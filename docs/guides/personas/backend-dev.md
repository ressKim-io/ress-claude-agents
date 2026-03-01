# 백엔드 개발자 가이드

> Java/Go 백엔드 개발자를 위한 에이전트 + 스킬 활용 가이드

---

## 설치 후 첫 5분

- [ ] `./install.sh --global --all --with-skills` 실행
- [ ] Claude Code에서 `/agents` 입력 → 에이전트 목록 확인
- [ ] `"Java 코드 리뷰해줘"` 또는 `"Go 코드 리뷰해줘"` 시도
- [ ] `"보안 취약점 검사해줘"` 시도

---

## 매일 쓰는 조합

> 전체 조합 테이블: [quick-reference.md](../quick-reference.md#2-백엔드-개발자-콤보)

### 코드 작성 사이클

```
1. 코드 작성 중
   → java-expert 또는 go-expert가 자동 리뷰 제안

2. 코드 완성 후
   → "코드 리뷰해줘" → code-reviewer 실행
   → "보안 검사해줘" → security-scanner 실행

3. 커밋/PR
   → "PR 만들어줘" → git-workflow 실행
```

### 자주 쓰는 스킬

| 매일 | 주 1-2회 | 프로젝트 초기 |
|------|---------|-------------|
| `/effective-java` 또는 `/effective-go` | `/msa-resilience` | `/msa-ddd` |
| `/spring-patterns` 또는 `/go-microservice` | `/database` | `/api-design` |
| `/spring-testing` 또는 `/go-testing` | `/msa-event-driven` | `/hexagonal-clean-architecture` |

---

## Java / Spring 섹션

### 핵심 에이전트

| 에이전트 | 용도 |
|---------|------|
| `java-expert` | Virtual Threads, WebFlux, JVM 튜닝, 대용량 트래픽 |
| `code-reviewer` | 코드 품질, 패턴 일관성, 버그 탐지 |
| `database-expert` | PostgreSQL 튜닝, PgBouncer, 쿼리 최적화 |
| `database-expert-mysql` | MySQL/InnoDB 튜닝, ProxySQL |

### 핵심 스킬

| 카테고리 | 스킬 | 핵심 내용 |
|---------|------|----------|
| 기본 | `/effective-java` | Record, Builder, DI, 불변 객체, Modern Java |
| 기본 | `/spring-patterns` | @Transactional, DTO/Entity, 예외 전략, 계층 구조 |
| 데이터 | `/spring-data` | JPA, QueryDSL 패턴 |
| 데이터 | `/spring-jooq` | jOOQ DSL, 코드 생성, Keyset Pagination |
| 캐싱 | `/spring-cache` | Redis 캐싱 전략 |
| 보안 | `/spring-security` | Security, Method Security |
| 인증 | `/spring-oauth2` | OAuth2, JWT |
| 테스트 | `/spring-testing` | JUnit 5, Mockito |
| 테스트 | `/spring-testcontainers` | Testcontainers, REST Assured |
| 동시성 | `/concurrency-spring` | @Async, Virtual Threads |
| 리팩토링 | `/refactoring-spring` | Spring 리팩토링 패턴 |

### 상황별 요청 예시

```
"Virtual Threads로 마이그레이션하고 싶어"
→ java-expert + /concurrency-spring

"JPA N+1 문제가 발생해"
→ database-expert + /spring-data + /database

"OAuth2 + JWT 인증 구현해줘"
→ /spring-oauth2 + /spring-security

"Testcontainers로 통합 테스트 작성해줘"
→ /spring-testcontainers + /spring-testing
```

---

## Go 섹션

### 핵심 에이전트

| 에이전트 | 용도 |
|---------|------|
| `go-expert` | Worker Pool, Fan-Out/In, sync.Pool, pprof |
| `code-reviewer` | 코드 품질, Go idiom 준수 |
| `database-expert` | PostgreSQL + pgx/sqlc 최적화 |

### 핵심 스킬

| 카테고리 | 스킬 | 핵심 내용 |
|---------|------|----------|
| 기본 | `/effective-go` | Go Proverbs, Modern Go (1.21+), 패턴 결정 가이드 |
| 기본 | `/go-microservice` | MSA 프로젝트 구조, 헥사고날 아키텍처 |
| 에러 | `/go-errors` | 에러 처리 패턴, 래핑 |
| 웹 | `/go-gin` | Gin 프레임워크 패턴 |
| DB | `/go-database` | pgx, sqlc, sqlx, ent, bun |
| 동시성 | `/concurrency-go` | Mutex, Channel, Worker Pool |
| 테스트 | `/go-testing` | Table-driven testing |
| 리팩토링 | `/refactoring-go` | Go 리팩토링 패턴 |

### 상황별 요청 예시

```
"Go MSA 프로젝트 구조 잡아줘"
→ go-expert + /go-microservice + /effective-go

"Worker Pool 패턴 구현해줘"
→ go-expert + /concurrency-go

"sqlc로 DB 레이어 설계해줘"
→ /go-database + /database

"Table-driven test 작성해줘"
→ /go-testing + /effective-go
```

---

## MSA 고급 조합

대규모 분산 시스템 설계 시 사용하는 조합.

### 서비스 설계

```
서비스 경계 정의:
  architect-agent + /msa-ddd + /msa-api-gateway-patterns

이벤트 드리븐 설계:
  architect-agent + /msa-event-driven + /msa-cqrs-eventsourcing

상태머신 설계:
  /state-machine + /msa-saga
```

### 복원력/신뢰성

```
장애 격리:
  /msa-resilience + /cell-based-architecture

분산 트랜잭션:
  saga-agent + /msa-saga + /distributed-lock

대규모 트래픽:
  /high-traffic-design + /database-sharding + /redis-streams
```

### 메시징

```
Kafka 기반:
  /kafka + /kafka-patterns + /kafka-advanced

이벤트 스트리밍:
  /kafka-streams + /kafka-connect-cdc

경량 메시징:
  /rabbitmq 또는 /nats-messaging
```

---

## 관련 시나리오

- [신규 MSA 서비스 개발](../scenarios/new-microservice.md) — Go 주문 서비스 구축 워크스루
- [프로덕션 장애 대응](../scenarios/production-incident.md) — OOMKilled 장애 대응 워크스루
