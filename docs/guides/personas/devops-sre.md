**English** | [한국어](../ko/personas/devops-sre.md)

# DevOps / SRE Guide

> Agent + skill usage guide for infrastructure operations, deployment, observability, and incident response

---

## First 5 Minutes After Install

- [ ] Run `./install.sh --global --all --with-skills`
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
   → /gitops-argocd for ArgoCD setup

3. Monitoring
   → otel-expert for observability setup
   → /monitoring-grafana for dashboards

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
| Terraform | `/terraform-modules` | Module patterns |
| Terraform | `/terraform-security` | Security best practices |
| AWS | `/aws-eks` | EKS Terraform, IRSA, Add-ons |
| AWS | `/aws-eks-advanced` | Karpenter, security hardening |
| AWS | `/aws-lambda` | Serverless, cold start optimization |
| K8s | `/k8s-security` | Pod Security, RBAC, Kyverno |
| K8s | `/k8s-helm` | Helm chart best practices |
| K8s | `/k8s-autoscaling` | HPA, VPA, KEDA, Karpenter |
| IaC | `/crossplane` | Multi-cloud IaC, Compositions |
| Docker | `/docker` | Dockerfile optimization, multi-stage builds |

### Example Requests

```
"Build an EKS cluster with Terraform"
→ terraform-reviewer + /aws-eks + /aws-eks-advanced

"Harden K8s security"
→ k8s-troubleshooter + /k8s-security + /k8s-helm

"Set up HPA + KEDA autoscaling"
→ /k8s-autoscaling + /k8s-autoscaling-advanced
```

---

## K8s Operations Section

### Scheduling / Traffic

| Skill | Key Content |
|-------|-------------|
| `/k8s-scheduling` | Node Affinity, Taint, Pod Affinity |
| `/k8s-scheduling-advanced` | Topology Spread, debugging |
| `/k8s-traffic` | Rate Limiting, queuing |
| `/k8s-traffic-ingress` | Ingress traffic management |
| `/k8s-traffic-istio` | Istio Rate Limiting, Circuit Breaker |

### Service Mesh

```
Istio basics:
  /istio-core → /istio-security → /istio-gateway

Istio advanced:
  /istio-advanced-traffic → /istio-otel → /istio-multicluster

Istio Ambient:
  /istio-ambient → /istio-gateway-api

Linkerd (lightweight):
  /linkerd

Gateway API:
  /gateway-api → /gateway-api-migration
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
database-expert → DB issue analysis (if needed)
  ↓
/log-trouble → Record troubleshooting
```

### Related Skills

| Skill | Use Case |
|-------|----------|
| `/observability` | Logging, RED Method |
| `/monitoring-troubleshoot` | Alert response, troubleshooting patterns |
| `/chaos-engineering` | Chaos testing, GameDay |
| `/disaster-recovery` | DR strategy, Velero backups |

---

## Observability Section

### Core Agent

| Agent | Role |
|-------|------|
| `otel-expert` | Large-scale OTel architecture, Tail Sampling, cost optimization |

### Observability Stack Skills

```
OpenTelemetry:
  /observability-otel → /observability-otel-scale → /observability-otel-optimization

eBPF (Zero-Code):
  /ebpf-observability → /ebpf-observability-advanced

Grafana Stack:
  /monitoring-grafana + /monitoring-metrics + /monitoring-logs

Log analysis:
  /logging-elk (ELK) or /logging-loki (Loki)

Alerting:
  /alerting-discord

AIOps:
  /aiops → /aiops-remediation
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
  /finops → /finops-tools

Advanced:
  /finops-advanced → /finops-automation → /finops-showback

Tool selection:
  /finops-tools → /finops-tools-advanced

GreenOps:
  /finops-greenops
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
  /gitops-argocd → /gitops-argocd-advanced

AI GitOps:
  /gitops-argocd-ai

Deployment strategies:
  /deployment-strategies → /deployment-canary

CI/CD:
  /cicd-devsecops → /cicd-policy

Supply chain:
  /supply-chain-security → /supply-chain-compliance
```

---

## Related Scenarios

- [Production Incident Response](../scenarios/production-incident.md) — K8s OOMKilled incident walkthrough
- [Platform Team Bootstrap](../scenarios/platform-bootstrap.md) — Backstage + ArgoCD + OTel walkthrough
