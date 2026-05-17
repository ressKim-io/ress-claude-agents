---
date: 2026-05-17
category: meta
tier: 2
importance: major
status: resolved
tags: [agent-spec, permission-boundary, escalation, 2026-agentic-coding-trends, collaboration-paradox, validation-gate, subshell-bug]
related:
  - dev-logs/2026-05-15-claude-meta-spec-refactor.md
  - "/Users/ress/.claude/plans/enchanted-prancing-falcon.md"
---

# Agent 정의 권한 경계 표준화 — 2026 Agentic Coding Trends 기준 점검 + 검증 게이트

## Context

사용자가 Anthropic 「2026 Agentic Coding Trends Report」를 기준으로 49개 agent 정의
(`.claude/agents/*.md`)를 점검 요청. Explore subagent 3개로 rules 25 / agents 49 /
거버넌스 인프라를 훑고, Plan subagent로 구현을 설계한 뒤 적용.

## 점검 근거 — 2026 Agentic Coding Trends Report

Anthropic 공식 리포트(`resources.anthropic.com`, 18p / 8 trends). 점검에 쓴 핵심 인사이트:

- **Collaboration Paradox**: 개발자는 일의 ~60%에 AI를 쓰지만 "완전 위임" 가능한 건 0~20%.
  효과적 AI 사용 = thoughtful set-up + 능동적 감독 + 검증이 전제.
- **Trend 4** — human oversight가 "전부 검토 → 중요한 것만 검토"로 이동.
- **Trend 8** — agentic coding의 dual-use(공격적 사용) 위험 → security-first 설계.

## 발견한 gap (agent 정의 49개)

| # | Gap | 현황 | 심각도 |
|---|---|---|---|
| G1 | "결과만 반환·외부 게시 금지" 권한 경계 미명시 | 49개 중 0개 | 높음 |
| G2 | "언제 멈추고 인간에게 escalate하는가" 불명확 | handoff 3 / approval gate 6 | 높음 |
| G3 | 자체 검증이 "권장"이지 "필수" 아님 | Verification Criteria 49개 중 0개 | 중간 |
| G4 | 유사 agent 라우팅 혼란 | cicd 2종·k8s 3종·db 2종 | 중간 |
| G5 | effort 필드·본문 구조 표준 미정렬 | effort 6/49, 섹션 9~92 | 낮음 |
| G6 | context isolation 설계 미명시 | 15/49 | 낮음 |

**핵심 통찰 — rules엔 있는데 agents엔 없다**: `user-approval.md`(rule)는 "subagent는 결과만
반환, 외부 게시 권한 위임 금지"를 명시한다. 그러나 rules는 메인 세션에만 자동 로딩되고,
subagent는 자기 정의 파일을 system prompt로 받는다 — 룰이 정작 실행 주체에게 전달되지 않는다.
특히 `git-workflow.md`는 본문에서 `gh pr create`/`git push`를 agent 워크플로우로 제시해
user-approval.md와 실제로 모순됐다.

## 적용한 변경 (scope: 표준 + 검증 인프라 보강)

사용자가 "신규 agent 자동 준수, 기존은 critical만 우선 + 점진" scope 선택. 실수정 3파일:

| 파일 | 변경 | Gap |
|---|---|---|
| `.claude/templates/AGENT-SPEC.md` | 표준 섹션에 Permission Boundary·Escalation 신설, Verification Criteria에 Self-verification 추가, §1 표에 본문 3섹션 필수 코멘트 | G1·G2·G3 |
| `scripts/validate-skill-frontmatter.sh` | `check_agents()`에 본문 H2 3섹션 검증 + `LEGACY_AGENTS_NO_BODY_SPEC` 화이트리스트(2단계 게이트) | G1·G2·G3 |
| `.claude/agents/git-workflow.md` | PR 생성 블록을 "메인 에이전트 승인 후 실행용 초안"으로 재작성, 본문 3섹션 추가 | G1 critical |

`.github/workflows/ci.yml`은 미변경 — drift job이 이미 `validate-skill-frontmatter.sh all`을
호출하므로 검증 추가만으로 CI 게이트가 작동.

## 검증 (6단계 전부 통과)

| 검증 | 결과 |
|---|---|
| shellcheck | exit 0 |
| `validate-skill-frontmatter.sh agents` | exit 0, `PASS 49/49` + `WARN 141건`(레거시 soft) |
| `validate-skill-frontmatter.sh all` | exit 0 (Agents·Skills·Assets 전부 PASS) |
| `validate-agent-handoff.sh all` | exit 0 — 무영향 |
| git-workflow.md grep | `gh pr create`/`git push` 전부 "직접 실행 금지" 컨텍스트 |
| hard-path 테스트 | code-reviewer를 화이트리스트에서 빼면 `FAIL 1/49` + exit 1 |

## 핵심 결정 / 학습

### 1. rules ≠ agent 정의 — 전달 경로가 다르다
rule에 룰을 적어도 subagent에는 전달되지 않는다. subagent 동작을 강제하려면 **agent 정의
파일 자체** 또는 그 템플릿(AGENT-SPEC)에 박아야 한다. 일반화 가능 — install되는 모든
프로젝트에 동일.

### 2. 신규 hard / 레거시 soft 2단계 게이트
49개 중 0개가 신규 표준을 충족하므로 전체 강제 시 CI 즉시 붕괴. `LEGACY_AGENTS_NO_BODY_SPEC`
화이트리스트로 레거시는 soft 경고(CI 비차단), 미등재(신규)는 hard fail. 화이트리스트가 곧
**마이그레이션 잔량 인벤토리** — 한 줄 제거 시 자동 hard 전환.

### 3. (디버깅) command substitution 서브셸 → 전역 배열 부수효과 유실
1차 구현에서 본문 섹션 검사를 `validate_agent()`에 넣었으나, 이 함수는
`issues=$(validate_agent ...)` command substitution(서브셸) 안에서 호출된다. 서브셸 안의
`SOFT_WARNINGS+=()`는 부모 셸에 반영되지 않아 soft 경고 141건이 전부 유실. **수정**: 본문
검사를 `check_agents()`의 `while ... done < <(...)` 본체로 이동 — process substitution은
while을 서브셸로 만들지 않으므로 전역 배열이 영속.

## Failure Type Tags

> `.claude/rules/debugging.md` §실패 유형 분류 참조

- [x] `wrong-layer` — soft 경고 누적 로직을 서브셸에서 실행되는 함수에 배치
- [x] `residual-effect` — rule(user-approval.md)에는 경계가 있으나 실행 주체(agent 정의)에 미반영

## Learning / Universal Lesson

- subagent 동작 강제는 rule이 아니라 agent 정의/템플릿에 박아야 한다 — install되는 모든
  프로젝트에 적용되는 일반 교훈.
- 일반화 가능 여부: **Yes** — 같은 패턴(거버넌스 규칙의 전달 경로 불일치) 재발 시
  `/promote-devlog`로 ADR 승격 후보.

## 후속 (점진 마이그레이션, 이번 scope 밖)

- **G2/G3**: agent별 Escalation·Verification 섹션 추가 + `LEGACY_AGENTS_NO_BODY_SPEC`에서
  한 줄씩 제거 → 자동 hard 전환. 메커니즘은 이미 제공됨.
- **G4** (라우팅 혼란): `_handoff.yml`에 routing hint 추가 검토.
- **G5/G6**: AGENT-SPEC 가이드 보강 후 점진.

## Reference

- Plan file: `/Users/ress/.claude/plans/enchanted-prancing-falcon.md`
- 점검 근거: 2026 Agentic Coding Trends Report — https://resources.anthropic.com/hubfs/2026%20Agentic%20Coding%20Trends%20Report.pdf
- 직전 유사 작업: [2026-05-15 Claude meta spec refactor](2026-05-15-claude-meta-spec-refactor.md) — AGENT-SPEC.md 최초 작성
- 권한 경계 룰 원천: `.claude/rules/user-approval.md` §"에이전트 실행 규칙"
