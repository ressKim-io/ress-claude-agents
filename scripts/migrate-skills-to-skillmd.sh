#!/usr/bin/env bash
# .claude/skills/<category>/<name>.md  ->  .claude/skills/<name>/SKILL.md
#
# 배경:
#   Claude Code 는 `.claude/skills/<skill-name>/SKILL.md` (한 단계 디렉토리 + SKILL.md)
#   만 로드한다. 카테고리 하위 디렉토리는 지원하지 않는다.
#   기존 `<category>/<name>.md` 레이아웃은 규격을 벗어나 로드되지 않았다.
#   근거: docs/audit/2026-08-24-agent-harness-readiness.md (F1 / F2)
#
#   카테고리 정보는 디렉토리에서 사라지므로 frontmatter `category:` 로 보존한다.
#   plugins/*.yml, .claude/workflows/*.yml 의 카테고리 참조는 그대로 두고,
#   install.sh 가 frontmatter 를 읽어 해석한다.
#
# 사용:
#   ./scripts/migrate-skills-to-skillmd.sh --list              # 카테고리 목록
#   ./scripts/migrate-skills-to-skillmd.sh go                  # dry-run (기본)
#   ./scripts/migrate-skills-to-skillmd.sh go --apply          # 실제 이동
#   ./scripts/migrate-skills-to-skillmd.sh --skill go/effective-go --apply
#   ./scripts/migrate-skills-to-skillmd.sh --all --apply
#
# 안전:
#   - 기본 dry-run. --apply 없이는 아무것도 바꾸지 않는다
#   - git mv 사용 (rename 추적 → diff 가 작고 되돌리기 쉽다)
#   - 대상이 이미 존재하면 skip (idempotent)
#   - bash 3.2 호환 (연관 배열 / mapfile 미사용)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKILLS_DIR=".claude/skills"
APPLY=false
TARGET=""
MODE=""

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY=true ;;
        --all)   MODE="all" ;;
        --list)  MODE="list" ;;
        --skill) MODE="skill"; TARGET="${2:-}"; shift ;;
        -h|--help) usage 0 ;;
        -*) printf 'unknown flag: %s\n' "$1" >&2; usage 1 ;;
        *)  MODE="category"; TARGET="$1" ;;
    esac
    shift
done

[[ -n "$MODE" ]] || usage 1

# --- 카테고리 목록 ---------------------------------------------------------
if [[ "$MODE" == "list" ]]; then
    find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r d; do
        n=$(find "$d" -maxdepth 1 -name "*.md" -type f | wc -l | tr -d ' ')
        [[ "$n" == "0" ]] && continue
        printf '%-18s %s\n' "$(basename "$d")" "$n"
    done
    exit 0
fi

# --- frontmatter 에 category: 삽입 -----------------------------------------
# name: 줄 바로 뒤에 넣는다. 이미 있으면 건드리지 않는다.
insert_category() {
    local file="$1" cat="$2"
    CATEGORY_VALUE="$cat" python3 - "$file" <<'PY'
import io, os, sys
path = sys.argv[1]
cat = os.environ["CATEGORY_VALUE"]
lines = io.open(path, encoding="utf-8").read().split("\n")

if not lines or lines[0].strip() != "---":
    sys.exit("no frontmatter: " + path)

try:
    end = lines.index("---", 1)
except ValueError:
    sys.exit("unterminated frontmatter: " + path)

for i in range(1, end):
    if lines[i].startswith("category:"):
        sys.exit(0)                      # 이미 있음 — 그대로 둔다

anchor = end                             # name: 이 없으면 frontmatter 끝에
for i in range(1, end):
    if lines[i].startswith("name:"):
        anchor = i + 1
        break

lines.insert(anchor, "category: " + cat)
io.open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
}

# --- 파일 1개 이동 ---------------------------------------------------------
migrate_one() {
    local src="$1"
    local cat name dest_dir dest
    cat=$(basename "$(dirname "$src")")
    name=$(basename "$src" .md)
    dest_dir="$SKILLS_DIR/$name"
    dest="$dest_dir/SKILL.md"

    if [[ -f "$dest" ]]; then
        printf '  SKIP  %-40s (대상 존재)\n' "$name"
        return 0
    fi

    if [[ "$APPLY" != true ]]; then
        printf '  PLAN  %s/%s.md -> %s  (category: %s)\n' "$cat" "$name" "$dest" "$cat"
        return 0
    fi

    mkdir -p "$dest_dir"
    git mv "$src" "$dest"
    insert_category "$dest" "$cat"
    git add "$dest"
    printf '  MOVE  %-40s category=%s\n' "$name" "$cat"
}

# --- 실행 ------------------------------------------------------------------
case "$MODE" in
    skill)
        src="$SKILLS_DIR/$TARGET.md"
        [[ -f "$src" ]] || { printf 'not found: %s\n' "$src" >&2; exit 1; }
        migrate_one "$src"
        ;;
    category)
        cat_dir="$SKILLS_DIR/$TARGET"
        [[ -d "$cat_dir" ]] || { printf 'category not found: %s\n' "$cat_dir" >&2; exit 1; }
        printf '=== %s ===\n' "$TARGET"
        find "$cat_dir" -maxdepth 1 -name "*.md" -type f | sort | while read -r f; do
            migrate_one "$f"
        done
        # 빈 카테고리 디렉토리 정리
        if [[ "$APPLY" == true ]] && [[ -d "$cat_dir" ]]; then
            rmdir "$cat_dir" 2>/dev/null && printf '  RMDIR %s\n' "$cat_dir"
        fi
        ;;
    all)
        find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name "*.md" -type f | sort | while read -r f; do
            migrate_one "$f"
        done
        ;;
esac

if [[ "$APPLY" != true ]]; then
    printf '\n(dry-run — 실제로 적용하려면 --apply)\n'
fi
