# Linkerd Service Mesh 가이드

Linkerd v2.17 핵심 운영 가이드: Rust micro-proxy 기반 경량 서비스 메시, 자동 mTLS, 멀티클러스터, Gateway API 통합

## Quick Reference (결정 트리)

```
Service Mesh 선택?
    |
    +-- 최소 레이턴시 / 경량 우선 ---------> Linkerd (0.9ms p99)
    |       |
    |       +-- mTLS만 필요 ---------------> Linkerd (zero-config)
    |       +-- L7 라우팅 필요 ------------> Linkerd HTTPRoute
    |       +-- 멀티클러스터 연동 ---------> Linkerd Multi-cluster
    |
    +-- 복잡한 L7 정책 / Wasm 필요 -------> Istio
    |
    +-- 기존 Envoy 투자 -----------------> Istio Ambient
    |
    +-- 간단한 mTLS + 최소 운영 ---------> Linkerd (권장)

Linkerd 기능 선택?
    |
    +-- 기본 보안 (mTLS) -----------------> linkerd inject (기본)
    |
    +-- 트래픽 관리 ----------------------> HTTPRoute + ServiceProfile
    |
    +-- 카나리 배포 ----------------------> SMI TrafficSplit
    |
    +-- 멀티클러스터 ---------------------> Link CRD + Gateway
    |
    +-- 관찰성 대시보드 -----------------> linkerd viz install
```

---

## CRITICAL: Linkerd 아키텍처

### Linkerd2-proxy (Rust Micro-Proxy)

```
+------------------------------------------------------------------+
|                   Linkerd Control Plane                            |
|  +-------------+  +--------------+  +------------------+          |
|  | destination |  | identity     |  | proxy-injector   |          |
|  | (서비스     |  | (mTLS 인증서 |  | (Sidecar 자동    |          |
|  |  디스커버리)|  |  자동 발급)  |  |  주입)           |          |
|  +------+------+  +------+-------+  +--------+---------+          |
+---------+----------------+--------------------+-------------------+
          |                |                    |
          v                v                    v
+------------------------------------------------------------------+
|                   Data Plane (Per Pod)                             |
|                                                                    |
|  +--------------------+     +-----------------------------+       |
|  |  Application       |<--->|  linkerd2-proxy (Rust)      |       |
|  |  Container         |     |  - 자동 mTLS               |       |
|  +--------------------+     |  - L7 메트릭               |       |
|                             |  - 로드 밸런싱 (EWMA)      |       |
|                             |  - Retry / Timeout          |       |
|                             +-----------------------------+       |
|                                                                    |
|  메모리: ~10-20MB per proxy  |  레이턴시: < 1ms p99              |
+------------------------------------------------------------------+
```

### Istio Envoy vs Linkerd2-proxy 아키텍처 비교

```
Istio (Envoy)                    Linkerd (linkerd2-proxy)
+-------------------+            +-------------------+
| C++ / 범용 프록시 |            | Rust / 전용 프록시|
| ~50-100MB 메모리  |            | ~10-20MB 메모리   |
| 풍부한 필터 체인  |            | 최적화된 핵심 기능|
| xDS 프로토콜      |            | gRPC 디스커버리   |
| Wasm 확장 지원    |            | 확장 제한적       |
+-------------------+            +-------------------+
```

---

## CRITICAL: Linkerd vs Istio Ambient 상세 비교

| 항목 | Linkerd v2.17 | Istio Ambient |
|------|---------------|---------------|
| **프록시** | linkerd2-proxy (Rust) | ztunnel + waypoint (Envoy) |
| **P99 레이턴시** | **~0.9ms** | 3-10ms |
| **Control Plane 메모리** | **~200MB** | 1-2GB |
| **Sidecar 메모리** | ~10-20MB/pod | ztunnel ~50MB/node |
| **mTLS** | 자동 (zero-config) | 자동 (ztunnel) |
| **L7 정책** | HTTPRoute, ServiceProfile | waypoint 배포 필요 |
| **Wasm 확장** | 미지원 | 지원 |
| **멀티클러스터** | Link CRD (간단) | 복잡한 설정 |
| **Gateway API** | v1.2 지원 | v1.2 지원 |
| **CNCF** | Graduated | Graduated |
| **설치 복잡도** | `linkerd install` (2분) | `istioctl install` (5-10분) |
| **학습 곡선** | 낮음 | 높음 |
| **커뮤니티** | Buoyant 주도 | Google/Solo.io 주도 |
| **EnvoyFilter 호환** | 해당 없음 | 지원 |

### 성능 벤치마크 (실측 기반)

```yaml
# 테스트 환경: 3 Node, 100 서비스, 1000 RPS
Linkerd v2.17:
  P50 레이턴시: 0.4ms
  P99 레이턴시: 0.9ms
  Control Plane 메모리: 200MB
  Proxy 메모리 (전체): 2GB (100 Pod x 20MB)
  설치 시간: 2분

Istio Ambient:
  P50 레이턴시 (L4): 1.5ms
  P99 레이턴시 (L7 waypoint): 5-10ms
  Control Plane 메모리: 1.5GB
  ztunnel 메모리 (전체): 150MB (3 Node x 50MB)
  waypoint 메모리: 300MB (3 waypoint x 100MB)
  설치 시간: 5-10분

# 결론: 순수 성능 = Linkerd, 확장성/기능 = Istio
```

---

## 설치 및 기본 설정

### CLI 설치

```bash
# Linkerd CLI 설치
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$HOME/.linkerd2/bin:$PATH

# 버전 확인
linkerd version

# 클러스터 사전 검증 (필수!)
linkerd check --pre
```

### Control Plane 설치

```bash
# CRD 먼저 설치
linkerd install --crds | kubectl apply -f -

# Control Plane 설치
linkerd install | kubectl apply -f -

# 설치 검증 (모든 체크 통과 확인)
linkerd check

# Helm으로 설치 (프로덕션 권장)
helm repo add linkerd-edge https://helm.linkerd.io/edge
helm repo add linkerd https://helm.linkerd.io/stable

helm install linkerd-crds linkerd/linkerd-crds -n linkerd --create-namespace
helm install linkerd-control-plane linkerd/linkerd-control-plane \
  -n linkerd \
  --set identity.externalCA=true \
  --set identity.issuer.scheme=kubernetes.io/tls
```

### 프로덕션 인증서 설정

```bash
# step CLI로 Root CA 생성 (프로덕션 필수)
step certificate create root.linkerd.cluster.local ca.crt ca.key \
  --profile root-ca --no-password --insecure --not-after=87600h

# Issuer 인증서 생성
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
  --profile intermediate-ca --not-after=8760h --no-password --insecure \
  --ca ca.crt --ca-key ca.key

# 인증서로 설치
linkerd install \
  --identity-trust-anchors-file ca.crt \
  --identity-issuer-certificate-file issuer.crt \
  --identity-issuer-key-file issuer.key \
  | kubectl apply -f -
```

---

## CRITICAL: 자동 mTLS (Zero-Config)

### Namespace 레벨 Injection

```yaml
# Namespace에 Linkerd 프록시 자동 주입 활성화
apiVersion: v1
kind: Namespace
metadata:
  name: production
  annotations:
    linkerd.io/inject: enabled
---
# 특정 Pod에서 주입 비활성화
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
  annotations:
    linkerd.io/inject: disabled
```

### Deployment 레벨 Injection

```yaml
# Deployment에 직접 annotation 추가
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: production
spec:
  template:
    metadata:
      annotations:
        linkerd.io/inject: enabled
        # 프록시 리소스 커스터마이징
        config.linkerd.io/proxy-cpu-request: "100m"
        config.linkerd.io/proxy-cpu-limit: "500m"
        config.linkerd.io/proxy-memory-request: "20Mi"
        config.linkerd.io/proxy-memory-limit: "128Mi"
    spec:
      containers:
      - name: order-service
        image: order-service:v1.2.0
        ports:
        - containerPort: 8080
```

### CLI로 수동 Injection

```bash
# 기존 Deployment에 프록시 주입
kubectl get deploy order-service -n production -o yaml \
  | linkerd inject - \
  | kubectl apply -f -

# Namespace 전체 주입
kubectl get deploy -n production -o yaml \
  | linkerd inject - \
  | kubectl apply -f -

# mTLS 상태 확인
linkerd edges -n production
linkerd identity -n production
```

### mTLS 동작 확인

```bash
# 메시 내 mTLS 연결 확인
linkerd viz edges po -n production

# 출력 예시:
# SRC          DST              SRC_P  DST_P  SECURED
# order-svc    payment-svc      -      -      TRUE
# order-svc    inventory-svc    -      -      TRUE
```

---

## HTTPRoute 기반 트래픽 관리

### Rate Limiting with HTTPRoute Policy

```yaml
# Gateway API HTTPRoute로 라우팅 + 정책 정의
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: order-route
  namespace: production
spec:
  parentRefs:
  - name: order-service
    kind: Service
    group: core
    port: 8080
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api/orders
    backendRefs:
    - name: order-service
      port: 8080
---
# Server 리소스로 Rate Limiting 설정
apiVersion: policy.linkerd.io/v1beta3
kind: Server
metadata:
  name: order-server
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: order-service
  port: 8080
  proxyProtocol: HTTP/2
---
# HTTPLocalRateLimitPolicy로 Rate Limit 적용
apiVersion: policy.linkerd.io/v1alpha1
kind: HTTPLocalRateLimitPolicy
metadata:
  name: order-rate-limit
  namespace: production
spec:
  targetRef:
    group: core
    kind: Server
    name: order-server
  total:
    requestsPerSecond: 1000
  identity:
    requestsPerSecond: 100
  overrides:
  - requestsPerSecond: 500
    clientRefs:
    - kind: ServiceAccount
      name: vip-client
      namespace: production
```

### Authorization Policy

```yaml
# 서비스 간 접근 제어 (mTLS Identity 기반)
apiVersion: policy.linkerd.io/v1alpha1
kind: AuthorizationPolicy
metadata:
  name: order-authz
  namespace: production
spec:
  targetRef:
    group: policy.linkerd.io
    kind: Server
    name: order-server
  requiredAuthenticationRefs:
  - name: order-mesh-authn
    kind: MeshTLSAuthentication
    group: policy.linkerd.io
---
apiVersion: policy.linkerd.io/v1alpha1
kind: MeshTLSAuthentication
metadata:
  name: order-mesh-authn
  namespace: production
spec:
  identities:
  - "*.production.serviceaccount.identity.linkerd.cluster.local"
  # 특정 서비스만 허용
  identityRefs:
  - kind: ServiceAccount
    name: api-gateway
  - kind: ServiceAccount
    name: frontend
```

---

## ServiceProfile (Per-Route 메트릭 / 재시도)

```yaml
# ServiceProfile로 경로별 메트릭, 재시도, 타임아웃 설정
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: order-service.production.svc.cluster.local
  namespace: production
spec:
  routes:
  - name: POST /api/orders
    condition:
      method: POST
      pathRegex: /api/orders
    responseClasses:
    - condition:
        status:
          min: 500
          max: 599
      isFailure: true
    # 멱등성 보장 시에만 재시도 활성화
    isRetryable: false
    timeout: 3s

  - name: GET /api/orders/{id}
    condition:
      method: GET
      pathRegex: /api/orders/[^/]+
    responseClasses:
    - condition:
        status:
          min: 500
          max: 599
      isFailure: true
    isRetryable: true
    timeout: 1s

  retryBudget:
    retryRatio: 0.2        # 전체 요청의 20%까지 재시도 허용
    minRetriesPerSecond: 10
    ttl: 10s
```

### ServiceProfile 자동 생성

```bash
# Swagger/OpenAPI에서 자동 생성
linkerd profile --open-api swagger.json order-service \
  -n production | kubectl apply -f -

# Protobuf에서 자동 생성
linkerd profile --proto order.proto order-service \
  -n production | kubectl apply -f -

# 경로별 메트릭 확인
linkerd viz routes -n production deploy/order-service
```

---

## SMI TrafficSplit (카나리 배포)

```yaml
# SMI TrafficSplit으로 가중치 기반 트래픽 분할
apiVersion: split.smi-spec.io/v1alpha4
kind: TrafficSplit
metadata:
  name: order-canary
  namespace: production
spec:
  service: order-service          # 루트 서비스 (클라이언트가 호출하는 대상)
  backends:
  - service: order-service-stable  # 안정 버전 (90%)
    weight: 900
  - service: order-service-canary  # 카나리 버전 (10%)
    weight: 100
---
# Stable 서비스
apiVersion: v1
kind: Service
metadata:
  name: order-service-stable
  namespace: production
spec:
  selector:
    app: order-service
    version: v1
  ports:
  - port: 8080
---
# Canary 서비스
apiVersion: v1
kind: Service
metadata:
  name: order-service-canary
  namespace: production
spec:
  selector:
    app: order-service
    version: v2
  ports:
  - port: 8080
```

### Flagger 연동 자동 카나리

```yaml
# Flagger + Linkerd 자동 카나리 배포
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: order-service
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-service
  service:
    port: 8080
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500     # 500ms 이하
      interval: 1m
```

---

## Linkerd Viz 대시보드

### 설치 및 접근

```bash
# Viz 확장 설치 (Prometheus + 대시보드)
linkerd viz install | kubectl apply -f -

# 설치 검증
linkerd check

# 대시보드 접근
linkerd viz dashboard &

# CLI로 실시간 메트릭 확인
linkerd viz top deploy -n production
linkerd viz stat deploy -n production
linkerd viz routes deploy/order-service -n production

# 실시간 트래픽 tap (디버깅)
linkerd viz tap deploy/order-service -n production
linkerd viz tap deploy/order-service -n production \
  --path /api/orders --method POST
```

### Viz Prometheus 메트릭

```yaml
# Linkerd가 자동 수집하는 핵심 메트릭
골든 시그널:
  - request_total          # 요청 수
  - response_latency_ms    # 레이턴시 (히스토그램)
  - response_total         # 응답 수 (status code별)

# Prometheus 쿼리 예시
# 성공률
sum(rate(response_total{classification="success",namespace="production"}[5m]))
/
sum(rate(response_total{namespace="production"}[5m]))

# P99 레이턴시
histogram_quantile(0.99,
  sum(rate(response_latency_ms_bucket{namespace="production"}[5m])) by (le, deployment)
)

# 요청 처리량
sum(rate(request_total{namespace="production"}[5m])) by (deployment)
```

### Grafana 대시보드 연동

```bash
# 외부 Prometheus/Grafana와 연동
linkerd viz install \
  --set prometheus.enabled=false \
  --set prometheusUrl=http://prometheus.monitoring:9090 \
  --set grafana.externalUrl=http://grafana.monitoring:3000 \
  | kubectl apply -f -
```

---

## CRITICAL: 멀티클러스터 설정

### 아키텍처

```
+---------------------+          +---------------------+
|    Cluster West     |          |    Cluster East     |
|                     |          |                     |
|  +---------------+  |   Link   |  +---------------+  |
|  | order-service |--+---CRD----+->| order-service |  |
|  +---------------+  |          |  +---------------+  |
|                     |          |                     |
|  +---------------+  |  mTLS    |  +---------------+  |
|  | linkerd-      |<-+--Gateway-+->| linkerd-      |  |
|  | gateway       |  |          |  | gateway       |  |
|  +---------------+  |          |  +---------------+  |
|                     |          |                     |
|  Shared Trust Root  |          |  Shared Trust Root  |
+---------------------+          +---------------------+
```

### 멀티클러스터 설치

```bash
# 양쪽 클러스터에 동일한 Trust Anchor 사용 (필수)
# Step 1: 공통 Root CA 생성
step certificate create root.linkerd.cluster.local ca.crt ca.key \
  --profile root-ca --no-password --insecure --not-after=87600h

# Step 2: 각 클러스터에 Control Plane 설치 (같은 Trust Anchor)
# Cluster West
linkerd install \
  --identity-trust-anchors-file ca.crt \
  --identity-issuer-certificate-file west-issuer.crt \
  --identity-issuer-key-file west-issuer.key \
  | kubectl --context=west apply -f -

# Cluster East
linkerd install \
  --identity-trust-anchors-file ca.crt \
  --identity-issuer-certificate-file east-issuer.crt \
  --identity-issuer-key-file east-issuer.key \
  | kubectl --context=east apply -f -

# Step 3: 멀티클러스터 확장 설치
linkerd multicluster install | kubectl --context=west apply -f -
linkerd multicluster install | kubectl --context=east apply -f -

# Step 4: 클러스터 링크 생성
linkerd multicluster link --context=east --cluster-name east \
  | kubectl --context=west apply -f -

# Step 5: 검증
linkerd multicluster check --context=west
linkerd multicluster gateways --context=west
```

### Link CRD

```yaml
# Link 리소스 (자동 생성됨, 참고용)
apiVersion: multicluster.linkerd.io/v1alpha1
kind: Link
metadata:
  name: east
  namespace: linkerd-multicluster
spec:
  targetClusterName: east
  targetClusterDomain: cluster.local
  targetClusterLinkerdNamespace: linkerd
  clusterCredentialsSecret: cluster-credentials-east
  gatewayAddress: gateway-east.example.com
  gatewayPort: 4143
  gatewayIdentity: gateway.linkerd-multicluster.serviceaccount.identity.linkerd.cluster.local
  probeSpec:
    path: /ready
    port: 4191
    period: 3s
  selector:
    matchLabels:
      mirror.linkerd.io/exported: "true"
```

### Federated Service (서비스 미러링)

```yaml
# 원격 클러스터 서비스를 로컬에서 접근
# East 클러스터의 서비스에 export 레이블 추가
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: production
  labels:
    mirror.linkerd.io/exported: "true"
spec:
  selector:
    app: payment-service
  ports:
  - port: 8080

# West 클러스터에서 자동으로 미러 서비스 생성됨:
# payment-service-east.production.svc.cluster.local
```

```bash
# 미러링 상태 확인
linkerd multicluster gateways
# CLUSTER  ALIVE  NUM_SVC  LATENCY
# east     True   3        5ms

# 미러 서비스 확인
kubectl get svc -n production | grep "\-east"
# payment-service-east    ClusterIP   10.96.100.1   8080/TCP
```

---

## Gateway API 통합

```yaml
# Linkerd + Gateway API HTTPRoute
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: order-route
  namespace: production
  annotations:
    linkerd.io/inject: enabled
spec:
  parentRefs:
  - name: order-service
    kind: Service
    group: core
    port: 8080
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api/v2/orders
      headers:
      - name: X-Canary
        value: "true"
    backendRefs:
    - name: order-service-canary
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /api/orders
    backendRefs:
    - name: order-service-stable
      port: 8080
      weight: 90
    - name: order-service-canary
      port: 8080
      weight: 10
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 기본 인증서로 프로덕션 운영 | 인증서 만료 시 메시 전체 중단 | `step` CLI로 외부 CA 설정, cert-manager 연동 |
| 모든 Pod에 무조건 inject | init container, Job 등 오작동 | `linkerd.io/inject: disabled` 예외 처리 |
| ServiceProfile 없이 운영 | per-route 메트릭 부재 | Swagger/Protobuf에서 자동 생성 |
| Viz를 프로덕션 모니터링으로 사용 | 내장 Prometheus 용량 부족 | 외부 Prometheus/Grafana 연동 |
| 멀티클러스터에서 Trust Anchor 불일치 | 클러스터 간 mTLS 실패 | 공통 Root CA 반드시 공유 |
| non-HTTP 트래픽 무시 | TCP 트래픽 프록시 오작동 | `config.linkerd.io/skip-outbound-ports` 설정 |
| Retry를 비멱등 API에 적용 | 중복 주문/결제 발생 | `isRetryable: false` 명시 |
| 업그레이드 시 CLI 버전 불일치 | Control Plane/Data Plane 호환 문제 | `linkerd check` 반드시 실행 |

---

## 체크리스트

### 초기 설치
- [ ] `linkerd check --pre` 사전 검증 통과
- [ ] 프로덕션용 Trust Anchor / Issuer 인증서 설정
- [ ] cert-manager 또는 외부 CA 연동
- [ ] CRD 설치 후 Control Plane 설치
- [ ] `linkerd check` 전체 통과

### Namespace 온보딩
- [ ] `linkerd.io/inject: enabled` annotation 추가
- [ ] 기존 Deployment 재배포 (프록시 주입)
- [ ] `linkerd edges` 로 mTLS 연결 확인
- [ ] init container / Job 등 예외 처리

### 트래픽 관리
- [ ] ServiceProfile 생성 (per-route 메트릭)
- [ ] 재시도 정책 설정 (멱등 API만)
- [ ] 타임아웃 설정
- [ ] Authorization Policy 설정

### 관찰성
- [ ] Viz 확장 설치
- [ ] 외부 Prometheus 연동 (프로덕션)
- [ ] Grafana 대시보드 설정
- [ ] 성공률 / 레이턴시 / 처리량 알림 설정

### 멀티클러스터
- [ ] 공통 Trust Anchor 공유
- [ ] 각 클러스터에 동일 버전 설치
- [ ] multicluster extension 설치
- [ ] Link CRD 생성 및 검증
- [ ] 서비스 미러링 확인 (`mirror.linkerd.io/exported`)

### 업그레이드
- [ ] CLI 버전 먼저 업그레이드
- [ ] CRD 업그레이드
- [ ] Control Plane 업그레이드
- [ ] Data Plane 롤링 업데이트 (`linkerd inject` 재적용)
- [ ] `linkerd check` 최종 검증

---

**관련 스킬**: `/istio-core`, `/istio-ambient`, `/k8s-traffic`, `/gateway-api`
