#!/usr/bin/env bash
# SKILL.md / Agent frontmatter 검증
#
# 검증 대상:
#   - .claude/agents/*.md      : 모든 agent는 frontmatter 필수 (현재 95% 보유)
#   - .claude/skills/**/*.md   : frontmatter 있으면 형식 검증, 없으면 우리 컨벤션 검증
#
# Frontmatter 표준 (Anthropic SKILL.md):
#   ---
#   name: skill-name             # 필수, 파일명(.md 제외)과 일치 권장
#   description: "..."           # 필수, 비어있지 않음
#   model: "..."                 # 선택 (agents only)
#   tools: [...]                 # 선택 (agents only)
#   ---
#
# 우리 컨벤션 (frontmatter 없는 skills):
#   # 제목
#
#   description 단락
#
# 사용:
#   ./scripts/validate-skill-frontmatter.sh             # 전체
#   ./scripts/validate-skill-frontmatter.sh agents      # agents만
#   ./scripts/validate-skill-frontmatter.sh skills      # skills만
#   ./scripts/validate-skill-frontmatter.sh report      # 통계만
#
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
# Frontmatter 파싱: 첫 줄이 ^---$인 경우 frontmatter 추출
# 출력: 0 = frontmatter 있음 (stdout에 본문 출력)
#       1 = frontmatter 없음
# ---------------------------------------------------------------------------
extract_frontmatter() {
    local file="$1"
    if [[ "$(head -1 "$file")" != "---" ]]; then
        return 1
    fi
    # 두 번째 ---까지 (시작 라인 1 다음부터)
    awk 'NR==1 && /^---$/ {flag=1; next} flag && /^---$/ {exit} flag' "$file"
    return 0
}

# Frontmatter에서 특정 필드 값 추출
# yq 없이 단순 파싱 — name: value, description: "value" 형식만 지원
get_field() {
    local frontmatter="$1"
    local field="$2"
    printf '%s\n' "$frontmatter" | awk -v f="$field" '
        $0 ~ "^"f": " {
            sub("^"f": *", "")
            sub(/^"/, "")
            sub(/"$/, "")
            print
            exit
        }
    '
}

# ---------------------------------------------------------------------------
# Agent 검증: frontmatter 필수
# ---------------------------------------------------------------------------
validate_agent() {
    local file="$1"
    local issues=()

    local frontmatter
    if ! frontmatter=$(extract_frontmatter "$file"); then
        issues+=("frontmatter 없음")
        printf '%s\n' "${issues[@]}"
        return 1
    fi

    local name desc
    name=$(get_field "$frontmatter" "name")
    desc=$(get_field "$frontmatter" "description")

    [[ -z "$name" ]] && issues+=("name 필드 누락")
    [[ -z "$desc" ]] && issues+=("description 필드 누락")

    # name이 파일명과 일치하는지 (확장자 제외)
    local expected
    expected=$(basename "$file" .md)
    if [[ -n "$name" && "$name" != "$expected" ]]; then
        issues+=("name='$name' != 파일명 '$expected'")
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
        printf '%s\n' "${issues[@]}"
        return 1
    fi
    return 0
}

check_agents() {
    section "Agents (.claude/agents/) frontmatter 검증"

    local total=0 pass=0 fail=0
    local violations=()

    while IFS= read -r file; do
        total=$((total + 1))
        local issues
        if issues=$(validate_agent "$file"); then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
            violations+=("$file|$issues")
        fi
    done < <(find .claude/agents -type f -name "*.md" | sort)

    if [[ $fail -gt 0 ]]; then
        log_fail "Agents: ${fail}/${total} 위반"
        for v in "${violations[@]}"; do
            local f="${v%%|*}"
            local i="${v#*|}"
            printf '        %s\n' "$f"
            printf '%s\n' "$i" | sed 's/^/          - /'
        done
    else
        log_pass "Agents: ${pass}/${total} frontmatter OK"
    fi
}

# ---------------------------------------------------------------------------
# Skill 검증: frontmatter 있으면 형식 검증, 없으면 우리 컨벤션 검증
# ---------------------------------------------------------------------------
validate_skill() {
    local file="$1"
    local issues=()
    local frontmatter

    if frontmatter=$(extract_frontmatter "$file"); then
        # frontmatter 모드
        local name desc
        name=$(get_field "$frontmatter" "name")
        desc=$(get_field "$frontmatter" "description")

        [[ -z "$name" ]] && issues+=("frontmatter: name 누락")
        [[ -z "$desc" ]] && issues+=("frontmatter: description 누락")

        local expected
        expected=$(basename "$file" .md)
        if [[ -n "$name" && "$name" != "$expected" ]]; then
            issues+=("frontmatter: name='$name' != 파일명 '$expected'")
        fi
    else
        # 컨벤션 모드: H1 + description 단락
        local first_line
        first_line=$(head -1 "$file")
        if [[ ! "$first_line" =~ ^"#"\ .+ ]]; then
            issues+=("convention: H1 제목(# ...) 누락 (첫 줄: '${first_line:0:50}')")
        fi

        # 2~5번째 줄에 비어있지 않은 description 단락이 있는지
        local has_desc=0
        while IFS= read -r line; do
            [[ -n "$line" && ! "$line" =~ ^"#" ]] && has_desc=1 && break
        done < <(sed -n '2,8p' "$file")
        [[ $has_desc -eq 0 ]] && issues+=("convention: description 단락 누락 (2~8행)")
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
        printf '%s\n' "${issues[@]}"
        return 1
    fi
    return 0
}

check_skills() {
    section "Skills (.claude/skills/) 형식 검증"

    local total=0 pass=0 fail=0
    local with_fm=0 without_fm=0
    local violations=()

    while IFS= read -r file; do
        total=$((total + 1))
        if [[ "$(head -1 "$file")" == "---" ]]; then
            with_fm=$((with_fm + 1))
        else
            without_fm=$((without_fm + 1))
        fi

        local issues
        if issues=$(validate_skill "$file"); then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
            violations+=("$file|$issues")
        fi
    done < <(find .claude/skills -type f -name "*.md" | sort)

    printf '  통계  total=%d  frontmatter=%d  convention=%d\n' "$total" "$with_fm" "$without_fm"

    if [[ $fail -gt 0 ]]; then
        log_fail "Skills: ${fail}/${total} 위반"
        for v in "${violations[@]}"; do
            local f="${v%%|*}"
            local i="${v#*|}"
            printf '        %s\n' "$f"
            printf '%s\n' "$i" | sed 's/^/          - /'
        done
    else
        log_pass "Skills: ${pass}/${total} 형식 OK"
    fi
}

# ---------------------------------------------------------------------------
# 통계 리포트 (마이그레이션 의사결정용)
# ---------------------------------------------------------------------------
report_stats() {
    section "Frontmatter 채택 현황"

    local agents_total agents_fm
    agents_total=$(find .claude/agents -type f -name "*.md" | wc -l | tr -d ' ')
    agents_fm=0
    while IFS= read -r f; do
        [[ "$(head -1 "$f")" == "---" ]] && agents_fm=$((agents_fm + 1))
    done < <(find .claude/agents -type f -name "*.md")

    local skills_total skills_fm
    skills_total=$(find .claude/skills -type f -name "*.md" | wc -l | tr -d ' ')
    skills_fm=0
    while IFS= read -r f; do
        [[ "$(head -1 "$f")" == "---" ]] && skills_fm=$((skills_fm + 1))
    done < <(find .claude/skills -type f -name "*.md")

    printf '  Agents  : %d/%d (%d%%)\n' "$agents_fm" "$agents_total" $((agents_fm * 100 / agents_total))
    printf '  Skills  : %d/%d (%d%%)\n' "$skills_fm" "$skills_total" $((skills_fm * 100 / skills_total))

    section "Skills frontmatter 카테고리별 분포"
    while IFS= read -r dir; do
        local cat total fm
        cat=$(basename "$dir")
        total=0
        fm=0
        while IFS= read -r f; do
            total=$((total + 1))
            [[ "$(head -1 "$f")" == "---" ]] && fm=$((fm + 1))
        done < <(find "$dir" -type f -name "*.md")
        printf '  %-15s %d/%d\n' "$cat" "$fm" "$total"
    done < <(find .claude/skills -mindepth 1 -maxdepth 1 -type d | sort)
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
main() {
    case "${1:-all}" in
        agents)
            check_agents
            ;;
        skills)
            check_skills
            ;;
        report)
            report_stats
            exit 0
            ;;
        all)
            check_agents
            check_skills
            report_stats
            ;;
        -h|--help|help)
            sed -n '2,32p' "$0"
            exit 0
            ;;
        *)
            printf 'unknown: %s\n사용법: %s [all|agents|skills|report]\n' "$1" "$0" >&2
            exit 2
            ;;
    esac

    echo ""
    if [[ $EXIT_CODE -eq 0 ]]; then
        printf 'OK  frontmatter/convention 검증 통과\n'
    else
        printf 'FAIL  %d개 검증 실패\n' "${#FAILED[@]}"
    fi

    exit $EXIT_CODE
}

main "$@"
