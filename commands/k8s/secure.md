# Kubernetes Security Hardening

Kubernetes manifest에 보안 설정을 자동으로 추가합니다.

## Instructions

1. 대상 manifest 파일을 분석합니다.
2. 누락된 보안 설정을 식별합니다.
3. Restricted Pod Security Standards 기준으로 설정을 추가합니다.
4. 변경 사항을 사용자에게 보여주고 확인을 받습니다.

## Security Settings to Add

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
  automountServiceAccountToken: false  # 필요 없는 경우
```

## Transformation Rules

### Before
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:v1.0.0
```

### After
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: myapp:v1.0.0
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL
```

## Special Cases

### initContainers
initContainers에도 동일한 securityContext 적용

### Multiple Containers
모든 컨테이너에 개별적으로 securityContext 적용

### Existing Settings
기존 설정이 있는 경우:
- 더 엄격한 설정으로 덮어쓰기
- 사용자에게 변경 사항 알림

## Helm Chart Handling

### values.yaml 수정
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### templates/deployment.yaml 수정
```yaml
spec:
  securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 8 }}
  containers:
  - name: {{ .Chart.Name }}
    securityContext:
      {{- toYaml .Values.securityContext | nindent 12 }}
```

## Output Format

```markdown
## Security Hardening Report

### Changes Applied

#### deployment.yaml
- Added: spec.securityContext.runAsNonRoot: true
- Added: spec.securityContext.runAsUser: 1000
- Added: containers[0].securityContext.allowPrivilegeEscalation: false
- Added: containers[0].securityContext.readOnlyRootFilesystem: true
- Added: containers[0].securityContext.capabilities.drop: ["ALL"]

### Warnings
- readOnlyRootFilesystem 적용 시 /tmp 등에 쓰기가 필요하면 emptyDir 볼륨 마운트 필요

### Next Steps
1. 변경된 manifest 검토
2. 로컬 환경에서 테스트
3. CI/CD 파이프라인에서 검증
```

## Usage

```
/secure deployment.yaml             # 특정 파일 보안 강화
/secure charts/myapp/               # Helm chart 보안 강화
/secure --dry-run                   # 변경 사항만 미리보기
/secure --user 10000                # 특정 UID 사용
```
