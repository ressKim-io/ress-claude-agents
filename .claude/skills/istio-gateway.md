# Istio Gateway Patterns

Gateway API vs Istio Gateway 비교, 트래픽 라우팅 패턴

## Quick Reference

```
Gateway 선택
    │
    ├─ 신규 구축 ────────────────────> Gateway API (K8s 표준)
    │   └─ Istio 1.22+ 권장
    │
    ├─ 기존 Istio 환경 ──────────────> Istio Gateway 유지
    │   └─ 점진적 마이그레이션 고려
    │
    ├─ 멀티 구현체 이식성 필요 ──────> Gateway API
    │
    ├─ Istio 전용 기능 필수 ─────────> Istio Gateway + VirtualService
    │   └─ EnvoyFilter, 복잡한 매칭
    │
    └─ Ambient Mode ─────────────────> Gateway API 권장
```

---

## Istio Gateway (Classic)

### 아키텍처

```
┌──────────────────────────────────────────────────────────────┐
│  Istio Ingress Gateway                                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Gateway (리스너 정의)                                  │ │
│  │    ↓                                                    │ │
│  │  VirtualService (라우팅 규칙)                           │ │
│  │    ↓                                                    │ │
│  │  DestinationRule (트래픽 정책)                          │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Gateway + VirtualService 구성

```yaml
# Gateway: 외부 트래픽 진입점
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: api-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "api.example.com"
    - "*.api.example.com"
    tls:
      httpsRedirect: true  # HTTPS 리다이렉트
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "api.example.com"
    tls:
      mode: SIMPLE
      credentialName: api-tls-secret
---
# VirtualService: 라우팅 규칙
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-routes
  namespace: production
spec:
  hosts:
  - "api.example.com"
  gateways:
  - istio-system/api-gateway
  http:
  - match:
    - uri:
        prefix: /api/v1/users
    route:
    - destination:
        host: user-service
        port:
          number: 8080
  - match:
    - uri:
        prefix: /api/v1/orders
    route:
    - destination:
        host: order-service
        port:
          number: 8080
  - route:
    - destination:
        host: default-service
```

### TLS 종료

```yaml
# Secret 생성 (cert-manager 또는 수동)
apiVersion: v1
kind: Secret
metadata:
  name: api-tls-secret
  namespace: istio-system
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
# mTLS (클라이언트 인증서 요구)
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: mtls-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "secure.example.com"
    tls:
      mode: MUTUAL
      credentialName: mtls-credential
      # CA 인증서도 포함된 Secret 필요
```

---

## Gateway API (K8s Native)

### 아키텍처

```
┌──────────────────────────────────────────────────────────────┐
│  Kubernetes Gateway API                                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GatewayClass (구현체 정의)                             │ │
│  │    ↓                                                    │ │
│  │  Gateway (리스너 정의)                                  │ │
│  │    ↓                                                    │ │
│  │  HTTPRoute / GRPCRoute / TCPRoute                       │ │
│  │    ↓                                                    │ │
│  │  ReferenceGrant (Cross-namespace 허용)                  │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Gateway + HTTPRoute 구성

```yaml
# GatewayClass (보통 Istio가 자동 생성)
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: istio
spec:
  controllerName: istio.io/gateway-controller
---
# Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: api-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "api.example.com"
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "api.example.com"
    tls:
      mode: Terminate
      certificateRefs:
      - name: api-tls-secret
        kind: Secret
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            gateway-access: "true"
---
# HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api-routes
  namespace: production
spec:
  parentRefs:
  - name: api-gateway
    namespace: istio-system
  hostnames:
  - "api.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api/v1/users
    backendRefs:
    - name: user-service
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /api/v1/orders
    backendRefs:
    - name: order-service
      port: 8080
```

### ReferenceGrant (Cross-namespace)

```yaml
# production namespace의 리소스를 istio-system Gateway가 참조 허용
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-access
  namespace: production
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: istio-system
  to:
  - group: ""
    kind: Service
---
# Secret 참조 허용 (TLS 인증서)
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-tls-secret
  namespace: cert-manager
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: istio-system
  to:
  - group: ""
    kind: Secret
```

---

## CRITICAL: Gateway API vs Istio Gateway 비교표

| 항목 | Istio Gateway | Gateway API |
|------|---------------|-------------|
| **API 표준** | Istio 전용 CRD | K8s SIG 표준 |
| **이식성** | Istio only | 멀티 구현체 (Istio, Envoy Gateway, Kong, etc.) |
| **구조** | Gateway + VirtualService | Gateway + HTTPRoute |
| **Cross-namespace** | 암묵적 허용 | ReferenceGrant 명시 필요 |
| **TLS 설정** | credentialName | certificateRefs |
| **Header 매칭** | 강력 (정규식 등) | 표준 기능 |
| **Weight 라우팅** | VirtualService에서 | HTTPRoute backendRefs |
| **성숙도** | 5년+ 검증 | GA (v1) 2023 |
| **Ambient 호환** | 지원 | **권장** |
| **권장** | 기존 환경 유지 | **신규 구축** |

### 기능 매핑

```yaml
# Istio Gateway → Gateway API 매핑

# 1. 기본 라우팅
VirtualService.http.match.uri → HTTPRoute.rules.matches.path
VirtualService.http.route     → HTTPRoute.rules.backendRefs

# 2. 헤더 기반 라우팅
VirtualService.http.match.headers → HTTPRoute.rules.matches.headers

# 3. 가중치 라우팅
VirtualService.http.route[].weight → HTTPRoute.rules.backendRefs[].weight

# 4. 리다이렉트
VirtualService.http.redirect → HTTPRoute.rules.filters[].type: RequestRedirect

# 5. 리라이트
VirtualService.http.rewrite → HTTPRoute.rules.filters[].type: URLRewrite
```

---

## 트래픽 관리 패턴

### Canary 배포

```yaml
# Istio Gateway 방식
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary-route
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
        subset: stable
      weight: 90
    - destination:
        host: my-service
        subset: canary
      weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-service-versions
spec:
  host: my-service
  subsets:
  - name: stable
    labels:
      version: v1
  - name: canary
    labels:
      version: v2
```

```yaml
# Gateway API 방식
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary-route
spec:
  parentRefs:
  - name: api-gateway
  rules:
  - backendRefs:
    - name: my-service-v1
      port: 8080
      weight: 90
    - name: my-service-v2
      port: 8080
      weight: 10
```

### A/B Testing (헤더 기반)

```yaml
# Istio Gateway 방식
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ab-testing
spec:
  hosts:
  - my-service
  http:
  # Feature flag 헤더로 분기
  - match:
    - headers:
        x-feature-flag:
          exact: "new-checkout"
    route:
    - destination:
        host: my-service
        subset: feature-checkout
  # 기본
  - route:
    - destination:
        host: my-service
        subset: stable
```

```yaml
# Gateway API 방식
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ab-testing
spec:
  parentRefs:
  - name: api-gateway
  rules:
  - matches:
    - headers:
      - name: x-feature-flag
        value: "new-checkout"
    backendRefs:
    - name: my-service-feature
      port: 8080
  - backendRefs:
    - name: my-service-stable
      port: 8080
```

### Traffic Mirroring

```yaml
# Istio Gateway 방식 (VirtualService)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mirror-traffic
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
        subset: stable
    mirror:
      host: my-service
      subset: shadow
    mirrorPercentage:
      value: 100.0
```

```yaml
# Gateway API 방식 (RequestMirror filter)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mirror-traffic
spec:
  parentRefs:
  - name: api-gateway
  rules:
  - filters:
    - type: RequestMirror
      requestMirror:
        backendRef:
          name: my-service-shadow
          port: 8080
    backendRefs:
    - name: my-service-stable
      port: 8080
```

### Timeout & Retry

```yaml
# Istio Gateway 방식
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: timeout-retry
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: 5xx,reset,connect-failure
```

```yaml
# Gateway API 방식 (Istio 확장)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: timeout-retry
  annotations:
    # Istio 확장 annotation
    retry.istio.io/attempts: "3"
    retry.istio.io/per-try-timeout: "3s"
spec:
  parentRefs:
  - name: api-gateway
  rules:
  - backendRefs:
    - name: my-service
      port: 8080
    timeouts:
      request: 10s
```

---

## 마이그레이션 가이드

### Istio Gateway → Gateway API

```bash
# 1. Gateway API CRD 설치 확인
kubectl get crd gateways.gateway.networking.k8s.io

# 2. GatewayClass 확인
kubectl get gatewayclass

# 3. 점진적 전환
# - 새 Gateway API 리소스 생성
# - 트래픽 일부 전환
# - 검증 후 기존 리소스 제거
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| Gateway API에서 VirtualService 사용 | 혼용 시 충돌 | 하나만 선택 |
| ReferenceGrant 누락 | Cross-namespace 라우팅 실패 | ReferenceGrant 생성 |
| 모든 Namespace에서 Gateway 접근 | 보안 위험 | allowedRoutes 제한 |
| TLS Secret 다른 namespace | 참조 불가 | 같은 namespace 또는 ReferenceGrant |
| weight 합계 != 100 | 예상치 못한 분배 | 정확히 100으로 |

---

## 체크리스트

### Istio Gateway
- [ ] Gateway selector 확인
- [ ] TLS Secret 같은 namespace
- [ ] VirtualService hosts 매칭
- [ ] DestinationRule subset 정의

### Gateway API
- [ ] GatewayClass 존재 확인
- [ ] allowedRoutes 설정
- [ ] ReferenceGrant (cross-namespace)
- [ ] parentRefs 정확히 지정

### 공통
- [ ] TLS 인증서 갱신 자동화
- [ ] 트래픽 분배 테스트
- [ ] 롤백 계획 수립

**관련 skill**: `/istio-core`, `/istio-observability`, `/k8s-traffic`
