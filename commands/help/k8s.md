# Kubernetes Commands

Kubernetes 운영을 위한 명령어입니다.

## 명령어

### `/k8s validate`
매니페스트를 검증합니다.

```
/k8s validate                    # 모든 YAML
/k8s validate deployment.yaml    # 특정 파일
/k8s validate ./manifests/       # 디렉토리
```

**검사 항목:**
- 리소스 requests/limits
- 라벨/셀렉터 일치
- 이미지 태그 (latest 금지)
- Probe 설정

---

### `/k8s secure`
보안 검사를 수행합니다.

```
/k8s secure                      # 모든 매니페스트
/k8s secure deployment.yaml      # 특정 파일
/k8s secure --fix                # 자동 수정
```

**검사 항목:**
- `runAsNonRoot: true`
- `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`
- 민감 정보 (Secret 사용)

---

### `/k8s netpol`
NetworkPolicy를 생성합니다.

```
/k8s netpol my-app              # 앱용 정책 생성
/k8s netpol --namespace prod    # 네임스페이스 지정
```

**생성 패턴:**
- 기본 deny-all
- 필요한 ingress/egress만 허용

---

### `/k8s helm-check`
Helm 차트를 검사합니다.

```
/k8s helm-check ./charts/my-app     # 차트 검사
/k8s helm-check --values prod.yaml  # 값 파일 포함
```

**검사 항목:**
- values.yaml 기본값
- 템플릿 문법
- 의존성 버전

---

## Skills (상세 지식)

| 명령어 | 내용 |
|--------|------|
| `/k8s-security` | 보안 패턴 (SecurityContext, RBAC, NetworkPolicy) |
| `/k8s-helm` | Helm 베스트 프랙티스 |

---

## Quick Reference

```bash
# 검증
kubectl apply --dry-run=client -f manifest.yaml
kubeval manifest.yaml
kubesec scan manifest.yaml

# Helm
helm lint ./charts/my-app
helm template ./charts/my-app
```
