**English** | [한국어](../ko/scenarios/new-microservice.md)

# Scenario: Build a New Microservice

> A walkthrough for building a Go-based Order Service from scratch

---

## Overview

| Item | Details |
|------|---------|
| **Audience** | Backend developers (Go or Java) |
| **Duration** | 2-3 hours |
| **Prerequisites** | Go 1.21+, Docker, Claude Code installed |
| **Deliverables** | Production-ready Go order service + tests + PR |

---

## Full Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 1     │     │  Step 2     │     │  Step 3     │
│  Service    │────►│  Scaffold   │────►│  Core       │
│  Design     │     │  Structure  │     │  Logic      │
│             │     │             │     │             │
│ architect   │     │ go-expert   │     │ go-expert   │
│ /msa-ddd    │     │ /go-micro   │     │ /go-database│
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       │
       ▼                                       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 4     │     │  Step 5     │     │  Step 6     │
│  Resilience │────►│  Testing    │────►│  Security   │
│  Patterns   │     │             │     │  Review     │
│             │     │             │     │             │
│ /resilience │     │ /go-testing │     │ security-   │
│ saga-agent  │     │ code-review │     │ scanner     │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  Step 7     │
                                        │  Create PR  │
                                        │             │
                                        │ git-workflow│
                                        └─────────────┘
```

---

## Step 1: Service Design

**Tools**: `architect-agent` + `/msa-ddd`

### How to Request

```
"Design an Order Service.
 - Integrates with Payment Service and Inventory Service
 - Define Bounded Contexts
 - Design API contracts (gRPC or REST)
 - Define event list"
```

### What Claude Does

- Creates a Bounded Context Map
- Defines Aggregate Roots (Order, OrderItem)
- Lists domain events (OrderCreated, OrderPaid, OrderCancelled)
- Designs API endpoints

### Checkpoint

- [ ] Are Bounded Context boundaries clear?
- [ ] Are dependencies with other services defined?
- [ ] Are event schemas defined?

---

## Step 2: Scaffold Project Structure

**Tools**: `go-expert` + `/go-microservice`

### How to Request

```
"Generate a Go order service project with hexagonal architecture.
 - Reference /go-microservice skill
 - cmd/server, internal/domain, internal/adapter, internal/port structure"
```

### Expected Result

```
order-service/
├── cmd/server/main.go
├── internal/
│   ├── domain/          # Domain models, business logic
│   │   ├── order.go
│   │   └── event.go
│   ├── port/            # Interfaces (inbound/outbound)
│   │   ├── inbound.go
│   │   └── outbound.go
│   └── adapter/         # Implementations
│       ├── http/
│       ├── grpc/
│       └── postgres/
├── go.mod
└── Dockerfile
```

### Checkpoint

- [ ] Are hexagonal architecture layers separated?
- [ ] Is the domain layer free of external dependencies?

---

## Step 3: Implement Core Business Logic

**Tools**: `go-expert` + `/go-database` + `/effective-go`

### How to Request

```
"Implement Order Aggregate core logic.
 - Order creation, payment confirmation, cancellation
 - State transitions: CREATED → PAID → SHIPPED → DELIVERED / CANCELLED
 - PostgreSQL repository (using pgx)"
```

### What Claude Does

- Implements Order domain model + state machine
- Repository interface + PostgreSQL adapter
- HTTP/gRPC handlers

### Checkpoint

- [ ] Are state transitions managed within the domain model?
- [ ] Does error handling follow Go idioms?

---

## Step 4: Apply Resilience Patterns

**Tools**: `saga-agent` + `/msa-resilience` + `/msa-event-driven`

### How to Request

```
"Apply resilience patterns to Payment Service calls.
 - Retry (Exponential Backoff + Jitter)
 - Circuit Breaker
 - Timeout
 - Event publishing via Transactional Outbox"
```

### What Claude Does

- Applies Retry/Circuit Breaker/Timeout to external service calls
- Guarantees event publishing with Transactional Outbox pattern
- Compensation transactions (refund on order cancellation)

### Checkpoint

- [ ] Are Circuit Breaker state transitions correct?
- [ ] Is idempotency guaranteed?
- [ ] Are events published within the same transaction?

---

## Step 5: Write Tests

**Tools**: `code-reviewer` + `/go-testing`

### How to Request

```
"Write tests for the order service.
 - Domain logic unit tests (table-driven)
 - Repository integration tests (Testcontainers)
 - HTTP handler tests
 - Happy path + Edge case + Error case"
```

### What Claude Does

- Given-When-Then structured tests
- Table-driven test patterns
- Mock/Stub for external dependencies
- Targeting 95%+ coverage

### Checkpoint

- [ ] Core business logic coverage 95%+?
- [ ] Edge case tests exist (empty order, duplicate payment, etc.)?
- [ ] Tests are independently runnable?

---

## Step 6: Security Review

**Tools**: `security-scanner`

### How to Request

```
"Run a security scan"
```

### What Claude Does

- OWASP Top 10 check
- SQL Injection prevention (parameter binding)
- Hardcoded secrets check
- Input validation check

### Checkpoint

- [ ] SQL queries use parameter binding?
- [ ] Secrets managed via environment variables?
- [ ] Input validation exists?

---

## Step 7: Create PR

**Tools**: `git-workflow`

### How to Request

```
"Create a PR"
```

### What Claude Does

- Conventional Commits format
- Auto-generates PR title + body
- Verifies tests pass

### Checkpoint

- [ ] Commit messages follow Conventional Commits?
- [ ] PR size under 400 lines?
- [ ] All tests passing?

---

## Wrap Up

### Verification

```bash
# Run tests
go test ./... -v -cover

# Lint
golangci-lint run

# Docker build
docker build -t order-service .

# Local run
docker compose up -d
curl http://localhost:8080/health
```

### Next Steps

- [Production Incident Response](production-incident.md) — Handle incidents in production
- `/deployment-strategies` — Canary/Blue-Green deployment strategies
- `/gitops-argocd` — Set up GitOps deployment with ArgoCD
- `/observability-otel` — Add OpenTelemetry instrumentation
