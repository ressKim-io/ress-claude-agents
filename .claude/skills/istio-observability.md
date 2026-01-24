# Istio Observability Patterns

Istio 모니터링 통합: Sidecar vs Ambient 모드별 차이, Prometheus/Grafana/Kiali 연동

## Quick Reference

```
모니터링 설정
    │
    ├─ Sidecar Mode ─────────────────> Pod별 상세 메트릭
    │   └─ istio_requests_total (pod 레이블)
    │
    ├─ Ambient Mode ─────────────────> Node/Waypoint 레벨
    │   ├─ ztunnel: L4 메트릭만
    │   └─ waypoint: L7 메트릭 (배포 시)
    │
    ├─ 트레이싱 필수 ────────────────> Sidecar 또는 Waypoint
    │
    └─ 서비스 토폴로지 ──────────────> Kiali + Prometheus
```

---

## CRITICAL: 모드별 메트릭 수집 아키텍처

### Sidecar Mode

```
┌────────────────────────────────────────────────────────────────┐
│  Pod                                                           │
│  ┌─────────────┐    ┌─────────────┐                           │
│  │ Application │◄──►│   Envoy     │──► /stats/prometheus      │
│  └─────────────┘    │  (Sidecar)  │    :15020                 │
│                     └──────┬──────┘                           │
│                            │                                   │
│                            ▼                                   │
│                     Per-Pod 메트릭                             │
│                     - istio_requests_total                     │
│                     - istio_request_duration                   │
│                     - 자동 Span 생성                           │
└────────────────────────────────────────────────────────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  Prometheus  │
                     └──────────────┘
```

### Ambient Mode

```
┌────────────────────────────────────────────────────────────────┐
│  Node                                                          │
│  ┌─────────────┐                                               │
│  │   ztunnel   │──► /stats/prometheus                         │
│  │ (DaemonSet) │    - L4 메트릭만 (TCP 연결, 바이트)           │
│  └──────┬──────┘                                               │
│         │                                                      │
│  ┌──────▼──────┐    ┌─────────────┐                           │
│  │    Pod      │───►│  Waypoint   │──► L7 메트릭 (선택적)      │
│  │ (Sidecar無) │    │  (필요 시)  │    - istio_requests_total  │
│  └─────────────┘    └─────────────┘                           │
└────────────────────────────────────────────────────────────────┘
```

### 모드별 메트릭 비교

| 메트릭 | Sidecar | Ambient (ztunnel) | Ambient (waypoint) |
|--------|---------|-------------------|-------------------|
| `istio_requests_total` | Pod별 상세 | 미지원 | Service별 |
| `istio_request_duration_milliseconds` | Pod별 | 미지원 | Service별 |
| `istio_tcp_connections_opened_total` | Pod별 | Node별 | - |
| `istio_tcp_sent_bytes_total` | Pod별 | Node별 | - |
| 트레이싱 Span | 자동 생성 | L4만 | L7 Span |
| Access Log | Pod별 | ztunnel 로그 | waypoint 로그 |

---

## Prometheus 통합

### ServiceMonitor 설정

```yaml
# Sidecar Mode: Pod Envoy 메트릭 수집
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-sidecar-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      # Istio sidecar가 주입된 모든 Pod
      security.istio.io/tlsMode: istio
  namespaceSelector:
    any: true
  endpoints:
  - port: http-envoy-prom
    path: /stats/prometheus
    interval: 15s
---
# PodMonitor (ServiceMonitor 대안)
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: envoy-stats
  namespace: monitoring
spec:
  selector:
    matchExpressions:
    - key: security.istio.io/tlsMode
      operator: Exists
  namespaceSelector:
    any: true
  podMetricsEndpoints:
  - port: "15020"
    path: /stats/prometheus
    interval: 15s
```

```yaml
# Ambient Mode: ztunnel 메트릭 수집
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ztunnel-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: ztunnel
  namespaceSelector:
    matchNames:
    - istio-system
  endpoints:
  - port: http-monitoring
    path: /stats/prometheus
    interval: 15s
---
# Waypoint 메트릭 수집
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: waypoint-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      gateway.istio.io/managed: istio.io-mesh-controller
  namespaceSelector:
    any: true
  podMetricsEndpoints:
  - port: "15020"
    path: /stats/prometheus
    interval: 15s
```

### 주요 메트릭

```yaml
# RED 메트릭 (Rate, Errors, Duration)

# 1. Request Rate
sum(rate(istio_requests_total{reporter="destination"}[5m])) by (destination_service_name)

# 2. Error Rate
sum(rate(istio_requests_total{reporter="destination", response_code=~"5.*"}[5m]))
  /
sum(rate(istio_requests_total{reporter="destination"}[5m])) by (destination_service_name)

# 3. Latency (P99)
histogram_quantile(0.99,
  sum(rate(istio_request_duration_milliseconds_bucket{reporter="destination"}[5m]))
  by (destination_service_name, le)
)

# 4. TCP 연결 (Ambient ztunnel)
sum(rate(istio_tcp_connections_opened_total[5m])) by (reporter)
sum(rate(istio_tcp_sent_bytes_total[5m])) by (reporter)
```

### Istio 메트릭 커스터마이징

```yaml
# Telemetry API로 메트릭 제어
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-metrics
  namespace: istio-system
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    # 불필요한 레이블 제거 (카디널리티 감소)
    - match:
        metric: REQUEST_COUNT
      tagOverrides:
        request_protocol:
          operation: REMOVE
        destination_principal:
          operation: REMOVE
    # 히스토그램 버킷 조정
    - match:
        metric: REQUEST_DURATION
      tagOverrides:
        response_flags:
          operation: REMOVE
```

---

## Grafana 대시보드

### 권장 대시보드

```yaml
# 1. Istio Control Plane Dashboard
ID: 7645
용도: istiod 상태, xDS 동기화, 인증서 갱신

# 2. Istio Mesh Dashboard
ID: 7639
용도: 전체 메시 트래픽, 성공률, 지연시간

# 3. Istio Service Dashboard
ID: 7636
용도: 서비스별 상세 메트릭

# 4. Istio Workload Dashboard
ID: 7630
용도: Pod/Deployment별 메트릭

# 5. Istio Performance Dashboard
ID: 11829
용도: Envoy 리소스 사용량
```

### 대시보드 프로비저닝

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards-istio
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  istio-mesh.json: |
    {
      "annotations": {...},
      "title": "Istio Mesh Dashboard",
      "panels": [
        {
          "title": "Global Request Volume",
          "targets": [
            {
              "expr": "round(sum(rate(istio_requests_total{reporter=\"destination\"}[5m])), 0.001)"
            }
          ]
        },
        {
          "title": "Global Success Rate",
          "targets": [
            {
              "expr": "sum(rate(istio_requests_total{reporter=\"destination\", response_code!~\"5.*\"}[5m])) / sum(rate(istio_requests_total{reporter=\"destination\"}[5m]))"
            }
          ]
        }
      ]
    }
```

### Ambient Mode용 대시보드 조정

```yaml
# Ambient에서는 ztunnel 메트릭 추가
panels:
- title: "ztunnel TCP Connections"
  targets:
  - expr: "sum(rate(istio_tcp_connections_opened_total{app=\"ztunnel\"}[5m])) by (node)"

- title: "ztunnel Bytes Transferred"
  targets:
  - expr: "sum(rate(istio_tcp_sent_bytes_total{app=\"ztunnel\"}[5m])) by (node)"

# Waypoint 메트릭 (L7)
- title: "Waypoint Request Rate"
  targets:
  - expr: "sum(rate(istio_requests_total{app=\"waypoint\"}[5m])) by (destination_service_name)"
```

---

## Kiali

### 설치 및 설정

```yaml
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali
  namespace: istio-system
spec:
  auth:
    strategy: anonymous  # 또는 openid, token
  deployment:
    accessible_namespaces:
    - "**"  # 모든 namespace
  external_services:
    prometheus:
      url: "http://prometheus.monitoring:9090"
    grafana:
      enabled: true
      url: "http://grafana.monitoring:3000"
    tracing:
      enabled: true
      url: "http://jaeger-query.tracing:16686"
```

### 서비스 토폴로지 활용

```yaml
# Kiali 기능
- Service Graph: 실시간 트래픽 흐름 시각화
- Traffic Animation: 요청 흐름 애니메이션
- Health Status: 서비스 상태 (정상/경고/오류)
- Metrics: 서비스별 RED 메트릭
- Traces: 분산 트레이싱 연동
- Istio Config: 설정 검증 및 편집
```

### Ambient Mode 지원 현황 (2026.01)

```yaml
# Kiali Ambient 지원
Kiali 1.80+: Ambient Mode 기본 지원

제한사항:
- ztunnel 기반 그래프: L4 연결만 표시
- waypoint 없는 서비스: L7 상세 정보 없음
- 트레이싱: waypoint 배포 시에만

권장:
- L7 시각화 필요 시 waypoint 배포
- ztunnel 메트릭으로 기본 연결 확인
```

---

## 분산 트레이싱 (Jaeger/Tempo)

### 모드별 Span 생성 차이

```yaml
# Sidecar Mode
- 자동 Span 생성 (Envoy에서)
- 요청/응답 헤더 자동 전파
- Pod 레벨 상세 트레이스

# Ambient Mode
- ztunnel: L4만 (Span 없음)
- waypoint: L7 Span 생성
- 앱에서 직접 Span 생성 권장
```

### Jaeger 연동

```yaml
# Telemetry 설정
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-tracing
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: jaeger
    randomSamplingPercentage: 1.0  # 1% 샘플링
    customTags:
      environment:
        literal:
          value: production
---
# MeshConfig (IstioOperator)
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      tracing:
        sampling: 1.0  # 1%
        zipkin:
          address: jaeger-collector.tracing:9411
    extensionProviders:
    - name: jaeger
      zipkin:
        service: jaeger-collector.tracing.svc.cluster.local
        port: 9411
```

### Tempo 연동 (Grafana Stack)

```yaml
# OTel Collector → Tempo
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: otel-tracing
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: otel
    randomSamplingPercentage: 1.0
---
# IstioOperator extensionProvider
spec:
  meshConfig:
    extensionProviders:
    - name: otel
      opentelemetry:
        service: otel-collector.monitoring.svc.cluster.local
        port: 4317
```

### Ambient Mode에서 트레이싱

```yaml
# 앱 레벨 계측 권장 (Ambient)
# OpenTelemetry SDK 직접 사용

# Java (Spring Boot)
dependencies:
  - io.opentelemetry:opentelemetry-api
  - io.opentelemetry.instrumentation:opentelemetry-spring-boot-starter

# Go
import "go.opentelemetry.io/otel"

# waypoint 배포 시 L7 Span 추가됨
```

---

## Access Logging

### Sidecar Mode

```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: access-logging
  namespace: istio-system
spec:
  accessLogging:
  - providers:
    - name: envoy
    filter:
      expression: "response.code >= 400"  # 에러만
---
# 전체 로그 (개발용)
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: full-access-log
  namespace: development
spec:
  accessLogging:
  - providers:
    - name: envoy
```

### Ambient Mode

```yaml
# ztunnel 로그 확인
kubectl logs -n istio-system -l app=ztunnel -f

# waypoint 로그 확인
kubectl logs -n production -l gateway.istio.io/managed -f

# 로그 포맷 커스터마이징 (IstioOperator)
meshConfig:
  accessLogFile: /dev/stdout
  accessLogFormat: |
    [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%"
    %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT%
    %DURATION% "%REQ(X-FORWARDED-FOR)%" "%REQ(USER-AGENT)%"
```

---

## OTel Collector 연동

```yaml
# Istio → OTel Collector → 백엔드
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: monitoring
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
      prometheus:
        config:
          scrape_configs:
          - job_name: 'istio-envoy'
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true

    processors:
      batch:
        timeout: 10s

    exporters:
      prometheus:
        endpoint: 0.0.0.0:8889
      otlp/tempo:
        endpoint: tempo.monitoring:4317
        tls:
          insecure: true

    service:
      pipelines:
        metrics:
          receivers: [prometheus]
          processors: [batch]
          exporters: [prometheus]
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [otlp/tempo]
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| Ambient에서 Pod별 메트릭 기대 | 불가능 | ztunnel/waypoint 메트릭 사용 |
| 높은 샘플링 비율 (100%) | 스토리지 폭증 | 1-5%로 조정 |
| 모든 레이블 유지 | 카디널리티 폭발 | Telemetry로 레이블 제거 |
| Access Log 전체 활성화 | 성능 저하 | 필터링 적용 |
| Kiali 없이 Ambient | 디버깅 어려움 | Kiali 1.80+ 설치 |

---

## 체크리스트

### Prometheus
- [ ] ServiceMonitor/PodMonitor 설정
- [ ] 스크래핑 간격 조정 (15-30s)
- [ ] 레이블 카디널리티 관리

### Grafana
- [ ] Istio 대시보드 설치
- [ ] Ambient용 대시보드 조정
- [ ] 알림 규칙 설정

### Kiali
- [ ] Prometheus/Grafana/Jaeger 연동
- [ ] Ambient 지원 버전 확인
- [ ] 접근 권한 설정

### 트레이싱
- [ ] 샘플링 비율 설정
- [ ] Ambient 시 앱 계측 추가
- [ ] 헤더 전파 확인

### Ambient 전환 시
- [ ] 기존 대시보드 호환성 검토
- [ ] ztunnel 메트릭 추가
- [ ] waypoint 메트릭 추가 (L7용)

**관련 skill**: `/istio-core`, `/istio-gateway`, `/observability-otel`, `/monitoring-grafana`
