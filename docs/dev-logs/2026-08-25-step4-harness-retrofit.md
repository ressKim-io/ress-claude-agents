---
date: 2026-08-25
category: meta
tier: 2
importance: major
status: resolved
tags: [harness, agents, frontmatter, effort, enforcement, validator, audit]
related:
  - dev-logs/2026-08-24-step5-install-scope-and-ci-gates.md
  - dev-logs/2026-08-24-step3-agent-tier-demotion.md
  - dev-logs/2026-08-24-step1-agent-spec-modernization.md
  - audit/2026-08-24-agent-harness-readiness.md
---

# Step 4 — harness 리트로핏 (frontmatter 실행값 / 본문 spec / 티어 결손 축)

[2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) §6 Step 4.
Step 1~3·5 완료 후 남은 마지막 실행 Step.

## 시작 시점 수치

| 항목 | 값 |
|---|---|
| `effort` | 5 / 34 |
| `disallowedTools` / `permissionMode` | 0 / 34 |
| `Verification Criteria` | 1 / 34 |
| `LEGACY_AGENTS_NO_BODY_SPEC` 잔여 | 34 (경고 99건) |
| borderline (한쪽 축만) | 13 |

## 착수 직후 뒤집힌 전제 — F10

Step 4 의 첫 항목은 "리뷰어 11개에 `disallowedTools` 또는 `permissionMode` 로 산문을 실행 강제로 승격 (F4)" 이었다.
공식 docs 재확인(2026-08-25) 결과 **그 해법이 스펙상 성립하지 않는다**:

| 필드 | 확인된 경계 |
|---|---|
| `disallowedTools` | 도구 이름 / MCP 패턴 단위만. `Bash(gh pr comment:*)` 같은 명령 단위 지정자 **미지원** (settings.json 문법과 다르다). 34/34 가 이미 `tools` 를 명시하므로 도구 단위 denylist 는 대부분 no-op |
| `permissionMode` | 부모가 `bypassPermissions`/`acceptEdits` 면 override 불가. 부모가 auto mode(Pro/Max/Team 기본)면 frontmatter 값이 **무시됨** |

즉 리뷰어의 구멍은 `Bash` 자체인데 두 필드 모두 그 안쪽에 닿지 못한다.
명령 단위에 닿는 건 `hooks: PreToolUse` 뿐이고, 그것도 `bypassPermissions` 하 동작이 공식 문서에 없다.

**사용자 결정 (2026-08-25)**: "일단 없애고, 나중에 다른 방식으로 근본적인 해결을 다른 세션에서. 지금 설정이 너무 1차원적이다."
→ F4 를 Step 4 에서 제거하고 **Step 6 (실행 강제 근본 설계)** 로 분리했다. 훅 스크립트도 만들지 않았다.

## 파생 발견

### F9 — effort 매트릭스 drift

`effort` 를 전개하려면 `effort-guide.md` 의 model×effort 매핑을 소비해야 하는데, 그 표가 2026-05-15 기준이었다.

| 항목 | 구판 | 현행 (2026-08-25 fetch) |
|---|---|---|
| `xhigh` 지원 | Opus 4.7 **만** | Fable 5 / Mythos 5 / Opus 5 / 4.8 / 4.7 / **Sonnet 5** |
| Haiku 4.5 | low~max 지원 | effort 파라미터 **supported models 목록에 부재** |
| Claude Code 기본 | `xhigh` | Sonnet 5 기준 **`high`** |

구판 기준으로는 `model: sonnet` 에 `xhigh` 를 붙이는 게 무효 조합이었다. **stale 매트릭스를 전개하면 34개에 무효값이 박히는 도미노**라 정정을 선행했다.

"Claude Code 기본이 xhigh" 라는 오해가 특히 문제였다 — 명시하지 않으면 `high` 로 떨어지므로, frontmatter 명시가 선택이 아니라 필수다.

### F8 — 스키마 sensor 가 1건만 보고 있었다

`effort: xhigh` 를 code-reviewer 에 붙이자마자 `validate-schemas.sh` 가 FAIL 했다. 원인은 `agent-manifest.v1.json` 이 2026-05 스펙(8필드 + `additionalProperties: false`)에 멈춰 있던 것.

더 나쁜 건 **이미 `effort` 를 쓰던 agent 5개가 CI 를 통과해왔다는 사실** — 스크립트가 `code-reviewer.md` **1건만 샘플 검증**했고 그 파일에 우연히 `effort` 가 없었다. sensor 가 있는데 보고 있지 않았다.

→ 스키마를 공식 16필드로 갱신하고, 검증을 **agent 전수(34) + 개수 회귀 가드**로 확대했다.

## 한 일

### 1. effort 34/34

- `effort-guide.md` / `token-budget.md` / `AGENTS.md` 3곳의 매트릭스·기본값 정정 (F9)
- `medium` 4건 (cost-analyzer / finops-advisor / compliance-auditor / ci-optimizer) — 정량 분석
- `xhigh` 24건 — 리뷰·조사 (반복 도구 호출이 필요한 long-horizon agentic)
- `model: haiku` 2건의 `effort: low` 는 유지하되 ⚠️ 미검증으로 표기 (API docs 의 supported models 부재만 확인, Claude Code 런타임 동작은 문서 없음)

### 2. 본문 3섹션 1/34 → 34/34

`Permission Boundary` / `Escalation` 은 AGENT-SPEC §5 표준 문구, `Verification Criteria` 는 **agent 별 개별 작성**.
5개 그룹으로 나눠 커밋 (리뷰어 11 / 조사형 5 / 전략형 7 / 정량형 4 / 도메인 6).

Verification Criteria 를 보일러플레이트로 찍지 않은 이유 — 검증 기준이 도메인마다 다르다:
- cascade 분석 → 상관/인과 구분 + 반증 가능성
- 감사 → 증거 유무로 통과/미통과/**미확인** 3분류
- 부하 테스트 → p50~p99 필수, 에러 0건도 명시
- 마이그레이션 → 버전 클레임에 출처 또는 ⚠️ 표기

### 3. borderline 13 → 0

조사 프로토콜 10건 신설 + 출력 계약 3건 신설. 프로토콜은 전부 **1단계에 입력 확인 게이트**를 두고 미충족 시 `[BLOCKED]` 반환하게 설계했다 — 이 agent 들은 출력 계약만 있어서 근거 없는 결론을 형식만 갖춰 반환할 수 있는 상태였다.

특히:
- `compliance-auditor` — 증거 없는 통제를 통과로 처리하지 않는 3분류
- `service-mesh-expert` — 선언 YAML 이 아니라 proxy config 실측으로 판정
- `platform-engineer` — Golden Path 미정의 시 전략 agent 로 이관

### 4. LEGACY 배열 완전 소진

경고 99 → 0. 빈 배열이 `set -u` 에 걸리는 문제를 가드로 처리.
Step 3 에서 삭제된 `python-expert` 의 잔존 엔트리도 정리했다.

## 검증

각 그룹 커밋마다 validator 5종 + shellcheck + inventory 재생성.
**음성 테스트 4건**으로 sensor 가 실제로 검출하는지 확인:

| 테스트 | 결과 |
|---|---|
| 미지 frontmatter 필드 (`bogusField`) | FAIL 검출 |
| `effort` enum 위반 (`ultrahigh`) | FAIL 검출 |
| `Verification Criteria` 삭제 | FAIL 검출 |
| 3섹션 없는 신규 agent 추가 | 3건 모두 FAIL 검출 |

### 5. 버전 클레임 전수 재검증

audit §2.4 대상. 클레임이 3개 agent 에 집중돼 있었다.

| 클레임 | 현행 (2026-08-25 검증) | 조치 |
|---|---|---|
| K8s 1.30 (6회) | 1.36 최신 / 지원 1.34~1.36 | **EOL** — 정정 |
| Spring Boot 3.3 | 4.1 최신 | **2025-06-30 EOL** — 정정 |
| Java 21 | LTS 25 (GA 2025-09-16) | 정정 |
| PostgreSQL 16 / Kotlin 2.0 / Python 3.12+ | 18 / 2.4 / 3.14 | 정정 |
| Next.js 15 | 16 LTS, 15 는 2026-10-21 종료 | 15·16 병기 |
| React 19 | 19.2.8 | ✅ 유지 |

값만 갱신하면 3개월 뒤 같은 drift 가 나므로 구조를 함께 바꿨다:
- `migration-expert` / `frontend-expert` 에 **Verified Version Baseline** 표 (최신 / 지원 범위 / 출처 URL / 검증일 / 분기 재검증)
- 예시 매트릭스에 "그대로 복사하지 말고 착수 시점에 재확인"
- 호환성 표의 미확인 조합은 빈칸이 아니라 `⚠️ 미검증` — **빈칸은 "호환된다" 로 읽힌다**

## 결과

| 항목 | 시작 | 종료 |
|---|---|---|
| `effort` | 5 / 34 | **34 / 34** |
| `Permission Boundary` / `Escalation` / `Verification Criteria` | 1 / 34 | **34 / 34** |
| LEGACY 배열 경고 | 99 | **0** |
| borderline (한쪽 축만) | 13 | **0** |
| agent 스키마 검증 커버리지 | 1 / 34 (구 스펙) | **34 / 34 (16필드)** |
| 미검증 버전 클레임 | 다수 | **0** |
| `disallowedTools` / `permissionMode` | 0 / 34 | **0 / 34 (의도적)** |

마지막 줄이 핵심이다. 0 을 유지한 건 방치가 아니라 **닿지 않는 필드를 붙여 강제되는 척하지 않겠다는 판단**이다.

## 남은 것

- **Step 6 미착수** — 실행 강제 근본 설계. 막다른 길 3건과 후보 3안이 audit 에 기록됨. ADR 선행이 착수 조건

## 학습

**"막지 못하는 것을 막는다고 적은 frontmatter 는 산문보다 나쁘다."**
지켜지고 있다고 착각하게 만들기 때문이다. AGENT-SPEC §1.2 에 이 문장을 MUST 로 넣었다.

**sensor 의 커버리지도 sensor 다.** F8 은 "검증 스크립트가 있다"와 "검증되고 있다"가 다르다는 사례다. 1건 샘플 검증은 34건 중 33건을 보지 않는 것과 같은데, PASS 로그 때문에 검증되고 있다고 보였다.

**stale 기준을 소비하기 전에 기준부터 검증한다.** F9 를 먼저 잡지 않았다면 34개 agent 에 무효 effort 값이 박혔을 것이다 — [`deep-thinking.md`](../../.claude/rules/deep-thinking.md) §4 자기 강화 추정 루프의 전형이다.
