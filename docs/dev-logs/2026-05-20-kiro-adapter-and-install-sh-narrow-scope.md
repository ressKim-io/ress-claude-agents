---
date: 2026-05-20
category: meta
tier: 2
importance: major
status: resolved
tags: [kiro-adapter, multi-tool, install-sh-deprecation, picky-install, adr-0006, adr-0007, agents-md-standard, deep-thinking]
related:
  - adr/0006-kiro-adapter-strategy.md
  - adr/0007-install-sh-narrow-scope.md
---

# Kiro IDE 어댑터 + install.sh 축소 결정 (PR-1: ADR 2 종 작성)

## Context

ressKim 이 Kiro IDE 를 ress-claude-agents 와 같이 운영하려는 욕구 + install.sh `--plugin` / `--workflow` 묶음이 광범위해서 "안 쓰는 것까지 다 깔린다" 는 불만을 동시에 제기. Plan mode 워크플로우 (Explore → Plan → Decision → ExitPlanMode 승인) 거쳐 8 PR sequence 확정.

## 검증 (deep-thinking 준수)

Kiro 공식 docs WebFetch + WebSearch cross-check (검증일 2026-05-20):

- AGENTS.md 워크스페이스 루트 자동 인식 (Linux Foundation 표준 합류) ✅ verified
- Skills = 폴더 + SKILL.md (Anthropic Agent Skills 표준) ✅ verified
- Subagents = `.kiro/agents/*.md` (front-matter `name/description/tools/model`) ✅ verified
- Steering 4 inclusion 모드 (always/fileMatch/manual/auto) ✅ verified
- Specs = `.kiro/specs/<feat>/{requirements,design,tasks}.md` (EARS notation) ✅ verified
- MCP = `.kiro/settings/mcp.json` (workspace) / `~/.kiro/settings/mcp.json` (global) ✅ verified

⚠️ unverified — Kiro 사양은 cutoff 이후 변경 가능. ADR 0006 Sources 에 review schedule 분기별 명시.

## Explore 발견 (control-plane/adapter.ts SOT)

Plan agent 가 사용자 주장과 실제 값 차이 잡아냄:

| 항목 | 사용자 주장 | 실제 |
|---|---|---|
| adapter.ts 줄수 | 232 | 307 |
| AGENTS.md 줄수 | 312 | 325 |
| `docs/architecture/` | 존재 가정 | 부재 (PR-2 에서 신규 생성) |

핵심 SOT 구조:
- install.sh (860 줄) = 자산 copy 만. 어댑터 코드 0%
- 어댑터 = `control-plane/src/adapter.ts` (claude/codex/cursor 3 도구 다중화)
- `.agents/skills/` = tool-agnostic universal source

## 의사결정 4 가지 (사용자 승인 2026-05-20)

| # | 결정 | 채택 옵션 | 근거 |
|---|---|---|---|
| 1 | Kiro 어댑터 방향성 | **수동 매핑 가이드 only** | Kiro 표준 호환성 높아 변환 거의 불필요. 사용자 자동화 거부 의도와 일관 |
| 2 | install.sh 미래 | **축소 (deprecation 3 단계)** | 불만 본질이 묶음 광범위함. 자산 copy 기능은 가치 유지. ADR 0006 picky 정신과 결 같음 |
| 3 | cherry-pick 워크플로우 | **단순 가이드 + install.sh 정밀 옵션** | slash command 는 Claude 전용 (다도구 정신 배치). install.sh `--skill` 옵션이 자연 결합 |
| 4 | multi-tool-adapter rule 범위 | **universal 원칙 + 도구별 1줄** | AGENTS.md sweet spot 150 줄 준수. 상세는 매핑 문서 분리 |

## PR-1 산출물 (본 세션)

- `docs/adr/0006-kiro-adapter-strategy.md` (143 줄) — Decision: Option 1 수동 가이드 only
- `docs/adr/0007-install-sh-narrow-scope.md` (172 줄) — Deprecation 3 단계: warn (2026-05-20) → error (2026-06-20) → remove (2026-07-20)
- `/Users/ress/.claude/plans/install-sh-staged-blossom.md` — Plan 원본 (Plan mode 산출)

## PR Sequence (다음 세션 시작점)

```
PR-1 (ADR 2 종)  ─ 완료 (본 세션)
  ↓
PR-2 (매핑 문서)  ─ 다음 세션 시작점
  ↓
PR-3 (rule) + PR-4 (AGENTS.md) ─ sequential merge 강제
  ↓
PR-5 (inventory) ─ 독립
  ↓
PR-6 (skill) ║ PR-7 (template) ─ 병렬 가능
  ↓
PR-8 (install.sh 축소 + cherry-pick 가이드)
```

## 학습

- **Plan agent 의 검증 가치** — 사용자 주장과 실제 값 차이 (adapter.ts 232→307, AGENTS.md 312→325, docs/architecture 부재) 잡아냄. deep-thinking rule 의 "추측 명시 금지" 정신을 plan 단계에서 자동 적용.
- **광범위 install vs picky install 은 같은 정신의 양면** — Kiro 합류 + install.sh 축소가 우연이 아니라 한 결정에서 갈라진 두 trade-off. PR-1 에 두 ADR 묶는 게 자연.
- **Kiro 표준 호환성이 변환 비용을 결정** — codex 처럼 `.toml` 형식 변환이 있었다면 adapter.ts 확장이 합리적이었을 것. Kiro 가 `.md` 표준 인식하므로 자동화 ROI 낮음.

## 회고 트리거

- 2026-08-20 (3 개월 후) — 사용자 불만 해소 / picky 운영 정착 / Option 2 (adapter.ts 확장) 재검토 가부
- 분기별 — Kiro 사양 변경 review (ADR 0006 Sources 의 출처 URL 7 개 재확인)

## 후속 작업

PR-2 부터 PR-8 까지 단계별 진행. 각 PR 단위로 사용자 GO 사인 의무 (메모리 `feedback_plan_before_parallel_work` 준수).
