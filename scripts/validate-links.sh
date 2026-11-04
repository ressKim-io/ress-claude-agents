#!/usr/bin/env bash
# 레포 내부 상대 링크의 유효성 검증.
#
# 배경: 2026-08-24 Step 2 가 skill 260개를 `.claude/skills/<cat>/<name>.md` 에서
# `.claude/skills/<name>/SKILL.md` 로 옮기면서 **상호 참조를 고치지 않았다**.
# 79개 링크가 깨진 채 3일간 남아 있었고, 그중 4개는 매 세션 로드되는 AGENTS.md
# 안에 있었다. 링크를 보는 CI job 이 하나도 없어 아무도 몰랐다 — PR #36 리뷰.
#
# 검증 범위: AGENTS.md / rules / skills / agents / commands / templates / plugin README /
#            살아 있는 docs (architecture, guides, onboarding)
# 원격 링크: 이 레포의 blob/main URL 은 실제 경로로 바꿔 검사한다. plugin 에 실리지 않는 rule 을
# 가리키는 링크라서, 파일을 옮기면 조용히 404 가 된다.
# plugin 경계: plugins/<plugin>/ 밖으로 나가는 링크는 실패다. 설치본은 plugin 별로
# 캐시되므로 대상 파일이 레포에 있어도 설치하면 깨진다. `/plugin:skill` 표기로 대체한다.
# 제외: 외부 URL, 코드 펜스(```) 안, 인라인 코드(`...`) 안 — 예시 링크는 링크가 아니다.
#
# 사용: ./scripts/validate-links.sh
# Exit code: 0 = 통과, 1 = 깨진 링크 있음

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib/layout.sh
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/layout.sh"

for kind in skills agents commands rules; do
    assert_floor "$kind" || exit 1
done

TARGETS_FILE="$(mktemp)"
trap 'rm -f "$TARGETS_FILE"' EXIT
{
    printf 'AGENTS.md\n'
    skill_files
    agent_files
    command_files
    rule_files
    find .claude/templates -maxdepth 1 -type f -name '*.md'
    if [ -d plugins ]; then
        find plugins -mindepth 2 -maxdepth 2 -type f -name README.md
    fi
    find docs/architecture docs/guides docs/onboarding -type f -name '*.md'
} >"$TARGETS_FILE"

TARGETS_FILE="$TARGETS_FILE" python3 - <<'PY'
import io, os, re, sys

TARGETS = io.open(os.environ["TARGETS_FILE"], encoding="utf-8").read().split()
REPO_URL = "https://github.com/ressKim-io/ress-claude-agents/blob/main/"

LINK = re.compile(r'\]\(([^)\s]+?\.(?:md|json|ya?ml|sh|ts|mjs))(#[^)]*)?\)')
broken = []
escaped = []
checked = 0


def plugin_root(path):
    parts = path.split(os.sep)
    if parts[0] == "plugins" and len(parts) > 2:
        return os.path.join(parts[0], parts[1])
    return None


for f in sorted(TARGETS):
    d = os.path.dirname(f) or "."
    root = plugin_root(f)
    in_fence = False
    for lineno, raw in enumerate(io.open(f, encoding="utf-8"), 1):
        stripped = raw.lstrip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        # 인라인 코드 스팬 제거 — 그 안의 링크는 예시 표기다
        line = re.sub(r'`[^`]*`', '', raw)
        for m in LINK.finditer(line):
            link = m.group(1)
            if link.startswith(REPO_URL):
                checked += 1
                if not os.path.exists(link[len(REPO_URL):]):
                    broken.append((f, lineno, link))
                continue
            if link.startswith(("http://", "https://", "mailto:")):
                continue
            checked += 1
            target = os.path.normpath(os.path.join(d, link))
            if root and not target.startswith(root + os.sep):
                escaped.append((f, lineno, link))
            elif not os.path.exists(target):
                broken.append((f, lineno, link))

if checked == 0:
    print("NG  검사한 링크가 0건이다. 패턴이나 대상 목록이 깨졌다.")
    sys.exit(1)

if escaped:
    print(f"\n=== plugin 경계를 넘는 링크 {len(escaped)}건 (설치본에서 깨진다) ===")
    for f, ln, link in escaped:
        print(f"  {f}:{ln}  ->  {link}")
    print("\n`/plugin:skill` 일반 텍스트로 바꾼다.")

if broken:
    print(f"\n=== 깨진 내부 링크 {len(broken)}건 (검사 {checked}건) ===")
    for f, ln, link in broken:
        print(f"  {f}:{ln}  ->  {link}")
    print("\nNG  깨진 링크가 있다. 자산을 옮겼다면 상호 참조도 같은 커밋에서 고친다.")

if escaped or broken:
    sys.exit(1)

print(f"OK  내부 링크 {checked}건 전부 유효 (파일 {len(TARGETS)}개)")
PY
