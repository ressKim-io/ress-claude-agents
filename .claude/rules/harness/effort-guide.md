# Effort Level Guide — Claude 5.5 세대 기준

이 레포의 agents 가 어떤 effort level 로 호출되어야 하는지의 매핑 표. 자산 개수는 `.claude/inventory.yml` `summary` 참조 (산문에 박지 않는다 — drift 원인).
새 작업 / 새 agent 를 작성할 때 "이거 effort 뭘 줘야 하지?" 의 답.

상세 룰은 [`token-budget.md`](token-budget.md) 참조. 이 문서는 매핑에 집중.

> **출처** (검증일 **2026-11-04**, 직전 2026-08-25). 검증 기록: [2026-11-04 사양 검증](../../../docs/audit/2026-11-04-claude-spec-verification.md)
> - effort 단계: https://platform.claude.com/docs/en/build-with-claude/effort
> - Claude Code 기본값: https://code.claude.com/docs/en/model-config
> - agent / skill frontmatter: https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/skills

---

## 단계 정의

| 레벨 | 권장 사용 상황 |
|---|---|
| `low` | 단순 조회, 분류, 템플릿 적용, 속도 우선 |
| `medium` | 범위가 명확한 코딩·분석. Opus 5.5 의 시작점이자 기본값 |
| `high` | 어렵거나 긴 작업, 리뷰, 조사. **본 레포 agent 기본** |
| `xhigh` / `max` | **품질 향상을 측정한 작업에만.** "Reserve `xhigh` and `max` for work where you've measured a quality gain." |

**effort 는 token budget 이 아니라 행동 신호다.** "It shapes behavior but doesn't guarantee a token count." 같은 이름이라도 모델마다 사고량이 다르다.

> ⚠️ **정정 (2026-11-04)**: 이전 판은 레벨별 비용 배수와 "xhigh 대비 max 의 품질 향상폭" 을 "Anthropic 공식" 표로 실었다. 현행 공식 문서에는 그런 수치가 없어 삭제했다. `xhigh` 를 레포 기본으로 삼던 정책도 Opus 4.7 기준이어서 폐기했다.

**모델별 지원** (✅ 2026-11-04 공식 docs, Fable 5.2 는 2026-11-11 보강):

| 모델 | `low`/`medium`/`high` | `xhigh` | `max` |
|---|---|---|---|
| Fable 5.2 / Fable 5.1 / Opus 5.5 / Sonnet 5.5 / Haiku 5.5 | ✅ | ✅ | ✅ |
| Fable 5 / Opus 5 / Sonnet 5 / Opus 4.8 / Opus 4.7 | ✅ | ✅ | ✅ |
| Opus 4.6 / Sonnet 4.6 | ✅ | ❌ (`high` 로 동작) | ✅ |
| Haiku 4.5 | ❌ effort 자체 미지원 | ❌ | ❌ |

미지원 레벨은 "falls back to the highest supported level at or below the one you set".

> ⚠️ `sonnet` / `haiku` / `opus` alias 는 제공자마다 다른 모델을 가리킨다. `haiku` 는 Anthropic API 밖에서 Haiku 4.5 이고, `sonnet` 은 Bedrock·Agent Platform·Foundry 에서 Sonnet 4.5 다. Haiku 4.5 에서 frontmatter `effort` 가 어떻게 처리되는지는 **문서에 없다.**

**기본값**:

| 모델 | API | Claude Code |
|---|---|---|
| Fable 5.2 | `high` | `medium` |
| Opus 5.5 | `medium` | `medium` |
| Sonnet 5.5 | `high` | `medium` |
| Haiku 5.5 | `medium` | `medium` |
| 이전 모델 (Fable 5.1 포함) | — | `high` (Opus 4.7 만 `xhigh`) |

명시하지 않으면 이 기본값으로 돈다. 다른 모델로 도는 subagent 는 세션 effort 를 물려받지 않는다. **이것이 전 agent 에 `effort` 를 명시하는 이유다.**

---

## Agents 매핑

| Effort | 카테고리 | 대상 (model) | 정당화 |
|---|---|---|---|
| `low` | 로깅 / 단순 자동화 | dev-logger (haiku) / git-workflow (haiku) | 단순 기록 / commit msg — 깊은 추론 불필요 |
| `medium` | 비용 민감 분석 | cost-analyzer / finops-advisor / compliance-auditor / ci-optimizer (sonnet) | 범위가 명확한 정량 분석 |
| `high` (본 레포 기본) | 일반 expert / reviewer, cascade·트레이드오프 분석 | 나머지 전부. `model: sonnet` 대다수와 architect-agent / debugging-expert / tech-lead (opus) | 리뷰·조사는 반복 도구 호출이 필요한 긴 작업 |
| `xhigh` / `max` | 없음 | — | 측정 근거가 생긴 agent 만 올린다 |

**`effort` 는 공식 frontmatter 필드다.** subagent frontmatter 의 `effort` 는 해당 agent 가 활성화된 동안 **세션 effort 를 override** 한다. 따라서 본 표는 "무엇을 고를지" 의 기준이고, **실제 강제는 각 agent 의 frontmatter 에서 일어난다.**

---

## Skills: `effort` 를 두지 않는다

"Effort level for the rest of the current turn. Overrides the session effort level" — skill 이 로드되면 **그 턴이 끝날 때까지** 세션 설정을 덮어쓴다.

- 지식 skill 은 호출한 작업의 effort 를 따라야 한다. 높이면 비용이 늘고, 낮추면 진행 중인 작업의 품질이 떨어진다
- API 에서는 top-level effort 변경이 prompt cache 를 깨뜨린다. Claude Code 의 skill effort 전환에도 적용되는지는 ⚠️ 문서에 없다
- 예외 검토: `context: fork` 로 자기 subagent 에서 도는 skill. 이때 값은 fork 된 subagent 에만 적용된다

---

## 적용 방법

### 1. Agent 호출 시
- 본 매핑 표 default 사용 (예: `code-reviewer` → high)
- 사용자가 override 명시한 경우 (예: "low effort 로 빠르게 훑어줘") 그대로 적용
- agent frontmatter 에 `effort:` 가 있으면 **그것이 최우선** (세션 effort override)

### 2. 새 agent 추가 시
- 본 표에서 effort 를 정한 뒤 **frontmatter `effort:` 에 명시**한다 — 표는 기준, frontmatter 가 강제
- 기준 모호 시 `high`
- 새 카테고리면 본 표에 한 줄 추가 (작성자가 책임)

### 3. 작업 복잡도별 직접 호출 (slash command / agent prompt)

```
단순 lookup / 1-2 파일 조회                   → low
범위가 명확한 코딩 / 정량 분석 / FinOps       → medium
어렵거나 긴 작업 / 리뷰 / 조사 / 트레이드오프 → high    (본 레포 기본)
품질 향상을 측정한 작업                       → xhigh / max
```

### 4. Subagent spawn 시
- token-budget.md §"Subagent 를 Context 절약 도구로" 참조
- **subagent 의 effort 는 main agent 와 독립** — 가벼운 fan-out 은 `low`, 깊은 분석은 `high`
- 10+ 파일 탐색만 fan-out 으로 (단일 함수 리팩토링에 subagent 금지)

---

## Decision Tree

```
단순 조회 / template 적용 / 산식 인가?
├── YES ──────────────────────────────→ low
└── NO
    │
    범위가 명확하고 짧은 작업인가?
    ├── YES ──────────────────────────→ medium
    └── NO (어렵거나 길거나 리뷰·조사) → high   ← 기본
                                          │
                                          품질 향상을 측정했나?
                                          └── YES → xhigh / max
```

---

## 자기 점검 (작업 시작 전)

- [ ] **단순 lookup** 인데 `high` 쓰고 있나? (낮춘다)
- [ ] `xhigh` / `max` 를 쓰는데 **측정 근거**가 있나? (없으면 `high`)
- [ ] **skill 에 `effort`** 를 넣지 않았나?
- [ ] **agent frontmatter 의 `model` 이 그 `effort` 를 지원하나?** (모델별 지원 표)

---

## 참고 / cross-link

- 토큰 / 캐시 / API 파라미터: [`token-budget.md`](token-budget.md)
- Token Budget skill (코드 예시 / 비용 계산): `/dx:token-budget` 슬래시
- 공식 출처 분기 재검증 대상 — **다음 2027-02**
