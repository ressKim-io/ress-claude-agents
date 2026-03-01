**English** | [한국어](../ko/personas/backend-dev.md)

# Backend Developer Guide

> Agent + skill usage guide for Java/Go backend developers

---

## First 5 Minutes After Install

- [ ] Run `./install.sh --global --all --with-skills`
- [ ] Type `/agents` in Claude Code to see the agent list
- [ ] Try `"Review my Java code"` or `"Review my Go code"`
- [ ] Try `"Run a security scan"`

---

## Everyday Combos

> Full combo table: [quick-reference.md](../quick-reference.md#2-backend-developer-combos)

### Coding Cycle

```
1. While coding
   → java-expert or go-expert suggests review feedback

2. After code is ready
   → "Review my code" → code-reviewer runs
   → "Run a security scan" → security-scanner runs

3. Commit / PR
   → "Create a PR" → git-workflow runs
```

### Frequently Used Skills

| Daily | 1-2x per week | Project kickoff |
|-------|--------------|----------------|
| `/effective-java` or `/effective-go` | `/msa-resilience` | `/msa-ddd` |
| `/spring-patterns` or `/go-microservice` | `/database` | `/api-design` |
| `/spring-testing` or `/go-testing` | `/msa-event-driven` | `/hexagonal-clean-architecture` |

---

## Java / Spring Section

### Core Agents

| Agent | Use Case |
|-------|----------|
| `java-expert` | Virtual Threads, WebFlux, JVM tuning, high-traffic |
| `code-reviewer` | Code quality, pattern consistency, bug detection |
| `database-expert` | PostgreSQL tuning, PgBouncer, query optimization |
| `database-expert-mysql` | MySQL/InnoDB tuning, ProxySQL |

### Core Skills

| Category | Skill | Key Content |
|----------|-------|-------------|
| Basics | `/effective-java` | Record, Builder, DI, immutability, Modern Java |
| Basics | `/spring-patterns` | @Transactional, DTO/Entity, exception strategy, layering |
| Data | `/spring-data` | JPA, QueryDSL patterns |
| Data | `/spring-jooq` | jOOQ DSL, code generation, Keyset Pagination |
| Caching | `/spring-cache` | Redis caching strategies |
| Security | `/spring-security` | Security, Method Security |
| Auth | `/spring-oauth2` | OAuth2, JWT |
| Testing | `/spring-testing` | JUnit 5, Mockito |
| Testing | `/spring-testcontainers` | Testcontainers, REST Assured |
| Concurrency | `/concurrency-spring` | @Async, Virtual Threads |
| Refactoring | `/refactoring-spring` | Spring refactoring patterns |

### Example Requests

```
"I want to migrate to Virtual Threads"
→ java-expert + /concurrency-spring

"I have a JPA N+1 problem"
→ database-expert + /spring-data + /database

"Implement OAuth2 + JWT authentication"
→ /spring-oauth2 + /spring-security

"Write integration tests with Testcontainers"
→ /spring-testcontainers + /spring-testing
```

---

## Go Section

### Core Agents

| Agent | Use Case |
|-------|----------|
| `go-expert` | Worker Pool, Fan-Out/In, sync.Pool, pprof |
| `code-reviewer` | Code quality, Go idiom compliance |
| `database-expert` | PostgreSQL + pgx/sqlc optimization |

### Core Skills

| Category | Skill | Key Content |
|----------|-------|-------------|
| Basics | `/effective-go` | Go Proverbs, Modern Go (1.21+), pattern decision guide |
| Basics | `/go-microservice` | MSA project structure, hexagonal architecture |
| Errors | `/go-errors` | Error handling patterns, wrapping |
| Web | `/go-gin` | Gin framework patterns |
| DB | `/go-database` | pgx, sqlc, sqlx, ent, bun |
| Concurrency | `/concurrency-go` | Mutex, Channel, Worker Pool |
| Testing | `/go-testing` | Table-driven testing |
| Refactoring | `/refactoring-go` | Go refactoring patterns |

### Example Requests

```
"Set up a Go MSA project structure"
→ go-expert + /go-microservice + /effective-go

"Implement a Worker Pool pattern"
→ go-expert + /concurrency-go

"Design a DB layer with sqlc"
→ /go-database + /database

"Write table-driven tests"
→ /go-testing + /effective-go
```

---

## Advanced MSA Combos

Combos for designing large-scale distributed systems.

### Service Design

```
Defining service boundaries:
  architect-agent + /msa-ddd + /msa-api-gateway-patterns

Event-driven design:
  architect-agent + /msa-event-driven + /msa-cqrs-eventsourcing

State machine design:
  /state-machine + /msa-saga
```

### Resilience / Reliability

```
Failure isolation:
  /msa-resilience + /cell-based-architecture

Distributed transactions:
  saga-agent + /msa-saga + /distributed-lock

High traffic:
  /high-traffic-design + /database-sharding + /redis-streams
```

### Messaging

```
Kafka-based:
  /kafka + /kafka-patterns + /kafka-advanced

Event streaming:
  /kafka-streams + /kafka-connect-cdc

Lightweight messaging:
  /rabbitmq or /nats-messaging
```

---

## Related Scenarios

- [Build a New Microservice](../scenarios/new-microservice.md) — Go order service walkthrough
- [Production Incident Response](../scenarios/production-incident.md) — OOMKilled incident walkthrough
