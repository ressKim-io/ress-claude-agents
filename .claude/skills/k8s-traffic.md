# Kubernetes Traffic Control Patterns

Istio, NGINX Ingress, Envoy 기반 인프라 레벨 트래픽 제어

## Quick Reference

```
트래픽 제어 선택
    │
    ├─ Service Mesh 있음 ───> Istio Rate Limiting
    │   └─ Global/Local 선택
    │
    ├─ Ingress만 사용 ──────> NGINX Ingress annotations
    │
    ├─ API Gateway ─────────> Kong / AWS API Gateway
    │
    └─ 대기열 필요 ─────────> Virtual Waiting Room 패턴
```

---

## CRITICAL: Istio Rate Limiting

### 아키텍처

```
┌──────────┐     ┌──────────┐     ┌─────────────┐
│  Client  │────▶│  Envoy   │────▶│  Ratelimit  │
└──────────┘     │ (Sidecar)│     │  Service    │
                 └────┬─────┘     └──────┬──────┘
                      │                  │
                      ▼                  ▼
                 ┌──────────┐      ┌──────────┐
                 │   App    │      │  Redis   │
                 └──────────┘      └──────────┘
```

### Global Rate Limiting (중앙 집중)

```yaml
# 1. Ratelimit 서비스 배포
apiVersion: v1
kind: ConfigMap
metadata:
  name: ratelimit-config
  namespace: istio-system
data:
  config.yaml: |
    domain: ticket-api
    descriptors:
      # 전체 API 제한: 10,000 req/s
      - key: generic_key
        value: global
        rate_limit:
          unit: second
          requests_per_unit: 10000

      # 엔드포인트별 제한
      - key: header_match
        value: ticket-reserve
        rate_limit:
          unit: second
          requests_per_unit: 1000

      # 사용자별 제한: 10 req/s per user
      - key: user_id
        rate_limit:
          unit: second
          requests_per_unit: 10
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ratelimit
  namespace: istio-system
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: ratelimit
        image: envoyproxy/ratelimit:v1.4.0
        env:
        - name: REDIS_SOCKET_TYPE
          value: tcp
        - name: REDIS_URL
          value: redis:6379
        - name: RUNTIME_ROOT
          value: /data
        - name: RUNTIME_SUBDIRECTORY
          value: ratelimit
        volumeMounts:
        - name: config
          mountPath: /data/ratelimit/config
```

### EnvoyFilter 설정

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ratelimit-filter
  namespace: istio-system
spec:
  configPatches:
  # HTTP Filter 추가
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.ratelimit
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimit
          domain: ticket-api
          failure_mode_deny: false  # rate limit 서비스 장애 시 허용
          rate_limit_service:
            grpc_service:
              envoy_grpc:
                cluster_name: rate_limit_cluster
            transport_api_version: V3

  # Rate Limit Cluster 정의
  - applyTo: CLUSTER
    patch:
      operation: ADD
      value:
        name: rate_limit_cluster
        type: STRICT_DNS
        connect_timeout: 1s
        lb_policy: ROUND_ROBIN
        http2_protocol_options: {}
        load_assignment:
          cluster_name: rate_limit_cluster
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: ratelimit.istio-system.svc.cluster.local
                    port_value: 8081
```

### 라우팅 기반 Rate Limit 적용

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ticket-api
spec:
  hosts:
  - ticket-api
  http:
  - match:
    - uri:
        prefix: /api/v1/tickets/reserve
    route:
    - destination:
        host: ticket-api
    headers:
      request:
        set:
          x-envoy-ratelimit-header: ticket-reserve
  - route:
    - destination:
        host: ticket-api
```

### Local Rate Limiting (사이드카 레벨)

중앙 서비스 없이 각 Pod에서 직접 제한:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: local-ratelimit
  namespace: ticket
spec:
  workloadSelector:
    labels:
      app: ticket-api
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.local_ratelimit
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
          stat_prefix: http_local_rate_limiter
          token_bucket:
            max_tokens: 100
            tokens_per_fill: 100
            fill_interval: 1s
          filter_enabled:
            runtime_key: local_rate_limit_enabled
            default_value:
              numerator: 100
              denominator: HUNDRED
          filter_enforced:
            runtime_key: local_rate_limit_enforced
            default_value:
              numerator: 100
              denominator: HUNDRED
          response_headers_to_add:
          - append: false
            header:
              key: x-rate-limit-remaining
              value: "%DYNAMIC_METADATA(envoy.http.local_rate_limit:tokens_remaining)%"
```

---

## NGINX Ingress Rate Limiting

### Annotation 기반

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ticket-api
  annotations:
    # 초당 요청 수 제한
    nginx.ingress.kubernetes.io/limit-rps: "100"

    # 분당 요청 수 제한
    nginx.ingress.kubernetes.io/limit-rpm: "1000"

    # 동시 연결 수 제한
    nginx.ingress.kubernetes.io/limit-connections: "50"

    # 제한 초과 시 응답 코드
    nginx.ingress.kubernetes.io/limit-rate-after: "10m"

    # Burst 허용
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"

    # Whitelist (rate limit 제외 IP)
    nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8,192.168.0.0/16"
spec:
  rules:
  - host: ticket.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: ticket-api
            port:
              number: 80
```

### ConfigMap 기반 (전역)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  # 전역 rate limiting
  limit-req-status-code: "429"
  limit-conn-status-code: "429"

  # 클라이언트 식별 (IP 기반)
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
```

---

## Kong Rate Limiting

### Plugin 설정

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limiting-ticket
spec:
  plugin: rate-limiting
  config:
    second: 10
    minute: 100
    hour: 1000
    policy: redis
    redis_host: redis
    redis_port: 6379
    redis_database: 0
    fault_tolerant: true
    hide_client_headers: false
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ticket-api
  annotations:
    konghq.com/plugins: rate-limiting-ticket
spec:
  ingressClassName: kong
  rules:
  - host: ticket.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: ticket-api
            port:
              number: 80
```

### Consumer별 Rate Limiting

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: vip-user
  annotations:
    kubernetes.io/ingress.class: kong
username: vip-user
---
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limiting-vip
spec:
  plugin: rate-limiting
  config:
    second: 100  # VIP는 10배 허용
    minute: 1000
    policy: redis
```

---

## Virtual Waiting Room (대기열)

티켓팅 시스템의 핵심 패턴:

### 아키텍처

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│  Client  │────▶│ Waiting Room │────▶│  Ticket  │
└──────────┘     │   (Queue)    │     │   API    │
                 └──────┬───────┘     └──────────┘
                        │
                        ▼
                 ┌──────────────┐
                 │    Redis     │
                 │ Sorted Set   │
                 └──────────────┘
```

### Istio + Redis 기반 구현

```yaml
# 대기열 서비스
apiVersion: apps/v1
kind: Deployment
metadata:
  name: waiting-room
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: waiting-room
        image: waiting-room:latest
        env:
        - name: REDIS_URL
          value: redis:6379
        - name: MAX_CONCURRENT_USERS
          value: "5000"
        - name: TOKEN_TTL_SECONDS
          value: "300"
---
# VirtualService로 대기열 라우팅
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ticket-with-queue
spec:
  hosts:
  - ticket.example.com
  http:
  # 대기열 토큰 있으면 바로 통과
  - match:
    - headers:
        x-queue-token:
          regex: ".+"
    route:
    - destination:
        host: ticket-api
  # 없으면 대기열로
  - route:
    - destination:
        host: waiting-room
```

### 대기열 상태 응답

```yaml
# 429 응답에 대기 정보 포함
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: queue-response-headers
spec:
  configPatches:
  - applyTo: HTTP_ROUTE
    patch:
      operation: MERGE
      value:
        response_headers_to_add:
        - header:
            key: X-Queue-Position
            value: "%DYNAMIC_METADATA(queue:position)%"
        - header:
            key: X-Queue-Wait-Time
            value: "%DYNAMIC_METADATA(queue:estimated_wait)%"
        - header:
            key: Retry-After
            value: "%DYNAMIC_METADATA(queue:retry_after)%"
```

---

## Circuit Breaker (Istio)

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ticket-api-circuit-breaker
spec:
  host: ticket-api
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10
        maxRetries: 3
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 30
```

---

## 티켓팅 시스템 권장 구성

```yaml
# 1. Global Rate Limit (전체 시스템 보호)
전체 API: 10,000 req/s

# 2. Endpoint별 Rate Limit
/api/tickets/reserve: 1,000 req/s
/api/tickets/search: 5,000 req/s

# 3. User별 Rate Limit
일반 사용자: 10 req/s
VIP: 50 req/s

# 4. IP별 Rate Limit (봇 방어)
단일 IP: 20 req/s

# 5. Virtual Waiting Room
동시 접속: 5,000명
대기열 용량: 100,000명
토큰 TTL: 5분
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 앱 레벨만 Rate Limit | 인프라 부하 | Istio/Ingress 레벨 추가 |
| 단일 Redis | SPOF | Redis Cluster |
| 고정 Limit만 | 버스트 대응 불가 | Token Bucket 알고리즘 |
| 429만 응답 | UX 나쁨 | 대기열 + 예상 시간 제공 |
| Local만 사용 | 분산 환경 불일치 | Global Rate Limit |

---

## 체크리스트

### Rate Limiting
- [ ] Global Rate Limit 설정
- [ ] Endpoint별 차등 적용
- [ ] User/IP별 제한
- [ ] Redis HA 구성

### 대기열
- [ ] Virtual Waiting Room 구현
- [ ] 대기 순번/예상 시간 제공
- [ ] 토큰 기반 입장 제어

### Circuit Breaker
- [ ] 연결 풀 설정
- [ ] Outlier Detection 설정
- [ ] 장애 시 Fallback

**관련 skill**: `/k8s-security`, `/k8s-helm`, `/distributed-lock`
