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
| `/architecture:api-design` | REST API Design Patterns — REST API 설계 원칙, RFC 9457 에러 처리, 페이지네이션, 버저닝 |
| `/architecture:cell-based-architecture` | Cell-Based Architecture 가이드 — 대규모 장애 격리를 위한 Cell 기반 아키텍처: Bulkhead 패턴, 블라스트 반경 제한, Horizontal Isolation |
| `/architecture:composable-architecture` | Composable Architecture (MACH) — MACH Alliance 기반 조합형 아키텍처 — Packaged Business Capabilities(PBC)를 교체·조합하여 … |
| `/architecture:config-explicit-defaults` | 설정 안 한 값은 자동 처리되니 괜찮다'는 mental model 오류 방지. 명시값/기본값/환경별 override 3단 검증 체크리스트로 config sprawl과 silent default … |
| `/architecture:consumer-driven-contracts` | 마이크로서비스 간 API contract drift를 막는 Consumer-Driven Contracts(CDC) + Pact 운영 가이드. consumer test로 contract 정의 → … |
| `/architecture:contract-first` | Contract-First Development — API 계약을 먼저 정의하고 코드를 생성하는 개발 방법론 — OpenAPI, Protobuf, AsyncAPI, Pact |
| `/architecture:data-mesh` | Data Mesh Architecture 가이드 — Zhamak Dehghani의 분산 데이터 아키텍처. 도메인 소유권, Data as a Product, 셀프서비스 플랫폼, 연합 거버넌스 |
| `/architecture:distributed-lock` | Distributed Lock Patterns — MSA/다중 서버 환경에서의 분산 락 패턴 |
| `/architecture:graphql-federation` | GraphQL Federation 가이드 — Apollo Federation v2 기반 Supergraph 설계, Subgraph 구현 (Go gqlgen / Spring DGS), Router … |
| `/architecture:grpc` | gRPC Service Design — gRPC 서비스 설계, Protocol Buffers, 스트리밍, 에러 처리, 성능 최적화 |
| `/architecture:hexagonal-clean-architecture` | Hexagonal Architecture (Clean Architecture) — Ports & Adapters 패턴, 의존성 역전, 도메인 중심 설계로 테스트 가능하고 유연한 시스템 구축 |
| `/architecture:high-traffic-design` | 대규모 트래픽 설계 가이드 — Backpressure, Rate Limiting, CDN Edge, Connection Pooling, Queue Load Leveling, Request … |
| `/architecture:modular-monolith` | Modular Monolith Architecture — 단일 배포 단위 내에서 모듈 경계를 강제하여 확장성과 단순성의 균형을 달성하는 아키텍처 패턴 |
| `/architecture:msa-api-gateway-patterns` | MSA API Gateway 패턴 가이드 — BFF, Gateway Aggregation, Protocol Translation, Layered Auth, API 버저닝 패턴의 설계 원칙과 실전 … |
| `/architecture:msa-cqrs-eventsourcing` | CQRS & Event Sourcing 가이드 — Command/Query 분리와 이벤트 기반 상태 관리로 확장 가능한 마이크로서비스를 구축하는 실전 가이드 |
| `/architecture:msa-ddd` | DDD 마이크로서비스 설계 가이드 — Bounded Context, Aggregate, Domain Event, Context Mapping, 서비스 경계 설계 |
| `/architecture:msa-event-driven` | 이벤트 드리븐 아키텍처 가이드 — 서비스 간 비동기 통신, 이벤트 스키마 설계, 발행/수신 패턴, Kubernetes 통합 |
| `/architecture:msa-observability` | MSA 분산 추적 & 관측성 가이드 — Distributed Tracing, Correlation ID, Service Topology, Trace Context, Baggage … |
| `/architecture:msa-resilience` | MSA 복원력 패턴 가이드 — Resilience4j 기반 Circuit Breaker, Bulkhead, Retry, Timeout, Fallback 패턴의 실전 구현과 조합 전략 |
| `/architecture:msa-saga` | Saga 패턴 가이드 — 분산 트랜잭션의 일관성을 보장하는 Saga 패턴 구현 전략 (Choreography, Orchestration, Compensation) |
| `/architecture:service-ownership-matrix` | 책임 경계 불명확으로 인한 의사결정 정체·장애 미대응을 막는 RACI / Shared Responsibility Model 작성 가이드. "platform team" 같은 모호한 owner 표기를 … |
| `/architecture:state-machine` | 도메인 상태머신 가이드 — 도메인 엔티티의 상태 전이 관리, FSM 구현 패턴, 이벤트 기반 상태 변경, 감사 추적 |
| `/architecture:strangler-fig-pattern` | Strangler Fig Pattern — 레거시 시스템을 점진적으로 현대화하는 안전한 마이그레이션 전략 |
| `/architecture:task-queue` | Task Queue 패턴 가이드 — 비동기 작업 분산 처리, 우선순위 큐, 재시도 전략, Worker 오토스케일링 패턴 |
| `/architecture:vertical-slice-architecture` | Vertical Slice Architecture — > Feature 단위로 코드를 조직하는 아키텍처 패턴 - Jimmy Bogard 제안 |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `architecture:architect-agent` | MSA 아키텍처 설계 에이전트. 서비스 경계 정의, API 계약(protobuf/OpenAPI) 설계, Bounded Context 매핑, 의존성 분석에 특화 |
