# Kubernetes Security Patterns

Kubernetes 보안 패턴 및 best practices.

## Pod Security Standards

### Restricted SecurityContext

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
```

### Namespace PSS Labels

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Network Policy

### Default Deny All

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Allow Specific Traffic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## RBAC

### Minimal Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
  resourceNames: ["app-config", "app-secrets"]  # Specific resources only
```

### ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
automountServiceAccountToken: false  # Disable unless needed
---
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
```

## Secrets Management

```yaml
# Mount as file (preferred)
spec:
  volumes:
  - name: secrets
    secret:
      secretName: app-secrets
  containers:
  - name: app
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
      readOnly: true

# NOT recommended: environment variable
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secrets
      key: password
```

## Security Checklist

| Category | Check | Required |
|----------|-------|----------|
| Container | runAsNonRoot: true | Yes |
| Container | allowPrivilegeEscalation: false | Yes |
| Container | readOnlyRootFilesystem: true | Yes |
| Container | capabilities.drop: ALL | Yes |
| Image | No :latest tag | Yes |
| Image | Trusted registry only | Yes |
| Network | NetworkPolicy defined | Yes |
| RBAC | Custom ServiceAccount | Yes |
| RBAC | Minimal permissions | Yes |
| Secrets | Volume mount, not env | Recommended |

## Anti-patterns

| Mistake | Correct | Why |
|---------|---------|-----|
| `privileged: true` | Never use | Full host access |
| `hostNetwork: true` | Pod network | Host network exposure |
| No NetworkPolicy | Default deny | Unrestricted traffic |
| Default ServiceAccount | Custom SA | Minimal permissions |
| ClusterRole for app | Role (namespaced) | Scope limitation |
