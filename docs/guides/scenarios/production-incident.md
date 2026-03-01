# 시나리오: 프로덕션 장애 대응

> K8s 파드 OOMKilled 장애를 발견부터 해결까지 대응하는 워크스루

---

## 개요

| 항목 | 내용 |
|------|------|
| **대상** | DevOps/SRE 또는 백엔드 개발자 |
| **소요 시간** | 30-60분 |
| **필요 조건** | K8s 클러스터 접근 권한, kubectl |
| **결과물** | 장애 해결 + 근본 원인 분석 + 재발 방지 조치 |

---

## 전체 흐름

```
┌──────────────────────────────────────────────────────┐
│                  ALERT: OOMKilled                      │
│          order-service 파드 반복 재시작                  │
└──────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 1     │     │  Step 2     │     │  Step 3     │
│  트리아지    │────►│  근본 원인   │────►│  관측성 분석 │
│             │     │  분석        │     │             │
│ incident-   │     │ k8s-trouble  │     │ otel-expert │
│ responder   │     │ shooter      │     │ /monitoring │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                    ┌─────────────┐     ┌─────────────┐
                    │  Step 4     │     │  Step 5     │
                    │  수정 적용   │────►│  기록/회고   │
                    │             │     │             │
                    │ code-review │     │ dev-logger  │
                    │ /k8s-auto   │     │ /log-trouble│
                    └─────────────┘     └─────────────┘
```

---

## Step 1: 자동 트리아지

**사용 도구**: `incident-responder`

### 이렇게 요청하세요

```
"프로덕션 order-service 파드가 OOMKilled로 반복 재시작하고 있어.
 장애 분석해줘."
```

### Claude가 하는 일

- 심각도 분류 (SEV1-4)
- 영향 범위 평가 (어떤 서비스, 몇 명의 사용자)
- 타임라인 구성 (언제부터 발생?)
- 초기 커뮤니케이션 템플릿 생성

### 예상 결과

```
## Incident Analysis
- Severity: SEV2
- Impact: 주문 생성 실패, 약 30% 사용자 영향
- Timeline: 14:30 UTC 배포 이후 발생
- Hypothesis: 메모리 누수 또는 리소스 limit 부족
```

### 체크포인트

- [ ] 심각도가 적절히 분류되었는가?
- [ ] 영향 범위가 파악되었는가?
- [ ] 최근 변경 사항이 확인되었는가?

---

## Step 2: 근본 원인 분석

**사용 도구**: `k8s-troubleshooter`

### 이렇게 요청하세요

```
"order-service OOMKilled 근본 원인 분석해줘.
 - 파드 상태, 이벤트, 로그 확인
 - 메모리 사용량 추이 분석
 - 최근 배포 변경 사항 확인"
```

### Claude가 하는 일

```bash
# 파드 상태 확인
kubectl get pods -n production -l app=order-service

# 이벤트 확인
kubectl describe pod <pod-name> -n production

# 메모리 사용량
kubectl top pods -n production -l app=order-service

# 로그 확인 (OOM 관련)
kubectl logs <pod-name> -n production --previous | grep -i "memory\|oom\|heap"

# 최근 배포
kubectl rollout history deployment/order-service -n production
```

### 가설 검증 사이클

```
가설 1: 메모리 limit 부족
  → kubectl describe pod → resource limits 확인
  → 결과: limit 512Mi, 실제 사용 480Mi → limit 근접

가설 2: 메모리 누수
  → 로그에서 heap 증가 패턴 확인
  → 결과: 특정 API 호출 시 goroutine 누수 발견

→ 근본 원인: goroutine 누수로 메모리 점진적 증가
```

### 체크포인트

- [ ] 근본 원인(cause)이 확인되었는가? (증상이 아닌)
- [ ] 가설이 데이터로 검증되었는가?

---

## Step 3: 관측성 데이터 분석

**사용 도구**: `otel-expert` + `/monitoring-troubleshoot`

### 이렇게 요청하세요

```
"Grafana에서 order-service 메모리/CPU 추이와
 에러율 변화를 분석해줘."
```

### Claude가 하는 일

- 메트릭 쿼리 제안 (Prometheus/Grafana)
- 트레이스 분석 (느린 요청 식별)
- 로그 상관관계 분석

### 주요 확인 사항

```promql
# 메모리 사용량 추이
container_memory_working_set_bytes{pod=~"order-service.*"}

# 재시작 횟수
kube_pod_container_status_restarts_total{container="order-service"}

# 에러율
rate(http_server_requests_seconds_count{service="order-service",status=~"5.."}[5m])
```

### 체크포인트

- [ ] 메모리 증가 패턴이 확인되었는가?
- [ ] 배포 시점과 장애 시점의 상관관계가 확인되었는가?

---

## Step 4: 수정 적용

**사용 도구**: `code-reviewer` + `/k8s-autoscaling`

### 즉시 조치 (긴급)

```
"goroutine 누수를 수정하고, 메모리 limit을 1Gi로 올려줘."
```

### Claude가 하는 일

1. **즉시 조치**: 메모리 limit 상향 + 파드 재시작
2. **근본 수정**: goroutine 누수 코드 수정
3. **재발 방지**: 회귀 테스트 추가

### 수정 후 검증

```bash
# 수정 배포 후 모니터링
kubectl rollout status deployment/order-service -n production

# 메모리 안정화 확인
kubectl top pods -n production -l app=order-service

# 에러율 정상화 확인
# Grafana 대시보드에서 확인
```

### 체크포인트

- [ ] 장애 증상이 해소되었는가?
- [ ] 회귀 테스트가 추가되었는가?
- [ ] 다른 서비스에 부작용이 없는가?

---

## Step 5: 기록 및 회고

**사용 도구**: `dev-logger` (`/log-trouble`)

### 이렇게 요청하세요

```
/log-trouble
```

### Claude가 하는 일

- 트러블슈팅 과정을 구조화된 마크다운으로 기록
- 타임라인, 근본 원인, 해결 방법, 재발 방지 조치 정리
- `docs/dev-logs/` 에 저장

### 포스트모템 항목

```markdown
## Post-Mortem: Order Service OOMKilled

### Timeline
- 14:30 v2.3.1 배포
- 14:45 첫 OOMKilled 발생
- 15:00 장애 인지, 분석 시작
- 15:30 근본 원인 확인 (goroutine 누수)
- 15:45 핫픽스 배포
- 16:00 서비스 정상화

### Root Cause
v2.3.1에서 추가된 HTTP 클라이언트가 Response Body를
Close하지 않아 goroutine 누수 발생

### Action Items
- [x] Response Body Close 수정
- [x] 메모리 limit 512Mi → 1Gi 상향
- [x] goroutine 모니터링 알림 추가
- [ ] 코드 리뷰 체크리스트에 resource leak 항목 추가
```

### 체크포인트

- [ ] 포스트모템이 작성되었는가?
- [ ] Action Items가 명확한가?
- [ ] 모니터링/알림이 강화되었는가?

---

## 마무리

### 검증 방법

```bash
# 파드 상태 정상 확인
kubectl get pods -n production -l app=order-service

# 메모리 안정 확인 (30분 모니터링)
watch kubectl top pods -n production -l app=order-service

# 에러율 0% 확인
# Grafana dashboard
```

### 다음 단계

- `/chaos-engineering` — 카오스 테스트로 유사 장애 사전 탐지
- `/sre-sli-slo` — SLI/SLO 정의하여 에러 버짓 관리
- `/aiops` — AIOps로 이상 탐지 자동화
- [플랫폼 팀 환경 구축](platform-bootstrap.md) — 관측성 인프라 체계화
