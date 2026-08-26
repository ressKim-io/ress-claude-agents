#!/usr/bin/env bash
# commands/ <-> .claude/commands/ drift 자동 검증
#
# 배경: 두 트리는 역할이 다르지만 내용은 같아야 한다.
#   - commands/          = 모듈 디렉토리 단위 소스 (install.sh 가 읽던 레이아웃)
#   - .claude/commands/  = 이 레포에서 Claude Code 가 읽는 **작업 세트**
# 2026-08-16 audit 에서 이 중복이 소리 없이 벌어진 사실이 확인됐다:
#   - 명령 16개가 .claude/ 에만 있어 설치 프로젝트에서 사용 불가 (기능 결함)
#   - manifest.yml / help/go.md 가 deprecated skill(go-errors)을 계속 참조
# 근본 원인은 "CI 가 검사하지 않는 것은 반드시 drift 한다".
#
# 검증 항목:
#   1. modules   : 공유 모듈 디렉토리(backend/dx/go/... )가 양쪽 동일
#   2. flattened : flatten 모듈(memory/review/workflow)의 각 파일이
#                  .claude/commands/ 최상위 동명 파일과 내용 일치
#   3. shared    : manifest.yml / help/index.md 동일
#   4. coverage  : 설치되는 rule 이 참조하는 bare 명령이 설치 소스에 존재
#
# 사용:
#   ./scripts/validate-commands-drift.sh            # 전체 (CI 기본)
#   ./scripts/validate-commands-drift.sh modules
#   ./scripts/validate-commands-drift.sh flattened
#   ./scripts/validate-commands-drift.sh shared
#   ./scripts/validate-commands-drift.sh coverage
#   ./scripts/validate-commands-drift.sh ssot
#
# Exit code: 0 = 통과, 1 = 실패

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="commands"
WORK=".claude/commands"

# flatten 모듈의 SSOT 는 commands/manifest.yml 의 `categories.<name>.flatten: true` 다
# (scripts/generate-docs.sh 의 is_flattened_category() 도 같은 필드를 읽는다).
# 여기서 하드코딩하면 SSOT 가 3곳으로 갈라지므로 manifest 에서 읽어온다.
read_flatten_modules_from_manifest() {
    yq -r '.categories | to_entries[] | select(.value.flatten == true) | .key' \
        "$SRC/manifest.yml" 2>/dev/null | sort
}

FLATTEN_MODULES=()
while IFS= read -r _m; do
    [[ -n "$_m" ]] && FLATTEN_MODULES+=("$_m")
done < <(read_flatten_modules_from_manifest)

if [[ ${#FLATTEN_MODULES[@]} -eq 0 ]]; then
    printf 'FAIL  %s 에서 flatten 카테고리를 읽지 못했습니다 (yq 미설치 또는 manifest 손상)\n' \
        "$SRC/manifest.yml" >&2
    exit 1
fi

EXIT_CODE=0

log_pass() { printf '  PASS  %s\n' "$1"; }
log_fail() { printf '  FAIL  %s\n' "$1"; EXIT_CODE=1; }
section()  { printf '\n=== %s ===\n' "$1"; }

is_flatten_module() {
    local candidate="$1" m
    for m in "${FLATTEN_MODULES[@]}"; do
        [[ "$m" == "$candidate" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# 1. 공유 모듈 디렉토리 동일성
# ---------------------------------------------------------------------------
check_modules() {
    section "공유 모듈 디렉토리 동일성"

    local mismatched=0 checked=0
    local dir mod
    for dir in "$SRC"/*/; do
        mod=$(basename "$dir")
        is_flatten_module "$mod" && continue

        if [[ ! -d "$WORK/$mod" ]]; then
            log_fail "$WORK/$mod 없음 (설치 소스에만 존재)"
            mismatched=$((mismatched + 1))
            continue
        fi
        if ! diff -rq "$SRC/$mod" "$WORK/$mod" >/dev/null 2>&1; then
            log_fail "모듈 '$mod' 내용 불일치"
            diff -rq "$SRC/$mod" "$WORK/$mod" 2>&1 | sed 's/^/        /' || true
            mismatched=$((mismatched + 1))
        fi
        checked=$((checked + 1))
    done

    # 역방향: .claude 에만 있는 모듈 디렉토리
    for dir in "$WORK"/*/; do
        mod=$(basename "$dir")
        is_flatten_module "$mod" && continue
        if [[ ! -d "$SRC/$mod" ]]; then
            log_fail "$SRC/$mod 없음 — '$mod' 모듈이 설치되지 않는다"
            mismatched=$((mismatched + 1))
        fi
    done

    if [[ $mismatched -eq 0 ]]; then
        log_pass "공유 모듈 ${checked}개 동일"
    fi
}

# ---------------------------------------------------------------------------
# 2. flatten 모듈 <-> .claude 최상위 파일 일치
# ---------------------------------------------------------------------------
# flatten 모듈은 설치 소스에서는 디렉토리로 묶여 있고, 이 레포의 작업 세트에서는
# 최상위 평면 파일이다 (bare 이름 /where 유지). 배치는 달라도 내용은 같아야 한다.
check_flattened() {
    section "flatten 모듈 <-> .claude 최상위 파일 일치"

    local mismatched=0 checked=0
    local mod f name
    for mod in "${FLATTEN_MODULES[@]}"; do
        if [[ ! -d "$SRC/$mod" ]]; then
            log_fail "$SRC/$mod 없음 (flatten 모듈 미설치)"
            mismatched=$((mismatched + 1))
            continue
        fi
        for f in "$SRC/$mod"/*.md; do
            [[ -f "$f" ]] || continue
            name=$(basename "$f")
            if [[ ! -f "$WORK/$name" ]]; then
                log_fail "$WORK/$name 없음 (설치 소스 $mod/$name 에만 존재)"
                mismatched=$((mismatched + 1))
                continue
            fi
            if ! diff -q "$f" "$WORK/$name" >/dev/null 2>&1; then
                log_fail "$mod/$name 내용 불일치 ($WORK/$name 와 다름)"
                mismatched=$((mismatched + 1))
            fi
            checked=$((checked + 1))
        done
    done

    # 역방향: .claude 최상위 .md 중 설치 소스에 없는 것 = 설치 불가 명령
    for f in "$WORK"/*.md; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        local found=0 mod2
        for mod2 in "${FLATTEN_MODULES[@]}"; do
            [[ -f "$SRC/$mod2/$name" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            log_fail "$name 이 설치 소스에 없음 — 설치 프로젝트에서 사용 불가"
            mismatched=$((mismatched + 1))
        fi
    done

    if [[ $mismatched -eq 0 ]]; then
        log_pass "flatten 명령 ${checked}개 일치"
    fi
}

# ---------------------------------------------------------------------------
# 3. 공유 파일 동일성
# ---------------------------------------------------------------------------
check_shared() {
    section "공유 파일 동일성 (manifest / help index)"

    local mismatched=0 rel
    for rel in "manifest.yml" "help/index.md"; do
        if [[ ! -f "$SRC/$rel" || ! -f "$WORK/$rel" ]]; then
            log_fail "$rel 이 한쪽에만 존재"
            mismatched=$((mismatched + 1))
            continue
        fi
        if ! diff -q "$SRC/$rel" "$WORK/$rel" >/dev/null 2>&1; then
            log_fail "$rel 불일치 — 한쪽만 갱신됨"
            mismatched=$((mismatched + 1))
        fi
    done

    if [[ $mismatched -eq 0 ]]; then
        log_pass "manifest.yml / help/index.md 동일"
    fi
}

# ---------------------------------------------------------------------------
# 4. rule 이 참조하는 bare 명령이 설치 소스에 존재하는가
# ---------------------------------------------------------------------------
# 설치되는 rule (.claude/rules/*.md) 이 /where, /log-trouble 처럼 bare 이름으로
# 명령을 참조한다. 그 명령이 설치 소스에 없으면 설치 사용자에게 깨진 안내가 된다.
check_coverage() {
    section "rule 참조 명령의 설치 가능 여부"

    local missing=0 checked=0
    local cmd rule_hits found dir

    # rule 본문에서 /command-name 패턴 수집 (kebab-case, 2글자 이상)
    while IFS= read -r cmd; do
        [[ -z "$cmd" ]] && continue
        found=0
        for dir in "$SRC"/*/; do
            [[ -f "${dir}${cmd}.md" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            rule_hits=$(grep -rl -- "/$cmd" .claude/rules/ 2>/dev/null | tr '\n' ' ')
            log_fail "/$cmd 미설치 — 참조: $rule_hits"
            missing=$((missing + 1))
        fi
        checked=$((checked + 1))
    done < <(
        # 하이픈을 강제하면 /where /related 같은 단일 단어 명령을 놓친다 —
        # 하필 이 검사가 보호하려는 대상이다. 아래 존재 여부 필터가 URL·경로
        # 조각을 걸러주므로 패턴을 넓혀도 오탐 위험은 낮다.
        grep -rhoE '/[a-z][a-z0-9]*(-[a-z0-9]+)*' .claude/rules/ 2>/dev/null \
          | sed 's|^/||' | sort -u \
          | while IFS= read -r c; do
                # 실제 명령 파일이 어느 한쪽 트리에 존재하는 이름만 대상으로 한다
                # (rule 본문의 경로/URL 조각을 걸러내기 위함)
                if [[ -f "$WORK/$c.md" ]] || compgen -G "$SRC/*/$c.md" >/dev/null; then
                    printf '%s\n' "$c"
                fi
            done
    )

    if [[ $missing -eq 0 ]]; then
        log_pass "rule 참조 명령 ${checked}개 전부 설치 가능"
    fi
}

# ---------------------------------------------------------------------------
# 5. flatten 모듈 목록 SSOT 일치

# ---------------------------------------------------------------------------
main() {
    local target="${1:-all}"
    case "$target" in
        modules)   check_modules ;;
        flattened) check_flattened ;;
        shared)    check_shared ;;
        coverage)  check_coverage ;;
        all)
            check_modules
            check_flattened
            check_shared
            check_coverage
            ;;
        *)
            printf 'Unknown target: %s\n' "$target" >&2
            printf 'Usage: %s [all|ssot|modules|flattened|shared|coverage]\n' "$0" >&2
            exit 2
            ;;
    esac

    printf '\n'
    if [[ $EXIT_CODE -eq 0 ]]; then
        printf 'OK  commands drift 검증 통과\n'
    else
        printf 'NG  commands drift 검증 실패\n'
    fi
    exit "$EXIT_CODE"
}

main "$@"
