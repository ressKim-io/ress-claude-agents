# Kubernetes Security Hardening

Kubernetes manifest에 보안 설정을 자동으로 추가합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | YAML manifest 파일 또는 Helm chart |
| Output | 보안 설정이 추가된 manifest |
| Required Tools | - |
| Verification | `/validate` 통과 |

## Checklist

### Pod-level SecurityContext
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
```

### Container-level SecurityContext
```yaml
containers:
- name: app
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

### ServiceAccount
```yaml
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
```

## Output Format

```markdown
## Security Hardening Report

### Changes Applied
- [deployment.yaml] Added securityContext
- [deployment.yaml] Added ServiceAccount settings

### Warnings
- `readOnlyRootFilesystem` 적용 시 `/tmp` 등에 쓰기가 필요하면 emptyDir 볼륨 마운트 필요
```

## Usage

```
/secure deployment.yaml      # 특정 파일
/secure charts/myapp/        # Helm chart
/secure --dry-run            # 미리보기
/secure --user 10000         # 특정 UID
```
