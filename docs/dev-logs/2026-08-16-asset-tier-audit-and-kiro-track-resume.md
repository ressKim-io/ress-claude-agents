---
date: 2026-08-16
category: meta
tier: 2
importance: major
status: resolved
tags: [audit, asset-tier, skill-discovery, backlog-consolidation, adr-hygiene, kiro-adapter, multi-tool, deep-thinking]
related:
  - adr/0008-asset-tier-policy.md
  - adr/0006-kiro-adapter-strategy.md
  - adr/0007-install-sh-narrow-scope.md
  - dev-logs/2026-05-20-kiro-adapter-and-install-sh-narrow-scope.md
---

# 자산 티어 audit + 백로그 단일 진입점 + Kiro 문서 트랙 재개 (PR #31)

## Context

레포가 2026-05-20 이후 3개월 정지(6~8월 커밋 0). 사용자 요청: **"오래돼서 개선할 것 찾아라 — skill 까지 안 가도 될 것들, agent 를 더 세분화할 수 있는 것들"**.

탐색 결과 개선 대상 발견에 그치지 않고 **자산 관리 체계 자체의 구조적 문제** 3가지가 드러나 audit + 정책 ADR + 백로그 통합까지 확장됐다.

## Issue

### 1. 발견 메커니즘이 규모를 못 따라감

`description` 은 Claude Code skill auto-invocation 의 primary signal 인데 **260개 중 224개(86%)가 동일 템플릿 접미사**를 쓴다:

```
"... Use when working with <카테고리> 도메인의 패턴 / 구현 선택."
```

2026-05-08 audit 이 "152/239(63.6%) 미참조" 로 관측하고 *"스킬은 description 매칭으로 자동 발견되므로 orphan ≠ 미사용"* 으로 해석했으나, **description 자체가 변별력을 잃은 상태**였으므로 그 해석은 성립하지 않았다.

### 2. spec 이 있는데 채택이 안 됨

2026-05-15 작성 SKILL-SPEC / AGENT-SPEC 준수율:

| 항목 | 준수 |
|---|---|
| skill `## Verification Criteria` (spec 상 **필수**) | **0 / 260** |
| skill sweet spot 250-400줄 | 66 / 260 (25%) |
| agent Permission Boundary / Escalation / Verification Criteria | 각 **1 / 49** |
| agent Pair Patterns | **0 / 49** |

### 3. 백로그가 문서 6곳에 흩어져 진입점 부재

audit §6 / ADR 0006·0007 / 2026-05-08 audit §7 / ADR 0001~0003 / ADR 0005 / Migration 0002 / TODO.md.

**대조군이 결정적이었다** — 2026-05-11 planning-agent-gap 의 권장 4건은 단일 문서에 모여 있었고 **전부 집행됐다**. 실행력 문제가 아니라 **진입점 문제**.

## Action

### 산출물 (PR #31, 커밋 4 / +787 −27 / 10 파일)

| 파일 | 내용 |
|---|---|
| `docs/audit/2026-08-15-asset-tier-rebalance.md` (신규 388줄) | 측정 + drift 8건 + 티어 판정 기준 + P0~P4 백로그 + **§8 선행 백로그 인수** |
| `docs/adr/0008-asset-tier-policy.md` (신규) | 티어 판정 기준 상시 정책화. 대안 A/B/C 비교 |
| `docs/architecture/multi-tool-mapping.md` (신규 146줄) | ADR 0006 **PR-2** — 4도구 매핑 + Kiro port 규칙 |
| `.claude/rules/multi-tool-adapter.md` (신규 73줄) | ADR 0006 **PR-3** — 거버넌스 원칙 |
| `AGENTS.md` | ADR 0006 **PR-4** — Kiro 행 + §Governance 4항 + Auto-Loaded Rules 등록 |
| ADR 0006 / 0007 | 진행 상태 명시, **deprecation 일정 상대화**, PR-6 블로커 기록, 분기 review 결과 |
| 2026-05-08 audit / TODO.md / 0002-progress.md | §8 포인터 1줄 |

### 티어 판정 기준 (사용자 질문 "skill 까지 안 가도 될 것" 의 답)

| 신호 | 티어 |
|---|---|
| 무조건 적용, 분기 없음 | rule |
| rule 에 딸린 짧은 상시 체크리스트 | **rule 섹션 — 독립 skill 아님** |
| 분기 있는 결정 트리 + 필요 시 참조 | skill |
| 이름으로 호출하는 단발 절차 | command |
| 자체 컨텍스트 + 다단계 조사 | agent |

대표 오배치: `rules/config-contract-audit.md`(135줄, 자동 로딩)가 3단 검증 모델을 이미 담고 있는데 같은 주제가 skill 4개(687줄)로 분산 → 발견 슬롯 4개 낭비.

### Kiro 분기 review (ADR 0006 이 예고한 2026-08 회차 — 도래하여 수행)

WebFetch 재검증 6건 중 **3건 변경**:

- ⚠️ Subagents docs URL 이동 (`/docs/chat/` → `/docs/custom-agents/`)
- ⚠️ agent 필드 대폭 확장, **`toolsSettings` deprecated → `permissions`**
- ⚠️ Specs 경로/EARS 미검증 (`/docs/specs/concepts/` HTTP 404) — 사유 기록 후 매핑 제외
- ✅ Steering / Skills / MCP 유지 → Option 1(수동) 결정 자체는 영향 없음

부수 소득: Kiro SKILL.md 요구사항(`name` ≤64 kebab, `description` ≤1024)이 이 레포 `skill-manifest.v1.json` 과 정확히 일치 → `assets/skills/` 자산은 **무변환 복사로 동작**.

## Result

- 미집행 백로그 6곳 → **§8 단일 진입점**, B트랙(결정 부채) / P트랙(자산 구조조정) 분리
- ADR 0006 8-PR 시퀀스 중 **PR-2·3·4 완료** (3개월 정지 해제)
- CI 5/5 green, `mergeStateStatus: CLEAN`, 머지 `4372362`
- **단 실제 자산 지표는 미변동** — description 224/260, Verification Criteria 0/260, 600줄 agent 2개, 미설치 command 16개 전부 그대로. 이번 PR 은 **진단·정책·문서 정합성**까지이며 개선 실행은 P0 부터

## Learning / Universal Lesson

### 1. 미실행 계획에 절대 날짜를 박으면 사문화된다 ★

ADR 0007 의 warn(2026-05-20) / error(06-20) / remove(07-20) 는 **구현 주체인 PR-8 이 착수되지 않아 3단계 전부 시작된 적 없이 만료**했다. 동일 사고가 ADR 0005("1주 baseline", 3개월 미수집)에서도 발생 — **2회 반복**.

→ **일정은 선행 산출물 머지일 기준 상대 표기(D0 / D+30 / D+60)로 쓴다.** 세션이 끊겨도 유효하다.
→ 일반화 가능: **Yes**. 3건째 누적 시 `/promote-devlog` 로 rule 승격 후보.

### 2. frontmatter "존재" 요건과 "품질" 요건은 다르다

커밋 `7f864d7 feat(skills): add frontmatter to 227 skills` 는 필드 존재만 채우고 SKILL-SPEC 의 `Use when [구체 trigger]` 패턴은 채우지 않았다. 결과적으로 lint 는 통과하는데 **발견은 안 되는** 상태가 3개월 유지됐다.

→ 완료 판정 기준을 "필드 존재" 가 아니라 **"spec 패턴 일치"** 로 잡는다. lint 도 그렇게 강화해야 한다.

### 3. CI 가 검사하지 않는 것은 반드시 drift 한다

`ci.yml` 은 rules↔AGENTS.md 상호참조·frontmatter·inventory 신선도를 검사하지만 **산문에 박힌 숫자는 검사하지 않는다.** 그 사각지대에서 D2~D4 가 발생했고, 심지어 커밋 `6ba921f docs: fix skill count drift (273→274)` 는 **수정 시도가 오차를 키웠다** (실제 260).

→ 자산 개수를 산문에 쓰지 말고 `.claude/inventory.yml` 참조로 대체한다.

### 4. 백로그 분산 = 미집행

단일 문서에 모인 권장(2026-05-11)은 4/4 집행, 6곳에 흩어진 것은 대부분 미집행. **진입점 단일화가 실행률을 좌우한다.**

### 5. 외부 도구 사양 분기 재검증은 실제로 값을 한다

ADR Sources 에 `분기별 (2026-08, 2026-11, 2027-02)` 를 박아둔 덕에 3개월 만에 Kiro 3건 drift 를 잡았다. **외부 사양 의존 ADR 에는 review 일정을 명시**한다.

### 6. ADR 상태만 보고 판단하지 말고 연관 dev-log 의 PR 시퀀스를 확인하라 ★

내가 처음 **"Accepted 인데 구현 0%"** 로 프레이밍한 것은 부정확했다. 사용자가 *"저거 시작하려다 끝낸 거 아니야?"* 라고 지적해 재확인하니, dev-log 에 **8-PR 시퀀스 + "PR-2 = 다음 세션 시작점"** 이 명시돼 있었다. ADR 자체가 PR-1 의 산출물이었으므로 설계상 구현은 PR-2 부터이고, **실패가 아니라 명시적 재개 지점이 있는 일시정지**였다.

사용자가 *"날짜가 뭔가 잘못된 것 같다"* 고 한 것도 맞았다 (ADR frontmatter 2026-05-20 vs 실제 커밋 2026-05-26, 그리고 일정 전체 사문화).

→ **ADR 은 frontmatter Status 만으로 진행 상태를 판단할 수 없다.** 연관 dev-log 의 PR 시퀀스를 함께 읽는다. 본 PR 에서 두 ADR 에 `**진행**:` 줄을 추가한 이유다.

### 7. 사용자 주장도 검증 대상 (3건 중 2건 적중, 1건 반증)

같은 세션에서 사용자가 *"여기는 main 금지 예외 아니야?"* 라고 했으나 검증 결과 **틀렸다** — `docs/dev-logs/2026-05-15-main-branch-protection.md` 에 이 레포 자체에 branch protection 을 건 기록이 있고, AGENTS.md 의 예외 조항은 K8s/Cloud/Monitoring 에만 적용된다.

→ 사용자 지적이든 자기 판단이든 **검증 후 답한다**. 동조도 반박도 근거 없이 하지 않는다 (`deep-thinking.md`).

### 8. rule 신설은 AGENTS.md 등록과 원자적이어야 한다

`validate-rules-drift.sh` 가 `.claude/rules/*.md` → AGENTS.md 역참조를 강제하므로 **rule 만 머지하면 CI fail → branch protection 에 걸려 머지 불가**. 원본 계획의 "PR-3 + PR-4 sequential merge" 를 **단일 PR** 로 정정했다.

## 후속 작업

**P트랙 (자산 구조조정) — 0% 착수**

| | 작업 |
|---|---|
| ~~**P0**~~ | ~~drift 8건 + 미설치 command 16개~~ → **PR #32 로 완료 (2026-08-16)**. 진행 중 macOS bash 3.2 install.sh 완전 고장이 추가 발견돼 함께 수정 |
| P1 | description 224개 재작성 (`assets/skills/` 15개가 형식 레퍼런스) |
| P2 | skill 티어 재배치 260 → 150 |
| P3 | agent 분할 3축 |
| P4 | Migration 0002 재평가 |

**B트랙 — 2/4** (B0·B1 완료 / B2 PR-5~8 / B3 기타 4건)

~~주의: B2 의 PR-8 과 P0 가 `install.sh` 를 동시에 건드린다 — 순서 조정 필요.~~ → P0(PR #32)가 먼저 착수돼 flatten + bash 3.2 호환을 반영했으므로 **충돌 해소**. PR-8 은 그 위에 deprecation 로직만 얹으면 된다.

## 관련 자료

- PR: https://github.com/ressKim-io/ress-claude-agents/pull/31 (머지 `4372362`)
- [audit §8](../audit/2026-08-15-asset-tier-rebalance.md#8-선행-백로그-인수-b-트랙) — 백로그 단일 진입점
- [ADR 0008](../adr/0008-asset-tier-policy.md) — 티어 판정 정책
- [2026-05-20 dev-log](2026-05-20-kiro-adapter-and-install-sh-narrow-scope.md) — 8-PR 시퀀스 원본
- Kiro 공식 docs (검증일 2026-08-16): https://kiro.dev/docs/steering/ · https://kiro.dev/docs/skills/ · https://kiro.dev/docs/custom-agents/configuration-reference/
