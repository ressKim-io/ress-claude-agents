---
date: 2026-08-24
category: meta
tier: 1
importance: critical
status: open
tags: [harness-engineering, agent-quality, skill-format, asset-tier, frontmatter-drift, spec-verification]
related:
  - audit/2026-08-24-agent-harness-readiness.md
  - audit/2026-08-15-asset-tier-rebalance.md
  - dev-logs/2026-08-17-p0-execution-and-review-loop.md
  - migration/0002-progress.md
---

# harness 엔지니어링 적합성 audit — skill 260개가 로드되지 않는다는 발견

## Context

사용자 질문 두 가지로 시작한 세션이다.

1. "지금 있는 agent 들이 **harness 엔지니어링에 쓸 수 있을 만큼** 품질이 괜찮은가. 이게 harness 엔지니어링이 유행하기 전에 만든 거라 방식이 다를 확률이 높다"
2. "agent 일 필요가 없는데 **과하게 잡은 것**은 없는가"

agent 자산은 2026-05-17 이후 3개월간 손대지 않은 상태였다. 선행 [2026-08-15 audit](../audit/2026-08-15-asset-tier-rebalance.md) 은 drift·개수·description 축을 봤고, harness 축은 이번이 처음이다.

세션 명목: **최신화 및 정리**.

## Issue

### 1. harness 3축 중 guides 만 있다

공식 출처 4건(Anthropic engineering 2편 + Claude Code 문서 2편)을 2026-08-24 fetch 해 현행 기준을 먼저 확정했다.

```
Agent = Model + Harness
Harness = guides(지시) + sensors(검증) + enforcement(구속)
```

핵심 명제는 **"에이전트가 실수하면 프롬프트가 아니라 환경을 고친다"** 인데, 이 레포는 19,819줄 전부가 guides 다.

| 축 | 실측 |
|---|---|
| sensors — `## Verification Criteria` | **1 / 49** |
| sensors — agent 행동 eval | **0건** |
| enforcement — `permissionMode`/`disallowedTools`/`maxTurns`/`isolation` | **0 / 49** |
| memory — `memory:` | **0 / 49** |

공식 subagent frontmatter 16개 필드 중 4개(`name` `description` `tools` `model`)만 쓰고 있었다.

### 2. `effort` 는 이제 공식 필드다 — rule 의 사실 오류

`.claude/rules/effort-guide.md:45`:

> Claude Code 는 frontmatter 의 `effort` 필드를 직접 읽지 않으므로 (model 만 표준 — F6) 본 표가 사람 / 스크립트 / agent prompt 의 SOT

공식 문서에 명시적으로 있다 — *"Effort level when this subagent is active. **Overrides the session effort level.**"*

`AGENT-SPEC.md` 의 F6 검증일이 2026-05-15 → **3개월 만에 drift**. [`multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md) 의 "외부 도구 사양은 분기별 재검증 (MANDATORY)" 을 **정작 Claude Code 자신에게 적용하지 않은** 결과다.

### 3. 산문 규약을 강제 메커니즘으로 승격하지 않음 — 자기 rule 위반

`multi-tool-adapter.md` 는 이렇게 쓴다:

> MUST port 시 산문 규약을 대상 도구의 **강제 메커니즘으로 승격**할 수 있는지 검토한다. 강제로 옮기면 규약 위반이 구조적으로 차단된다.

Kiro 의 `permissions` 를 그 예로 들면서, Claude Code 에도 `permissionMode` / `disallowedTools` 가 있는데 안 쓴다.

실측: **`Bash` 49/49**. 읽기 전용이어야 할 리뷰어 11개가 전부 무제한 `Bash` 보유 → 기술적으로 `gh pr comment` 실행 가능. [`user-approval.md`](../../.claude/rules/user-approval.md) 를 산문으로만 막고 있다.

### 4. 49개 중 19개는 agent 일 이유가 없다

판정 기준을 **"조사 프로토콜 + 출력 계약"** 둘 다 보유로 잡았다. 둘 다 없으면 위임 단위가 아니라 레퍼런스 문서다.

| 판정 | 개수 | 줄수 |
|---|---|---|
| 정당한 agent | 19 | 7,553 |
| borderline | 11 | 4,649 |
| **agent 일 이유 없음** | **19** | **7,617** |

휴리스틱 오탐을 의심해 6개를 손으로 열어봤고 전부 판정이 유지됐다. `architect-agent` 의 "Step 1/2/3" 은 Event Storming **방법론 설명**이지 실행 프로토콜이 아니었고(535줄 중 327줄이 코드 샘플), `otel-expert` 는 H2 가 `역할;사용 시점;전문 분야;…;참조 스킬` 로 **스킬 문서 구조 그대로**였다.

과잉 분할 2건도 확인 — load-tester 4개(1,087줄, 내용은 설치·DSL 튜토리얼), database 2개(동일 구조 2벌).

### 5. 🔴 skill 260개 / 97,912줄이 로드되지 않는다

과잉을 찾다가 **정반대 문제**를 발견했다.

공식 skill 경로는 **`.claude/skills/<skill-name>/SKILL.md`** — 한 단계 디렉터리 + `SKILL.md` 다. 카테고리 하위 디렉터리는 지원되지 않는다.

이 레포는 `.claude/skills/<카테고리>/<이름>.md` — **두 단계 + flat 파일**이라 두 가지 모두 위반이다.

직접 관측으로도 확인됐다. 이 세션에 로드된 skill 목록에 `.claude/commands/` 유래 51개(`go:lint` `review-pr` `where` …)는 전부 있는데, `.claude/skills/` 260개(`effective-go` `kafka` `redis-streams` …)는 **한 개도 없다**.

`install.sh:848-855` 의 flatten-symlink 도 flat `.md` 를 만들 뿐이라 설치된 프로젝트에서도 동일하게 미로드다.

**선행 audit 의 진단이 더 근본적인 원인 위에 서 있었다.** 2026-08-15 audit 은 "224/260 이 템플릿 description 이라 발견이 안 된다" 고 했지만, description 이 아무리 좋아도 **애초에 로드되지 않는다**.

### 6. 🔴 Migration 0002 P7 의 목표 경로도 규격 위반

`.gitignore:39` 가 `.claude/skills/*/*/SKILL.md` 를 제외하며 "P7 까지는 단일 파일 형식이 SSOT" 라고 주석한다.

그 경로는 `skills/<카테고리>/<이름>/SKILL.md` = **skills/ 아래 두 단계**다. 규격은 한 단계뿐이므로 **이 경로도 로드되지 않는다**.

**지금 P7 을 설계대로 실행하면 260개를 변환하고도 여전히 안 붙는다.**

## Action

본 세션은 **측정 + 백로그 정의 + 문서화** 까지 수행했다. 실제 자산 변경은 다음 세션부터.

- [audit/2026-08-24-agent-harness-readiness.md](../audit/2026-08-24-agent-harness-readiness.md) 작성 — 측정 결과, 발견 F1~F6, 실행 백로그 Step 1~4, 재개 절차, 재측정 명령
- 본 dev-log 작성

### 사용자 결정 (2026-08-24)

| 항목 | 결정 |
|---|---|
| 진행 방식 | Step 2개씩. **문서화 → commit → 실행** 순서 |
| 세션 분할 | 한 세션 분량을 넘으므로 재개 가능하도록 문서화 필수 |
| 주요 변경 | 전부 dev-log 남김 |
| Step 2 커밋 분할 | **카테고리 단위** (22개) |

### 평탄화 가능성 (사전 확인)

| 확인 항목 | 결과 |
|---|---|
| 260개 파일명 중복 | **0건** |
| `.claude/commands/` 51개와 이름 충돌 | **0건** |

이름 재설계 없이 그대로 평탄화 가능하다.

## Result

⏳ **진행 중** (status: open). Step 1~4 미착수.

측정만으로 확정된 것:

| # | 발견 | 심각도 |
|---|---|---|
| F1 | skill 260개 미로드 | 🔴 기능 결함 |
| F2 | P7 목표 경로도 규격 위반 | 🔴 계획 결함 |
| F3 | `effort` 필드 사실 오류 | 🟡 |
| F4 | 산문 규약 미승격 (리뷰어 11개 무제한 Bash) | 🟡 |
| F5 | AGENT-SPEC 3섹션 1/49, LEGACY 배열로 CI 우회 | 🟡 |
| F6 | agent 19개 티어 오배치 (7,617줄) | 🟡 |

### 유지 결정 — 재작성 금지

harness 축에서 **이미 앞서 있는** 부분이라 정리 중 훼손하지 않는다.

- **generator ↔ evaluator 분리 4쌍** (`code-reviewer`↔language expert, `k8s-reviewer`↔`k8s-security-reviewer`, `dockerfile-reviewer`↔`container-security-reviewer`, `cicd-reviewer`↔`cicd-security-reviewer`) — Anthropic harness-design 글의 핵심 패턴과 정확히 일치
- description 의 hand-off 위계
- `tools` 명시적 listing 49/49
- CI drift job 6종 — **sensor 를 붙일 자리가 이미 마련됨**

## 학습

1. **자산 개수가 자산 가치가 아니다.** 260 skills / 97,912줄이 3개월 이상 사문화돼 있었는데 inventory·CI·audit 어느 것도 잡지 못했다. 전부 "파일이 존재하는가" 만 검사하고 **"도구가 실제로 로드하는가" 를 검사하지 않았다.** → Step 2 에 "1개 먼저 검증" 단계를 강제로 넣은 이유.
2. **자기 rule 을 자기에게 적용하지 않았다.** `multi-tool-adapter.md` 의 "분기별 외부 사양 재검증" 과 "산문→강제 승격" 둘 다 타 도구(Kiro)용으로만 쓰고 Claude Code 자신에겐 적용한 적이 없다. F1·F2·F3 이 전부 여기서 나왔다.
3. **선행 audit 의 진단도 검증 대상이다.** 2026-08-15 audit 의 description 개선(P1)은 로드되지 않는 파일의 description 을 고치는 작업이었다. 상위 전제를 확인하지 않으면 정확한 측정도 헛돈다.

## Related Files

- `docs/audit/2026-08-24-agent-harness-readiness.md` — 실행 백로그 SOT
- `.claude/rules/effort-guide.md:45` — F3
- `.claude/templates/AGENT-SPEC.md` — Step 1
- `.gitignore:36-41` — F2
- `install.sh:839-860` — F1
- `scripts/validate-skill-frontmatter.sh` — F5 (`LEGACY_AGENTS_NO_BODY_SPEC`)
