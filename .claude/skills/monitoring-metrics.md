# Metrics Monitoring Patterns

Prometheus 스케일링, Thanos, VictoriaMetrics 설정 가이드

## Quick Reference (결정 트리)
```
클러스터 수?
    ├─ 1-5개 ────> Prometheus Federation (단순)
    ├─ 5-50개 ───> Thanos (S3 저장, 쿼리 통합)
    └─ 50+개 ────> VictoriaMetrics (고성능, 비용 효율)

일일 데이터 포인트?
    ├─ < 10M ────> 단일 Prometheus
    ├─ 10M-100M ─> Thanos
    └─ > 100M ───> VictoriaMetrics Cluster
```

---

## CRITICAL: 스케일링 솔루션 비교

| 항목 | Federation | Thanos | VictoriaMetrics |
|------|------------|--------|-----------------|
| 복잡도 | 낮음 | 중간 | 중간 |
| 장기 저장 | 제한적 | S3/GCS | 로컬/S3 |
| 쿼리 성능 | 단일 | 분산 | 고성능 |
| HA | 별도 구성 | 내장 | 내장 |
| 권장 규모 | 소규모 | 중-대 | 모든 규모 |

```
비용 우선 + 대규모 ────> VictoriaMetrics
AWS/GCP 네이티브 ─────> Thanos + S3/GCS
단순함 우선 ──────────> Prometheus Federation
```

---

## Thanos 설정

### 아키텍처
```
┌────────────┐    ┌────────────┐
│Prometheus  │    │Prometheus  │
│ + Sidecar  │    │ + Sidecar  │
└─────┬──────┘    └─────┬──────┘
      └────────┬────────┘
               ▼
        ┌────────────┐
        │  Thanos    │◄── Grafana
        │  Query     │
        └─────┬──────┘
              ▼
     ┌────────────────┐
     │ Store/Compact  │──> S3
     └────────────────┘
```

### Helm 배포
```yaml
thanos:
  query:
    enabled: true
    replicaCount: 2
    stores:
      - dnssrv+_grpc._tcp.prometheus-operated.monitoring.svc
  storegateway:
    enabled: true
    persistence:
      size: 8Gi
  compactor:
    enabled: true
    retentionResolutionRaw: 30d
    retentionResolution5m: 90d
    retentionResolution1h: 1y
  objstoreConfig: |-
    type: S3
    config:
      bucket: thanos-metrics
      region: ap-northeast-2
```

### Prometheus Sidecar
```yaml
prometheus:
  prometheusSpec:
    thanos:
      objectStorageConfig:
        name: thanos-objstore-secret
        key: objstore.yml
    externalLabels:
      cluster: production
```

---

## VictoriaMetrics 설정

### 클러스터 아키텍처
```
              ┌──────────┐
              │vmselect  │◄── Grafana
              └────┬─────┘
     ┌─────────────┼─────────────┐
     ▼             ▼             ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│vmstorage│  │vmstorage│  │vmstorage│
└─────────┘  └─────────┘  └─────────┘
     ▲             ▲             ▲
     └─────────────┼─────────────┘
              ┌────┴─────┐
              │vminsert  │◄── Prometheus/OTel
              └──────────┘
```

### Helm 배포
```yaml
victoria-metrics-cluster:
  vmselect:
    replicaCount: 2
  vminsert:
    replicaCount: 2
    extraArgs:
      replicationFactor: 2
  vmstorage:
    replicaCount: 3
    persistentVolume:
      size: 50Gi
      storageClass: gp3
    retentionPeriod: 6  # 6개월
    extraArgs:
      dedup.minScrapeInterval: 15s
      downsampling.period: 30d:5m,90d:1h  # 비용 최적화
```

---

## OTel → Prometheus 메트릭

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    timeout: 10s
  transform:
    metric_statements:
      - context: datapoint
        statements:
          - set(attributes["exported_job"], attributes["job"])

exporters:
  prometheusremotewrite:
    endpoint: http://vminsert:8480/insert/0/prometheus/api/v1/write

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [batch, transform]
      exporters: [prometheusremotewrite]
```

---

## Cardinality 관리

### CRITICAL: High Cardinality 방지
```
❌ BAD
http_requests_total{user_id="123", request_id="abc"}

✅ GOOD
http_requests_total{method="GET", status="200", path="/api/orders"}
```

### 레이블 가이드
| 레이블 | 권장 | 이유 |
|--------|------|------|
| user_id | ❌ | 무한 증가 |
| request_id | ❌ | 무한 증가 |
| status_code | ✅ | ~10개 값 |
| method | ✅ | ~5개 값 |

### Prometheus Relabeling
```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'go_.*'
    action: drop
  - source_labels: [path]
    regex: '/api/v1/users/[0-9]+'
    target_label: path
    replacement: '/api/v1/users/:id'
```

### 카디널리티 모니터링
```promql
# 상위 10개 high cardinality 메트릭
topk(10, count by (__name__) ({__name__=~".+"}))

# 레이블별 고유 값 수
count(count by (endpoint) (http_requests_total))
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| user_id 레이블 | 카디널리티 폭발 | 로그로 이동 |
| 100% 데이터 보관 | 스토리지 비용 | 다운샘플링 |
| 단일 Prometheus | SPOF | HA/Thanos |
| 모든 메트릭 수집 | 비용, 성능 | 필요한 것만 |
| 짧은 scrape interval | 부하 증가 | 15-30초 |

---

## 체크리스트

### 스케일링
- [ ] 규모에 맞는 솔루션 선택
- [ ] HA 구성 (2+ 레플리카)
- [ ] 장기 저장소 설정

### Cardinality
- [ ] 레이블 가이드라인 수립
- [ ] 모니터링 쿼리 설정
- [ ] Relabeling 설정

### 성능
- [ ] scrape interval 15-30s
- [ ] 다운샘플링 설정

**관련 skill**: `/observability`, `/observability-otel`, `/monitoring-grafana`
