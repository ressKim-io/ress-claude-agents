# Monitoring Troubleshooting Guide

알림 대응, 역할별 가이드, 트러블슈팅 패턴

## Quick Reference (결정 트리)

```
알림 우선순위
    │
    ├─ P1 Critical ─────> 즉시 대응 (5분 이내)
    │   └─ 서비스 다운, 에러율 > 5%
    │
    ├─ P2 Warning ──────> 업무시간 내 (4시간)
    │   └─ 에러율 > 1%, 지연 > 2초
    │
    └─ P3 Info ─────────> 일일 리뷰 (24시간)
        └─ 디스크 > 70%, 메모리 > 80%
```

---

## 역할별 모니터링 가이드

### 개발자 (Developer)

**봐야 할 skill:**
- `/observability` - 기본 로깅, 메트릭
- `/monitoring-grafana` - RED 대시보드

**주요 관심사:**
| 메트릭 | 정상 범위 | 알림 임계값 |
|--------|----------|------------|
| 에러율 | < 0.1% | > 1% |
| P95 응답시간 | < 200ms | > 500ms |
| 요청/초 | 베이스라인 ±20% | ±50% |

**주요 대시보드:** RED Dashboard
```promql
# 내 서비스 에러율
sum(rate(http_requests_total{service="$my_service",status=~"5.."}[5m]))
  / sum(rate(http_requests_total{service="$my_service"}[5m])) * 100
```

### DevOps/SRE

**봐야 할 skill:**
- `/monitoring-metrics` - Prometheus 스케일링
- `/monitoring-logs` - 로그 파이프라인
- `/monitoring-grafana` - 인프라 대시보드

**주요 관심사:**
| 메트릭 | 정상 범위 | 알림 임계값 |
|--------|----------|------------|
| CPU 사용률 | < 70% | > 85% |
| 메모리 사용률 | < 80% | > 90% |
| 디스크 사용률 | < 70% | > 85% |
| Pod 재시작 | 0 | > 3/시간 |

**주요 대시보드:** Infrastructure, SLO Dashboard

### 기획자/PM

**봐야 할 skill:**
- `/monitoring-grafana` (읽기 전용)

**주요 관심사:**
| 메트릭 | 의미 |
|--------|------|
| 가용성 (%) | 서비스 정상 시간 비율 |
| 에러 버짓 | 허용된 오류 예산 잔여량 |
| 월간 요청 수 | 서비스 사용량 |

**주요 대시보드:** Summary Dashboard (SLO 요약)

---

## CRITICAL: 알림 대응 프로세스

### P1 Critical 대응 플로우

```
알림 수신
    │
    ▼
┌─────────────────────────────────────┐
│ 1. 영향 범위 확인 (2분)              │
│    - 어떤 서비스가 영향받는가?        │
│    - 사용자 영향은?                  │
└─────────────────┬───────────────────┘
                  ▼
┌─────────────────────────────────────┐
│ 2. 최근 변경 확인 (1분)              │
│    - 최근 배포가 있었나?             │
│    - 설정 변경이 있었나?             │
└─────────────────┬───────────────────┘
                  ▼
          ┌───────┴───────┐
          │ 최근 배포 있음? │
          └───────┬───────┘
          YES     │     NO
          ▼       │     ▼
      롤백 실행    │   스케일업/재시작
          │       │     │
          └───────┼─────┘
                  ▼
┌─────────────────────────────────────┐
│ 3. 상태 확인 및 에스컬레이션          │
│    - 복구 확인                       │
│    - RCA 문서 작성                   │
└─────────────────────────────────────┘
```

### 영향 범위 파악 쿼리

```promql
# 영향받는 서비스 목록
sum by (service) (
  rate(http_requests_total{status=~"5.."}[5m])
) > 0

# 영향받는 사용자 수 (추정)
count(
  count by (user_id) (
    http_requests_total{status=~"5.."}
  )
)
```

---

## 일반적인 문제 및 해결

### 높은 에러율

**증상:** 에러율 > 5%

**진단:**
```promql
# 에러 분포 확인
sum by (status, endpoint) (
  rate(http_requests_total{status=~"5.."}[5m])
)
```

**해결:**
1. 특정 엔드포인트 문제 → 해당 코드 확인
2. 전체적 문제 → 최근 배포 롤백 검토
3. 외부 의존성 → 업스트림 서비스 확인

### 높은 지연시간

**증상:** P95 > 2초

**진단:**
```promql
# 느린 엔드포인트 확인
histogram_quantile(0.95,
  sum by (endpoint, le) (
    rate(http_request_duration_seconds_bucket[5m])
  )
)
```

**해결:**
1. DB 쿼리 확인 → 슬로우 쿼리 로그
2. 외부 API 지연 → 타임아웃/서킷브레이커
3. 리소스 부족 → 스케일업

### 메모리/CPU 급증

**증상:** 리소스 > 90%

**진단:**
```promql
# 상위 메모리 사용 Pod
topk(10,
  container_memory_usage_bytes{namespace="production"}
)
```

**해결:**
1. 메모리 릭 의심 → 힙 덤프 분석
2. 트래픽 급증 → HPA 확인/수동 스케일
3. 비효율적 코드 → 프로파일링

### 디스크 부족

**증상:** 디스크 사용률 > 85%

**진단:**
```bash
# 큰 파일/디렉토리 확인
du -sh /var/log/* | sort -rh | head -10
```

**해결:**
1. 로그 정리 → logrotate 확인
2. 임시 파일 정리 → /tmp, /var/cache
3. 볼륨 확장 → PVC resize

---

## 로그 기반 디버깅

### Grafana Explore 사용

```logql
# trace_id로 전체 요청 흐름 추적
{namespace="production"}
  | json
  | trace_id="abc123def456"

# 에러와 관련 컨텍스트 (전후 5줄)
{app="order-service"} |= "error"
```

### Trace-Log 연동

```
1. Grafana에서 Trace 확인 (Tempo)
2. Span 클릭 → "View Logs" 버튼
3. 해당 trace_id의 모든 로그 확인 (Loki)
```

---

## Grafana RBAC 빠른 설정

| 역할 | Org Role | 폴더 접근 | 권한 |
|------|----------|----------|------|
| 개발자 | Viewer | /Application | 읽기 |
| DevOps | Editor | 전체 | 편집 |
| SRE | Admin | 전체 | 관리 |
| PM | Viewer | /Summary | 읽기 |

### API로 권한 설정

```bash
# 팀에 폴더 Viewer 권한 부여
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {"teamId": 1, "permission": 1}
    ]
  }' \
  http://admin:admin@localhost:3000/api/folders/app/permissions
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 알림 무시 | 장애 확대 | 에스컬레이션 정책 |
| 로그 없이 디버깅 | 추측 기반 수정 | trace_id 기반 추적 |
| 롤백 주저 | 장애 시간 증가 | 빠른 롤백 원칙 |
| 혼자 대응 | 피로/실수 | 온콜 로테이션 |
| 문서화 안 함 | 같은 문제 반복 | RCA 필수 작성 |

---

## 체크리스트

### 알림 대응
- [ ] P1/P2/P3 분류 기준 숙지
- [ ] 에스컬레이션 경로 확인
- [ ] 롤백 절차 숙지

### 진단 도구
- [ ] Grafana 대시보드 접근
- [ ] 로그 쿼리 방법 숙지
- [ ] Trace 조회 방법 숙지

### 사후 처리
- [ ] RCA 템플릿 준비
- [ ] 장애 리뷰 일정 (24-48시간 내)
- [ ] 개선 항목 추적

**관련 skill**: `/monitoring-grafana`, `/monitoring-metrics`, `/monitoring-logs`
