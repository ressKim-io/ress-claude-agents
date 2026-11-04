#!/usr/bin/env bash
# 자산 목록의 무결성 검증.
#
# 이전의 generate-docs.sh / validate-commands-drift.sh 는 commands 트리 두 벌과 manifest 가
# 서로 같은지만 봤다. 없는 명령을 참조해도 잡지 못했다 (존재하는 이름만 검사했다).
#
# 검증 항목:
#   1. floors    : 자산 종류별 개수 하한
#   2. locations : 로드되지 않는 위치의 SKILL.md, 옛 구조의 자산 폴더 금지
#   3. commands  : 모든 command 에 frontmatter description 존재
#   4. refs      : 문서의 `/plugin:이름`, subagent_type 이 실제 자산으로 해석됨
#   7. skills    : description 이 '무엇. Use when 상황.' 형식, 250자 이내, 템플릿 문구·중복 없음
#   5. plugins   : marketplace, plugin 폴더, plugin.json, enabledPlugins 가 서로 일치
#   6. paths     : 본문에 적은 rule·plugin 경로가 실제로 존재
#
# 사용: ./scripts/validate-catalog.sh
# Exit code: 0 = 통과, 1 = 실패

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib/layout.sh
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/layout.sh"

EXIT_CODE=0

log_pass() { printf '  PASS  %s\n' "$1"; }
log_fail() { printf '  FAIL  %s\n' "$1"; EXIT_CODE=1; }
section()  { printf '\n=== %s ===\n' "$1"; }

check_floors() {
    section "자산 개수 하한"
    local kind
    for kind in skills agents commands rules; do
        if assert_floor "$kind"; then
            log_pass "$kind $(asset_count "$kind")개"
        else
            EXIT_CODE=1
        fi
    done
}

check_skill_locations() {
    section "skill 위치"
    local misplaced
    misplaced=$(comm -23 <(any_skill_manifests) <(skill_files))
    if [[ -n "$misplaced" ]]; then
        log_fail "로드되지 않는 위치의 SKILL.md:"
        printf '%s\n' "$misplaced" | sed 's/^/        /'
    else
        log_pass "모든 SKILL.md 가 <skill-name>/SKILL.md 형태"
    fi
}

has_description() {
    awk '
        NR == 1 { if ($0 != "---") exit 1; next }
        /^---$/ { exit 1 }
        /^description:[[:space:]]*[^[:space:]]/ { found = 1; exit 0 }
        END { exit(found ? 0 : 1) }
    ' "$1"
}

check_command_descriptions() {
    section "command description"
    local file missing=0
    while IFS= read -r file; do
        if ! has_description "$file"; then
            printf '        description 없음: %s\n' "$file"
            missing=$((missing + 1))
        fi
    done < <(command_files)
    if [[ $missing -gt 0 ]]; then
        log_fail "description 없음 ${missing}건"
    else
        log_pass "command 전부 description 보유"
    fi
}

check_legacy_directories() {
    section "옛 구조"
    local dirs
    dirs=$(legacy_asset_dirs)
    if [[ -n "$dirs" ]]; then
        log_fail "옛 구조의 자산 폴더가 있다. plugins/<plugin>/ 으로 옮긴다:"
        printf '%s\n' "$dirs" | sed 's/^/        옛 구조: /'
    else
        log_pass "옛 구조의 자산 폴더 없음"
    fi
}

check_skill_descriptions() {
    section "skill description"
    local list
    list=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$list'" RETURN
    skill_files >"$list"

    if ! LIST_FILE="$list" python3 - <<'PY'
import io, os, re, sys

# 목록 예산이 컨텍스트의 1% 라 길수록 뒤쪽 skill 의 description 이 먼저 빠진다.
LIMIT = 250
TEMPLATE = re.compile(r"Use when working with|도메인의 패턴|구현 선택")
problems = []
seen = {}
paths = io.open(os.environ["LIST_FILE"], encoding="utf-8").read().split()
for path in paths:
    name = path.split("/")[3]
    head = io.open(path, encoding="utf-8").read().split("\n---", 1)[0]
    match = re.search(r"^description:[ \t]*(.*)$", head, re.M)
    description = match.group(1).strip().strip('"') if match else ""
    if TEMPLATE.search(description):
        problems.append(f"템플릿 문구: {name}")
    if description.count(". Use when ") != 1 or not description.endswith("."):
        problems.append(f"'무엇. Use when 상황.' 형식이 아니다: {name}")
    if len(description) > LIMIT:
        problems.append(f"{LIMIT}자 초과 ({len(description)}자): {name}")
    if description in seen:
        problems.append(f"중복: {seen[description]} / {name}")
    seen.setdefault(description, name)

if not paths:
    print("        대상 0건 — 목록이 비었다")
    sys.exit(1)
for problem in problems:
    print(f"        {problem}")
if problems:
    sys.exit(1)
print(f"        {len(paths)}건 형식 통과")
PY
    then
        log_fail "description 규칙 위반"
    else
        log_pass "description 규칙 통과"
    fi
}

check_references() {
    section "명령·skill·agent 참조"
    local assets strict loose
    assets=$(mktemp)
    strict=$(mktemp)
    loose=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$assets' '$strict' '$loose'" RETURN

    { skill_files; command_files; agent_files; } >"$assets"
    { printf 'AGENTS.md\n'; rule_files; } >"$strict"
    {
        printf 'README.md\nREADME.ko.md\n'
        skill_files
        agent_files
        command_files
        find docs/architecture docs/guides docs/onboarding -type f -name '*.md'
        find .claude/templates -maxdepth 1 -type f
    } >"$loose"

    if ! ASSETS_FILE="$assets" STRICT_FILE="$strict" LOOSE_FILE="$loose" python3 - <<'PY'
import io, json, os, re, sys

# 내장 명령과, 문서가 형식을 설명하려고 쓰는 자리표시자. 자산이 아니다.
NOT_ASSETS = {
    "clear", "compact", "doctor", "skill-doctor", "plugin", "resume", "rename",
    "x", "command-name", "admin",
}
BUILTIN_AGENTS = {"general-purpose", "Explore", "Plan"}

commands, agents = set(), set()
for path in io.open(os.environ["ASSETS_FILE"], encoding="utf-8").read().split():
    parts = path.split("/")
    plugin, kind = parts[1], parts[2]
    name = parts[3][:-3] if parts[3].endswith(".md") else parts[3]
    (agents if kind == "agents" else commands).add(f"{plugin}:{name}")

plugins = [e["name"] for e in json.load(open(".claude-plugin/marketplace.json", encoding="utf-8"))["plugins"]]
QUALIFIED_PREFIX = "|".join(map(re.escape, plugins))
# 규칙과 AGENTS.md: 백틱으로 적은 `/명령` 은 전부 실제 자산이어야 한다.
STRICT = re.compile(r"`/([a-z][a-z0-9-]*(?::[a-z0-9-]+)*)(?:\s[^`]*)?`")
# 그 밖의 문서: `/api` 같은 경로가 많아 plugin 접두사가 붙은 표기만 본다.
QUALIFIED = re.compile(rf"(?<![\w/.<-])/((?:{QUALIFIED_PREFIX})(?::[a-z0-9-]+)+)")
SUBAGENT = re.compile(r"subagent_type: `([^`]+)`")

problems = []
checked = 0


def scan(listing, pattern, skip=()):
    global checked
    for path in io.open(os.environ[listing], encoding="utf-8").read().split():
        for lineno, line in enumerate(io.open(path, encoding="utf-8"), 1):
            for name in pattern.findall(line):
                if name in skip:
                    continue
                checked += 1
                if name not in commands:
                    problems.append(f"해석되지 않는 명령: {path}:{lineno}  /{name}")
            for name in SUBAGENT.findall(line):
                checked += 1
                if name not in agents and name not in BUILTIN_AGENTS:
                    problems.append(f"없는 agent: {path}:{lineno}  {name}")


scan("STRICT_FILE", STRICT, NOT_ASSETS)
scan("LOOSE_FILE", QUALIFIED)

if checked == 0:
    print("        참조 0건 — 패턴이 깨졌다")
    sys.exit(1)
if problems:
    for problem in problems:
        print(f"        {problem}")
    sys.exit(1)
print(f"        참조 {checked}건 해석됨")
PY
    then
        log_fail "해석되지 않는 참조가 있다"
    else
        log_pass "참조 전부 해석됨"
    fi
}

check_plugins() {
    section "plugin 구성"
    if ! python3 - <<'PY'
import glob, json, os, sys

MARKETPLACE = ".claude-plugin/marketplace.json"
SETTINGS = ".claude/settings.json"
problems = []

if not os.path.exists(MARKETPLACE):
    if os.path.isdir("plugins"):
        print(f"        {MARKETPLACE} 가 없는데 plugins/ 가 있다")
        sys.exit(1)
    print("        plugin 구조 아님")
    sys.exit(0)

marketplace = json.load(open(MARKETPLACE, encoding="utf-8"))
names = set()
for entry in marketplace.get("plugins", []):
    name = entry["name"]
    names.add(name)
    if entry.get("source") != f"./plugins/{name}" or not os.path.isdir(f"plugins/{name}"):
        problems.append(f"marketplace 항목의 경로가 없다: {name}")
        continue
    manifest = f"plugins/{name}/.claude-plugin/plugin.json"
    if not os.path.exists(manifest):
        problems.append(f"plugin.json 없음: {name}")
    elif json.load(open(manifest, encoding="utf-8")).get("name") != name:
        problems.append(f"plugin.json 의 name 이 폴더와 다르다: {name}")
    if not any(os.path.isdir(f"plugins/{name}/{kind}") for kind in ("skills", "agents", "commands")):
        problems.append(f"자산이 없는 plugin: {name}")
    # 이름이 같으면 skill 이 이겨 command 가 조용히 사라진다 (공식 문서)
    skills = {p.split("/")[3] for p in glob.glob(f"plugins/{name}/skills/*/SKILL.md")}
    commands = {os.path.basename(p)[:-3] for p in glob.glob(f"plugins/{name}/commands/*.md")}
    for shadowed in sorted(skills & commands):
        problems.append(f"command 와 skill 의 이름이 겹친다: {name}:{shadowed}")

for name in sorted(os.listdir("plugins")) if os.path.isdir("plugins") else []:
    if os.path.isdir(f"plugins/{name}") and name not in names:
        problems.append(f"marketplace 에 없다: {name}")

settings = json.load(open(SETTINGS, encoding="utf-8"))
marketplace_name = marketplace["name"]
for key in settings.get("enabledPlugins", {}):
    plugin, _, source = key.partition("@")
    if source == marketplace_name and plugin not in names:
        problems.append(f"enabledPlugins 항목이 marketplace 에 없다: {key}")
if settings.get("enabledPlugins") and marketplace_name not in settings.get("extraKnownMarketplaces", {}):
    problems.append(f"extraKnownMarketplaces 에 {marketplace_name} 이 없다")

for problem in problems:
    print(f"        {problem}")
if problems:
    sys.exit(1)
print(f"        plugin {len(names)}개 일치")
PY
    then
        log_fail "plugin 구성이 맞지 않다"
    else
        log_pass "plugin 구성 일치"
    fi
}

check_path_mentions() {
    section "본문의 경로 표기"
    local targets
    targets=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$targets'" RETURN
    {
        printf 'AGENTS.md\n'
        skill_files
        agent_files
        command_files
        rule_files
        find .claude/templates -maxdepth 1 -type f
        find docs/architecture docs/guides docs/onboarding -type f -name '*.md'
    } >"$targets"

    if ! TARGETS_FILE="$targets" python3 - <<'PY'
import io, os, re, sys

MENTION = re.compile(
    r"(?<![\w/.-])(\.claude/rules/[a-z0-9/-]+\.md"
    r"|plugins/[a-z0-9-]+/(?:skills|agents|commands|templates)/[A-Za-z0-9._/-]+)"
)
missing = []
checked = 0
for path in io.open(os.environ["TARGETS_FILE"], encoding="utf-8").read().split():
    for lineno, line in enumerate(io.open(path, encoding="utf-8"), 1):
        for mention in MENTION.findall(line):
            mention = mention.rstrip("./")
            checked += 1
            if not os.path.exists(mention):
                missing.append((path, lineno, mention))
if checked == 0:
    print("        경로 표기 0건 — 패턴이 깨졌다")
    sys.exit(1)
for path, lineno, mention in missing:
    print(f"        없는 경로: {path}:{lineno}  {mention}")
if missing:
    sys.exit(1)
print(f"        경로 표기 {checked}건 존재")
PY
    then
        log_fail "없는 경로를 가리키는 표기가 있다"
    else
        log_pass "경로 표기 전부 존재"
    fi
}

check_floors
check_skill_locations
check_legacy_directories
check_command_descriptions
check_skill_descriptions
check_references
check_plugins
check_path_mentions

printf '\n'
if [[ $EXIT_CODE -eq 0 ]]; then
    printf 'OK  자산 목록 검증 통과\n'
else
    printf 'NG  자산 목록 검증 실패\n'
fi
exit "$EXIT_CODE"
