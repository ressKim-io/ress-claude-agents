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
| `/cicd:cicd-devsecops` | CI/CD 보안 파이프라인 — GitHub Actions, Trivy 취약점 스캔, SonarQube, secret 관리 |
| `/cicd:cicd-policy` | CI/CD 정책 자동화 — Kyverno 정책과 CLI 검증, 보안 점수 대시보드, 통합 DevSecOps 파이프라인 |
| `/cicd:deployment-canary` | Canary·A/B 배포 — Argo Rollouts, AnalysisTemplate, Istio 트래픽 분할, 자동 롤백, progressive delivery |
| `/cicd:deployment-strategies` | 기본 배포 전략 — Rolling Update, Blue-Green, 전략 비교, Argo Rollouts 설치와 CLI |
| `/cicd:ec2-cd-pipeline` | EC2 배포 파이프라인 — GitHub Actions + SSM, ALB 헬스체크, CloudFront behavior 라우팅, 배포 완료 대기 |
| `/cicd:ephemeral-environments` | PR 별 프리뷰 환경 — Argo CD ApplicationSet PR generator, namespace 격리, Kyverno 자동 정리, static 과 비교 |
| `/cicd:ephemeral-environments-advanced` | 임시 환경 심화 — Qovery 설정, 환경별 데이터베이스 전략, Spot 인스턴스 비용 최적화 |
| `/cicd:gitops-argocd` | ArgoCD 기본 — GitOps 원칙, 설치, Application 정의, App of Apps, CLI, bootstrap sync-wave |
| `/cicd:gitops-argocd-advanced` | ArgoCD 심화 — ApplicationSet 멀티 클러스터·환경, sync 전략, repo 구조, AppProject RBAC, 알림 |
| `/cicd:gitops-argocd-ai` | AI 기반 GitOps — Spacelift Intent, ArgoCD AI 분석, 예측적 배포, 자동 drift 수정 |
| `/cicd:gitops-argocd-helm` | ArgoCD 와 Helm 통합 — Image Updater, multi-source Application, Helm hooks vs ArgoCD hooks, secrets, ECR CronJob |
| `/cicd:supply-chain-compliance` | 공급망 컴플라이언스 — EU Cyber Resilience Act, SBOM 자동화, VEX, 중앙 저장소 아키텍처 |
| `/cicd:supply-chain-security` | 소프트웨어 공급망 보안 — SBOM, SLSA 레벨과 provenance, Sigstore/Cosign 서명, K8s 정책 적용 |

## Agents (4)

| 이름 | 설명 |
|---|---|
| `cicd:ci-optimizer` | CI/CD 파이프라인 분석 및 최적화 에이전트. 빌드 시간 분석, 병목 지점 식별, DORA 메트릭 추적, Flaky 테스트 탐지 |
| `cicd:cicd-reviewer` | CI/CD 파이프라인 종합 리뷰어 — 비용, 캐싱, 권한 범위, 작업 구조, 시크릿 관리 best practice |
| `cicd:cicd-security-reviewer` | CI/CD 공격 표면 전문 리뷰어 — OWASP Top 10 CI/CD Risks + SLSA framework. Pipeline poisoning, secret exfiltration, … |
| `cicd:gitops-reviewer` | AI-powered GitOps configuration reviewer |
