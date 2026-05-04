#!/usr/bin/env bash
# Agent handoff 정의 검증
#
# 검증 항목:
#   1. agents     : .claude/agents/_handoff.yml에 모든 agent가 등록됐는지
#                   (실제 .md 파일과 매핑 일치)
#   2. vocabulary : agent의 produces/consumes에 정의되지 않은 artifact 사용 금지
#   3. workflows  : type=handoff-flow 워크플로우의 stage 핸드오프가 valid한지
#                   (각 stage의 inputs는 (a) 직전 stages의 outputs 합집합 또는
#                    (b) external 입력에 포함되어야 한다)
#
# 사용:
#   ./scripts/validate-agent-handoff.sh             # 전체 검증
#   ./scripts/validate-agent-handoff.sh agents
#   ./scripts/validate-agent-handoff.sh vocabulary
#   ./scripts/validate-agent-handoff.sh workflows
#
# 의존성: 표준 grep/sed/awk만 사용 (yq 없이도 동작)
# Exit code: 0 통과, 1 실패

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HANDOFF_FILE=".claude/agents/_handoff.yml"
WORKFLOWS_DIR=".claude/workflows"

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

# workflow 파일의 stage 정보 추출
# get_workflow_stages <workflow-file>
# 출력: <stage_name>|<inputs comma>|<outputs comma>
get_workflow_stages() {
    local file="$1"
    awk '
        /^  - name:/ {
            if (stage != "") {
                print stage "|" inputs "|" outputs
            }
            stage = $3
            inputs = ""
            outputs = ""
            next
        }
        /^    inputs:/ {
            line = $0; sub(/.*\[/, "", line); sub(/\].*/, "", line)
            gsub(/, */, ",", line); gsub(/^[ \t]+|[ \t]+$/, "", line)
            inputs = line
        }
        /^    outputs:/ {
            line = $0; sub(/.*\[/, "", line); sub(/\].*/, "", line)
            gsub(/, */, ",", line); gsub(/^[ \t]+|[ \t]+$/, "", line)
            outputs = line
        }
        END {
            if (stage != "") print stage "|" inputs "|" outputs
        }
    ' "$file"
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
# Check 3: workflow 핸드오프 검증
# ---------------------------------------------------------------------------

# workflow 파일에서 external_inputs 필드 추출
get_workflow_external_inputs() {
    local file="$1"
    awk '
        /^external_inputs:/ {
            line = $0; sub(/.*\[/, "", line); sub(/\].*/, "", line)
            gsub(/, */, "\n", line); gsub(/^[ \t]+|[ \t]+$/, "", line)
            print line
            exit
        }
    ' "$file"
}

check_workflow() {
    local file="$1"
    local wf_name violations
    wf_name=$(grep -m1 '^name:' "$file" | sed 's/^name: *//')
    violations=0

    # type=handoff-flow가 아니면 skip
    if ! grep -q "^type: handoff-flow" "$file"; then
        return 0
    fi

    printf '  → %s\n' "$wf_name"

    # workflow 자체 external_inputs (없으면 빈 set)
    local wf_externals
    wf_externals=$(get_workflow_external_inputs "$file")

    local stages_data
    stages_data=$(get_workflow_stages "$file")

    # 누적 outputs (지금까지 어떤 artifact가 생성됐는지)
    local cumulative_outputs=""

    while IFS='|' read -r stage inputs outputs; do
        [[ -z "$stage" ]] && continue

        # inputs 검증
        IFS=',' read -ra in_arr <<< "$inputs"
        for inp in "${in_arr[@]}"; do
            inp=$(echo "$inp" | sed 's/^ *//; s/ *$//')
            [[ -z "$inp" ]] && continue
            # workflow의 external_inputs에 포함?
            if [[ -n "$wf_externals" ]] && grep -qxF "$inp" <<< "$wf_externals"; then
                continue
            fi
            # 누적 outputs에 포함?
            if grep -qxF "$inp" <<< "$cumulative_outputs"; then
                continue
            fi
            printf '        FAIL  stage "%s" input "%s" external_inputs 또는 이전 stage outputs에 없음\n' \
                "$stage" "$inp"
            violations=$((violations + 1))
        done

        # outputs 누적
        IFS=',' read -ra out_arr <<< "$outputs"
        for out in "${out_arr[@]}"; do
            out=$(echo "$out" | sed 's/^ *//; s/ *$//')
            [[ -z "$out" ]] && continue
            cumulative_outputs+="${out}"$'\n'
        done
    done <<< "$stages_data"

    if [[ $violations -gt 0 ]]; then
        log_fail "$wf_name: ${violations}건 핸드오프 위반"
    else
        log_pass "$wf_name 핸드오프 valid"
    fi
}

check_workflows() {
    section "Workflow 핸드오프 (type=handoff-flow)"

    local found=0
    while IFS= read -r wf; do
        check_workflow "$wf"
        found=$((found + 1))
    done < <(grep -lE "^type: handoff-flow$" "$WORKFLOWS_DIR"/*.yml 2>/dev/null)

    if [[ $found -eq 0 ]]; then
        printf '  INFO  handoff-flow 워크플로우 없음\n'
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
        workflows)
            check_workflows
            ;;
        all)
            check_agents_registered
            check_vocabulary
            check_workflows
            ;;
        -h|--help|help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *)
            printf 'unknown: %s\n사용법: %s [all|agents|vocabulary|workflows]\n' "$1" "$0" >&2
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
