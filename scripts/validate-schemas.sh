#!/usr/bin/env bash
# Migration 0002 P1 검증 게이트
#
# 1. schemas/*.v1.json 자체 compile (JSON Schema Draft 2020-12 meta-schema 통과)
# 2. 기존 frontmatter 샘플이 schema validate 통과
#    - .agents/skills/source-command-log-summary/SKILL.md → skill-manifest.v1.json
#    - .claude/agents/code-reviewer.md                    → agent-manifest.v1.json
#
# 의존성: npx (ajv-cli 5는 npx로 캐시 실행, 추가 설치 불필요)
# Exit code: 0 통과, 1 실패

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXIT_CODE=0
FAILED=()

log_pass() { printf '  PASS  %s\n' "$1"; }
log_fail() { printf '  FAIL  %s\n' "$1"; EXIT_CODE=1; FAILED+=("$1"); }
section()  { printf '\n=== %s ===\n' "$1"; }

# ---------------------------------------------------------------------------
# 1. Schema 자체 compile
# ---------------------------------------------------------------------------
section "Schema compile (Draft 2020-12)"

SCHEMAS=(
    "schemas/skill-manifest.v1.json"
    "schemas/project-profile.v1.json"
    "schemas/agent-manifest.v1.json"
)

for schema in "${SCHEMAS[@]}"; do
    if npx --yes ajv-cli@5 compile --spec=draft2020 -s "$schema" >/dev/null 2>&1; then
        log_pass "$schema"
    else
        log_fail "$schema"
        npx --yes ajv-cli@5 compile --spec=draft2020 -s "$schema" 2>&1 | sed 's/^/    /'
    fi
done

# ---------------------------------------------------------------------------
# 2. Frontmatter → JSON 추출 후 schema validate
# ---------------------------------------------------------------------------
section "Frontmatter sample validation"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# YAML frontmatter (파일 첫 ---~--- 사이) 만 stdout 출력
extract_frontmatter() {
    local file="$1"
    awk 'NR==1 && /^---$/ {flag=1; next} flag && /^---$/ {exit} flag' "$file"
}

# YAML → JSON 변환. node 내장으로 처리 (의존성 zero).
yaml_to_json() {
    local yaml_text="$1"
    node -e '
        const yaml = process.argv[1];
        // minimal YAML parser — frontmatter는 단순 구조라 동작.
        // 복잡한 케이스는 P3 control-plane의 yaml 패키지가 처리.
        const lines = yaml.split("\n");
        const obj = {};
        let currentKey = null;
        let currentArr = null;
        for (const line of lines) {
            if (!line.trim()) continue;
            const arrMatch = line.match(/^\s+-\s+(.+)$/);
            if (arrMatch && currentArr) {
                currentArr.push(arrMatch[1].replace(/^["'\'']|["'\'']$/g, ""));
                continue;
            }
            const kvMatch = line.match(/^([a-zA-Z_][a-zA-Z0-9_-]*)\s*:\s*(.*)$/);
            if (kvMatch) {
                const [, key, valRaw] = kvMatch;
                const val = valRaw.trim();
                currentKey = key;
                currentArr = null;
                if (val === "") {
                    currentArr = [];
                    obj[key] = currentArr;
                } else if (val.startsWith("[") && val.endsWith("]")) {
                    obj[key] = val.slice(1, -1).split(",").map(s => s.trim().replace(/^["'\'']|["'\'']$/g, "")).filter(Boolean);
                } else {
                    obj[key] = val.replace(/^["'\'']|["'\'']$/g, "");
                }
            }
        }
        process.stdout.write(JSON.stringify(obj));
    ' "$yaml_text"
}

validate_sample() {
    local file="$1"
    local schema="$2"
    local label="$3"

    if [[ ! -f "$file" ]]; then
        log_fail "$label: $file (file not found)"
        return
    fi

    local fm json
    fm="$(extract_frontmatter "$file")"
    if [[ -z "$fm" ]]; then
        log_fail "$label: frontmatter 없음 ($file)"
        return
    fi

    json="$(yaml_to_json "$fm")"
    local out="$TMPDIR/$(basename "$file" .md).json"
    printf '%s\n' "$json" >"$out"

    if npx --yes ajv-cli@5 validate --spec=draft2020 -s "$schema" -d "$out" >/dev/null 2>&1; then
        log_pass "$label"
    else
        log_fail "$label"
        npx --yes ajv-cli@5 validate --spec=draft2020 -s "$schema" -d "$out" 2>&1 | sed 's/^/    /'
        printf '    extracted JSON: %s\n' "$json"
    fi
}

validate_sample \
    ".agents/skills/source-command-log-summary/SKILL.md" \
    "schemas/skill-manifest.v1.json" \
    "source-command-log-summary → skill-manifest.v1"

validate_sample \
    ".claude/agents/code-reviewer.md" \
    "schemas/agent-manifest.v1.json" \
    "code-reviewer → agent-manifest.v1"

# ---------------------------------------------------------------------------
# 결과
# ---------------------------------------------------------------------------
printf '\n'
if [[ $EXIT_CODE -eq 0 ]]; then
    printf '✓ All schema checks passed\n'
else
    printf '✗ %d check(s) failed:\n' "${#FAILED[@]}"
    for f in "${FAILED[@]}"; do
        printf '  - %s\n' "$f"
    done
fi

exit "$EXIT_CODE"
