**English** | [한국어](../ko/scenarios/production-incident.md)

# Scenario: Production Incident Response

> A walkthrough for responding to a K8s pod OOMKilled incident from detection to resolution

---

## Overview

| Item | Details |
|------|---------|
| **Audience** | DevOps/SRE or backend developers |
| **Duration** | 30-60 minutes |
| **Prerequisites** | K8s cluster access, kubectl |
| **Deliverables** | Incident resolved + root cause analysis + prevention measures |

---

## Full Flow

```
┌──────────────────────────────────────────────────────┐
│                  ALERT: OOMKilled                      │
│         order-service pods restarting repeatedly        │
└──────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 1     │     │  Step 2     │     │  Step 3     │
│  Triage     │────►│  Root Cause │────►│  Observ.    │
│             │     │  Analysis   │     │  Analysis   │
│ incident-   │     │ k8s-trouble │     │ otel-expert │
│ responder   │     │ shooter     │     │ /monitoring │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                    ┌─────────────┐     ┌─────────────┐
                    │  Step 4     │     │  Step 5     │
                    │  Apply Fix  │────►│  Record &   │
                    │             │     │  Retro      │
                    │ code-review │     │ dev-logger  │
                    │ /k8s-auto   │     │ /log-trouble│
                    └─────────────┘     └─────────────┘
```

---

## Step 1: Auto-Triage

**Tools**: `incident-responder`

### How to Request

```
"Production order-service pods are restarting with OOMKilled.
 Analyze the incident."
```

### What Claude Does

- Severity classification (SEV1-4)
- Blast radius assessment (which services, how many users)
- Timeline construction (when did it start?)
- Initial communication template

### Expected Result

```
## Incident Analysis
- Severity: SEV2
- Impact: Order creation failing, ~30% of users affected
- Timeline: Started after 14:30 UTC deployment
- Hypothesis: Memory leak or insufficient resource limits
```

### Checkpoint

- [ ] Is severity classification appropriate?
- [ ] Is the blast radius identified?
- [ ] Are recent changes accounted for?

---

## Step 2: Root Cause Analysis

**Tools**: `k8s-troubleshooter`

### How to Request

```
"Analyze root cause of order-service OOMKilled.
 - Check pod status, events, logs
 - Analyze memory usage trends
 - Review recent deployment changes"
```

### What Claude Does

```bash
# Check pod status
kubectl get pods -n production -l app=order-service

# Check events
kubectl describe pod <pod-name> -n production

# Memory usage
kubectl top pods -n production -l app=order-service

# Check logs (OOM-related)
kubectl logs <pod-name> -n production --previous | grep -i "memory\|oom\|heap"

# Recent deployments
kubectl rollout history deployment/order-service -n production
```

### Hypothesis Validation Cycle

```
Hypothesis 1: Insufficient memory limit
  → kubectl describe pod → check resource limits
  → Result: limit 512Mi, actual usage 480Mi → near limit

Hypothesis 2: Memory leak
  → Check logs for heap growth pattern
  → Result: goroutine leak found on specific API call

→ Root cause: goroutine leak causing gradual memory increase
```

### Checkpoint

- [ ] Is the root cause (not symptom) confirmed?
- [ ] Is the hypothesis validated with data?

---

## Step 3: Observability Data Analysis

**Tools**: `otel-expert` + `/monitoring-troubleshoot`

### How to Request

```
"Analyze order-service memory/CPU trends and
 error rate changes in Grafana."
```

### What Claude Does

- Suggests metric queries (Prometheus/Grafana)
- Trace analysis (identifying slow requests)
- Log correlation analysis

### Key Queries

```promql
# Memory usage trend
container_memory_working_set_bytes{pod=~"order-service.*"}

# Restart count
kube_pod_container_status_restarts_total{container="order-service"}

# Error rate
rate(http_server_requests_seconds_count{service="order-service",status=~"5.."}[5m])
```

### Checkpoint

- [ ] Is the memory growth pattern identified?
- [ ] Is there correlation between deployment time and incident?

---

## Step 4: Apply Fix

**Tools**: `code-reviewer` + `/k8s-autoscaling`

### Immediate Action (Emergency)

```
"Fix the goroutine leak and increase memory limit to 1Gi."
```

### What Claude Does

1. **Immediate**: Increase memory limit + restart pods
2. **Root fix**: Fix goroutine leak in code
3. **Prevention**: Add regression test

### Post-Fix Verification

```bash
# Monitor after deploying the fix
kubectl rollout status deployment/order-service -n production

# Verify memory stabilization
kubectl top pods -n production -l app=order-service

# Verify error rate normalized
# Check in Grafana dashboard
```

### Checkpoint

- [ ] Is the incident symptom resolved?
- [ ] Is a regression test added?
- [ ] No side effects on other services?

---

## Step 5: Record & Retrospective

**Tools**: `dev-logger` (`/log-trouble`)

### How to Request

```
/log-trouble
```

### What Claude Does

- Records the troubleshooting process as structured markdown
- Organizes timeline, root cause, resolution, prevention measures
- Saves to `docs/dev-logs/`

### Post-Mortem Template

```markdown
## Post-Mortem: Order Service OOMKilled

### Timeline
- 14:30 v2.3.1 deployed
- 14:45 First OOMKilled occurrence
- 15:00 Incident detected, analysis started
- 15:30 Root cause confirmed (goroutine leak)
- 15:45 Hotfix deployed
- 16:00 Service normalized

### Root Cause
HTTP client added in v2.3.1 did not close Response Body,
causing goroutine leak

### Action Items
- [x] Fix Response Body close
- [x] Increase memory limit 512Mi → 1Gi
- [x] Add goroutine monitoring alert
- [ ] Add resource leak item to code review checklist
```

### Checkpoint

- [ ] Is the post-mortem written?
- [ ] Are action items clear?
- [ ] Is monitoring/alerting strengthened?

---

## Wrap Up

### Verification

```bash
# Verify pods are healthy
kubectl get pods -n production -l app=order-service

# Monitor memory stability (30 min)
watch kubectl top pods -n production -l app=order-service

# Verify 0% error rate
# Check Grafana dashboard
```

### Next Steps

- `/chaos-engineering` — Proactively detect similar failures with chaos testing
- `/sre-sli-slo` — Define SLIs/SLOs for error budget management
- `/aiops` — Automate anomaly detection with AIOps
- [Platform Team Bootstrap](platform-bootstrap.md) — Systematize observability infrastructure
