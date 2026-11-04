<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# infra

인프라 — Terraform, AWS·EKS, Docker, Crossplane, DB 운영·마이그레이션, 클라우드 CLI 안전

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install infra@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/infra/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`java`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/java/README.md)
- [`messaging`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/messaging/README.md)
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`saas`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/saas/README.md)
- [`security`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/security/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`infra/terraform.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/infra/terraform.md)
- [`core/cloud-cli-safety.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/cloud-cli-safety.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (22)

| 이름 | 설명 |
|---|---|
| `/infra:aws-eks` | AWS EKS 가이드 — EKS 클러스터 구성, VPC 설계, IRSA, Add-ons 관리 |
| `/infra:aws-eks-advanced` | AWS EKS 고급 가이드 — Karpenter 설정, 보안 강화, 운영 최적화 |
| `/infra:aws-lambda` | AWS Lambda & Serverless Patterns — AWS Lambda 기반 서버리스 아키텍처 설계, 콜드 스타트 최적화, 이벤트 소스 통합 |
| `/infra:cloud-cli-safety` | AWS / GCP 위험 CLI 명령 카탈로그 — 데이터 손실 / 권한 / 비용 폭증 위험 |
| `/infra:compatibility-matrix` | Compatibility Matrix 가이드 — K8s 에코시스템 버전 호환성 매트릭스 관리. EKS/GKE/kind 간 전환 시 버전 조합 검증 |
| `/infra:compose-to-k8s` | Docker Compose → Kubernetes 전환 가이드 — Docker Compose에서 Kubernetes 매니페스트로의 전환 패턴. Kompose 활용 및 수동 전환 전략 |
| `/infra:crossplane` | Crossplane 멀티클라우드 가이드 — Kubernetes-native 인프라 관리: Provider 설정, Compositions, 멀티클라우드 패턴 |
| `/infra:crossplane-advanced` | Crossplane 고급 패턴 가이드 — 멀티클라우드 패턴, GitOps 통합, Drift Detection, Crossplane v2 |
| `/infra:database` | Database Patterns — 인덱스 최적화, N+1 해결, 쿼리 성능, 마이그레이션 패턴 |
| `/infra:database-migration` | Database Migration Patterns — Flyway, Liquibase, golang-migrate, 안전한 스키마 변경 패턴 |
| `/infra:database-sharding` | 데이터베이스 샤딩 가이드 — 대규모 트래픽 환경에서 수평 확장을 위한 샤딩 전략, Shard Key 선택, Citus/Vitess 구현, Read Replica 패턴 |
| `/infra:db-managed-service-checklist` | 매니지드 DB 서비스(RDS, Cloud SQL, Aurora 등)와 self-hosted/local DB의 차이를 점검하는 체크리스트. superuser 권한, schema, extension, … |
| `/infra:docker` | Docker & Dockerfile Patterns — Dockerfile 최적화, 멀티스테이지 빌드, Go/Java 컨테이너 패턴 |
| `/infra:eks-pitfalls` | EKS 운영 Pitfalls — EKS 운영 중 발생하는 실전 함정 카탈로그. 매니지드 노드그룹/IAM/networking/스케일링 |
| `/infra:expand-contract-pattern` | Zero-downtime DB schema migration을 위한 Expand-Contract (Parallel Change) 패턴. NOT NULL 컬럼 추가/컬럼명 변경/타입 변경을 3단계 … |
| `/infra:mysql-operations` | MySQL/InnoDB 운영 — buffer pool·redo log 등 InnoDB 파라미터 튜닝, EXPLAIN 쿼리 최적화, ProxySQL 커넥션 풀링과 읽기/쓰기 분리, Group … |
| `/infra:postgresql-operations` | PostgreSQL 운영 — postgresql.conf 파라미터 튜닝, EXPLAIN ANALYZE 쿼리 최적화, 잠금 진단, PgBouncer 커넥션 풀링, Percona Operator 기반 … |
| `/infra:redis-operations` | Redis 운영 — Standalone/Sentinel/Cluster 모드 선택, Cache-Aside·Write-Through 캐싱 전략과 Cache Stampede 방지, … |
| `/infra:terraform-k8s-bootstrap` | Terraform K8s Bootstrap 가이드 — Terraform→EKS/GKE→ArgoCD 부트스트랩 패턴, 책임 경계 정의, 순환 의존성 해결 |
| `/infra:terraform-modules` | Terraform Module Patterns — Terraform 모듈 개발 패턴 및 best practices |
| `/infra:terraform-pitfalls` | Terraform 실전 Pitfalls — Terraform/OpenTofu 운영 중 발생하는 실전 함정. state 관리/모듈 설계/순환 의존/secret 노출 |
| `/infra:terraform-security` | Terraform Security Patterns — Terraform 보안 패턴 및 best practices |

## Agents (5)

| 이름 | 설명 |
|---|---|
| `infra:container-security-reviewer` | 컨테이너 공격 표면 전문 리뷰어 — CIS Docker Benchmark + 공급망 공격 방지. Container escape, signed image, runtime security를 공격자 … |
| `infra:dockerfile-reviewer` | Dockerfile / docker-compose 종합 리뷰어 — base image 선택, 레이어 최적화, multi-stage, 빌드 캐시, 이미지 size, Compose 품질 |
| `infra:infra-roadmap-planner` | Multi-phase 인프라 전환 계획 에이전트. EC2/docker-compose → kind/k3s → EKS/GKE 같은 단계별 인프라 진화를 계획하고, 처음부터 변수화·호환성을 고려한 … |
| `infra:migration-expert` | 프레임워크, 언어, DB, 인프라 버전 업그레이드 전문 에이전트. 위험 평가, 계획 수립, 단계별 실행, 검증까지 마이그레이션 전체 사이클 지원 |
| `infra:terraform-reviewer` | AI-powered Terraform/OpenTofu code reviewer |

## Commands (4)

| 이름 | 설명 |
|---|---|
| `/infra:terraform-module-gen` | Terraform: 재사용 가능한 모듈을 생성합니다 |
| `/infra:terraform-plan-review` | Terraform: terraform plan 결과를 분석합니다 |
| `/infra:terraform-security-check` | Terraform: 보안 취약점을 검사합니다 |
| `/infra:terraform-validate` | Terraform: best practice 및 품질을 검증합니다 |
