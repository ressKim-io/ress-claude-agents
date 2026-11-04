<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# architecture

아키텍처 설계 — MSA, DDD, Saga, CQRS, API 설계, gRPC, 모듈러 모놀리스, 대규모 트래픽

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install architecture@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/architecture/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`messaging`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/messaging/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`java`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/java/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`platform`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/platform/README.md)
- [`service-mesh`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/service-mesh/README.md)
- [`go`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/go/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (25)

| 이름 | 설명 |
|---|---|
| `/architecture:api-design` | REST API 설계 — URL 규칙, RFC 9457 Problem Details 에러 응답, 페이지네이션, 필터링·정렬, 버저닝 |
| `/architecture:cell-based-architecture` | Cell-Based Architecture 가이드 — 대규모 장애 격리를 위한 Cell 기반 아키텍처: Bulkhead 패턴, 블라스트 반경 제한, Horizontal Isolation |
| `/architecture:composable-architecture` | 조합형 아키텍처(MACH) — Packaged Business Capabilities(PBC), API Composition, Micro-Frontends 로 교체 가능한 구성 요소 설계 |
| `/architecture:config-explicit-defaults` | 묵시적 기본값 방지 — 명시값·라이브러리 기본값·환경별 override 3단 검증과 silent default drift 점검 |
| `/architecture:consumer-driven-contracts` | Consumer-Driven Contracts — Pact consumer test, provider verification, GitOps 연동으로 서비스 간 API contract drift 방지 |
| `/architecture:contract-first` | Contract-First 개발 — OpenAPI 3.1 spec-first, Protobuf/gRPC, AsyncAPI, Schema Registry, 코드 생성 CI 파이프라인 |
| `/architecture:data-mesh` | Data Mesh — 도메인 소유권, Data as a Product, 셀프서비스 데이터 플랫폼, 연합 거버넌스, Spring Boot·Go data product 구현 |
| `/architecture:distributed-lock` | 분산 락 — Redisson(Spring Boot), Redsync(Go Redlock), ShedLock 스케줄러 중복 방지, Fencing Token |
| `/architecture:graphql-federation` | GraphQL Federation — Apollo Federation v2 Supergraph, Subgraph 스키마 설계, Go gqlgen·Spring DGS 구현, Router 배포, … |
| `/architecture:grpc` | gRPC 서비스 설계 — Protocol Buffers, buf 설정, Go·Spring 구현, 스트리밍, 에러 처리, 인터셉터, gRPC-Gateway |
| `/architecture:hexagonal-clean-architecture` | Hexagonal(Ports & Adapters)·Clean Architecture — 의존성 역전, 도메인 중심 계층 구조, Spring Boot·Go 구현 |
| `/architecture:high-traffic-design` | 대규모 트래픽 설계 — Backpressure, Rate Limiting, CDN Edge, Connection Pooling, Queue Load Leveling, Request Batching |
| `/architecture:modular-monolith` | 모듈러 모놀리스 — 단일 배포 안에서 모듈 경계 강제, Spring Modulith, Go internal 패키지, 서비스 추출 전략 |
| `/architecture:msa-api-gateway-patterns` | MSA API Gateway 패턴 — BFF, Gateway Aggregation, Protocol Translation, 계층형 인가, API 버저닝·deprecation |
| `/architecture:msa-cqrs-eventsourcing` | CQRS 와 Event Sourcing — Command/Query 분리, 이벤트 저장소, Eventual Consistency, Axon Framework |
| `/architecture:msa-ddd` | DDD 마이크로서비스 설계 — Bounded Context, Aggregate, Domain Event, Context Mapping, Event Storming, 서비스 분해 전략 |
| `/architecture:msa-event-driven` | 이벤트 드리븐 아키텍처 — 서비스 간 비동기 통신, 이벤트 스키마 설계, 발행·수신 패턴, 메시징 패턴 비교 |
| `/architecture:msa-observability` | MSA 분산 추적 — Distributed Tracing, Trace Context 전파, Correlation ID, Baggage, Span Attributes, Exemplar, 서비스 … |
| `/architecture:msa-resilience` | MSA 복원력 — Resilience4j Circuit Breaker, Bulkhead, Retry, Timeout, Fallback 조합과 Istio 연동 |
| `/architecture:msa-saga` | Saga 패턴 — Choreography vs Orchestration, 보상 트랜잭션, 실패 처리 |
| `/architecture:service-ownership-matrix` | 서비스 소유권 — RACI, Shared Responsibility Model, 팀 이름이 아닌 개인·직무 단위 owner 명시, 워크숍 템플릿 |
| `/architecture:state-machine` | 도메인 상태머신 — 상태 전이 테이블, Go looplab/fsm, Spring State Machine, guard·side effect, 감사 로그, Mermaid 시각화 |
| `/architecture:strangler-fig-pattern` | Strangler Fig — 레거시 점진 현대화, API Gateway 라우팅 전환, 데이터 동기화, 신구 시스템 병행 검증 |
| `/architecture:task-queue` | Task Queue — Celery, BullMQ, Go asynq, Spring RabbitMQ 기반 비동기 작업 분산, 우선순위 큐, 재시도, Worker 오토스케일링 |
| `/architecture:vertical-slice-architecture` | Vertical Slice Architecture — 계층이 아닌 feature 단위 코드 구성, Spring Boot·Go 구현, CQRS 결합, 공유 코드 전략 |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `architecture:architect-agent` | MSA 아키텍처 설계 에이전트. 서비스 경계 정의, API 계약(protobuf/OpenAPI) 설계, Bounded Context 매핑, 의존성 분석에 특화 |
