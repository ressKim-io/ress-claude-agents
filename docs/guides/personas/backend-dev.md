**English** | [한국어](../ko/personas/backend-dev.md)

# Backend Developer Guide

> Agent + skill usage guide for Java/Go backend developers

---

## First 5 Minutes After Install

- [ ] Run `/plugin marketplace add ressKim-io/ress-claude-agents`, then `/plugin install` `go@ress`, `java@ress`, `architecture@ress`, `dx@ress`
- [ ] Type `/agents` in Claude Code to see the agent list
- [ ] Try `"Review my Java code"` or `"Review my Go code"`
- [ ] Try `"Run a security scan"`

---

## Everyday Combos

> Full combo table: [quick-reference.md](../quick-reference.md#2-backend-developer-combos)

### Coding Cycle

```
1. While coding
   → /java:jvm-performance or /go:go-performance suggests review feedback

2. After code is ready
   → "Review my code" → code-reviewer runs
   → "Run a security scan" → security-scanner runs

3. Commit / PR
   → "Create a PR" → git-workflow runs
```

### Frequently Used Skills

| Daily | 1-2x per week | Project kickoff |
|-------|--------------|----------------|
| `/java:effective-java` or `/go:effective-go` | `/architecture:msa-resilience` | `/architecture:msa-ddd` |
| `/java:spring-patterns` or `/go:go-microservice` | `/infra:database` | `/architecture:api-design` |
| `/java:spring-testing` or `/go:go-testing` | `/architecture:msa-event-driven` | `/architecture:hexagonal-clean-architecture` |
| `/dx:clean-code` | `/dx:refactoring-principles` | `/dx:clean-code` |

---

## Java / Spring Section

### Core Agents

| Agent / Skill | Use Case |
|-------|----------|
| `/java:jvm-performance` | Virtual Threads, WebFlux, JVM tuning, high-traffic |
| `code-reviewer` | Code quality, pattern consistency, bug detection |

### Core Skills

| Category | Skill | Key Content |
|----------|-------|-------------|
| Basics | `/java:effective-java` | Record, Builder, DI, immutability, Modern Java |
| Basics | `/java:spring-patterns` | @Transactional, DTO/Entity, exception strategy, layering |
| Data | `/java:spring-data` | JPA, QueryDSL patterns |
| Data | `/java:spring-jooq` | jOOQ DSL, code generation, Keyset Pagination |
| Caching | `/java:spring-cache` | Redis caching strategies |
| Security | `/java:spring-security` | Security, Method Security |
| Auth | `/java:spring-oauth2` | OAuth2, JWT |
| Testing | `/java:spring-testing` | JUnit 5, Mockito |
| Testing | `/java:spring-testcontainers` | Testcontainers, REST Assured |
| Concurrency | `/java:concurrency-spring` | @Async, Virtual Threads |
| Refactoring | `/java:refactoring-spring` | Spring refactoring patterns |
| Clean Code | `/dx:clean-code` | Guard Clause, Cognitive Complexity, naming, Tell Don't Ask |

### Example Requests

```
"I want to migrate to Virtual Threads"
→ /java:jvm-performance + /java:concurrency-spring

"I have a JPA N+1 problem"
→ /infra:postgresql-operations + /java:spring-data + /infra:database

"Implement OAuth2 + JWT authentication"
→ /java:spring-oauth2 + /java:spring-security

"Write integration tests with Testcontainers"
→ /java:spring-testcontainers + /java:spring-testing

"Check clean code quality and readability"
→ /java:jvm-performance + /dx:clean-code + /dx:refactoring-principles

"Security review my Java code"
→ /java:spring-security-review + security-scanner
```

---

## Go Section

### Core Agents

| Agent / Skill | Use Case |
|-------|----------|
| `/go:go-performance` | Worker Pool, Fan-Out/In, sync.Pool, pprof |
| `code-reviewer` | Code quality, Go idiom compliance |

### Core Skills

| Category | Skill | Key Content |
|----------|-------|-------------|
| Basics | `/go:effective-go` | Go Proverbs, Modern Go (1.21+), pattern decision guide |
| Basics | `/go:go-microservice` | MSA project structure, hexagonal architecture |
| Errors | `/go:effective-go` | Error handling patterns, wrapping |
| Web | `/go:go-gin` | Gin framework patterns |
| DB | `/go:go-database` | pgx, sqlc, sqlx, ent, bun |
| Concurrency | `/go:concurrency-go` | Mutex, Channel, Worker Pool |
| Testing | `/go:go-testing` | Table-driven testing |
| Refactoring | `/go:refactoring-go` | Go refactoring patterns |
| Clean Code | `/dx:clean-code` | Guard Clause, Cognitive Complexity, naming |

### Example Requests

```
"Set up a Go MSA project structure"
→ /go:go-performance + /go:go-microservice + /go:effective-go

"Implement a Worker Pool pattern"
→ /go:go-performance + /go:concurrency-go

"Design a DB layer with sqlc"
→ /go:go-database + /infra:database

"Write table-driven tests"
→ /go:go-testing + /go:effective-go

"Review Go error handling + OTel integration"
→ /go:go-performance + /go:effective-go

"Clean code review for Go"
→ /go:go-performance + /dx:clean-code + /go:refactoring-go
```

---

## Advanced MSA Combos

Combos for designing large-scale distributed systems.

### Service Design

```
Defining service boundaries:
  architect-agent + /architecture:msa-ddd + /architecture:msa-api-gateway-patterns

Event-driven design:
  architect-agent + /architecture:msa-event-driven + /architecture:msa-cqrs-eventsourcing

State machine design:
  /architecture:state-machine + /architecture:msa-saga
```

### Resilience / Reliability

```
Failure isolation:
  /architecture:msa-resilience + /architecture:cell-based-architecture

Distributed transactions:
  /architecture:msa-saga + /architecture:distributed-lock

High traffic:
  /architecture:high-traffic-design + /infra:database-sharding + /messaging:redis-streams
```

### Messaging

```
Kafka-based:
  /messaging:kafka + /messaging:kafka-patterns + /messaging:kafka-advanced

Event streaming:
  /messaging:kafka-streams + /messaging:kafka-connect-cdc

Lightweight messaging:
  /messaging:rabbitmq or /messaging:nats-messaging
```

---

## Related Scenarios

- [Build a New Microservice](../scenarios/new-microservice.md) — Go order service walkthrough
- [Production Incident Response](../scenarios/production-incident.md) — OOMKilled incident walkthrough
