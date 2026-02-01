# eBPF Observability 가이드

Zero-code 분산 추적: Grafana Beyla, Odigos, Cilium Hubble 활용

## Quick Reference (결정 트리)

```
eBPF Observability 도구 선택?
    |
    +-- 자동 HTTP/gRPC 추적 ---------> Grafana Beyla
    |       |
    |       +-- 단일 앱 모니터링 -----> Beyla Sidecar
    |       +-- 클러스터 전체 --------> Beyla DaemonSet
    |
    +-- 멀티 언어 자동 계측 ---------> Odigos
    |       |
    |       +-- OpenTelemetry 백엔드 -> Odigos + OTel Collector
    |       +-- 엔터프라이즈 ---------> Odigos Enterprise
    |
    +-- 네트워크 가시성 -------------> Cilium Hubble
    |       |
    |       +-- Service Map ---------> Hubble UI
    |       +-- 네트워크 정책 디버깅 -> Hubble CLI
    |
    +-- 종합 플랫폼 -----------------> DeepFlow
            |
            +-- 분산 추적 + APM -----> DeepFlow Community
```

---

## CRITICAL: eBPF vs 기존 Agent 비교

| 항목 | 기존 Agent | eBPF 기반 |
|------|-----------|----------|
| **코드 변경** | SDK 추가 필요 | Zero-code |
| **시작 시간** | Agent 초기화 대기 | 즉시 |
| **리소스 오버헤드** | 높음 (~100MB/Pod) | 낮음 (Node 레벨) |
| **언어 지원** | 언어별 SDK | 모든 언어 자동 |
| **커널 접근** | 불가 | 시스템 콜 추적 |
| **컨테이너 호환** | 복잡한 설정 | 자동 감지 |
| **성숙도** | 검증됨 | 발전 중 (2024~) |

### eBPF 장점

```
커널 레벨 모니터링
    |
    +-- 100배 빠른 시작 (ms 단위)
    +-- 애플리케이션 변경 없음
    +-- 모든 언어/프레임워크 지원
    +-- 네트워크 + 시스템 콜 추적
    +-- 낮은 오버헤드 (1-3%)
```

---

## eBPF 기초 개념

### eBPF 아키텍처

```
User Space                         Kernel Space
+------------------+              +----------------------+
|                  |              |                      |
| BPF Program      |   load       | eBPF Virtual Machine |
| (C, Rust, Go)    | --------->   |                      |
|                  |              | +------------------+ |
+------------------+              | | Verifier         | |
                                  | | (안전성 검증)    | |
+------------------+              | +------------------+ |
|                  |              |         |           |
| BPF Maps         | <----------> | +------------------+ |
| (데이터 저장)    |   read/write | | JIT Compiler     | |
|                  |              | | (네이티브 코드)  | |
+------------------+              | +------------------+ |
                                  |         |           |
                                  | +------------------+ |
                                  | | Hook Points      | |
                                  | | (kprobe, uprobe, | |
                                  | |  tracepoint)     | |
                                  | +------------------+ |
                                  +----------------------+
```

### 주요 Hook 포인트

```yaml
# eBPF Hook 포인트 종류
kprobe:
  - 커널 함수 진입/종료 추적
  - 예: tcp_connect, tcp_accept

uprobe:
  - 사용자 공간 함수 추적
  - 예: HTTP 핸들러, DB 쿼리

tracepoint:
  - 커널 정적 추적점
  - 예: syscalls, scheduler

XDP (eXpress Data Path):
  - 패킷 레벨 처리 (NIC 드라이버)
  - 예: DDoS 방어, 로드밸런싱

tc (Traffic Control):
  - 네트워크 트래픽 제어
  - 예: QoS, 패킷 필터링
```

---

## Grafana Beyla

### 개요

Grafana Beyla는 eBPF 기반 자동 계측 도구로, 애플리케이션 코드 변경 없이 HTTP/gRPC 트레이싱과 메트릭을 수집합니다.

### 지원 프로토콜

- HTTP/1.x, HTTP/2
- gRPC
- SQL (MySQL, PostgreSQL)
- Redis
- Kafka

### DaemonSet 배포 (클러스터 전체)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: beyla
  namespace: observability
spec:
  selector:
    matchLabels:
      app: beyla
  template:
    metadata:
      labels:
        app: beyla
    spec:
      serviceAccountName: beyla
      hostPID: true  # eBPF를 위한 필수 설정
      containers:
        - name: beyla
          image: grafana/beyla:1.8
          securityContext:
            privileged: true  # eBPF 커널 접근
            runAsUser: 0
          env:
            # 발견 설정
            - name: BEYLA_DISCOVERY_SERVICES
              value: "http"  # http, grpc, sql

            # OpenTelemetry 내보내기
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.observability:4317"
            - name: OTEL_EXPORTER_OTLP_PROTOCOL
              value: "grpc"

            # Prometheus 메트릭
            - name: BEYLA_PROMETHEUS_PORT
              value: "9090"

            # 네임스페이스 필터
            - name: BEYLA_KUBE_NAMESPACE
              value: "production,staging"
          volumeMounts:
            - name: sys-kernel-debug
              mountPath: /sys/kernel/debug
      volumes:
        - name: sys-kernel-debug
          hostPath:
            path: /sys/kernel/debug
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: beyla
  namespace: observability
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: beyla
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: beyla
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: beyla
subjects:
  - kind: ServiceAccount
    name: beyla
    namespace: observability
```

### Sidecar 배포 (특정 앱)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      shareProcessNamespace: true  # Sidecar에서 앱 프로세스 접근
      containers:
        - name: my-app
          image: my-app:latest
          ports:
            - containerPort: 8080

        - name: beyla
          image: grafana/beyla:1.8
          securityContext:
            privileged: true
            runAsUser: 0
          env:
            - name: BEYLA_OPEN_PORT
              value: "8080"  # 특정 포트만 모니터링
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.observability:4317"
```

### Beyla 설정 파일

```yaml
# beyla-config.yaml
discovery:
  services:
    - name: "http-services"
      k8s_namespace: "production"
      k8s_pod_labels:
        app: "*"
    - name: "grpc-services"
      k8s_namespace: "production"
      protocol: grpc

# 라우트 정규화
routes:
  patterns:
    - /api/users/{id}
    - /api/orders/{orderId}/items/{itemId}
  ignored_patterns:
    - /health
    - /ready
    - /metrics

# 메트릭 설정
prometheus:
  port: 9090
  path: /metrics

# 트레이싱 설정
otel:
  protocol: grpc
  endpoint: http://otel-collector:4317
  traces:
    enabled: true
    sampler:
      name: parentbased_traceidratio
      arg: "0.1"  # 10% 샘플링

# 필터
attributes:
  kubernetes:
    enable: true
```

---

## Odigos

### 개요

Odigos는 eBPF 기반 자동 계측 플랫폼으로, 설치만으로 클러스터 전체 애플리케이션을 OpenTelemetry로 계측합니다.

### 설치

```bash
# Helm 설치
helm repo add odigos https://keyval-dev.github.io/odigos-charts
helm install odigos odigos/odigos \
  --namespace odigos-system \
  --create-namespace

# 또는 CLI 설치
brew install odigos
odigos install
```

### 백엔드 설정

```yaml
# odigos-destination.yaml
apiVersion: odigos.io/v1alpha1
kind: Destination
metadata:
  name: jaeger
  namespace: odigos-system
spec:
  type: jaeger
  jaeger:
    endpoint: "jaeger-collector.observability:14250"
---
apiVersion: odigos.io/v1alpha1
kind: Destination
metadata:
  name: prometheus
  namespace: odigos-system
spec:
  type: prometheus
  prometheus:
    url: "http://prometheus.observability:9090/api/v1/write"
---
apiVersion: odigos.io/v1alpha1
kind: Destination
metadata:
  name: grafana-cloud
  namespace: odigos-system
spec:
  type: grafana
  grafana:
    url: "https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
    secretRef:
      name: grafana-credentials
```

### 네임스페이스 활성화

```yaml
# 네임스페이스 레이블로 자동 계측 활성화
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    odigos-instrumentation: enabled
---
# 또는 InstrumentedApplication CR
apiVersion: odigos.io/v1alpha1
kind: InstrumentedApplication
metadata:
  name: my-app
  namespace: production
spec:
  instrumentations:
    - type: ebpf
      languages:
        - go
        - java
        - python
        - nodejs
        - dotnet
```

### 언어별 지원 현황

| 언어 | 지원 프레임워크 | 자동 계측 |
|------|----------------|----------|
| **Go** | net/http, gin, echo, fiber | eBPF |
| **Java** | Spring, Quarkus, Micronaut | eBPF + Agent |
| **Python** | Flask, Django, FastAPI | eBPF |
| **Node.js** | Express, Fastify, NestJS | eBPF |
| **.NET** | ASP.NET Core | eBPF |
| **Rust** | Actix, Axum | eBPF |

---

## Cilium Hubble

### 개요

Hubble은 Cilium의 네트워크 가시성 레이어로, eBPF 기반 패킷 레벨 모니터링을 제공합니다.

### Hubble 활성화

```bash
# Cilium에서 Hubble 활성화
cilium hubble enable --ui

# 또는 Helm values
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}"
```

### Hubble Helm 설정

```yaml
# cilium-values.yaml
hubble:
  enabled: true

  relay:
    enabled: true
    replicas: 1

  ui:
    enabled: true
    replicas: 1
    ingress:
      enabled: true
      hosts:
        - hubble.example.com

  metrics:
    enabled:
      - dns:query
      - drop
      - tcp
      - flow
      - icmp
      - http
    serviceMonitor:
      enabled: true

  # L7 가시성 (HTTP, gRPC, Kafka)
  export:
    static:
      enabled: true
      filePath: /var/run/cilium/hubble/events.log

# L7 프록시 활성화 (필요 시)
envoy:
  enabled: true
```

### Hubble CLI 사용

```bash
# Flow 관찰
hubble observe --namespace production

# 특정 서비스 트래픽
hubble observe --to-service payment-service

# 드롭된 패킷 확인
hubble observe --verdict DROPPED

# HTTP 요청 필터
hubble observe --protocol http --http-status 500

# JSON 출력
hubble observe -o json | jq '.flow.source.labels'

# 실시간 Service Map
hubble observe --output=compact --follow
```

### Network Policy 디버깅

```bash
# 정책으로 드롭된 트래픽 확인
hubble observe --verdict DROPPED --type policy-verdict

# 특정 Pod 트래픽 추적
hubble observe --from-pod production/my-app-xyz

# DNS 쿼리 모니터링
hubble observe --protocol dns

# 출력 예시
TIMESTAMP             SOURCE                DESTINATION           TYPE    VERDICT   SUMMARY
Jan 15 10:30:15.123   production/app-a      production/app-b      L7/HTTP FORWARDED GET /api/users HTTP/1.1
Jan 15 10:30:15.456   production/app-b      external/0.0.0.0      L3/L4   DROPPED   Policy denied
```

---

## DeepFlow

### 개요

DeepFlow는 eBPF 기반 종합 Observability 플랫폼으로, 자동 분산 추적과 네트워크 성능 모니터링을 제공합니다.

### 설치

```bash
# Helm 설치
helm repo add deepflow https://deepflowio.github.io/deepflow
helm install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --set global.image.repository=deepflowce
```

### 주요 기능

```yaml
# DeepFlow 기능 매트릭스
AutoTracing:
  - eBPF 기반 자동 Span 생성
  - 분산 트레이싱 (코드 변경 없음)
  - Cross-process 상관관계 자동 연결

AutoMetrics:
  - 서비스별 RED 메트릭 (Rate, Error, Duration)
  - 네트워크 레이턴시
  - TCP 재전송, RTT

AutoTagging:
  - Kubernetes 메타데이터 자동 태깅
  - Cloud 리소스 매핑 (AWS, GCP, Azure)

NetworkProfiling:
  - 패킷 레벨 분석
  - 네트워크 경로 추적
```

---

## CRITICAL: eBPF 요구사항

### 커널 버전

```bash
# 최소 커널 버전 확인
uname -r
# 권장: 5.8 이상 (BTF 지원)
# 최소: 4.15 (기본 eBPF)

# BTF 지원 확인
ls /sys/kernel/btf/vmlinux
```

### 노드 요구사항

| 요구사항 | 설명 |
|---------|------|
| **커널** | 5.8+ 권장 (BTF, CO-RE) |
| **CAP_BPF** | eBPF 프로그램 로드 |
| **CAP_SYS_PTRACE** | uprobe 활성화 |
| **CAP_NET_ADMIN** | XDP, TC 프로그램 |
| **/sys/kernel/debug** | tracing 접근 |

### SecurityContext 설정

```yaml
securityContext:
  # 옵션 1: privileged (개발/테스트)
  privileged: true

  # 옵션 2: capabilities (프로덕션 권장)
  capabilities:
    add:
      - BPF
      - SYS_PTRACE
      - NET_ADMIN
      - PERFMON
  runAsUser: 0
```

---

## OpenTelemetry 연동

### OTel Collector 설정

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

  k8sattributes:
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.pod.name
        - k8s.deployment.name
        - k8s.node.name

exporters:
  otlp/jaeger:
    endpoint: jaeger-collector:4317
    tls:
      insecure: true

  prometheus:
    endpoint: 0.0.0.0:8889
    namespace: ebpf

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, k8sattributes]
      exporters: [otlp/jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch, k8sattributes]
      exporters: [prometheus]
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 구버전 커널에서 실행 | 기능 제한/실패 | 커널 5.8+ 업그레이드 |
| privileged 없이 배포 | eBPF 로드 실패 | 적절한 capabilities |
| 모든 네임스페이스 활성화 | 오버헤드 증가 | 필요한 네임스페이스만 |
| 샘플링 미설정 | 과도한 데이터 | 10% 샘플링 시작 |
| Hubble L7 무분별 활성화 | CPU 사용량 급증 | 필요한 서비스만 |

---

## 체크리스트

### 환경 준비
- [ ] 커널 버전 확인 (5.8+ 권장)
- [ ] BTF 지원 확인
- [ ] SecurityContext 설정

### Beyla 배포
- [ ] DaemonSet 또는 Sidecar 선택
- [ ] 네임스페이스 필터 설정
- [ ] OTel Collector 연동

### Odigos 배포
- [ ] 백엔드 Destination 설정
- [ ] 네임스페이스 레이블
- [ ] 언어별 지원 확인

### Hubble 설정
- [ ] Cilium 기반 확인
- [ ] 필요한 메트릭 활성화
- [ ] UI/Relay 배포

### OpenTelemetry
- [ ] OTel Collector 설정
- [ ] 트레이싱 백엔드 연동
- [ ] 샘플링 비율 설정

**관련 skill**: `/observability-otel`, `/monitoring-metrics`, `/cilium-networking`

---

## Sources

- [OpenTelemetry eBPF (OBI)](https://opentelemetry.io/docs/zero-code/obi/)
- [Grafana Beyla Documentation](https://grafana.com/docs/grafana-cloud/monitor-applications/application-observability/setup/instrument/beyla/)
- [Odigos Documentation](https://docs.odigos.io/)
- [Cilium Hubble](https://docs.cilium.io/en/stable/observability/hubble/)
- [DeepFlow](https://deepflow.io/docs/)
- [eBPF Introduction](https://ebpf.io/what-is-ebpf/)
