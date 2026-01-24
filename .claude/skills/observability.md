# Observability Patterns

로깅, 트레이싱, 메트릭을 위한 OpenTelemetry 기반 패턴

## 3 Pillars of Observability

| Pillar | 목적 | 질문 |
|--------|------|------|
| **Logs** | 이벤트 기록 | "무슨 일이 일어났나?" |
| **Traces** | 요청 흐름 추적 | "어디서 느려졌나?" |
| **Metrics** | 수치 측정 | "얼마나 많이/빠르게?" |

---

## 구조화된 로깅

### JSON 로그 포맷

```json
{
  "timestamp": "2025-01-24T10:30:00Z",
  "level": "error",
  "message": "Failed to process order",
  "service": "order-service",
  "trace_id": "abc123def456",
  "span_id": "789xyz",
  "user_id": 42,
  "order_id": "ORD-001",
  "error": "insufficient stock",
  "duration_ms": 150
}
```

### 로그 레벨 가이드

| Level | 사용 시점 | 프로덕션 |
|-------|----------|----------|
| `ERROR` | 즉시 조치 필요 | ✅ |
| `WARN` | 잠재적 문제 | ✅ |
| `INFO` | 주요 비즈니스 이벤트 | ✅ |
| `DEBUG` | 개발/디버깅용 | ❌ (필요시만) |
| `TRACE` | 상세 흐름 | ❌ |

### 필수 컨텍스트

```
✅ 포함해야 할 것:
- trace_id, span_id (분산 추적)
- user_id, request_id (요청 식별)
- service, version (서비스 식별)
- duration_ms (성능)
- error code/message (에러 시)

❌ 제외해야 할 것:
- 비밀번호, 토큰
- 개인정보 (이메일, 전화번호)
- 전체 요청/응답 바디 (요약만)
```

---

## OpenTelemetry 설정

### Spring Boot 3/4

**의존성**
```groovy
// Spring Boot 4
implementation 'org.springframework.boot:spring-boot-starter-opentelemetry'

// Spring Boot 3
implementation 'io.opentelemetry.instrumentation:opentelemetry-spring-boot-starter'
```

**설정**
```yaml
# application.yml
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
    console: "%d{yyyy-MM-dd HH:mm:ss} [%X{traceId}/%X{spanId}] %-5level %logger{36} - %msg%n"
```

**자동 계측 (150+ 라이브러리)**
- Spring MVC/WebFlux
- JDBC, JPA, Hibernate
- Kafka, RabbitMQ
- RestTemplate, WebClient
- Redis, MongoDB

### Go

**의존성**
```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    "go.opentelemetry.io/otel/sdk/trace"
    "go.opentelemetry.io/otel/sdk/resource"
    semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)
```

**초기화**
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

**HTTP 미들웨어 (Gin)**
```go
import "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"

r := gin.New()
r.Use(otelgin.Middleware("order-service"))
```

**커스텀 Span**
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

## Context Propagation

### HTTP 헤더

```
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
tracestate: congo=t61rcWkgMzE

W3C Trace Context 형식:
- trace_id: 0af7651916cd43dd8448eb211c80319c
- span_id: b7ad6b7169203331
- flags: 01 (sampled)
```

### 로그에 trace_id 주입

**Spring Boot (Logback)**
```xml
<!-- logback-spring.xml -->
<encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <includeMdcKeyName>traceId</includeMdcKeyName>
    <includeMdcKeyName>spanId</includeMdcKeyName>
</encoder>
```

**Go (zerolog)**
```go
func LoggerMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        span := trace.SpanFromContext(c.Request.Context())
        traceID := span.SpanContext().TraceID().String()
        spanID := span.SpanContext().SpanID().String()

        logger := zerolog.Ctx(c.Request.Context()).With().
            Str("trace_id", traceID).
            Str("span_id", spanID).
            Logger()

        c.Request = c.Request.WithContext(logger.WithContext(c.Request.Context()))
        c.Next()
    }
}
```

---

## 메트릭

### RED Method

| 메트릭 | 설명 | 예시 |
|--------|------|------|
| **R**ate | 요청 수/초 | `http_requests_total` |
| **E**rrors | 에러율 | `http_errors_total / http_requests_total` |
| **D**uration | 응답 시간 | `http_request_duration_seconds` |

### Spring Boot Actuator

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,prometheus,metrics
  metrics:
    tags:
      application: ${spring.application.name}
```

```java
@RestController
@RequiredArgsConstructor
public class OrderController {
    private final MeterRegistry meterRegistry;

    @PostMapping("/orders")
    public Order createOrder(@RequestBody OrderRequest request) {
        Timer.Sample sample = Timer.start(meterRegistry);
        try {
            Order order = orderService.create(request);
            meterRegistry.counter("orders.created",
                "status", "success",
                "type", request.getType()
            ).increment();
            return order;
        } catch (Exception e) {
            meterRegistry.counter("orders.created",
                "status", "error",
                "error", e.getClass().getSimpleName()
            ).increment();
            throw e;
        } finally {
            sample.stop(meterRegistry.timer("orders.create.duration"));
        }
    }
}
```

### Go Prometheus

```go
import "github.com/prometheus/client_golang/prometheus"

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "path", "status"},
    )

    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal, httpRequestDuration)
}
```

---

## Collector 설정

### Docker Compose (Grafana LGTM)

```yaml
version: '3.8'
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
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

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| trace_id 없는 로그 | 분산 추적 불가 | OTel 자동 주입 |
| 전체 payload 로깅 | 로그 폭발 | ID/상태만 기록 |
| 100% 샘플링 | 비용 폭발 | 프로덕션 10-20% |
| 문자열 로그만 | 검색 어려움 | 구조화 JSON |
| 민감정보 로깅 | 보안 위험 | 마스킹 필터 |

---

## 체크리스트

### 로깅
- [ ] JSON 구조화 로깅 설정
- [ ] 로그 레벨 적절히 사용
- [ ] 민감정보 마스킹

### OpenTelemetry
- [ ] OTel SDK/Agent 설정
- [ ] trace_id 로그 연동
- [ ] 샘플링 비율 설정
- [ ] Collector 배포

### 메트릭
- [ ] RED 메트릭 수집
- [ ] 커스텀 비즈니스 메트릭
- [ ] 알림 규칙 설정

### 인프라
- [ ] Grafana 대시보드
- [ ] 로그 보관 정책
- [ ] 알림 채널 설정
