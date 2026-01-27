# Kubernetes Scheduling 가이드

Node Affinity, Pod Affinity/Anti-Affinity, Taint & Toleration

## Quick Reference (결정 트리)

```
스케줄링 목적?
    │
    ├─ 특정 노드에 배치 ─────────> Node Affinity + nodeSelector
    │       │
    │       ├─ 필수 조건 ────> requiredDuringScheduling
    │       └─ 선호 조건 ────> preferredDuringScheduling
    │
    ├─ 특정 노드 회피 ──────────> Taint + Toleration
    │
    ├─ Pod 간 같이/따로 배치 ───> Pod Affinity/Anti-Affinity
    │       │
    │       ├─ 같은 노드/존 ──> Pod Affinity
    │       └─ 다른 노드/존 ──> Pod Anti-Affinity (HA)
    │
    └─ 리소스 기반 배치 ────────> Resource Requests
```

---

## CRITICAL: 스케줄링 개념 비교

| 기능 | 대상 | 방향 | 용도 |
|------|------|------|------|
| **nodeSelector** | Node | 끌어당김 | 단순 노드 선택 |
| **Node Affinity** | Node | 끌어당김 | 고급 노드 선택 |
| **Taint/Toleration** | Node | 밀어냄 | 노드 격리/전용화 |
| **Pod Affinity** | Pod | 끌어당김 | Pod 공존 |
| **Pod Anti-Affinity** | Pod | 밀어냄 | Pod 분산 (HA) |

```
┌─────────────────────────────────────────────────────────────┐
│                    Scheduling Flow                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Pod 생성 요청                                               │
│       │                                                      │
│       ▼                                                      │
│  Filtering (노드 필터링)                                     │
│  ├─ Taint/Toleration 체크                                   │
│  ├─ Node Affinity required 체크                             │
│  └─ 리소스 체크                                              │
│       │                                                      │
│       ▼                                                      │
│  Scoring (노드 점수화)                                       │
│  ├─ Node Affinity preferred 점수                            │
│  ├─ Pod Affinity/Anti-Affinity 점수                         │
│  └─ 리소스 균형 점수                                         │
│       │                                                      │
│       ▼                                                      │
│  최고 점수 노드에 배치                                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Node Selector (기본)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  nodeSelector:
    disktype: ssd
    environment: production
  containers:
    - name: my-container
      image: myapp:latest
```

**장점**: 단순함
**단점**: 필수 조건만 가능, OR 연산 불가

---

## Node Affinity

### 유형

| 유형 | 스케줄링 시 | 실행 중 | 용도 |
|------|------------|---------|------|
| **requiredDuringSchedulingIgnoredDuringExecution** | 필수 | 무시 | 반드시 필요한 조건 |
| **preferredDuringSchedulingIgnoredDuringExecution** | 선호 | 무시 | 가능하면 적용 |

### Required (필수)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              # GPU 노드에만 배치
              - key: gpu-type
                operator: In
                values:
                  - nvidia-a100
                  - nvidia-v100
              # 프로덕션 환경
              - key: environment
                operator: In
                values:
                  - production
  containers:
    - name: ml-training
      image: ml-training:latest
      resources:
        limits:
          nvidia.com/gpu: 1
```

### Preferred (선호)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        # 가중치 100: SSD 노드 선호
        - weight: 100
          preference:
            matchExpressions:
              - key: disktype
                operator: In
                values:
                  - ssd
        # 가중치 50: ap-northeast-2a 선호
        - weight: 50
          preference:
            matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                  - ap-northeast-2a
  containers:
    - name: web
      image: web:latest
```

### Operator 종류

| Operator | 의미 | 예시 |
|----------|------|------|
| **In** | 값 중 하나 | `values: [a, b]` |
| **NotIn** | 값이 아닌 것 | `values: [c, d]` |
| **Exists** | 키가 존재 | (values 불필요) |
| **DoesNotExist** | 키가 없음 | (values 불필요) |
| **Gt** | 값보다 큼 | `values: ["100"]` |
| **Lt** | 값보다 작음 | `values: ["50"]` |

---

## Taint & Toleration

### Taint 적용

```bash
# Taint 추가
kubectl taint nodes node1 dedicated=gpu:NoSchedule
kubectl taint nodes node1 maintenance=true:NoExecute

# Taint 제거
kubectl taint nodes node1 dedicated=gpu:NoSchedule-

# Taint 확인
kubectl describe node node1 | grep -A5 Taints
```

### Taint Effect

| Effect | 동작 |
|--------|------|
| **NoSchedule** | 새 Pod 스케줄링 금지 |
| **PreferNoSchedule** | 가능하면 스케줄링 안함 |
| **NoExecute** | 기존 Pod도 퇴거 |

### Toleration 설정

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload
spec:
  tolerations:
    # 정확히 일치하는 toleration
    - key: "dedicated"
      operator: "Equal"
      value: "gpu"
      effect: "NoSchedule"

    # 키만 일치 (모든 값 허용)
    - key: "gpu-type"
      operator: "Exists"
      effect: "NoSchedule"

    # NoExecute에 시간 제한
    - key: "node.kubernetes.io/not-ready"
      operator: "Exists"
      effect: "NoExecute"
      tolerationSeconds: 300  # 5분 후 퇴거

  containers:
    - name: gpu-app
      image: gpu-app:latest
```

### CRITICAL: GPU 노드 전용화

```bash
# 1. GPU 노드에 Taint 추가
kubectl taint nodes gpu-node-1 nvidia.com/gpu=true:NoSchedule

# 2. GPU 노드에 Label 추가
kubectl label nodes gpu-node-1 gpu-type=nvidia-a100
```

```yaml
# GPU 워크로드 Pod
apiVersion: v1
kind: Pod
spec:
  # Toleration: Taint 허용
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

  # Node Affinity: GPU 노드 선택
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: gpu-type
                operator: In
                values:
                  - nvidia-a100

  containers:
    - name: ml
      image: ml-training:latest
      resources:
        limits:
          nvidia.com/gpu: 1
```

---

## Pod Affinity / Anti-Affinity

### Pod Affinity (같이 배치)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: cache
    spec:
      affinity:
        podAffinity:
          # 필수: web Pod와 같은 노드
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - web
              topologyKey: kubernetes.io/hostname
      containers:
        - name: redis
          image: redis:7
```

### Pod Anti-Affinity (따로 배치) - HA

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: web
    spec:
      affinity:
        podAntiAffinity:
          # 필수: 같은 앱은 다른 노드에
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - web
              topologyKey: kubernetes.io/hostname

          # 선호: 가능하면 다른 AZ에
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - web
                topologyKey: topology.kubernetes.io/zone
      containers:
        - name: web
          image: web:latest
```

### TopologyKey 종류

| TopologyKey | 분산 범위 |
|-------------|----------|
| `kubernetes.io/hostname` | 노드 |
| `topology.kubernetes.io/zone` | AZ (가용 영역) |
| `topology.kubernetes.io/region` | 리전 |
| `kubernetes.io/os` | OS 유형 |

---

## 실전 시나리오

### 1. 프로덕션 워크로드 격리

```yaml
# 프로덕션 노드 Taint
# kubectl taint nodes prod-node-* environment=production:NoSchedule

apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-app
spec:
  template:
    spec:
      tolerations:
        - key: "environment"
          operator: "Equal"
          value: "production"
          effect: "NoSchedule"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: environment
                    operator: In
                    values:
                      - production
      containers:
        - name: app
          image: app:latest
```

### 2. 멀티 AZ 고가용성

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-app
spec:
  replicas: 6
  template:
    spec:
      affinity:
        # 다른 노드에 분산
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: ha-app
              topologyKey: kubernetes.io/hostname

        # AZ 균등 분산
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: ha-app
                topologyKey: topology.kubernetes.io/zone
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: ha-app
```

### 3. 데이터 지역성 (캐시 + 앱)

```yaml
# Redis 배포
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  template:
    metadata:
      labels:
        app: redis
        tier: cache
    spec:
      containers:
        - name: redis
          image: redis:7
---
# 앱: Redis와 같은 노드 선호
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  template:
    spec:
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    tier: cache
                topologyKey: kubernetes.io/hostname
      containers:
        - name: web
          image: web:latest
```

---

## Topology Spread Constraints

### 균등 분산

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-app
spec:
  replicas: 6
  template:
    spec:
      topologySpreadConstraints:
        # AZ 간 균등 분산
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: spread-app

        # 노드 간 균등 분산
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: spread-app
      containers:
        - name: app
          image: app:latest
```

| 파라미터 | 설명 |
|----------|------|
| **maxSkew** | 최대 불균형 허용치 (1 = 완벽 균등) |
| **whenUnsatisfiable** | DoNotSchedule / ScheduleAnyway |

---

## 디버깅

### 스케줄링 실패 원인 확인

```bash
# Pod 이벤트 확인
kubectl describe pod <pod-name>

# 일반적인 실패 메시지
# - 0/5 nodes are available: 3 node(s) had taint {key=value:NoSchedule}
# - 0/5 nodes are available: 2 node(s) didn't match Pod's node affinity
# - 0/5 nodes are available: 1 Insufficient cpu, 2 Insufficient memory
```

### 노드 상태 확인

```bash
# 노드 라벨 확인
kubectl get nodes --show-labels

# 노드 Taint 확인
kubectl describe nodes | grep -A3 Taints

# 노드 리소스 확인
kubectl describe node <node-name> | grep -A5 "Allocated resources"
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| required만 사용 | 스케줄링 불가 상황 | preferred 혼용 |
| Anti-Affinity + 적은 노드 | 레플리카 부족 | 노드 수 확보 또는 preferred |
| Toleration만 설정 | 다른 노드에도 배치됨 | Node Affinity 함께 사용 |
| topologyKey 오타 | 무시됨 | 표준 키 사용 |
| 과도한 Taint | 스케줄링 복잡 | 필요한 것만 |

---

## 체크리스트

### Node Affinity
- [ ] required vs preferred 구분
- [ ] operator 올바른 사용
- [ ] 노드 라벨 사전 확인

### Taint/Toleration
- [ ] Taint와 함께 Node Affinity 사용
- [ ] tolerationSeconds 고려 (NoExecute)
- [ ] 시스템 Taint 처리

### Pod Affinity/Anti-Affinity
- [ ] topologyKey 적절히 설정
- [ ] HA를 위한 Anti-Affinity
- [ ] 데이터 지역성 고려

### Topology Spread
- [ ] maxSkew 적절히 설정
- [ ] 여러 topology 레벨 고려

**관련 skill**: `/k8s-autoscaling`, `/k8s-security`, `/k8s-helm`
