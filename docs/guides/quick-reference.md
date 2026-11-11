**English** | [한국어](ko/quick-reference.md)

# Combo Reference

> Recommended agent + skill combos by situation. This is the answer to "What should I use?"

---

## 1. Core Essentials — Every Developer Must Know

Know these before you start.

### Auto-Applied Rules (Always Active)

| Rule | Purpose |
|------|---------|
| `workflow` | Enforces Explore → Plan → Code → Verify → Commit order |
| `testing` | TDD, Given-When-Then, 80%+ coverage |
| `git` | Conventional Commits, PR 400-line limit |
| `security` | No hardcoded secrets, input validation |
| `debugging` | Reproduce → Diagnose → Root Cause → Fix |
| `clean-code` | Method 20-50 lines, Cognitive Complexity ≤15, Guard Clause, WHY-only comments |

### Core Agents (Most Frequently Used)

| Agent | When to Use | Trigger |
|-------|------------|---------|
| `code-reviewer` | After code changes | `"Review my code"` |
| `security-scanner` | Security vulnerability check | `"Run a security scan"` |
| `git-workflow` | Commit, PR automation | `"Create a PR"` |

---

## 2. Backend Developer Combos

> Detailed guide: [personas/backend-dev.md](personas/backend-dev.md)

| Situation | Core Agent | Supporting Skills | How to Request |
|-----------|-----------|-------------------|----------------|
| Java code review | `/java:jvm-performance` | `/java:effective-java`, `/java:spring-patterns` | "Review my Java code" |
| Go code review | `/go:go-performance` | `/go:effective-go`, `/go:go-microservice` | "Review my Go code" |
| API design | `architect-agent` | `/architecture:api-design`, `/architecture:grpc` | "Review my REST API design" |
| MSA service decomposition | `architect-agent` | `/architecture:msa-ddd`, `/architecture:hexagonal-clean-architecture` | "Design service boundaries" |
| Distributed transactions | — | `/architecture:msa-saga`, `/architecture:msa-event-driven` | "Implement the Saga pattern" |
| Resilience patterns | `/java:jvm-performance` | `/architecture:msa-resilience`, `/java:spring-cache` | "Set up a Circuit Breaker" |
| DB performance issues | — | `/infra:postgresql-operations`, `/infra:mysql-operations`, `/infra:database-sharding` | "Optimize this query" |
| Redis caching | — | `/infra:redis-operations`, `/java:spring-cache`, `/architecture:distributed-lock` | "Design a Redis caching strategy" |
| Load testing | `load-tester` | `/sre:load-testing` | "Write a K6 load test scenario" |
| Writing tests | `code-reviewer` | `/java:spring-testing`, `/go:go-testing` | "Write test code" |
| Clean code review | `/dx:clean-code` | `/dx:clean-code`, `/dx:refactoring-principles` | "Check clean code quality" |
| Security code review | `/dx:clean-code` | `/java:effective-java` or `/go:effective-go` | "Security review my Java/Go code" |

### Java Combos

```
New Spring project:
  /java:spring-patterns → /java:effective-java → /java:spring-security → /java:spring-testing

Spring performance optimization:
  /java:jvm-performance → /java:concurrency-spring → /java:spring-cache → /java:spring-jooq

Clean code + refactoring:
  /java:jvm-performance → /dx:clean-code → /dx:refactoring-principles → /java:refactoring-spring

Security hardening:
  /java:spring-security-review → security-scanner → /java:spring-security
```

### Go Combos

```
New Go project:
  /go:effective-go → /go:go-microservice → /go:go-database → /go:go-testing

Go performance optimization:
  /go:go-performance → /go:concurrency-go → /go:go-database → /go:refactoring-go

Clean code + refactoring:
  /go:go-performance → /dx:clean-code → /dx:refactoring-principles → /go:refactoring-go

Error handling + OTel:
  /go:go-performance → /observability:observability-otel → /go:effective-go
```

---

## 3. DevOps / SRE Combos

> Detailed guide: [personas/devops-sre.md](personas/devops-sre.md)

| Situation | Core Agent | Supporting Skills | How to Request |
|-----------|-----------|-------------------|----------------|
| K8s troubleshooting | `k8s-troubleshooter` | `/k8s:k8s-security`, `/k8s:k8s-autoscaling` | "My pods are crashing, analyze it" |
| Production incident | `incident-responder` | `/observability:observability`, `/observability:monitoring-troubleshoot` | "Handle this production incident" |
| Terraform review | `terraform-reviewer` | `/infra:terraform-modules`, `/infra:terraform-security` | "Review my Terraform plan" |
| GitOps deployment | `ci-optimizer` | `/cicd:gitops-argocd`, `/cicd:deployment-strategies` | "Set up ArgoCD deployment" |
| Observability setup | — | `/observability:observability-otel`, `/observability:observability-otel-scale`, `/observability:monitoring-grafana` | "Configure OTel Collector" |
| Service mesh | `k8s-troubleshooter` | `/service-mesh:istio-core`, `/service-mesh:linkerd` | "Review Istio configuration" |
| Cost optimization | `cost-analyzer` | `/sre:finops`, `/sre:finops-tools` | "Analyze cloud costs" |
| Chaos testing | `incident-responder` | `/sre:chaos-engineering` | "Design a chaos experiment" |
| DR planning | `k8s-troubleshooter` | `/sre:disaster-recovery` | "Create a DR plan" |
| CI/CD optimization | `ci-optimizer` | `/cicd:cicd-devsecops`, `/cicd:cicd-policy` | "Analyze the CI pipeline" |
| K8s manifest review | `k8s-reviewer` | `/k8s:k8s-security`, `/k8s:k8s-helm` | "Review my K8s manifests" |
| Dockerfile review | `dockerfile-reviewer` | `/infra:docker` | "Review my Dockerfile" |
| CI/CD pipeline review | `cicd-reviewer` | `/cicd:cicd-devsecops` | "Review my GitHub Actions" |
| GitOps review | `gitops-reviewer` | `/cicd:gitops-argocd` | "Review my ArgoCD config" |
| Observability review | `observability-reviewer` | `/observability:observability-otel` | "Review my Prometheus rules" |

### Security Review Combos (Red Team Prep)

```
K8s security audit:
  k8s-security-reviewer + network-security-reviewer → /k8s:k8s-security

Container security:
  container-security-reviewer + dockerfile-reviewer → /infra:docker

CI/CD security:
  cicd-security-reviewer → /cicd:supply-chain-security → /cicd:cicd-devsecops

Full pre-pentest:
  k8s-security-reviewer + container-security-reviewer + cicd-security-reviewer + network-security-reviewer
```

### IaC Combos

```
EKS cluster setup:
  terraform-reviewer → /infra:aws-eks → /infra:aws-eks-advanced → /k8s:k8s-security

Multi-cloud IaC:
  terraform-reviewer → /infra:crossplane → /infra:crossplane-advanced → /infra:terraform-modules
```

### Observability Combos

```
Full Observability Stack:
  /observability:observability-otel → /observability:monitoring-grafana → /observability:monitoring-metrics → /observability:alerting-discord

eBPF-based Zero-Code:
  /observability:ebpf-observability → /observability:ebpf-observability-advanced
```

---

## 4. Fullstack / Generalist Combos

> Detailed guide: [personas/fullstack-generalist.md](personas/fullstack-generalist.md)

| Situation | Core Agent | Supporting Skills | How to Request |
|-----------|-----------|-------------------|----------------|
| New project setup | `architect-agent` | `/architecture:api-design`, `/infra:docker` | "Design the project structure" |
| Code cleanup | `code-reviewer` | `/dx:clean-code`, `/dx:refactoring-principles` | "Refactor this code" |
| Clean code check | `/dx:clean-code` | `/dx:clean-code` | "Check code readability" |
| PR automation | `git-workflow` | `/dx:conventional-commits`, `/dx:git-workflow` | "Create a PR" |
| Dev environment setup | `platform-engineer` | `/dx:local-dev-makefile`, `/infra:docker` | "Set up local dev environment" |
| Documentation | `dev-logger` | `/dx:docs-as-code` | "Generate API docs" |
| Security check | `security-scanner` | `/k8s:k8s-security`, `/infra:terraform-security` | "Run a security scan" |
| Tech decisions | `architect-agent` | Relevant domain skills | "Compare A vs B" |

---

## 5. Advanced Combos — Agent Chaining

Use multiple agents in sequence for complex workflows.

### New MSA API Development (End-to-End)

> Scenario guide: [scenarios/new-microservice.md](scenarios/new-microservice.md)

```
1. architect-agent    → Design service boundaries, define API contracts
      ↓
2. /java:jvm-performance or /go:go-performance → Implement code, apply patterns
      ↓
3. code-reviewer      → Code review, quality verification
      ↓
4. /java:jvm-performance or /go:go-performance → Clean code + security review (built-in checklists)
      ↓
5. security-scanner   → Security vulnerability check
      ↓
6. /sre:load-testing      → Performance verification
      ↓
7. git-workflow       → Create PR
```

### Production Incident Response

> Scenario guide: [scenarios/production-incident.md](scenarios/production-incident.md)

```
1. incident-responder → Auto-triage, severity classification
      ↓
2. k8s-troubleshooter → Cluster diagnostics
      ↓
3. /infra:postgresql-operations → DB issue analysis (if needed)
      ↓
4. /observability:observability-otel → Trace/metrics analysis
      ↓
5. dev-logger         → Incident record (/devlog:log-trouble)
```

### IDP Bootstrap (Platform)

> Scenario guide: [scenarios/platform-bootstrap.md](scenarios/platform-bootstrap.md)

```
1. platform-engineer  → IDP design, Backstage setup
      ↓
2. architect-agent    → Define Golden Paths
      ↓
3. terraform-reviewer → IaC review, security verification
      ↓
4. ci-optimizer       → CI/CD pipeline optimization
      ↓
5. /observability:observability-otel → Observability defaults
      ↓
6. finops-advisor     → Cost strategy
```
