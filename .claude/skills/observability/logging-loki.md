# Loki Log Analysis Guide

Grafana Loki + LogQL을 활용한 로그 검색/분석 가이드 (보안팀/개발팀용)

## Quick Reference (선택 기준)
```
Loki vs ELK 선택
    ├─ Loki ────────> 비용 효율, Grafana 통합, 메트릭 연계
    │                 메타데이터만 인덱싱 (저장 70% 절감)
    │
    └─ ELK ─────────> 전체 텍스트 검색, 복잡한 집계
                      장기 보관 + 컴플라이언스 감사
```

### Loki 장점/제한
| 장점 | 제한 |
|------|------|
| 저장 비용 70% 절감 | 전체 텍스트 인덱싱 없음 |
| Prometheus 라벨 연계 | 고카디널리티 비효율 |
| 설정 간단 | 복잡한 조인 불가 |

---

## 역할별 LogQL 쿼리

### 개발팀용 쿼리

**에러 추적**
```logql
# 내 서비스 에러 로그
{namespace="production", app="order-service"} |= "error"

# 특정 trace_id로 전체 흐름 추적
{namespace="production"} | json | trace_id="abc123def456"

# 최근 5분간 에러 + 스택트레이스
{app="payment-service"} |= "Exception" | json | line_format "{{.timestamp}} {{.message}}\n{{.stacktrace}}"
```

**성능 분석**
```logql
# 느린 요청 (1초 이상)
{app="api-gateway"} | json | duration_ms > 1000

# 엔드포인트별 평균 응답시간
avg_over_time({app="api-gateway"} | json | unwrap duration_ms [5m]) by (endpoint)

# P95 응답시간
quantile_over_time(0.95, {app="api-gateway"} | json | unwrap duration_ms [5m])
```

### 보안팀용 쿼리

**인증/접근 분석**
```logql
# 로그인 실패 시도
{job="security"} |= "login_failed" | json
  | line_format "IP={{.ip}} USER={{.username}} TIME={{.timestamp}}"

# 동일 IP 다중 실패 (brute force 의심)
sum by (ip) (count_over_time({job="security"} |= "login_failed" | json [5m])) > 5

# 비정상 시간대 접근 (야간 02-06시)
{job="security"} |= "login_success" | json
  | __timestamp__ >= 02:00 and __timestamp__ <= 06:00
```

**봇/매크로 탐지**
```logql
# 봇 탐지 이벤트
{app="bot-detector"} | json | is_bot="true"
  | line_format "{{.timestamp}} IP={{.client_ip}} SIGNAL={{.detection_signals}}"

# 고신뢰도 봇 (confidence > 0.9)
{app="bot-detector"} | json | is_bot="true" | confidence > 0.9

# IP별 봇 탐지 횟수
sum by (client_ip) (count_over_time({app="bot-detector"} | json | is_bot="true" [1h]))
```

**결제/민감정보 접근**
```logql
# 결제 로그 조회
{log_type="payment"} | json
  | line_format "{{.timestamp}} TXN={{.transaction_id}} AMT={{.amount}} STATUS={{.status}}"

# 개인정보 접근 로그
{log_type="personal_info_access"} | json
  | line_format "{{.timestamp}} USER={{.accessor}} TARGET={{.data_subject}} ACTION={{.action}}"

# 대량 조회 탐지 (10건 이상/분)
sum by (accessor) (count_over_time({log_type="personal_info_access"} | json [1m])) > 10
```

---

## LogQL 문법 심화

### 파서 (Parser)
```logql
# JSON 파싱
{app="api"} | json

# 정규식 파싱
{app="nginx"} | regexp `(?P<ip>\d+\.\d+\.\d+\.\d+) - (?P<user>\S+)`

# Pattern 파싱 (간단한 구조)
{app="nginx"} | pattern `<ip> - <user> [<_>] "<method> <path> <_>" <status>`

# 라인 포맷 (출력 형식 지정)
{app="api"} | json | line_format "{{.level}} [{{.trace_id}}] {{.message}}"
```

### 필터 연산자
```logql
# 포함 (대소문자 구분)
{app="api"} |= "error"

# 포함 (대소문자 무시)
{app="api"} |~ "(?i)error"

# 미포함
{app="api"} != "health"

# 정규식 매칭
{app="api"} |~ "status=[45][0-9]{2}"

# 체이닝 (AND 조건)
{app="api"} |= "error" != "timeout" |~ "user_id=\\d+"
```

### 메트릭 쿼리
```logql
# 분당 에러 수
count_over_time({app="api"} |= "error" [1m])

# 에러율 (%)
sum(rate({app="api"} |= "error" [5m]))
  / sum(rate({app="api"} [5m])) * 100

# 레이블별 집계
sum by (status_code) (count_over_time({app="api"} | json [5m]))

# Top 10 에러 엔드포인트
topk(10, sum by (endpoint) (count_over_time({app="api"} |= "error" | json [1h])))
```

---

## 대시보드 구성

### 개발팀 대시보드
```
┌──────────────┬──────────────┬──────────────┐
│ Error Count  │ Error Rate % │ Slow Requests│
│  (실시간)    │   (5분)      │   (>1초)     │
├──────────────┴──────────────┴──────────────┤
│           Error Logs (실시간 스트림)         │
├──────────────────────────────────────────────┤
│           Endpoint별 에러 분포               │
└──────────────────────────────────────────────┘
```

**패널 쿼리**
```logql
# Error Count
sum(count_over_time({app=~"$app"} |= "error" [1m]))

# Slow Requests
count_over_time({app=~"$app"} | json | duration_ms > 1000 [5m])
```

### 보안팀 대시보드
```
┌──────────────┬──────────────┬──────────────┐
│ Bot Detected │ Login Failed │ PII Access   │
│   (1시간)    │   (1시간)    │   (1시간)    │
├──────────────┴──────────────┴──────────────┤
│        국가별/IP별 봇 탐지 히트맵            │
├────────────────────┬─────────────────────────┤
│  보안 이벤트 로그  │  의심 IP Top 10        │
└────────────────────┴─────────────────────────┘
```

---

## 알림 설정 (Grafana Alerting)

### 에러율 알림
```yaml
# 에러율 5% 초과 시
- alert: HighErrorRate
  expr: |
    sum(rate({app="order-service"} |= "error" [5m]))
    / sum(rate({app="order-service"} [5m])) * 100 > 5
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "High error rate: {{ $value }}%"
```

### 봇 공격 알림
```yaml
# 분당 봇 100건 초과
- alert: BotAttackDetected
  expr: |
    sum(count_over_time({app="bot-detector"} | json | is_bot="true" [1m])) > 100
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "Bot attack: {{ $value }} detections/min"
```

### 개인정보 대량 접근 알림
```yaml
# 단일 사용자 10건/분 초과 접근
- alert: SuspiciousPIIAccess
  expr: |
    max by (accessor) (
      sum(count_over_time({log_type="personal_info_access"} | json [1m])) by (accessor)
    ) > 10
  for: 1m
  labels:
    severity: high
```

---

## 고급 패턴

### Trace-Log 연계
```logql
# 1. 느린 trace 찾기 (Tempo에서)
# 2. trace_id로 전체 로그 조회
{namespace="production"} | json | trace_id="<TRACE_ID>"
  | line_format "{{.service}} {{.timestamp}} {{.message}}"
```

### 시계열 분석
```logql
# 시간별 트렌드
sum(count_over_time({app="api"} |= "error" [1h])) by (hour)

# 이전 기간 대비 (offset 사용)
count_over_time({app="api"} |= "error" [1h])
  / count_over_time({app="api"} |= "error" [1h] offset 1d) * 100 - 100
```

---

## 성능 최적화

### 쿼리 최적화
```
✅ 좋은 쿼리
───────────
{app="order-service", env="production"} |= "error"
→ 라벨로 먼저 필터, 그 후 텍스트 필터

❌ 나쁜 쿼리
───────────
{} |= "order-service" |= "error"
→ 모든 로그 스캔 후 필터 (매우 느림)
```

### 고카디널리티 주의
```
❌ 피해야 할 라벨
───────────────
- user_id (무한 증가)
- request_id (무한 증가)
- ip_address (높은 카디널리티)

✅ 사용해야 할 라벨
─────────────────
- app, service, namespace
- env (dev/staging/prod)
- level (error/warn/info)
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 빈 라벨 셀렉터 `{}` | 전체 스캔 | 라벨 먼저 지정 |
| 고카디널리티 라벨 | 인덱스 폭발 | 로그 본문에 포함 |
| 긴 시간 범위 | 타임아웃 | 시간 범위 축소 |
| 복잡한 정규식 | CPU 부하 | 단순 필터 우선 |

---

## 체크리스트

### 개발팀
- [ ] 에러 추적 쿼리 숙지
- [ ] trace_id 연계 검색
- [ ] 성능 분석 쿼리

### 보안팀
- [ ] 로그인/접근 분석 쿼리
- [ ] 봇 탐지 대시보드
- [ ] 개인정보 접근 모니터링
- [ ] 알림 규칙 설정

**관련 skill**: `/monitoring-logs`, `/logging-security`, `/logging-elk`

---

## 참고 자료
- [LogQL 공식 문서](https://grafana.com/docs/loki/latest/query/)
- [LogQL 쿼리 예제](https://grafana.com/docs/loki/latest/query/query_examples/)
- [Loki vs ELK 비교](https://signoz.io/blog/loki-vs-elasticsearch/)
