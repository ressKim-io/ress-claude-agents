[English](../../personas/devops-sre.md) | **한국어**

# DevOps / SRE 가이드

> 인프라 운영, 배포, 관측성, 인시던트 대응을 위한 에이전트 + 스킬 활용 가이드

---

## 설치 후 첫 5분

- [ ] `./install.sh --global --all --with-skills` 실행
- [ ] Claude Code에서 `/agents` 입력 → 에이전트 목록 확인
- [ ] `"K8s 클러스터 상태 확인해줘"` 시도
- [ ] `"Terraform plan 리뷰해줘"` 시도

---

## 매일 쓰는 조합

> 전체 조합 테이블: [quick-reference.md](../quick-reference.md#3-devops--sre-콤보)

### 운영 사이클

```
1. 인프라 변경
   → terraform-reviewer로 IaC 리뷰
   → security-scanner로 보안 검증

2. 배포
   → ci-optimizer로 파이프라인 최적화
   → /gitops-argocd로 ArgoCD 설정

3. 모니터링
   → otel-expert로 관측성 구축
   → /monitoring-grafana로 대시보드 설정

4. 장애 대응
   → incident-responder로 자동 트리아지
   → k8s-troubleshooter로 클러스터 진단
```

---

## IaC / 인프라 섹션

### 핵심 에이전트

| 에이전트 | 용도 |
|---------|------|
| `terraform-reviewer` | IaC 보안/비용/신뢰성 11개 도메인 리뷰 |
| `k8s-troubleshooter` | K8s 문제 진단, 근본 원인 분석 |
| `cost-analyzer` | FinOps 분석, 비용 이상 탐지 |

### 핵심 스킬

| 카테고리 | 스킬 | 핵심 내용 |
|---------|------|----------|
| Terraform | `/terraform-modules` | 모듈 패턴 |
| Terraform | `/terraform-security` | 보안 best practices |
| AWS | `/aws-eks` | EKS Terraform, IRSA, Add-ons |
| AWS | `/aws-eks-advanced` | Karpenter, 보안 강화 |
| AWS | `/aws-lambda` | 서버리스, 콜드 스타트 최적화 |
| K8s | `/k8s-security` | Pod Security, RBAC, Kyverno |
| K8s | `/k8s-helm` | Helm chart best practices |
| K8s | `/k8s-autoscaling` | HPA, VPA, KEDA, Karpenter |
| IaC | `/crossplane` | Multi-cloud IaC, Compositions |
| Docker | `/docker` | Dockerfile 최적화, 멀티스테이지 빌드 |

### 상황별 요청 예시

```
"EKS 클러스터 Terraform으로 구축해줘"
→ terraform-reviewer + /aws-eks + /aws-eks-advanced

"K8s 보안 강화해줘"
→ k8s-troubleshooter + /k8s-security + /k8s-helm

"HPA + KEDA 오토스케일링 설정해줘"
→ /k8s-autoscaling + /k8s-autoscaling-advanced
```

---

## K8s 운영 섹션

### 스케줄링/트래픽

| 스킬 | 핵심 내용 |
|------|----------|
| `/k8s-scheduling` | Node Affinity, Taint, Pod Affinity |
| `/k8s-scheduling-advanced` | Topology Spread, 디버깅 |
| `/k8s-traffic` | Rate Limiting, 대기열 |
| `/k8s-traffic-ingress` | Ingress 트래픽 관리 |
| `/k8s-traffic-istio` | Istio Rate Limiting, Circuit Breaker |

### Service Mesh

```
Istio 시작:
  /istio-core → /istio-security → /istio-gateway

Istio 고급:
  /istio-advanced-traffic → /istio-otel → /istio-multicluster

Istio Ambient:
  /istio-ambient → /istio-gateway-api

Linkerd (경량):
  /linkerd

Gateway API:
  /gateway-api → /gateway-api-migration
```

---

## 인시던트 대응 섹션

### 핵심 에이전트

| 에이전트 | 역할 |
|---------|------|
| `incident-responder` | 자동 트리아지, 심각도 분류, 커뮤니케이션 템플릿 |
| `k8s-troubleshooter` | K8s 클러스터 진단, AIOps |

### 대응 흐름

```
알림 수신
  ↓
incident-responder → 자동 트리아지 (SEV 분류, 영향 범위)
  ↓
k8s-troubleshooter → 클러스터 진단 (파드, 노드, 네트워크)
  ↓
database-expert → DB 이슈 분석 (필요 시)
  ↓
/log-trouble → 트러블슈팅 기록
```

### 관련 스킬

| 스킬 | 용도 |
|------|------|
| `/observability` | 로깅, RED Method |
| `/monitoring-troubleshoot` | 알림 대응, 트러블슈팅 패턴 |
| `/chaos-engineering` | 카오스 테스트, GameDay |
| `/disaster-recovery` | DR 전략, Velero 백업 |

---

## 관측성 섹션

### 핵심 에이전트

| 에이전트 | 역할 |
|---------|------|
| `otel-expert` | 대규모 OTel 아키텍처, Tail Sampling, 비용 최적화 |

### 관측성 스택별 스킬

```
OpenTelemetry:
  /observability-otel → /observability-otel-scale → /observability-otel-optimization

eBPF (Zero-Code):
  /ebpf-observability → /ebpf-observability-advanced

Grafana Stack:
  /monitoring-grafana + /monitoring-metrics + /monitoring-logs

로그 분석:
  /logging-elk (ELK) 또는 /logging-loki (Loki)

알림:
  /alerting-discord

AIOps:
  /aiops → /aiops-remediation
```

---

## FinOps 섹션

### 핵심 에이전트

| 에이전트 | 역할 |
|---------|------|
| `cost-analyzer` | 비용 분석, 이상 탐지, 최적화 제안 |
| `finops-advisor` | FinOps 전략, 성숙도 평가, GreenOps |

### FinOps 스킬 경로

```
기본:
  /finops → /finops-tools

고급:
  /finops-advanced → /finops-automation → /finops-showback

도구 선택:
  /finops-tools → /finops-tools-advanced

GreenOps:
  /finops-greenops
```

---

## GitOps / CI/CD 섹션

### 핵심 에이전트

| 에이전트 | 역할 |
|---------|------|
| `ci-optimizer` | CI/CD 최적화, DORA 메트릭, Flaky 테스트 |
| `git-workflow` | Git 워크플로우 자동화, PR |

### GitOps 스킬 경로

```
ArgoCD 기본:
  /gitops-argocd → /gitops-argocd-advanced

AI GitOps:
  /gitops-argocd-ai

배포 전략:
  /deployment-strategies → /deployment-canary

CI/CD:
  /cicd-devsecops → /cicd-policy

Supply Chain:
  /supply-chain-security → /supply-chain-compliance
```

---

## 관련 시나리오

- [프로덕션 장애 대응](../scenarios/production-incident.md) — K8s OOMKilled 장애 대응 워크스루
- [플랫폼 팀 환경 구축](../scenarios/platform-bootstrap.md) — Backstage + ArgoCD + OTel 구축 워크스루
