# Istio Ambient Mode 심화 가이드

Ambient 아키텍처 상세, ztunnel, Waypoint 고급 설정, Cilium 통합, 모니터링

## CRITICAL: Ambient Mode 심화

### Ambient Mode 아키텍처 상세

```
+------------------------------------------------------------------+
|                   Istio Ambient Mode Architecture                  |
+------------------------------------------------------------------+
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |                        Control Plane                          | |
|  |  +---------+  +---------+  +---------+                       | |
|  |  | Istiod  |  | Istiod  |  | Istiod  |  (HA)                 | |
|  |  +----+----+  +----+----+  +----+----+                       | |
|  +-------+------------+------------+----------------------------+ |
|          | xDS        |            |                              |
|          v            v            v                              |
|  +--------------------------------------------------------------+ |
|  |                         Data Plane                            | |
|  |                                                                | |
|  |  Node 1                          Node 2                       | |
|  |  +--------------------+         +--------------------+       | |
|  |  | ztunnel (DaemonSet)|         | ztunnel (DaemonSet)|       | |
|  |  | - L4 mTLS          |         | - L4 mTLS          |       | |
|  |  | - TCP 프록시       |         | - TCP 프록시       |       | |
|  |  +--------+-----------+         +--------+-----------+       | |
|  |           |                              |                    | |
|  |  +--------v-----------+         +--------v-----------+       | |
|  |  |   Pod (Sidecar 無) |         |   Pod (Sidecar 無) |       | |
|  |  +--------------------+         +--------------------+       | |
|  |                                                                | |
|  |  Namespace with Waypoint:                                     | |
|  |  +-------------------------------------------------------------+ | |
|  |  | Waypoint Proxy (L7)                                      | | |
|  |  | - HTTP 라우팅                                            | | |
|  |  | - 트레이싱                                               | | |
|  |  | - 세밀한 정책                                            | | |
|  |  +-------------------------------------------------------------+ | |
|  +--------------------------------------------------------------+ |
+------------------------------------------------------------------+
```

### ztunnel 상세

```yaml
# ztunnel은 Istio 설치 시 자동 배포됨
# DaemonSet으로 각 노드에 하나씩 실행

# ztunnel 상태 확인
kubectl get pods -n istio-system -l app=ztunnel

# ztunnel 로그 확인
kubectl logs -n istio-system -l app=ztunnel -c istio-proxy

# ztunnel 메트릭
# - istio_tcp_connections_opened_total
# - istio_tcp_connections_closed_total
# - istio_tcp_sent_bytes_total
# - istio_tcp_received_bytes_total
```

### Waypoint 고급 설정

```yaml
# 서비스별 Waypoint (세밀한 제어)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: payment-waypoint
  namespace: production
  labels:
    istio.io/waypoint-for: service
  annotations:
    # 특정 서비스 어카운트에만 적용
    istio.io/for-service-account: payment-service
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
---
# Waypoint 리소스 설정
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: high-traffic-waypoint
  namespace: production
  labels:
    istio.io/waypoint-for: service
  annotations:
    proxy.istio.io/config: |
      concurrency: 4
      resources:
        requests:
          cpu: 200m
          memory: 256Mi
        limits:
          cpu: 1000m
          memory: 1Gi
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
```

### Ambient + L7 정책 적용

```yaml
# Waypoint가 있는 서비스에만 L7 정책 적용 가능

# AuthorizationPolicy (L7)
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: payment-authz
  namespace: production
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: payment-service
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/order-service"]
    to:
    - operation:
        methods: ["POST"]
        paths: ["/api/v1/payments"]
---
# RequestAuthentication (JWT)
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: production
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: api-gateway
  jwtRules:
  - issuer: "https://auth.example.com"
    jwksUri: "https://auth.example.com/.well-known/jwks.json"
```

### Cilium + Istio Ambient 통합

```yaml
# Cilium이 CNI로 설치된 환경에서 Ambient Mode 활성화

# 1. Cilium 설정 확인
cilium config view | grep -i "bpf"

# 2. Istio Ambient 설치 (Cilium 호환)
istioctl install --set profile=ambient \
  --set values.cni.provider=cilium

# 3. 통합 검증
# Cilium은 L3/L4 네트워크 정책
# Istio Ambient는 mTLS + L7 정책
# 두 시스템이 보완적으로 동작

# 주의사항:
# - Cilium eBPF 모드와 ztunnel 충돌 가능
# - 커널 버전 5.10+ 권장
# - 네트워크 정책 중복 확인 필요
```

### Ambient Mode 모니터링

```yaml
# Prometheus 쿼리 (ztunnel 메트릭)

# ztunnel 연결 수
sum(istio_tcp_connections_opened_total{reporter="ztunnel"}) by (destination_workload)

# L4 트래픽 볼륨
sum(rate(istio_tcp_sent_bytes_total{reporter="ztunnel"}[5m])) by (source_workload, destination_workload)

# Waypoint 메트릭 (L7)
sum(rate(istio_requests_total{reporter="waypoint"}[5m])) by (destination_service, response_code)

# Ambient vs Sidecar 비교 대시보드
# Grafana에서 reporter 라벨로 구분:
# - reporter="source" (Sidecar)
# - reporter="ztunnel" (Ambient L4)
# - reporter="waypoint" (Ambient L7)
```

### Ambient Mode 트러블슈팅

```bash
# 1. Ambient 적용 상태 확인
kubectl get namespace production -o yaml | grep -i ambient

# 2. ztunnel 연결 상태
kubectl exec -n istio-system $(kubectl get pod -n istio-system -l app=ztunnel -o jsonpath='{.items[0].metadata.name}') -- curl localhost:15020/healthz

# 3. Waypoint 상태 확인
kubectl get gateway -n production -l istio.io/waypoint-for

# 4. HBONE 연결 테스트
istioctl x waypoint status -n production

# 5. 트래픽 흐름 확인
# Ambient: Pod -> ztunnel -> (waypoint if L7) -> ztunnel -> Pod
kubectl logs -n istio-system -l app=ztunnel --tail=100 | grep "connection"
```

---

## Ambient Mode 체크리스트

### 마이그레이션 전
- [ ] Istio 버전 1.22+ 확인
- [ ] 커널 버전 5.8+ 확인 (eBPF 최적화)
- [ ] CNI 호환성 확인 (Cilium 주의)
- [ ] EnvoyFilter 사용 현황 분석

### 마이그레이션 중
- [ ] Namespace 레이블 전환
- [ ] Pod 재시작 (Sidecar 제거)
- [ ] L7 필요 서비스에 Waypoint 배포
- [ ] mTLS 연결 검증

### 마이그레이션 후
- [ ] 모니터링 대시보드 조정
- [ ] 알림 규칙 업데이트
- [ ] 성능/리소스 비교
- [ ] 문서 업데이트

---

**참조 스킬**: `/istio-core` (Sidecar vs Ambient 비교, mTLS 설정), `/istio-gateway`, `/istio-observability`, `/istio-security`, `/k8s-security`, `/ebpf-observability`
