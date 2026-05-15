#!/usr/bin/env bash
# add-skill-frontmatter.sh
#
# 미보유 skill 에 frontmatter 골격 추가 (Phase B 자동화 step 1).
# description 은 H1 + 본문 첫 단락 기반 자동 추출. SKILL-SPEC.md 의 "Use when X" 패턴은
# 별도 정밀화 step 2 에서 subagent fan-out 으로 보강.
#
# 사용:
#   ./scripts/add-skill-frontmatter.sh           # 일괄 적용
#   ./scripts/add-skill-frontmatter.sh --dry-run # 미리보기만
#
# Frontmatter 형식 (SKILL-SPEC.md 따름):
#   ---
#   name: skill-slug
#   description: "[H1] — [본문 첫 단락]. Use when working with [category] 도메인."
#   effort: xhigh | low | max (카테고리 default per effort-guide.md)
#   deprecated: false
#   ---

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$ROOT/.claude/skills"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# 카테고리 default effort (effort-guide.md §Skills 매핑)
default_effort() {
    case "$1" in
        dx) echo "low" ;;
        migration) echo "max" ;;
        *) echo "xhigh" ;;
    esac
}

# H1 추출 (첫 # 시작 라인). multi-byte safe.
extract_h1() {
    awk '
        /^# / {
            sub(/^# */, "")
            gsub(/"/, "\047")
            if (length($0) > 200) $0 = substr($0, 1, 200)
            print
            exit
        }
    ' "$1"
}

# H1 직후 첫 의미있는 단락 (비어있지 않은 첫 라인). multi-byte safe.
extract_first_para() {
    awk '
        /^# / { found=1; next }
        found && /^[[:space:]]*$/ { next }
        found && /^[^#`]/ {
            gsub(/"/, "\047")
            gsub(/  +/, " ")
            sub(/^[[:space:]]+/, "")
            sub(/[[:space:]]+$/, "")
            # 150 byte 제한 + 단어 경계에서 안전 cut (한글 3-byte 중간 깨짐 회피)
            if (length($0) > 150) {
                $0 = substr($0, 1, 150)
                # 마지막 단어 끝까지만 (공백 기준)
                sub(/[^ ]*$/, "", $0)
                sub(/[[:space:]]+$/, "", $0)
            }
            print
            exit
        }
    ' "$1"
}

# description 조립
build_description() {
    local h1="$1"
    local para="$2"
    local category="$3"

    if [[ -z "$h1" ]]; then
        h1="$category skill"
    fi

    if [[ -n "$para" ]]; then
        echo "$h1 — $para Use when working with $category 도메인의 패턴 / 구현 선택."
    else
        echo "$h1. Use when working with $category 도메인의 패턴 / 구현 선택."
    fi
}

ADDED=0
SKIPPED=0
FAILED=0

while IFS= read -r file; do
    rel="${file#"$SKILLS_DIR"/}"

    # frontmatter 있으면 skip
    if [[ "$(head -1 "$file" 2>/dev/null)" == "---" ]]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # 카테고리 = 첫 디렉토리
    category="${rel%%/*}"
    if [[ "$category" == "$rel" ]]; then
        category="root"  # flat 파일 (없어야 함)
    fi

    # name = 파일명 (확장자 제외)
    name=$(basename "$file" .md)

    # H1 + 첫 단락
    h1=$(extract_h1 "$file")
    para=$(extract_first_para "$file")

    effort=$(default_effort "$category")
    description=$(build_description "$h1" "$para" "$category")

    if $DRY_RUN; then
        printf '[DRY] %s\n  effort: %s\n  description: "%s"\n\n' "$rel" "$effort" "$description"
        ADDED=$((ADDED + 1))
        continue
    fi

    # frontmatter 추가
    {
        echo "---"
        echo "name: $name"
        echo "description: \"$description\""
        echo "effort: $effort"
        echo "deprecated: false"
        echo "---"
        echo ""
        cat "$file"
    } > "$file.tmp"

    if mv "$file.tmp" "$file"; then
        ADDED=$((ADDED + 1))
        printf 'Added: %s (effort=%s)\n' "$rel" "$effort"
    else
        FAILED=$((FAILED + 1))
        printf 'FAILED: %s\n' "$rel" >&2
    fi
done < <(find "$SKILLS_DIR" -type f -name '*.md' -not -name 'SKILL.md' | sort)

echo ""
echo "=== Summary ==="
if $DRY_RUN; then
    echo "DRY-RUN — would add frontmatter to $ADDED skills (already had: $SKIPPED)"
else
    echo "Added frontmatter to $ADDED skills"
    echo "Skipped (already had frontmatter): $SKIPPED"
    echo "Failed: $FAILED"
fi
