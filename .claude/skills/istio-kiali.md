# Istio Kiali Dashboard

Kiali 설치/설정, 서비스 토폴로지 시각화

## Quick Reference

```
Kiali 기능
    │
    ├─ Service Graph ─────> 실시간 트래픽 흐름 시각화
    │
    ├─ Traffic Animation ─> 요청 흐름 애니메이션
    │
    ├─ Health Status ─────> 서비스 상태 (정상/경고/오류)
    │
    ├─ Metrics ───────────> 서비스별 RED 메트릭
    │
    ├─ Traces ────────────> 분산 트레이싱 연동
    │
    └─ Istio Config ──────> 설정 검증 및 편집
```

---

## 설치 및 설정

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

---

## Ambient Mode 지원 현황 (2026.01)

```yaml
# Kiali 1.80+: Ambient Mode 기본 지원

제한사항:
- ztunnel 기반 그래프: L4 연결만 표시
- waypoint 없는 서비스: L7 상세 정보 없음
- 트레이싱: waypoint 배포 시에만

권장:
- L7 시각화 필요 시 waypoint 배포
- ztunnel 메트릭으로 기본 연결 확인
```

---

## 활용 가이드

### 서비스 그래프

- **노드 색상**: 헬스 상태 (녹색/노랑/빨강)
- **엣지 두께**: 트래픽 볼륨
- **엣지 색상**: 성공률 (녹색 = 100%, 빨강 = 에러 많음)

### 디버깅 워크플로우

1. Service Graph에서 빨간색 노드/엣지 확인
2. 해당 서비스 클릭 → Workloads 탭
3. Logs/Traces 확인
4. Istio Config 탭에서 설정 검증

---

## 체크리스트

- [ ] Prometheus/Grafana/Jaeger 연동
- [ ] Ambient 지원 버전 확인 (1.80+)
- [ ] 접근 권한 설정 (auth strategy)
- [ ] 네임스페이스 접근 범위 설정

**관련 skill**: `/istio-observability`, `/istio-core`, `/monitoring-grafana`
