# Kubernetes Commands

Kubernetes 운영을 위한 명령어입니다.

## 명령어

| 명령어 | 설명 |
|--------|------|
| `/k8s validate` | 매니페스트 검증 |
| `/k8s secure` | 보안 설정 추가 |
| `/k8s netpol` | NetworkPolicy 생성 |
| `/k8s helm-check` | Helm 차트 검사 |

## 관련 Skills

| Skill | 내용 |
|-------|------|
| `/k8s-security` | 보안 패턴 (SecurityContext, RBAC) |
| `/k8s-helm` | Helm 베스트 프랙티스 |

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
