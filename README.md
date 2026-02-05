<div align="center">

# ress-claude-agents

![Claude](https://img.shields.io/badge/Claude_Code-D97757?style=for-the-badge&logo=claude&logoColor=white)
![Skills](https://img.shields.io/badge/Skills-128-2563EB?style=for-the-badge)
![Agents](https://img.shields.io/badge/Agents-24-F97316?style=for-the-badge)
![Lines](https://img.shields.io/badge/47K+_Lines-4F46E5?style=for-the-badge)

[![CI](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml/badge.svg)](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/ressKim-io/ress-claude-agents?style=social)](https://github.com/ressKim-io/ress-claude-agents)

### AI가 동료가 되는 개발 환경을 설계합니다

DevOps · Backend · SRE · MLOps를 위한 Production-ready Claude Code 확장

[Why AI-First](#-why-ai-first) · [By Numbers](#-by-numbers) · [Quick Start](#-quick-start) · [Agents](#-agents) · [Skills](#-skills) · [Automation](#-automation-infrastructure)

</div>

---

## 🧪 Why AI-First

> *"Google 검색 → StackOverflow → 복사 → 적용 → 디버깅"*
> *이 반복 루프를 끊을 수 있다면?*

저는 Claude Code를 단순 코드 자동완성이 아닌, **도메인 전문가로** 만들어 함께 일하는 방식을 실험합니다.
128개의 Skills에 각 분야의 Best Practices를 구조화하고, 24개의 Agents가 자율적으로 판단하고 실행합니다.

```
🔄 기존 방식                          ⚡ AI-Augmented 방식
──────────────────                    ──────────────────
Google/StackOverflow 검색              → /k8s-security 로 즉시 패턴 적용
Runbook 찾아서 수동 실행               → incident-responder 가 자동 진단
"이거 어떻게 해요?" 반복 질문          → 47,000줄의 지식 베이스가 즉시 답변
100만 VU 테스트 시나리오 수동 작성     → load-tester-k6 가 템플릿 제공
```

**이 레포가 해결하는 문제:**
- 매번 같은 패턴을 검색하고 복사하는 비효율
- 팀원마다 다른 코딩 스타일과 아키텍처 결정
- 장애 대응 시 Runbook을 찾느라 낭비되는 MTTR
- 새로운 기술 도입 시 러닝 커브

---

## 📊 By Numbers

<div align="center">

| | Metric | Value | Description |
|---|--------|-------|-------------|
| 🤖 | **Agents** | 24 (~7,900줄) | 보안, 인시던트, FinOps, MLOps 등 자율 실행 전문가 |
| 💡 | **Skills** | 128 (~41,900줄) | Go, Spring, K8s, MSA, eBPF 등 온디맨드 도메인 지식 |
| ⚡ | **Commands** | 35 | `/go review`, `/java performance` 등 자동화 워크플로우 |
| 📦 | **Templates** | 4 | Go, Java, K8s, Terraform 프로젝트 부트스트래핑 |
| 🧪 | **Tests** | 36 cases | BATS 테스트 + CI 검증으로 100% 자동화 |
| 📏 | **Total** | **47,000+ lines** | 체계적으로 카테고리화된 AI 지식 체계 |

</div>

---

## 🚀 Quick Start

```bash
# Clone
git clone https://github.com/ressKim-io/ress-claude-agents.git
cd ress-claude-agents

# 전역 설치 (모든 프로젝트에 적용)
./install.sh --global --all --with-skills

# 또는 필요한 것만 수동 복사
cp -r .claude/agents ~/.claude/agents    # Agents만
cp -r .claude/skills ~/.claude/skills    # Skills만
```

### 사용 예시

```bash
# Claude Code에서 agents 확인
/agents

# Agent 자동 선택 (자연어로 요청)
"보안 취약점 검사해줘"           → security-scanner
"프로덕션 파드가 죽어요"         → k8s-troubleshooter
"100만 동시접속 아키텍처 설계해줘" → ticketing-expert
"K6로 부하테스트 시나리오 작성해줘" → load-tester-k6
```

---

## 🤖 Agents

Claude Code의 **Subagent 시스템**을 활용한 자율 실행 AI 에이전트 (23 files, ~7,500줄).

> **Skills**는 "지식"이고, **Agents**는 "전문가"입니다. 자율적으로 판단하고 작업을 수행합니다.

### DevOps & SRE

| Agent | Description | Auto-trigger |
|-------|-------------|--------------|
| 🔒 `security-scanner` | OWASP Top 10, 시크릿 탐지, 취약점 분석 | 코드 변경 후 |
| 🔧 `k8s-troubleshooter` | K8s 문제 진단, 근본 원인 분석, AIOps | 장애 발생 시 |
| 📋 `terraform-reviewer` | IaC 보안/비용/신뢰성 11개 도메인 리뷰 | `terraform plan` 전 |
| 🚨 `incident-responder` | 장애 대응 자동화, MTTR 단축, 런북 실행 | 인시던트 발생 시 |
| 👀 `code-reviewer` | 멀티 언어 코드 리뷰, 버그/성능/보안 탐지 | PR 생성 후 |
| 💰 `cost-analyzer` | FinOps 분석, 비용 이상 탐지, 최적화 제안 | 비용 리뷰 시 |
| 📈 `finops-advisor` | FinOps 전략, 성숙도 평가, 도구 선택, GreenOps | 비용 전략 수립 시 |
| 📡 `otel-expert` | 대규모 OTel 아키텍처, Tail Sampling, 비용 최적화 | 10K+ RPS OTel 구축 시 |

### Platform & MLOps

| Agent | Description | Auto-trigger |
|-------|-------------|--------------|
| 🏗️ `platform-engineer` | IDP 설계, Backstage, Golden Path, DX 최적화 | 플랫폼 구축 시 |
| 🧠 `mlops-expert` | GPU 스케줄링, 분산 학습, 모델 서빙, LLM 배포 | AI/ML 워크로드 시 |
| 🗄️ `database-expert` | PostgreSQL 튜닝, PgBouncer, K8s DB 운영 | PostgreSQL 성능 이슈 시 |
| 🗄️ `database-expert-mysql` | MySQL/InnoDB 튜닝, ProxySQL, MySQL HA | MySQL 성능 이슈 시 |
| 🔴 `redis-expert` | Redis Cluster, Sentinel, 캐싱 전략, Lua | Redis 최적화 시 |

### Language Experts (High-Traffic)

| Agent | Expertise | Key Patterns |
|-------|-----------|--------------|
| 🦫 `go-expert` | Go 대용량 트래픽 | Worker Pool, Fan-Out/In, sync.Pool, pprof |
| ☕ `java-expert` | Java/Spring 대용량 트래픽 | Virtual Threads (Java 21+), WebFlux, JVM 튜닝 |

### Ticketing Platform (1M+ Concurrent Users)

| Agent | Purpose | Core Features |
|-------|---------|---------------|
| 🎫 `ticketing-expert` | 티켓팅 아키텍처 | Virtual Waiting Room, Redis 대기열, Saga 패턴 |
| 🤖 `anti-bot` | 봇/매크로 방어 | Rate Limiting, 행동 분석, Device Fingerprint |
| 📊 `load-tester` | 부하 테스트 허브 | 도구 비교, 선택 가이드 |
| ⚡ `load-tester-k6` | K6 전문 | JavaScript, Grafana Cloud, K6 Operator |
| 🎯 `load-tester-gatling` | Gatling 전문 | Scala/Java DSL, 엔터프라이즈 |
| 🔄 `load-tester-ngrinder` | nGrinder 전문 | Groovy, Controller/Agent, 웹 UI |

### Workflow Automation

| Agent | Purpose | Features |
|-------|---------|----------|
| 📝 `git-workflow` | Git 워크플로우 자동화 | 커밋 메시지 생성, PR 자동화 |
| ⚙️ `ci-optimizer` | CI/CD 최적화 | 빌드 시간 분석, DORA 메트릭 |
| 🔍 `pr-review-bot` | AI PR 리뷰 설정 | Copilot/CodeRabbit/Claude Action |

---

## 💡 Skills

필요할 때만 로드되는 도메인 지식 (128 files, ~41,900줄).

<details>
<summary><b>Go & Spring (10 files)</b></summary>

```
/go-errors          # Error handling patterns
/go-gin             # Gin framework
/go-testing         # Table-driven testing
/concurrency-go     # Mutex, Channel, Worker Pool

/spring-data        # JPA, QueryDSL
/spring-cache       # Redis 캐싱
/spring-security    # Security, Method Security
/spring-oauth2      # OAuth2, JWT
/spring-testing     # JUnit, Mockito
/spring-testcontainers  # Testcontainers
```
</details>

<details>
<summary><b>MSA & High-Traffic (9 files)</b></summary>

```
/msa-saga               # Saga 패턴 (Choreography/Orchestration, Temporal.io)
/msa-cqrs-eventsourcing # CQRS + Event Sourcing, Eventual Consistency
/msa-resilience         # Circuit Breaker, Bulkhead, Retry/Timeout (Resilience4j)
/msa-event-driven       # EDA, Transactional Outbox, Idempotent Consumer, DLQ
/msa-ddd                # DDD, Bounded Context, Aggregate, Event Storming
/msa-api-gateway-patterns # BFF, Gateway Aggregation, API Versioning, gRPC-REST
/msa-observability      # Distributed Tracing, Correlation ID, Exemplar, Tempo
/database-sharding      # 샤딩 전략, Citus, Vitess, Read Replica
/high-traffic-design    # Backpressure, CDN, Connection Pool, Rate Limiting 심화
```
</details>

<details>
<summary><b>Kubernetes & Service Mesh (25 files)</b></summary>

```
/k8s-security       # Pod Security, RBAC, Kyverno, Trivy
/k8s-helm           # Helm chart best practices
/k8s-autoscaling    # HPA, VPA, KEDA
/k8s-autoscaling-advanced # Karpenter, 조합 전략, 모니터링
/k8s-scheduling     # Node Affinity, Taint, Pod Affinity
/k8s-scheduling-advanced # 실전 시나리오, Topology Spread, 디버깅
/k8s-traffic        # Rate Limiting, 대기열

/istio-core         # Sidecar vs Ambient, mTLS
/istio-ambient      # Ambient 심화, ztunnel, Waypoint, Cilium 통합
/istio-security     # PeerAuth, AuthorizationPolicy
/istio-gateway      # Classic vs Gateway API
/istio-observability # Metrics, Tracing, Kiali

/gateway-api        # Gateway API vs Ingress, Envoy, Kong
/gateway-api-migration # Ingress NGINX 마이그레이션, Istio Gateway
/crossplane         # Multi-cloud IaC, Compositions, XRDs
/crossplane-advanced # 멀티클라우드 패턴, GitOps 통합, Drift Detection
```
</details>

<details>
<summary><b>Monitoring & Observability (16 files)</b></summary>

```
/observability      # 로깅, RED Method
/observability-otel # OpenTelemetry SDK/Collector
/observability-otel-scale # 대규모 OTel 아키텍처 (10K+ RPS)
/observability-otel-optimization # OTel 비용 최적화, 샘플링, 스케일링
/ebpf-observability # eBPF, Grafana Beyla, Odigos
/ebpf-observability-advanced # Cilium Hubble, DeepFlow, 프로덕션 요구사항
/monitoring-grafana # 대시보드, 알림, RBAC
/monitoring-metrics # Prometheus, Thanos, VictoriaMetrics
/monitoring-logs    # Fluent Bit, Loki
/logging-compliance # PCI-DSS, 전자금융거래법
/logging-security   # 봇/매크로 탐지
/aiops              # AIOps, 이상 탐지, 자동 복구
```
</details>

<details>
<summary><b>SRE & DevOps (25 files)</b></summary>

```
/sre-sli-slo        # SLI/SLO, 에러 버짓
/cicd-devsecops     # GitHub Actions, Trivy, SonarQube
/gitops-argocd      # ArgoCD, App of Apps
/gitops-argocd-advanced # ApplicationSet, Sync 전략, 시크릿
/gitops-argocd-ai   # AI-assisted GitOps, Spacelift, 예측적 배포
/deployment-strategies # Canary, Blue-Green
/chaos-engineering  # LitmusChaos, Probe, 기본 실험
/chaos-engineering-gameday # GameDay 운영, 모니터링, 알림
/disaster-recovery  # Velero, 백업, 복구 절차
/disaster-recovery-advanced # 멀티 클러스터 DR, DB DR, 테스트
/ephemeral-environments # PR Preview, ArgoCD ApplicationSet
/ephemeral-environments-advanced # Qovery, DB 전략, 비용 최적화
/load-testing       # K6 기본/고급, K6 on Kubernetes
/load-testing-analysis # nGrinder, 결과 분석, SLO Threshold
/finops             # Kubecost, Right-sizing, Spot
/finops-advanced    # Showback/Chargeback, 이상 탐지
/finops-tools       # OpenCost, Kubecost, Infracost, KEDA+Karpenter
/finops-tools-advanced # Cast AI, Kubecost 고급, 4Rs Framework
/finops-greenops    # 탄소 발자국, 지속가능성, SCI
/supply-chain-security # SBOM, SLSA, Sigstore
/supply-chain-compliance # EU CRA, SBOM 자동화, VEX
```
</details>

<details>
<summary><b>Platform & MLOps (14 files)</b></summary>

```
/backstage          # Developer Portal, Software Catalog
/golden-paths       # 표준화 경로, 템플릿 패턴
/k8s-gpu            # NVIDIA Operator, MIG, Kueue, Volcano
/ml-serving         # KServe, vLLM, TensorRT-LLM
/mlops              # Kubeflow, KServe 배포
/mlops-tracking     # MLflow, 실험 추적, Model Registry
/llmops             # RAG 아키텍처, 프롬프트 관리, LLM 가드레일
/wasm-edge          # WebAssembly, WasmEdge, Spin, K8s 통합
/wasm-edge-iot      # Edge/IoT 활용, 성능 최적화
```
</details>

<details>
<summary><b>Developer Experience (10 files)</b></summary>

```
/dx-metrics         # DORA, SPACE, DevEx
/dx-ai-agents       # AI 에이전트 거버넌스, Copilot/Claude 통합
/dx-ai-agents-orchestration # 멀티 에이전트, 가드레일, Self-Healing
/dx-onboarding      # Time-to-First-Deploy
/local-dev-makefile # make up으로 풀스택 실행, Hot Reload, Dockerfile.dev
/docs-as-code       # MkDocs, Docusaurus, TechDocs
/docs-as-code-automation # API 문서 자동화, CI/CD, 품질 측정
/token-efficiency   # 토큰 & 컨텍스트 효율화, 낭비 패턴 방지
```
</details>

<details>
<summary><b>Infrastructure & Database (14 files)</b></summary>

```
/aws-eks            # EKS Terraform, IRSA, Add-ons
/aws-eks-advanced   # Karpenter, 보안 강화, 운영 최적화
/aws-lambda         # Serverless, 콜드 스타트 최적화, SnapStart
/terraform-modules  # Module patterns
/terraform-security # Security best practices
/kafka              # Strimzi, KEDA 연동
/kafka-patterns     # Producer/Consumer 패턴, 모니터링
/database           # 인덱스, N+1, 쿼리 최적화
/database-migration # Flyway, Liquibase
/distributed-lock   # Redis, Redisson
/grpc               # gRPC 서비스 설계, Protocol Buffers, 스트리밍
```
</details>

---

## ⚡ Commands

| Category | Commands |
|----------|----------|
| **Go** | `/go review`, `/go test-gen`, `/go lint`, `/go refactor` |
| **Java** | `/java review`, `/java test-gen`, `/java lint`, `/java refactor`, `/java performance` |
| **Backend** | `/backend review`, `/backend test-gen`, `/backend api-doc`, `/backend refactor` |
| **K8s** | `/k8s validate`, `/k8s secure`, `/k8s netpol`, `/k8s helm-check` |
| **Terraform** | `/terraform plan-review`, `/terraform security`, `/terraform module-gen` |
| **DX** | `/dx pr-create`, `/dx issue-create`, `/dx changelog`, `/dx release` |
| **Session** | `/session save`, `/session end` |

---

## 🏗️ Automation Infrastructure

이 레포는 컨텐츠만이 아니라, **컨텐츠를 관리하는 시스템** 자체도 자동화했습니다.

### Inventory 자동 생성

```bash
./scripts/generate-inventory.sh generate
# → .claude/inventory.yml 자동 생성
# → 모든 Skills/Agents 목록 + 줄 수 + 카테고리
# → CI에서 freshness 검증 (outdated 시 빌드 실패)
```

Claude Code 세션 시작 시 `inventory.yml`만 읽으면 전체 구조를 파악할 수 있어, **세션 시작 비용을 최소화**합니다.

### CI/CD Pipeline

GitHub Actions로 4개 Job이 매 커밋마다 실행됩니다:

| Job | Description |
|-----|-------------|
| **Test** | BATS 36 test cases 실행 |
| **Docs** | README ↔ 실제 파일 정합성 검증 |
| **Inventory** | `inventory.yml` freshness 체크 |
| **Lint** | ShellCheck으로 모든 스크립트 정적 분석 |

### Pre-commit Hooks & Quality Gates

```bash
make setup-hooks   # validate + lint 자동 실행
make all           # 전체 검증 (validate + test)
```

- 모든 Skill 파일 **500줄 미만** (Anthropic guidelines)
- 모든 Agent 파일 **600줄 미만**
- Smart installer: `--global` / `--local` / `--with-skills` 옵션 지원

---

## 🛠️ Tech Stack

<div align="center">

**Languages & Frameworks**

![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white)
![Java](https://img.shields.io/badge/Java-ED8B00?style=flat-square&logo=openjdk&logoColor=white)
![Spring](https://img.shields.io/badge/Spring_Boot-6DB33F?style=flat-square&logo=springboot&logoColor=white)
![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=kotlin&logoColor=white)

**Infrastructure & Orchestration**

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=flat-square&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS_EKS-FF9900?style=flat-square&logo=amazoneks&logoColor=white)
![Crossplane](https://img.shields.io/badge/Crossplane-0080FF?style=flat-square&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat-square&logo=helm&logoColor=white)

**GitOps & CI/CD**

![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=flat-square&logo=argo&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white)
![KEDA](https://img.shields.io/badge/KEDA-326CE5?style=flat-square&logoColor=white)

**Service Mesh & Networking**

![Istio](https://img.shields.io/badge/Istio-466BB0?style=flat-square&logo=istio&logoColor=white)
![Envoy](https://img.shields.io/badge/Envoy-AC6199?style=flat-square&logoColor=white)

**Observability**

![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat-square&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?style=flat-square&logo=grafana&logoColor=white)
![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-000000?style=flat-square&logo=opentelemetry&logoColor=white)

**Messaging & Database**

![Kafka](https://img.shields.io/badge/Apache_Kafka-231F20?style=flat-square&logo=apachekafka&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-DC382D?style=flat-square&logo=redis&logoColor=white)

**AI/ML**

![Kubeflow](https://img.shields.io/badge/Kubeflow-2196F3?style=flat-square&logoColor=white)
![MLflow](https://img.shields.io/badge/MLflow-0194E2?style=flat-square&logo=mlflow&logoColor=white)

</div>

---

## 🎯 Design Philosophy

[Anthropic의 Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)를 따라 설계했습니다:

### Progressive Disclosure

```
세션 시작 → CLAUDE.md (~100 tokens)
         → inventory.yml 참조로 전체 구조 파악
         → 필요한 Skill만 로드 (<5,000 tokens)
```

매 세션마다 47,000줄을 읽는 대신, **필요한 순간에 필요한 지식만** 로드합니다.

### Token Efficiency

| Rule | Description |
|------|-------------|
| 파일 크기 확인 | `wc -l` 사용 (전체 Read 금지) |
| Agent 위임 | 대상 파일 미리 읽지 않기 (경로만 전달) |
| Write 검증 | `wc -l` + `head`/`tail` (전체 Read-back 금지) |
| 동일 파일 | 2회 이상 읽기 금지 (1회 Read + Edit 패턴) |

### Anthropic Guidelines 준수

- **모든 Skill 파일 500줄 미만** - Claude가 효율적으로 처리할 수 있는 크기
- **Compact CLAUDE.md** - 50-80줄, 핵심 규칙만 포함
- **Multi-Agent Architecture** - 전문화된 에이전트가 협력
- **Inventory 시스템** - 세션 시작 비용 최소화

> *"For each line, ask: 'Would removing this cause Claude to make mistakes?'"*

---

## 📁 Structure

```
ress-claude-agents/
├── .claude/
│   ├── agents/               # 23 autonomous AI agents
│   │   ├── security-scanner.md
│   │   ├── k8s-troubleshooter.md
│   │   ├── ticketing-expert.md
│   │   ├── finops-advisor.md # FinOps 전략, GreenOps
│   │   ├── platform-engineer.md # IDP, Backstage
│   │   ├── mlops-expert.md   # GPU, 모델 서빙
│   │   ├── database-expert.md # PostgreSQL
│   │   ├── database-expert-mysql.md # MySQL
│   │   ├── otel-expert.md    # 대규모 OTel
│   │   ├── load-tester*.md   # Hub + K6/Gatling/nGrinder
│   │   └── ...
│   ├── skills/               # 128 on-demand knowledge files
│   ├── inventory.yml         # Auto-generated skill/agent index
│   └── standards.yml         # Code quality standards
├── commands/                 # 35 automation commands
├── project-templates/        # Go, Java, K8s, Terraform
├── scripts/
│   ├── generate-docs.sh      # Documentation generator
│   └── generate-inventory.sh # Inventory generator
├── global/CLAUDE.md          # Global settings
├── tests/                    # BATS tests (36 cases)
└── install.sh                # Smart installer
```

---

## 🧪 Development

```bash
make test          # BATS 테스트 (36 cases)
make validate      # README ↔ 파일 정합성 검증
make inventory     # .claude/inventory.yml 재생성
make lint          # ShellCheck 정적 분석
make all           # validate + test (전체 검증)
make setup-hooks   # Pre-commit hook 설치
```

---

## 🔗 Related Resources

### Awesome Claude Code
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) - Skills, hooks, slash-commands 모음
- [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) - 100+ subagents 컬렉션
- [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills) - Skills 및 도구 모음
- [anthropics/skills](https://github.com/anthropics/skills) - Anthropic 공식 Skills

### Official Documentation
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices) - Anthropic 공식 가이드
- [Claude Code Docs](https://docs.anthropic.com/claude-code) - Skills, Commands, MCP
- [Agent Skills Standard](https://agentskills.io/) - Skills 표준

---

## 🤝 Contributing

AI-augmented development에 관심이 있다면 이슈나 PR 환영합니다.

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/ress-claude-agents.git

# Create branch
git checkout -b feature/your-feature

# Run tests before commit
make all
```

---

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with Claude Code**

*AI를 도구가 아닌 동료로 — 47,000줄의 AI 지식 체계*

[![GitHub Stars](https://img.shields.io/github/stars/ressKim-io/ress-claude-agents?style=for-the-badge&color=yellow)](https://github.com/ressKim-io/ress-claude-agents)

</div>
