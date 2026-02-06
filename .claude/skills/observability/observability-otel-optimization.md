# OpenTelemetry 비용 최적화 가이드

Kafka 버퍼 아키텍처, 데이터 볼륨 절감, Collector 모니터링 & 알림

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

## Sources

- [OTel Collector Scaling](https://opentelemetry.io/docs/collector/scaling/)
- [Tail-based Sampling](https://opentelemetry.io/docs/collector/configuration/#tail-sampling-processor)
- [OTel Collector Helm Chart](https://github.com/open-telemetry/opentelemetry-helm-charts)
- [Grafana Tempo Scaling](https://grafana.com/docs/tempo/latest/operations/scaling/)

## 참조 스킬

- `/observability-otel-scale` - 대규모 트래픽 OTel 아키텍처, 샘플링 전략
- `/observability-otel` - OTel 기본 설정
- `/monitoring-grafana` - Grafana 모니터링
- `/finops` - FinOps 기초
