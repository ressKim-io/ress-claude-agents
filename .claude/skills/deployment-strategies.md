# 배포 전략 가이드

Canary, Blue-Green, Rolling Update 및 Argo Rollouts 활용

## Quick Reference (결정 트리)

```
배포 전략 선택?
    │
    ├─ 빠른 롤백 필요 ───────────> Blue-Green
    │
    ├─ 점진적 검증 필요 ─────────> Canary
    │
    ├─ 리소스 효율 중시 ─────────> Rolling Update
    │
    └─ 사용자 세그먼트 테스트 ───> A/B Testing

도구 선택?
    │
    ├─ 기본 K8s ────────> Rolling Update (Deployment)
    ├─ 고급 트래픽 제어 ─> Argo Rollouts + Istio
    └─ 서비스 메시 있음 ─> Istio VirtualService
```

---

## CRITICAL: 전략 비교

| 전략 | 다운타임 | 롤백 속도 | 리소스 | 복잡도 |
|------|----------|----------|--------|--------|
| **Rolling Update** | 없음 | 느림 | 1x | 낮음 |
| **Blue-Green** | 없음 | 즉시 | 2x | 중간 |
| **Canary** | 없음 | 빠름 | 1.x | 높음 |
| **A/B Testing** | 없음 | 빠름 | 1.x | 높음 |

```
┌─────────────────────────────────────────────────────────────┐
│                    Deployment Strategies                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Rolling Update: [v1][v1][v2][v2] → [v2][v2][v2][v2]        │
│                                                              │
│  Blue-Green:     [v1 100%] ─switch─> [v2 100%]              │
│                                                              │
│  Canary:         [v1 90%] → [v1 70%] → ... → [v2 100%]     │
│                  [v2 10%] → [v2 30%] → ...                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Rolling Update (기본)

### Deployment 설정

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%        # 추가 Pod 허용량
      maxUnavailable: 25%  # 동시 중단 허용량
  template:
    spec:
      containers:
        - name: my-app
          image: myapp:v2
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
```

### 권장 설정

| 시나리오 | maxSurge | maxUnavailable |
|----------|----------|----------------|
| 안전 우선 | 1 | 0 |
| 빠른 배포 | 50% | 50% |
| 균형 | 25% | 25% |

### 롤백

```bash
# 이전 버전으로 롤백
kubectl rollout undo deployment/my-app

# 특정 리비전으로 롤백
kubectl rollout undo deployment/my-app --to-revision=2

# 롤아웃 상태 확인
kubectl rollout status deployment/my-app

# 히스토리 확인
kubectl rollout history deployment/my-app
```

---

## Blue-Green 배포

### 수동 Blue-Green

```yaml
# blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-blue
  labels:
    app: my-app
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
      version: blue
  template:
    metadata:
      labels:
        app: my-app
        version: blue
    spec:
      containers:
        - name: my-app
          image: myapp:v1
---
# green-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-green
  labels:
    app: my-app
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
      version: green
  template:
    metadata:
      labels:
        app: my-app
        version: green
    spec:
      containers:
        - name: my-app
          image: myapp:v2
---
# service.yaml - selector 변경으로 전환
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
    version: blue  # → green으로 변경하여 전환
  ports:
    - port: 80
      targetPort: 8080
```

### Argo Rollouts Blue-Green

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: myapp:v2
  strategy:
    blueGreen:
      activeService: my-app-active
      previewService: my-app-preview
      autoPromotionEnabled: false  # 수동 승인
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
          - templateName: success-rate
        args:
          - name: service-name
            value: my-app-preview
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-active
spec:
  selector:
    app: my-app
  ports:
    - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-preview
spec:
  selector:
    app: my-app
  ports:
    - port: 80
```

```bash
# Preview 확인 후 Promote
kubectl argo rollouts promote my-app

# 롤백
kubectl argo rollouts abort my-app
```

---

## Canary 배포

### Argo Rollouts Canary

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 10
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: myapp:v2
  strategy:
    canary:
      steps:
        # 1단계: 10% 트래픽
        - setWeight: 10
        - pause: {duration: 5m}

        # 2단계: 분석 실행
        - analysis:
            templates:
              - templateName: success-rate
            args:
              - name: service-name
                value: my-app

        # 3단계: 30% 트래픽
        - setWeight: 30
        - pause: {duration: 5m}

        # 4단계: 50% 트래픽
        - setWeight: 50
        - pause: {duration: 5m}

        # 5단계: 최종 분석
        - analysis:
            templates:
              - templateName: success-rate

        # 6단계: 100%
        - setWeight: 100

      # Istio 트래픽 관리
      trafficRouting:
        istio:
          virtualService:
            name: my-app-vsvc
            routes:
              - primary
          destinationRule:
            name: my-app-destrule
            canarySubsetName: canary
            stableSubsetName: stable
```

### AnalysisTemplate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 1m
      count: 5
      successCondition: result[0] >= 0.95
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}",status!~"5.."}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))

    - name: latency-p99
      interval: 1m
      count: 5
      successCondition: result[0] <= 500
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[5m])) by (le)
            ) * 1000
```

### Istio VirtualService (수동 Canary)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
spec:
  hosts:
    - my-app
  http:
    - route:
        - destination:
            host: my-app
            subset: stable
          weight: 90
        - destination:
            host: my-app
            subset: canary
          weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app
spec:
  host: my-app
  subsets:
    - name: stable
      labels:
        version: v1
    - name: canary
      labels:
        version: v2
```

---

## A/B Testing

### Header 기반 라우팅

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
spec:
  hosts:
    - my-app.example.com
  http:
    # 특정 헤더가 있으면 canary로
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: my-app
            subset: canary

    # 특정 쿠키가 있으면 canary로
    - match:
        - headers:
            cookie:
              regex: ".*canary=true.*"
      route:
        - destination:
            host: my-app
            subset: canary

    # 기본은 stable
    - route:
        - destination:
            host: my-app
            subset: stable
```

### 사용자 세그먼트 기반

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
spec:
  hosts:
    - my-app.example.com
  http:
    # 베타 테스터
    - match:
        - headers:
            x-user-group:
              exact: "beta"
      route:
        - destination:
            host: my-app
            subset: canary

    # 내부 직원
    - match:
        - headers:
            x-internal:
              exact: "true"
      route:
        - destination:
            host: my-app
            subset: canary

    # 일반 사용자
    - route:
        - destination:
            host: my-app
            subset: stable
```

---

## Argo Rollouts 설치 & CLI

### 설치

```bash
# Controller 설치
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# kubectl 플러그인 설치
brew install argoproj/tap/kubectl-argo-rollouts

# 대시보드 (선택)
kubectl argo rollouts dashboard
```

### CLI 명령어

```bash
# 롤아웃 상태 확인
kubectl argo rollouts get rollout my-app --watch

# 수동 Promote
kubectl argo rollouts promote my-app

# 특정 스텝까지 Promote
kubectl argo rollouts promote my-app --full

# Abort (롤백)
kubectl argo rollouts abort my-app

# Retry (재시도)
kubectl argo rollouts retry rollout my-app

# 이미지 변경으로 롤아웃 트리거
kubectl argo rollouts set image my-app myapp=myapp:v3

# 일시 정지
kubectl argo rollouts pause my-app

# 재개
kubectl argo rollouts resume my-app
```

---

## 자동화된 롤백

### Analysis 기반 자동 롤백

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
        - setWeight: 20
        - analysis:
            templates:
              - templateName: error-rate
            args:
              - name: service
                value: my-app
      # 분석 실패 시 자동 롤백
      abortScaleDownDelaySeconds: 30
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate
spec:
  args:
    - name: service
  metrics:
    - name: error-rate
      interval: 30s
      successCondition: result[0] < 0.05  # 에러율 5% 미만
      failureLimit: 3                      # 3번 실패 시 롤백
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service}}",status=~"5.."}[2m]))
            /
            sum(rate(http_requests_total{service="{{args.service}}"}[2m]))
```

### 분석 유형

| 분석 단계 | 용도 |
|----------|------|
| **prePromotionAnalysis** | Blue-Green 전환 전 |
| **postPromotionAnalysis** | Blue-Green 전환 후 |
| **analysis (step)** | Canary 각 단계 |
| **backgroundAnalysis** | 전체 롤아웃 중 지속 |

---

## 프로그레시브 딜리버리 파이프라인

### ArgoCD + Argo Rollouts 통합

```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/my-app.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
# Rollout (소스 저장소에 포함)
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 2m}
        - analysis:
            templates:
              - templateName: success-rate
        - setWeight: 50
        - pause: {duration: 2m}
        - setWeight: 100
```

### 전체 플로우

```
┌─────────────────────────────────────────────────────────────┐
│              Progressive Delivery Pipeline                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Git Push → ArgoCD Sync → Rollout 시작                      │
│       │                        │                             │
│       │                        ▼                             │
│       │              [Canary 20%] ─analysis─> Pass?         │
│       │                        │              │              │
│       │                        │         No: Rollback        │
│       │                        ▼                             │
│       │              [Canary 50%] ─analysis─> Pass?         │
│       │                        │              │              │
│       │                        │         No: Rollback        │
│       │                        ▼                             │
│       │              [100% Promotion]                        │
│       │                        │                             │
│       │                        ▼                             │
│       └──────────────> Complete                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 모니터링

### Prometheus 메트릭

```promql
# Rollout 상태
argo_rollouts_info{name="my-app"}

# 현재 Phase
argo_rollouts_info{name="my-app",phase="Progressing"}

# 레플리카 상태
argo_rollouts_replicas{name="my-app"}

# 분석 결과
argo_rollouts_analysis_run_info{name="my-app"}
```

### Grafana 대시보드

```json
{
  "panels": [
    {
      "title": "Rollout Status",
      "targets": [{
        "expr": "argo_rollouts_info{namespace=\"$namespace\"}",
        "legendFormat": "{{name}} - {{phase}}"
      }]
    },
    {
      "title": "Canary Weight",
      "targets": [{
        "expr": "argo_rollouts_info{name=\"my-app\"} * on() group_left argo_rollouts_replicas{name=\"my-app\",type=\"canary\"}",
        "legendFormat": "Canary %"
      }]
    }
  ]
}
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| Readiness Probe 없음 | 불완전한 Pod에 트래픽 | Probe 필수 설정 |
| 분석 메트릭 없음 | 수동 판단 필요 | AnalysisTemplate 사용 |
| 짧은 pause 시간 | 충분한 검증 불가 | 최소 5분 이상 |
| Blue-Green 리소스 방치 | 비용 낭비 | scaleDownDelay 설정 |
| 단일 메트릭만 분석 | 일부 문제 누락 | 다중 메트릭 (에러율 + 지연시간) |
| 롤백 계획 없음 | 장애 시 혼란 | 자동 롤백 조건 설정 |

---

## 체크리스트

### 기본 설정
- [ ] Readiness/Liveness Probe 설정
- [ ] 리소스 requests/limits 설정
- [ ] PodDisruptionBudget 설정

### Canary
- [ ] Argo Rollouts 설치
- [ ] 단계별 weight 설정
- [ ] AnalysisTemplate 정의
- [ ] 자동 롤백 조건 설정

### Blue-Green
- [ ] Active/Preview Service 생성
- [ ] prePromotionAnalysis 설정
- [ ] scaleDownDelay 설정

### 모니터링
- [ ] 배포 메트릭 수집
- [ ] 알림 설정
- [ ] 대시보드 구성

**관련 skill**: `/gitops-argocd`, `/istio-traffic`, `/sre-sli-slo`, `/monitoring-metrics`
