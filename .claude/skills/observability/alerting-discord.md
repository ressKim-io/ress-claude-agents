# Alerting & Discord 가이드

Prometheus AlertManager 설정 및 Discord 웹훅 연동

## Quick Reference (결정 트리)

```
알림 채널 선택?
    │
    ├─ 긴급 (Critical) ────> PagerDuty / Opsgenie + Discord
    ├─ 경고 (Warning) ─────> Discord / Slack
    └─ 정보 (Info) ────────> Discord (별도 채널)

알림 설정 방식?
    │
    ├─ Prometheus Stack ──> AlertManager (기본)
    ├─ Grafana ───────────> Grafana Alerting
    └─ 클라우드 ──────────> CloudWatch / Azure Monitor
```

---

## CRITICAL: AlertManager 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    AlertManager Flow                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Prometheus ──(alert rules)──> AlertManager                  │
│                                      │                       │
│                               ┌──────┴──────┐                │
│                               │             │                │
│                          Grouping      Routing               │
│                               │             │                │
│                          Inhibition    Silencing             │
│                               │             │                │
│                               └──────┬──────┘                │
│                                      │                       │
│                              ┌───────┼───────┐               │
│                              │       │       │               │
│                          Discord  Slack  PagerDuty           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 핵심 개념

| 개념 | 설명 |
|------|------|
| **Grouping** | 유사 알림 그룹화 (노이즈 감소) |
| **Routing** | 조건에 따른 알림 전송 경로 |
| **Inhibition** | 특정 알림이 다른 알림 억제 |
| **Silencing** | 일시적 알림 음소거 |

---

## AlertManager 설정

### 기본 설정 (alertmanager.yaml)

```yaml
global:
  resolve_timeout: 5m
  # SMTP 설정 (이메일)
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'alertmanager@example.com'
  smtp_auth_password: 'password'

# 라우팅 규칙
route:
  # 기본 수신자
  receiver: 'discord-warning'
  # 그룹화 기준
  group_by: ['alertname', 'namespace', 'severity']
  # 그룹 대기 시간
  group_wait: 30s
  # 그룹 재전송 간격
  group_interval: 5m
  # 반복 전송 간격
  repeat_interval: 4h

  # 하위 라우트
  routes:
    # Critical 알림 → PagerDuty + Discord
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
      continue: true  # 다음 라우트도 적용

    - match:
        severity: critical
      receiver: 'discord-critical'

    # Warning 알림 → Discord
    - match:
        severity: warning
      receiver: 'discord-warning'

    # 특정 팀 알림
    - match:
        team: backend
      receiver: 'discord-backend'

    - match:
        team: infra
      receiver: 'discord-infra'

# 알림 억제 규칙
inhibit_rules:
  # Critical이 있으면 같은 alertname의 Warning 억제
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace']

# 수신자 정의
receivers:
  - name: 'discord-critical'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/xxx/yyy'
        title: '🔴 CRITICAL Alert'
        message: |
          **{{ .Status | toUpper }}**: {{ .CommonAnnotations.summary }}
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Namespace:* {{ .Labels.namespace }}
          *Description:* {{ .Annotations.description }}
          {{ end }}

  - name: 'discord-warning'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/xxx/zzz'
        title: '🟡 Warning Alert'
        message: |
          **{{ .Status | toUpper }}**: {{ .CommonAnnotations.summary }}
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Description:* {{ .Annotations.description }}
          {{ end }}

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: 'your-pagerduty-service-key'
        severity: critical

  - name: 'discord-backend'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/backend/xxx'

  - name: 'discord-infra'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/infra/xxx'
```

---

## Discord 웹훅 설정

### 웹훅 생성

```
1. Discord 서버 설정 → 연동 → 웹후크
2. 새 웹후크 만들기
3. 채널 선택 (alerts-critical, alerts-warning 등)
4. 웹후크 URL 복사
```

### AlertManager 0.25+ 네이티브 Discord

```yaml
# alertmanager.yaml (v0.25+)
receivers:
  - name: 'discord'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/xxx/yyy'
        title: '{{ template "discord.title" . }}'
        message: '{{ template "discord.message" . }}'
```

### 커스텀 템플릿

```yaml
# alertmanager-templates.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-templates
  namespace: monitoring
data:
  discord.tmpl: |
    {{ define "discord.title" }}
    {{ if eq .Status "firing" }}🔥{{ else }}✅{{ end }} {{ .CommonLabels.alertname }}
    {{ end }}

    {{ define "discord.message" }}
    **Status**: {{ .Status | toUpper }}
    **Severity**: {{ .CommonLabels.severity }}
    {{ if .CommonAnnotations.summary }}
    **Summary**: {{ .CommonAnnotations.summary }}
    {{ end }}

    {{ range .Alerts }}
    ---
    **Alert**: {{ .Labels.alertname }}
    **Namespace**: {{ .Labels.namespace | default "N/A" }}
    **Pod**: {{ .Labels.pod | default "N/A" }}
    {{ if .Annotations.description }}
    **Description**: {{ .Annotations.description }}
    {{ end }}
    {{ if .Annotations.runbook_url }}
    **Runbook**: {{ .Annotations.runbook_url }}
    {{ end }}
    {{ end }}
    {{ end }}
```

---

## Prometheus Alert Rules

### 핵심 알림 규칙

```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-alerts
  namespace: monitoring
spec:
  groups:
    - name: kubernetes-pods
      rules:
        # Pod CrashLoopBackOff
        - alert: PodCrashLooping
          expr: |
            sum(rate(kube_pod_container_status_restarts_total[15m])) by (namespace, pod) > 0
          for: 5m
          labels:
            severity: warning
            team: infra
          annotations:
            summary: "Pod {{ $labels.pod }} is crash looping"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has restarted more than 0 times in 15 minutes"
            runbook_url: "https://wiki.example.com/runbooks/pod-crashloop"

        # Pod Not Ready
        - alert: PodNotReady
          expr: |
            sum by (namespace, pod) (kube_pod_status_phase{phase!="Running",phase!="Succeeded"}) > 0
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} is not ready"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been not ready for 15 minutes"

        # High Memory Usage
        - alert: ContainerHighMemory
          expr: |
            (container_memory_working_set_bytes / container_spec_memory_limit_bytes) > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Container memory usage > 90%"
            description: "Container {{ $labels.container }} in {{ $labels.namespace }}/{{ $labels.pod }} is using > 90% memory"

    - name: kubernetes-nodes
      rules:
        # Node Not Ready
        - alert: NodeNotReady
          expr: |
            kube_node_status_condition{condition="Ready",status="true"} == 0
          for: 5m
          labels:
            severity: critical
            team: infra
          annotations:
            summary: "Node {{ $labels.node }} is not ready"
            description: "Node {{ $labels.node }} has been not ready for 5 minutes"

        # Node High CPU
        - alert: NodeHighCPU
          expr: |
            (1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 0.9
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Node CPU usage > 90%"
            description: "Node {{ $labels.instance }} CPU usage is above 90% for 10 minutes"

        # Node Disk Space Low
        - alert: NodeDiskSpaceLow
          expr: |
            (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) < 0.1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node disk space < 10%"
            description: "Node {{ $labels.instance }} has less than 10% disk space available"

    - name: application-slo
      rules:
        # High Error Rate
        - alert: HighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
            /
            sum(rate(http_requests_total[5m])) by (service)
            > 0.05
          for: 5m
          labels:
            severity: critical
            team: backend
          annotations:
            summary: "Service {{ $labels.service }} error rate > 5%"
            description: "Service {{ $labels.service }} has error rate above 5% for 5 minutes"
            runbook_url: "https://wiki.example.com/runbooks/high-error-rate"

        # High Latency (p99)
        - alert: HighLatencyP99
          expr: |
            histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
            > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Service {{ $labels.service }} p99 latency > 1s"
            description: "Service {{ $labels.service }} p99 latency is above 1 second"
```

---

## 알림 라우팅 예시

### 팀별 라우팅

```yaml
route:
  receiver: 'default-discord'
  routes:
    # Backend 팀
    - match:
        team: backend
      receiver: 'discord-backend'
      routes:
        - match:
            severity: critical
          receiver: 'pagerduty-backend'
          continue: true

    # Infra 팀
    - match:
        team: infra
      receiver: 'discord-infra'
      routes:
        - match:
            severity: critical
          receiver: 'pagerduty-infra'

    # 특정 서비스
    - match:
        service: payment
      receiver: 'discord-payment-critical'
```

### 시간대별 라우팅

```yaml
route:
  receiver: 'discord-default'
  routes:
    # 업무 시간 (09-18시)
    - match:
        severity: critical
      active_time_intervals:
        - business-hours
      receiver: 'slack-critical'

    # 업무 외 시간
    - match:
        severity: critical
      active_time_intervals:
        - off-hours
      receiver: 'pagerduty-critical'

time_intervals:
  - name: business-hours
    time_intervals:
      - weekdays: ['monday:friday']
        times:
          - start_time: '09:00'
            end_time: '18:00'
  - name: off-hours
    time_intervals:
      - weekdays: ['monday:friday']
        times:
          - start_time: '00:00'
            end_time: '09:00'
          - start_time: '18:00'
            end_time: '24:00'
      - weekdays: ['saturday', 'sunday']
```

---

## Silencing (알림 음소거)

### CLI로 Silence 생성

```bash
# amtool로 silence 생성
amtool silence add alertname=PodCrashLooping namespace=staging \
  --comment="Staging maintenance" \
  --author="admin" \
  --duration=2h

# Silence 목록
amtool silence query

# Silence 해제
amtool silence expire <silence-id>
```

### API로 Silence 생성

```bash
curl -X POST http://alertmanager:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "PodCrashLooping", "isRegex": false},
      {"name": "namespace", "value": "staging", "isRegex": false}
    ],
    "startsAt": "2024-01-15T10:00:00Z",
    "endsAt": "2024-01-15T12:00:00Z",
    "createdBy": "admin",
    "comment": "Staging maintenance"
  }'
```

---

## 모니터링

### AlertManager 메트릭

```promql
# 발송된 알림 수
sum(alertmanager_notifications_total) by (integration)

# 알림 발송 실패
sum(alertmanager_notifications_failed_total) by (integration)

# 활성 알림 수
alertmanager_alerts{state="active"}

# Silenced 알림 수
alertmanager_silences{state="active"}
```

### Grafana 대시보드

```json
{
  "panels": [
    {
      "title": "Active Alerts by Severity",
      "targets": [{
        "expr": "sum(ALERTS{alertstate=\"firing\"}) by (severity)",
        "legendFormat": "{{severity}}"
      }]
    },
    {
      "title": "Notifications Sent",
      "targets": [{
        "expr": "rate(alertmanager_notifications_total[1h])",
        "legendFormat": "{{integration}}"
      }]
    }
  ]
}
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 모든 알림 Critical | 알림 피로 | severity 적절히 구분 |
| group_wait 너무 짧음 | 알림 폭탄 | 30초 이상 권장 |
| runbook 없음 | 대응 지연 | 알림마다 runbook 링크 |
| 테스트 없이 적용 | 알림 누락 | 스테이징 테스트 |
| 단일 채널만 사용 | 노이즈 | 심각도별 채널 분리 |

---

## 체크리스트

### AlertManager
- [ ] 기본 설정 (group_wait, group_interval)
- [ ] 라우팅 규칙 (severity, team)
- [ ] 수신자 설정 (Discord, Slack, PagerDuty)
- [ ] 억제 규칙 (inhibit_rules)

### Alert Rules
- [ ] 핵심 메트릭 알림 (Pod, Node, SLO)
- [ ] 적절한 severity 지정
- [ ] runbook_url 포함
- [ ] for 절로 플래핑 방지

### Discord
- [ ] 채널 분리 (critical, warning, info)
- [ ] 웹훅 설정
- [ ] 커스텀 템플릿 적용

### 운영
- [ ] Silence 절차 문서화
- [ ] 알림 대시보드 구성
- [ ] 정기 알림 리뷰

**관련 skill**: `/sre-sli-slo`, `/monitoring-metrics`, `/monitoring-troubleshoot`
