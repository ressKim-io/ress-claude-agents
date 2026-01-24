# Network Policy Generator

Kubernetes Network Policy를 생성하고 검증합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Namespace 또는 Deployment manifest |
| Output | NetworkPolicy YAML 파일들 |
| Required Tools | kubectl (optional) |
| Verification | `kubectl apply --dry-run=client -f netpol.yaml` |

## Default Policies

### 1. Default Deny All (필수)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

### 2. Allow DNS (필수)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

## Analysis Mode

Deployment 분석 시 확인:
1. 어떤 서비스와 통신하는지
2. 외부 API 호출 여부
3. Database 연결 여부

## Output Format

```markdown
## Network Policy Report

### Namespace: production

#### Existing Policies
1. default-deny-all ✓
2. allow-dns ✓

#### Generated Policies
- allow-backend-to-db.yaml
```

## Usage

```
/netpol                      # 현재 디렉토리 분석
/netpol production           # 특정 namespace
/netpol --analyze deploy.yaml # deployment 분석
/netpol --validate           # 기존 정책 검증
```
