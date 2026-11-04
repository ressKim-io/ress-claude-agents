**English** | [한국어](../ko/personas/devops-sre.md)

# DevOps / SRE Guide

> Agent + skill usage guide for infrastructure operations, deployment, observability, and incident response

---

## First 5 Minutes After Install

- [ ] Run `/plugin marketplace add ressKim-io/ress-claude-agents`, then `/plugin install` `k8s@ress`, `infra@ress`, `cicd@ress`, `observability@ress`, `sre@ress`, `dx@ress`
- [ ] Type `/agents` in Claude Code to see the agent list
- [ ] Try `"Check K8s cluster status"`
- [ ] Try `"Review my Terraform plan"`

---

## Everyday Combos

> Full combo table: [quick-reference.md](../quick-reference.md#3-devops--sre-combos)

### Operations Cycle

```
1. Infrastructure changes
   → terraform-reviewer for IaC review
   → security-scanner for security verification

2. Deployment
   → ci-optimizer for pipeline optimization
   → /cicd:gitops-argocd for ArgoCD setup

3. Monitoring
   → /observability:observability-otel for observability setup
   → /observability:monitoring-grafana for dashboards

4. Incident response
   → incident-responder for auto-triage
   → k8s-troubleshooter for cluster diagnostics
```

---

## IaC / Infrastructure Section

### Core Agents

| Agent | Use Case |
|-------|----------|
| `terraform-reviewer` | IaC review across 11 domains: security, cost, reliability |
| `k8s-troubleshooter` | K8s diagnostics, root cause analysis |
| `cost-analyzer` | FinOps analysis, anomaly detection |

### Core Skills

| Category | Skill | Key Content |
|----------|-------|-------------|
| Terraform | `/infra:terraform-modules` | Module patterns |
| Terraform | `/infra:terraform-security` | Security best practices |
| AWS | `/infra:aws-eks` | EKS Terraform, IRSA, Add-ons |
| AWS | `/infra:aws-eks-advanced` | Karpenter, security hardening |
| AWS | `/infra:aws-lambda` | Serverless, cold start optimization |
| K8s | `/k8s:k8s-security` | Pod Security, RBAC, Kyverno |
| K8s | `/k8s:k8s-helm` | Helm chart best practices |
| K8s | `/k8s:k8s-autoscaling` | HPA, VPA, KEDA, Karpenter |
| IaC | `/infra:crossplane` | Multi-cloud IaC, Compositions |
| Docker | `/infra:docker` | Dockerfile optimization, multi-stage builds |

### Example Requests

```
"Build an EKS cluster with Terraform"
→ terraform-reviewer + /infra:aws-eks + /infra:aws-eks-advanced

"Harden K8s security"
→ k8s-troubleshooter + /k8s:k8s-security + /k8s:k8s-helm

"Set up HPA + KEDA autoscaling"
→ /k8s:k8s-autoscaling + /k8s:k8s-autoscaling-advanced
```

---

## Code Review Section (NEW)

### DevOps Reviewers (Category Budget System)

| Agent | Use Case |
|-------|----------|
| `k8s-reviewer` | K8s manifest, Helm, Kustomize review (9 domains) |
| `dockerfile-reviewer` | Dockerfile, docker-compose review (8 domains) |
| `cicd-reviewer` | GitHub Actions, GitLab CI review (8 domains) |
| `gitops-reviewer` | ArgoCD, Flux configuration review (8 domains) |
| `observability-reviewer` | Prometheus, Alertmanager, OTel, Grafana review (9 domains) |

### Security Reviewers (Attack Surface — Red Team Prep)

| Agent | Use Case |
|-------|----------|
| `k8s-security-reviewer` | CIS K8s Benchmark + MITRE ATT&CK — container escape, RBAC escalation |
| `container-security-reviewer` | CIS Docker Benchmark — supply chain, secret leakage, image CVE |
| `cicd-security-reviewer` | OWASP CI/CD Top 10 — pipeline poisoning, script injection, SLSA |
| `network-security-reviewer` | Zero Trust — lateral movement, IMDS, egress exfiltration |

### Review Flow

```
1. Infrastructure changes
   → k8s-reviewer / dockerfile-reviewer / cicd-reviewer (general quality)
   → k8s-security-reviewer / container-security-reviewer (attack surface)

2. Pre-pentest hardening
   → k8s-security-reviewer + network-security-reviewer + cicd-security-reviewer
   → Follow "Red Team 대비 Checklist" in each agent

3. GitOps configuration
   → gitops-reviewer (sync, drift, environment isolation)

4. Observability config
   → observability-reviewer (alert quality, cardinality, SLO consistency)
```

---

## K8s Operations Section

### Scheduling / Traffic

| Skill | Key Content |
|-------|-------------|
| `/k8s:k8s-scheduling` | Node Affinity, Taint, Pod Affinity |
| `/k8s:k8s-scheduling-advanced` | Topology Spread, debugging |
| `/k8s:k8s-traffic` | Rate Limiting, queuing |
| `/k8s:k8s-traffic-ingress` | Ingress traffic management |
| `/service-mesh:k8s-traffic-istio` | Istio Rate Limiting, Circuit Breaker |

### Service Mesh

```
Istio basics:
  /service-mesh:istio-core → /service-mesh:istio-security → /service-mesh:istio-gateway

Istio advanced:
  /service-mesh:istio-advanced-traffic → /service-mesh:istio-otel → /service-mesh:istio-multicluster

Istio Ambient:
  /service-mesh:istio-ambient → /service-mesh:istio-gateway-api

Linkerd (lightweight):
  /service-mesh:linkerd

Gateway API:
  /k8s:gateway-api → /k8s:gateway-api-migration
```

---

## Incident Response Section

### Core Agents

| Agent | Role |
|-------|------|
| `incident-responder` | Auto-triage, severity classification, communication templates |
| `k8s-troubleshooter` | K8s cluster diagnostics, AIOps |

### Response Flow

```
Alert received
  ↓
incident-responder → Auto-triage (severity, blast radius)
  ↓
k8s-troubleshooter → Cluster diagnostics (pods, nodes, network)
  ↓
/infra:postgresql-operations → DB issue analysis (if needed)
  ↓
/dx:log-trouble → Record troubleshooting
```

### Related Skills

| Skill | Use Case |
|-------|----------|
| `/observability:observability` | Logging, RED Method |
| `/observability:monitoring-troubleshoot` | Alert response, troubleshooting patterns |
| `/sre:chaos-engineering` | Chaos testing, GameDay |
| `/sre:disaster-recovery` | DR strategy, Velero backups |

---

## Observability Section

### Core Agent

| Agent | Role |
|-------|------|

### Observability Stack Skills

```
OpenTelemetry:
  /observability:observability-otel → /observability:observability-otel-scale → /observability:observability-otel-optimization

eBPF (Zero-Code):
  /observability:ebpf-observability → /observability:ebpf-observability-advanced

Grafana Stack:
  /observability:monitoring-grafana + /observability:monitoring-metrics + /observability:monitoring-logs

Log analysis:
  /observability:logging-elk (ELK) or /observability:logging-loki (Loki)

Alerting:
  /observability:alerting-discord

AIOps:
  /observability:aiops → /observability:aiops-remediation
```

---

## FinOps Section

### Core Agents

| Agent | Role |
|-------|------|
| `cost-analyzer` | Cost analysis, anomaly detection, optimization recommendations |
| `finops-advisor` | FinOps strategy, maturity assessment, GreenOps |

### FinOps Skill Path

```
Basics:
  /sre:finops → /sre:finops-tools

Advanced:
  /sre:finops-advanced → /sre:finops-automation → /sre:finops-showback

Tool selection:
  /sre:finops-tools → /sre:finops-tools-advanced

GreenOps:
  /sre:finops-greenops
```

---

## GitOps / CI/CD Section

### Core Agents

| Agent | Role |
|-------|------|
| `ci-optimizer` | CI/CD optimization, DORA metrics, flaky test detection |
| `git-workflow` | Git workflow automation, PR |

### GitOps Skill Path

```
ArgoCD basics:
  /cicd:gitops-argocd → /cicd:gitops-argocd-advanced

AI GitOps:
  /cicd:gitops-argocd-ai

Deployment strategies:
  /cicd:deployment-strategies → /cicd:deployment-canary

CI/CD:
  /cicd:cicd-devsecops → /cicd:cicd-policy

Supply chain:
  /cicd:supply-chain-security → /cicd:supply-chain-compliance
```

---

## Related Scenarios

- [Production Incident Response](../scenarios/production-incident.md) — K8s OOMKilled incident walkthrough
- [Platform Team Bootstrap](../scenarios/platform-bootstrap.md) — Backstage + ArgoCD + OTel walkthrough
