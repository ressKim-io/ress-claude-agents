#!/usr/bin/env bash
# claude CLI 로 plugin 이 실제로 인식되는지 확인한다. 모델을 호출하지 않아 토큰을 쓰지 않는다.
#
# CI 에서 돌지 않는다: claude CLI 가 필요하다 (새 의존성이라 별도로 결정한다).
#
# 검사:
#   1. claude plugin validate   : 매니페스트와 자산. version 누락 경고만 허용한다.
#                                 version 은 일부러 비워 둔다 — 커밋 SHA 로 업데이트를 감지한다 (ADR 0012).
#   2. initialize 응답          : --plugin-dir 로 불러 skill·command·agent 가 파일 수만큼 보이는지 본다.
#   3. 자체 활성화              : 레포 루트의 settings.json 만으로 enabledPlugins 가 로드되는지 본다.
#                                 `claude plugin details` 는 프로젝트 marketplace 를 읽지 않아 쓸 수 없다.
#
# 사용: ./scripts/verify-plugins.sh [plugin ...]   # 인자가 없으면 marketplace 의 전체 plugin
# Exit code: 0 = 통과, 1 = 실패

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v claude >/dev/null 2>&1; then
    printf 'FAIL  claude CLI 가 없다\n'
    exit 1
fi

MARKETPLACE_LIST=$(python3 -c '
import json
for entry in json.load(open(".claude-plugin/marketplace.json", encoding="utf-8"))["plugins"]:
    print(entry["name"])
')
PLUGINS="${*:-$MARKETPLACE_LIST}"
EXIT_CODE=0

check_validate() {
    local target="$1" report
    report=$(claude plugin validate "$target" --json 2>&1) || {
        printf 'FAIL  validate %s\n%s\n' "$target" "$report" | cut -c1-200
        EXIT_CODE=1
        return
    }
    if ! REPORT="$report" python3 - "$target" <<'PY'
import json, os, re, sys

report = json.loads(os.environ["REPORT"])
warnings = report.get("warnings", [])
unexpected = [w for w in warnings if not re.search(r"\bversion\b", json.dumps(w, ensure_ascii=False))]
for warning in unexpected:
    print(f"  경고: {json.dumps(warning, ensure_ascii=False)[:200]}")
sys.exit(1 if unexpected else 0)
PY
    then
        printf 'FAIL  validate %s: 허용되지 않은 경고\n' "$target"
        EXIT_CODE=1
        return
    fi
    printf 'PASS  validate %s\n' "$target"
}

initialize_response() {
    printf '%s\n' '{"type":"control_request","request_id":"p","request":{"subtype":"initialize"}}' \
        | claude -p --input-format stream-json --output-format stream-json --verbose \
            --no-session-persistence "$@" 2>&1 || true
}

check_loaded() {
    local plugin="$1" response
    response=$(initialize_response --plugin-dir "plugins/$plugin")
    if ! RESPONSE="$response" python3 - "$plugin" <<'PY'
import glob, json, os, sys

plugin = sys.argv[1]
init = None
for line in os.environ["RESPONSE"].splitlines():
    try:
        message = json.loads(line)
    except ValueError:
        continue
    if message.get("type") == "control_response":
        init = message["response"].get("response", {})
if init is None:
    print(f"  initialize 응답을 받지 못했다: {plugin}")
    sys.exit(1)

prefix = f"{plugin}:"
commands = {c["name"] for c in init.get("commands", []) if c["name"].startswith(prefix)}
agents = {a["name"] for a in init.get("agents", []) if a["name"].startswith(prefix)}
want_commands = {prefix + os.path.basename(os.path.dirname(p)) for p in glob.glob(f"plugins/{plugin}/skills/*/SKILL.md")}
want_commands |= {prefix + os.path.basename(p)[:-3] for p in glob.glob(f"plugins/{plugin}/commands/*.md")}
want_agents = {prefix + os.path.basename(p)[:-3] for p in glob.glob(f"plugins/{plugin}/agents/*.md")}

missing = sorted((want_commands - commands) | (want_agents - agents))
for name in missing:
    print(f"  로드되지 않음: {name}")
print(f"  {plugin}: skill+command {len(commands)}/{len(want_commands)}, agent {len(agents)}/{len(want_agents)}")
sys.exit(1 if missing or not (want_commands or want_agents) else 0)
PY
    then
        printf 'FAIL  load %s\n' "$plugin"
        EXIT_CODE=1
        return
    fi
    printf 'PASS  load %s\n' "$plugin"
}

check_self_enabled() {
    local response
    response=$(initialize_response)
    if ! RESPONSE="$response" python3 - <<'PY'
import json, os, sys

enabled = [key.split("@")[0] for key, on in json.load(open(".claude/settings.json", encoding="utf-8")).get("enabledPlugins", {}).items() if on]
init = None
for line in os.environ["RESPONSE"].splitlines():
    try:
        message = json.loads(line)
    except ValueError:
        continue
    if message.get("type") == "control_response":
        init = message["response"].get("response", {})
if init is None:
    print("  initialize 응답을 받지 못했다")
    sys.exit(1)
failed = False
for plugin in enabled:
    count = sum(c["name"].startswith(plugin + ":") for c in init.get("commands", []))
    print(f"  {plugin}: 레포 루트에서 {count}개 로드")
    failed = failed or count == 0
sys.exit(1 if failed or not enabled else 0)
PY
    then
        printf 'FAIL  self-enable\n'
        EXIT_CODE=1
        return
    fi
    printf 'PASS  self-enable\n'
}

check_validate .
for plugin in $PLUGINS; do
    check_validate "plugins/$plugin"
    check_loaded "$plugin"
done
check_self_enabled

exit "$EXIT_CODE"
