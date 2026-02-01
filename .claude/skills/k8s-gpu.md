# Kubernetes GPU 가이드

NVIDIA GPU Operator, MIG 파티셔닝, Kueue/Volcano 스케줄링, GPU 모니터링

## Quick Reference (결정 트리)

```
GPU 워크로드 유형?
    │
    ├─ 분산 학습 (Multi-GPU)
    │       │
    │       ├─ Gang 스케줄링 필요 ───> Volcano
    │       └─ 큐 관리 필요 ────────> Kueue
    │
    ├─ 단일 GPU 학습
    │       │
    │       └─ 기본 스케줄링 ───────> NVIDIA Device Plugin
    │
    ├─ GPU 공유 (소형 워크로드)
    │       │
    │       ├─ 격리 필요 ──────────> MIG (A100/H100)
    │       └─ 처리량 우선 ────────> MPS (시분할)
    │
    └─ 추론
            │
            ├─ 소형 모델 ──────────> MIG / Time-slicing
            └─ 대형 LLM ───────────> 전용 GPU
```

---

## CRITICAL: GPU 스케줄링 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                 Kubernetes GPU Scheduling Stack                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Application Layer                            │   │
│  │  ┌─────────┬─────────┬─────────┬─────────┐               │   │
│  │  │PyTorch  │Tensor-  │ KServe  │ Custom  │               │   │
│  │  │Job      │FlowJob  │Inference│  Pod    │               │   │
│  │  └─────────┴─────────┴─────────┴─────────┘               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Scheduling Layer                             │   │
│  │  ┌─────────────────────┬─────────────────────┐           │   │
│  │  │       Kueue         │      Volcano        │           │   │
│  │  │  (Queue/Quota)      │  (Gang Scheduling)  │           │   │
│  │  └─────────────────────┴─────────────────────┘           │   │
│  │                        │                                  │   │
│  │  ┌─────────────────────────────────────────────┐         │   │
│  │  │           Default K8s Scheduler             │         │   │
│  │  └─────────────────────────────────────────────┘         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Device Layer                                 │   │
│  │  ┌─────────┬─────────┬─────────┬─────────┐               │   │
│  │  │ NVIDIA  │  MIG    │   MPS   │  DCGM   │               │   │
│  │  │ Device  │Manager  │         │Exporter │               │   │
│  │  │ Plugin  │         │         │         │               │   │
│  │  └─────────┴─────────┴─────────┴─────────┘               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Hardware Layer                               │   │
│  │  ┌─────────┬─────────┬─────────┬─────────┐               │   │
│  │  │ A100    │  H100   │   T4    │  L4     │               │   │
│  │  │ (80GB)  │ (80GB)  │ (16GB)  │ (24GB)  │               │   │
│  │  └─────────┴─────────┴─────────┴─────────┘               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## NVIDIA GPU Operator

### 설치

```bash
# Helm repo 추가
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

# GPU Operator 설치
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=true \
  --set toolkit.enabled=true \
  --set devicePlugin.enabled=true \
  --set dcgmExporter.enabled=true \
  --set mig.strategy=mixed  # MIG 지원
```

### 설정 옵션

```yaml
# gpu-operator-values.yaml
driver:
  enabled: true
  version: "535.104.12"  # CUDA 12.2

toolkit:
  enabled: true

devicePlugin:
  enabled: true
  config:
    name: time-slicing-config
    default: any

dcgmExporter:
  enabled: true
  serviceMonitor:
    enabled: true

mig:
  strategy: mixed  # none, single, mixed

nodeStatusExporter:
  enabled: true

validator:
  enabled: true
```

### GPU 노드 확인

```bash
# GPU 노드 레이블 확인
kubectl get nodes -l nvidia.com/gpu.present=true

# GPU 리소스 확인
kubectl describe node <gpu-node> | grep -A 10 "Allocatable"

# nvidia.com/gpu:  8
# nvidia.com/mig-1g.5gb: 0

# 할당된 GPU 확인
kubectl get pods -A -o custom-columns=\
"POD:.metadata.name,GPU:.spec.containers[*].resources.limits.nvidia\.com/gpu"
```

---

## GPU 공유 전략

### MIG (Multi-Instance GPU)

**지원 GPU**: A100, A30, H100

```yaml
# MIG 파티션 설정
apiVersion: v1
kind: ConfigMap
metadata:
  name: mig-parted-config
  namespace: gpu-operator
data:
  config.yaml: |
    version: v1
    mig-configs:
      # A100-40GB 파티션 예시
      all-1g.5gb:
        - devices: all
          mig-enabled: true
          mig-devices:
            "1g.5gb": 7     # 7개의 소형 인스턴스

      all-balanced:
        - devices: all
          mig-enabled: true
          mig-devices:
            "3g.20gb": 2    # 중형 2개
            "1g.5gb": 1     # 소형 1개

      # H100-80GB 파티션 예시
      h100-inference:
        - devices: all
          mig-enabled: true
          mig-devices:
            "1g.10gb": 7    # 추론용 소형 7개
```

### MIG 사용 Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mig-inference-pod
spec:
  containers:
    - name: inference
      image: nvcr.io/nvidia/tritonserver:latest
      resources:
        limits:
          nvidia.com/mig-1g.5gb: 1  # MIG 슬라이스 요청
```

### Time-Slicing (시분할)

**모든 GPU 지원**

```yaml
# Time-slicing 설정
apiVersion: v1
kind: ConfigMap
metadata:
  name: time-slicing-config
  namespace: gpu-operator
data:
  any: |
    version: v1
    sharing:
      timeSlicing:
        renameByDefault: false
        resources:
          - name: nvidia.com/gpu
            replicas: 4  # 1 GPU를 4개로 분할
```

```yaml
# Time-slicing 사용 Pod
apiVersion: v1
kind: Pod
metadata:
  name: shared-gpu-pod
spec:
  containers:
    - name: app
      image: cuda-app:latest
      resources:
        limits:
          nvidia.com/gpu: 1  # 1/4 GPU 사용
```

### MPS (Multi-Process Service)

**CUDA 컨텍스트 공유**

```yaml
# MPS 활성화
apiVersion: v1
kind: ConfigMap
metadata:
  name: mps-config
  namespace: gpu-operator
data:
  config.yaml: |
    version: v1
    sharing:
      mps:
        renameByDefault: false
        resources:
          - name: nvidia.com/gpu
            replicas: 10  # 최대 10개 프로세스 공유
```

### 공유 전략 비교

| 전략 | 격리 | 성능 | 적합 워크로드 |
|------|------|------|---------------|
| **MIG** | 하드웨어 | 최고 | 안정적 추론, 학습 |
| **Time-slicing** | 없음 | 중간 | 개발, CI/CD |
| **MPS** | 소프트웨어 | 높음 | 추론, 배치 |

---

## Kueue (큐 관리)

### 설치

```bash
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/kueue/releases/download/v0.6.0/manifests.yaml
```

### ClusterQueue 설정

```yaml
# GPU 리소스 풀 정의
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: a100-40gb
spec:
  nodeLabels:
    nvidia.com/gpu.product: "NVIDIA-A100-SXM4-40GB"
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: t4
spec:
  nodeLabels:
    nvidia.com/gpu.product: "Tesla-T4"
---
# ClusterQueue
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: ml-cluster-queue
spec:
  namespaceSelector: {}
  queueingStrategy: StrictFIFO
  resourceGroups:
    - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
      flavors:
        - name: a100-40gb
          resources:
            - name: "nvidia.com/gpu"
              nominalQuota: 16
              borrowingLimit: 4
            - name: "cpu"
              nominalQuota: 128
            - name: "memory"
              nominalQuota: 512Gi
        - name: t4
          resources:
            - name: "nvidia.com/gpu"
              nominalQuota: 32
  preemption:
    reclaimWithinCohort: Any
    withinClusterQueue: LowerPriority
---
# LocalQueue (팀별)
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: ml-team-queue
  namespace: ml-training
spec:
  clusterQueue: ml-cluster-queue
```

### Kueue Job 제출

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: training-job
  namespace: ml-training
  labels:
    kueue.x-k8s.io/queue-name: ml-team-queue
spec:
  parallelism: 4
  completions: 4
  suspend: true  # Kueue가 관리
  template:
    spec:
      containers:
        - name: trainer
          image: pytorch-training:latest
          resources:
            requests:
              nvidia.com/gpu: 1
              cpu: 8
              memory: 32Gi
            limits:
              nvidia.com/gpu: 1
      restartPolicy: Never
```

---

## Volcano (Gang Scheduling)

### 설치

```bash
helm repo add volcano-sh https://volcano-sh.github.io/helm-charts
helm install volcano volcano-sh/volcano \
  --namespace volcano-system \
  --create-namespace
```

### 분산 학습 Job

```yaml
# PyTorch DDP with Volcano
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: pytorch-ddp-training
spec:
  minAvailable: 4      # Gang: 4개 모두 시작해야 함
  schedulerName: volcano
  plugins:
    svc: ["--publish-not-ready-addresses"]
    ssh: []
    env: []
  policies:
    - event: PodEvicted
      action: RestartJob
  queue: default
  tasks:
    - replicas: 4
      name: worker
      template:
        spec:
          containers:
            - name: pytorch
              image: pytorch-ddp:latest
              command:
                - torchrun
                - --nnodes=4
                - --nproc_per_node=1
                - --rdzv_backend=c10d
                - --rdzv_endpoint=$(VC_WORKER_0_SVC):29500
                - train.py
              ports:
                - containerPort: 29500
                  name: rdzv
              resources:
                limits:
                  nvidia.com/gpu: 1
                  rdma/rdma_shared_device_a: 1  # RDMA (선택)
              env:
                - name: NCCL_DEBUG
                  value: INFO
                - name: NCCL_IB_DISABLE
                  value: "0"
          restartPolicy: OnFailure
```

### MPI Job (Horovod)

```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: horovod-training
spec:
  minAvailable: 5  # 1 master + 4 workers
  schedulerName: volcano
  plugins:
    ssh: []
    svc: []
  tasks:
    - replicas: 1
      name: master
      policies:
        - event: TaskCompleted
          action: CompleteJob
      template:
        spec:
          containers:
            - name: horovod
              image: horovod-training:latest
              command:
                - horovodrun
                - -np
                - "4"
                - -H
                - $(VC_WORKER_HOSTS)
                - python
                - train.py
    - replicas: 4
      name: worker
      template:
        spec:
          containers:
            - name: horovod
              image: horovod-training:latest
              resources:
                limits:
                  nvidia.com/gpu: 1
```

---

## GPU 모니터링

### DCGM Exporter 메트릭

```promql
# GPU 사용률 (%)
DCGM_FI_DEV_GPU_UTIL

# GPU 메모리 사용량
DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL * 100

# GPU 온도
DCGM_FI_DEV_GPU_TEMP

# 전력 소비
DCGM_FI_DEV_POWER_USAGE

# Tensor Core 활용률
DCGM_FI_PROF_PIPE_TENSOR_ACTIVE

# SM (Streaming Multiprocessor) 활용률
DCGM_FI_PROF_SM_ACTIVE
```

### Grafana 대시보드 패널

```json
{
  "panels": [
    {
      "title": "GPU Utilization by Node",
      "targets": [{
        "expr": "DCGM_FI_DEV_GPU_UTIL{gpu=~\"$gpu\"}",
        "legendFormat": "{{kubernetes_node}} - GPU {{gpu}}"
      }]
    },
    {
      "title": "GPU Memory Usage",
      "targets": [{
        "expr": "DCGM_FI_DEV_FB_USED{gpu=~\"$gpu\"} / DCGM_FI_DEV_FB_TOTAL * 100",
        "legendFormat": "{{kubernetes_node}} - GPU {{gpu}}"
      }]
    },
    {
      "title": "Cluster GPU Allocation",
      "targets": [{
        "expr": "sum(kube_pod_container_resource_limits{resource=\"nvidia_com_gpu\"}) / sum(kube_node_status_allocatable{resource=\"nvidia_com_gpu\"}) * 100"
      }]
    }
  ]
}
```

### 알림 규칙

```yaml
groups:
  - name: gpu-alerts
    rules:
      - alert: GPUHighTemperature
        expr: DCGM_FI_DEV_GPU_TEMP > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "GPU temperature > 85°C"

      - alert: GPUMemoryExhausted
        expr: DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL > 0.95
        for: 5m
        labels:
          severity: critical

      - alert: GPUUnderutilized
        expr: DCGM_FI_DEV_GPU_UTIL < 20
        for: 30m
        labels:
          severity: info
        annotations:
          summary: "GPU underutilized - consider right-sizing"
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 전체 GPU 요청 | 리소스 낭비 | MIG/Time-slicing |
| Gang 스케줄링 미사용 | 분산 학습 실패 | Volcano 사용 |
| 쿼터 미설정 | 팀간 경합 | Kueue ClusterQueue |
| 모니터링 부재 | 사용률 불명 | DCGM Exporter |
| 단일 노드 풀 | 스케일링 어려움 | 워크로드별 노드 풀 |

---

## 체크리스트

### 인프라 설정
- [ ] NVIDIA GPU Operator 설치
- [ ] DCGM Exporter 활성화
- [ ] GPU 노드 레이블링
- [ ] Karpenter/CA GPU 풀 설정

### 스케줄링
- [ ] Kueue 또는 Volcano 설치
- [ ] ClusterQueue/LocalQueue 정의
- [ ] 팀별 쿼터 설정
- [ ] 우선순위 클래스 정의

### 공유 전략
- [ ] MIG 프로필 설정 (A100/H100)
- [ ] Time-slicing 또는 MPS 설정
- [ ] ResourceFlavor 정의

### 모니터링
- [ ] Grafana 대시보드 구성
- [ ] 알림 규칙 설정
- [ ] 사용률 리포트 자동화

**관련 agent**: `mlops-expert`
**관련 skill**: `/ml-serving`, `/k8s-autoscaling`

---

## Sources

- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [Kueue Documentation](https://kueue.sigs.k8s.io/)
- [Volcano Documentation](https://volcano.sh/docs/)
- [DCGM Exporter](https://github.com/NVIDIA/dcgm-exporter)
