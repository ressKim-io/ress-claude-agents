# Network Policy Generator

Kubernetes Network Policy를 생성하고 검증합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Namespace 또는 Deployment manifest |
| Output | NetworkPolicy YAML 파일들 |
| Required Tools | kubectl (optional) |
| Verification | `kubectl apply --dry-run=client -f netpol.yaml` |

## Checklist

### Default Policies (필수)

#### 1. Default Deny All
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

#### 2. Allow DNS
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

### Analysis Mode
Deployment 분석 시 확인:
1. 어떤 서비스와 통신하는지
2. 외부 API 호출 여부
3. Database 연결 여부

## Output Format

```markdown
## Network Policy Report

### Namespace: production

#### Existing Policies
1. default-deny-all
2. allow-dns

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

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| NetworkPolicy 적용 안됨 | CNI 플러그인 미지원 | Calico, Cilium 등 NetworkPolicy 지원 CNI 확인 |
| DNS 조회 실패 | egress DNS 허용 안됨 | `allow-dns` 정책 먼저 적용 |
| 파드 간 통신 불가 | default-deny 적용 후 허용 정책 누락 | 필요한 ingress/egress 규칙 추가 |
| namespaceSelector 동작 안함 | 네임스페이스 라벨 누락 | `kubectl label namespace <ns> name=<ns>` |
| podSelector 매칭 안됨 | 라벨 오타 또는 불일치 | `kubectl get pods --show-labels`로 확인 |
| 외부 API 호출 실패 | egress 0.0.0.0/0 미허용 | 필요한 CIDR 범위 egress 규칙 추가 |
