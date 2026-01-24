# OpenTelemetry Patterns

Spring Boot, Go를 위한 OpenTelemetry 설정 및 Collector 구성

## Quick Reference

```
OTel 설정
    │
    ├─ Spring Boot ────> spring-boot-starter-opentelemetry
    │
    ├─ Go ─────────────> go.opentelemetry.io/otel
    │
    └─ Collector ──────> Tempo(traces) + Loki(logs) + Prometheus(metrics)
```

---

## Spring Boot 설정

### 의존성

```groovy
// Spring Boot 4
implementation 'org.springframework.boot:spring-boot-starter-opentelemetry'

// Spring Boot 3
implementation 'io.opentelemetry.instrumentation:opentelemetry-spring-boot-starter'
```

### 설정

```yaml
spring:
  application:
    name: order-service

otel:
  exporter:
    otlp:
      endpoint: http://otel-collector:4317
  resource:
    attributes:
      service.name: order-service
      service.version: 1.0.0
      deployment.environment: production

logging:
  pattern:
    console: "%d [%X{traceId}/%X{spanId}] %-5level %logger{36} - %msg%n"
```

### 자동 계측 (150+ 라이브러리)

- Spring MVC/WebFlux
- JDBC, JPA, Hibernate
- Kafka, RabbitMQ
- RestTemplate, WebClient
- Redis, MongoDB

---

## Go 설정

### 의존성

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    "go.opentelemetry.io/otel/sdk/trace"
    "go.opentelemetry.io/otel/sdk/resource"
    semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)
```

### 초기화

```go
func initTracer(ctx context.Context) (*trace.TracerProvider, error) {
    exporter, err := otlptracehttp.New(ctx,
        otlptracehttp.WithEndpoint("otel-collector:4318"),
        otlptracehttp.WithInsecure(),
    )
    if err != nil {
        return nil, err
    }

    res := resource.NewWithAttributes(
        semconv.SchemaURL,
        semconv.ServiceName("order-service"),
        semconv.ServiceVersion("1.0.0"),
        semconv.DeploymentEnvironment("production"),
    )

    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(res),
        trace.WithSampler(trace.TraceIDRatioBased(0.1)), // 10% 샘플링
    )

    otel.SetTracerProvider(tp)
    return tp, nil
}
```

### HTTP 미들웨어 (Gin)

```go
import "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"

r := gin.New()
r.Use(otelgin.Middleware("order-service"))
```

### 커스텀 Span

```go
func ProcessOrder(ctx context.Context, orderID string) error {
    tracer := otel.Tracer("order-service")
    ctx, span := tracer.Start(ctx, "ProcessOrder")
    defer span.End()

    span.SetAttributes(
        attribute.String("order.id", orderID),
        attribute.Int("order.items", 5),
    )

    // 중첩 span
    ctx, childSpan := tracer.Start(ctx, "ValidateStock")
    err := validateStock(ctx, orderID)
    childSpan.End()

    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return err
    }

    return nil
}
```

---

## Collector 설정

### Docker Compose (Grafana LGTM Stack)

```yaml
version: '3.8'
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.115.0  # 2024.12 기준
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP

  tempo:
    image: grafana/tempo:latest
    # 트레이스 저장

  loki:
    image: grafana/loki:latest
    # 로그 저장

  prometheus:
    image: prom/prometheus:latest
    # 메트릭 저장

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
```

### Collector Config

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

exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
  prometheus:
    endpoint: 0.0.0.0:8889

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/tempo]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [loki]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

---

## 샘플링 전략

| 환경 | 샘플링 비율 | 이유 |
|------|------------|------|
| 개발 | 100% | 전체 디버깅 |
| 스테이징 | 50% | 중간 수준 |
| 프로덕션 | 10-20% | 비용 최적화 |

```go
// 부모 기반 + 비율
trace.WithSampler(
    trace.ParentBased(trace.TraceIDRatioBased(0.1)),
)
```

---

## Collector 버전 관리

```yaml
# 권장: 특정 버전 명시 (latest 지양)
otel-collector:
  image: otel/opentelemetry-collector-contrib:0.115.0

# 업그레이드 가이드: https://github.com/open-telemetry/opentelemetry-collector/releases
# Breaking changes 확인 후 업그레이드
```

| 버전 | 주요 변경 |
|------|----------|
| 0.100+ | Log body 구조 변경 |
| 0.90+ | metrics.exporters 설정 변경 |
| 0.80+ | processor 순서 중요도 증가 |

---

## 2026 트렌드: 차세대 관측성

### eBPF 기반 모니터링

```
전통적 계측          eBPF 기반
────────────        ────────────
SDK 추가 필요        무침투적 (코드 변경 없음)
런타임 오버헤드       커널 레벨에서 효율적 수집
언어별 설정          언어 독립적
```

**대표 도구**: Coroot, Pixie, Cilium Hubble

### 통합 Observability 스택 트렌드

```
기존: Prometheus + Loki + Tempo (별도 운영)
트렌드: Grafana Cloud / ClickHouse 기반 통합 스택
```

---

## 체크리스트

### SDK 설정
- [ ] OTel SDK 의존성 추가
- [ ] 서비스 리소스 속성 설정
- [ ] 샘플링 비율 설정

### Collector
- [ ] Collector 배포 (버전 명시)
- [ ] 파이프라인 구성 (traces/logs/metrics)
- [ ] 백엔드 연결 (Tempo/Loki/Prometheus)

### 모니터링
- [ ] Grafana 대시보드 구성
- [ ] 알림 규칙 설정

**관련 skill**: `/monitoring-grafana`, `/monitoring-metrics`, `/monitoring-logs`
