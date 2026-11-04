<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# cicd

CI/CD — GitHub Actions, ArgoCD, 배포 전략, Ephemeral 환경, 파이프라인 리뷰와 최적화

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install cicd@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/cicd/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`core/user-approval.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/user-approval.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (13)

| 이름 | 설명 |
|---|---|
| `/cicd:cicd-devsecops` | CI/CD & DevSecOps 가이드 — GitHub Actions, 보안 스캔(Trivy, SonarQube), 통합 파이프라인 |
| `/cicd:cicd-policy` | CI/CD Policy as Code 가이드 — Kyverno 정책, 보안 점수 대시보드, 통합 DevSecOps 파이프라인 |
| `/cicd:deployment-canary` | Canary & A/B Testing 배포 가이드 — Argo Rollouts Canary, AnalysisTemplate, Istio 트래픽 라우팅 |
| `/cicd:deployment-strategies` | 배포 전략 가이드 — Rolling Update, Blue-Green 배포 및 기본 전략 개요 |
| `/cicd:ec2-cd-pipeline` | EC2 기반 CD 파이프라인 패턴 — GitHub Actions + SSM + ALB + CloudFront 기반 EC2 배포 실무 패턴 |
| `/cicd:ephemeral-environments` | Ephemeral Environments 가이드 — PR별 프리뷰 환경: Argo CD ApplicationSet, Qovery, Namespace 격리 패턴 |
| `/cicd:ephemeral-environments-advanced` | Ephemeral Environments 고급 가이드 — Qovery 설정, 데이터베이스 전략, Spot 인스턴스 비용 최적화 |
| `/cicd:gitops-argocd` | GitOps & ArgoCD 가이드 — ArgoCD를 활용한 선언적 GitOps 배포 및 App of Apps 패턴 |
| `/cicd:gitops-argocd-advanced` | GitOps ArgoCD 고급 패턴 — ApplicationSet, Sync 전략, 프로젝트/RBAC, 시크릿 관리 |
| `/cicd:gitops-argocd-ai` | AI-assisted GitOps 가이드 — AI 기반 GitOps 자동화: Spacelift Intent, ArgoCD AI 분석, 예측적 배포, Drift 수정 |
| `/cicd:gitops-argocd-helm` | ArgoCD + Helm 통합 패턴 가이드 — ArgoCD Image Updater, Multi-source Application, Helm hooks 비교, Secrets+Helm 통합 |
| `/cicd:supply-chain-compliance` | Supply Chain 컴플라이언스 가이드 — EU Cyber Resilience Act, SBOM 자동화, VEX, 중앙 저장소 아키텍처 |
| `/cicd:supply-chain-security` | Supply Chain Security 가이드 — SBOM, SLSA, Sigstore를 활용한 소프트웨어 공급망 보안 |

## Agents (4)

| 이름 | 설명 |
|---|---|
| `cicd:ci-optimizer` | CI/CD 파이프라인 분석 및 최적화 에이전트. 빌드 시간 분석, 병목 지점 식별, DORA 메트릭 추적, Flaky 테스트 탐지 |
| `cicd:cicd-reviewer` | CI/CD 파이프라인 종합 리뷰어 — 비용, 캐싱, 권한 범위, 작업 구조, 시크릿 관리 best practice |
| `cicd:cicd-security-reviewer` | CI/CD 공격 표면 전문 리뷰어 — OWASP Top 10 CI/CD Risks + SLSA framework. Pipeline poisoning, secret exfiltration, … |
| `cicd:gitops-reviewer` | AI-powered GitOps configuration reviewer |
