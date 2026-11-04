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
| `/k8s:defense-in-depth-layers` | K8s 4중 방어 모델 — NetworkPolicy·Istio AuthorizationPolicy·PeerAuthentication 조합, OWASP K8s Top 10 안티패턴 |
| `/k8s:gateway-api` | Kubernetes Gateway API 개념과 리소스, Envoy Gateway·Kong 설정, Ingress NGINX EOL 대응 결정 트리 |
| `/k8s:gateway-api-migration` | Ingress NGINX 에서 Gateway API 로의 전환 절차 — Annotation 매핑, TCPRoute/UDPRoute, Istio Gateway API 모드 |
| `/k8s:helm-environment-strategy` | dev/staging/prod 환경별 설정 분리 — Helm values overlay, Kustomize overlay, ArgoCD 연동 변수화 |
| `/k8s:k8s-autoscaling` | HPA, VPA, KEDA, Karpenter 비교와 기본 설정, 워크로드 자동 스케일링 결정 트리 |
| `/k8s:k8s-autoscaling-advanced` | Karpenter 노드 오토스케일링, HPA·VPA·KEDA 조합 전략, 스케일링 모니터링 |
| `/k8s:k8s-gpu` | Kubernetes GPU 기본 구성 — NVIDIA GPU Operator, MIG 파티셔닝, GPU 공유 전략 |
| `/k8s:k8s-gpu-scheduling` | GPU 워크로드 스케줄링 — Kueue 큐 관리, Volcano Gang 스케줄링, GPU 모니터링 |
| `/k8s:k8s-helm` | Helm chart 개발 — 구조, values.yaml·values.schema.json, _helpers.tpl, Library Chart, YAML anchor, 멀티 환경 values |
| `/k8s:k8s-scheduling` | 파드 배치 기본 — nodeSelector, Node Affinity, Pod Affinity/Anti-Affinity, Taint & Toleration 비교 |
| `/k8s:k8s-scheduling-advanced` | 파드 스케줄링 심화 — Topology Spread Constraints, 실전 시나리오, 스케줄링 디버깅 |
| `/k8s:k8s-security` | Kubernetes 보안 — Pod Security Standards, NetworkPolicy, RBAC, Secrets 관리, Kyverno 정책, Trivy 스캔, AppProject 최소 … |
| `/k8s:k8s-traffic` | 인프라 트래픽 제어 허브 — Rate Limiting, Circuit Breaker, Virtual Waiting Room 대기열, 티켓팅 권장 구성 |
| `/k8s:k8s-traffic-ingress` | Ingress 레벨 Rate Limiting — NGINX Ingress annotation, Kong rate-limiting 플러그인 |
| `/k8s:k8s-troubleshoot-trees` | K8s 장애 디버깅 의사결정 트리 — CrashLoopBackOff, ImagePullBackOff, Pending, NetworkPolicy, DNS 실패, IMDS 접근 |
| `/k8s:multi-env-diff-checklist` | dev/staging/prod 또는 멀티 클라우드 간 manifest·values·config diff 점검 — 의도된 차이와 실수 구분, CI 검출 스크립트 |
| `/k8s:netpol-defense-depth` | NetworkPolicy 와 서비스 메시 AuthorizationPolicy 의 3중 방어 체크리스트, CNI 호환성, 차단 시 트러블슈팅 순서 |

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
