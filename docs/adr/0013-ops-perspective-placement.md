# ADR 0013 — AIOps·에이전트 운영 관점의 배치: 새 plugin 대신 `dx`·`security` 에 둔다

- **Status**: Accepted
- **Date**: 2026-11-06
- **Driver**: [AIOps·에이전트 운영 검증 기록](../audit/2026-11-06-aiops-agent-ops-verification.md) — 새 skill 3개가 인용할 외부 사실과 그 출처·검증일·상태
- **Related**: [ADR 0008](0008-asset-tier-policy.md), [ADR 0009](0009-enforcement-layer-placement.md), [ADR 0012](0012-native-plugin-structure.md)

## Context

2026-11-05 외부 사례 조사에서 근거가 쌓인 것은 read-only 조사·제안과 좁게 열거된 실행이었다. 실행 권한을 넓힌 곳은 범위를 좁히고 모델 밖에서 강제했다. 조사 원문은 커밋하지 않고, skill 이 인용할 사실만 Driver 의 검증 기록에 옮긴다.

레포에는 이 관점을 받을 자리가 없었다 (2026-11-06 확인).

| 공백 | 확인한 내용 |
|---|---|
| 행동 단위 자율성 등급과 강제 수단 | 자율성·성숙도 척도가 `ai`·`observability`·`sre`·`cicd` 의 여러 skill 에 따로 있다. 단계마다 실제로 막는 수단(`permissions.deny`, hook 등)을 짝지은 척도는 없다 |
| Claude Code 무인 실행 운영 | `plugins/` 에 `claude -p`, `--bare`, Agent SDK 언급이 없다 |
| 운영 MCP 연결 보안 | `security` plugin 에 MCP, prompt injection, LLM 언급이 없다 |

배치에 걸리는 레포 사실은 다음과 같다.

- 이 레포는 `dx` 만 켠다 (`.claude/settings.json` 의 `enabledPlugins`)
- rule 은 plugin 에 실을 수 없다 ([ADR 0012](0012-native-plugin-structure.md) §Decision 3). 설치본에는 rule 과 `permissions` 가 없다 (같은 ADR §Consequences)
- 다른 plugin 을 가리키는 `/plugin:skill` 은 그 plugin 이 없으면 열리지 않는다 (같은 곳)
- skill 이름과 description 은 기본값으로 컨텍스트의 1% 안에 들어가야 한다. 넘치면 덜 쓰는 skill 부터 description 이 빠진다 (`.claude/templates/SKILL-SPEC.md` §목록 예산)
- `dx` 의 상시 토큰은 이미 plugin 중 가장 크다. 2026-11-04 추정치로 약 4,950 이고, 다음은 `observability` 약 4,202 다 ([Migration 0003](../migration/0003-plugin-restructure.md))

## Decision

새 관점 plugin 을 만들지 않는다. AIOps·에이전트 운영 관점의 자산을 기존 plugin 에 나눠 둔다.

| plugin | 경로 | 맡는 것 |
|---|---|---|
| `dx` | `plugins/dx/skills/agent-autonomy-tiers` | 공통 기반: 행동 단위 자율성 등급과 단계별 강제 수단 |
| `dx` | `plugins/dx/skills/claude-unattended-ops` | 공통 기반: Claude Code 무인 실행의 경로, 권한 배치, 실패한 run 판정 |
| `security` | `plugins/security/skills/ops-mcp-security` | 운영 시스템에 붙는 MCP 연결 보안 |

1. 도메인별 행동은 기존 domain skill 에 남긴다. 새 skill 은 그 skill 을 `/sre:runbook-driven-ops` 처럼 `/plugin:skill` 로 가리킨다. 레포 안의 다른 자율성 척도는 고치지 않고 축이 다르다는 것만 밝힌다. 기존 자산 수정은 무승인 실행 예시 2건으로 한정한다.
2. 새 agent 를 만들지 않는다. AGENT-SPEC 템플릿은 모든 agent 의 Permission Boundary 에 "kubectl 은 읽기 전용(get / describe / logs / top)만" 을 그대로 쓰라고 요구한다 (`.claude/templates/AGENT-SPEC.md` §Permission Boundary). 이 규약 아래에서 새 운영 agent 는 조사형일 수밖에 없고, 조사형으로 선언된 agent 는 이미 있다 (`sre:incident-responder`, `k8s:k8s-troubleshooter`). 설치본에서 이 문구는 안내문이다 (ADR 0012 §Consequences).

## 대안 비교

| 안 | 강점 | 약점 | 판단 |
|---|---|---|---|
| a. 새 `aiops`/`agentops` plugin | 관점이 한 폴더에 모인다. `dx` 예산이 늘지 않는다 | 이 레포에서 켜지 않는다. 켜면 예산 문제가 돌아온다 (ADR 0012 §Decision 2). README 의 plugin 표에서 AIOps 는 이미 `observability` 영역이다. `token-budget`·`threat-modeling` 같은 관련 skill 참조가 전부 plugin 경계를 넘는다. 루트 `README.md`·`README.ko.md` 의 plugin 표와 `scripts/generate-plugin-readmes.py` 의 `RULES`·`REQUIRES` 맵을 손으로 고쳐야 한다. 생성기는 plugin 폴더의 README 만 만든다 | ❌ |
| b. `.claude/rules` 규범 | 이 레포에서는 자동 로딩된다. skill 목록 예산을 쓰지 않는다 | 설치본에 실리지 않는다. 세 주제는 분기가 있는 결정 트리라 ADR 0008 §Decision 1 의 판정으로는 skill 이다. 외부 작업 승인 규범은 이미 `.claude/rules/core/user-approval.md` 에 있다 | ❌ |
| c. `ai` plugin | 에이전트 거버넌스(`/ai:dx-ai-agents`)와 Claude Code 운영 전략(`/ai:ai-first-playbook`)이 있고, 자율성 척도 여럿도 여기 있다. 새 plugin 작업이 없다 | `plugin.json` 의 범위가 RAG·Vector DB·LLMOps·모델 서빙 같은 AI 기능 구축이라, plugin 으로 설치하면 무관한 skill 까지 목록 예산을 쓴다. 이 레포에서 켜지 않는다. MCP 보안이 `security` 의 위협 모델링·시크릿 관리와 떨어진다 | ❌ |
| **d. `dx` 2 + `security` 1** | `dx` 의 두 skill 은 이 레포가 직접 쓴다. 이 레포도 `claude -p` 를 돌리고(`scripts/verify-plugins.sh`, `scripts/verify-enforcement-runtime.sh`) `permissions` 를 둔다. `token-budget`·`pr-review-automation`, `threat-modeling`·`secrets-management` 와 같은 plugin 이라 상대 링크로 묶인다. 새 plugin 등록이 없다 | `dx` 상시 토큰이 더 커지고, 예산을 넘으면 description 이 빠진다. `security` skill 은 이 레포에서 로드되지 않는다. `dx` 와 `security` 사이의 참조는 상대 plugin 이 없으면 열리지 않는다 | ✅ 채택 |

a·c 의 "이 레포에서 켜지 않는다" 는 d 의 `security` skill 에도 해당한다. d 는 그 범위를 skill 하나로 줄인다.

## Consequences

**얻는 것**
- 설치자는 새 plugin 을 따로 고르지 않는다. `dx`·`security` 를 설치하면 새 skill 이 함께 온다
- `dx` 의 두 skill 은 이 레포가 켜서 쓴다. ADR 0012 가 "아무도 실행하지 않는 경로는 썩는다" 에 대응한 방식이 그대로 적용된다
- 새 plugin 등록, 루트 README 표, 생성기 맵을 고치지 않는다

**잃는 것 / 위험**
- `dx` 에 description 2개가 더해진다 (계획 초안 기준 136자, 160자). 목록 예산을 넘었는지는 대화형 `/doctor`·`/skill-doctor` 로만 확인된다. Migration 0003 의 전후 비교도 2026-11-06 현재 실행하지 않았다 ⚠️
- `security` skill 은 이 레포에서 로드되지 않아 `--plugin-dir plugins/security` 로 확인한다
- 새 skill 이 가리키는 도메인 skill 은 그 plugin 이 없으면 열리지 않는다. 생성되는 plugin README 의 "함께 쓰면 좋은 plugin" 이 안내한다
- 설치본에는 rule 과 `permissions` 가 없다. 그래서 새 skill 의 일관성 기준은 사용자 자신의 settings 와 승인 규칙으로 쓰고, 설치본에서 막지 못하는 것을 막는다고 쓰지 않는다

**ADR 0008 과의 긴장**

ADR 0008 §검증의 미결 목표 "skill 총수 ≤ 160" 과 반대 방향이다 (같은 ADR §Consequences 는 "150 선" 으로 적는다). 현재 총수는 이미 이 목표를 넘고 (`.claude/inventory.yml` 의 `summary`), 이 결정은 skill 을 셋 더한다. 새 skill 로 둔 근거는 Context 의 세 공백이다. 총수 목표의 존폐는 이 ADR 에서 정하지 않는다.

**진행 순서**

PR 하나에 목적 하나를 두고, 앞 PR 이 머지된 뒤 `main` 에서 다음 브랜치를 딴다. `scripts/validate-catalog.sh` 가 없는 `/plugin:skill` 참조를 실패시키므로 참조되는 skill 부터 넣는다.

| 순서 | PR | 내용 |
|---|---|---|
| 0 | PR-A | ADR 0009 `ask` 재측정 반영. 측정은 사용자가 대화형 세션에서 한다 |
| 1 | PR-B | 검증 기록과 이 ADR |
| 2 | PR-C | `security/ops-mcp-security` |
| 3 | PR-D | `dx/agent-autonomy-tiers`. 강제 수단 표의 `ask` 행은 PR-A 결과를 따른다 |
| 4 | PR-E | `dx/claude-unattended-ops`, 앞 두 skill 에 역참조 추가 |
| 5 | PR-F | 무승인 실행 예시 2건 수정(`/observability:aiops-remediation`, `/ai:dx-ai-agents-orchestration`)과 dev-log |

**범위 밖 (후속)**
- Permission Boundary 선언과 본문이 어긋난 agent: `sre:incident-responder`, `k8s:k8s-troubleshooter` 는 kubectl 읽기 전용을 선언하고 본문에서 확인 후 `kubectl delete`·`scale` 을 허용한다. `sre:cost-analyzer` 는 결과만 반환한다고 선언하고 본문에 승인된 절감안 자동 적용을 둔다
- replay 평가 스위트 (`claude plugin eval`)
- 기존 skill 확장: `/sre:runbook-driven-ops`·`/sre:incident-postmortem`, `/ai:llmops` 의 AI SLO·메트릭 이름 정렬

**재평가 시점**: `/doctor`·`/skill-doctor` 에서 `dx` description 이 빠진 것이 확인되거나, ADR 0008 재점검(2026-11-15)에서 총수 목표를 유지하기로 하면 이 배치를 다시 본다.

## 검증

```bash
./scripts/verify-plugins.sh dx security   # 새 skill 로드 (로컬, 모델 호출 없음)
./scripts/validate-catalog.sh             # description 형식과 /plugin:skill 참조
python3 scripts/generate-plugin-readmes.py validate
```

description 예산은 사용자가 대화형 `/doctor`, `/skill-doctor` 로 확인한다.

## Sources

- 외부 사실: [AIOps·에이전트 운영 검증 기록](../audit/2026-11-06-aiops-agent-ops-verification.md)
- 레포 사실: 본문에 적은 파일과 ADR, 2026-11-06 확인
