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

### 3.6 본문 구성 — reference dump

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

## 4. 발견 (F1~F6)

| # | 발견 | 위치 | 심각도 |
|---|---|---|---|
| **F1** | **skill 260개가 로드되지 않는다** | `.claude/skills/<cat>/<name>.md` | 🔴 기능 결함 |
| **F2** | **Migration 0002 P7 의 목표 경로도 규격 위반** | `.gitignore:39` | 🔴 계획 결함 |
| **F3** | `effort` 는 공식 frontmatter 필드다 — rule 의 사실 오류 | `.claude/rules/effort-guide.md:45` | 🟡 |
| **F4** | 산문 규약을 강제 메커니즘으로 승격하지 않음 (자기 rule 위반) | 리뷰어 11개 | 🟡 |
| **F5** | AGENT-SPEC 필수 3섹션이 1/49, LEGACY 배열로 CI 우회 | `validate-skill-frontmatter.sh` | 🟡 |
| **F6** | agent 14개가 티어 오배치 (5,395줄) | §3.3 | 🟡 |
| **F7** | 티어 판정 정규식이 `Output Template` 표기를 놓쳐 5개를 오분류 | §3.1 / 부록 A | 🟡 |

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

### Step 3 — agent 14개 강등 (F6 / F7)

- [x] **판정 오탐 정정 (F7)** — `## Output Template` 미매칭으로 5개 오분류. 강등 19 → **14**, borderline 11 → **16** (§3.1 / §3.3.1 / 부록 A)
- [x] 강등 14개와 기존 skill 260개의 **전수 중복 대조** → §3.5 표 (B 폐기 5 / C 신규이관 7 / D 분할 2)
- [ ] **검증 게이트 1건** — `load-tester-gatling` → `sre/load-testing-gatling`. 참조 0건 / 중복 0건이라 최소 위험으로 전 경로(신규 skill → agent 삭제 → inventory → validator) 관통
- [ ] B 폐기 5건 — 고유분 흡수 후 agent 삭제
- [ ] C 신규 이관 7건 — 신규 skill 생성 후 agent 삭제
- [ ] D 분할 2건 — `go-performance`/`go-security`, `jvm-performance`/`spring-security-review`
- [ ] 재판정 5건 (§3.3.1) — agent 유지, 본문 skill 중복분 삭제 → 참조로 대체
- [ ] borderline 11개 재판정 (강등 / 유지 / 보강)
- [ ] `plugins/*.yml`(55건), `.claude/workflows/*.yml`, `inventory.yml` 참조 갱신
- [ ] **skill 본문의 `**관련 agent**:` 상호참조 일괄 정리** — 같은 파일이 여러 agent 를 참조하므로 강등 전건 완료 후 한 번에 sweep (multi-tenancy / media-handling / audit-log / data-subject-rights / credit-system / subscription-billing / kr-location-info-act 등)
- [ ] dev-log 1건

### Step 4 — harness 리트로핏

- [ ] 리뷰어 11개에 `disallowedTools` 또는 `permissionMode` — 산문을 실행 강제로 승격 (F4)
- [ ] 42개 agent 에 `effort` frontmatter 실제 반영 (F3 후속)
- [ ] `## Verification Criteria` 섹션 채우기 → `LEGACY_AGENTS_NO_BODY_SPEC` 배열 소진 (F5)
- [ ] agent 행동 eval 도입 검토 (고정 입력 → 기대 발견 항목)
- [ ] `memory: project` 도입 검토 — dev-logs 수동 반영 루프 대체
- [ ] 버전 클레임 전수 재검증 + ✅/⚠️ 마킹, 분기 재검증 일정 명시
- [ ] dev-log 1건

---

### Step 5 — Step 2 파생 (install.sh 범위 / CI 게이트)

Step 2 수행 중 발견. Step 3·4 와 독립이며 순서 제약 없다.

- [ ] `--plugin X --with-skills` 가 260개 전부 설치한다. `WITH_SKILLS` 전체 설치 블록이 `backup_and_link ... "dir"` 로 plugin 산출물을 덮어써 **plugin 의 범위 축소 기능이 죽어 있다**. `git stash` 후 HEAD 에서도 261개 설치로 재현 — **기존 결함이며 Step 2 의 회귀가 아니다**. [ADR 0007](../adr/0007-install-sh-narrow-scope.md) / PR-8 영역
- [ ] `validate-schemas.sh` 를 CI job 으로 편입할지 결정 — 현재 CI 에 없어서 Step 1 이 발견한 `.agents/` dangling ref 실패가 방치돼 있었다. 미편입이면 같은 류가 다시 방치된다
- [ ] dev-log 1건

---

## 7. 세션 재개 절차

**현재 상태 (2026-08-24 기준)**: Step 1 ✅ / Step 2 ✅ / **Step 3 진행 중** (대조 완료, 이관 대기) / **Step 4 · 5 대기**.
작업 브랜치 `docs/harness-readiness-audit` — `origin` 에 push 완료 (`git status -sb` 로 동기 상태 확인).

1. 본 문서 §6 에서 미체크 항목 확인 — `grep -n "^- \[ \]" docs/audit/2026-08-24-agent-harness-readiness.md`
2. dev-log 로 직전 세션 맥락 복원 (최신순):
   [step2](../dev-logs/2026-08-24-step2-skill-skillmd-migration.md) → [step1](../dev-logs/2026-08-24-step1-agent-spec-modernization.md) → [측정 audit](../dev-logs/2026-08-24-harness-engineering-audit.md)
3. [부록 A](#부록-a-재측정-명령) 로 현재 수치 재측정 — 본 문서 수치와 다르면 **본 문서를 먼저 갱신**
4. Step 순서:
   - **Step 3** 은 Step 2 를 전제로 한다 (옮겨갈 곳이 실제로 동작해야 강등 가능) → 전제 충족됨
   - **Step 4** / **Step 5** 는 독립. 순서 제약 없음
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
