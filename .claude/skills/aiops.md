# AIOps 가이드

AI 기반 IT 운영: 이상 탐지, 근본 원인 분석, 자동 복구

## Quick Reference (결정 트리)

```
AIOps 도입 단계?
    │
    ├─ 1단계: 데이터 수집 ────> OpenTelemetry 표준화
    │       │
    │       ├─ Metrics ───────> Prometheus
    │       ├─ Logs ──────────> Loki/Elasticsearch
    │       └─ Traces ────────> Jaeger/Tempo
    │
    ├─ 2단계: 이상 탐지 ──────> ML 기반 분석
    │       │
    │       ├─ 시계열 이상 ───> Prophet/LSTM
    │       └─ 로그 이상 ─────> Log Anomaly Detection
    │
    ├─ 3단계: 근본 원인 분석 ─> RCA Automation
    │       │
    │       ├─ Causal AI ─────> 의존성 그래프
    │       └─ LLM 분석 ──────> 컨텍스트 요약
    │
    └─ 4단계: 자동 복구 ──────> Self-Healing
            │
            ├─ Runbook ───────> 자동화된 복구
            └─ Policy ────────> 정책 기반 조치
```

---

## CRITICAL: AIOps 성숙도 모델

| Level | 단계 | 자동화 수준 | 목표 |
|-------|------|------------|------|
| **L1** | 반응적 | 수동 분석 | 알림 관리 |
| **L2** | 사전 예방적 | 이상 탐지 | MTTD 단축 |
| **L3** | 예측적 | RCA 자동화 | MTTR 단축 |
| **L4** | 자율 운영 | 자동 복구 | 무중단 운영 |

### 시장 현황 (2026)

| 지표 | 값 | 출처 |
|------|-----|------|
| AIOps 시장 성장률 | 15% CAGR | Gartner |
| Observability 도입률 | 70% | Gartner |
| RCA 자동화 사용 | 12% | LogicMonitor |
| 자동 복구 원하는 조직 | 44% | LogicMonitor |

---

## OpenTelemetry 통합

### OTel Collector 설정

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
spec:
  mode: daemonset
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      prometheus:
        config:
          scrape_configs:
            - job_name: 'kubernetes-pods'
              kubernetes_sd_configs:
                - role: pod

    processors:
      batch:
        timeout: 10s
        send_batch_size: 1024
      memory_limiter:
        check_interval: 1s
        limit_mib: 1000
      # AI 분석용 속성 추가
      attributes:
        actions:
          - key: ai.analysis.enabled
            value: true
            action: insert

    exporters:
      otlp:
        endpoint: "tempo:4317"
        tls:
          insecure: true
      prometheus:
        endpoint: "0.0.0.0:8889"
      loki:
        endpoint: "http://loki:3100/loki/api/v1/push"

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
        metrics:
          receivers: [otlp, prometheus]
          processors: [memory_limiter, batch]
          exporters: [prometheus]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch, attributes]
          exporters: [loki]
```

---

## 이상 탐지 (Anomaly Detection)

### Prometheus + Prophet 통합

```python
# anomaly_detector.py
from prometheus_api_client import PrometheusConnect
from prophet import Prophet
import pandas as pd

class AnomalyDetector:
    def __init__(self, prometheus_url: str):
        self.prom = PrometheusConnect(url=prometheus_url)

    def detect_metric_anomaly(
        self,
        query: str,
        lookback_hours: int = 168,  # 1주
        sensitivity: float = 0.95
    ) -> list:
        # 메트릭 조회
        data = self.prom.custom_query_range(
            query=query,
            start_time=datetime.now() - timedelta(hours=lookback_hours),
            end_time=datetime.now(),
            step="5m"
        )

        # Prophet 형식으로 변환
        df = pd.DataFrame({
            'ds': [datetime.fromtimestamp(d[0]) for d in data[0]['values']],
            'y': [float(d[1]) for d in data[0]['values']]
        })

        # 모델 학습 및 예측
        model = Prophet(interval_width=sensitivity)
        model.fit(df)
        forecast = model.predict(df)

        # 이상치 탐지
        df['yhat'] = forecast['yhat']
        df['yhat_lower'] = forecast['yhat_lower']
        df['yhat_upper'] = forecast['yhat_upper']
        df['anomaly'] = (df['y'] < df['yhat_lower']) | (df['y'] > df['yhat_upper'])

        return df[df['anomaly']].to_dict('records')
```

### Grafana ML 기반 이상 탐지

```yaml
# Grafana Alerting Rule with ML
apiVersion: 1
groups:
  - name: aiops-anomaly-detection
    folder: AIOps
    interval: 1m
    rules:
      - uid: anomaly-cpu
        title: CPU Anomaly Detection
        condition: C
        data:
          # A: 현재 값
          - refId: A
            relativeTimeRange:
              from: 600
              to: 0
            datasourceUid: prometheus
            model:
              expr: |
                avg(rate(container_cpu_usage_seconds_total{
                  namespace="production"
                }[5m])) by (pod)

          # B: 예측 기준선 (이동 평균 + 표준편차)
          - refId: B
            relativeTimeRange:
              from: 86400  # 24시간
              to: 0
            datasourceUid: prometheus
            model:
              expr: |
                avg_over_time(
                  avg(rate(container_cpu_usage_seconds_total{
                    namespace="production"
                  }[5m])) by (pod)[24h:5m]
                ) + 3 * stddev_over_time(
                  avg(rate(container_cpu_usage_seconds_total{
                    namespace="production"
                  }[5m])) by (pod)[24h:5m]
                )

          # C: 이상 여부 판단
          - refId: C
            datasourceUid: __expr__
            model:
              type: math
              expression: $A > $B
```

---

## 근본 원인 분석 (RCA)

### LLM 기반 RCA 자동화

```python
# rca_analyzer.py
from openai import OpenAI
from kubernetes import client, config
import json

class RCAAnalyzer:
    def __init__(self):
        self.llm = OpenAI()
        config.load_incluster_config()
        self.k8s = client.CoreV1Api()

    def analyze_incident(self, alert: dict) -> dict:
        # 1. 관련 데이터 수집
        context = self._gather_context(alert)

        # 2. LLM 분석
        analysis = self._llm_analyze(alert, context)

        # 3. 결과 구조화
        return {
            "incident": alert,
            "root_cause": analysis["root_cause"],
            "impact": analysis["impact"],
            "remediation": analysis["remediation"],
            "confidence": analysis["confidence"]
        }

    def _gather_context(self, alert: dict) -> dict:
        namespace = alert.get("namespace", "default")
        pod = alert.get("pod")

        context = {
            "events": [],
            "logs": [],
            "metrics": {}
        }

        # Kubernetes 이벤트 수집
        events = self.k8s.list_namespaced_event(
            namespace=namespace,
            field_selector=f"involvedObject.name={pod}"
        )
        context["events"] = [
            {"reason": e.reason, "message": e.message, "time": str(e.last_timestamp)}
            for e in events.items[-10:]
        ]

        # Pod 상태 수집
        pod_obj = self.k8s.read_namespaced_pod(name=pod, namespace=namespace)
        context["pod_status"] = {
            "phase": pod_obj.status.phase,
            "conditions": [
                {"type": c.type, "status": c.status, "reason": c.reason}
                for c in (pod_obj.status.conditions or [])
            ]
        }

        return context

    def _llm_analyze(self, alert: dict, context: dict) -> dict:
        prompt = f"""
        당신은 SRE 전문가입니다. 다음 Kubernetes 인시던트를 분석하세요.

        ## Alert
        {json.dumps(alert, indent=2)}

        ## Context
        {json.dumps(context, indent=2)}

        다음 형식으로 응답하세요:
        1. Root Cause: 근본 원인 (1-2문장)
        2. Impact: 영향 범위 (서비스/사용자)
        3. Remediation: 복구 단계 (번호 목록)
        4. Confidence: 분석 신뢰도 (0-100%)
        """

        response = self.llm.chat.completions.create(
            model="gpt-4",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3
        )

        # 응답 파싱 (실제로는 더 정교한 파싱 필요)
        return self._parse_response(response.choices[0].message.content)
```

### 인과 관계 그래프 (Causal Graph)

```yaml
# 서비스 의존성 정의
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-topology
data:
  topology.yaml: |
    services:
      - name: frontend
        depends_on: [api-gateway]
        metrics:
          - http_requests_total
          - http_request_duration_seconds

      - name: api-gateway
        depends_on: [order-service, user-service]
        metrics:
          - gateway_requests_total
          - gateway_latency_seconds

      - name: order-service
        depends_on: [postgres, redis]
        metrics:
          - order_processing_total
          - order_latency_seconds

      - name: postgres
        type: database
        metrics:
          - pg_connections
          - pg_query_duration_seconds

    # 장애 전파 규칙
    propagation_rules:
      - if: postgres.pg_connections > 90%
        then: order-service.latency_increase
        confidence: 0.85

      - if: order-service.error_rate > 5%
        then: api-gateway.error_rate_increase
        confidence: 0.90
```

---

## 자동 복구 (Auto-Remediation)

### Runbook 자동화

```yaml
# runbook-operator CRD
apiVersion: aiops.io/v1
kind: Runbook
metadata:
  name: pod-crash-loop-remediation
spec:
  trigger:
    alertname: PodCrashLoopBackOff
    severity: critical

  conditions:
    - type: pod_restart_count
      operator: ">"
      value: 5

  actions:
    - name: collect-diagnostics
      type: kubectl
      command: |
        kubectl logs {{ .pod }} -n {{ .namespace }} --previous > /tmp/crash-logs.txt
        kubectl describe pod {{ .pod }} -n {{ .namespace }} > /tmp/pod-describe.txt

    - name: check-resources
      type: prometheus
      query: |
        container_memory_working_set_bytes{
          pod="{{ .pod }}",
          namespace="{{ .namespace }}"
        } / container_spec_memory_limit_bytes > 0.95

    - name: remediate-oom
      type: kubectl
      condition: "{{ .check-resources.result == true }}"
      command: |
        kubectl patch deployment {{ .deployment }} -n {{ .namespace }} \
          -p '{"spec":{"template":{"spec":{"containers":[{
            "name":"{{ .container }}",
            "resources":{"limits":{"memory":"{{ .current_memory * 1.5 }}"}}
          }]}}}}'

    - name: restart-pod
      type: kubectl
      condition: "{{ .check-resources.result == false }}"
      command: |
        kubectl delete pod {{ .pod }} -n {{ .namespace }}

  notification:
    slack:
      channel: "#incidents"
      message: |
        🔧 Auto-remediation executed for {{ .pod }}
        Action: {{ .executed_action }}
        Result: {{ .result }}
```

### KEDA 기반 자동 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: aiops-autoscaler
spec:
  scaleTargetRef:
    name: order-service
  minReplicaCount: 2
  maxReplicaCount: 20
  triggers:
    # 에러율 기반 스케일링
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: error_rate
        threshold: "5"
        query: |
          sum(rate(http_requests_total{
            status=~"5..",
            service="order-service"
          }[5m])) /
          sum(rate(http_requests_total{
            service="order-service"
          }[5m])) * 100

    # 지연 시간 기반 스케일링
    - type: prometheus
      metadata:
        metricName: p99_latency
        threshold: "1000"  # 1초
        query: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket{
              service="order-service"
            }[5m])) by (le)
          ) * 1000
```

---

## 모니터링 대시보드

### Grafana AIOps 대시보드

```json
{
  "title": "AIOps Overview",
  "panels": [
    {
      "title": "Anomaly Score",
      "type": "timeseries",
      "targets": [{
        "expr": "anomaly_score{job=\"aiops-detector\"}",
        "legendFormat": "{{ service }}"
      }],
      "thresholds": {
        "steps": [
          {"color": "green", "value": 0},
          {"color": "yellow", "value": 0.7},
          {"color": "red", "value": 0.9}
        ]
      }
    },
    {
      "title": "Auto-Remediation Actions",
      "type": "stat",
      "targets": [{
        "expr": "sum(increase(remediation_actions_total[24h]))"
      }]
    },
    {
      "title": "MTTR Trend",
      "type": "timeseries",
      "targets": [{
        "expr": "avg(incident_resolution_time_seconds) / 60"
      }],
      "unit": "minutes"
    }
  ]
}
```

---

## 핵심 메트릭

### AIOps KPIs

| 메트릭 | 설명 | 목표 |
|--------|------|------|
| MTTD | 탐지까지 시간 | < 5분 |
| MTTR | 복구까지 시간 | < 30분 |
| 노이즈 감소율 | 알림 통합 효율 | > 80% |
| 자동 복구율 | 자동화된 해결 | > 40% |
| 예측 정확도 | 이상 탐지 정밀도 | > 90% |

### PromQL 쿼리

```promql
# MTTD (탐지 시간)
avg(incident_detection_time_seconds)

# MTTR (복구 시간)
avg(incident_resolution_time_seconds)

# 알림 노이즈 감소율
1 - (
  sum(increase(alerts_deduplicated_total[24h])) /
  sum(increase(alerts_raw_total[24h]))
)

# 자동 복구 성공률
sum(increase(remediation_success_total[7d])) /
sum(increase(remediation_attempts_total[7d]))
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 데이터 사일로 | 상관관계 분석 불가 | OTel 통합 |
| 과도한 알림 | 알림 피로 | 노이즈 필터링 |
| LLM 맹신 | 잘못된 RCA | 인과 모델 병행 |
| 자동화 과신 | 예상치 못한 조치 | 승인 게이트 |
| 데이터 폭증 | 비용 증가 | 샘플링/보존 정책 |

---

## 체크리스트

### AIOps Level 1 (반응적)
- [ ] OpenTelemetry 표준화
- [ ] 중앙 집중식 로깅
- [ ] 기본 알림 설정

### AIOps Level 2 (사전 예방적)
- [ ] ML 기반 이상 탐지
- [ ] 알림 중복 제거/그룹화
- [ ] 서비스 의존성 맵핑

### AIOps Level 3 (예측적)
- [ ] LLM 기반 RCA
- [ ] 인과 관계 그래프
- [ ] Runbook 자동화

### AIOps Level 4 (자율 운영)
- [ ] 자동 복구 파이프라인
- [ ] 예측적 스케일링
- [ ] Self-Healing 시스템

**관련 agent**: `incident-responder`, `k8s-troubleshooter`
**관련 skill**: `/observability`, `/alerting`

---

## Sources

- [Kubernetes Observability Trends 2026](https://www.usdsi.org/data-science-insights/kubernetes-observability-and-monitoring-trends-in-2026)
- [AI-Based Observability 2026](https://middleware.io/blog/how-ai-based-insights-can-change-the-observability/)
- [Modern Kubernetes Monitoring with AIOps](https://developers.redhat.com/articles/2025/12/17/modern-kubernetes-monitoring-metrics-tools-and-aiops)
- [LLMs for Root Cause Analysis](https://dzone.com/articles/llms-automated-root-cause-analysis-incident-response)
- [Observability AI Trends 2026](https://www.logicmonitor.com/blog/observability-ai-trends-2026)
- [Causal Reasoning in Observability](https://www.infoq.com/articles/causal-reasoning-observability/)
