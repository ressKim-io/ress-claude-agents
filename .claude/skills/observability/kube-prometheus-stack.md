# kube-prometheus-stack 가이드

Helm chart 설치, values 커스터마이징, Phase별 환경 overlay, ArgoCD 통합

## Quick Reference (결정 트리)

```
kube-prometheus-stack 설정?
    │
    ├─ 설치 방식 ──────────> ArgoCD Application (권장)
    │
    ├─ 환경별 설정 ────────> values overlay
    │     │
    │     ├─ dev (kind) ────> 최소 리소스, 단기 retention
    │     ├─ staging ───────> 중간 리소스, 7일 retention
    │     └─ prod ──────────> HA, 30일+ retention, Thanos
    │
    ├─ 스케일링 ───────────> Prometheus replicas or Thanos
    │     │
    │     ├─ 단일 클러스터 ─> Prometheus HA (2 replicas)
    │     └─ 멀티 클러스터 ─> Thanos or VictoriaMetrics
    │
    └─ 알림 채널 ──────────> AlertManager config
          │
          ├─ dev ───────────> Discord/Slack
          └─ prod ──────────> PagerDuty + Slack
```

---

## 설치 (ArgoCD Application)

### Multi-source 패턴 (chart + values 분리)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"     # 앱보다 먼저 설치
spec:
  project: monitoring
  sources:
    - repoURL: https://prometheus-community.github.io/helm-charts
      chart: kube-prometheus-stack
      targetRevision: "65.1.0"              # 버전 고정
      helm:
        valueFiles:
          - $values/monitoring/kube-prometheus-stack/values.yaml
          - $values/monitoring/kube-prometheus-stack/values-prod.yaml
    - repoURL: https://github.com/my-org/k8s-config.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true              # CRD가 크므로 SSA 필수
      - Replace=true                       # CRD 업데이트 시
```

### ServerSideApply가 필요한 이유

```
kube-prometheus-stack CRD는 매우 큼 (PrometheusRule 등).
기본 kubectl apply는 annotation 크기 제한에 걸림.
→ ServerSideApply=true로 해결.
```

---

## Values 커스터마이징

### 기본 values.yaml (모든 환경 공통)

```yaml
# monitoring/kube-prometheus-stack/values.yaml

# --- Prometheus ---
prometheus:
  prometheusSpec:
    retention: 2d                          # 환경별 override
    retentionSize: "5GB"
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: "1"
        memory: 2Gi
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard       # 환경별 override
          resources:
            requests:
              storage: 10Gi               # 환경별 override
    # ServiceMonitor 자동 탐색
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false

# --- Grafana ---
grafana:
  enabled: true
  adminPassword: ""                        # ESO로 주입
  persistence:
    enabled: true
    size: 5Gi
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://kube-prometheus-stack-prometheus:9090
          isDefault: true
        - name: Loki
          type: loki
          url: http://loki:3100
          jsonData:
            derivedFields:
              - datasourceUid: tempo
                matcherRegex: "traceID=(\\w+)"
                name: TraceID
                url: "$${__value.raw}"
        - name: Tempo
          type: tempo
          uid: tempo
          url: http://tempo:3100

# --- AlertManager ---
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        cpu: 50m
        memory: 64Mi

# --- Node Exporter ---
nodeExporter:
  enabled: true

# --- kube-state-metrics ---
kubeStateMetrics:
  enabled: true

# --- 기본 알림 룰 ---
defaultRules:
  create: true
  rules:
    etcd: false                            # managed K8s에서는 비활성화
    kubeScheduler: false                   # managed K8s에서는 접근 불가
    kubeControllerManager: false
```

### values-dev.yaml (kind 환경)

```yaml
prometheus:
  prometheusSpec:
    retention: 2h
    retentionSize: "1GB"
    replicas: 1
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          resources:
            requests:
              storage: 5Gi

grafana:
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
  persistence:
    size: 1Gi

alertmanager:
  config:
    route:
      receiver: discord-dev
      group_wait: 30s
      group_interval: 5m
    receivers:
      - name: discord-dev
        discord_configs:
          - webhook_url_file: /etc/alertmanager/secrets/discord-webhook
```

### values-prod.yaml (EKS/GKE)

```yaml
prometheus:
  prometheusSpec:
    retention: 30d
    retentionSize: "50GB"
    replicas: 2                           # HA
    resources:
      requests:
        cpu: "1"
        memory: 4Gi
      limits:
        cpu: "4"
        memory: 8Gi
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3           # EKS: gp3, GKE: pd-ssd
          resources:
            requests:
              storage: 100Gi
    # Thanos sidecar (멀티 클러스터 or 장기 보관)
    thanos:
      image: quay.io/thanos/thanos:v0.36.1
      objectStorageConfig:
        existingSecret:
          name: thanos-objstore-config
          key: config.yaml

grafana:
  replicas: 2
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
  persistence:
    size: 10Gi
  ingress:
    enabled: true
    ingressClassName: alb                 # EKS: alb, GKE: gce
    annotations:
      alb.ingress.kubernetes.io/scheme: internal
    hosts:
      - grafana.internal.example.com

alertmanager:
  alertmanagerSpec:
    replicas: 3                           # HA
  config:
    route:
      receiver: pagerduty-critical
      group_wait: 10s
      group_interval: 1m
      routes:
        - receiver: pagerduty-critical
          matchers:
            - severity = critical
        - receiver: slack-warning
          matchers:
            - severity = warning
    receivers:
      - name: pagerduty-critical
        pagerduty_configs:
          - service_key_file: /etc/alertmanager/secrets/pagerduty-key
      - name: slack-warning
        slack_configs:
          - api_url_file: /etc/alertmanager/secrets/slack-webhook
            channel: "#alerts-warning"
```

---

## Phase별 설정 진화

```
Phase 0 (docker-compose):
  → docker run prom/prometheus (단독 실행)
  → 설정 파일: prometheus.yml만

Phase 1 (kind):
  → kube-prometheus-stack (values-dev.yaml)
  → Prometheus 1 replica, retention 2h
  → Grafana 기본 대시보드
  → AlertManager → Discord

Phase 2 (staging):
  → kube-prometheus-stack (values-staging.yaml)
  → Prometheus 1 replica, retention 7d
  → ServiceMonitor 추가 (앱 메트릭)
  → AlertManager → Slack

Phase 3 (EKS/GKE prod):
  → kube-prometheus-stack (values-prod.yaml)
  → Prometheus 2 replica (HA) + Thanos sidecar
  → 장기 보관: S3/GCS → Thanos Store
  → AlertManager → PagerDuty + Slack
  → Grafana HA (2 replicas) + Ingress
```

### kind → EKS/GKE 전환 시 바뀌는 것

| 항목 | kind | EKS/GKE |
|------|------|---------|
| StorageClass | `standard` | `gp3` / `pd-ssd` |
| Retention | `2h` | `30d` |
| Storage Size | `5Gi` | `100Gi` |
| Prometheus replicas | 1 | 2 (HA) |
| Thanos | 비활성화 | 활성화 (S3/GCS) |
| AlertManager | Discord | PagerDuty + Slack |
| Grafana Ingress | NodePort | ALB / GCE LB |
| etcd rules | false | false (managed) |
| Node resources | 최소 | 충분한 request/limit |

---

## EKS vs GKE 전용 설정

### EKS

```yaml
# values-eks.yaml (prod overlay에 추가)
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3

grafana:
  ingress:
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internal
      alb.ingress.kubernetes.io/target-type: ip

# Thanos S3 backend
  thanos:
    objectStorageConfig:
      # Secret에 S3 bucket 설정 포함
```

### GKE

```yaml
# values-gke.yaml (prod overlay에 추가)
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: pd-ssd

grafana:
  ingress:
    ingressClassName: gce
    annotations:
      kubernetes.io/ingress.class: gce-internal

# Thanos GCS backend
  thanos:
    objectStorageConfig:
      # Secret에 GCS bucket 설정 포함

# GMP (Google Managed Prometheus) 대안
# GKE에서는 managed service로 대체 가능
# 하지만 kube-prometheus-stack이 더 유연함
```

---

## 트러블슈팅

### CRD 크기 제한 에러

```
error: metadata.annotations too long
→ 해결: syncOptions에 ServerSideApply=true 추가
```

### ServiceMonitor가 안 잡히는 경우

```yaml
# Prometheus가 모든 namespace의 ServiceMonitor를 탐색하도록
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false    # false로 설정!
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    # 또는 특정 label만 탐색
    serviceMonitorSelector:
      matchLabels:
        monitoring: "true"
```

### ArgoCD OutOfSync 반복

```yaml
# kube-prometheus-stack는 동적으로 변하는 필드가 많음
spec:
  ignoreDifferences:
    - group: admissionregistration.k8s.io
      kind: MutatingWebhookConfiguration
      jsonPointers:
        - /webhooks/0/clientConfig/caBundle
    - group: admissionregistration.k8s.io
      kind: ValidatingWebhookConfiguration
      jsonPointers:
        - /webhooks/0/clientConfig/caBundle
```

### Apdex 계산 시 OTel 히스토그램 버킷 주의

OTel SDK 기본 explicit bucket boundaries에 `le="2.0"` 없음. Apdex 4T 계산 시 `le="2.5"` 사용.

```
OTel 기본 버킷 (초): 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0
                                                                                          ↑ 2.0 없음, 2.5 사용
```

```promql
# Apdex (T=0.5s): satisfied ≤ 0.5s, tolerating ≤ 4T=2.0s → le="2.5" 사용
(
  sum(rate(http_server_request_duration_seconds_bucket{le="0.5"}[5m]))
  + sum(rate(http_server_request_duration_seconds_bucket{le="2.5"}[5m]))
) / 2
/ (sum(rate(http_server_request_duration_seconds_count[5m])) > 0)
```

정확한 2.0s 경계가 필요하면 OTel SDK View에서 커스텀 버킷 설정:
```yaml
# application.yml (Spring Boot OTel)
otel:
  metrics:
    views:
      - instrument_name: http.server.request.duration
        histogram:
          bucket_boundaries: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 2.5, 5.0, 10.0]
```

### PrometheusRule CRD 라벨 필수

PrometheusRule 리소스에 `app.kubernetes.io/part-of: {project}-monitoring` 라벨이 없으면 Mimir ruler selector에 매칭되지 않아 **rule이 로드되지 않는다** (silent failure).

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: example-recording-rules
  namespace: monitoring
  labels:
    app.kubernetes.io/part-of: {project}-monitoring  # ← 필수. 누락 시 Mimir에서 무시
spec:
  groups:
    - name: example-sli
      rules:
        - record: example:sli:availability:5m
          expr: ...
```

**검증 방법:**
- `mimirtool rules lint <rule-file.yaml>` — 문법 검증
- Mimir ruler API에서 로드된 rule 확인: `curl http://mimir:8080/prometheus/api/v1/rules`
- label 누락은 에러 없이 rule이 누락되므로 반드시 사전 확인
