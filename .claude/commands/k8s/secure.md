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

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| 컨테이너 시작 실패 (`CrashLoopBackOff`) | readOnlyRootFilesystem 적용 후 쓰기 필요 | `/tmp` 등에 emptyDir 볼륨 마운트 |
| 권한 거부 에러 | runAsNonRoot 적용 후 root 필요 | 이미지 수정하여 non-root 사용자 지원 |
| 파일 접근 불가 | fsGroup 설정 불일치 | 볼륨의 파일 소유권과 fsGroup 맞춤 |
| capabilities 제거 후 기능 불가 | 특정 capability 필요 | 필요한 capability만 add (예: NET_BIND_SERVICE) |
| ServiceAccount 토큰 접근 불가 | automountServiceAccountToken: false | 필요시 true로 설정 또는 projected volume 사용 |
| seccomp 프로필 에러 | RuntimeDefault 미지원 | 노드의 seccomp 지원 여부 확인 |
