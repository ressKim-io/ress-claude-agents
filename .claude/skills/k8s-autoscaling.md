# Kubernetes Autoscaling 가이드

HPA, VPA, KEDA, Karpenter를 활용한 워크로드 자동 스케일링

## Quick Reference (결정 트리)

```
스케일링 대상?
    │
    ├─ Pod 수량 (수평) ────────> HPA or KEDA
    │       │
    │       ├─ CPU/메모리 기반 ──> HPA
    │       └─ 이벤트/큐 기반 ───> KEDA (Kafka, SQS 등)
    │
    ├─ Pod 리소스 (수직) ─────> VPA
    │
    └─ Node 수량 ─────────────> Cluster Autoscaler or Karpenter

KEDA vs HPA?
    │
    ├─ CPU/메모리 병목 ────> HPA
    ├─ I/O/이벤트 병목 ────> KEDA
    └─ Scale-to-Zero 필요 ─> KEDA (HPA 불가)
```

---

## CRITICAL: Autoscaler 비교

| Autoscaler | 대상 | 장점 | 단점 |
|------------|------|------|------|
| **HPA** | Pod 수 | K8s 기본, 안정적 | 이벤트 기반 불가 |
| **VPA** | Pod 리소스 | 자동 right-sizing | Pod 재시작 필요 |
| **KEDA** | Pod 수 | 60+ 스케일러, Scale-to-Zero | 추가 설치 필요 |
| **Karpenter** | Node | 빠른 프로비저닝, 비용 최적화 | AWS 전용 |
| **Cluster Autoscaler** | Node | 멀티 클라우드 | 느린 스케일업 |

```
┌─────────────────────────────────────────────────────────────┐
│                    Autoscaling Architecture                  │
├─────────────────────────────────────────────────────────────┤
│  HPA/KEDA ──> Pod 수 조절 ──> Node 부족 ──> Karpenter/CA    │
│      │                            │                          │
│  Metrics Server              Node Pool                       │
│  Prometheus                  Spot/On-Demand                  │
└─────────────────────────────────────────────────────────────┘
```

---

## HPA (Horizontal Pod Autoscaler)

### 기본 설정

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    # CPU 기반 (가장 일반적)
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

    # 메모리 기반 (주의: 느린 지표)
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5분 대기
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
      selectPolicy: Max
```

### Custom Metrics HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
    # Prometheus 커스텀 메트릭
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "100"

    # External 메트릭 (SQS 큐 길이 등)
    - type: External
      external:
        metric:
          name: sqs_queue_length
          selector:
            matchLabels:
              queue: orders
        target:
          type: AverageValue
          averageValue: "30"
```

### CRITICAL: HPA Best Practices

| 항목 | 권장 | 이유 |
|------|------|------|
| CPU 기준 | 60-80% | 버스트 여유 확보 |
| 메모리 기준 | 사용 자제 | 느린 지표, OOM 위험 |
| minReplicas | 2 이상 | HA 보장 |
| stabilizationWindow | scaleDown 300s | 플래핑 방지 |
| requests 설정 | 필수 | HPA 계산 기준 |

---

## VPA (Vertical Pod Autoscaler)

### 설치

```bash
# VPA 설치
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh
```

### VPA 모드

| 모드 | 동작 | 사용 시기 |
|------|------|----------|
| **Off** | 추천만 제공 | 분석/튜닝 단계 |
| **Initial** | 생성 시에만 적용 | 안정적 운영 |
| **Auto** | 자동 재시작 | 개발/스테이징 |

### 설정

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Off"  # 추천만 (권장)
  resourcePolicy:
    containerPolicies:
      - containerName: "*"
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 2
          memory: 4Gi
        controlledResources: ["cpu", "memory"]
```

### VPA 추천 조회

```bash
# VPA 추천값 확인
kubectl describe vpa my-app-vpa

# 추천값 JSON
kubectl get vpa my-app-vpa -o jsonpath='{.status.recommendation}'
```

### CRITICAL: HPA + VPA 함께 사용

```yaml
# HPA: Custom Metrics로 스케일링
# VPA: Off 모드로 추천만 받기

# 1. VPA (Off 모드)
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Off"  # 추천만

# 2. HPA (Custom Metrics)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  metrics:
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second  # CPU 대신
        target:
          type: AverageValue
          averageValue: "100"
```

---

## KEDA (Kubernetes Event-Driven Autoscaler)

### 설치

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
```

### KEDA 구성 요소

| CRD | 용도 |
|-----|------|
| **ScaledObject** | Deployment 스케일링 |
| **ScaledJob** | Job 스케일링 |
| **TriggerAuthentication** | 인증 정보 |

### Kafka 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-consumer-scaler
spec:
  scaleTargetRef:
    name: kafka-consumer
  pollingInterval: 15
  cooldownPeriod: 30
  minReplicaCount: 1
  maxReplicaCount: 10  # 파티션 수 이하로
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: kafka:9092
        consumerGroup: my-consumer-group
        topic: my-topic
        lagThreshold: "100"  # lag > 100이면 스케일업
        offsetResetPolicy: earliest
```

### Prometheus 메트릭 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaler
spec:
  scaleTargetRef:
    name: my-app
  minReplicaCount: 1
  maxReplicaCount: 20
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: http_requests_total
        query: |
          sum(rate(http_requests_total{deployment="my-app"}[2m]))
        threshold: "100"
```

### AWS SQS 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: aws-credentials
spec:
  secretTargetRef:
    - parameter: awsAccessKeyID
      name: aws-secrets
      key: AWS_ACCESS_KEY_ID
    - parameter: awsSecretAccessKey
      name: aws-secrets
      key: AWS_SECRET_ACCESS_KEY
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: sqs-scaler
spec:
  scaleTargetRef:
    name: sqs-consumer
  minReplicaCount: 0  # Scale to Zero!
  maxReplicaCount: 10
  triggers:
    - type: aws-sqs-queue
      authenticationRef:
        name: aws-credentials
      metadata:
        queueURL: https://sqs.ap-northeast-2.amazonaws.com/123456789/my-queue
        queueLength: "5"
        awsRegion: ap-northeast-2
```

### CRITICAL: KEDA Scale-to-Zero

```yaml
# Scale-to-Zero 설정
spec:
  minReplicaCount: 0  # 0으로 스케일 다운 가능
  cooldownPeriod: 300  # 5분 유휴 후 0으로
  idleReplicaCount: 0  # 유휴 시 레플리카 수
```

**장점**: 비용 절감 (이벤트 없으면 Pod 0개)
**주의**: Cold Start 지연 발생

---

## Karpenter (Node Autoscaler)

### 설치 (EKS)

```bash
helm repo add karpenter https://charts.karpenter.sh
helm install karpenter karpenter/karpenter \
  --namespace karpenter --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$KARPENTER_ROLE_ARN \
  --set settings.clusterName=$CLUSTER_NAME \
  --set settings.interruptionQueue=$KARPENTER_QUEUE
```

### NodePool 설정

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        # 인스턴스 유형
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ["medium", "large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
  limits:
    cpu: 1000
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "my-cluster"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "my-cluster"
  role: KarpenterNodeRole-my-cluster
```

### Karpenter vs Cluster Autoscaler

| 항목 | Karpenter | Cluster Autoscaler |
|------|-----------|-------------------|
| 프로비저닝 속도 | 30-60초 | 수 분 |
| 인스턴스 선택 | 자동 최적화 | 노드 그룹 기반 |
| Spot 통합 | 네이티브 | 별도 설정 |
| 비용 최적화 | 자동 consolidation | 수동 |
| 지원 클라우드 | AWS | AWS, GCP, Azure |

---

## 조합 전략

### 권장 조합

```
┌─────────────────────────────────────────────────────────┐
│             Production Autoscaling Stack                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Stateless API ──> HPA (CPU 70%)                        │
│       +                                                  │
│  Event Consumer ──> KEDA (Kafka lag)                    │
│       +                                                  │
│  Right-sizing ──> VPA (Off mode, 추천만)                │
│       +                                                  │
│  Node 관리 ──> Karpenter (Spot 70% + On-Demand 30%)     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### 워크로드별 권장

| 워크로드 | 권장 조합 |
|----------|----------|
| API 서버 | HPA (CPU) + Karpenter |
| Kafka Consumer | KEDA (lag) + Karpenter |
| Batch Job | KEDA ScaledJob + Spot |
| ML 추론 | HPA (custom metric) + GPU Node |
| 크론 작업 | KEDA (cron trigger) |

---

## 모니터링

### Prometheus 메트릭

```promql
# HPA 현재 레플리카
kube_horizontalpodautoscaler_status_current_replicas

# HPA 목표 레플리카
kube_horizontalpodautoscaler_status_desired_replicas

# KEDA 스케일링 이벤트
keda_scaler_metrics_value

# Karpenter 노드 프로비저닝
karpenter_nodes_created_total
karpenter_nodes_terminated_total
```

### Grafana 대시보드

```json
{
  "panels": [
    {
      "title": "HPA Status",
      "targets": [{
        "expr": "kube_horizontalpodautoscaler_status_current_replicas{namespace=\"$namespace\"}",
        "legendFormat": "{{horizontalpodautoscaler}}"
      }]
    },
    {
      "title": "KEDA Scaler Value",
      "targets": [{
        "expr": "keda_scaler_metrics_value{namespace=\"$namespace\"}",
        "legendFormat": "{{scaledObject}}"
      }]
    }
  ]
}
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 메모리로 HPA | 느린 반응, OOM | CPU 또는 Custom Metric |
| requests 미설정 | HPA 계산 불가 | 항상 requests 설정 |
| HPA + VPA Auto | 충돌 | VPA Off 모드 사용 |
| maxReplicas > 파티션 | 유휴 Pod | 파티션 수 이하로 |
| 짧은 cooldown | 플래핑 | 적절한 대기 시간 |
| Spot만 사용 | 중단 위험 | On-Demand 혼합 |

---

## 체크리스트

### HPA
- [ ] Deployment에 requests 설정
- [ ] CPU 목표 60-80%
- [ ] stabilizationWindow 설정 (scaleDown 300s)
- [ ] minReplicas 2 이상

### VPA
- [ ] Off 모드로 추천 분석
- [ ] 추천값으로 requests 튜닝
- [ ] HPA와 함께 사용 시 Custom Metrics

### KEDA
- [ ] 적절한 스케일러 선택
- [ ] lagThreshold/threshold 튜닝
- [ ] Scale-to-Zero 필요시 설정
- [ ] TriggerAuthentication 설정

### Karpenter
- [ ] Spot + On-Demand 혼합
- [ ] consolidation 정책 설정
- [ ] NodePool limits 설정

**관련 skill**: `/kafka`, `/k8s-scheduling`, `/finops`, `/monitoring-metrics`
