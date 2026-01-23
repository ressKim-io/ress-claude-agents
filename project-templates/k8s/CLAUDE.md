# Kubernetes Project - Claude Settings

Kubernetes manifests 및 Helm charts 프로젝트를 위한 Claude Code 설정입니다.

## Project Structure

```
k8s-project/
├── charts/                      # Helm charts
│   └── app-name/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-prod.yaml
│       └── templates/
├── base/                        # Kustomize base
│   ├── kustomization.yaml
│   └── *.yaml
├── overlays/                    # Kustomize overlays
│   ├── dev/
│   ├── staging/
│   └── prod/
└── policies/                    # Network Policies, RBAC 등
```

## Pod Security Standards

**IMPORTANT:** Restricted 정책 적용 필수

### Namespace 설정
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

### SecurityContext 필수 설정
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

## Resource Management

**IMPORTANT:** requests = limits 정책 적용

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "256Mi"    # requests와 동일
    cpu: "250m"        # requests와 동일
```

### 가이드라인
- 모든 컨테이너에 requests/limits 필수
- Memory: requests = limits (OOM 예방)
- CPU: requests = limits (예측 가능한 성능)
- 실제 사용량 모니터링 후 조정

## Network Policy

**IMPORTANT:** Default Deny 정책 적용

### 기본 Deny 정책 (모든 namespace에 적용)
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

### Allow 정책 예시
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

## Image Policy

**IMPORTANT:** Semantic Versioning 필수

```yaml
# Good
image: myapp:v1.2.3
image: myapp:1.2.3

# Bad - 절대 사용 금지
image: myapp:latest
image: myapp
```

### 이미지 보안
- 신뢰할 수 있는 레지스트리만 사용
- 이미지 스캔 (Trivy, Grype) 필수
- Distroless 또는 최소 base 이미지 권장

## Labels & Annotations

### 필수 라벨
```yaml
metadata:
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "1.2.3"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: helm
```

### 권장 어노테이션
```yaml
metadata:
  annotations:
    description: "Application description"
    owner: "team-name"
    slack-channel: "#team-alerts"
```

## Probes

### 필수 Probe 설정
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3

# 권장: 시작 시간이 긴 앱
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

## Helm Best Practices

### Chart.yaml
```yaml
apiVersion: v2
name: myapp
description: A Helm chart for MyApp
type: application
version: 0.1.0        # Chart version
appVersion: "1.2.3"   # Application version
```

### values.yaml 구조
```yaml
# 이미지 설정
image:
  repository: myregistry/myapp
  tag: "v1.2.3"
  pullPolicy: IfNotPresent

# 리소스 설정
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "256Mi"
    cpu: "250m"

# 복제본 수
replicaCount: 2

# 서비스 설정
service:
  type: ClusterIP
  port: 80

# Ingress 설정
ingress:
  enabled: false
  className: nginx
  hosts: []

# 보안 컨텍스트
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### 템플릿 규칙
- `{{ include "chart.fullname" . }}` 사용
- 조건부 리소스는 `{{- if .Values.xxx }}`
- 기본값 제공: `{{ .Values.xxx | default "default" }}`

## Kustomize Best Practices

### base/kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

commonLabels:
  app.kubernetes.io/name: myapp
```

### overlays/prod/kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: production

patches:
  - path: replica-patch.yaml
  - path: resource-patch.yaml

images:
  - name: myapp
    newTag: v1.2.3
```

## Security Checklist

### RBAC
- [ ] 최소 권한 원칙 적용
- [ ] ServiceAccount 별도 생성 (default 사용 금지)
- [ ] ClusterRole 대신 Role 우선 사용
- [ ] system:masters 그룹 사용 금지

### Secrets
- [ ] Secret은 별도 관리 (Sealed Secrets, External Secrets)
- [ ] 환경변수보다 volume mount 선호
- [ ] etcd 암호화 활성화

### 컨테이너
- [ ] root 실행 금지 (runAsNonRoot: true)
- [ ] 읽기 전용 파일시스템 (readOnlyRootFilesystem: true)
- [ ] capabilities 모두 제거 (drop: ALL)
- [ ] privileged: false

## Validation Tools

권장 도구:
- **kubeconform**: 스키마 검증
- **kube-linter**: best practice 검증
- **trivy**: 이미지 취약점 스캔
- **pluto**: deprecated API 검출

## Commands

다음 명령어 사용 가능:
- `/validate` - manifest 보안 및 best practice 검증
- `/secure` - SecurityContext 등 보안 설정 자동 추가
- `/netpol` - Network Policy 생성 및 검증
- `/helm-check` - Helm chart best practice 검증

---

*global CLAUDE.md 설정도 함께 적용됩니다*
