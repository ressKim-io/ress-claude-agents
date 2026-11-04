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
| `/infra:aws-eks` | AWS EKS 기본 — 클러스터 구성, VPC 설계, IRSA, Add-ons 관리 |
| `/infra:aws-eks-advanced` | EKS 심화 — Karpenter 설정, 보안 강화, 운영 최적화 |
| `/infra:aws-lambda` | AWS Lambda 서버리스 — 콜드 스타트 최적화, 이벤트 소스 통합, VPC 연결, 비용 최적화 |
| `/infra:cloud-cli-safety` | AWS·GCP 위험 CLI 명령 카탈로그 — 데이터 손실, 권한, 비용 폭증 위험 |
| `/infra:compatibility-matrix` | K8s 에코시스템 버전 호환성 매트릭스 — kind·EKS·GKE 버전 매핑, add-on 호환성, deprecated API 검증 |
| `/infra:compose-to-k8s` | Docker Compose 에서 Kubernetes 매니페스트로 전환 — Kompose 자동 변환, 수동 패턴, StatefulSet |
| `/infra:crossplane` | Crossplane 기본 — 설치, Provider, Managed Resources, Compositions, Terraform 과 비교 |
| `/infra:crossplane-advanced` | Crossplane 심화 — GCP·Azure ProviderConfig, ArgoCD 연동, drift 감지와 수정, Crossplane v2 |
| `/infra:database` | DB 성능 일반 — 인덱스 설계, N+1 해결, 쿼리 최적화, 커넥션 풀 설정 |
| `/infra:database-migration` | DB 스키마 마이그레이션 도구 — Flyway, Liquibase, golang-migrate, 안전한 스키마 변경 |
| `/infra:database-sharding` | DB 샤딩 — Shard Key 선택, Citus·Vitess, Resharding, cross-shard 쿼리, Read Replica, hot shard 해결 |
| `/infra:db-managed-service-checklist` | self-hosted PostgreSQL·MySQL 에서 RDS, Cloud SQL, Aurora 로 이전할 때 체크리스트 — 권한·확장·설정 차이, pg_restore·mysqldump 주의 |
| `/infra:docker` | Dockerfile 최적화 — 멀티스테이지 빌드, Go·Spring Boot 컨테이너, 레이어 캐시, 보안, 멀티 플랫폼 빌드, Compose |
| `/infra:eks-pitfalls` | EKS 운영 함정 — VPC CNI prefix delegation·max-pods, 서브넷 CIDR, WARM_IP_TARGET, Kyverno webhook, IAM 누락, IMDS |
| `/infra:expand-contract-pattern` | 무중단 DB 스키마 변경 3단계 Expand-Contract — NOT NULL 컬럼 추가, 컬럼명·타입 변경, backfill, 롤백 안전성 |
| `/infra:mysql-operations` | MySQL/InnoDB 운영 — buffer pool·redo log 등 InnoDB 파라미터 튜닝, EXPLAIN 쿼리 최적화, ProxySQL 커넥션 풀링과 읽기/쓰기 분리, Group … |
| `/infra:postgresql-operations` | PostgreSQL 운영 — postgresql.conf 파라미터 튜닝, EXPLAIN ANALYZE 쿼리 최적화, 잠금 진단, PgBouncer 커넥션 풀링, Percona Operator 기반 … |
| `/infra:redis-operations` | Redis 운영 — Standalone/Sentinel/Cluster 모드 선택, Cache-Aside·Write-Through 캐싱 전략과 Cache Stampede 방지, … |
| `/infra:terraform-k8s-bootstrap` | Terraform 으로 EKS/GKE 를 만들고 ArgoCD 로 넘기는 부트스트랩 — 책임 경계, 순환 의존성, App of Apps |
| `/infra:terraform-modules` | Terraform 모듈 작성 — 디렉터리 구조, variables·outputs·versions·locals 템플릿, 변수 validation, 네이밍 |
| `/infra:terraform-pitfalls` | Terraform/OpenTofu 운영 함정 — Security Group 인라인 규칙 충돌, ENI IP 계산, create_before_destroy, ignore_changes, state … |
| `/infra:terraform-security` | Terraform 보안 — sensitive 변수, IAM 최소 권한, 암호화, Security Group, S3 버킷, tfsec 검사 |

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
