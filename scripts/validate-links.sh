#!/usr/bin/env bash
# 레포 내부 마크다운 상대 링크의 유효성 검증.
#
# 배경: 2026-08-24 Step 2 가 skill 260개를 `.claude/skills/<cat>/<name>.md` 에서
# `.claude/skills/<name>/SKILL.md` 로 옮기면서 **상호 참조를 고치지 않았다**.
# 79개 링크가 깨진 채 3일간 남아 있었고, 그중 4개는 매 세션 로드되는 AGENTS.md
# 안에 있었다. 링크를 보는 CI job 이 하나도 없어 아무도 몰랐다 — PR #36 리뷰.
#
# 검증 범위: AGENTS.md / .claude/rules / .claude/skills / .claude/templates
# 제외: 외부 URL, 코드 펜스(```) 안, 인라인 코드(`...`) 안 — 예시 링크는 링크가 아니다.
#
# 사용: ./scripts/validate-links.sh
# Exit code: 0 = 통과, 1 = 깨진 링크 있음

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - "$@" <<'PY'
import io, os, re, sys, glob

TARGETS = ["AGENTS.md"] + \
          glob.glob(".claude/rules/*.md") + \
          glob.glob(".claude/skills/*/SKILL.md") + \
          glob.glob(".claude/templates/*.md")

LINK = re.compile(r'\]\(([^)\s]+?\.md)(#[^)]*)?\)')
broken = []
checked = 0

for f in sorted(TARGETS):
    d = os.path.dirname(f) or "."
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
            if link.startswith(("http://", "https://", "mailto:")):
                continue
            checked += 1
            if not os.path.exists(os.path.join(d, link)):
                broken.append((f, lineno, link))

if broken:
    print(f"\n=== 깨진 내부 링크 {len(broken)}건 (검사 {checked}건) ===")
    for f, ln, link in broken:
        print(f"  {f}:{ln}  ->  {link}")
    print("\nNG  깨진 링크가 있다. 자산을 옮겼다면 상호 참조도 같은 커밋에서 고친다.")
    sys.exit(1)

print(f"OK  내부 링크 {checked}건 전부 유효")
PY
