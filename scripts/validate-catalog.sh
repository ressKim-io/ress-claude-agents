#!/usr/bin/env bash
# 자산 목록의 무결성 검증.
#
# 이전의 generate-docs.sh / validate-commands-drift.sh 는 commands 트리 두 벌과 manifest 가
# 서로 같은지만 봤다. 없는 명령을 참조해도 잡지 못했다 (존재하는 이름만 검사했다).
#
# 검증 항목:
#   1. floors    : 자산 종류별 개수 하한
#   2. locations : 로드되지 않는 위치의 SKILL.md 금지
#   3. commands  : 모든 command 에 frontmatter description 존재
#   4. refs      : rule 과 AGENTS.md 의 `/명령` 표기가 실제 자산으로 해석됨
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

check_references() {
    section "rule / AGENTS.md 의 명령 참조"
    local names refs
    names=$(mktemp)
    refs=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$names' '$refs'" RETURN

    {
        skill_files
        command_files
        if [[ -d .claude/commands/help ]]; then
            find .claude/commands/help -type f -name '*.md'
        fi
    } >"$names"
    { printf 'AGENTS.md\n'; rule_files; } >"$refs"

    if ! NAMES_FILE="$names" REFS_FILE="$refs" python3 - <<'PY'
import io, os, re, sys

# 내장 명령과, 문서가 형식을 설명하려고 쓰는 자리표시자. 자산이 아니다.
NOT_ASSETS = {
    "clear", "compact", "doctor", "skill-doctor", "plugin", "resume", "rename",
    "x", "command-name", "admin",
}

def asset_names(path):
    parts = path[:-3].split("/")
    if parts[0] == "plugins":
        plugin = parts[1]
        if parts[2] == "skills":
            return {f"{plugin}:{parts[3]}", parts[3]}
        return {":".join([plugin] + parts[3:])}
    if parts[1] == "skills":
        return {parts[2]}
    return {":".join(parts[2:])}

known = set()
for path in io.open(os.environ["NAMES_FILE"], encoding="utf-8").read().split():
    known |= asset_names(path)

REF = re.compile(r"`/([a-z][a-z0-9-]*(?::[a-z0-9-]+)*)(?:\s[^`]*)?`")
unresolved = []
checked = 0
for path in io.open(os.environ["REFS_FILE"], encoding="utf-8").read().split():
    for lineno, line in enumerate(io.open(path, encoding="utf-8"), 1):
        for name in REF.findall(line):
            if name in NOT_ASSETS:
                continue
            checked += 1
            if name not in known:
                unresolved.append((path, lineno, name))

if checked == 0:
    print("        명령 참조 0건 — 패턴이 깨졌다")
    sys.exit(1)
if unresolved:
    for path, lineno, name in unresolved:
        print(f"        해석되지 않는 명령: {path}:{lineno}  /{name}")
    sys.exit(1)
print(f"        참조 {checked}건 해석됨")
PY
    then
        log_fail "해석되지 않는 명령 참조가 있다"
    else
        log_pass "명령 참조 전부 해석됨"
    fi
}

check_floors
check_skill_locations
check_command_descriptions
check_references

printf '\n'
if [[ $EXIT_CODE -eq 0 ]]; then
    printf 'OK  자산 목록 검증 통과\n'
else
    printf 'NG  자산 목록 검증 실패\n'
fi
exit "$EXIT_CODE"
