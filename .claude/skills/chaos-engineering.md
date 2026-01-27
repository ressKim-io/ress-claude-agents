# Chaos Engineering 가이드

LitmusChaos를 활용한 시스템 복원력 테스트 및 GameDay 운영

## Quick Reference (결정 트리)

```
Chaos 테스트 도구?
    │
    ├─ Kubernetes 네이티브 ────> LitmusChaos (CNCF, 추천)
    ├─ AWS 환경 ──────────────> AWS Fault Injection Simulator
    ├─ 간단한 테스트 ─────────> chaos-mesh
    └─ 넷플릭스 스타일 ───────> Chaos Monkey

테스트 단계?
    │
    ├─ 1단계: Steady State 정의
    ├─ 2단계: 가설 수립
    ├─ 3단계: 실험 실행
    ├─ 4단계: 결과 분석
    └─ 5단계: 개선 및 반복
```

---

## CRITICAL: Chaos Engineering 원칙

```
┌─────────────────────────────────────────────────────────────┐
│              Chaos Engineering Process                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Steady State 정의                                        │
│     └─ "정상 상태"의 측정 가능한 지표 설정                   │
│                                                              │
│  2. 가설 수립                                                │
│     └─ "X 장애 시에도 Steady State 유지될 것"               │
│                                                              │
│  3. 실험 설계 & 실행                                         │
│     └─ 프로덕션과 유사한 환경에서 제어된 장애 주입           │
│                                                              │
│  4. 결과 분석                                                │
│     └─ 가설 검증, 약점 발견                                  │
│                                                              │
│  5. 개선                                                     │
│     └─ 발견된 약점 수정, 모니터링 개선                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 핵심 원칙

| 원칙 | 설명 |
|------|------|
| **Steady State 정의** | 시스템 정상 동작의 측정 가능한 지표 |
| **실제 이벤트 가설** | 실제 발생 가능한 장애 시나리오 |
| **프로덕션 실험** | 가능하면 프로덕션 환경에서 |
| **자동화** | 지속적 실험을 위한 자동화 |
| **폭발 반경 최소화** | 영향 범위 제한 |

---

## LitmusChaos 설치

### Helm 설치

```bash
# LitmusChaos 설치
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm install litmus litmuschaos/litmus \
  --namespace litmus \
  --create-namespace \
  --set portal.frontend.service.type=LoadBalancer
```

### CRD 구성요소

| CRD | 역할 |
|-----|------|
| **ChaosEngine** | 실험 실행 트리거 |
| **ChaosExperiment** | 실험 정의 (장애 유형) |
| **ChaosResult** | 실험 결과 |
| **ChaosSchedule** | 실험 스케줄링 |

---

## 기본 실험

### Pod Delete 실험

```yaml
# ChaosExperiment 설치
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosExperiment
metadata:
  name: pod-delete
  namespace: litmus
spec:
  definition:
    scope: Namespaced
    permissions:
      - apiGroups: [""]
        resources: ["pods"]
        verbs: ["delete", "get", "list"]
    image: litmuschaos/go-runner:latest
    args:
      - -c
      - ./experiments -name pod-delete
    command:
      - /bin/bash
    env:
      - name: TOTAL_CHAOS_DURATION
        value: "30"
      - name: CHAOS_INTERVAL
        value: "10"
      - name: FORCE
        value: "false"
---
# ChaosEngine으로 실험 실행
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: order-service-chaos
  namespace: production
spec:
  appinfo:
    appns: production
    applabel: "app=order-service"
    appkind: deployment
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: "60"
            - name: CHAOS_INTERVAL
              value: "10"
            - name: PODS_AFFECTED_PERC
              value: "50"
        probe:
          - name: "check-order-api"
            type: "httpProbe"
            mode: "Continuous"
            runProperties:
              probeTimeout: 5s
              retry: 3
              interval: 5s
            httpProbe/inputs:
              url: "http://order-service.production.svc:8080/health"
              insecureSkipVerify: false
              method:
                get:
                  criteria: "=="
                  responseCode: "200"
```

### Container Kill 실험

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: container-kill-chaos
  namespace: production
spec:
  appinfo:
    appns: production
    applabel: "app=api-gateway"
    appkind: deployment
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: container-kill
      spec:
        components:
          env:
            - name: TARGET_CONTAINER
              value: "api-gateway"
            - name: TOTAL_CHAOS_DURATION
              value: "30"
            - name: CHAOS_INTERVAL
              value: "10"
```

### Network Chaos (지연/손실)

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: network-chaos
  namespace: production
spec:
  appinfo:
    appns: production
    applabel: "app=payment-service"
    appkind: deployment
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-network-latency
      spec:
        components:
          env:
            - name: NETWORK_INTERFACE
              value: "eth0"
            - name: NETWORK_LATENCY
              value: "500"  # 500ms 지연
            - name: TOTAL_CHAOS_DURATION
              value: "60"
            - name: CONTAINER_RUNTIME
              value: "containerd"
---
# 네트워크 패킷 손실
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: network-loss-chaos
spec:
  experiments:
    - name: pod-network-loss
      spec:
        components:
          env:
            - name: NETWORK_INTERFACE
              value: "eth0"
            - name: NETWORK_PACKET_LOSS_PERCENTAGE
              value: "30"  # 30% 패킷 손실
            - name: TOTAL_CHAOS_DURATION
              value: "60"
```

### CPU/Memory Stress

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: stress-chaos
  namespace: production
spec:
  appinfo:
    appns: production
    applabel: "app=compute-service"
    appkind: deployment
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-cpu-hog
      spec:
        components:
          env:
            - name: CPU_CORES
              value: "2"
            - name: TOTAL_CHAOS_DURATION
              value: "60"
            - name: CPU_LOAD
              value: "100"
---
# 메모리 스트레스
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: memory-stress-chaos
spec:
  experiments:
    - name: pod-memory-hog
      spec:
        components:
          env:
            - name: MEMORY_CONSUMPTION
              value: "500"  # 500Mi
            - name: TOTAL_CHAOS_DURATION
              value: "60"
```

---

## Probe (검증)

### HTTP Probe

```yaml
probe:
  - name: "health-check"
    type: "httpProbe"
    mode: "Continuous"
    runProperties:
      probeTimeout: 5s
      retry: 3
      interval: 5s
    httpProbe/inputs:
      url: "http://service.namespace.svc:8080/health"
      method:
        get:
          criteria: "=="
          responseCode: "200"
```

### Prometheus Probe

```yaml
probe:
  - name: "error-rate-check"
    type: "promProbe"
    mode: "Edge"  # 실험 시작/끝에 체크
    runProperties:
      probeTimeout: 5s
      retry: 2
      interval: 10s
    promProbe/inputs:
      endpoint: "http://prometheus:9090"
      query: "sum(rate(http_requests_total{status=~\"5..\"}[1m])) / sum(rate(http_requests_total[1m]))"
      comparator:
        type: "float"
        criteria: "<"
        value: "0.05"  # 에러율 5% 미만
```

### Command Probe

```yaml
probe:
  - name: "db-connection-check"
    type: "cmdProbe"
    mode: "Continuous"
    runProperties:
      probeTimeout: 10s
      retry: 3
      interval: 10s
    cmdProbe/inputs:
      command: "pg_isready -h postgres -p 5432"
      comparator:
        type: "string"
        criteria: "contains"
        value: "accepting connections"
```

---

## GameDay 운영

### GameDay 체크리스트

```markdown
## Pre-GameDay
- [ ] 시나리오 정의 및 문서화
- [ ] Steady State 지표 정의 (SLI 기반)
- [ ] 롤백 절차 준비
- [ ] 참가자 알림 및 역할 배정
- [ ] 모니터링 대시보드 준비
- [ ] 알림 채널 음소거 (필요시)

## During GameDay
- [ ] 시작 전 Steady State 확인
- [ ] 단계별 실험 실행
- [ ] 실시간 모니터링
- [ ] 이슈 발생 시 즉시 롤백
- [ ] 관찰 내용 기록

## Post-GameDay
- [ ] 결과 분석 및 문서화
- [ ] 발견된 이슈 티켓 생성
- [ ] 개선 사항 우선순위 지정
- [ ] 회고 미팅
- [ ] 다음 GameDay 계획
```

### GameDay 시나리오 예시

```yaml
# gameday-scenario.yaml
name: "Order Service Resilience"
date: "2024-01-20"
duration: "2 hours"
participants:
  - role: "Facilitator"
    name: "SRE Team Lead"
  - role: "Observer"
    name: "Backend Engineers"

steady_state:
  - metric: "Order Success Rate"
    threshold: "> 99.9%"
    query: "sum(rate(orders_total{status='success'}[5m])) / sum(rate(orders_total[5m]))"
  - metric: "P99 Latency"
    threshold: "< 500ms"
    query: "histogram_quantile(0.99, rate(order_duration_seconds_bucket[5m]))"

experiments:
  - name: "Single Pod Failure"
    hypothesis: "Order service는 1개 Pod 실패 시에도 99.9% 성공률 유지"
    chaos:
      type: pod-delete
      target: order-service
      params:
        pods_affected: 1
    expected_result: "자동 복구, SLO 유지"
    blast_radius: "1 pod (of 3)"

  - name: "Database Latency"
    hypothesis: "DB 100ms 추가 지연 시에도 P99 1초 미만"
    chaos:
      type: network-latency
      target: postgresql
      params:
        latency_ms: 100
    expected_result: "지연 증가하나 SLO 내"
    blast_radius: "DB connections"

  - name: "Full AZ Failure"
    hypothesis: "1개 AZ 장애 시에도 서비스 지속"
    chaos:
      type: az-failure-simulation
      target: ap-northeast-2a
    expected_result: "다른 AZ로 트래픽 전환"
    blast_radius: "33% of capacity"

rollback_procedure: |
  1. ChaosEngine 삭제: kubectl delete chaosengine -n production --all
  2. Pod 재시작: kubectl rollout restart deployment/order-service
  3. 상태 확인: kubectl get pods -n production
```

### 실험 스케줄링 (CI/CD 통합)

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosSchedule
metadata:
  name: weekly-chaos
  namespace: litmus
spec:
  schedule:
    now: false
    repeat:
      # 매주 화요일 오전 10시
      minChaosInterval: "168h"
      timeRange:
        startTime: "10:00"
        endTime: "12:00"
      workDays:
        includedDays: "Tue"
  engineTemplateSpec:
    appinfo:
      appns: staging
      applabel: "app=order-service"
      appkind: deployment
    engineState: active
    chaosServiceAccount: litmus-admin
    experiments:
      - name: pod-delete
        spec:
          components:
            env:
              - name: TOTAL_CHAOS_DURATION
                value: "30"
```

---

## 모니터링 & 알림

### Prometheus 메트릭

```promql
# Chaos 실험 상태
litmuschaos_experiment_result{result="Pass"}
litmuschaos_experiment_result{result="Fail"}

# 실험 지속 시간
litmuschaos_experiment_duration_seconds

# 영향받은 Pod 수
litmuschaos_affected_pods_count
```

### Grafana 대시보드

```json
{
  "panels": [
    {
      "title": "Chaos Experiment Status",
      "targets": [{
        "expr": "litmuschaos_experiment_result",
        "legendFormat": "{{experiment_name}} - {{result}}"
      }]
    },
    {
      "title": "Service Health During Chaos",
      "targets": [{
        "expr": "rate(http_requests_total{status!~\"5..\"}[1m]) / rate(http_requests_total[1m])",
        "legendFormat": "Success Rate"
      }]
    }
  ]
}
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 프로덕션 첫 실험 | 서비스 장애 | 스테이징부터 시작 |
| Steady State 없음 | 성공/실패 판단 불가 | SLI 기반 지표 정의 |
| 롤백 계획 없음 | 장애 확대 | 롤백 절차 사전 준비 |
| 모니터링 없이 실험 | 영향 파악 불가 | 대시보드 준비 |
| 너무 큰 폭발 반경 | 심각한 장애 | 작은 범위부터 시작 |

---

## 체크리스트

### 사전 준비
- [ ] LitmusChaos 설치
- [ ] ServiceAccount/RBAC 설정
- [ ] Steady State 지표 정의
- [ ] 롤백 절차 문서화

### 실험 설계
- [ ] 가설 명확히 정의
- [ ] Probe 설정 (성공/실패 조건)
- [ ] 폭발 반경 제한
- [ ] 스테이징 먼저 테스트

### GameDay
- [ ] 참가자 사전 교육
- [ ] 모니터링 대시보드 준비
- [ ] 실시간 기록
- [ ] 회고 및 개선

**관련 skill**: `/sre-sli-slo`, `/load-testing`, `/monitoring-troubleshoot`
