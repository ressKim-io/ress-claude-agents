# Network Policy Generator

Kubernetes Network Policy를 생성하고 검증합니다.

## Instructions

1. 대상 namespace 또는 deployment를 분석합니다.
2. 필요한 Network Policy를 생성합니다.
3. Default Deny 정책을 기본으로 적용합니다.
4. 필요한 트래픽만 허용하는 정책을 추가합니다.

## Default Deny Policy

### 모든 Ingress/Egress 차단 (namespace 단위)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: {{ namespace }}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## Common Policy Templates

### Allow DNS (Egress)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: {{ namespace }}
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

### Allow Frontend to Backend
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: {{ namespace }}
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Allow Backend to Database
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: {{ namespace }}
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
```

### Allow Ingress Controller
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
  namespace: {{ namespace }}
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
```

### Allow Prometheus Scraping
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus
  namespace: {{ namespace }}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
      podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 9090
```

## Analysis Mode

### Deployment 분석 시 확인 사항
1. 어떤 서비스와 통신하는지 (Service 참조)
2. 외부 API 호출 여부
3. Database 연결 여부
4. 메시지 큐 연결 여부

### 생성할 정책 목록
- default-deny-all (필수)
- allow-dns (필수)
- 서비스 간 통신 정책 (분석 결과 기반)

## Validation

### 기존 Network Policy 검증
- [ ] Default Deny 정책 존재 여부
- [ ] DNS 허용 정책 존재 여부
- [ ] 불필요하게 넓은 범위 허용 여부 (podSelector: {} with allow)
- [ ] 중복 정책 여부

## Output Format

```markdown
## Network Policy Report

### Namespace: production

#### Existing Policies
1. default-deny-all ✓
2. allow-dns ✓
3. allow-frontend-to-backend ✓

#### Missing Policies
- allow-backend-to-db: backend → database:5432 통신 필요

#### Generated Policies

##### allow-backend-to-db.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
...
```

#### Recommendations
- monitoring namespace에서 메트릭 수집 허용 정책 추가 권장
```

## Usage

```
/netpol                             # 현재 디렉토리 분석 및 생성
/netpol production                  # 특정 namespace용 정책 생성
/netpol --analyze deployment.yaml   # deployment 분석 후 정책 제안
/netpol --validate                  # 기존 정책 검증
```
