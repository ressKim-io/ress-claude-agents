# Agent harness 적합성 audit (2026-08-24)

## 요약

| 항목 | 수치 |
|---|---|
| Agents | 49 / 19,819줄 (평균 404줄) |
| Skills | 260 / 97,912줄 |
| Commands | 51 (`.claude/commands/`) |
| Agent 마지막 수정 | 2026-05-17 (3개월 경과) |

사용자 요청("harness 엔지니어링에 쓸 수 있을 만큼 agent 품질이 괜찮은지 / agent 일 필요 없는데 과하게 잡은 것 확인")에 따라 자산을 **① 2026 harness 기준 적합성**, **② 티어 적합성** 두 축으로 측정했다.

핵심 결론 4가지:

1. **harness 3축 중 guides 만 있다.** `Agent = Model + Harness`, harness = guides(지시) + sensors(검증) + enforcement(구속). 이 레포는 19,819줄 전부가 guides 다. sensors·enforcement 는 **사실상 0**.
2. **frontmatter 가 2026-05 스펙에 멈춰 있다.** 공식 16개 필드 중 4개만 사용. harness 핵심 4개(`memory` `hooks` `permissionMode`/`disallowedTools` `maxTurns`)가 통째로 **0/49**.
3. **49개 중 14개는 agent 일 이유가 없다.** 조사 프로토콜도 출력 계약도 없는 순수 레퍼런스 5,395줄이 agent 로 등록돼 있다. (초판은 19개 / 7,617줄로 셌으나 판정 스크립트가 `## Output Template` 표기를 놓친 오탐이었다 — 2026-08-24 Step 3 착수 시 정정. §3.3 참조)
4. **skill 260개 / 97,912줄이 로드되지 않는다.** 디렉터리 구조가 공식 규격 위반이다. 그리고 **Migration 0002 P7 이 향하는 목표 경로도 규격 위반**이라, 지금 P7 을 그대로 실행하면 260개를 변환하고도 여전히 안 붙는다.

3과 4는 같은 문제의 양면이다 — 레퍼런스가 agent 안에 5,395줄 들어앉아 있고, 정작 레퍼런스가 있어야 할 skill 97,912줄은 죽어 있다.

> 본 문서는 **측정 + 실행 백로그 정의**를 수행한다. §6 백로그는 세션을 넘겨 재개할 수 있도록 체크박스로 관리한다.
> 선행 audit: [2026-08-15 자산 티어 재배치](2026-08-15-asset-tier-rebalance.md) (drift / 개수 / description 축). 본 audit 은 harness / 티어 축으로 그와 중복되지 않는다.

---

## 1. 검증한 현행 기준

전 항목 **2026-08-24 fetch**. `deep-thinking.md` §2 출처 기록 의무 적용.

| 출처 | 검증일 | 상태 | 확인 내용 |
|---|---|---|---|
| [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) | 2026-08-24 | ✅ | subagent frontmatter **16개 필드** |
| [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) | 2026-08-24 | ✅ | skill 경로 = `.claude/skills/<skill-name>/SKILL.md`, custom commands → skills 병합, `context: fork` |
| [anthropic.com/engineering/effective-harnesses-for-long-running-agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) | 2026-08-24 | ✅ | 세션 간 영속 아티팩트, 검증 루프, bounded work |
| [anthropic.com/engineering/harness-design-long-running-apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) | 2026-08-24 | ✅ | generator↔evaluator 분리, harness 가정 만료 |
| [github.com/ai-boost/awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering) | 2026-08-24 | ✅ | 역량 축 분류 (evals / memory / permissions / observability) |
| [faros.ai/blog/harness-engineering](https://www.faros.ai/blog/harness-engineering) | 2026-08-24 | ⚠️ 2차 | `Agent = Model + Harness` 정식화, Hashimoto 2026-02 기원 |

⚠️ Hashimoto 2026-02 원문("engineering the harness" 명명 기원)은 2차 출처로만 확인했다. **본 audit 의 모든 판정 근거는 위 ✅ 4건(Anthropic 공식 2건 + Claude Code 공식 문서 2건)에서만 나왔다.**

### 1.1 harness 정의 (판정 기준)

```
Agent = Model + Harness
Harness = guides(지시)  +  sensors(검증)  +  enforcement(구속)
```

핵심 명제: **에이전트가 실수하면 프롬프트가 아니라 환경을 고친다.** 그래야 같은 실수가 구조적으로 재발 불가능해진다.

Anthropic 공식 2편에서 확인한 실행 원칙:

- **generator ↔ evaluator 분리** — "자기 작업을 평가시키면 에이전트는 품질이 명백히 평범해도 자신 있게 칭찬한다"
- **harness 가정은 만료된다** — "모든 harness 구성요소는 모델이 스스로 못 하는 일에 대한 가정을 인코딩한다. 그 가정은 stress test 대상"
- **done 기준을 코드 작성 전에 계약으로 합의**
- 세션 간 **구조화된 handoff / 영속 아티팩트**

---

## 2. 측정 결과 — harness 3축

전 항목 2026-08-24 실측. 재현 명령은 [부록 A](#부록-a-재측정-명령).

| 축 | 지표 | 실측 | 판정 |
|---|---|---|---|
| **guides** | agent 49개 / 19,819줄, description hand-off 체계, tools 명시 49/49 | — | ✅ 상급 |
| **sensors** | `## Verification Criteria` 보유 | **1 / 49** | ❌ |
| | agent 행동 eval | **0건** | ❌ |
| **enforcement** | `permissionMode` / `disallowedTools` / `maxTurns` / `isolation` | **0 / 49** | ❌ |
| **memory** | `memory:` (세션 간 학습) | **0 / 49** | ❌ |
| **context 경제성** | `skills:` (progressive disclosure) | **0 / 49** | ⚠️ 역행 |

### 2.0 Step 4 이후 재측정 (2026-08-25)

§2 이하의 표는 **audit 시점(2026-08-24, agent 49개)** 의 측정이다 — 기록으로 보존한다. Step 3·4 를 거친 현재 값은 아래.

| 축 | 지표 | audit 시점 | Step 4 이후 | 판정 변화 |
|---|---|---|---|---|
| guides | agent 개수 / 줄수 | 49 / 19,819 | **34 / 14,182** | Step 3 에서 레퍼런스 5,395줄 이관(19,819→12,736), Step 4 에서 프로토콜·계약 1,446줄 추가 |
| sensors | `## Verification Criteria` | 1 / 49 | **34 / 34** | ❌ → ✅ |
| | agent frontmatter 스키마 검증 | 1건 샘플 (구 스펙) | **34건 전수 (16필드)** | ❌ → ✅ (F8) |
| | agent 행동 eval | 0건 | 0건 | ❌ — Step 6 |
| enforcement | `permissionMode` / `disallowedTools` / `maxTurns` | 0 / 49 | **0 / 34 (의도적)** | 🔴 스펙상 불가 판명 (F10) |
| | **`.claude/settings.json` `permissions` 규칙** | 0 | **22 (deny 11 / ask 11)** | ❌ → ✅ Step 6. agent 수와 무관하게 전 agent 에 적용 |
| memory | `memory:` | 0 / 49 | 0 / 34 | ❌ — Step 6 |
| context 경제성 | `skills:` | 0 / 49 | 0 / 34 | ⚠️ 미착수 |
| — | `effort` | 6 / 49 | **34 / 34** | ⚠️ → ✅ |
| — | 티어 borderline (한쪽 축만) | 16 | **0** | ✅ |
| — | `LEGACY_AGENTS_NO_BODY_SPEC` 경고 | 144 (49 기준) → 99 (34 기준) | **0** | ✅ |
| — | 미검증 버전 클레임 | K8s 1.30 등 다수 | **0** — Verified Baseline 표로 대체 | ✅ |

frontmatter enforcement 0/34 는 방치가 아니라 "닿지 않는 필드를 붙여 강제되는 척하지 않는다" 는 판단의 결과다 (F10). **강제는 frontmatter 밖 — 세션 설정에서 일어난다** (Step 6 / [ADR 0009](../adr/0009-enforcement-layer-placement.md)).

남은 ❌ 는 `memory` / 행동 eval / `skills` 세 축이다 — Step 7+ 로 이월.

### 2.1 frontmatter 채택률

공식 16개 필드 대비:

| 필드 | 사용 | 비고 |
|---|---|---|
| `name` `description` `tools` `model` | 49 / 49 | ✅ |
| `effort` | 6 / 49 | outlier(opus 3 + haiku 4)만 |
| `disallowedTools` `permissionMode` `maxTurns` `skills` `mcpServers` `hooks` `memory` `background` `isolation` `color` `initialPrompt` | **0 / 49** | 미사용 11개 |

harness 관점에서 빠진 것 중 중요한 4개:

| 필드 | harness 역할 | 현재 대체물 |
|---|---|---|
| `memory: project` | 세션 간 학습 = "실수하면 영구 수정"의 **실제 메커니즘** | 없음 (dev-logs 를 사람이 수동 반영) |
| `hooks` | sensor — agent 스코프 lifecycle 검증 | 없음 |
| `disallowedTools` / `permissionMode` | constrain | **산문** |
| `maxTurns` | bounded autonomy | 없음 |

### 2.2 도구 권한 분포

| 도구 | 보유 | 비고 |
|---|---|---|
| `Bash` | **49 / 49** | 읽기 전용이어야 할 리뷰어 11개 포함 |
| `Write` | 5 / 49 | |
| `WebFetch` | 1 / 49 | |

리뷰어 11개(`code-reviewer` `k8s-reviewer` `k8s-security-reviewer` `terraform-reviewer` `gitops-reviewer` `observability-reviewer` `cicd-reviewer` `cicd-security-reviewer` `dockerfile-reviewer` `container-security-reviewer` `network-security-reviewer`)가 무제한 `Bash` 를 보유한다. 기술적으로 `gh pr comment` 실행이 가능하며, [`user-approval.md`](../../.claude/rules/user-approval.md) §"에이전트에 외부 게시 권한 위임 금지"를 **산문으로만** 막고 있다.

### 2.3 spec 준수율

[`AGENT-SPEC.md`](../../.claude/templates/AGENT-SPEC.md) 가 본문 **필수**라고 규정한 3섹션:

| 섹션 | 보유 |
|---|---|
| `## Permission Boundary` | 1 / 49 (`git-workflow`) |
| `## Escalation` | 1 / 49 (`git-workflow`) |
| `## Verification Criteria` | 1 / 49 (`git-workflow`) |

`scripts/validate-skill-frontmatter.sh` 는 나머지 48개를 `LEGACY_AGENTS_NO_BODY_SPEC` 배열에 등재해 soft warning 으로 우회한다. 실행하면 **144건 경고가 CI 비차단으로 흘러간다**.

### 2.4 가정 만료 (staleness)

| 지표 | 실측 |
|---|---|
| agent 마지막 수정 | 2026-05-17 (3개월) |
| 출처 URL 0건인 agent | **24 / 49** |
| 검증일 마커 보유 | 6 / 49 |
| 본문의 미검증 버전 클레임 | `K8s 1.30`(6회) `Java 21` `Spring Boot 3.x` `React 19+` `Next.js 15` `Terraform 1.7+` 등 |

[`deep-thinking.md`](../../.claude/rules/deep-thinking.md) 가 요구하는 ✅verified / ⚠️unverified 마킹이 agent 자산에는 적용된 적이 없다.

---

## 3. 측정 결과 — 티어 적합성 ("과하게 잡은 것")

### 3.1 판정 기준

agent 는 **격리된 컨텍스트에서 조사를 수행하고 요약을 반환**하는 위임 단위다. 따라서:

| 신호 | 의미 |
|---|---|
| **조사 프로토콜** (`## Review Process` / `Protocol` / `Decision Tree` / `Methodology`) | 어떻게 파고들지 |
| **출력 계약** (`## Output Format` / `Report Template` / **`Output Template(s)`**) | 무엇을 돌려줄지 |

둘 다 없으면 위임 단위가 아니라 **레퍼런스 문서**다. 한쪽만 있으면 borderline 이다.

> ⚠️ **정정 (2026-08-24, Step 3 착수 시)**: 초판 정규식은 `Output Format|Report Template|출력` 이었는데 이 레포가 실제로 쓰는 표기는 **`## Output Template(s)`** 라 매칭되지 않았다. 그 결과 출력 계약을 실제로 가진 agent 5개가 강등 대상으로 잘못 분류됐다. 부록 A 의 재측정 명령도 함께 정정했다.

### 3.2 판정 결과

| 판정 | 개수 | 줄수 | 대상 |
|---|---|---|---|
| **정당한 agent** | 19 | 7,553 | 리뷰어 11 + 조사형 4 + ADR 생산형 3 + `git-workflow` |
| **borderline** (한쪽만) | 16 | 6,871 | `ci-optimizer` `compliance-auditor` `cost-analyzer` `dev-logger` `frontend-expert` `infra-roadmap-planner` `load-tester` `migration-expert` `pr-review-bot` `service-mesh-expert` `tech-lead` + **재판정 5** (§3.3.1) |
| **agent 일 이유 없음** | **14** | **5,395** | 아래 §3.3 |

합계 19 + 16 + 14 = 49 / 7,553 + 6,871 + 5,395 = 19,819줄.

### 3.3 강등 대상 14개

`anti-bot`(288) `database-expert`(311) `database-expert-mysql`(287) `go-expert`(605) `java-expert`(605) `load-tester-gatling`(270) `load-tester-k6`(292) `load-tester-ngrinder`(375) `messaging-expert`(475) `otel-expert`(242) `python-expert`(504) `redis-expert`(372) `saga-agent`(493) `ticketing-expert`(276)

휴리스틱 오탐을 의심해 6개를 손으로 검증했다:

| agent | 손 검증 결과 |
|---|---|
| `otel-expert` | H2 가 `역할;사용 시점;전문 분야;핵심 지식;권장 도구;질문 예시;**참조 스킬**` — 스킬 문서 구조 그대로. 판정 유지 |
| `saga-agent` | deliverable 언급 0건. Temporal 패턴 레퍼런스. 판정 유지 |
| `architect-agent` | "Step 1/2/3" 은 Event Storming **방법론 설명**이지 실행 프로토콜이 아님. 535줄 중 327줄이 protobuf/gRPC 코드 샘플 → **조사 프로토콜 축은 확증. 출력 계약 축은 미확인이었고 §3.3.1 에서 뒤집혔다** |
| `product-engineer` | RICE / MoSCoW / Shape Up 프레임워크 모음 → 동일 (§3.3.1) |
| `platform-engineer` | Backstage Quick Start = 설치 가이드 → 동일 (§3.3.1) |
| `finops-advisor` | Maturity Model + Tool Selection = 진단 가이드 → 동일 (§3.3.1) |

**손 검증의 한계**: 6건 모두 *조사 프로토콜* 축만 재확인했고 *출력 계약* 축은 정규식 결과를 그대로 신뢰했다. 정규식이 틀린 축을 손 검증이 덮지 못해 오탐이 살아남았다.

#### 3.3.1 재판정 5개 — 출력 계약 보유 (강등 보류)

정규식이 놓친 `## Output Template(s)` 를 실제로 가진 agent 다. 5개 모두 ` ```markdown ` fence 안에 **반환할 보고서 구조**가 들어 있어 §3.1 기준상 borderline(출력 계약 O / 조사 프로토콜 X) 이다.

| agent | 줄 | 출력 계약 |
|---|---|---|
| `architect-agent` | 535 | `## Output Template: 서비스 분해 제안서` — Bounded Context 표 / 통신 설계 표 / 마이그레이션 로드맵 |
| `finops-advisor` | 357 | `## Output Templates` → FinOps 성숙도 평가 보고서 (Gap 표 + 90일 로드맵) |
| `mlops-expert` | 423 | `## Output Templates` → GPU Cluster Design (요구사항 / 인프라 표 / 스케줄링 / 서빙) |
| `platform-engineer` | 430 | `## Output Templates` → IDP 설계 문서 (현재 상태 / 목표 아키텍처 / Golden Paths / 로드맵) |
| `product-engineer` | 477 | `## Output Templates` → Story Map / RICE Sheet / Shape Up Pitch / MVP Definition / Feature Spec (5종) |

**조치** (사용자 결정 2026-08-24): 강등하지 않는다. agent 는 유지하되 **본문의 skill 중복분(코드 샘플·튜토리얼)을 삭제하고 skill 참조로 대체**한다 — 출력 계약과 조사 절차만 남긴다.

### 3.4 과잉 분할 2건

| 건 | 현황 | 근거 |
|---|---|---|
| load-tester 4개 | 허브 + k6 + gatling + ngrinder = 1,087줄 | 내용이 "설치 및 설정 / DSL / 사용법" 튜토리얼. 도구 선택은 프로젝트당 1회 |
| database 2개 | `database-expert`(PostgreSQL) + `-mysql` = 598줄 | 동일 구조 2벌 (Quick Reference / Tuning / Pooling / Monitoring / Anti-Patterns) |

> 두 건 모두 **강등으로 자동 해소된다** — agent 를 skill 로 내리면 agent 쪽 과잉 분할은 0이 된다. 다만 skill 쪽에서는 분리를 유지한다: 엔진(PostgreSQL/MySQL)·도구(K6/Gatling/nGrinder)가 다르면 description 매칭이 갈리므로 합치면 오히려 발견이 나빠진다 (§3.5).

### 3.5 강등 14개 × skill 260개 중복 대조 (2026-08-24)

Step 3 착수 시 전수 대조했다. 판정 근거는 H2/H3 구조 비교 + 키워드 실측(`grep -c`)이다.

**B. 폐기 — 기존 skill 이 이미 커버 (5건 / 1,906줄)**

| agent | 줄 | 중복 skill | 흡수할 고유분 |
|---|---|---|---|
| `saga-agent` | 493 | `msa-saga`(502) — 10섹션 중 8 일치 | Temporal 결정성 제약 / Workflow Versioning / Search Attributes / 멱등키 생성전략 + Dedup 테이블 |
| `otel-expert` | 242 | `observability-otel-scale`(트래픽 규모별 + Tail Sampling) `observability-cost` `observability-otel` | **없음** — 본문이 `## 참조 스킬` 포함 index 구조 |
| `python-expert` | 504 | `python-async`(TaskGroup·asyncpg·Semaphore·aiohttp·redis) `python-patterns`(Pydantic·타입) `python-performance`(__slots__·generators·프로파일링·풀) `python-testing` | Framework Selection 표 / `pyproject.toml` |
| `load-tester-k6` | 292 | `load-testing`(K6 기본·고급·K8s Operator) | Grafana Cloud K6 100만 VU 구성 / GitHub Actions 통합 |
| `load-tester-ngrinder` | 375 | `load-testing-analysis`(nGrinder·결과분석) | K8s 배포 / 웹 UI / AWS Auto Scaling / Jenkins |

**C. 신규 skill 로 이관 — 기존 커버 없음 (7건 / 2,279줄)**

| agent | 줄 | 기존 커버 실측 | 신규 skill |
|---|---|---|---|
| `redis-expert` | 372 | `redis-streams` 는 Streams 전용. 캐싱·Sentinel·Cluster·Redlock·Operator·메모리 **0** | `infrastructure/redis-operations` |
| `database-expert` | 311 | `infrastructure/database` 는 일반 인덱스·N+1. PG 파라미터·PgBouncer·Percona Operator **0** | `infrastructure/postgresql-operations` |
| `database-expert-mysql` | 287 | 동일. InnoDB 튜닝·ProxySQL·InnoDB Cluster **0** | `infrastructure/mysql-operations` |
| `messaging-expert` | 475 | `rabbitmq` 는 quorum 16회만 — queue depth / unacked / memory alarm **각 0**. kafka 계열은 lag·rebalance 일부 | `messaging/broker-troubleshooting` (패턴 4종 DLQ·Outbox·Idempotent·Retry 는 `msa-event-driven`·`msa-resilience` 중복 → 삭제) |
| `ticketing-expert` | 276 | `high-traffic-design`·`distributed-lock`·`msa-saga` 가 각 1섹션 | `business/virtual-waiting-room` |
| `anti-bot` | 288 | `rate-limiting` 과 Redis sliding window 1섹션만 | `security/anti-bot` (Rate Limiting 섹션 삭제 후 참조) |
| `load-tester-gatling` | 270 | **없음** — Gatling skill 부재 | `sre/load-testing-gatling` |

**D. 부분 이관 — 분할 (2건 / 1,210줄)**

| agent | 줄 | 중복 | 고유분 행선지 |
|---|---|---|---|
| `go-expert` | 605 | `effective-go`(인터페이스·에러·Worker Pool) `concurrency-go` `msa-resilience`(Circuit Breaker) `go-microservice`(Graceful Shutdown) `secure-coding`(Go 5행 요약표) | sync.Pool·Zero-alloc·GC튜닝·pprof·Performance Targets·OTel 에러통합 → `go/go-performance` / Security Review Checklist 7섹션 → `go/go-security` |
| `java-expert` | 605 | `effective-java`(VT 개요) `concurrency-spring` `spring-cache` `msa-resilience` `spring-security` `secure-coding`(Java 5행 요약표) | VT vs WebFlux 결정표·HikariCP+VT 주의·G1GC/ZGC 튜닝·Performance Targets → `spring/jvm-performance` / Security Review Checklist 8섹션 → `spring/spring-security-review` |

> 보안 체크리스트 행선지는 사용자 결정(2026-08-24): `secure-coding` 의 언어별 표는 언어당 5행 요약이라 깊이가 다르다. 요약은 남기고 상세는 언어 skill 에서 발견되게 한다.

**참조 갱신 범위**: `plugins/*.yml` + `.claude/workflows/*.yml` 55건, 타 자산 상호참조 58건.

---

### 3.6 borderline 재판정 (2026-08-24 Step 3)

정정된 정규식(§3.1)으로 borderline 을 다시 판정했다. 두 건이 **양쪽 축을 다 갖고 있어 "정당한 agent" 로 승격**했고, 한 건은 정규식 오탐이 반대 방향으로 드러나 **강등**했다.

| agent | 판정 변화 | 근거 |
|---|---|---|
| `migration-expert` | borderline → **정당** | `## Migration Assessment Protocol` + `## Output Templates` 양쪽 보유. 초판 정규식이 `Output Templates` 를 놓쳤다 |
| `tech-lead` | borderline → **정당** | `## RFC/ADR Workflow` + `## Output Templates` 양쪽 보유. 동일 원인 |
| `pr-review-bot` | borderline → **강등** | `## Workflow 파일 생성 헬퍼` 는 GitHub Actions YAML 생성기이지 조사 프로토콜이 아니다 (정규식 오탐). 본문 296/486줄(61%)이 도구 설정 카탈로그 → `dx/pr-review-automation` 으로 이관 |

**Step 3 종료 시점 판정 (agent 35 → 34)**

| 판정 | 개수 | 줄수 | 후속 |
|---|---|---|---|
| 정당한 agent | 21 | 8,737 | 유지 |
| borderline (한쪽만) | 13 | 3,996 | **Step 4 에서 결손 축 보강** |
| 강등 대상 | **0** | 0 | — |

borderline 13 의 결손 축 (Step 4 작업 목록):

| 결손 | agent | 필요 작업 |
|---|---|---|
| 조사 프로토콜 없음 (출력 계약만) | `ci-optimizer` `compliance-auditor` `cost-analyzer` `load-tester` `service-mesh-expert` `architect-agent` `finops-advisor` `mlops-expert` `platform-engineer` `product-engineer` | `## Review Process` / `Decision Tree` 신설 |
| 출력 계약 없음 (프로토콜만) | `dev-logger` `frontend-expert` `infra-roadmap-planner` | `## Output Format` 신설 |

> `architect-agent` / `finops-advisor` / `mlops-expert` / `platform-engineer` / `product-engineer` 5건은 본 Step 에서 **본문 중복 삭제까지 완료**했고(§3.3.1), 남은 것은 조사 프로토콜 신설뿐이다.

---

### 3.7 본문 구성 — reference dump

| agent | 총줄 | 코드블록 | 비율 |
|---|---|---|---|
| `load-tester-ngrinder` | 375 | 300 | 80% |
| `infra-roadmap-planner` | 537 | 393 | 73% |
| `mlops-expert` | 423 | 292 | 69% |
| `python-expert` | 504 | 343 | 68% |
| `go-expert` | 605 | 398 | 65% |
| `java-expert` | 605 | 385 | 63% |

`skills:` frontmatter 로 필요할 때만 로드하는 progressive disclosure 가 정답이지만 **0/49** 다. 그리고 레포에 skill 260개가 있는데 **agent 가 skill 을 참조하는 건 0건** — 두 자산군이 분리 운영되고 있다.

---

## 4. 발견 (F1~F11)

| # | 발견 | 위치 | 심각도 |
|---|---|---|---|
| **F1** | **skill 260개가 로드되지 않는다** | `.claude/skills/<cat>/<name>.md` | 🔴 기능 결함 |
| **F2** | **Migration 0002 P7 의 목표 경로도 규격 위반** | `.gitignore:39` | 🔴 계획 결함 |
| **F3** | `effort` 는 공식 frontmatter 필드다 — rule 의 사실 오류 | `.claude/rules/effort-guide.md:45` | 🟡 |
| **F4** | 산문 규약을 강제 메커니즘으로 승격하지 않음 (자기 rule 위반) | 리뷰어 11개 | 🟡 |
| **F5** | AGENT-SPEC 필수 3섹션이 1/49, LEGACY 배열로 CI 우회 | `validate-skill-frontmatter.sh` | 🟡 |
| **F6** | agent 15개가 티어 오배치 (5,881줄) | §3.3 / §3.6 | 🟡 |
| **F7** | 티어 판정 정규식이 `Output Template` 표기를 놓쳐 **7개**를 오분류 (강등 5 + borderline 2) 하고, `Workflow` 부분일치로 `pr-review-bot` 1개를 반대로 오분류 | §3.1 / §3.6 / 부록 A | 🟡 |
| **F8** | `validate-schemas.sh` 가 agent 34개 중 **1건만 샘플 검증**해, 구 스키마(8필드 + `additionalProperties:false`)를 위반한 agent 5개를 통과시켰다 | `scripts/validate-schemas.sh` / `schemas/agent-manifest.v1.json` | 🟡 |
| **F9** | `effort-guide.md` 의 model×effort 매트릭스 drift — "xhigh 는 Opus 4.7 만" / "Haiku 4.5 는 low~max 지원" 이 현행 스펙과 불일치 | `.claude/rules/effort-guide.md` | 🟡 |
| **F10** | **F4 의 해법이 스펙상 성립하지 않는다** — `disallowedTools` 는 도구 단위, `permissionMode` 는 부모 세션에 종속. 둘 다 `Bash` 안쪽 명령에 닿지 못한다 | AGENT-SPEC §1.2 / §Step 6 | 🔴 설계 결함 |
| **F11** | **이미 있던 강제력 레이어가 3.5개월째 0% 로 작동했다** — `control-plane` 의 PreToolUse `admit` hook 이 존재하지 않는 env var 로 배선돼 있고, hook 명령이 참조하는 npm 패키지도 미배포다. 수집 이벤트 0건 | `control-plane/src/install-hook.ts` / Migration 0002 P5~P6.5 | 🔴 무효 통제 |

### F1 상세 — skill 260개 미로드

공식 규격은 **`.claude/skills/<skill-name>/SKILL.md`** — 한 단계 디렉터리 + `SKILL.md` 파일이다. 카테고리 하위 디렉터리는 지원되지 않는다.

이 레포는 `.claude/skills/<카테고리>/<이름>.md` — **두 단계 + flat 파일**이라 두 가지 모두 위반한다.

직접 관측으로도 확인된다. 2026-08-24 세션에 로드된 skill 목록에는 `.claude/commands/` 유래 51개(`go:lint` `review-pr` `where` …)가 전부 있지만 `.claude/skills/` 의 260개(`effective-go` `kafka` `redis-streams` …)는 **한 개도 없다**.

`install.sh:848-855` 의 flatten-symlink 도 `skills/<name>.md` 라는 flat 파일을 만들 뿐이라 설치된 프로젝트에서도 동일하게 미로드다.

**영향**: 97,912줄 / 22 카테고리가 사문화. 선행 audit(2026-08-15)의 "224/260 이 템플릿 description 이라 발견이 안 된다"는 진단은 **더 근본적인 원인 위에 서 있었다** — description 이 좋아도 애초에 로드되지 않는다.

### F2 상세 — P7 목표 경로 오류

`.gitignore:39` 는 `.claude/skills/*/*/SKILL.md` 를 제외하며 "P4 adapter 산출물이지만 P7 까지는 단일 파일 형식이 SSOT" 라고 주석한다.

`.claude/skills/*/*/SKILL.md` 는 `skills/<카테고리>/<이름>/SKILL.md` = **skills/ 아래 두 단계**다. 규격은 한 단계뿐이므로 이 경로도 로드되지 않는다.

**지금 P7 을 설계대로 실행하면 260개를 변환하고도 여전히 안 붙는다.** 착수 전 목표 경로를 `.claude/skills/<이름>/SKILL.md` 로 정정해야 한다.

**평탄화 가능성 확인 (2026-08-24 실측)**: 260개 파일명 중복 **0건**, `.claude/commands/` 51개와 이름 충돌 **0건**. 이름 재설계 없이 그대로 평탄화 가능하다.

### F11 상세 — 죽은 강제력 레이어 부검 (2026-08-25)

Step 6 착수 조사 중 발견했다. **이 레포엔 이미 PreToolUse hook 이 있었고, 도입 이래 단 한 번도 발동한 적이 없다.**

경위: Migration 0002 P5(2026-05-06)에서 `control-plane` 의 `admit` 서브명령 + `install-hook.ts` 가 도입됐고, P6(2026-05-08)에서 baseline sink([ADR 0004](../adr/0004-admit-baseline-sink.md))가 붙었으며, P6.5 는 "setup 완료, 1주 수집 중" 상태로 3.5개월 정지해 있었다.

| 결함 | 실측 |
|---|---|
| `install-hook.ts:80-84` 가 만드는 hook 명령이 `$CLAUDE_TOOL` / `$CLAUDE_TOOL_INPUT_path` / `$CLAUDE_ACTIVE_SKILL` 를 참조 | 공식 문서상 **존재하지 않는 env var**. command hook 입력은 **stdin JSON** 이고, Claude Code 가 설정하는 건 `CLAUDE_PROJECT_DIR` `CLAUDE_PLUGIN_ROOT` `CLAUDE_PLUGIN_DATA` `CLAUDE_CODE_REMOTE` `CLAUDE_CODE_BRIDGE_SESSION_ID` `CLAUDE_EFFORT` 뿐이다 |
| hook 명령이 `npx @ress/claude-agents admit …` | 해당 패키지 **npm 미배포** (`npm view` → `E404`). 명령 자체가 실행되지 않는다 |
| P6.5 "baseline setup 완료 (2026-05-08)" 4항목 | 싱크 파일 없음 / `.claude/settings.local.json` 없음 / `~/.zshrc` export 없음 / lock 파일 없음. **수집 이벤트 0건** |
| control-plane vitest 111건 all green | `admit()` **순수 함수만** 테스트한다. hook 배선을 검증하는 테스트는 0건 |

**왜 아무도 몰랐나**: `PreToolUse` hook 은 exit 1 이나 실행 실패를 **비차단 오류로 처리하고 그대로 진행**한다. 즉 깨진 hook 은 아무 소리 없이 통과시킨다. 산문 규칙은 최소한 확률적으로라도 지켜지는데, 깨진 hook 은 0% 이면서 더 안전해 보인다 — **F4 보다 나쁜 상태였다.**

**교훈 (Step 6 설계에 반영)**:
1. 강제력 자산은 **위반 fixture 없이 도입하지 않는다.** 순수 함수 테스트는 배선 결함을 못 잡는다.
2. 선언형 설정(`permissions.deny`)을 스크립트 hook 보다 선호한다 — 잘못된 규칙은 startup warning 으로 드러나지만 깨진 hook 은 침묵한다.
3. 외부 도구 사양(env var / 입력 형식)은 [`multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md) §분기 재검증 대상이다. 2026-05 배선은 검증 없이 작성됐다.

**조치**: 사용자 결정(2026-08-25) — **폐기**. ADR 0002/0005 Rejected, ADR 0004 Superseded, control-plane 에서 제거. 상세는 §6 Step 6-A.

---

## 5. 유지할 것 (재작성 금지)

harness 축에서 **이미 앞서 있는** 부분이다. 정리 작업 중 훼손하지 않는다.

| 자산 | 근거 |
|---|---|
| **generator ↔ evaluator 분리 4쌍** — `code-reviewer`↔language expert, `k8s-reviewer`↔`k8s-security-reviewer`, `dockerfile-reviewer`↔`container-security-reviewer`, `cicd-reviewer`↔`cicd-security-reviewer` | Anthropic harness-design 글의 핵심 패턴과 정확히 일치. 2026 기준으로도 앞서 있음 |
| description 의 **hand-off 위계** (upstream consume / downstream produce / parallel pair) | 오케스트레이션 뼈대가 이미 인코딩됨 |
| `tools` 명시적 listing 49/49 (`*` 회피) | 최소권한의 출발점 |
| 32/49 의 `## Output Format` | 구조화 출력 계약의 씨앗 |
| CI drift job 6종 | **sensor 를 붙일 자리가 이미 마련됨** |

---

## 6. 실행 백로그

**세션을 넘겨 재개 가능하도록 체크박스로 관리한다.** 새 세션은 §7 재개 절차를 따른다.

커밋 규율: [`rules/git.md`](../../.claude/rules/git.md) "커밋당 4~5 파일 / PR 400줄". Step 2 는 **카테고리 단위 커밋**(사용자 결정 2026-08-24).

### Step 1 — 사실 최신화 (파일 4 / 위험 없음) ✅ 완료 2026-08-24

- [x] `.claude/rules/effort-guide.md` — L45 의 "`effort` 필드를 직접 읽지 않으므로" 오류 정정 (F3)
- [x] `.claude/templates/AGENT-SPEC.md` — frontmatter 16필드 반영(§1.1~1.3 재구성), 검증일 2026-08-24 + **다음 재검증 2026-11** 명시, `skills`/`memory`/`permissionMode` 가이드 추가
- [x] `AGENTS.md` — §Claude-Only Features 에 skill = `SKILL.md` 규격, commands→skills 병합, 실행 강제 3필드 반영
- [x] dev-log — [`2026-08-24-step1-agent-spec-modernization.md`](../dev-logs/2026-08-24-step1-agent-spec-modernization.md)

> 검증: `validate-rules-drift` / `validate-skill-frontmatter` / `validate-agent-handoff` / `validate-commands-drift` 전부 통과. `validate-schemas.sh` 는 1건 실패하나 **HEAD 에서도 동일하게 실패하는 기존 결함**(`.agents/` dangling ref) — 아래 Step 2 로 편입.

### Step 2 — 죽은 skill 260개 복구 (F1 / F2) ✅ 완료 2026-08-24

- [x] 변환 스크립트 작성 (`scripts/migrate-skills-to-skillmd.sh`)
- [x] **1개로 먼저 검증** — `go/effective-go` 이관 후 `/` 목록 등재 실측 확인. **F1 확증**
- [x] 22 카테고리 단위로 `git mv` — `.claude/skills/<name>/SKILL.md`, 카테고리는 frontmatter `category:` 보존
- [x] `.gitignore` 의 규격 위반 제외 규칙(`.claude/skills/*/*/SKILL.md`) 삭제 (F2)
- [x] `install.sh` — `install_skills_by_category` 헬퍼, individual basename 해석, flatten symlink 제거
- [x] `generate-inventory.sh` / `-labels.sh` / `validate-skill-frontmatter.sh` 경로·카테고리 해석 갱신 + inventory 재생성
- [x] `docs/migration/0002-progress.md` — P7 범위 축소 + P4-D 결정 정정
- [x] `docs/architecture/multi-tool-mapping.md` 갱신
- [x] `.agents/` dangling ref 제거 — `validate-schemas.sh` 통과
- [x] dev-log — [`2026-08-24-step2-skill-skillmd-migration.md`](../dev-logs/2026-08-24-step2-skill-skillmd-migration.md)

> 검증: 구 레이아웃 잔여 0 / SKILL.md 260 / category 260 / 22 카테고리 합계 이관 전과 동일.
> validator 5종 + shellcheck + inventory 신선도 전부 PASS. `--workflow compose-to-k8s` 스모크 58개(dx 26 + kubernetes 14 + infrastructure 18) 정확.

> Step 2 수행 중 새로 발견한 2건은 **Step 5** 로 분리했다 (Step 2 잔여가 아니라 별개 작업).

### Step 3 — agent 강등 (F6 / F7) ✅ 완료 2026-08-24

- [x] **판정 오탐 정정 (F7)** — `## Output Template` 미매칭으로 5개 오분류. 강등 19 → **14**, borderline 11 → **16** (§3.1 / §3.3.1 / 부록 A)
- [x] 강등 14개와 기존 skill 260개의 **전수 중복 대조** → §3.5 표 (B 폐기 5 / C 신규이관 7 / D 분할 2)
- [x] **검증 게이트 1건** — `load-tester-gatling` → `sre/load-testing-gatling`. skill 로드 실측 + install 스모크로 전 경로 확인
- [x] B 폐기 5건 — 고유분 흡수 후 agent 삭제
- [x] C 신규 이관 7건 — 신규 skill 생성 후 agent 삭제
- [x] D 분할 2건 — `go-performance`/`go-security`, `jvm-performance`/`spring-security-review`
- [x] 재판정 5건 (§3.3.1) — agent 유지, 본문 skill 중복분 삭제 → 참조 표로 대체
- [x] borderline 재판정 (§3.6) — `migration-expert`/`tech-lead` 정당 승격, `pr-review-bot` 강등
- [x] `plugins/*.yml`, `.claude/workflows/*.yml`, `inventory.yml` 참조 갱신
- [x] **skill 본문 `**관련 agent**:` 상호참조 일괄 sweep** (13개 skill)
- [x] dev-log — [`2026-08-24-step3-agent-tier-demotion.md`](../dev-logs/2026-08-24-step3-agent-tier-demotion.md)

> 결과: agents 49→34 (19,819→12,736줄) / skills 260→272. 강등 대상 0.
> 신규 skill 12개. §3.4 과잉 분할 2건도 해소.
> 부수 발견: workflow `skills:` 목록의 dangling 참조 — 일부 수정, 나머지는 **검증 CI job 부재**로 Step 5 에 편입.

### Step 4 — harness 리트로핏 ✅ 완료 2026-08-25

- [x] **`effort` 전 agent 반영** (F3 후속) — 5/34 → **34/34**. 선행으로 `effort-guide.md` 의 model×effort 매트릭스를 정정했다 (아래 F9)
- [x] **`## Verification Criteria` + `Permission Boundary` + `Escalation`** — 각 1/34 → **34/34**. `LEGACY_AGENTS_NO_BODY_SPEC` **완전 소진**, 신규 agent 는 hard fail (F5)
- [x] **borderline 13 결손 축 보강** (§3.6) — 조사 프로토콜 10 신설 + 출력 계약 3 신설. borderline **13 → 0**
- [x] **agent 스키마 / 검증 확대** (F8 신규) — `agent-manifest.v1` 을 공식 16필드로 갱신, `validate-schemas.sh` 를 1건 샘플 → agent 전수로 확대
- [x] **AGENT-SPEC §1.2 사실 정정** — `disallowedTools` 를 "gh / git push 금지의 승격 자리" 라고 적은 것이 스펙상 성립하지 않음 (아래 F10)
- [x] **버전 클레임 전수 재검증 + ✅/⚠️ 마킹** — K8s 1.30(EOL) / Spring Boot 3.3(EOL) / Java 21 등 정정, `migration-expert`·`frontend-expert` 에 Verified Version Baseline 표(출처 URL + 검증일 + 분기 재검증) 신설
- [x] dev-log — [`2026-08-25-step4-harness-retrofit.md`](../dev-logs/2026-08-25-step4-harness-retrofit.md)

**Step 4 에서 분리한 것** → 아래 **Step 6**:
- ~~리뷰어 11개에 `disallowedTools` 또는 `permissionMode`~~ — **스펙상 성립하지 않아 이월** (F10). 사용자 결정 2026-08-25: "일차원적 설정 말고 근본적인 해결을 다른 세션에서"
- ~~agent 행동 eval 도입 검토~~ / ~~`memory: project` 도입 검토~~ — Step 6 의 harness 근본 설계와 같은 묶음

---

### Step 5 — Step 2 파생 (install.sh 범위 / CI 게이트) ✅ 완료 2026-08-24

Step 2 수행 중 발견. Step 3·4 와 독립이며 순서 제약 없다.

- [x] **`--plugin X --with-skills` 범위 무시 수정** — 전체 설치 블록을 `PLUGIN_NAMES`/`WORKFLOW_NAMES` 가 비었을 때만 실행하도록 게이트. `--plugin backend-go --with-skills` 272 → **40** (go 12 + msa 16 + architecture 12). `--all --with-skills` 는 272 유지
- [x] `validate-schemas.sh` **CI 편입** — `drift` job 에 스텝 추가 (편입 결정)
- [x] **workflow / plugin skill·category 참조 검증** — `validate-agent-handoff.sh` 에 `check_skill_refs` 추가. 죽은 참조 **11건 전부 수정**. 음성 테스트로 검출 확인
- [x] **범위 회귀 방지 CI 케이스** — 기존 스모크 job 은 exit code 만 봐서 이 결함을 통과시켰다. 설치 개수를 카테고리 기대값과 대조하는 스텝 추가
- [x] dev-log — [`2026-08-24-step5-install-scope-and-ci-gates.md`](../dev-logs/2026-08-24-step5-install-scope-and-ci-gates.md)

> 남긴 것 (범위 밖, 목록만): ADR 0007 의 `--skill`/`--agent`/`--rule` 자산 단위 옵션은 여전히 PR-8 미착수.
> `--all` 이 agents/rules 를 설치하지 않는다 (commands + skills 만) — 도움말의 "Install all modules" 와 불일치.

---

### Step 6 — 실행 강제(enforcement) 레이어 ✅ 완료 2026-08-25

Step 4 착수 시 F4 를 `disallowedTools` / `permissionMode` 로 닫으려다 **스펙상 불가**임이 확인돼 분리했다 (F10). 착수 조사에서 **이미 있던 강제력 레이어가 3.5개월째 0% 로 작동했다는 사실**을 추가로 발견했다 (F11).

**풀어야 하는 문제**: 리뷰어를 포함한 34개 agent 전부가 무제한 `Bash` 를 갖는다. `gh pr comment` / `git push` / `argocd app sync` / 변경형 `kubectl` 이 기술적으로 실행 가능하고, [`user-approval.md`](../../.claude/rules/user-approval.md) §"에이전트에 외부 게시 권한 위임 금지" 를 **산문으로만** 막고 있다.

#### 검증한 사실 (전 항목 2026-08-25 WebFetch)

출처: [hooks](https://code.claude.com/docs/en/hooks) · [permissions](https://code.claude.com/docs/en/permissions) · [permission-modes](https://code.claude.com/docs/en/permission-modes) · [settings](https://code.claude.com/docs/en/settings) · [sub-agents](https://code.claude.com/docs/en/sub-agents)

| # | 사실 | 상태 |
|---|---|---|
| V1 | hook event **31개** (`SessionStart` … `SessionEnd`) | ✅ |
| V2 | command hook 입력 = **stdin JSON** (`tool_name` / `tool_input` / `permission_mode` …). env var 은 `CLAUDE_PROJECT_DIR` `CLAUDE_PLUGIN_ROOT` `CLAUDE_PLUGIN_DATA` `CLAUDE_CODE_REMOTE` `CLAUDE_CODE_BRIDGE_SESSION_ID` `CLAUDE_EFFORT` 뿐 | ✅ |
| V3 | `PreToolUse` exit 2 = 차단. JSON `permissionDecision: deny\|allow\|escalate`. **exit 1 = 비차단 오류로 그냥 진행**. timeout 시 결정 폐기 | ✅ |
| V4 | `PostToolUse` 는 **차단 불가** (이미 실행됨) | ✅ |
| V5 | **"Deny rules block in every mode, including `bypassPermissions`."** allow 규칙은 bypassPermissions 에서 무효 | ✅ |
| V6 | **"Hook decisions don't bypass permission rules."** deny/ask 는 hook 반환값과 무관하게 평가 — deny-first | ✅ |
| V7 | Bash 지정자 `Bash(git push *)` 지원, `:*` 는 끝자리 wildcard 동치. `Bash(command:...)` 형태는 **무시 + startup warning** | ✅ |
| V8 | 어느 scope 의 deny 든 어느 scope 의 allow 를 이긴다 | ✅ |
| V9 | settings.json 의 hook 은 **subagent 안에서도 실행**된다 | ✅ |
| V10 | subagent frontmatter `hooks` 지원. project-level agent 의 frontmatter hook 은 **workspace trust 수락 후** 동작. plugin subagent 는 `hooks`/`mcpServers`/`permissionMode` 무시 | ✅ |
| V11 | 인자를 제약하는 Bash 패턴은 **취약** (옵션 순서 / 변수 / 공백) — 공식 Warning | ✅ |
| V12 | `bypassPermissions` 하에서 PreToolUse hook 이 실행/차단되는지 | ⚠️ not stated → **✅ 실측 P3: 실행되고 차단한다** |
| V13 | `ask` 규칙이 `bypassPermissions` 에서 유지되는지 | ⚠️ not stated → **✅ 실측 P4: 유지된다 (자동승인 안 됨)** |
| V14 | `Stop` hook 무한루프 안전장치 (`stop_hook_active` 등) | ⚠️ **not stated** → 사용하지 않는다 |

#### F10 정정 — 나가는 문은 `permissions.deny` 다

F10 이 "명령 단위에 닿는 건 hook 뿐" 이라고 적은 것은 **agent frontmatter 안에서만 참**이다. `.claude/settings.json` 의 `permissions.deny` 는 (V7) 명령 단위에 닿고, (V5) 모든 모드에서 유효하며, (V8) 어떤 allow 도 못 뚫고, (V9/V6) subagent 에도 적용된다. 그리고 **선언형 설정이라 hook script 처럼 조용히 죽지 않는다** (F11 의 교훈).

→ **1순위 = `permissions.deny` / `ask`. hook 은 deny 로 표현 불가능한 잔여분에만, 그리고 반드시 fixture 와 함께.**

#### 사용자 결정 (2026-08-25)

| 항목 | 결정 |
|---|---|
| 죽은 `admit` hook (F11) | **폐기** — ADR 0002/0005 Rejected, control-plane 에서 제거 |
| install.sh 배포 경계 | **고려하지 않는다** — install.sh 자체를 없애는 방향. 이 레포 dogfooding 만 |
| 착수 범위 | Step 6 만 (rules 분류 · ablation 은 Step 7+) |

#### 작업 목록

- [x] **6-A. 죽은 admit hook 폐기** (F11) ✅ 2026-08-25 — vitest 111→97, typecheck 통과 — `control-plane` 의 `admit.ts` / `install-hook.ts` / `admit.test.ts` 삭제, `index.ts`(admit 커맨드 · baseline sink) · `init.ts`(step 5 hook wiring · `LockFile.hook`) 정리, `cli.test.ts` / `init.test.ts` 의 해당 describe 제거. ADR 0002·0005 Rejected / 0004 Superseded, `docs/migration/0002-progress.md` P5·P6.5 상태 정정. **보존**: `applies_when`(match/adapter 가 사용), `security.sandbox`(스키마 유지 + orphan 표기)
- [x] **6-B. 실측 게이트** (§7-5) ✅ 2026-08-25 — P0~P7 8건, 결과는 [ADR 0009](../adr/0009-enforcement-layer-placement.md) §실측 — 문서에 없는 것만. sentinel 명령(`echo ENFORCE_PROBE_…`)만 사용, 파괴적 명령 금지
      - M1 deny 규칙이 **subagent 의 Bash** 에도 적용되는가 (V9 는 hook 상속만 명시)
      - M2 `bypassPermissions` 하에서 PreToolUse hook 실행/차단 여부 (V12)
      - M3 `ask` 규칙이 `bypassPermissions` 에서 유지되는가 (V13)
      - M4 deny 위반 시 실제 거절 동작 · 메시지 (V5/V6)
      > M1~M4 전에 6-D 를 확정하지 않는다 — F10 이 정확히 "배치처 동작을 확인하지 않고 설계한" 실패였다
- [x] **6-C. ADR 0009** ✅ 2026-08-25 — [`0009-enforcement-layer-placement.md`](../adr/0009-enforcement-layer-placement.md) — `docs/adr/0009-enforcement-layer-placement.md`. 대안 3안 비교: (A) `permissions.deny`+`ask` 우선 · hook 보조 / (B) hook 단독 / (C) agent 에서 `Bash` 제거 후 메인이 검증 명령 실행. (C) 의 비용 정량화(리뷰어 11개가 `terraform validate` / `helm template` / `trivy` / `git diff` 를 잃는다). Sources 표 + 분기 재검증 2026-11
- [x] **6-D. `.claude/settings.json` 신설** ✅ 2026-08-25 — deny 11 / ask 11 — `user-approval.md` 금지 표의 강제 승격
      - `deny` = 세션 내 실행 이유가 없는 것: 변경형 `kubectl`(`apply`/`delete`/`patch`/`edit`/`scale`/`rollout`/`set image`), `argocd app sync --force`, `git push --force`, `git commit --no-verify`
      - `ask` = 승인 프로세스가 존재하는 것: `git push`, `gh pr create/comment/merge/close`, `gh issue create/close`, `gh release create` — deny 로 막으면 **승인받은 push 조차 불가능**해진다
      - V11 을 존중해 명령 이름 수준에서 건다. `Bash(command:...)` 형태 금지 (V7)
      - ⚠️ 추가하는 순간 현재 세션에 즉시 적용된다 → 백로그 push **이후** 순서
- [x] **6-E. 조용한 실패 검출** (F11 교훈) ✅ 2026-08-25 — 정적 게이트 음성 테스트 6/6, 런타임 25/25 (음성 대조군 3 포함). CI 에 control-plane vitest 도 추가 — 정적/런타임 분리
      - 정적(CI): `scripts/validate-enforcement.sh` + `drift` job 스텝 — `user-approval.md` 금지 표 ↔ `settings.json` 드리프트, JSON 유효성, 무효 패턴 검출
      - 런타임(로컬): `make verify-enforcement` — sentinel 위반 시도 후 거절 단언. **CI 에선 claude CLI 부재로 못 돈다 — 이 한계를 문서에 명시**
- [x] **6-F. 산문 정정** ✅ 2026-08-25 — `AGENT-SPEC.md` §1.2(`hooks` 를 "명령 단위에 닿는 유일한 필드" 라 한 오류), `user-approval.md`(금지 표에 강제 메커니즘 열 추가, 산문 잔존분 명시), `AGENTS.md`, 본 문서 §2.0
- [x] **6-G. dev-log** ✅ 2026-08-25 — [`2026-08-25-step6-enforcement-layer.md`](../dev-logs/2026-08-25-step6-enforcement-layer.md)

**완료 기준**: §7-6 검증 명령 전부 통과 + M1~M4 가 ADR 0009 에 검증일과 함께 기록 + `user-approval.md` 각 금지 항목의 강제 메커니즘 확정. 실행하지 못한 검증은 "실행 안 함" 으로 명시한다.

---

### Step 7+ — 범위 밖 (목록만)

- always-on rules 13개(1,503줄) + `AGENTS.md`(340줄) = **90KB 가 매 세션 상주**한다. 각 항목을 [DENY 가능] / [HOOK 가능] / [CI 가능] / [강제 불가] 로 분류하고 이관 확정분을 산문에서 제거 — 측정 없이 줄일 수 있는 유일한 구간
- 활성화 경로 트레이스(`claude -p --output-format stream-json`) 기반 ablation. 단일 자산 ablation 은 중복 쌍(A/B 가 서로를 받쳐줌)에서 양쪽 다 "불필요" 로 오판하므로 **경로 단위**로 묶어 이진 탐색
- `mcp-configs/settings.json` 이 `mcpServers` 를 settings.json 에 두는 문제 (Claude Code 는 `.mcp.json` 을 쓴다) — 관찰만

---

## 7. 세션 재개 절차

**현재 상태 (2026-08-25 기준)**: Step 1~6 전부 ✅. **다음은 Step 7+** (아래 §Step 7+ 목록).

Step 6(실행 강제)은 Step 4 에서 분리됐다 — F10 으로 기존 해법이 스펙상 불가임이 확인됐기 때문이다. 2026-08-25 착수 조사에서 **F10 의 출구가 `permissions.deny`** 임을 공식 문서로 확인했고(§6 V1~V14), 동시에 **이미 있던 hook 이 3.5개월째 죽어 있었다는 사실(F11)** 을 발견했다. 재개 시 §6 Step 6 의 V 표와 F11 상세부터 읽는다.

작업 브랜치 `docs/harness-readiness-audit` — `origin` 동기 상태는 `git status -sb` 로 확인.

1. 본 문서 §6 에서 미체크 항목 확인 — `grep -n "^- \[ \]" docs/audit/2026-08-24-agent-harness-readiness.md`
2. dev-log 로 직전 세션 맥락 복원 (최신순):
   [step4](../dev-logs/2026-08-25-step4-harness-retrofit.md) → [step5](../dev-logs/2026-08-24-step5-install-scope-and-ci-gates.md) → [step3](../dev-logs/2026-08-24-step3-agent-tier-demotion.md) → [step2](../dev-logs/2026-08-24-step2-skill-skillmd-migration.md) → [step1](../dev-logs/2026-08-24-step1-agent-spec-modernization.md) → [측정 audit](../dev-logs/2026-08-24-harness-engineering-audit.md)
3. [부록 A](#부록-a-재측정-명령) 로 현재 수치 재측정 — 본 문서 수치와 다르면 **본 문서를 먼저 갱신**
4. Step 순서:
   - **Step 3** 은 Step 2 를 전제로 한다 (옮겨갈 곳이 실제로 동작해야 강등 가능) → 완료
   - **Step 6** 은 6-A(폐기) → 6-B(실측) → 6-C(ADR) → 6-D(설정) → 6-E(검출) → 6-F(산문) → 6-G(dev-log) 순서다. **6-B 실측 없이 6-D 를 확정하지 않는다** — F10 이 그 실패였다
   - 6-D 의 `.claude/settings.json` 은 **추가 즉시 현재 세션에 적용**된다. `ask` 층이 승인 흐름을 프롬프트로 대체하므로, deny 로 잘못 넣으면 승인받은 작업도 막힌다
   - 현재 수치는 §2.0 참조 (§2 이하는 audit 시점 기록)
5. **자산을 옮기거나 형식을 바꾸는 작업은 "1건 먼저 검증" 게이트를 반드시 거친다.** Step 2 에서 이 게이트가 실제로 작동했다 — 1건 이관 후 로드 확인이 되고 나서야 260개를 진행했다. 건너뛰면 전량 롤백 위험
6. 검증 명령 (커밋 전 전부 통과해야 함):
   ```bash
   for s in validate-rules-drift validate-skill-frontmatter validate-agent-handoff \
            validate-commands-drift validate-schemas; do ./scripts/$s.sh >/dev/null 2>&1 \
     && echo "PASS $s" || echo "FAIL $s"; done
   shellcheck install.sh scripts/*.sh
   ./scripts/generate-inventory.sh && ./scripts/generate-inventory-labels.sh \
     && git diff --quiet .claude/inventory*.yml && echo "inventory 최신"
   ```

---

## 부록 A: 재측정 명령

```bash
# agent 개수 / 줄수
ls .claude/agents/*.md | wc -l && wc -l .claude/agents/*.md | tail -1

# frontmatter 필드 채택률
for k in skills memory permissionMode maxTurns disallowedTools hooks color \
         isolation background mcpServers initialPrompt effort; do
  echo "$k: $(grep -l "^$k:" .claude/agents/*.md 2>/dev/null | wc -l) / 49"
done

# 도구 권한 분포
for t in Bash Write WebFetch; do
  echo "$t: $(grep -l "^  - $t\$" .claude/agents/*.md | wc -l) / 49"
done

# AGENT-SPEC 필수 3섹션
for s in "Permission Boundary" "Escalation" "Verification Criteria"; do
  echo "$s: $(grep -l "^## .*$s" .claude/agents/*.md | wc -l) / 49"
done

# 티어 판정 (조사 프로토콜 × 출력 계약)
for f in .claude/agents/*.md; do
  P=no; grep -qE "^## .*(Process|Protocol|Decision Tree|Workflow|Methodology)" "$f" && P=YES
  O=no; grep -qE "^## .*(Output Format|Report Template|Output Template|출력)" "$f" && O=YES  # Output Template 누락이 F7 오탐 원인
  [ "$P" = no ] && [ "$O" = no ] && basename "$f" .md
done

# skill 로딩 가능 여부
find .claude/skills -name "SKILL.md" | wc -l      # 규격 준수 개수
find .claude/skills -name "*.md" ! -name "SKILL.md" | wc -l   # 미로드 개수

# 평탄화 충돌
find .claude/skills -name "*.md" -exec basename {} .md \; | sort | uniq -d
comm -12 <(find .claude/skills -name "*.md" -exec basename {} .md \; | sort -u) \
         <(find .claude/commands -name "*.md" -exec basename {} .md \; | sort -u)

# staleness
git log -1 --format=%ad -- .claude/agents/
for f in .claude/agents/*.md; do grep -qE "https?://" "$f" || basename "$f"; done | wc -l
```

---

## 관련 문서

- [2026-08-15 자산 티어 재배치 audit](2026-08-15-asset-tier-rebalance.md) — 선행 audit (drift / description 축)
- [ADR 0008 asset tier policy](../adr/0008-asset-tier-policy.md) — 티어 판정 상시 정책
- [Migration 0002 progress](../migration/0002-progress.md) — P7 (F2 대상)
- [`AGENT-SPEC.md`](../../.claude/templates/AGENT-SPEC.md) — Step 1 / Step 4 대상
- [`rules/deep-thinking.md`](../../.claude/rules/deep-thinking.md) — §1 출처 기록 의무의 근거
