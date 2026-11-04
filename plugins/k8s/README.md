<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# k8s

Kubernetes — 스케줄링, 오토스케일링, 트래픽, Helm, 보안, GPU, manifest 리뷰와 장애 진단

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install k8s@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/k8s/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`service-mesh`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/service-mesh/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`ai`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/ai/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`messaging`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/messaging/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`infra/k8s-manifest.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/infra/k8s-manifest.md)
- [`infra/version-compatibility.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/infra/version-compatibility.md)
- [`core/user-approval.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/user-approval.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (17)

| 이름 | 설명 |
|---|---|
| `/k8s:defense-in-depth-layers` | Kubernetes 보안을 L3/L4 NetworkPolicy + L7 AuthorizationPolicy + Pod Security + Image policy 4중 레이어로 강제하는 체크리스트. … |
| `/k8s:gateway-api` | Kubernetes Gateway API 가이드 — Ingress NGINX 지원 종료 대응: Gateway API, Envoy Gateway, Kong 마이그레이션 |
| `/k8s:gateway-api-migration` | Gateway API 마이그레이션 가이드 — Ingress NGINX -> Gateway API 전환, Istio Gateway API 통합, Annotation 매핑 |
| `/k8s:helm-environment-strategy` | Helm & Kustomize 환경별 변수화 전략 — 환경별(dev/staging/prod) 설정 분리, Helm values overlay, Kustomize overlay 패턴 |
| `/k8s:k8s-autoscaling` | Kubernetes Autoscaling 가이드 — HPA, VPA, KEDA, Karpenter를 활용한 워크로드 자동 스케일링 |
| `/k8s:k8s-autoscaling-advanced` | Kubernetes Autoscaling 고급 가이드 — Karpenter, 조합 전략, 모니터링 |
| `/k8s:k8s-gpu` | Kubernetes GPU 가이드 — NVIDIA GPU Operator, MIG 파티셔닝, GPU 공유 전략 |
| `/k8s:k8s-gpu-scheduling` | Kubernetes GPU 스케줄링 & 모니터링 — Kueue 큐 관리, Volcano Gang 스케줄링, GPU 모니터링 |
| `/k8s:k8s-helm` | Helm Best Practices — Helm chart 개발 패턴 및 best practices |
| `/k8s:k8s-scheduling` | Kubernetes Scheduling 가이드 — Node Affinity, Pod Affinity/Anti-Affinity, Taint & Toleration |
| `/k8s:k8s-scheduling-advanced` | Kubernetes Scheduling 고급 가이드 — 실전 시나리오, Topology Spread, 디버깅 |
| `/k8s:k8s-security` | Kubernetes Security Patterns — Kubernetes 보안 패턴 및 best practices |
| `/k8s:k8s-traffic` | Kubernetes Traffic Control Patterns — 인프라 레벨 트래픽 제어 허브: Rate Limiting, Circuit Breaker, 대기열 |
| `/k8s:k8s-traffic-ingress` | Ingress Rate Limiting — NGINX Ingress, Kong 기반 Rate Limiting |
| `/k8s:k8s-troubleshoot-trees` | K8s Troubleshooting Decision Trees — 실전 트러블슈팅 기록 기반 K8s 디버깅 의사결정 트리. CrashLoopBackOff / ImagePullBackOff / … |
| `/k8s:multi-env-diff-checklist` | dev / staging / prod 환경 manifest의 차이를 자동 검증하는 체크리스트. hardcoded 값과 환경별 override 누락을 사전에 검출. 멀티 클라우드(AWS/GCP) … |
| `/k8s:netpol-defense-depth` | Kubernetes NetworkPolicy + 서비스 메시 AuthorizationPolicy의 멀티 레이어 방어 체크리스트. ingress + egress + AuthZ 3중 구조 누락 검출. … |

## Agents (4)

| 이름 | 설명 |
|---|---|
| `k8s:k8s-reviewer` | K8s manifest / Helm chart / Kustomize 종합 리뷰어 — Pod Security Standards, RBAC, 리소스 관리, 고가용성, 이미지 정책 |
| `k8s:k8s-security-reviewer` | K8s 공격 표면 전문 리뷰어 — CIS K8s Benchmark + MITRE ATT&CK for Containers. Container escape, lateral movement, … |
| `k8s:k8s-troubleshooter` | AI-powered Kubernetes troubleshooting agent |
| `k8s:network-security-reviewer` | K8s 네트워크 공격 표면 전문 리뷰어 — Zero Trust + MITRE ATT&CK Lateral Movement. NetworkPolicy / 서비스 메시 mTLS / egress … |

## Commands (4)

| 이름 | 설명 |
|---|---|
| `/k8s:helm-check` | K8s: Helm chart의 best practice를 검증합니다 |
| `/k8s:netpol` | K8s: NetworkPolicy를 생성하고 검증합니다 |
| `/k8s:secure` | K8s: 보안 설정을 자동으로 추가합니다 |
| `/k8s:validate` | K8s: 매니페스트의 best practice를 검증합니다 |
