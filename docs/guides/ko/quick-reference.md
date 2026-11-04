[English](../quick-reference.md) | **한국어**

# 콤보 레퍼런스

> 상황별 에이전트 + 스킬 추천 조합. 이 파일이 "뭘 써야 하지?"의 답.

---

## 1. 코어 에센셜 — 모든 개발자 필수

시작하기 전에 이것만은 알아두세요.

### 자동 적용 Rules (항상 활성화)

| Rule | 역할 |
|------|------|
| `workflow` | Explore → Plan → Code → Verify → Commit 순서 강제 |
| `testing` | TDD, Given-When-Then, 커버리지 80%+ |
| `git` | Conventional Commits, PR 400줄 제한 |
| `security` | 시크릿 하드코딩 금지, 입력 검증 |
| `debugging` | Reproduce → Diagnose → Root Cause → Fix |
| `clean-code` | 메서드 20-50줄, Cognitive Complexity ≤15, Guard Clause, WHY 주석 |

### 핵심 Agents (가장 자주 사용)

| Agent | 언제 쓰나 | 트리거 |
|-------|----------|--------|
| `code-reviewer` | 코드 변경 후 리뷰 | `"코드 리뷰해줘"` |
| `security-scanner` | 보안 취약점 점검 | `"보안 검사해줘"` |
| `git-workflow` | 커밋, PR 자동화 | `"PR 만들어줘"` |

---

## 2. 백엔드 개발자 콤보

> 상세 가이드: [personas/backend-dev.md](personas/backend-dev.md)

| 상황 | 핵심 에이전트 | 지원 스킬 | 이렇게 요청하세요 |
|------|-------------|----------|-----------------|
| Java 코드 리뷰 | `/java:jvm-performance` | `/java:effective-java`, `/java:spring-patterns` | "Java 코드 리뷰해줘" |
| Go 코드 리뷰 | `/go:go-performance` | `/go:effective-go`, `/go:go-microservice` | "Go 코드 리뷰해줘" |
| API 설계 | `architect-agent` | `/architecture:api-design`, `/architecture:grpc` | "REST API 설계 검토해줘" |
| MSA 서비스 분리 | `architect-agent` | `/architecture:msa-ddd`, `/architecture:hexagonal-clean-architecture` | "서비스 경계 설계해줘" |
| 분산 트랜잭션 | — | `/architecture:msa-saga`, `/architecture:msa-event-driven` | "Saga 패턴 구현해줘" |
| 복원력 패턴 | `/java:jvm-performance` | `/architecture:msa-resilience`, `/java:spring-cache` | "Circuit Breaker 설정해줘" |
| DB 성능 이슈 | — | `/infra:postgresql-operations`, `/infra:mysql-operations`, `/infra:database-sharding` | "쿼리 최적화해줘" |
| Redis 캐싱 | — | `/infra:redis-operations`, `/java:spring-cache`, `/architecture:distributed-lock` | "Redis 캐싱 전략 설계해줘" |
| 부하 테스트 | `load-tester` | `/sre:load-testing` | "K6로 부하테스트 시나리오 작성해줘" |
| 테스트 작성 | `code-reviewer` | `/java:spring-testing`, `/go:go-testing` | "테스트 코드 작성해줘" |
| 클린 코드 리뷰 | `/dx:clean-code` | `/dx:clean-code`, `/dx:refactoring-principles` | "클린 코드 품질 확인해줘" |
| 보안 코드 리뷰 | `/dx:clean-code` | `/java:effective-java` 또는 `/go:effective-go` | "Java/Go 보안 리뷰해줘" |

### Java 전용 콤보

```
Spring 신규 프로젝트:
  /java:spring-patterns → /java:effective-java → /java:spring-security → /java:spring-testing

Spring 성능 최적화:
  /java:jvm-performance → /java:concurrency-spring → /java:spring-cache → /java:spring-jooq

클린 코드 + 리팩토링:
  /java:jvm-performance → /dx:clean-code → /dx:refactoring-principles → /java:refactoring-spring

보안 강화:
  /java:spring-security-review → security-scanner → /java:spring-security
```

### Go 전용 콤보

```
Go 신규 프로젝트:
  /go:effective-go → /go:go-microservice → /go:go-database → /go:go-testing

Go 성능 최적화:
  /go:go-performance → /go:concurrency-go → /go:go-database → /go:refactoring-go

클린 코드 + 리팩토링:
  /go:go-performance → /dx:clean-code → /dx:refactoring-principles → /go:refactoring-go

에러 핸들링 + OTel:
  /go:go-performance → /observability:observability-otel → /go:effective-go
```

---

## 3. DevOps / SRE 콤보

> 상세 가이드: [personas/devops-sre.md](personas/devops-sre.md)

| 상황 | 핵심 에이전트 | 지원 스킬 | 이렇게 요청하세요 |
|------|-------------|----------|-----------------|
| K8s 장애 진단 | `k8s-troubleshooter` | `/k8s:k8s-security`, `/k8s:k8s-autoscaling` | "파드가 죽어요, 원인 분석해줘" |
| 프로덕션 인시던트 | `incident-responder` | `/observability:observability`, `/observability:monitoring-troubleshoot` | "프로덕션 장애 대응해줘" |
| Terraform 리뷰 | `terraform-reviewer` | `/infra:terraform-modules`, `/infra:terraform-security` | "Terraform plan 리뷰해줘" |
| GitOps 배포 | `ci-optimizer` | `/cicd:gitops-argocd`, `/cicd:deployment-strategies` | "ArgoCD 배포 설정해줘" |
| 관측성 구축 | — | `/observability:observability-otel`, `/observability:observability-otel-scale`, `/observability:monitoring-grafana` | "OTel Collector 설정해줘" |
| Service Mesh | `k8s-troubleshooter` | `/service-mesh:istio-core`, `/service-mesh:linkerd` | "Istio 설정 검토해줘" |
| 비용 최적화 | `cost-analyzer` | `/sre:finops`, `/sre:finops-tools` | "클라우드 비용 분석해줘" |
| 카오스 테스트 | `incident-responder` | `/sre:chaos-engineering` | "카오스 실험 설계해줘" |
| DR 계획 | `k8s-troubleshooter` | `/sre:disaster-recovery` | "DR 계획 수립해줘" |
| CI/CD 최적화 | `ci-optimizer` | `/cicd:cicd-devsecops`, `/cicd:cicd-policy` | "CI 파이프라인 분석해줘" |
| K8s 매니페스트 리뷰 | `k8s-reviewer` | `/k8s:k8s-security`, `/k8s:k8s-helm` | "K8s 매니페스트 리뷰해줘" |
| Dockerfile 리뷰 | `dockerfile-reviewer` | `/infra:docker` | "Dockerfile 리뷰해줘" |
| CI/CD 파이프라인 리뷰 | `cicd-reviewer` | `/cicd:cicd-devsecops` | "GitHub Actions 리뷰해줘" |
| GitOps 리뷰 | `gitops-reviewer` | `/cicd:gitops-argocd` | "ArgoCD 설정 리뷰해줘" |
| 관측성 리뷰 | `observability-reviewer` | `/observability:observability-otel` | "Prometheus 규칙 리뷰해줘" |

### 보안 리뷰 콤보 (Red Team 대비)

```
K8s 보안 감사:
  k8s-security-reviewer + network-security-reviewer → /k8s:k8s-security

컨테이너 보안:
  container-security-reviewer + dockerfile-reviewer → /infra:docker

CI/CD 보안:
  cicd-security-reviewer → /cicd:supply-chain-security → /cicd:cicd-devsecops

펜테스트 전 종합:
  k8s-security-reviewer + container-security-reviewer + cicd-security-reviewer + network-security-reviewer
```

### IaC 콤보

```
EKS 클러스터 구축:
  terraform-reviewer → /infra:aws-eks → /infra:aws-eks-advanced → /k8s:k8s-security

멀티클라우드 IaC:
  terraform-reviewer → /infra:crossplane → /infra:crossplane-advanced → /infra:terraform-modules
```

### 관측성 콤보

```
Full Observability Stack:
  /observability:observability-otel → /observability:monitoring-grafana → /observability:monitoring-metrics → /observability:alerting-discord

eBPF 기반 Zero-Code:
  /observability:ebpf-observability → /observability:ebpf-observability-advanced
```

---

## 4. 풀스택 / 제너럴리스트 콤보

> 상세 가이드: [personas/fullstack-generalist.md](personas/fullstack-generalist.md)

| 상황 | 핵심 에이전트 | 지원 스킬 | 이렇게 요청하세요 |
|------|-------------|----------|-----------------|
| 새 프로젝트 시작 | `architect-agent` | `/architecture:api-design`, `/infra:docker` | "프로젝트 구조 설계해줘" |
| 코드 정리 | `code-reviewer` | `/dx:clean-code`, `/dx:refactoring-principles` | "코드 리팩토링해줘" |
| 클린 코드 점검 | `/dx:clean-code` | `/dx:clean-code` | "코드 가독성 확인해줘" |
| PR 자동화 | `git-workflow` | `/dx:conventional-commits`, `/dx:git-workflow` | "PR 만들어줘" |
| 개발환경 구축 | `platform-engineer` | `/dx:local-dev-makefile`, `/infra:docker` | "로컬 개발환경 설정해줘" |
| 문서화 | `dev-logger` | `/dx:docs-as-code` | "API 문서 생성해줘" |
| 보안 점검 | `security-scanner` | `/k8s:k8s-security`, `/infra:terraform-security` | "보안 취약점 검사해줘" |
| 기술 의사결정 | `architect-agent` | 해당 도메인 스킬 | "A vs B 비교해줘" |

---

## 5. 복합 콤보 — 에이전트 체이닝

여러 에이전트를 순서대로 사용하는 고급 패턴.

### 신규 MSA API 개발 (End-to-End)

> 시나리오 가이드: [scenarios/new-microservice.md](scenarios/new-microservice.md)

```
1. architect-agent    → 서비스 경계 설계, API 계약 정의
      ↓
2. /java:jvm-performance 또는 /go:go-performance → 코드 구현, 패턴 적용
      ↓
3. code-reviewer      → 코드 리뷰, 품질 검증
      ↓
4. /java:jvm-performance 또는 /go:go-performance → 클린 코드 + 보안 리뷰 (내장 체크리스트)
      ↓
5. security-scanner   → 보안 취약점 점검
      ↓
6. /sre:load-testing      → 성능 검증
      ↓
7. git-workflow       → PR 생성
```

### 프로덕션 장애 대응 (Incident Response)

> 시나리오 가이드: [scenarios/production-incident.md](scenarios/production-incident.md)

```
1. incident-responder → 자동 트리아지, 심각도 분류
      ↓
2. k8s-troubleshooter → K8s 클러스터 진단
      ↓
3. /infra:postgresql-operations → DB 관련 이슈 분석 (필요 시)
      ↓
4. /observability:observability-otel → 트레이스/메트릭 분석
      ↓
5. dev-logger         → 인시던트 기록 (/dx:log-trouble)
```

### IDP 구축 (Platform Bootstrap)

> 시나리오 가이드: [scenarios/platform-bootstrap.md](scenarios/platform-bootstrap.md)

```
1. platform-engineer  → IDP 설계, Backstage 구축
      ↓
2. architect-agent    → Golden Path 정의
      ↓
3. terraform-reviewer → IaC 리뷰, 보안 검증
      ↓
4. ci-optimizer       → CI/CD 파이프라인 최적화
      ↓
5. /observability:observability-otel → 관측성 기본값 설정
      ↓
6. finops-advisor     → 비용 전략 수립
```
