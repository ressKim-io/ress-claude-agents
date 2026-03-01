**English** | [한국어](ko/README.md)

# Usage Guide

> 160 Skills + 27 Agents + 5 Rules — Find the right tool for your situation

---

## Key Concepts in 3 Lines

| Component | Role | How to Load |
|-----------|------|-------------|
| **Skills** | Domain knowledge (patterns, guides, references) | Load on demand with `/skill-name` |
| **Agents** | Autonomous experts (diagnosis, analysis, automation) | Natural language request or select from `/agents` |
| **Rules** | Always-on coding rules (Git, testing, security) | Auto-applied based on file path |

---

## Persona Guides

Choose the guide that fits you.

| Persona | Focus Areas | Guide |
|---------|------------|-------|
| **Backend Developer** | Java/Go, API design, MSA, testing | [personas/backend-dev.md](personas/backend-dev.md) |
| **DevOps / SRE** | K8s, IaC, GitOps, incidents, observability | [personas/devops-sre.md](personas/devops-sre.md) |
| **Fullstack / Generalist** | General development, quick start, learning | [personas/fullstack-generalist.md](personas/fullstack-generalist.md) |

---

## Scenario Walkthroughs

Follow step-by-step guides for real-world situations.

| Scenario | Duration | Key Tools |
|----------|----------|-----------|
| [Build a New Microservice](scenarios/new-microservice.md) | 2-3 hours | `architect-agent`, `/msa-ddd`, `/go-microservice` |
| [Production Incident Response](scenarios/production-incident.md) | 30-60 min | `incident-responder`, `k8s-troubleshooter`, `/observability` |
| [Platform Team Bootstrap](scenarios/platform-bootstrap.md) | 1-2 days | `platform-engineer`, `/backstage`, `/gitops-argocd` |

---

## Getting Started

1. **Check the Combo Reference**: [quick-reference.md](quick-reference.md) — Recommended combos at a glance
2. **Read your persona guide**: Pick from the table above
3. **Follow a scenario**: Run a walkthrough that matches your situation

---

## Structure

```
docs/guides/
├── README.md                     ← You are here (English)
├── quick-reference.md            ← Combo reference table (core)
├── personas/
│   ├── backend-dev.md            ← Backend Developer (Java/Go)
│   ├── devops-sre.md             ← DevOps/SRE
│   └── fullstack-generalist.md   ← Fullstack/Generalist
├── scenarios/
│   ├── new-microservice.md       ← Build a new MSA service
│   ├── production-incident.md    ← Production incident response
│   └── platform-bootstrap.md     ← Platform team bootstrap
└── ko/                           ← Korean translations
    └── ...
```
