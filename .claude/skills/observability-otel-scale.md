# OpenTelemetry 대규모 트래픽 설정 가이드

초당 수만~수십만 요청 환경을 위한 OTel Collector 스케일링, 샘플링 전략, 비용 최적화

## Quick Reference (결정 트리)

```
대규모 트래픽 OTel 아키텍처?
    |
    +-- 초당 1만 요청 미만 ----------> 단일 Collector + Head Sampling
    |
    +-- 초당 1만~10만 요청 ----------> Agent + Gateway 패턴
    |       |
    |       +-- 샘플링 ---------------> Tail-based (중요 트레이스 보존)
    |       +-- 버퍼링 ---------------> Kafka/Redis 큐
    |
    +-- 초당 10만+ 요청 -------------> 분산 Collector + Load Balancing
            |
            +-- Multi-tier ------------> Agent → Gateway → Backend
            +-- Sharding --------------> Trace ID 기반 샤딩

샘플링 전략?
    |
    +-- 비용 최적화 우선 ------------> Head Sampling (10-20%)
    +-- 에러/지연 분석 우선 ---------> Tail-based Sampling
    +-- 하이브리드 -----------------> Probabilistic + Error-based
```

---

## CRITICAL: 트래픽 규모별 아키텍처

### 소규모 (< 10K RPS)

```
App Pods ──────> OTel Collector ──────> Backend (Tempo/Jaeger)
                 (Deployment)
```

### 중규모 (10K - 100K RPS)

```
┌─────────────────────────────────────────────────────────────────┐
│  Node 1                    Node 2                    Node N     │
│  ┌─────────┐              ┌─────────┐              ┌─────────┐ │
│  │ App Pod │              │ App Pod │              │ App Pod │ │
│  └────┬────┘              └────┬────┘              └────┬────┘ │
│       │                        │                        │      │
│       ▼                        ▼                        ▼      │
│  ┌─────────┐              ┌─────────┐              ┌─────────┐ │
│  │ Agent   │              │ Agent   │              │ Agent   │ │
│  │(DaemonSet)             │(DaemonSet)             │(DaemonSet) │
│  └────┬────┘              └────┬────┘              └────┬────┘ │
└───────┼────────────────────────┼────────────────────────┼──────┘
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │   Gateway Collector     │
                    │   (Deployment, HPA)     │
                    │   - Tail Sampling       │
                    │   - Aggregation         │
                    └────────────┬────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
         ┌─────────┐       ┌─────────┐       ┌─────────┐
         │  Tempo  │       │  Loki   │       │Prometheus│
         │(Traces) │       │ (Logs)  │       │(Metrics) │
         └─────────┘       └─────────┘       └─────────┘
```

### 대규모 (100K+ RPS)

```
                            ┌──────────────────┐
                            │  Load Balancer   │
                            │(Trace ID Hashing)│
                            └────────┬─────────┘
                                     │
        ┌────────────────────────────┼────────────────────────────┐
        ▼                            ▼                            ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│ Gateway Pool 1│          │ Gateway Pool 2│          │ Gateway Pool N│
│ (Shard A-F)   │          │ (Shard G-M)   │          │ (Shard N-Z)   │
└───────┬───────┘          └───────┬───────┘          └───────┬───────┘
        │                          │                          │
        └──────────────────────────┼──────────────────────────┘
                                   ▼
                          ┌─────────────────┐
                          │      Kafka      │
                          │  (Buffer/Queue) │
                          └────────┬────────┘
                                   │
                                   ▼
                    ┌─────────────────────────┐
                    │   Backend Collector     │
                    │   - Final Processing    │
                    │   - Export to Storage   │
                    └─────────────────────────┘
```

---

## Agent Collector (DaemonSet)

### Helm 설치

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

helm install otel-agent open-telemetry/opentelemetry-collector \
  --namespace observability \
  --create-namespace \
  -f otel-agent-values.yaml
```

### Agent 설정

```yaml
# otel-agent-values.yaml
mode: daemonset

presets:
  kubernetesAttributes:
    enabled: true
  kubeletMetrics:
    enabled: true

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
          max_recv_msg_size_mib: 16  # 대용량 배치 처리
        http:
          endpoint: 0.0.0.0:4318

    # Host 메트릭 수집
    hostmetrics:
      collection_interval: 30s
      scrapers:
        cpu:
        memory:
        disk:
        network:

  processors:
    # 메모리 보호
    memory_limiter:
      check_interval: 1s
      limit_mib: 400
      spike_limit_mib: 100

    # 배치 처리
    batch:
      timeout: 1s
      send_batch_size: 1024
      send_batch_max_size: 2048

    # K8s 메타데이터 추가
    k8sattributes:
      extract:
        metadata:
          - k8s.namespace.name
          - k8s.deployment.name
          - k8s.pod.name
          - k8s.node.name
      pod_association:
        - sources:
            - from: resource_attribute
              name: k8s.pod.ip

    # 리소스 속성 정리
    resource:
      attributes:
        - key: host.name
          from_attribute: k8s.node.name
          action: upsert

  exporters:
    otlp:
      endpoint: otel-gateway.observability:4317
      tls:
        insecure: true
      sending_queue:
        enabled: true
        num_consumers: 10
        queue_size: 10000
      retry_on_failure:
        enabled: true
        initial_interval: 5s
        max_interval: 30s
        max_elapsed_time: 300s

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, k8sattributes, resource, batch]
        exporters: [otlp]
      metrics:
        receivers: [otlp, hostmetrics]
        processors: [memory_limiter, k8sattributes, resource, batch]
        exporters: [otlp]
      logs:
        receivers: [otlp]
        processors: [memory_limiter, k8sattributes, resource, batch]
        exporters: [otlp]

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

# 각 노드에 배포
tolerations:
  - operator: Exists
```

---

## Gateway Collector (Deployment + HPA)

### Gateway 설정

```yaml
# otel-gateway-values.yaml
mode: deployment
replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
          max_recv_msg_size_mib: 32

  processors:
    memory_limiter:
      check_interval: 1s
      limit_mib: 1500
      spike_limit_mib: 400

    batch:
      timeout: 2s
      send_batch_size: 2048
      send_batch_max_size: 4096

    # CRITICAL: Tail-based Sampling
    tail_sampling:
      decision_wait: 10s
      num_traces: 100000
      expected_new_traces_per_sec: 10000
      policies:
        # 1. 에러는 100% 수집
        - name: error-policy
          type: status_code
          status_code:
            status_codes: [ERROR]

        # 2. 느린 요청은 100% 수집
        - name: latency-policy
          type: latency
          latency:
            threshold_ms: 1000

        # 3. 특정 서비스는 높은 비율
        - name: critical-service
          type: string_attribute
          string_attribute:
            key: service.name
            values: [payment-service, order-service]
            enabled_regex_matching: false
          sample_rate: 50  # 50%

        # 4. 나머지는 낮은 비율
        - name: probabilistic-policy
          type: probabilistic
          probabilistic:
            sampling_percentage: 5

    # 속성 필터링 (비용 절감)
    attributes:
      actions:
        # 불필요한 속성 제거
        - key: http.request.header.cookie
          action: delete
        - key: http.request.header.authorization
          action: delete
        - key: db.statement
          action: hash  # 민감 데이터 해싱

    # 스팬 필터링
    filter:
      error_mode: ignore
      traces:
        span:
          # health check 제외
          - 'attributes["http.route"] == "/health"'
          - 'attributes["http.route"] == "/ready"'
          - 'attributes["http.route"] == "/metrics"'

  exporters:
    otlp/tempo:
      endpoint: tempo-distributor.observability:4317
      tls:
        insecure: true
      sending_queue:
        enabled: true
        num_consumers: 20
        queue_size: 50000

    prometheusremotewrite:
      endpoint: http://prometheus.observability:9090/api/v1/write
      resource_to_telemetry_conversion:
        enabled: true

    loki:
      endpoint: http://loki-gateway.observability:3100/loki/api/v1/push

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, filter, tail_sampling, attributes, batch]
        exporters: [otlp/tempo]
      metrics:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [prometheusremotewrite]
      logs:
        receivers: [otlp]
        processors: [memory_limiter, attributes, batch]
        exporters: [loki]

resources:
  limits:
    cpu: 2
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

# Pod Anti-Affinity (분산 배치)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: otel-gateway
          topologyKey: kubernetes.io/hostname
```

---

## CRITICAL: Tail-based Sampling 설정

### 샘플링 정책 우선순위

```yaml
# 정책 평가 순서 (첫 매치 적용)
tail_sampling:
  policies:
    # 1순위: 에러 트레이스 (100%)
    - name: errors
      type: status_code
      status_code:
        status_codes: [ERROR]

    # 2순위: 느린 요청 (100%)
    - name: slow-requests
      type: latency
      latency:
        threshold_ms: 500

    # 3순위: 특정 작업 (100%)
    - name: important-operations
      type: string_attribute
      string_attribute:
        key: operation.name
        values:
          - checkout
          - payment
          - refund

    # 4순위: 복합 조건
    - name: composite-policy
      type: composite
      composite:
        max_total_spans_per_second: 1000
        policy_order: [errors, slow-requests, probabilistic]
        rate_allocation:
          - policy: errors
            percent: 50
          - policy: slow-requests
            percent: 30
          - policy: probabilistic
            percent: 20

    # 최종: 확률적 샘플링
    - name: probabilistic
      type: probabilistic
      probabilistic:
        sampling_percentage: 5
```

### Trace ID 기반 Load Balancing

```yaml
# Gateway 앞에 Load Balancer 설정 (Trace ID 해싱)
apiVersion: v1
kind: Service
metadata:
  name: otel-gateway-lb
  namespace: observability
  annotations:
    # AWS NLB
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 600  # Tail sampling decision_wait보다 길게
  ports:
    - port: 4317
      targetPort: 4317
      protocol: TCP
      name: otlp-grpc
  selector:
    app.kubernetes.io/name: otel-gateway
---
# 또는 Envoy로 Trace ID 기반 라우팅
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: otel-gateway
  namespace: observability
spec:
  host: otel-gateway
  trafficPolicy:
    loadBalancer:
      consistentHash:
        httpHeaderName: "traceparent"  # W3C Trace Context
```

---

## Kafka 버퍼 아키텍처

### 초대규모 트래픽용

```yaml
# Kafka exporter/receiver 설정
config:
  exporters:
    kafka:
      brokers:
        - kafka-0.kafka:9092
        - kafka-1.kafka:9092
        - kafka-2.kafka:9092
      topic: otel-traces
      encoding: otlp_proto
      producer:
        max_message_bytes: 10000000
        compression: zstd
        required_acks: 1  # 성능 우선
        flush_max_messages: 1000

  receivers:
    kafka:
      brokers:
        - kafka-0.kafka:9092
        - kafka-1.kafka:9092
        - kafka-2.kafka:9092
      topic: otel-traces
      encoding: otlp_proto
      group_id: otel-backend-consumer
      initial_offset: latest
```

### Kafka 토픽 설정

```bash
# 토픽 생성 (파티션 수 = Gateway 인스턴스 수의 배수)
kafka-topics.sh --create \
  --topic otel-traces \
  --partitions 30 \
  --replication-factor 3 \
  --config retention.ms=3600000 \
  --config compression.type=zstd \
  --config max.message.bytes=10485760
```

---

## 비용 최적화

### 데이터 볼륨 절감

```yaml
processors:
  # 1. 속성 필터링
  attributes:
    actions:
      # 큰 속성 제거
      - key: http.request.body
        action: delete
      - key: http.response.body
        action: delete
      # SQL 쿼리 잘라내기
      - key: db.statement
        action: truncate
        truncate:
          limit: 500

  # 2. 스팬 필터링
  filter:
    traces:
      span:
        # 내부 통신 제외
        - 'attributes["http.url"] contains "internal"'
        # 짧은 스팬 제외
        - 'duration < 1ms'

  # 3. 메트릭 집계
  metricstransform:
    transforms:
      - include: http.server.request.duration
        action: aggregate
        aggregation_type: histogram
        # 상세 라벨 제거
        label_set: [service.name, http.method, http.status_code]
```

### 비용 대비 가치

```
트래픽: 100K RPS 가정

샘플링 없음 (100%):
  - 일일 트레이스: ~8.6B spans
  - 저장 비용: ~$10,000/월 (Tempo Cloud 기준)

5% 샘플링:
  - 일일 트레이스: ~430M spans
  - 저장 비용: ~$500/월
  - 절감: 95%

Tail-based (에러/지연 100%, 나머지 5%):
  - 일일 트레이스: ~500M spans
  - 중요 이벤트 100% 보존
  - 저장 비용: ~$600/월
  - 가치: 높음 (문제 분석 가능)
```

---

## 모니터링 및 알림

### Collector 자체 메트릭

```yaml
# Collector 메트릭 활성화
service:
  telemetry:
    metrics:
      address: 0.0.0.0:8888
      level: detailed
    logs:
      level: info

# ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: otel-collector
  namespace: observability
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: otel-collector
  endpoints:
    - port: metrics
      interval: 30s
```

### 주요 알림 규칙

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: otel-collector-alerts
spec:
  groups:
    - name: otel-collector
      rules:
        # 큐 포화
        - alert: OTelCollectorQueueFull
          expr: |
            otelcol_exporter_queue_size / otelcol_exporter_queue_capacity > 0.8
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "OTel Collector queue is filling up"

        # 드롭된 데이터
        - alert: OTelCollectorDataDropped
          expr: |
            rate(otelcol_processor_dropped_spans[5m]) > 0
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "OTel Collector is dropping spans"

        # 메모리 압박
        - alert: OTelCollectorHighMemory
          expr: |
            container_memory_usage_bytes{container="otel-collector"}
            / container_spec_memory_limit_bytes > 0.85
          for: 5m
          labels:
            severity: warning

        # Export 실패
        - alert: OTelCollectorExportFailure
          expr: |
            rate(otelcol_exporter_send_failed_spans[5m]) > 0
          for: 5m
          labels:
            severity: critical
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| Gateway 단일 인스턴스 | SPOF + 병목 | HPA + Anti-affinity |
| Tail sampling 미사용 | 중요 트레이스 유실 | 에러/지연 100% 수집 |
| 무제한 queue_size | OOM | 적절한 제한 + 알림 |
| 모든 속성 전송 | 비용 폭증 | 속성 필터링 |
| 샘플링만 의존 | 희귀 에러 누락 | Error 트레이스 전체 수집 |
| 단일 Collector | 확장 불가 | Agent/Gateway 분리 |

---

## 체크리스트

### 아키텍처
- [ ] 트래픽 규모 파악
- [ ] Agent/Gateway 분리 (10K+ RPS)
- [ ] HPA 설정
- [ ] Pod Anti-affinity

### 샘플링
- [ ] Tail-based sampling 설정
- [ ] 에러/지연 트레이스 100%
- [ ] 확률적 샘플링 비율 결정

### 비용 최적화
- [ ] 불필요 속성 제거
- [ ] 스팬 필터링 (health check 등)
- [ ] 보존 기간 설정

### 모니터링
- [ ] Collector 메트릭 수집
- [ ] 알림 규칙 설정
- [ ] 큐 상태 모니터링

**관련 skill**: `/observability-otel`, `/monitoring-grafana`, `/ebpf-observability`, `/finops`

---

## Sources

- [OTel Collector Scaling](https://opentelemetry.io/docs/collector/scaling/)
- [Tail-based Sampling](https://opentelemetry.io/docs/collector/configuration/#tail-sampling-processor)
- [OTel Collector Helm Chart](https://github.com/open-telemetry/opentelemetry-helm-charts)
- [Grafana Tempo Scaling](https://grafana.com/docs/tempo/latest/operations/scaling/)
