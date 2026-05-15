---
date: 2026-05-15
category: meta
tier: 2
importance: major
status: resolved
tags: [external-verification, claude-code-best-practice, frontmatter, effort-guide, skills-batch, code-review, stacked-pr]
related:
  - "/Users/ress/.claude/plans/claude-recursive-journal.md"
  - dev-logs/2026-05-12-pr18-20-fact-check-and-dangling-ref-fixes.md
---

# Claude / Claude Code 공식 best practice 정합화 — Phase A/B/C + length cleanup

## Context

사용자가 "Claude 효율적 사용법 외부 검색 후 우리 컬렉션에 적용" 요청. ress-claude-agents (49 agents / 273 skills / 24 rules) 가 install 받는 모든 프로젝트에 안티패턴 전파 위험 점검.

외부 검증 7건 (Anthropic / Claude Code 공식 docs, 2026-05-15 fetched) 기반 Phase A/B/C 진행. 총 4 PR (3 머지, 1 자동 close + 재생성).

## 외부 검증 사실 (F1-F8, 2026-05-15)

| # | Fact | 출처 |
|---|---|---|
| F1 | Skill `description` = auto-invocation primary signal. `What. Use when X.` 패턴 | https://code.claude.com/docs/en/skills |
| F2 | CLAUDE.md 권장 <200 줄 (instruction 준수도 저하) | https://code.claude.com/docs/en/memory |
| F3 | Opus 4.7 권장 effort `xhigh` (coding). `max` 는 frontier 만 (xhigh 대비 2x cost / +3%p) | https://platform.claude.com/docs/en/docs/build-with-claude/effort |
| F4 | Opus 4.7 manual `thinking.budget_tokens` → 400. adaptive only | https://platform.claude.com/docs/en/docs/build-with-claude/adaptive-thinking |
| F5 | Prompt cache 최소 4096 tokens (Opus 4.7) | https://docs.claude.com/en/docs/build-with-claude/prompt-caching |
| F6 | Sub-agent universal "always sonnet" 룰 **없음** | https://code.claude.com/docs/en/sub-agents |
| F7 | Verification criteria = "single highest-leverage thing" | https://code.claude.com/docs/en/best-practices |
| F8 | Path-scoped rules (`paths:` frontmatter) | https://code.claude.com/docs/en/memory |

## 작업 흐름

### Phase A — Foundation (PR #23 머지)
- `.claude/rules/effort-guide.md` (121줄, 사용자 핵심 요구) — 카테고리별 effort 매핑 표
- `.claude/rules/token-budget.md` +5 (F5 cache 4096 tokens + effort-guide cross-link)
- AGENTS.md 통계 233 → 274, `effort-guide.md` / `deep-thinking.md` cross-link 추가

### Phase A — SPEC (PR #24 → #25)
- `.claude/templates/SKILL-SPEC.md` (214줄, F1 명문화)
- `.claude/templates/AGENT-SPEC.md` (242줄, F6 명문화)
- 두 SPEC 모두 Verification Criteria 섹션 강제 (F7)

### Phase B Step 1 (PR #25 머지)
- `scripts/add-skill-frontmatter.sh` 자동 적용 (227 skills)
- baseline 16% (46/273) → **100% (273/273)** frontmatter
- description: H1 + 본문 첫 단락 + generic trigger (정밀화 Step 2 별도)
- effort 카테고리 default (xhigh 대다수, dx=low, migration=max)

### Phase C Step 1 (PR #25 머지)
- 6 outlier agent (opus 3 + haiku 3) frontmatter `effort:` 명시
  - opus → `max` (architect / debugging-expert / tech-lead)
  - haiku → `low` (dev-logger / git-workflow / pr-review-bot)

### Length cleanup (PR #26 머지)
- `cloud-cli-safety.md` 분리: rule 202 → **43줄** + skill 신규 223줄
- 자동 로드 토큰 -159줄 절감, `validate-rules-drift.sh` sweet spot WARN 해소
- `subscription-billing-flows.md` description 319자 + broken character "메인 hu" → 192자, 구체 trigger 보강

## code-reviewer agent 활용 → CR-001/CR-002 fix

PR #25 의 4 commits 를 `code-reviewer` agent 로 종합 리뷰 (8/10). 발견 2 Medium:
- **CR-001**: `effort-guide.md` spec=max vs frontmatter=xhigh (cell-based-architecture / kafka-msa-patterns) 불일치
- **CR-002**: AGENTS.md rules `24개` → 실제 25개 (effort-guide.md 추가 반영 누락)

`grep`/`find` 으로 사실 검증 후 `008cba0` commit 으로 fix. 종합 8/10 → **8.5/10**.

리뷰 결과 PR #25 comment 게시: https://github.com/ressKim-io/ress-claude-agents/pull/24#issuecomment-4459936572

## 핵심 결정 / 학습

### 1. 자동화 vs 정밀 분석 분리
- **자동화 (Step 1)**: 227 skills frontmatter / 6 outlier effort / cloud-cli 분리 → 본 세션
- **정밀 분석 (Step 2)**: description trigger 정밀화 / AGENTS.md 슬림화 / 본문 압축 → 다음 세션
- 판단 기준: 정보 손실 risk vs 길이 절감 가치

### 2. 한글 multi-byte safe 처리
- `add-skill-frontmatter.sh` 의 awk `substr()` 가 byte 단위 → 한글 3-byte 중간 cut
- fix: 150 byte 제한 + 단어 경계 cut (`sub(/[^ ]*$/, "", $0)`)
- 3 skill description 실제 broken character 발견·수정 (`subscription-billing` / `feature-flags` / `rate-limiting`)

### 3. Stacked PR 함정
- PR #23 머지 + `--delete-branch` 시 stacked base brach (`feature/effort-guide`) 삭제 → PR #24 자동 close (mergedAt=null)
- 복구: `git rebase origin/main` (cherry-picked 13f72d7 자동 drop) → force-with-lease push → 새 PR #25 생성

### 4. validate scripts 활용
- `validate-skill-frontmatter.sh` SKILL.md 폴더형 패턴 미인식 → script bug fix (`expected = basename(dirname(file))`)
- `generate-inventory.sh` SKILL.md 미계산 (14 drift) → 별도 PR 후보
- `validate-rules-drift.sh` 의 양방향 참조 검증 — `deep-thinking.md` 누락 발견 + fix

### 5. 외부 검증 의무 (deep-thinking.md §검증 의무)
- 모든 사실 명시 전 WebFetch 로 공식 출처 확인
- 출처 URL + 검증일 (`✅ verified 2026-05-15`) frontmatter / commit msg / PR body 에 명시
- ⚠️ unverified 영역 없음

## 미해결 (다음 세션 권장)

| 작업 | 우선순위 | 비고 |
|---|---|---|
| **AGENTS.md 슬림화 (325 → <200, F2)** | Critical | 큰 작업, 정보 손실 risk 신중 분석 필요 |
| Phase B Step 2: description trigger 정밀화 (227 skills) | High | subagent fan-out 5개, 큰 토큰 비용 |
| Phase C Step 2: 20 agent description <30 단어 보강 | High | subagent 위임 |
| Phase D: 400+ 줄 skills 117개 본문 압축 | Medium | 정성 작업 |
| Phase D: Verification Criteria 섹션 (273 + 49) | Medium | placeholder 자동 + 의미 정성 |
| `dx/` 전략 skills (engineering-strategy 등) effort xhigh 보정 | Low | CR-004 |
| `build_description()` 마침표 처리 + 재적용 | Low | CR-003 |
| `validate-skill-frontmatter.sh` description 길이 (50-300자) 검증 추가 | Low | CR-005 |
| `generate-inventory.sh` SKILL.md 미계산 fix (14 drift) | Low | inventory 자동 일관성 |
| commit msg description ≤50자 엄수 | 다음 PR 부터 | 본 PR 4/5 가 51-61자 OVER (이미 머지) |

## Reference

- Plan file: `/Users/ress/.claude/plans/claude-recursive-journal.md`
- PRs: #23 (effort-guide), #25 (Phase B/C + fix), #26 (length cleanup)
- 자동 close: #24 (stacked base 삭제로 자동 close, 동일 내용 #25 재생성)
- 직전 유사 작업: [2026-05-12 PR #18-20 fact-check](2026-05-12-pr18-20-fact-check-and-dangling-ref-fixes.md)
