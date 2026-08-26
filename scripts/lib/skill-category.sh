#!/usr/bin/env bash
# skill 의 frontmatter category 파서 — 단일 구현.
#
# 왜 공유하는가: 이 파서가 install.sh / validate-skill-frontmatter.sh /
# generate-inventory.sh / generate-inventory-labels.sh 에 4벌 복사돼 있었고,
# 그중 둘은 `n>=2{exit}` early-exit 이 빠져 **본문의 `category:` 줄까지 읽었다**.
# 그 결과 validator 가 install.sh 는 해석하지 못하는 phantom 카테고리
# (`payment` / `reactive`)를 유효한 것으로 통과시켰다 — 2026-08-26 PR #36 리뷰.
#
# 사용: source "$(dirname "$0")/lib/skill-category.sh"; skill_frontmatter_category <file>

# frontmatter(첫 `---` ~ 두 번째 `---`) 안의 category: 만 읽는다.
# 본문에 등장하는 category: 줄은 n>=2 로 잘라내 무시한다.
skill_frontmatter_category() {
    awk '
      /^---$/ { n++; next }
      n == 1 && /^category:/ { sub(/^category: *"?/, ""); sub(/"$/, ""); print; exit }
      n >= 2 { exit }
    ' "$1"
}

# 디렉터리 아래 모든 SKILL.md 를 한 번만 훑어 "<name><TAB><category>" 로 출력.
# 카테고리별로 재파싱하는 O(카테고리 × 스킬) 패턴을 피하려는 용도.
skill_category_map() {
    local root="$1" skill_md name cat
    for skill_md in "$root"/*/SKILL.md; do
        [ -f "$skill_md" ] || continue
        name=$(basename "$(dirname "$skill_md")")
        cat=$(skill_frontmatter_category "$skill_md")
        printf '%s\t%s\n' "$name" "$cat"
    done
}
