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
| Java code review | `java-expert` | `/effective-java`, `/spring-patterns` | "Review my Java code" |
| Go code review | `go-expert` | `/effective-go`, `/go-microservice` | "Review my Go code" |
| API design | `architect-agent` | `/api-design`, `/grpc` | "Review my REST API design" |
| MSA service decomposition | `architect-agent` | `/msa-ddd`, `/hexagonal-clean-architecture` | "Design service boundaries" |
| Distributed transactions | `saga-agent` | `/msa-saga`, `/msa-event-driven` | "Implement the Saga pattern" |
| Resilience patterns | `java-expert` | `/msa-resilience`, `/spring-cache` | "Set up a Circuit Breaker" |
| DB performance issues | `database-expert` | `/database`, `/database-sharding` | "Optimize this query" |
| Redis caching | `redis-expert` | `/spring-cache`, `/distributed-lock` | "Design a Redis caching strategy" |
| Load testing | `load-tester-k6` | `/load-testing` | "Write a K6 load test scenario" |
| Writing tests | `code-reviewer` | `/spring-testing`, `/go-testing` | "Write test code" |
| Clean code review | `java-expert` or `go-expert` | `/clean-code`, `/refactoring-principles` | "Check clean code quality" |
| Security code review | `java-expert` or `go-expert` | `/effective-java` or `/effective-go` | "Security review my Java/Go code" |

### Java Combos

```
New Spring project:
  /spring-patterns → /effective-java → /spring-security → /spring-testing

Spring performance optimization:
  java-expert → /concurrency-spring → /spring-cache → /spring-jooq

Clean code + refactoring:
  java-expert → /clean-code → /refactoring-principles → /refactoring-spring

Security hardening:
  java-expert (security checklist) → security-scanner → /spring-security
```

### Go Combos

```
New Go project:
  /effective-go → /go-microservice → /go-database → /go-testing

Go performance optimization:
  go-expert → /concurrency-go → /go-database → /refactoring-go

Clean code + refactoring:
  go-expert → /clean-code → /refactoring-principles → /refactoring-go

Error handling + OTel:
  go-expert (Handle OR Return + OTel) → /observability-otel → /go-errors
```

---

## 3. DevOps / SRE Combos

> Detailed guide: [personas/devops-sre.md](personas/devops-sre.md)

| Situation | Core Agent | Supporting Skills | How to Request |
|-----------|-----------|-------------------|----------------|
| K8s troubleshooting | `k8s-troubleshooter` | `/k8s-security`, `/k8s-autoscaling` | "My pods are crashing, analyze it" |
| Production incident | `incident-responder` | `/observability`, `/monitoring-troubleshoot` | "Handle this production incident" |
| Terraform review | `terraform-reviewer` | `/terraform-modules`, `/terraform-security` | "Review my Terraform plan" |
| GitOps deployment | `ci-optimizer` | `/gitops-argocd`, `/deployment-strategies` | "Set up ArgoCD deployment" |
| Observability setup | `otel-expert` | `/observability-otel`, `/monitoring-grafana` | "Configure OTel Collector" |
| Service mesh | `k8s-troubleshooter` | `/istio-core`, `/linkerd` | "Review Istio configuration" |
| Cost optimization | `cost-analyzer` | `/finops`, `/finops-tools` | "Analyze cloud costs" |
| Chaos testing | `incident-responder` | `/chaos-engineering` | "Design a chaos experiment" |
| DR planning | `k8s-troubleshooter` | `/disaster-recovery` | "Create a DR plan" |
| CI/CD optimization | `ci-optimizer` | `/cicd-devsecops`, `/cicd-policy` | "Analyze the CI pipeline" |
| K8s manifest review | `k8s-reviewer` | `/k8s-security`, `/k8s-helm` | "Review my K8s manifests" |
| Dockerfile review | `dockerfile-reviewer` | `/docker` | "Review my Dockerfile" |
| CI/CD pipeline review | `cicd-reviewer` | `/cicd-devsecops` | "Review my GitHub Actions" |
| GitOps review | `gitops-reviewer` | `/gitops-argocd` | "Review my ArgoCD config" |
| Observability review | `observability-reviewer` | `/observability-otel` | "Review my Prometheus rules" |

### Security Review Combos (Red Team Prep)

```
K8s security audit:
  k8s-security-reviewer + network-security-reviewer → /k8s-security

Container security:
  container-security-reviewer + dockerfile-reviewer → /docker

CI/CD security:
  cicd-security-reviewer → /supply-chain-security → /cicd-devsecops

Full pre-pentest:
  k8s-security-reviewer + container-security-reviewer + cicd-security-reviewer + network-security-reviewer
```

### IaC Combos

```
EKS cluster setup:
  terraform-reviewer → /aws-eks → /aws-eks-advanced → /k8s-security

Multi-cloud IaC:
  terraform-reviewer → /crossplane → /crossplane-advanced → /terraform-modules
```

### Observability Combos

```
Full Observability Stack:
  otel-expert → /observability-otel → /monitoring-grafana → /monitoring-metrics → /alerting-discord

eBPF-based Zero-Code:
  otel-expert → /ebpf-observability → /ebpf-observability-advanced
```

---

## 4. Fullstack / Generalist Combos

> Detailed guide: [personas/fullstack-generalist.md](personas/fullstack-generalist.md)

| Situation | Core Agent | Supporting Skills | How to Request |
|-----------|-----------|-------------------|----------------|
| New project setup | `architect-agent` | `/api-design`, `/docker` | "Design the project structure" |
| Code cleanup | `code-reviewer` | `/clean-code`, `/refactoring-principles` | "Refactor this code" |
| Clean code check | `java-expert` or `go-expert` | `/clean-code` | "Check code readability" |
| PR automation | `git-workflow` | `/conventional-commits`, `/git-workflow` | "Create a PR" |
| Dev environment setup | `platform-engineer` | `/local-dev-makefile`, `/docker` | "Set up local dev environment" |
| Documentation | `dev-logger` | `/docs-as-code` | "Generate API docs" |
| Security check | `security-scanner` | `/k8s-security`, `/terraform-security` | "Run a security scan" |
| Tech decisions | `architect-agent` | Relevant domain skills | "Compare A vs B" |

---

## 5. Advanced Combos — Agent Chaining

Use multiple agents in sequence for complex workflows.

### New MSA API Development (End-to-End)

> Scenario guide: [scenarios/new-microservice.md](scenarios/new-microservice.md)

```
1. architect-agent    → Design service boundaries, define API contracts
      ↓
2. java-expert or go-expert → Implement code, apply patterns
      ↓
3. code-reviewer      → Code review, quality verification
      ↓
4. java-expert or go-expert → Clean code + security review (built-in checklists)
      ↓
5. security-scanner   → Security vulnerability check
      ↓
6. load-tester-k6     → Performance verification
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
3. database-expert    → DB issue analysis (if needed)
      ↓
4. otel-expert        → Trace/metrics analysis
      ↓
5. dev-logger         → Incident record (/log-trouble)
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
5. otel-expert        → Observability defaults
      ↓
6. finops-advisor     → Cost strategy
```
