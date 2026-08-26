#!/usr/bin/env bash
# Agent handoff 정의 검증
#
# 검증 항목:
#   1. agents     : .claude/agents/_handoff.yml에 모든 agent가 등록됐는지
#                   (실제 .md 파일과 매핑 일치)
#   2. vocabulary : agent의 produces/consumes에 정의되지 않은 artifact 사용 금지
#
# 제거 (2026-08-26): workflows / skill-refs 검증은 `.claude/workflows/` 와 `plugins/`
# 를 대상으로 했다. install.sh 제거와 함께 두 자산군이 사라져 검증 대상이 없다 (ADR 0011).
#
# 사용:
#   ./scripts/validate-agent-handoff.sh             # 전체 검증
#   ./scripts/validate-agent-handoff.sh agents
#   ./scripts/validate-agent-handoff.sh vocabulary
#
# 의존성: 표준 grep/sed/awk만 사용 (yq 없이도 동작)
# Exit code: 0 통과, 1 실패

set -euo pipefail

# frontmatter category 파서 (install.sh 와 단일 구현 공유)
# shellcheck source=scripts/lib/skill-category.sh
# shellcheck disable=SC1091
source "$(dirname "$0")/lib/skill-category.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HANDOFF_FILE=".claude/agents/_handoff.yml"

EXIT_CODE=0
FAILED=()

log_pass() { printf '  PASS  %s\n' "$1"; }
log_fail() { printf '  FAIL  %s\n' "$1"; EXIT_CODE=1; FAILED+=("$1"); }
section()  { printf '\n=== %s ===\n' "$1"; }

# ---------------------------------------------------------------------------
# YAML 파싱 헬퍼 (간단 grep/awk 기반)
# ---------------------------------------------------------------------------

# _handoff.yml에서 정의된 artifact 이름 추출
get_artifacts() {
    awk '
        /^artifacts:/ { in_section=1; next }
        in_section && /^[a-z]/ { in_section=0 }
        in_section && /^  [a-z][a-z0-9-]*:/ {
            name=$1; sub(/:$/, "", name); print name
        }
    ' "$HANDOFF_FILE"
}

# _handoff.yml에서 정의된 agent 이름 추출
get_handoff_agents() {
    awk '
        /^agents:/ { in_section=1; next }
        in_section && /^[a-z]/ { in_section=0 }
        in_section && /^  [a-z][a-z0-9-]*:$/ {
            name=$1; sub(/:$/, "", name); print name
        }
    ' "$HANDOFF_FILE"
}

# 특정 agent의 produces 또는 consumes 추출
# get_agent_field <agent-name> <produces|consumes>
get_agent_field() {
    local agent="$1"
    local field="$2"
    awk -v ag="  ${agent}:" -v f="    ${field}:" '
        $0 == ag { in_agent=1; next }
        in_agent && /^  [a-z]/ && $0 != ag { in_agent=0 }
        in_agent && index($0, f) == 1 {
            line=$0; sub(/.*\[/, "", line); sub(/\].*/, "", line)
            gsub(/, */, "\n", line); gsub(/^[ \t]+|[ \t]+$/, "", line)
            print line
        }
    ' "$HANDOFF_FILE"
}

# ---------------------------------------------------------------------------
# Check 1: 모든 agent가 _handoff.yml에 등록됐는지
# ---------------------------------------------------------------------------
check_agents_registered() {
    section "Agent registration (_handoff.yml ↔ .claude/agents/)"

    local actual_agents handoff_agents missing extra
    actual_agents=$(find .claude/agents -maxdepth 1 -type f -name "*.md" -exec basename {} .md \; | sort -u)
    handoff_agents=$(get_handoff_agents | sort -u)

    missing=$(comm -23 <(printf '%s\n' "$actual_agents") <(printf '%s\n' "$handoff_agents"))
    extra=$(comm -13 <(printf '%s\n' "$actual_agents") <(printf '%s\n' "$handoff_agents"))

    if [[ -n "$missing" ]]; then
        log_fail "_handoff.yml 미등록 agent ($(echo "$missing" | wc -l | tr -d ' ')개):"
        printf '%s\n' "$missing" | sed 's/^/        /'
    fi
    if [[ -n "$extra" ]]; then
        log_fail "_handoff.yml에는 있으나 실제 없는 agent ($(echo "$extra" | wc -l | tr -d ' ')개):"
        printf '%s\n' "$extra" | sed 's/^/        /'
    fi
    if [[ -z "$missing" && -z "$extra" ]]; then
        local count
        count=$(printf '%s\n' "$actual_agents" | wc -l | tr -d ' ')
        log_pass "${count}/${count} agent 모두 등록됨"
    fi
}

# ---------------------------------------------------------------------------
# Check 2: vocabulary 일관성
# ---------------------------------------------------------------------------
check_vocabulary() {
    section "Artifact vocabulary 일관성 (produces/consumes)"

    local artifacts
    artifacts=$(get_artifacts | sort -u)

    local violations=0
    while IFS= read -r agent; do
        [[ -z "$agent" ]] && continue
        local prod cons
        prod=$(get_agent_field "$agent" "produces" | sort -u)
        cons=$(get_agent_field "$agent" "consumes" | sort -u)

        # produces/consumes에 있는 모든 artifact가 vocabulary에 존재하는지
        for artifact in $prod $cons; do
            [[ -z "$artifact" ]] && continue
            if ! grep -qxF "$artifact" <<< "$artifacts"; then
                printf '        UNDEFINED  %s/%s ← vocabulary에 없음\n' "$agent" "$artifact"
                violations=$((violations + 1))
            fi
        done
    done < <(get_handoff_agents)

    if [[ $violations -gt 0 ]]; then
        log_fail "Vocabulary 위반: ${violations}건"
    else
        local artifact_count agent_count
        artifact_count=$(get_artifacts | wc -l | tr -d ' ')
        agent_count=$(get_handoff_agents | wc -l | tr -d ' ')
        log_pass "${agent_count} agents의 produces/consumes 모두 ${artifact_count}개 vocabulary 안에 있음"
    fi
}


# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
main() {
    case "${1:-all}" in
        agents)
            check_agents_registered
            ;;
        vocabulary)
            check_vocabulary
            ;;
        all)
            check_agents_registered
            check_vocabulary
            ;;
        -h|--help|help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *)
            printf 'unknown: %s\n사용법: %s [all|agents|vocabulary]\n' "$1" "$0" >&2
            exit 2
            ;;
    esac

    echo ""
    if [[ $EXIT_CODE -eq 0 ]]; then
        printf 'OK  agent handoff 검증 통과\n'
    else
        printf 'FAIL  %d개 검증 실패\n' "${#FAILED[@]}"
        for f in "${FAILED[@]}"; do
            printf '  - %s\n' "$f"
        done
    fi

    exit $EXIT_CODE
}

main "$@"
