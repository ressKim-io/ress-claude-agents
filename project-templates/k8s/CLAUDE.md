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

## Commands
- `/validate` - Security & best practice validation
- `/secure` - Auto-add SecurityContext
- `/netpol` - Generate NetworkPolicy
- `/helm-check` - Helm chart validation

---
*Applies with global CLAUDE.md settings*
