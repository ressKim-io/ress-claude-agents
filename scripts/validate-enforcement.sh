#!/usr/bin/env bash
# .claude/settings.json <-> .claude/rules/user-approval.md 강제 규칙 드리프트 검증
#
# 배경: 2026-08-25 audit F11 — control-plane 의 PreToolUse hook 이 존재하지 않는
# 환경변수로 배선돼 3.5개월간 0% 로 작동했는데, 순수 함수 테스트만 있어 아무도
# 알아채지 못했다. 강제력 자산은 "강제된다는 주장이 거짓이 됐을 때 즉시 드러나야"
# 한다 (ADR 0009). 본 스크립트가 정적 층을 담당한다.
#
# 검증 항목:
#   1. syntax  : settings.json 파싱 + 규칙 형식 (Tool 또는 Tool(specifier))
#   2. invalid : 공식 문서상 무시되는 패턴 (Bash(command:...)) 사용 0건
#   3. overlap : deny 와 ask 에 같은 규칙 중복 0건
#   4. drift   : settings.json 규칙 <-> user-approval.md 매핑 표 양방향 일치
#   5. count   : 규칙 최소 개수 하한 — 빈 상태가 "0건 일치" 로 통과하는 것 차단
#
# 잡지 못하는 것 (의도적):
#   - 규칙이 런타임에 실제로 발동하는지. 그건 `make verify-enforcement` 가 하고,
#     claude CLI 가 필요해 CI 에서 돌지 않는다. ADR 0009 §Consequences 참조.
#
# 사용: ./scripts/validate-enforcement.sh [syntax|invalid|overlap|drift|count]
# Exit code: 0 = 통과, 1 = 실패

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SETTINGS=".claude/settings.json"
RULEDOC=".claude/rules/user-approval.md"

# 규칙이 통째로 사라져도 "0건 양방향 일치" 로 초록이 되는 것을 막는다.
# validate-schemas.sh 의 MIN_AGENT_COUNT 과 같은 이유 — 빈 상태가 통과하면
# 게이트가 아니라 장식이다 (PR #36 리뷰).
MIN_RULE_COUNT=15

EXIT_CODE=0
FAILED_CHECKS=()

log_pass() { printf '  PASS  %s\n' "$1"; }
log_fail() { printf '  FAIL  %s\n' "$1"; EXIT_CODE=1; FAILED_CHECKS+=("$1"); }
section()  { printf '\n=== %s ===\n' "$1"; }

require_files() {
    local missing=0
    [[ -f "$SETTINGS" ]] || { printf 'ERROR: %s 없음\n' "$SETTINGS"; missing=1; }
    [[ -f "$RULEDOC"  ]] || { printf 'ERROR: %s 없음\n' "$RULEDOC";  missing=1; }
    command -v jq >/dev/null 2>&1 || { printf 'ERROR: jq 필요\n'; missing=1; }
    [[ $missing -eq 0 ]] || exit 1
}

# settings.json 의 규칙을 "층<TAB>규칙" 으로 출력
settings_rules() {
    jq -r '
      (.permissions.deny // [] | .[] | "deny\t" + .),
      (.permissions.ask  // [] | .[] | "ask\t"  + .)
    ' "$SETTINGS"
}

# user-approval.md 매핑 표의 행을 "층<TAB>규칙" 으로 출력
#   형식: | `Bash(...)` | deny | ... |
doc_rules() {
    # SC2016: 백틱은 마크다운 코드 표기이지 명령 치환이 아니다 — 확장하면 안 된다.
    # shellcheck disable=SC2016
    grep -E '^\| `[A-Za-z]+\(.*\)` \| (deny|ask) \|' "$RULEDOC" \
      | sed -E 's/^\| `([^`]+)` \| (deny|ask) \|.*/\2\t\1/'
}

check_syntax() {
    section "1. settings.json 파싱 + 규칙 형식"
    if ! jq empty "$SETTINGS" 2>/dev/null; then
        # 파싱이 안 되면 이후 체크는 빈 규칙 목록을 보고 오해를 부르는 PASS 를 낸다.
        # F11 의 실패 모드(무효한데 통과로 보임)를 스크립트 자신이 반복하지 않도록 즉시 중단.
        log_fail "$SETTINGS JSON 파싱 실패 — 이후 검증 중단"
        printf '\nNG  실패: %s\n' "${FAILED_CHECKS[*]}"
        exit 1
    fi
    log_pass "JSON 파싱 OK"

    local bad=0 rule
    while IFS=$'\t' read -r _ rule; do
        [[ -n "$rule" ]] || continue
        if ! printf '%s' "$rule" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*(\(.+\))?$'; then
            printf '        형식 위반: %s\n' "$rule"
            bad=$((bad + 1))
        fi
    done < <(settings_rules)

    if [[ $bad -gt 0 ]]; then
        log_fail "규칙 형식 위반 ${bad}건 (Tool 또는 Tool(specifier) 이어야 함)"
    else
        log_pass "규칙 형식 전부 유효"
    fi
}

check_invalid_pattern() {
    section "2. 무시되는 패턴 사용 여부"
    # 공식 문서: Bash(command:...) 같은 primary content field 매칭은 Claude Code 가
    # 무시하고 startup warning 을 낸다. 즉 "설정했지만 아무것도 막지 않는" 상태다.
    local hits
    hits=$(settings_rules | grep -cE $'\t'"(Bash|PowerShell)\(command:" || true)
    local hits2
    hits2=$(settings_rules | grep -cE $'\t'"(Read|Edit|Write)\(file_path:|Grep\(path:|WebFetch\(url:" || true)
    local total=$((hits + hits2))
    if [[ $total -gt 0 ]]; then
        settings_rules | grep -E $'\t'"(Bash|PowerShell)\(command:|(Read|Edit|Write)\(file_path:|Grep\(path:|WebFetch\(url:" \
          | sed 's/^/        /'
        log_fail "런타임이 무시하는 지정자 ${total}건 — 강제되는 것처럼 보이지만 아무것도 막지 않는다"
    else
        log_pass "무시되는 지정자 0건"
    fi
}

check_overlap() {
    section "3. deny / ask 중복"
    local dup
    dup=$(settings_rules | awk -F'\t' '{print $2}' | sort | uniq -d)
    if [[ -n "$dup" ]]; then
        printf '%s\n' "$dup" | sed 's/^/        /'
        log_fail "deny 와 ask 에 동시 등재된 규칙이 있다 (deny 가 이기므로 ask 는 죽은 선언)"
    else
        log_pass "중복 0건"
    fi
}

check_drift() {
    section "4. settings.json <-> user-approval.md 양방향 드리프트"
    local only_settings only_doc
    only_settings=$(comm -23 <(settings_rules | sort) <(doc_rules | sort))
    only_doc=$(comm -13 <(settings_rules | sort) <(doc_rules | sort))

    if [[ -n "$only_settings" ]]; then
        printf '        settings.json 에만 있음 (문서 미기재):\n'
        printf '%s\n' "$only_settings" | sed 's/^/          /'
    fi
    if [[ -n "$only_doc" ]]; then
        printf '        user-approval.md 에만 있음 (강제 안 됨):\n'
        printf '%s\n' "$only_doc" | sed 's/^/          /'
    fi

    if [[ -n "$only_settings" || -n "$only_doc" ]]; then
        log_fail "규칙 드리프트 — 양쪽을 같은 커밋에서 고칠 것"
    else
        local n
        n=$(settings_rules | wc -l | tr -d ' ')
        log_pass "규칙 ${n}건 양방향 일치"
    fi
}

check_min_count() {
    section "5. 최소 규칙 개수"
    local n
    n=$(settings_rules | wc -l | tr -d ' ')
    if [[ "$n" -lt "$MIN_RULE_COUNT" ]]; then
        log_fail "규칙 ${n}건 — 하한 ${MIN_RULE_COUNT}건 미달. 강제력이 축소·삭제됐는지 확인할 것"
        printf '        의도한 축소라면 %s 의 MIN_RULE_COUNT 를 함께 낮춘다.\n' "$0"
    else
        log_pass "규칙 ${n}건 (하한 ${MIN_RULE_COUNT})"
    fi
}

main() {
    require_files
    local target="${1:-all}"
    case "$target" in
        syntax)  check_syntax ;;
        invalid) check_invalid_pattern ;;
        overlap) check_overlap ;;
        drift)   check_drift ;;
        count)   check_min_count ;;
        all)
            check_syntax
            check_invalid_pattern
            check_overlap
            check_drift
            check_min_count
            ;;
        *)
            printf 'Usage: %s [syntax|invalid|overlap|drift|count|all]\n' "$0" >&2
            exit 2
            ;;
    esac

    printf '\n'
    if [[ $EXIT_CODE -eq 0 ]]; then
        printf 'OK  enforcement 규칙 검증 통과\n'
    else
        printf 'NG  실패: %s\n' "${FAILED_CHECKS[*]}"
    fi
    exit $EXIT_CODE
}

main "$@"
