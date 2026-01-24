# Kubernetes Project - Claude Settings

## Quick Reference
- Validate: `kubectl apply --dry-run=client -f .`
- Lint: `kube-linter lint .`
- Security: `kubeconform -strict .`
- Helm: `helm lint charts/`

## Project Structure
```
charts/app/              # Helm charts
base/                    # Kustomize base
overlays/{dev,prod}/     # Environment overlays
policies/                # NetworkPolicy, RBAC
```

## CRITICAL Rules

1. **SecurityContext** - Verify: `grep -r "runAsNonRoot" .`
   ```yaml
   securityContext:
     runAsNonRoot: true
     allowPrivilegeEscalation: false
     readOnlyRootFilesystem: true
     capabilities:
       drop: ["ALL"]
   ```

2. **Resources** - Verify: `grep -r "resources:" .`
   ```yaml
   resources:
     requests: { memory: "256Mi", cpu: "250m" }
     limits: { memory: "256Mi", cpu: "250m" }  # Same as requests
   ```

3. **No :latest Tag** - Verify: `grep -r ":latest" .`
   ```yaml
   image: myapp:v1.2.3  # NOT myapp:latest
   ```

## Common Mistakes

| Mistake | Correct | Verify |
|---------|---------|--------|
| `privileged: true` | Never use | `grep "privileged"` |
| `:latest` tag | Semantic version | `grep ":latest"` |
| No NetworkPolicy | Default deny | `ls policies/` |
| Default SA | Custom ServiceAccount | `grep "serviceAccountName"` |
| No probes | liveness + readiness | `grep "Probe"` |

## Skills Reference
- `/k8s-security` - Security patterns, PSS, RBAC
- `/k8s-helm` - Helm chart best practices
- `/monitoring-grafana` - Grafana 대시보드, 알림, RBAC
- `/monitoring-metrics` - Prometheus 스케일링, Thanos/VictoriaMetrics
- `/monitoring-logs` - Fluent Bit, Loki, 로그 필터링
- `/monitoring-troubleshoot` - 알림 대응, 트러블슈팅
- `/logging-compliance` - 결제/개인정보 법적 로그 (PCI-DSS, 전자금융거래법)
- `/logging-security` - 봇/매크로 탐지, 보안 감사 로그
- `/logging-loki` - Loki + LogQL 검색/분석 (개발팀/보안팀용)
- `/logging-elk` - ELK Stack 검색/분석 (Elasticsearch, Kibana)

## Commands
- `/validate` - Security & best practice validation
- `/secure` - Auto-add SecurityContext
- `/netpol` - Generate NetworkPolicy
- `/helm-check` - Helm chart validation

---
*Applies with global CLAUDE.md settings*
