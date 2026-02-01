# ress-claude-agents

[![CI](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml/badge.svg)](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Powered-blueviolet.svg)](https://claude.ai/claude-code)
[![Skills](https://img.shields.io/badge/Skills-66_Files-blue.svg)](#skills-on-demand-knowledge)
[![Agents](https://img.shields.io/badge/Agents-10_Autonomous-orange.svg)](#agents-autonomous-ai-assistants)

> **AI와 함께 일하는 DevOps Engineer의 실험실**
>
> Claude Code를 활용해 DevOps/백엔드 개발 생산성을 극대화하는 agents, skills, commands 모음

## Why This Project?

AI가 개발 워크플로우를 어떻게 바꿀 수 있는지 직접 실험하고 있습니다.

```
기존 방식                          AI-Augmented 방식
──────────                         ─────────────────
Google/StackOverflow 검색          /k8s-security 로 즉시 패턴 적용
문서 왔다갔다 하며 복붙              /go review 로 코드 리뷰 자동화
반복적인 boilerplate 작성           /terraform module-gen 으로 생성
컨텍스트 매번 설명                   CLAUDE.md 로 프로젝트 컨텍스트 유지
```

**이 저장소는 Claude Code의 확장 시스템(Skills, Commands, MCP)을 활용해 AI를 "도메인 전문가"로 만드는 실험입니다.**

---

## Quick Start (수동 복사)

원하는 영역만 선택해서 복사하면 바로 사용 가능합니다.

### 복사 위치

| 범위 | 복사할 위치 | 효과 |
|------|------------|------|
| **전역 (모든 프로젝트)** | `~/.claude/` | 어디서든 사용 가능 |
| **프로젝트 전용** | `<프로젝트>/.claude/` | 해당 프로젝트만 적용 |

### 원하는 영역만 복사

```bash
# 1. Agents만 (자율 AI 에이전트) - 가장 강력
cp -r .claude/agents ~/.claude/agents

# 2. Skills만 (도메인 지식) - 가장 많이 사용
cp -r .claude/skills ~/.claude/skills

# 3. Commands만 (자동화 명령어)
cp -r commands ~/.claude/commands

# 4. 특정 skill만
cp .claude/skills/spring-*.md ~/.claude/skills/

# 5. 특정 command 카테고리만
cp -r commands/k8s ~/.claude/commands/

# 6. 전체 설정 (global CLAUDE.md 포함)
cp global/CLAUDE.md ~/.claude/CLAUDE.md
cp -r .claude/agents ~/.claude/agents
cp -r .claude/skills ~/.claude/skills
cp -r commands ~/.claude/commands
```

### 사용 예시

```bash
# Go + K8s 프로젝트에 필요한 것만
mkdir -p ~/.claude/skills
cp .claude/skills/go-*.md ~/.claude/skills/
cp .claude/skills/k8s-*.md ~/.claude/skills/
cp -r commands/go commands/k8s ~/.claude/commands/
```

---

## 자동 설치 (install.sh)

스크립트로 설치하려면:

```bash
# 전역 설치 (모든 프로젝트에 적용)
./install.sh --global

# 또는 대화형 설치
./install.sh
```

---

## What & Why

### 이 프로젝트의 목적

Claude Code를 **DevOps 및 백엔드 개발에 최적화**하기 위한 설정, 명령어, 지식 베이스 모음입니다.

### 해결하는 문제들

| 문제 | 해결 방법 |
|------|----------|
| 매번 같은 컨텍스트 설명 반복 | **Project Templates**: 프로젝트별 CLAUDE.md 제공 |
| Claude가 프레임워크 패턴을 모름 | **Skills**: 66개 온디맨드 지식 파일 |
| 반복적인 분석 작업 | **Agents**: 6개 자율 AI 에이전트 (보안, 비용, 장애 등) |
| 반복적인 작업 수동 실행 | **Commands**: 29개 자동화 명령어 |
| 긴 작업 시 컨텍스트 손실 | **Session Context**: 자동 저장/복원 |
| 팀 간 모니터링/로그 가이드 부재 | **Monitoring/Logging Skills**: 역할별 가이드 |

### 주요 기능

```
┌─────────────────────────────────────────────────────────────┐
│                    ress-claude-agents                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🤖 Agents (10 files)        💡 Skills (66 files)          │
│  ├─ security-scanner        ├─ Go/Spring 프레임워크         │
│  ├─ k8s-troubleshooter      ├─ Kubernetes/Terraform/Istio   │
│  ├─ terraform-reviewer      ├─ 모니터링 (Grafana, Prometheus)│
│  ├─ incident-responder      ├─ 로깅 (Loki, ELK, 컴플라이언스)│
│  ├─ code-reviewer           ├─ DevOps (ArgoCD, KEDA, DR)    │
│  ├─ cost-analyzer           └─ API/DB/Docker/Kafka 패턴     │
│  ├─ go/java-expert (대용량)                                 │
│  └─ git-workflow, ci-optimizer                              │
│                                                             │
│  ⚡ Commands (29 files)      📦 Project Templates           │
│  ├─ /go review, lint        ├─ Go Backend                   │
│  ├─ /backend test-gen       ├─ Java/Kotlin Backend          │
│  ├─ /k8s validate, secure   ├─ Kubernetes                   │
│  ├─ /terraform plan-review  └─ Terraform                    │
│  └─ /dx pr-create, release                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 지원 기술 스택

| 분야 | 기술 |
|------|------|
| **Languages** | Go (Gin), Java/Kotlin (Spring Boot) |
| **Infrastructure** | Kubernetes (Helm, Kustomize), Terraform, AWS EKS |
| **GitOps/CD** | ArgoCD, Argo Rollouts, KEDA |
| **Service Mesh** | Istio (Sidecar/Ambient), mTLS, Traffic Management |
| **Containers** | Docker (Multi-stage builds) |
| **Observability** | Prometheus, Grafana, OpenTelemetry, Loki |
| **Messaging** | Apache Kafka (Strimzi Operator) |
| **Database** | JPA, QueryDSL, 마이그레이션 (Flyway, Liquibase) |
| **Security** | Kyverno, Trivy, PCI-DSS, 봇/매크로 탐지 |
| **SRE** | SLI/SLO, Chaos Engineering, DR (Velero) |

---

## Installation

### 설치 옵션

```bash
# 전역 설치 - core만 (세션 관리 + 기본 설정)
./install.sh --global

# 전역 설치 - 전체 모듈
./install.sh --global --all --with-skills

# 로컬 설치 - 현재 프로젝트만
./install.sh --local --modules go,k8s

# 대화형 설치
./install.sh
```

### 옵션 설명

| 옵션 | 설명 |
|------|------|
| `--global` | `~/.claude/`에 설치 (모든 프로젝트) |
| `--local` | `./.claude/`에 설치 (현재 프로젝트만) |
| `--all` | 모든 모듈 설치 |
| `--modules LIST` | 특정 모듈만 설치 (backend,go,k8s,terraform,dx) |
| `--with-skills` | Skills 포함 |
| `--with-mcp` | MCP 설정 포함 (global만) |

### install.sh 특징

- **동적 모듈 탐색**: `commands/` 디렉토리에서 자동으로 모듈 목록 생성
- **입력 검증**: `--modules` 옵션에 잘못된 모듈명 입력 시 에러
- **에러 처리**: `set -euo pipefail`로 안전한 실행, 실패 시 즉시 중단
- **백업 관리**: 기존 파일 자동 백업 및 목록 출력

### 설치 결과

**Global 설치** (symlink):
```
~/.claude/
├── CLAUDE.md      → global/CLAUDE.md
├── commands/      → commands/
└── skills/        → .claude/skills/
```

**Local 설치** (copy):
```
./.claude/
├── CLAUDE.md      (프로젝트용으로 수정 가능)
├── commands/
└── skills/
```

---

## Commands

### Help
```
/help              # 전체 명령어 목록
/help session      # 세션 관리 상세
/help go           # Go 명령어 상세
/help backend      # Backend 명령어 상세
/help k8s          # Kubernetes 상세
/help terraform    # Terraform 상세
/help dx           # DX 상세
```

### Session (세션 컨텍스트 관리)
긴 작업 시 auto compact로 인한 컨텍스트 손실 방지

```
/session save      # 현재 컨텍스트 저장
/session end       # 세션 종료 및 정리
```

**자동 기능**: 복잡한 작업 시 `.claude/session-context.md` 자동 생성/삭제

### 개발 Commands

| Category | Commands |
|----------|----------|
| Go | `/go review`, `/go test-gen`, `/go lint`, `/go refactor` |
| Backend | `/backend review`, `/backend test-gen`, `/backend api-doc`, `/backend refactor` |
| K8s | `/k8s validate`, `/k8s secure`, `/k8s netpol`, `/k8s helm-check` |
| Terraform | `/terraform plan-review`, `/terraform security`, `/terraform module-gen`, `/terraform validate` |
| DX | `/dx pr-create`, `/dx issue-create`, `/dx changelog`, `/dx release` |

---

## Agents (Autonomous AI Assistants)

Claude Code의 Subagent 시스템을 활용한 **자율 실행 AI 에이전트** (10 files, ~3,900줄):

> Skills는 "지식"이고, Agents는 "전문가"입니다. Skills를 참조하며 자율적으로 작업을 수행합니다.

### DevOps Agents
| Agent | 용도 | 자동 실행 |
|-------|------|----------|
| `security-scanner` | 보안 취약점 분석, OWASP Top 10, 시크릿 탐지 | 코드 변경 후 |
| `k8s-troubleshooter` | K8s 문제 진단, 근본 원인 분석, AIOps | 장애 발생 시 |
| `terraform-reviewer` | IaC 보안/비용/신뢰성 11개 도메인 리뷰 | `terraform plan` 전 |
| `incident-responder` | 장애 대응 자동화, MTTR 단축, 런북 실행 | 인시던트 발생 시 |
| `code-reviewer` | 멀티 언어 코드 리뷰, 버그/성능/보안 탐지 | PR 생성 후 |
| `cost-analyzer` | FinOps 분석, 비용 이상 탐지, 최적화 제안 | 비용 리뷰 시 |

### Language Experts (대용량 트래픽 특화)
| Agent | 용도 | 핵심 기능 |
|-------|------|----------|
| `go-expert` | Go 대용량 트래픽 전문가 | Worker Pool, Fan-Out/In, Zero-Alloc, pprof |
| `java-expert` | Java/Spring 대용량 트래픽 전문가 | Virtual Threads, WebFlux, JVM 튜닝, HikariCP |

### Workflow Automation
| Agent | 용도 | 핵심 기능 |
|-------|------|----------|
| `git-workflow` | Git 워크플로우 자동화 | 커밋 메시지 생성, PR 자동화, Changelog |
| `ci-optimizer` | CI/CD 파이프라인 최적화 | 빌드 시간 분석, DORA 메트릭, Flaky 테스트 탐지 |

### 사용 예시

```bash
# Claude Code에서 agents 확인
/agents

# Agent 직접 호출 (Task tool 통해 자동 선택됨)
"보안 취약점 검사해줘"       → security-scanner 자동 실행
"프로덕션 파드가 죽어요"      → k8s-troubleshooter 자동 실행
"terraform plan 결과 리뷰해줘" → terraform-reviewer 자동 실행
```

### 2026 AI Agents 트렌드 반영

- **Multi-Agent Architecture**: 전문화된 에이전트가 협력
- **Human-on-the-Loop**: 파괴적 작업은 항상 승인 필요
- **AIOps Integration**: 관측 데이터 기반 자동 진단
- **Autonomous Remediation**: 승인된 런북 자동 실행

---

## Skills (On-demand Knowledge)

필요할 때만 로드되는 도메인 지식 (66 files, ~18,000줄):

### Go
```
/go-errors          # Error handling patterns
/go-gin             # Gin framework patterns
/go-testing         # Table-driven testing patterns
/concurrency-go     # 동시성 패턴 (Mutex, Channel, Worker Pool)
```

### Spring (Java/Kotlin)
```
/spring-data        # JPA, QueryDSL 패턴 및 조합
/spring-cache       # Redis 캐싱 전략
/spring-security    # Security 기본 설정, Method Security
/spring-oauth2      # OAuth2, JWT 토큰 발급/검증
/spring-testing     # JUnit, Mockito 단위 테스트
/spring-testcontainers  # Testcontainers, REST Assured 통합 테스트
/concurrency-spring # 동시성 문제 해결 (락킹, 데드락 방지)
```

### Kubernetes & Terraform
```
/k8s-security       # Pod Security Standards, RBAC, Kyverno, Trivy
/k8s-helm           # Helm chart best practices
/k8s-autoscaling    # HPA, VPA, KEDA, Karpenter
/k8s-scheduling     # Node Affinity, Taint, TopologySpreadConstraints
/k8s-traffic        # 트래픽 제어 허브 (Rate Limiting, 대기열)
  └─ /k8s-traffic-istio    # Istio Rate Limiting, Circuit Breaker
  └─ /k8s-traffic-ingress  # NGINX/Kong Rate Limiting
/terraform-modules  # Terraform module patterns
/terraform-security # Terraform security
```

### Istio Service Mesh
```
/istio-core         # Sidecar vs Ambient 모드 비교, mTLS 강제
/istio-security     # PeerAuthentication, AuthorizationPolicy, JWT
/istio-gateway      # Gateway 허브 (Classic vs API 비교)
  └─ /istio-gateway-classic # Gateway + VirtualService + TLS
  └─ /istio-gateway-api     # Gateway API + HTTPRoute
/istio-observability # 모니터링 허브 (모드별 메트릭 차이)
  └─ /istio-metrics  # Prometheus 연동, RED 메트릭
  └─ /istio-tracing  # Jaeger/Tempo, Access Logging
  └─ /istio-kiali    # Kiali 설치/설정, 토폴로지
```

### Monitoring & Observability
```
/observability         # 로깅 기본, 메트릭 (RED Method)
/observability-otel    # OpenTelemetry SDK 및 Collector 설정
/monitoring-grafana    # Grafana 대시보드, 알림, RBAC
/monitoring-metrics    # Prometheus 스케일링, Thanos/VictoriaMetrics
/monitoring-logs       # Fluent Bit, Loki, 로그 필터링
/monitoring-troubleshoot # 알림 대응, 트러블슈팅
```

### SRE & DevOps
```
/sre-sli-slo           # SLI/SLO/SLA 정의, 에러 버짓, 다중 윈도우 알림
/supply-chain-security # SBOM, Cosign, SLSA, Kyverno verifyImages
/cicd-devsecops        # GitHub Actions, Trivy, SonarQube, Kyverno
/gitops-argocd         # ArgoCD, App of Apps, ApplicationSet
/deployment-strategies # Canary, Blue-Green, Argo Rollouts
/chaos-engineering     # LitmusChaos, GameDay 절차
/disaster-recovery     # Velero, RTO/RPO, Multi-cluster DR
/alerting-discord      # AlertManager, Discord 웹훅
/platform-backstage    # IDP, Software Catalog, Golden Paths
/finops                # Kubecost, Right-sizing, Spot Instance
/finops-advanced       # Showback/Chargeback, 비용 이상 탐지, Infracost
```

### Developer Experience
```
/dx-metrics            # DORA, SPACE, DevEx, DX Core 4 프레임워크
/dx-ai-agents          # AI 에이전트 거버넌스, Copilot/Claude 통합
/dx-onboarding         # 개발자 온보딩 자동화, Time-to-First-Deploy
```

### Infrastructure
```
/aws-eks               # EKS Terraform, IRSA, Karpenter, Add-ons
/load-testing          # K6, K6 Operator, nGrinder
```

### Messaging
```
/kafka                 # Strimzi Operator, Producer/Consumer, KEDA
```

### Logging & Compliance
```
/logging-compliance    # 결제/개인정보 법적 로그 (PCI-DSS, 전자금융거래법)
/logging-security      # 봇/매크로 탐지, 보안 감사 로그
/logging-loki          # Loki + LogQL 검색/분석 (개발팀/보안팀용)
/logging-elk           # ELK Stack 검색/분석 (Elasticsearch, Kibana)
```

### API & Database
```
/api-design            # REST API 설계, 에러 처리 (RFC 9457)
/docker                # Dockerfile 최적화, 멀티스테이지 빌드
/database              # 인덱스, N+1 해결, 쿼리 최적화
/database-migration    # Flyway, Liquibase, 스키마 변경 패턴
/distributed-lock      # MSA 분산 락 (Redis, Redisson)
```

### Refactoring
```
/refactoring-principles  # 코드 스멜 카탈로그, SOLID, 점진적 전략
/refactoring-go          # Go Early Return, 인터페이스 추출, 성능 최적화
/refactoring-spring      # God Class 분해, N+1 해결, 계층 분리
```

### Git & Workflow
```
/git-workflow          # Git conventions
/conventional-commits  # 커밋 규칙 + 자동 버전/CHANGELOG
```

---

## Project Templates

프로젝트별 CLAUDE.md 템플릿:

```bash
# Go backend
cp project-templates/backend-go/CLAUDE.md /your/project/

# Java/Kotlin backend
cp project-templates/backend-java/CLAUDE.md /your/project/

# Kubernetes
cp project-templates/k8s/CLAUDE.md /your/project/

# Terraform
cp project-templates/terraform/CLAUDE.md /your/project/
```

---

## Structure

```
ress-claude-agents/
├── .claude/
│   ├── agents/               # Autonomous AI agents (10 files)
│   │   ├── security-scanner.md
│   │   ├── k8s-troubleshooter.md
│   │   ├── terraform-reviewer.md
│   │   ├── incident-responder.md
│   │   ├── code-reviewer.md
│   │   ├── cost-analyzer.md
│   │   ├── go-expert.md        # Go 대용량 트래픽 전문가
│   │   ├── java-expert.md      # Java/Spring 대용량 트래픽 전문가
│   │   ├── git-workflow.md     # Git 워크플로우 자동화
│   │   └── ci-optimizer.md     # CI/CD 파이프라인 최적화
│   ├── skills/               # On-demand domain knowledge (66 files)
│   │   ├── go-*.md          # Go 패턴 (4 files)
│   │   ├── spring-*.md      # Spring 패턴 (6 files)
│   │   ├── k8s-*.md         # Kubernetes (8 files)
│   │   ├── istio-*.md       # Istio Service Mesh (9 files)
│   │   ├── terraform-*.md   # Terraform (2 files)
│   │   ├── monitoring-*.md  # 모니터링 (4 files)
│   │   ├── logging-*.md     # 로깅/컴플라이언스 (4 files)
│   │   ├── observability*.md # Observability (2 files)
│   │   ├── database*.md     # 데이터베이스 (2 files)
│   │   ├── refactoring-*.md # 리팩토링 (3 files)
│   │   └── ...              # SRE/DevOps, Infrastructure, Messaging 등
│   └── standards.yml         # 코드 품질 기준 (함수 길이, 커버리지 등)
├── global/CLAUDE.md          # Global settings
├── commands/
│   ├── manifest.yml          # 명령어 메타데이터 중앙 관리
│   ├── help/                 # Help commands (7 files)
│   ├── session/              # Session context commands (2 files)
│   ├── go/                   # Go commands (4 files)
│   ├── backend/              # Java/Kotlin commands (4 files)
│   ├── k8s/                  # Kubernetes commands (4 files)
│   ├── terraform/            # Terraform commands (4 files)
│   └── dx/                   # DX commands (4 files)
├── project-templates/        # Project-specific CLAUDE.md templates
│   ├── backend-go/
│   ├── backend-java/
│   ├── k8s/
│   └── terraform/
├── mcp-configs/              # MCP server settings
├── .github/workflows/
│   └── ci.yml                # GitHub Actions CI (test, lint, validate)
├── .githooks/
│   └── pre-commit            # 커밋 전 검증 (문서, shellcheck)
├── scripts/
│   ├── generate-docs.sh      # 문서 생성/검증 스크립트
│   └── setup-hooks.sh        # Git hooks 설정
├── tests/
│   ├── install.bats          # BATS 테스트 (36 cases)
│   └── README.md             # 테스트 실행 가이드
├── modules.txt               # 설치 가능 모듈 목록
├── Makefile                  # 공통 명령어 (make help)
└── install.sh                # Installer script (동적 모듈 탐색, 에러 처리)
```

---

## Design Principles

1. **Compact CLAUDE.md**: 50-80줄, 필수 규칙만
2. **On-demand Skills**: 필요할 때만 상세 패턴 로드
3. **Command Contracts**: 명확한 Input/Output/Verification
4. **Session Context**: auto compact 시에도 컨텍스트 유지
5. **Selective Install**: 필요한 모듈만 선택 설치
6. **Centralized Config**: 설정값 중앙화 (`standards.yml`, `manifest.yml`)

---

## Development

### 테스트 실행

```bash
# BATS 설치 (macOS)
brew install bats-core

# 테스트 실행
bats tests/install.bats

# 상세 출력
bats --verbose-run tests/install.bats
```

### 문서 생성/검증

```bash
# yq 설치 (YAML 파서)
brew install yq

# 모든 작업 실행
./scripts/generate-docs.sh

# 일관성 검증만
./scripts/generate-docs.sh validate

# 요약 통계
./scripts/generate-docs.sh summary
```

### Git Hooks 설정

```bash
# Git hooks 설정 (최초 1회)
./scripts/setup-hooks.sh

# 이후 커밋 시 자동 검증 (문서 일관성, shellcheck)
# 검증 우회 (권장하지 않음)
git commit --no-verify
```

### Makefile

```bash
make help      # 사용 가능한 명령어 목록
make test      # BATS 테스트 실행
make validate  # 문서 일관성 검증
make lint      # shellcheck 실행
make all       # validate + test
```

---

## Statistics

| 항목 | 수량 |
|------|------|
| **Agents** | 10 files (~3,900줄) |
| Skills | 66 files (~18,000줄) |
| Commands | 29 files |
| Templates | 4 projects |
| Tests | 36 cases |
| **Total** | ~24,400줄 |

---

## Reference

### Claude Code & AI Development
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices) - Anthropic 공식 가이드
- [Claude Code Documentation](https://docs.anthropic.com/claude-code) - Skills, Commands, MCP 레퍼런스
- [Model Context Protocol](https://modelcontextprotocol.io/) - MCP 공식 문서

### Design Philosophy
> "For each line, ask: 'Would removing this cause Claude to make mistakes?'"

이 원칙에 따라 Skills 파일은 **최소한의 컨텍스트로 최대한의 정확도**를 목표로 설계되었습니다.

---

## About

AI-augmented development에 관심이 있다면 이슈나 PR 환영합니다.

**Built with Claude Code** - 이 저장소의 대부분의 코드와 문서는 Claude와 함께 작성되었습니다.
