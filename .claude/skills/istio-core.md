# Istio Core Patterns

Istio Service Mesh 핵심 개념: Sidecar vs Ambient 모드 비교 및 선택 가이드

## Quick Reference

```
Istio 모드 선택
    │
    ├─ L7 기능 필수 (트레이싱, 세밀한 라우팅) ───> Sidecar Mode
    │
    ├─ 리소스 효율성 우선 ─────────────────────> Ambient Mode
    │   └─ L7 필요 시 ───> waypoint 배포
    │
    ├─ 레거시 앱 (Sidecar 주입 불가) ──────────> Ambient Mode
    │
    ├─ 모니터링 상세도 중요 ───────────────────> Sidecar Mode
    │
    └─ 신규 구축 + 2026 이후 ─────────────────> Ambient Mode 권장
```

---

## Sidecar Mode

### 아키텍처

```
┌─────────────────────────────────────────────────────┐
│  Pod                                                │
│  ┌─────────────────┐    ┌─────────────────┐        │
│  │  Application    │◄──►│  Envoy Proxy    │◄──────►│ 외부
│  │  Container      │    │  (Sidecar)      │        │
│  └─────────────────┘    └─────────────────┘        │
│                                │                    │
│                                ▼                    │
│                         mTLS, L7 정책               │
└─────────────────────────────────────────────────────┘
```

### Sidecar Injection 설정

```yaml
# Namespace 레벨 자동 주입
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: enabled
---
# Pod 레벨 제어
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    # 주입 비활성화
    sidecar.istio.io/inject: "false"

    # 리소스 커스터마이징
    sidecar.istio.io/proxyCPU: "100m"
    sidecar.istio.io/proxyMemory: "128Mi"
    sidecar.istio.io/proxyCPULimit: "500m"
    sidecar.istio.io/proxyMemoryLimit: "512Mi"
```

### Sidecar 리소스 스코핑

```yaml
# 불필요한 설정 수신 제한 (메모리 절약)
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: production
spec:
  workloadSelector:
    labels:
      app: my-app
  egress:
  - hosts:
    - "./*"                    # 같은 namespace만
    - "istio-system/*"         # istio-system
    - "*/payment-service.svc"  # 특정 서비스
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY  # 등록된 서비스만 허용
```

---

## Ambient Mode

### 아키텍처

```
Node Level (ztunnel)                    Namespace Level (waypoint)
┌─────────────────────────────────────────────────────────────────┐
│  Node                                                           │
│  ┌──────────────┐                                               │
│  │   ztunnel    │◄─────── L4 mTLS, 암호화                       │
│  │  (DaemonSet) │                                               │
│  └──────┬───────┘                                               │
│         │                                                       │
│  ┌──────▼───────┐     ┌─────────────────┐                      │
│  │     Pod      │────►│    Waypoint     │◄─── L7 정책 필요 시   │
│  │ (Sidecar 無) │     │   (선택적)      │                      │
│  └──────────────┘     └─────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

### Ambient 활성화

```yaml
# Namespace에 Ambient 적용
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio.io/dataplane-mode: ambient
---
# Waypoint 배포 (L7 기능 필요 시)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: production-waypoint
  namespace: production
  labels:
    istio.io/waypoint-for: service  # 또는 workload
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
```

### Waypoint 세부 설정

```yaml
# Service Account별 Waypoint
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: payment-waypoint
  namespace: production
  labels:
    istio.io/waypoint-for: service
  annotations:
    # 리소스 설정
    proxy.istio.io/config: |
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
    allowedRoutes:
      namespaces:
        from: Same
```

---

## CRITICAL: Sidecar vs Ambient 비교표

| 항목 | Sidecar Mode | Ambient Mode |
|------|-------------|--------------|
| **아키텍처** | Pod당 Envoy Sidecar | Node당 ztunnel + waypoint |
| **리소스** | Pod당 ~50-100MB | **70% 절감 가능** |
| **L4 mTLS** | Sidecar에서 처리 | ztunnel에서 처리 |
| **L7 정책** | 직접 적용 | **waypoint 배포 필요** |
| **모니터링 상세도** | Pod별 상세 메트릭 | **Node/waypoint 레벨** |
| **트레이싱** | 자동 Span 생성 | **ztunnel은 L4만** |
| **성숙도** | 5년+ 검증 | 2024 GA, 발전 중 |
| **앱 변경** | 재배포 필요 | 무중단 적용 |
| **디버깅** | Pod별 명확 | 상대적 복잡 |
| **Startup 지연** | Sidecar 초기화 대기 | 없음 |

### 성능 비교 (실측 기반)

```yaml
# Sidecar Mode
리소스:
  평균 Pod: +80MB 메모리, +50m CPU
  1000 Pod 클러스터: ~80GB 추가 메모리
지연시간:
  P50: +1ms
  P99: +3ms

# Ambient Mode
리소스:
  Node당 ztunnel: ~50MB
  waypoint (L7용): ~100MB
  1000 Pod / 10 Node: ~500MB + waypoint
지연시간:
  L4만: +0.5ms
  L7 (waypoint): +2ms
```

---

## CRITICAL: Ambient Mode 제한사항 (2026.01)

### 미지원/제한 기능

| 기능 | 상태 | 대안 |
|------|------|------|
| **EnvoyFilter** | 미지원 | waypoint용 별도 설정 필요 |
| **Lua Filter** | 미지원 | WasmPlugin 사용 |
| **일부 AuthorizationPolicy** | 제한적 | waypoint 배포 시 L7 가능 |
| **RequestAuthentication (L7)** | waypoint 필요 | L7 정책은 waypoint에서 |
| **Traffic Mirroring** | 제한적 | waypoint 필요 |
| **Fault Injection** | waypoint 필요 | L7 기능 |
| **Custom Headers** | waypoint 필요 | L7 기능 |

### 모니터링 관점 제한

```yaml
# Sidecar Mode에서 가능한 것
- Pod별 상세 메트릭 (istio_requests_total per pod)
- 자동 분산 트레이싱 Span
- Pod 레벨 Access Log

# Ambient Mode 제한
- ztunnel: L4 메트릭만 (TCP 연결, 바이트)
- 트레이싱: waypoint 배포 시에만 L7 Span
- Access Log: ztunnel/waypoint 레벨
```

### 워크로드 호환성

```yaml
# Ambient 호환 확인
지원:
  - 일반 Deployment/StatefulSet
  - Kubernetes Service 통한 통신

제한:
  - hostNetwork: true Pod
  - initContainer 네트워킹 의존
  - 일부 CNI 플러그인 (Calico eBPF 등 확인 필요)
```

---

## 마이그레이션 가이드

### Sidecar → Ambient

```yaml
# Step 1: 준비
# Ambient 지원 Istio 버전 확인 (1.22+)
istioctl version

# Step 2: Namespace 단위 전환
# 기존 Sidecar 레이블 제거
kubectl label namespace production istio-injection-

# Ambient 활성화
kubectl label namespace production istio.io/dataplane-mode=ambient

# Step 3: Pod 재시작 (Sidecar 제거)
kubectl rollout restart deployment -n production

# Step 4: L7 기능 필요 시 waypoint 배포
istioctl waypoint apply -n production --enroll-namespace

# Step 5: 검증
istioctl analyze -n production
```

### Gradual Migration

```yaml
# Namespace 단위 점진적 전환
Phase 1: staging → Ambient
Phase 2: 모니터링 확인 (1주)
Phase 3: production non-critical → Ambient
Phase 4: production critical (신중히)

# 롤백 옵션
kubectl label namespace production istio.io/dataplane-mode-
kubectl label namespace production istio-injection=enabled
kubectl rollout restart deployment -n production
```

---

## 하이브리드 구성

```yaml
# 동일 클러스터에서 혼용
Namespace A: Sidecar Mode (레거시, 상세 모니터링 필요)
Namespace B: Ambient Mode (신규, 리소스 효율)

# 통신 가능
- Sidecar ↔ Ambient: mTLS 자동 협상
- 제한: Cross-namespace L7 정책 시 주의
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| Ambient에서 L7 정책 기대 | 적용 안됨 | waypoint 배포 |
| 모든 앱에 waypoint | 리소스 낭비 | L7 필요한 서비스만 |
| EnvoyFilter 마이그레이션 누락 | 설정 유실 | WasmPlugin 전환 |
| 모니터링 변경 미고려 | 메트릭 손실 | 대시보드 조정 |
| hostNetwork Pod 포함 | 동작 안함 | 해당 Pod 제외 |

---

## 체크리스트

### Sidecar Mode
- [ ] Namespace 레이블 설정
- [ ] 리소스 limit 설정
- [ ] Sidecar 스코핑 (필요 시)
- [ ] Startup probe 조정

### Ambient Mode
- [ ] Istio 버전 확인 (1.22+)
- [ ] CNI 호환성 확인
- [ ] Namespace 레이블 변경
- [ ] L7 필요 서비스에 waypoint 배포
- [ ] 모니터링 대시보드 조정

### 마이그레이션
- [ ] 기능 매핑 검토 (EnvoyFilter 등)
- [ ] 단계별 전환 계획
- [ ] 롤백 계획 수립
- [ ] 모니터링 알림 조정

---

## CRITICAL: mTLS 강제 설정

### Namespace STRICT mTLS

```yaml
# 네임스페이스 전체에 mTLS 강제
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # 모든 트래픽 mTLS 필수
```

### 메시 전체 STRICT mTLS

```yaml
# 전체 메시에 mTLS 강제 (istio-system에 적용)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

### 특정 포트 예외 (메트릭 수집)

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: metrics-exception
  namespace: production
spec:
  selector:
    matchLabels:
      app: my-service
  mtls:
    mode: STRICT
  portLevelMtls:
    9090:  # Prometheus 메트릭 포트
      mode: PERMISSIVE
```

### mTLS 마이그레이션 단계

```
1. PERMISSIVE 모드로 시작 (기존 트래픽 유지)
   │
2. Kiali에서 mTLS 적용 현황 확인
   │
3. 모든 서비스에 Sidecar 주입 완료 확인
   │
4. STRICT 모드로 전환
   │
5. 문제 발생 시 PERMISSIVE로 롤백
```

### mTLS 상태 확인

```bash
# istioctl로 mTLS 상태 확인
istioctl authn tls-check <pod-name> -n <namespace>

# PeerAuthentication 목록
kubectl get peerauthentication -A

# 특정 Pod의 mTLS 설정 확인
istioctl x describe pod <pod-name> -n <namespace>
```

상세한 Istio 보안 설정은 `/istio-security` 스킬 참조

---

## CRITICAL: Ambient Mode 심화

### Ambient Mode 아키텍처 상세

```
+------------------------------------------------------------------+
|                   Istio Ambient Mode Architecture                  |
+------------------------------------------------------------------+
|                                                                    |
|  ┌──────────────────────────────────────────────────────────────┐ |
|  │                        Control Plane                          │ |
|  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                       │ |
|  │  │ Istiod  │  │ Istiod  │  │ Istiod  │  (HA)                 │ |
|  │  └────┬────┘  └────┬────┘  └────┬────┘                       │ |
|  └───────┼────────────┼────────────┼────────────────────────────┘ |
|          │ xDS        │            │                              |
|          ▼            ▼            ▼                              |
|  ┌──────────────────────────────────────────────────────────────┐ |
|  │                         Data Plane                            │ |
|  │                                                                │ |
|  │  Node 1                          Node 2                       │ |
|  │  ┌────────────────────┐         ┌────────────────────┐       │ |
|  │  │ ztunnel (DaemonSet)│         │ ztunnel (DaemonSet)│       │ |
|  │  │ - L4 mTLS          │         │ - L4 mTLS          │       │ |
|  │  │ - TCP 프록시       │         │ - TCP 프록시       │       │ |
|  │  └────────┬───────────┘         └────────┬───────────┘       │ |
|  │           │                              │                    │ |
|  │  ┌────────▼───────────┐         ┌────────▼───────────┐       │ |
|  │  │   Pod (Sidecar 無) │         │   Pod (Sidecar 無) │       │ |
|  │  └────────────────────┘         └────────────────────┘       │ |
|  │                                                                │ |
|  │  Namespace with Waypoint:                                     │ |
|  │  ┌─────────────────────────────────────────────────────────┐ │ |
|  │  │ Waypoint Proxy (L7)                                      │ │ |
|  │  │ - HTTP 라우팅                                            │ │ |
|  │  │ - 트레이싱                                               │ │ |
|  │  │ - 세밀한 정책                                            │ │ |
|  │  └─────────────────────────────────────────────────────────┘ │ |
|  └──────────────────────────────────────────────────────────────┘ |
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

**관련 skill**: `/istio-gateway`, `/istio-observability`, `/istio-security`, `/k8s-security`, `/ebpf-observability`
