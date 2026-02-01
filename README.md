# ress-claude-agents

<div align="center">

[![Awesome](https://awesome.re/badge.svg)](https://awesome.re)
[![CI](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml/badge.svg)](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Powered-blueviolet.svg)](https://docs.anthropic.com/claude-code)

[![Agents](https://img.shields.io/badge/Agents-17-orange.svg)](#-agents-autonomous-ai-assistants)
[![Skills](https://img.shields.io/badge/Skills-66-blue.svg)](#-skills-on-demand-knowledge)
[![Commands](https://img.shields.io/badge/Commands-29-green.svg)](#commands)
[![Last Updated](https://img.shields.io/badge/Updated-Feb_2026-brightgreen.svg)](#)

**Production-ready Claude Code extensions for DevOps & Backend Engineering**

[Quick Start](#-quick-start) · [Agents](#-agents-autonomous-ai-assistants) · [Skills](#-skills-on-demand-knowledge) · [Why AI-First](#-why-ai-first-development)

</div>

---

## 🧪 Why AI-First Development

> *"AI가 개발 워크플로우를 어떻게 바꿀 수 있을까?"*

저는 이 질문에 답하기 위해 Claude Code를 일상 업무에 적극 활용하고 있습니다. 단순히 코드 자동완성이 아니라, **AI를 도메인 전문가로 만들어** 함께 일하는 방식을 실험합니다.

```
🔄 기존 방식                          ⚡ AI-Augmented 방식
──────────────────                    ──────────────────
Google/StackOverflow 검색              → /k8s-security 로 즉시 패턴 적용
Runbook 찾아서 수동 실행               → incident-responder 가 자동 진단
100만 VU 테스트 시나리오 작성          → load-tester-k6 가 템플릿 제공
"이거 어떻게 해요?" 반복 질문          → ticketing-expert 가 아키텍처 설계
```

### 📊 This Repository by Numbers

| Metric | Value | Description |
|--------|-------|-------------|
| **17 Agents** | ~5,100 lines | 자율 실행 AI 에이전트 (보안, 인시던트, 비용 분석 등) |
| **66 Skills** | ~18,000 lines | 온디맨드 도메인 지식 (Go, Spring, K8s, Istio 등) |
| **29 Commands** | Custom workflows | 자동화 명령어 (/go review, /k8s secure 등) |
| **4 Templates** | Project setups | Go, Java, K8s, Terraform 프로젝트 템플릿 |
| **100%** | Test coverage | BATS 테스트 + CI 검증 |

### 🎯 Design Philosophy

[Anthropic의 Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)를 따라 설계했습니다:

1. **Compact CLAUDE.md** - 50-80줄, 핵심 규칙만
2. **Progressive Disclosure** - 필요할 때만 Skills 로드 (~100 tokens → <5k tokens)
3. **Optimized for Claude** - 모든 Agent 파일 600줄 미만 (권장 범위)
4. **Multi-Agent Architecture** - 전문화된 에이전트가 협력

> *"For each line, ask: 'Would removing this cause Claude to make mistakes?'"*

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

## 🤖 Agents (Autonomous AI Assistants)

Claude Code의 **Subagent 시스템**을 활용한 자율 실행 AI 에이전트 (17 files, ~5,100줄).

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

## 💡 Skills (On-demand Knowledge)

필요할 때만 로드되는 도메인 지식 (66 files, ~18,000줄).

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
<summary><b>Kubernetes & Istio (17 files)</b></summary>

```
/k8s-security       # Pod Security, RBAC, Kyverno, Trivy
/k8s-helm           # Helm chart best practices
/k8s-autoscaling    # HPA, VPA, KEDA, Karpenter
/k8s-scheduling     # Node Affinity, Taint, Topology
/k8s-traffic        # Rate Limiting, 대기열

/istio-core         # Sidecar vs Ambient, mTLS
/istio-security     # PeerAuth, AuthorizationPolicy
/istio-gateway      # Classic vs Gateway API
/istio-observability # Metrics, Tracing, Kiali
```
</details>

<details>
<summary><b>Monitoring & Observability (10 files)</b></summary>

```
/observability      # 로깅, RED Method
/observability-otel # OpenTelemetry SDK/Collector
/monitoring-grafana # 대시보드, 알림, RBAC
/monitoring-metrics # Prometheus, Thanos, VictoriaMetrics
/monitoring-logs    # Fluent Bit, Loki
/logging-compliance # PCI-DSS, 전자금융거래법
/logging-security   # 봇/매크로 탐지
```
</details>

<details>
<summary><b>SRE & DevOps (15 files)</b></summary>

```
/sre-sli-slo        # SLI/SLO, 에러 버짓
/cicd-devsecops     # GitHub Actions, Trivy, SonarQube
/gitops-argocd      # ArgoCD, App of Apps
/deployment-strategies # Canary, Blue-Green
/chaos-engineering  # LitmusChaos, GameDay
/disaster-recovery  # Velero, Multi-cluster DR
/finops             # Kubecost, Right-sizing
```
</details>

<details>
<summary><b>Developer Experience (3 files)</b></summary>

```
/dx-metrics         # DORA, SPACE, DevEx
/dx-ai-agents       # AI 에이전트 거버넌스
/dx-onboarding      # Time-to-First-Deploy
```
</details>

<details>
<summary><b>Infrastructure & Database (11 files)</b></summary>

```
/aws-eks            # EKS Terraform, IRSA, Karpenter
/terraform-modules  # Module patterns
/terraform-security # Security best practices
/kafka              # Strimzi, KEDA 연동
/database           # 인덱스, N+1, 쿼리 최적화
/database-migration # Flyway, Liquibase
/distributed-lock   # Redis, Redisson
```
</details>

---

## ⚡ Commands

| Category | Commands |
|----------|----------|
| **Go** | `/go review`, `/go test-gen`, `/go lint`, `/go refactor` |
| **Backend** | `/backend review`, `/backend test-gen`, `/backend api-doc`, `/backend refactor` |
| **K8s** | `/k8s validate`, `/k8s secure`, `/k8s netpol`, `/k8s helm-check` |
| **Terraform** | `/terraform plan-review`, `/terraform security`, `/terraform module-gen` |
| **DX** | `/dx pr-create`, `/dx issue-create`, `/dx changelog`, `/dx release` |
| **Session** | `/session save`, `/session end` |

---

## 📁 Structure

```
ress-claude-agents/
├── .claude/
│   ├── agents/               # 17 autonomous AI agents
│   │   ├── security-scanner.md
│   │   ├── k8s-troubleshooter.md
│   │   ├── ticketing-expert.md
│   │   ├── load-tester*.md   # Hub + K6/Gatling/nGrinder
│   │   └── ...
│   ├── skills/               # 66 on-demand knowledge files
│   └── standards.yml         # Code quality standards
├── commands/                 # 29 automation commands
├── project-templates/        # Go, Java, K8s, Terraform
├── global/CLAUDE.md          # Global settings
├── tests/                    # BATS tests (36 cases)
└── install.sh                # Installer with validation
```

---

## 🛠️ Tech Stack Coverage

| Category | Technologies |
|----------|-------------|
| **Languages** | Go (Gin), Java/Kotlin (Spring Boot) |
| **Infrastructure** | Kubernetes, Terraform, AWS EKS |
| **GitOps** | ArgoCD, Argo Rollouts, KEDA |
| **Service Mesh** | Istio (Sidecar/Ambient), mTLS |
| **Observability** | Prometheus, Grafana, OpenTelemetry, Loki |
| **Messaging** | Apache Kafka (Strimzi) |
| **Security** | Kyverno, Trivy, PCI-DSS |
| **SRE** | SLI/SLO, Chaos Engineering, DR |

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

## 🧪 Development

```bash
# 테스트 실행
make test          # BATS 테스트

# 문서 검증
make validate      # 일관성 검증

# 전체 검증
make all           # validate + test
```

---

## 📈 Statistics

| Item | Count |
|------|-------|
| **Agents** | 17 files (~5,100 lines) |
| **Skills** | 66 files (~18,000 lines) |
| **Commands** | 29 files |
| **Templates** | 4 projects |
| **Tests** | 36 cases |
| **Total** | ~25,000+ lines |

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

**Built with Claude Code** 🤖

*이 저장소의 대부분의 코드와 문서는 Claude와 함께 작성되었습니다.*

[![GitHub Stars](https://img.shields.io/github/stars/ressKim-io/ress-claude-agents?style=social)](https://github.com/ressKim-io/ress-claude-agents)

</div>
