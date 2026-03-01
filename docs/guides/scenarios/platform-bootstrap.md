**English** | [한국어](../ko/scenarios/platform-bootstrap.md)

# Scenario: Platform Team Bootstrap

> A walkthrough for building an Internal Developer Platform with Backstage + ArgoCD + OpenTelemetry

---

## Overview

| Item | Details |
|------|---------|
| **Audience** | Platform engineers, DevOps leads |
| **Duration** | 1-2 days |
| **Prerequisites** | K8s cluster, Helm, GitHub organization |
| **Deliverables** | Backstage portal + GitOps pipeline + observability stack + Golden Paths |

---

## Full Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 1     │     │  Step 2     │     │  Step 3     │
│  IDP Design │────►│  Backstage  │────►│  Golden     │
│             │     │  Setup      │     │  Paths      │
│ platform-   │     │ /backstage  │     │ /golden-    │
│ engineer    │     │ /platform-  │     │ paths       │
│ architect   │     │ backstage   │     │ architect   │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       │
       ▼                                       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 4     │     │  Step 5     │     │  Step 6     │
│  GitOps     │────►│  Observ.    │────►│  Security   │
│  Setup      │     │  Stack      │     │  Baseline   │
│ /gitops-    │     │ otel-expert │     │ security-   │
│ argocd      │     │ /observ-    │     │ scanner     │
│ ci-optimizer│     │ ability     │     │ terraform-  │
└─────────────┘     └─────────────┘     │ reviewer    │
                                        └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  Step 7     │
                                        │  DX Metrics │
                                        │             │
                                        │ /dx-metrics │
                                        │ finops-     │
                                        │ advisor     │
                                        └─────────────┘
```

---

## Step 1: IDP Design

**Tools**: `platform-engineer` + `architect-agent`

### How to Request

```
"Design an Internal Developer Platform.
 - 5-10 teams, 20-50 services
 - Self-service goal: developers provision environments without tickets
 - Tech stack: K8s + ArgoCD + Backstage + OTel"
```

### What Claude Does

- Designs IDP architecture (self-service layer definitions)
- Designs service catalog for team structure
- Documents tech stack selection rationale

### Expected Result

```
IDP Architecture:
┌─────────────────────────────────────────────┐
│           Backstage (Developer Portal)       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ Catalog  │ │ Template │ │ TechDocs │    │
│  └──────────┘ └──────────┘ └──────────┘    │
├─────────────────────────────────────────────┤
│           ArgoCD (GitOps Engine)             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ App of   │ │ AppSet   │ │ Sync     │    │
│  │ Apps     │ │ Generator│ │ Policies │    │
│  └──────────┘ └──────────┘ └──────────┘    │
├─────────────────────────────────────────────┤
│           OpenTelemetry (Observability)      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ Traces   │ │ Metrics  │ │ Logs     │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└─────────────────────────────────────────────┘
```

### Checkpoint

- [ ] Is the self-service scope defined?
- [ ] Are team structure and permission models designed?

---

## Step 2: Backstage Setup

**Tools**: `/backstage` + `/platform-backstage`

### How to Request

```
"Set up a Backstage Developer Portal.
 - Configure Software Catalog
 - Create Software Templates (service creation templates)
 - Integrate TechDocs
 - Connect ArgoCD plugin"
```

### What Claude Does

- Backstage installation + base configuration
- Registers existing services in Software Catalog
- Creates Software Templates (Go/Java service templates)
- Configures TechDocs

### Checkpoint

- [ ] Can you access Backstage?
- [ ] Are services registered in the Software Catalog?
- [ ] Does the new service creation template work?

---

## Step 3: Define Golden Paths

**Tools**: `architect-agent` + `/golden-paths` + `/golden-paths-infra`

### How to Request

```
"Define Golden Paths.
 - Go service Golden Path (hexagonal architecture)
 - Java/Spring service Golden Path
 - Infrastructure Golden Path (Terraform modules)"
```

### What Claude Does

- Standardizes service templates (project structure, CI/CD, observability defaults)
- Reflects Golden Paths in Backstage Software Templates
- Creates infrastructure Terraform module templates

### Checkpoint

- [ ] Do Go/Java service templates follow the Golden Path?
- [ ] Can you create a service with one click in Backstage?
- [ ] Is CI/CD pipeline automatically included?

---

## Step 4: GitOps Setup

**Tools**: `ci-optimizer` + `/gitops-argocd` + `/gitops-argocd-advanced`

### How to Request

```
"Set up an ArgoCD GitOps environment.
 - App of Apps pattern
 - Environment separation (dev/staging/prod)
 - ApplicationSet for auto-generation
 - Sync policies + secret management"
```

### What Claude Does

- ArgoCD installation + configuration
- App of Apps pattern for managing all apps
- ApplicationSet Generator for per-environment auto-creation
- Sealed Secrets or External Secrets Operator integration

### Checkpoint

- [ ] Are all apps Synced in ArgoCD?
- [ ] Do Git changes auto-deploy?
- [ ] Are secrets securely managed?

---

## Step 5: Observability Stack

**Tools**: `otel-expert` + `/observability-otel` + `/monitoring-grafana`

### How to Request

```
"Build an observability stack.
 - OpenTelemetry Collector (Traces + Metrics + Logs)
 - Grafana + Prometheus + Tempo + Loki
 - Include auto-instrumentation in Golden Path services"
```

### What Claude Does

- Deploys OTel Collector DaemonSet
- Installs Grafana stack (Prometheus, Tempo, Loki)
- Creates default dashboards (RED metrics)
- Sets up alert rules

### Checkpoint

- [ ] Are metrics showing in Grafana dashboards?
- [ ] Are traces being collected?
- [ ] Are logs searchable?

---

## Step 6: Security Baseline

**Tools**: `security-scanner` + `terraform-reviewer`

### How to Request

```
"Set up a platform security baseline.
 - K8s Pod Security Standards
 - Kyverno policies (image signing, resource limits)
 - Default network policies
 - Team-based RBAC"
```

### What Claude Does

- Configures Pod Security Admission
- Deploys Kyverno policies (required labels, resource limits, image verification)
- Applies default NetworkPolicy
- Sets up team-based RBAC permissions

### Checkpoint

- [ ] Are security policies applied?
- [ ] Do violations trigger warnings/blocks?
- [ ] Are team permissions properly separated?

---

## Step 7: DX Metrics + Cost Strategy

**Tools**: `/dx-metrics` + `finops-advisor`

### How to Request

```
"Set up DX metrics and FinOps strategy to measure IDP effectiveness.
 - DORA metrics (deployment frequency, lead time, MTTR, change failure rate)
 - Time-to-First-Deploy tracking
 - Kubecost cost monitoring"
```

### What Claude Does

- Sets up DORA metrics collection pipeline
- Adds DX dashboard to Backstage
- Installs Kubecost + per-team cost visibility

### Checkpoint

- [ ] Are DORA metrics being collected?
- [ ] Is per-team cost visible?
- [ ] Are baseline numbers recorded?

---

## Wrap Up

### Verification

```bash
# Backstage health check
curl -s http://backstage.internal/api/health | jq .status

# ArgoCD all apps status
argocd app list --output json | jq '.[].status.sync.status'

# OTel Collector status
kubectl get pods -n observability -l app=otel-collector

# Grafana health check
curl -s http://grafana.internal/api/health
```

### IDP Maturity Checklist

```
Level 1 (Basics):
  [x] Backstage portal running
  [x] GitOps deployment automation
  [x] Basic observability stack

Level 2 (Self-Service):
  [ ] Golden Path service creation automation
  [ ] Dev environment self-provisioning
  [ ] Per-team cost visibility

Level 3 (Optimization):
  [ ] DORA metrics-driven improvements
  [ ] AI-assisted GitOps
  [ ] FinOps automation
```

### Next Steps

- `/developer-self-service` — Advanced self-service platform
- `/kratix` — Kratix Promise-based platform API
- `/secrets-management` — Advanced secret management
- `/ephemeral-environments` — Per-PR preview environments
- `/dx-onboarding` — New developer onboarding automation
