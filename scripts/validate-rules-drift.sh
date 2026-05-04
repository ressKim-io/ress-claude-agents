#!/usr/bin/env bash
# AGENTS.md <-> .claude/rules/ drift 자동 검증
#
# 검증 항목:
#   1. model-ids   : Phase D 마커 — 구 모델 ID 잔존 0건 (claude-3-*, claude-*-4-2025*)
#   2. refs        : AGENTS.md <-> .claude/rules/ 양방향 참조 무결성
#   3. consistency : Critical 룰 키워드 양쪽 존재 일관성
#   4. sweet-spot  : Rules 200줄 이내 권장 (경고)
#
# 사용:
#   ./scripts/validate-rules-drift.sh             # 전체 (CI 기본)
#   ./scripts/validate-rules-drift.sh model-ids   # 모델 ID만
#   ./scripts/validate-rules-drift.sh refs
#   ./scripts/validate-rules-drift.sh consistency
#   ./scripts/validate-rules-drift.sh sweet-spot
#
# Exit code: 0 = 통과, 1 = 실패. sweet-spot은 경고만 (실패 처리 X).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXIT_CODE=0
FAILED_CHECKS=()

log_pass() { printf '  PASS  %s\n' "$1"; }
log_fail() { printf '  FAIL  %s\n' "$1"; EXIT_CODE=1; FAILED_CHECKS+=("$1"); }
log_warn() { printf '  WARN  %s\n' "$1"; }
section()  { printf '\n=== %s ===\n' "$1"; }

# ---------------------------------------------------------------------------
# Check 1: 모델 ID drift (Phase D 마커)
# ---------------------------------------------------------------------------
# 잡고자 하는 패턴 (드리프트):
#   - claude-3-(opus|sonnet|haiku)        : 3.x 시대 ID
#   - claude-(opus|sonnet|haiku)-3...     : 3-suffix 형식 (claude-haiku-3-20250522 등)
#   - claude-(opus|sonnet|haiku)-4-2025   : 4.x 초기 dated 모델 (4.5 GA 이전)
#
# 정상 (4.5 / 4.6 / 4.7 표기, 또는 dated 없는 4):
#   - claude-opus-4-7, claude-sonnet-4-6, claude-haiku-4-5
#
# 검증 대상: .claude/ 활성 자산 + AGENTS.md + CLAUDE.md
check_model_id_drift() {
    section "Phase D 마커: 모델 ID drift 검증"

    local pattern='claude-(3-(opus|sonnet|haiku)|(opus|sonnet|haiku)-(3|4-2025))'
    local matches
    if matches=$(grep -rEn "$pattern" .claude/ AGENTS.md CLAUDE.md 2>/dev/null); then
        local count
        count=$(printf '%s\n' "$matches" | wc -l | tr -d ' ')
        log_fail "구 모델 ID 잔존: ${count}건"
        printf '%s\n' "$matches" | sed 's/^/        /'
    else
        log_pass "모델 ID drift = 0건"
    fi
}

# ---------------------------------------------------------------------------
# Check 2: 양방향 참조 무결성
# ---------------------------------------------------------------------------
check_agents_md_references() {
    section "AGENTS.md -> .claude/rules/ 링크 유효성"

    local missing=()
    while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        if [[ ! -f "$ref" ]]; then
            missing+=("$ref")
        fi
    done < <(grep -oE '\.claude/rules/[a-z-]+\.md' AGENTS.md CLAUDE.md 2>/dev/null | awk -F: '{print $NF}' | sort -u)

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_fail "AGENTS.md/CLAUDE.md 링크 누락: ${#missing[@]}건"
        for f in "${missing[@]}"; do
            printf '        %s\n' "$f"
        done
    else
        log_pass "AGENTS.md/CLAUDE.md -> rules 링크 전부 유효"
    fi
}

check_rules_back_referenced() {
    section ".claude/rules/ -> AGENTS.md/CLAUDE.md 역참조"

    local unreferenced=()
    while IFS= read -r rule; do
        local base
        base=$(basename "$rule")
        if ! grep -qE "(\.claude/rules/)?${base}|${base%.md}\.md" AGENTS.md CLAUDE.md 2>/dev/null; then
            unreferenced+=("$rule")
        fi
    done < <(find .claude/rules -type f -name "*.md" | sort)

    if [[ ${#unreferenced[@]} -gt 0 ]]; then
        log_fail "AGENTS.md/CLAUDE.md에 미참조 rules: ${#unreferenced[@]}건"
        for f in "${unreferenced[@]}"; do
            printf '        %s\n' "$f"
        done
    else
        log_pass "모든 rules가 AGENTS.md/CLAUDE.md에서 참조됨"
    fi
}

# ---------------------------------------------------------------------------
# Check 3: Critical 룰 양쪽 일관성
# ---------------------------------------------------------------------------
# 형식: "정규식 키워드|rule 파일|설명"
# AGENTS.md와 해당 rule 파일 양쪽에 모두 존재해야 한다.
CRITICAL_RULES=(
    "하드코딩|security.md|시크릿 하드코딩 금지"
    "bcrypt|security.md|비밀번호 해시 알고리즘"
    "PreparedStatement|security.md|SQL injection 방지"
    "Conventional Commits|git.md|커밋 형식"
    "force push|git.md|main 보호"
    "TDD|testing.md|테스트 우선 작성"
    "TestContainers|testing.md|실제 DB 통합 테스트"
    "EXPLORE|workflow.md|작업 순서"
    "kubectl|user-approval.md|K8s 직접 변경 금지"
    "ServerSideApply|user-approval.md|Force Sync 금지"
    "Conventional Commits|git.md|PR 제목 형식"
)

check_critical_rules_consistency() {
    section "Critical 룰 양쪽 존재 일관성"

    local mismatches=0
    local checked=0
    for entry in "${CRITICAL_RULES[@]}"; do
        local keyword="${entry%%|*}"
        local rest="${entry#*|}"
        local rule_file="${rest%%|*}"
        local desc="${rest#*|}"
        local rule_path=".claude/rules/${rule_file}"
        checked=$((checked + 1))

        local in_agents=0 in_rule=0
        grep -qE "$keyword" AGENTS.md 2>/dev/null && in_agents=1
        [[ -f "$rule_path" ]] && grep -qE "$keyword" "$rule_path" 2>/dev/null && in_rule=1

        if [[ $in_agents -eq 0 && $in_rule -eq 1 ]]; then
            printf '        DRIFT  "%s" (%s) — rule 있음, AGENTS.md 누락\n' "$keyword" "$desc"
            mismatches=$((mismatches + 1))
        elif [[ $in_agents -eq 1 && $in_rule -eq 0 ]]; then
            printf '        DRIFT  "%s" (%s) — AGENTS.md 있음, rule(%s) 누락\n' "$keyword" "$desc" "$rule_file"
            mismatches=$((mismatches + 1))
        elif [[ $in_agents -eq 0 && $in_rule -eq 0 ]]; then
            printf '        MISSING  "%s" (%s) — 양쪽 모두 누락\n' "$keyword" "$desc"
            mismatches=$((mismatches + 1))
        fi
    done

    if [[ $mismatches -gt 0 ]]; then
        log_fail "Critical 룰 일관성 위반: ${mismatches}/${checked}건"
    else
        log_pass "Critical 룰 양쪽 일관성 OK (${checked}/${checked} 키워드)"
    fi
}

# ---------------------------------------------------------------------------
# Check 4: Rules sweet spot (≤ 200줄)
# ---------------------------------------------------------------------------
# Opus 4.7 기준: rules는 매 대화 자동 로딩 → 길면 묻힘. sweet spot 100~150,
# 200줄까지 허용. 초과 시 경고만 (실패 처리 X) — cloud-cli-safety처럼
# 활성화 항목 누적이 의도된 케이스가 있어서.
check_rules_length_sweet_spot() {
    section "Rules sweet spot (<= 200줄, 경고만)"

    local violations=()
    while IFS= read -r rule; do
        local lines
        lines=$(wc -l < "$rule" | tr -d ' ')
        if [[ $lines -gt 200 ]]; then
            violations+=("${rule}:${lines}")
        fi
    done < <(find .claude/rules -type f -name "*.md" | sort)

    if [[ ${#violations[@]} -gt 0 ]]; then
        log_warn "Sweet spot 초과: ${#violations[@]}개 (rules는 매 대화 자동 로딩)"
        for v in "${violations[@]}"; do
            printf '        %s줄  %s\n' "${v##*:}" "${v%:*}"
        done
    else
        log_pass "모든 rules sweet spot 통과 (<= 200줄)"
    fi
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
main() {
    case "${1:-all}" in
        model-ids)
            check_model_id_drift
            ;;
        refs)
            check_agents_md_references
            check_rules_back_referenced
            ;;
        consistency)
            check_critical_rules_consistency
            ;;
        sweet-spot)
            check_rules_length_sweet_spot
            ;;
        all)
            check_model_id_drift
            check_agents_md_references
            check_rules_back_referenced
            check_critical_rules_consistency
            check_rules_length_sweet_spot
            ;;
        -h|--help|help)
            sed -n '2,18p' "$0"
            exit 0
            ;;
        *)
            printf 'unknown command: %s\n사용법: %s [all|model-ids|refs|consistency|sweet-spot]\n' "$1" "$0" >&2
            exit 2
            ;;
    esac

    echo ""
    if [[ $EXIT_CODE -eq 0 ]]; then
        printf 'OK  drift lint 검증 통과\n'
    else
        printf 'FAIL  %d개 검증 실패:\n' "${#FAILED_CHECKS[@]}"
        for f in "${FAILED_CHECKS[@]}"; do
            printf '  - %s\n' "$f"
        done
    fi

    exit $EXIT_CODE
}

main "$@"
