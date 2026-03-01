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
| Java 코드 리뷰 | `java-expert` | `/effective-java`, `/spring-patterns` | "Java 코드 리뷰해줘" |
| Go 코드 리뷰 | `go-expert` | `/effective-go`, `/go-microservice` | "Go 코드 리뷰해줘" |
| API 설계 | `architect-agent` | `/api-design`, `/grpc` | "REST API 설계 검토해줘" |
| MSA 서비스 분리 | `architect-agent` | `/msa-ddd`, `/hexagonal-clean-architecture` | "서비스 경계 설계해줘" |
| 분산 트랜잭션 | `saga-agent` | `/msa-saga`, `/msa-event-driven` | "Saga 패턴 구현해줘" |
| 복원력 패턴 | `java-expert` | `/msa-resilience`, `/spring-cache` | "Circuit Breaker 설정해줘" |
| DB 성능 이슈 | `database-expert` | `/database`, `/database-sharding` | "쿼리 최적화해줘" |
| Redis 캐싱 | `redis-expert` | `/spring-cache`, `/distributed-lock` | "Redis 캐싱 전략 설계해줘" |
| 부하 테스트 | `load-tester-k6` | `/load-testing` | "K6로 부하테스트 시나리오 작성해줘" |
| 테스트 작성 | `code-reviewer` | `/spring-testing`, `/go-testing` | "테스트 코드 작성해줘" |

### Java 전용 콤보

```
Spring 신규 프로젝트:
  /spring-patterns → /effective-java → /spring-security → /spring-testing

Spring 성능 최적화:
  java-expert → /concurrency-spring → /spring-cache → /spring-jooq
```

### Go 전용 콤보

```
Go 신규 프로젝트:
  /effective-go → /go-microservice → /go-database → /go-testing

Go 성능 최적화:
  go-expert → /concurrency-go → /go-database → /refactoring-go
```

---

## 3. DevOps / SRE 콤보

> 상세 가이드: [personas/devops-sre.md](personas/devops-sre.md)

| 상황 | 핵심 에이전트 | 지원 스킬 | 이렇게 요청하세요 |
|------|-------------|----------|-----------------|
| K8s 장애 진단 | `k8s-troubleshooter` | `/k8s-security`, `/k8s-autoscaling` | "파드가 죽어요, 원인 분석해줘" |
| 프로덕션 인시던트 | `incident-responder` | `/observability`, `/monitoring-troubleshoot` | "프로덕션 장애 대응해줘" |
| Terraform 리뷰 | `terraform-reviewer` | `/terraform-modules`, `/terraform-security` | "Terraform plan 리뷰해줘" |
| GitOps 배포 | `ci-optimizer` | `/gitops-argocd`, `/deployment-strategies` | "ArgoCD 배포 설정해줘" |
| 관측성 구축 | `otel-expert` | `/observability-otel`, `/monitoring-grafana` | "OTel Collector 설정해줘" |
| Service Mesh | `k8s-troubleshooter` | `/istio-core`, `/linkerd` | "Istio 설정 검토해줘" |
| 비용 최적화 | `cost-analyzer` | `/finops`, `/finops-tools` | "클라우드 비용 분석해줘" |
| 카오스 테스트 | `incident-responder` | `/chaos-engineering` | "카오스 실험 설계해줘" |
| DR 계획 | `k8s-troubleshooter` | `/disaster-recovery` | "DR 계획 수립해줘" |
| CI/CD 최적화 | `ci-optimizer` | `/cicd-devsecops`, `/cicd-policy` | "CI 파이프라인 분석해줘" |

### IaC 콤보

```
EKS 클러스터 구축:
  terraform-reviewer → /aws-eks → /aws-eks-advanced → /k8s-security

멀티클라우드 IaC:
  terraform-reviewer → /crossplane → /crossplane-advanced → /terraform-modules
```

### 관측성 콤보

```
Full Observability Stack:
  otel-expert → /observability-otel → /monitoring-grafana → /monitoring-metrics → /alerting-discord

eBPF 기반 Zero-Code:
  otel-expert → /ebpf-observability → /ebpf-observability-advanced
```

---

## 4. 풀스택 / 제너럴리스트 콤보

> 상세 가이드: [personas/fullstack-generalist.md](personas/fullstack-generalist.md)

| 상황 | 핵심 에이전트 | 지원 스킬 | 이렇게 요청하세요 |
|------|-------------|----------|-----------------|
| 새 프로젝트 시작 | `architect-agent` | `/api-design`, `/docker` | "프로젝트 구조 설계해줘" |
| 코드 정리 | `code-reviewer` | `/refactoring-principles` | "코드 리팩토링해줘" |
| PR 자동화 | `git-workflow` | `/conventional-commits`, `/git-workflow` | "PR 만들어줘" |
| 개발환경 구축 | `platform-engineer` | `/local-dev-makefile`, `/docker` | "로컬 개발환경 설정해줘" |
| 문서화 | `dev-logger` | `/docs-as-code` | "API 문서 생성해줘" |
| 보안 점검 | `security-scanner` | `/k8s-security`, `/terraform-security` | "보안 취약점 검사해줘" |
| 기술 의사결정 | `architect-agent` | 해당 도메인 스킬 | "A vs B 비교해줘" |

---

## 5. 복합 콤보 — 에이전트 체이닝

여러 에이전트를 순서대로 사용하는 고급 패턴.

### 신규 MSA API 개발 (End-to-End)

> 시나리오 가이드: [scenarios/new-microservice.md](scenarios/new-microservice.md)

```
1. architect-agent    → 서비스 경계 설계, API 계약 정의
      ↓
2. java-expert 또는 go-expert → 코드 구현, 패턴 적용
      ↓
3. code-reviewer      → 코드 리뷰, 품질 검증
      ↓
4. security-scanner   → 보안 취약점 점검
      ↓
5. load-tester-k6     → 성능 검증
      ↓
6. git-workflow       → PR 생성
```

### 프로덕션 장애 대응 (Incident Response)

> 시나리오 가이드: [scenarios/production-incident.md](scenarios/production-incident.md)

```
1. incident-responder → 자동 트리아지, 심각도 분류
      ↓
2. k8s-troubleshooter → K8s 클러스터 진단
      ↓
3. database-expert    → DB 관련 이슈 분석 (필요 시)
      ↓
4. otel-expert        → 트레이스/메트릭 분석
      ↓
5. dev-logger         → 인시던트 기록 (/log-trouble)
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
5. otel-expert        → 관측성 기본값 설정
      ↓
6. finops-advisor     → 비용 전략 수립
```
