# ADR 0008 — 자산 티어 판정 정책: description 우선 재배치

- **Status**: Accepted
- **Date**: 2026-08-15
- **Driver**: [2026-08-15 자산 티어 재배치 audit](../audit/2026-08-15-asset-tier-rebalance.md) — skill 260개 중 224개(86%)가 동일 템플릿 description 으로 발견 불가
- **Depends on**: 없음
- **Related**: ADR 0004 / 0005 (Migration 0002 admit baseline — 본 결정으로 P4 순위로 유보), [2026-05-08 자산 audit](../audit/2026-05-08-asset-audit.md)

## Context

레포에는 5개 자산 티어(rule / skill / command / agent / plugin·workflow)가 있으나 **어떤 자산이 어느 티어에 속하는지의 판정 기준이 문서화된 적이 없다**. 그 결과 2026-01 ~ 2026-05 사이 자산이 66 → 260 skills 로 늘어나는 동안 배치가 관행에 맡겨졌고, 다음 상태에 도달했다.

| 증상 | 측정값 (2026-08-15) |
|---|---|
| 템플릿 description 사용 skill | 224 / 260 (86%) |
| SKILL-SPEC sweet spot(250-400줄) 준수 | 66 / 260 (25%) |
| spec 하한(250줄) 미달 | 59 |
| `## Verification Criteria` 보유 skill | 0 / 260 |
| AGENT-SPEC 상한(600줄) 초과 agent | 2 (go-expert / java-expert, 각 605) |
| Permission Boundary 보유 agent | 1 / 49 |

핵심 인과관계: `description` 은 Claude Code skill auto-invocation 의 primary signal 인데(SKILL-SPEC §1, 출처 `code.claude.com/docs/en/skills` 검증일 2026-05-15), 224개가 아래 접미사를 공유해 **서로 구별되지 않는다**.

```
"... Use when working with <카테고리> 도메인의 패턴 / 구현 선택."
```

2026-05-08 audit 이 측정한 "skills 239개 중 152개(63.6%) 미참조" 는 이 원인의 결과였다. 당시에는 "스킬은 description 매칭으로 자동 발견되므로 orphan ≠ 미사용" 으로 해석했으나, description 자체가 변별력을 잃은 상태였으므로 그 해석은 성립하지 않는다.

또한 커밋 `7f864d7 feat(skills): add frontmatter to 227 skills` 는 frontmatter **존재** 요건만 충족하고 **품질** 요건(`What. Use when [구체 trigger].`)은 충족하지 않았다. SKILL-SPEC 자신이 이 상태를 실명으로 기록해 두었다 — `❌ Bad (현재 273 중 ~227 의 패턴)`.

## Decision

### 1. 티어 판정 기준 (상시 적용)

신규 자산 작성 및 기존 자산 재배치 시 아래를 적용한다.

| 신호 | 티어 | 근거 |
|---|---|---|
| 모든 작업에 무조건 적용, 분기 없음 | **rule** | 매 세션 자동 로딩. AGENTS.md §Claude Code-Specific — "Rules 100~150줄이 sweet spot, 길면 묻힘" |
| 한 rule 에 딸린 짧은 상시 체크리스트 | **rule 섹션** (독립 skill 금지) | 발견 슬롯을 소비하지 않음 |
| 분기 있는 결정 트리 + 필요할 때만 참조 | **skill** | 발견 슬롯 1개 소비 — 변별력 있는 description 필수 |
| 이름으로 호출하는 단발 절차 | **command** | 사용자 직접 호출, 발견 불필요 |
| 자체 컨텍스트 + 다단계 조사 필요 | **agent** | 별도 컨텍스트 윈도우 |

판정 질문 순서: **"매번 읽어야 하나?"** → rule / **"결정할 게 있나?"** → skill / **"직접 부를 건가?"** → command / **"따로 조사해야 하나?"** → agent.

### 2. 개선 순서 — description 재작성 우선

발견 문제를 **description 재작성(P1)** 으로 먼저 해결하고, 구조 재배치(P2) → agent 분할(P3) → Migration 0002 재평가(P4) 순으로 진행한다.

### 3. agent 분할은 기존 4축만 사용

신규 분할 축을 만들지 않는다: 도구별(`load-tester`) / 엔진별(`database-expert`) / 관점별(`k8s-reviewer` vs `k8s-security-reviewer`) / 단계별(`platform-strategy-agent` vs `platform-engineer`).

분할 PR 의 수락 조건으로 **역할 경계 + Permission Boundary + Escalation + Pair Patterns 동시 작성**을 요구한다 (AGENT-SPEC §5). 이를 통해 `validate-skill-frontmatter.sh` 의 `LEGACY_AGENTS_NO_BODY_SPEC` 화이트리스트를 점진 축소한다.

### 4. 자산 개수를 산문에 쓰지 않는다

AGENTS.md / rules 본문에 "274 skills" 같은 숫자를 직접 쓰지 않고 `.claude/inventory.yml` 참조 링크로 대체한다. CI 가 산문 숫자를 검증하지 않아 drift 가 반복 발생했다 (D2~D4, 커밋 `6ba921f` 는 수정 시도가 오차를 키운 사례).

## 대안 비교

| | A. 현행 유지 | **B. 티어 재배치 (채택)** | C. control-plane 결정적 매칭 우선 |
|---|---|---|---|
| **내용** | 평면 260 skills 유지, description 방치 | description 재작성 → 티어 재배치 → agent 분할 | Migration 0002 P6.5 baseline 재수집 → P7 에서 260개 `applies_when` 변환 |
| **발견 문제 해결** | ❌ 방치 | ✅ Claude Code 기본 메커니즘 개선 | ✅ 결정적 매칭 (가장 근본적) |
| **효과 시점** | — | **즉시** — 재작성한 카테고리부터 | P7 완료 후 (변환 260건 + baseline 대기) |
| **도구 종속** | 없음 | 없음 — 모든 AGENTS.md 호환 도구에 적용 | control-plane 설치 + PreToolUse hook 필요 (Claude Code 한정) |
| **선행 조건** | — | 없음 | ADR 0005 결정(3개월 미수집), P7 전체 변환 |
| **작업량** | 0 | description 224개 + 병합 ~110개 | 변환 260개 + hook 운영 + baseline 재수집 |
| **폐기 위험** | — | 낮음 — `applies_when` 은 description 을 **대체하지 않고 보완**하므로 C 를 나중에 해도 버려지지 않음 | 중간 — baseline 미통과 시 warn 영구(ADR 0005 Option C)로 투자 회수 불가 |

### 정량 근거

- 발견 불가 상태 skill: **224 / 260 (86%)** — A 는 이 수치를 그대로 유지
- B 의 P1 범위: description 224개 재작성. 카테고리 단위 PR 22개로 분할 가능, 각 PR 이 독립적으로 효과 발생
- C 의 선행 대기: P6.5 baseline 임계는 "total ≥ 50 / activation rate ≥ 70%" (ADR 0004). 2026-05-08 설정 후 **3개월간 미수집**이며 재개해도 1주 wall-clock 추가 소요
- C 는 `assets/skills/` 15개만 `applies_when` 보유 → 잔여 245개 변환 필요

### 왜 C 가 아닌가

C 가 기술적으로 우월하다는 점은 인정한다 — 결정적 매칭은 description 매칭의 확률적 성격을 제거한다. 그러나 **B 와 C 는 배타적이지 않다.** `applies_when` 은 스케줄러 입력이고 `description` 은 auto-invocation 신호라 역할이 다르며, skill-manifest schema 는 둘을 동시에 갖도록 설계돼 있다(`skill-manifest.v1.json` — `description` required, `applies_when` optional).

따라서 **B 를 먼저 하고 C 를 P4 로 유보**하는 것이 순서상 손실이 없다. P1 완료 후 발견율을 재측정해 C 의 필요성을 데이터로 판단한다.

## Consequences

### 긍정

- 발견 슬롯 낭비 제거 — 260 → 150 선, sweet spot 비율 25% → 60% 목표
- SKILL-SPEC / AGENT-SPEC 이 실제 강제력을 갖게 됨 (현재 준수율 0~18%)
- 신규 자산 작성 시 "이걸 skill 로 만들까 rule 로 만들까" 판단이 §Decision 1 로 결정됨
- agent 분할과 동시에 spec 필수 섹션이 채워져 LEGACY 화이트리스트 축소

### 부정 / 트레이드오프

- **세분화된 검색성 일부 상실** — `istio-kiali` 처럼 좁은 이름으로 정확히 찾던 경로가 사라진다. `[[cross-link]]` 확충(현 8/260)과 deprecated stub 의 `replaced_by` 로 보완하되, 완전 상쇄되지는 않음
- **작업량이 크다** — description 224개 + 병합 대상 ~110개. 카테고리 단위 PR 분할이 필수이며 단기간 완료 불가
- **Migration 0002 가 더 지연된다** — 이미 3개월 정지 상태에서 P4 로 밀리므로, P8(registry publish) 목표는 사실상 무기한 연기. 0002 를 공식 보류 처리할지는 P1 재측정 후 별도 ADR 로 결정
- **병합 판단에 주관이 개입** — S6(<250줄 59개 전수 판정)은 기계적 기준이 없다. §Decision 1 의 판정 질문을 적용하되 경계 사례는 PR 리뷰에서 합의

### 중립

- 본 정책은 **자산 배치**에 대한 것이고 자산 **내용**의 정확성(deep-thinking.md 소관)과는 독립적이다

## 검증

- [ ] P1 완료 후 `grep -rl '도메인의 패턴 / 구현 선택' .claude/skills/ | wc -l` = 0
- [ ] sweet spot(250-400줄) 비율 ≥ 60%
- [ ] skill 총수 ≤ 160
- [ ] 분할된 agent 전원이 역할 경계 / Permission Boundary / Escalation / Pair Patterns 보유
- [ ] AGENTS.md 산문에 자산 개수 숫자 부재
- [ ] 재점검 2026-11-15 ([audit §7](../audit/2026-08-15-asset-tier-rebalance.md#7-재점검-일정))
