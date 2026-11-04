**English** | [한국어](../ko/personas/fullstack-generalist.md)

# Fullstack / Generalist Guide

> "Just ask" — A guide to using Claude Code for general development

---

## First 5 Minutes After Install

- [ ] Run `./install.sh --global --all --with-skills`
- [ ] Type `/agents` in Claude Code to see the agent list
- [ ] Try `"Analyze this project structure"`
- [ ] Try `"Review my code"`

---

## Everyday Combos

> Full combo table: [quick-reference.md](../quick-reference.md#4-fullstack--generalist-combos)

### "Just Ask" Pattern

Ask in natural language and the right agent is auto-selected.

```
"Run a security scan"              → security-scanner auto-selected
"My production pods are crashing"  → k8s-troubleshooter auto-selected
"Review my code"                   → code-reviewer auto-selected
"Create a PR"                      → git-workflow auto-selected
"Analyze cloud costs"              → cost-analyzer auto-selected
```

Load specific skills directly with slash commands:

```
/architecture:api-design         → Load REST API design guide
/infra:docker             → Load Dockerfile optimization guide
/java:effective-java     → Load Java pattern decision guide
```

---

## Dev Environment Setup

### Local Development

| Skill | Use Case |
|-------|----------|
| `/dx:local-dev-makefile` | `make up` for full-stack run, Hot Reload |
| `/infra:docker` | Dockerfile optimization, multi-stage builds |
| `/dx:dx-onboarding-environment` | Dev Container automation |

```
"Set up my local dev environment with Docker"
→ /dx:local-dev-makefile + /infra:docker
```

### Cloud IDE

| Skill | Use Case |
|-------|----------|
| `/dx:dx-onboarding-gitpod` | Gitpod/Codespaces setup |
| `/dx:dx-onboarding` | Time-to-First-Deploy optimization |
| `/dx:dx-onboarding-deploy` | First deployment guide |

---

## Code Quality

### Essential Agents

| Agent | When to Use |
|-------|------------|
| `code-reviewer` | After code changes (auto-review) |
| `security-scanner` | After code changes (security check) |
| `git-workflow` | When committing, creating PRs |

### Clean Code & Refactoring

| Skill | Target |
|-------|--------|
| `/dx:clean-code` | Composed Method, Cognitive Complexity, Guard Clause, naming |
| `/dx:refactoring-principles` | Language-agnostic fundamentals |
| `/java:refactoring-spring` | Spring Boot code |
| `/go:refactoring-go` | Go code |

```
Clean code review:
  /java:jvm-performance or /go:go-performance → /dx:clean-code → /dx:refactoring-principles

"Check my code readability"
→ /dx:clean-code + code-reviewer
```

### Tech Decisions

When you're stuck choosing between technologies:

```
"Compare A vs B"
→ architect-agent analyzes trade-offs

"Is this architecture okay?"
→ architect-agent + relevant domain skills

"Compare Kafka vs RabbitMQ vs NATS"
→ /messaging:kafka + /messaging:rabbitmq + /messaging:nats-messaging
```

---

## Record Keeping

### dev-logger Agent

Records your development process as structured markdown.

| Command | Use Case | Example |
|---------|----------|---------|
| `/dx:log-feedback` | Record AI correction requests | Pattern mismatch, omissions |
| `/dx:log-decision` | Record tech decisions | A vs B selection rationale |
| `/dx:log-meta` | Record rule/skill changes | Workflow improvements |
| `/dx:log-trouble` | Record troubleshooting | Error cause, resolution |
| `/dx:log-summary` | Session summary | Run before ending a session |

```
Before ending a session:
  /dx:log-summary → Auto-generates today's work summary
```

---

## Documentation

| Skill | Use Case |
|-------|----------|
| `/dx:docs-as-code` | MkDocs, Docusaurus, TechDocs |
| `/dx:docs-as-code-automation` | API doc automation, Vale linter |
| `/dx:conventional-commits` | Commit message rules, Changelog automation |
| `/dx:token-efficiency` | Claude Code session token efficiency |

---

## Frequently Used Commands

| Category | Command | Description |
|----------|---------|-------------|
| Review | `/backend review` | Backend code review |
| Testing | `/backend test-gen` | Test code generation |
| Docs | `/backend api-doc` | API doc generation |
| Git | `/dx pr-create` | Auto-create PR |
| Git | `/dx changelog` | Generate changelog |
| Session | `/session save` | Save session state |

---

## Recommended Learning Path

```
Week 1: Learn the basic cycle
  - code-reviewer, security-scanner, git-workflow
  - /java:effective-java or /go:effective-go, /dx:clean-code

Week 2: Project structure
  - /architecture:api-design, /infra:docker, /dx:local-dev-makefile
  - Using architect-agent

Week 3: Testing + Observability
  - /java:spring-testing or /go:go-testing
  - /observability:observability, /observability:monitoring-grafana

Week 4+: Domain deep dives
  - Expand into MSA, K8s, or Platform skills based on your interests
```

---

## Related Scenarios

- [Build a New Microservice](../scenarios/new-microservice.md) — Build a service from scratch
- [Production Incident Response](../scenarios/production-incident.md) — Experience incident response
