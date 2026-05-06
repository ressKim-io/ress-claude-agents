#!/usr/bin/env bash
# Migration 0002 P1+P2 검증 게이트
#
# 1. schemas/*.v1.json 자체 compile (JSON Schema Draft 2020-12 meta-schema 통과)
# 2. P1 sample frontmatter validate
#    - .agents/skills/source-command-log-summary/SKILL.md → skill-manifest.v1.json
#    - .claude/agents/code-reviewer.md                    → agent-manifest.v1.json
# 3. P2 PoC 10개 (assets/skills/{kubernetes,go}/*/SKILL.md) → skill-manifest.v1.json
#    + strict 모드 (description >=40 chars + applies_when 존재)
#
# 의존성: npx (ajv-cli 5는 npx 캐시 실행, 추가 설치 불필요), node (내장 YAML 파서)
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
# 2. Frontmatter → JSON 변환 + schema validate (공통 함수)
# ---------------------------------------------------------------------------
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# YAML frontmatter (파일 첫 ---~--- 사이) 만 stdout 출력
extract_frontmatter() {
    awk 'NR==1 && /^---$/ {flag=1; next} flag && /^---$/ {exit} flag' "$1"
}

# YAML → JSON. node 내장만 사용. nested map / array / inline array 지원.
# 복잡한 YAML 케이스는 P3 control-plane의 yaml 패키지에 위임.
yaml_to_json_stdin() {
    # shellcheck disable=SC2016
    # JS literal — single quotes are intentional, no shell expansion expected
    node -e '
        const fs = require("fs");
        const txt = fs.readFileSync(0, "utf8");
        const lines = txt.split("\n");
        let i = 0;
        function readScalar(v) {
            v = v.trim();
            if (v === "") return null;
            if (v.startsWith("\"") && v.endsWith("\"")) return JSON.parse(v);
            if (v.startsWith("'\''") && v.endsWith("'\''")) return v.slice(1, -1);
            if (/^-?[0-9]+$/.test(v)) return parseInt(v, 10);
            if (v === "true") return true;
            if (v === "false") return false;
            if (v === "null") return null;
            return v;
        }
        function parseBlock(indent) {
            const result = {};
            while (i < lines.length) {
                const line = lines[i];
                if (!line.trim()) { i++; continue; }
                const li = line.length - line.trimStart().length;
                if (li < indent) return result;
                if (li > indent) { i++; continue; }
                const m = line.match(/^(\s*)([^:]+?):\s*(.*)$/);
                if (!m) { i++; continue; }
                const key = m[2].trim().replace(/^"(.*)"$/, "$1");
                const val = m[3];
                i++;
                if (val.trim() === "") {
                    const peek = lines[i] || "";
                    const peekIndent = peek.length - peek.trimStart().length;
                    if (peek.trim().startsWith("- ")) {
                        const arr = [];
                        while (i < lines.length) {
                            const l = lines[i];
                            const lli = l.length - l.trimStart().length;
                            if (!l.trim()) { i++; continue; }
                            if (lli <= indent) break;
                            const am = l.match(/^\s*-\s+(.*)$/);
                            if (!am) break;
                            arr.push(readScalar(am[1]));
                            i++;
                        }
                        result[key] = arr;
                    } else if (peekIndent > indent) {
                        result[key] = parseBlock(peekIndent);
                    } else {
                        result[key] = null;
                    }
                } else if (val.trim().startsWith("[") && val.trim().endsWith("]")) {
                    result[key] = val.trim().slice(1, -1).split(",").map(s => readScalar(s)).filter(v => v !== null);
                } else {
                    result[key] = readScalar(val);
                }
            }
            return result;
        }
        process.stdout.write(JSON.stringify(parseBlock(0)));
    '
}

validate_against_schema() {
    local file="$1"
    local schema="$2"
    local label="$3"
    local strict="${4:-false}"     # strict=true: description >=40 + applies_when 존재 추가 체크

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

    json="$(printf '%s' "$fm" | yaml_to_json_stdin)"
    local out
    out="$TMPDIR/$(printf '%s' "$file" | tr '/' '_').json"
    printf '%s\n' "$json" >"$out"

    if ! npx --yes ajv-cli@5 validate --spec=draft2020 -s "$schema" -d "$out" >/dev/null 2>&1; then
        log_fail "$label (schema)"
        npx --yes ajv-cli@5 validate --spec=draft2020 -s "$schema" -d "$out" 2>&1 | sed 's/^/    /'
        printf '    extracted JSON: %s\n' "$json"
        return
    fi

    if [[ "$strict" == "true" ]]; then
        local desc_len has_aw
        desc_len="$(node -e 'process.stdout.write(String((JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).description || "").length))' "$out")"
        has_aw="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).applies_when ? "yes" : "no")' "$out")"
        if (( desc_len < 40 )); then
            log_fail "$label (strict: description $desc_len chars < 40)"
            return
        fi
        if [[ "$has_aw" != "yes" ]]; then
            log_fail "$label (strict: applies_when 누락)"
            return
        fi
    fi

    log_pass "$label"
}

# ---------------------------------------------------------------------------
# 3. P1 sample 검증
# ---------------------------------------------------------------------------
section "P1 sample frontmatter validation"

validate_against_schema \
    ".agents/skills/source-command-log-summary/SKILL.md" \
    "schemas/skill-manifest.v1.json" \
    "source-command-log-summary → skill-manifest.v1"

validate_against_schema \
    ".claude/agents/code-reviewer.md" \
    "schemas/agent-manifest.v1.json" \
    "code-reviewer → agent-manifest.v1"

# ---------------------------------------------------------------------------
# 4. P2 PoC 10개 strict 검증
# ---------------------------------------------------------------------------
section "P2 PoC 10개 (strict: description >=40 + applies_when 필수)"

POC_FILES=(
    "assets/skills/kubernetes/k8s-helm/SKILL.md"
    "assets/skills/kubernetes/k8s-autoscaling/SKILL.md"
    "assets/skills/kubernetes/k8s-security/SKILL.md"
    "assets/skills/kubernetes/k8s-scheduling/SKILL.md"
    "assets/skills/kubernetes/k8s-traffic/SKILL.md"
    "assets/skills/go/go-testing/SKILL.md"
    "assets/skills/go/go-database/SKILL.md"
    "assets/skills/go/go-microservice/SKILL.md"
    "assets/skills/go/go-errors/SKILL.md"
    "assets/skills/go/go-gin/SKILL.md"
)

POC_COUNT=${#POC_FILES[@]}
if [[ $POC_COUNT -ne 10 ]]; then
    log_fail "P2 게이트: PoC 파일 수 $POC_COUNT (expected 10)"
fi

for f in "${POC_FILES[@]}"; do
    name="$(basename "$(dirname "$f")")"
    validate_against_schema "$f" "schemas/skill-manifest.v1.json" "$name" "true"
done

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
