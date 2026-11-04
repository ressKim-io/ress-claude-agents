[English](../../personas/backend-dev.md) | **한국어**

# 백엔드 개발자 가이드

> Java/Go 백엔드 개발자를 위한 에이전트 + 스킬 활용 가이드

---

## 설치 후 첫 5분

- [ ] `/plugin marketplace add ressKim-io/ress-claude-agents` 후 `go@ress`, `java@ress`, `architecture@ress`, `dx@ress` 를 `/plugin install`
- [ ] Claude Code에서 `/agents` 입력 → 에이전트 목록 확인
- [ ] `"Java 코드 리뷰해줘"` 또는 `"Go 코드 리뷰해줘"` 시도
- [ ] `"보안 취약점 검사해줘"` 시도

---

## 매일 쓰는 조합

> 전체 조합 테이블: [quick-reference.md](../quick-reference.md#2-백엔드-개발자-콤보)

### 코드 작성 사이클

```
1. 코드 작성 중
   → /java:jvm-performance 또는 /go:go-performance가 자동 리뷰 제안

2. 코드 완성 후
   → "코드 리뷰해줘" → code-reviewer 실행
   → "보안 검사해줘" → security-scanner 실행

3. 커밋/PR
   → "PR 만들어줘" → git-workflow 실행
```

### 자주 쓰는 스킬

| 매일 | 주 1-2회 | 프로젝트 초기 |
|------|---------|-------------|
| `/java:effective-java` 또는 `/go:effective-go` | `/architecture:msa-resilience` | `/architecture:msa-ddd` |
| `/java:spring-patterns` 또는 `/go:go-microservice` | `/infra:database` | `/architecture:api-design` |
| `/java:spring-testing` 또는 `/go:go-testing` | `/architecture:msa-event-driven` | `/architecture:hexagonal-clean-architecture` |
| `/dx:clean-code` | `/dx:refactoring-principles` | `/dx:clean-code` |

---

## Java / Spring 섹션

### 핵심 에이전트

| 에이전트 / 스킬 | 용도 |
|---------|------|
| `/java:jvm-performance` | Virtual Threads, WebFlux, JVM 튜닝, 대용량 트래픽 |
| `code-reviewer` | 코드 품질, 패턴 일관성, 버그 탐지 |

### 핵심 스킬

| 카테고리 | 스킬 | 핵심 내용 |
|---------|------|----------|
| 기본 | `/java:effective-java` | Record, Builder, DI, 불변 객체, Modern Java |
| 기본 | `/java:spring-patterns` | @Transactional, DTO/Entity, 예외 전략, 계층 구조 |
| 데이터 | `/java:spring-data` | JPA, QueryDSL 패턴 |
| 데이터 | `/java:spring-jooq` | jOOQ DSL, 코드 생성, Keyset Pagination |
| 캐싱 | `/java:spring-cache` | Redis 캐싱 전략 |
| 보안 | `/java:spring-security` | Security, Method Security |
| 인증 | `/java:spring-oauth2` | OAuth2, JWT |
| 테스트 | `/java:spring-testing` | JUnit 5, Mockito |
| 테스트 | `/java:spring-testcontainers` | Testcontainers, REST Assured |
| 동시성 | `/java:concurrency-spring` | @Async, Virtual Threads |
| 리팩토링 | `/java:refactoring-spring` | Spring 리팩토링 패턴 |
| 클린 코드 | `/dx:clean-code` | Guard Clause, Cognitive Complexity, 네이밍, Tell Don't Ask |

### 상황별 요청 예시

```
"Virtual Threads로 마이그레이션하고 싶어"
→ /java:jvm-performance + /java:concurrency-spring

"JPA N+1 문제가 발생해"
→ /infra:postgresql-operations + /java:spring-data + /infra:database

"OAuth2 + JWT 인증 구현해줘"
→ /java:spring-oauth2 + /java:spring-security

"Testcontainers로 통합 테스트 작성해줘"
→ /java:spring-testcontainers + /java:spring-testing

"클린 코드 품질 확인해줘"
→ /java:jvm-performance + /dx:clean-code + /dx:refactoring-principles

"Java 보안 리뷰해줘"
→ /java:spring-security-review + security-scanner
```

---

## Go 섹션

### 핵심 에이전트

| 에이전트 / 스킬 | 용도 |
|---------|------|
| `/go:go-performance` | Worker Pool, Fan-Out/In, sync.Pool, pprof |
| `code-reviewer` | 코드 품질, Go idiom 준수 |

### 핵심 스킬

| 카테고리 | 스킬 | 핵심 내용 |
|---------|------|----------|
| 기본 | `/go:effective-go` | Go Proverbs, Modern Go (1.21+), 패턴 결정 가이드 |
| 기본 | `/go:go-microservice` | MSA 프로젝트 구조, 헥사고날 아키텍처 |
| 에러 | `/go:effective-go` | 에러 처리 패턴, 래핑 |
| 웹 | `/go:go-gin` | Gin 프레임워크 패턴 |
| DB | `/go:go-database` | pgx, sqlc, sqlx, ent, bun |
| 동시성 | `/go:concurrency-go` | Mutex, Channel, Worker Pool |
| 테스트 | `/go:go-testing` | Table-driven testing |
| 리팩토링 | `/go:refactoring-go` | Go 리팩토링 패턴 |
| 클린 코드 | `/dx:clean-code` | Guard Clause, Cognitive Complexity, 네이밍 |

### 상황별 요청 예시

```
"Go MSA 프로젝트 구조 잡아줘"
→ /go:go-performance + /go:go-microservice + /go:effective-go

"Worker Pool 패턴 구현해줘"
→ /go:go-performance + /go:concurrency-go

"sqlc로 DB 레이어 설계해줘"
→ /go:go-database + /infra:database

"Table-driven test 작성해줘"
→ /go:go-testing + /go:effective-go

"Go 에러 핸들링 + OTel 통합 리뷰해줘"
→ /go:go-performance + /go:effective-go

"Go 클린 코드 리뷰해줘"
→ /go:go-performance + /dx:clean-code + /go:refactoring-go
```

---

## MSA 고급 조합

대규모 분산 시스템 설계 시 사용하는 조합.

### 서비스 설계

```
서비스 경계 정의:
  architect-agent + /architecture:msa-ddd + /architecture:msa-api-gateway-patterns

이벤트 드리븐 설계:
  architect-agent + /architecture:msa-event-driven + /architecture:msa-cqrs-eventsourcing

상태머신 설계:
  /architecture:state-machine + /architecture:msa-saga
```

### 복원력/신뢰성

```
장애 격리:
  /architecture:msa-resilience + /architecture:cell-based-architecture

분산 트랜잭션:
  /architecture:msa-saga + /architecture:distributed-lock

대규모 트래픽:
  /architecture:high-traffic-design + /infra:database-sharding + /messaging:redis-streams
```

### 메시징

```
Kafka 기반:
  /messaging:kafka + /messaging:kafka-patterns + /messaging:kafka-advanced

이벤트 스트리밍:
  /messaging:kafka-streams + /messaging:kafka-connect-cdc

경량 메시징:
  /messaging:rabbitmq 또는 /messaging:nats-messaging
```

---

## 관련 시나리오

- [신규 MSA 서비스 개발](../scenarios/new-microservice.md) — Go 주문 서비스 구축 워크스루
- [프로덕션 장애 대응](../scenarios/production-incident.md) — OOMKilled 장애 대응 워크스루
