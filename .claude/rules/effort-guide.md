# Effort Level Guide — Claude 4.x 단계별 사용 가이드

이 레포의 agents / skills 가 어떤 effort level 로 호출되어야 하는지의 카테고리별 매핑 표. 자산 개수는 `.claude/inventory.yml` `summary` 참조 (산문에 박지 않는다 — drift 원인).
사용자가 새 작업 / 새 agent / 새 skill 을 작성할 때 "이거 effort 뭘 줘야 하지?" 의 답.

상세 룰 / Opus 4.7 전용 가이드는 [`token-budget.md`](token-budget.md) 참조. 이 문서는 매핑에 집중.

> **출처**
> - effort 단계 정의: https://platform.claude.com/docs/en/docs/build-with-claude/effort (검증일 2026-05-15)
> - subagent frontmatter `effort` 필드: https://code.claude.com/docs/en/sub-agents (검증일 **2026-08-24**)

---

## 단계 정의 (Anthropic 공식)

| 레벨 | 정의 | 비용 (high 대비) | 권장 사용 상황 |
|---|---|---|---|
| `low` | 최소 추론, 속도 우선 | ~25% | 단순 조회 / lookup / 단순 자동화 / subagent 일부 |
| `medium` | 비용 민감 + 품질 타협 가능 | ~50% | 비용 민감 분석, FinOps 류 |
| `high` | intelligence-sensitive 작업 최소 기준 (Claude 4.x 기본값) | 100% (기본) | 일반 코딩 minimum, 분석 |
| `xhigh` | **Opus 4.7 coding/agentic 권장 시작점** (Claude Code 기본) | ~200% | 일반 expert / review / 트레이드오프 분석 |
| `max` | frontier 문제만 | xhigh 의 2x | cascade failure / cross-service / 트레이드오프 |

**모델별 지원**:
- Opus 4.7: 전체 (low / medium / high / xhigh / max)
- Opus 4.6 / Sonnet 4.6 / Haiku 4.5: low / medium / high / max (xhigh **없음**)
- 4.5 이하: low / medium / high 만

**Opus 4.7 특유의 동작**:
- xhigh / max → "go above and beyond" — 명시되지 않은 개선까지 시도
- low / medium → 더 strict 하게 요청만 수행 (literal interpretation)
- effort 를 명시 안 하면 Claude Code 기본 `xhigh` (코딩 작업), API 기본 `high`

**xhigh vs max 트레이드오프**: max 는 xhigh 대비 cost 2x 인데 quality 향상은 ~3%p. 비용 효율 대부분의 작업은 xhigh 가 sweet spot.

---

## Agents 매핑

| Effort | 카테고리 | 대상 (model) | 정당화 |
|---|---|---|---|
| `low` | 로깅 / 단순 자동화 | dev-logger (haiku) / git-workflow (haiku) / pr-review-bot (haiku) / anti-bot (sonnet) | 단순 기록 / commit msg / WAF 설정 — 깊은 추론 불필요 |
| `medium` | 비용 민감 분석 | cost-analyzer / finops-advisor / compliance-auditor / ci-optimizer (sonnet) | 정량 분석은 model 자체 capability 충분, effort 절약 |
| `xhigh` (기본) | 일반 expert / reviewer | sonnet 42 개 대다수 (code-reviewer / go-expert / java-expert / python-expert / k8s-reviewer / terraform-reviewer / database-expert / messaging-expert ...) | Opus 4.7 coding/agentic 권장 시작점 |
| `max` | frontier 추론 | architect-agent (opus) / debugging-expert (opus) / tech-lead (opus) | cascade failure / 트레이드오프 / 전사 RFC — opus + max 정당 |

**`effort` 는 공식 frontmatter 필드다.** subagent frontmatter 의 `effort` 는 해당 agent 가 활성화된 동안 **세션 effort 를 override** 한다. 따라서 본 표는 "무엇을 고를지" 의 기준이고, **실제 강제는 각 agent 의 frontmatter 에서 일어난다** — 표만 맞추고 frontmatter 를 비워두면 세션 기본값이 그대로 적용된다.

> ⚠️ **정정 (2026-08-24)**: 2026-05-15 ~ 2026-08-24 동안 본 문서는 "Claude Code 는 frontmatter 의 `effort` 필드를 직접 읽지 않으므로 본 표가 SOT" 라고 잘못 기술했다. 대부분의 agent 가 `effort` 미명시로 남아 세션 기본값에 방치된 원인이다.
> 경위: [2026-08-24 audit F3](../../docs/audit/2026-08-24-agent-harness-readiness.md#4-발견-f1f6)

---

## Skills 매핑 (카테고리 default)

| Effort | 카테고리 | 정당화 |
|---|---|---|
| `low` | `dx/` (changelog, commit, release notes) / `help:*` 슬래시 / 단순 lookup | template 적용 / 산식 조회 — 추론 불필요 |
| `xhigh` (기본) | `go/` / `kubernetes/` / `architecture/` (대다수) / `business/` / `security/` / `spring/` / `cicd/` / `observability/` 등 | 일반 코딩 / 패턴 적용 / 설계 |
| `max` | `architecture/cell-based-architecture` / `architecture/kafka-msa-patterns` / `migration/` (전 카테고리) | blast radius 큼 + 트레이드오프 cascade |

**예외**: `medium` skill 은 없음 — Skill 은 카테고리 default 또는 invoker 의 명시 override 로 충분.

---

## 적용 방법

### 1. Agent / Skill 호출 시
- 본 매핑 표 default 사용 (예: `code-reviewer` → xhigh)
- 사용자가 override 명시한 경우 (예: "low effort 로 빠르게 훑어줘") 그대로 적용
- agent frontmatter 에 `effort:` 가 있으면 **그것이 최우선** (세션 effort override)

### 2. 새 agent / skill 추가 시
- 본 표에서 effort 를 정한 뒤 **frontmatter `effort:` 에 명시**한다 — 표는 기준, frontmatter 가 강제
- `model` 과의 정합성 확인: `xhigh` 는 Opus 4.7 계열만 지원. haiku / sonnet 4.6 이하는 `high` 또는 `max`
- 새 카테고리면 본 표에 한 줄 추가 (작성자가 책임)
- 기준 모호 시 `xhigh` (Opus 4.7 권장 시작점) 사용

### 3. 작업 복잡도별 직접 호출 (slash command / agent prompt)

```
단순 lookup / 1-2 파일 조회                 → low
정량 분석 / cost / FinOps                    → medium
일반 코딩 / 단일 도메인 expert / review     → xhigh   (Claude Code 기본)
cascade / cross-service / 트레이드오프      → max     (드물게)
```

### 4. Subagent spawn 시
- token-budget.md §"Subagent 를 Context 절약 도구로" 참조
- **subagent 의 effort 는 main agent 와 독립** — 가벼운 fan-out 은 `low`, 깊은 분석은 `xhigh` 또는 `max`
- 10+ 파일 탐색만 fan-out 으로 (단일 함수 리팩토링에 subagent 금지)

---

## Decision Tree

```
이 작업이 단순 조회 / template 적용 / 산식 인가?
├── YES ──────────────────────────────────────────→ low
└── NO
    │
    이 작업이 정량 분석 / 비용 계산 / 컴플라이언스 audit 인가?
    ├── YES ──────────────────────────────────────→ medium
    └── NO
        │
        이 작업이 cross-service / cascade / 트레이드오프 분석 인가?
        ├── YES ──────────────────────────────────→ max
        └── NO (일반 코딩 / 단일 도메인 분석 / review) → xhigh   ← 기본
```

---

## 자기 점검 (작업 시작 전)

- [ ] 이 작업의 **blast radius** 가 큰가? (큼 → max / xhigh 상향)
- [ ] **단순 lookup** 인데 xhigh 쓰고 있나? (낮춰서 25% 비용)
- [ ] **subagent 에 max** 주고 있나? (대부분 low 로 충분, fan-out 의 합산 비용 고려)
- [ ] **agent frontmatter `model: haiku`** 인데 `xhigh` 요구하나? (model + effort 정합성 — haiku 는 xhigh 미지원)

---

## 참고 / cross-link

- 단계 / 비용 / Adaptive thinking 상세: [`token-budget.md`](token-budget.md)
- Subagent spawn 가이드: [`token-budget.md`](token-budget.md) §"Subagent 를 Context 절약 도구로"
- Token Budget skill (코드 예시 / 비용 계산): `/token-budget` 슬래시
- 공식 출처: https://platform.claude.com/docs/en/docs/build-with-claude/effort (2026-05-15 fetched)
