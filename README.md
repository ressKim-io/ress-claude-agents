# ress-claude-agents

Personal Claude Code agents and configs for DevOps & backend development.

## Quick Start (수동 복사)

원하는 영역만 선택해서 복사하면 바로 사용 가능합니다.

### 복사 위치

| 범위 | 복사할 위치 | 효과 |
|------|------------|------|
| **전역 (모든 프로젝트)** | `~/.claude/` | 어디서든 사용 가능 |
| **프로젝트 전용** | `<프로젝트>/.claude/` | 해당 프로젝트만 적용 |

### 원하는 영역만 복사

```bash
# 1. Skills만 (도메인 지식) - 가장 많이 사용
cp -r .claude/skills ~/.claude/skills

# 2. Commands만 (자동화 명령어)
cp -r commands ~/.claude/commands

# 3. 특정 skill만
cp .claude/skills/spring-*.md ~/.claude/skills/

# 4. 특정 command 카테고리만
cp -r commands/k8s ~/.claude/commands/

# 5. 전체 설정 (global CLAUDE.md 포함)
cp global/CLAUDE.md ~/.claude/CLAUDE.md
cp -r commands ~/.claude/commands
cp -r .claude/skills ~/.claude/skills
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
| Claude가 프레임워크 패턴을 모름 | **Skills**: 47개 온디맨드 지식 파일 |
| 반복적인 작업 수동 실행 | **Commands**: 29개 자동화 명령어 |
| 긴 작업 시 컨텍스트 손실 | **Session Context**: 자동 저장/복원 |
| 팀 간 모니터링/로그 가이드 부재 | **Monitoring/Logging Skills**: 역할별 가이드 |

### 주요 기능

```
┌─────────────────────────────────────────────────────────────┐
│                    ress-claude-agents                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📦 Project Templates        💡 Skills (47 files)          │
│  ├─ Go Backend              ├─ Go/Spring 프레임워크         │
│  ├─ Java/Kotlin Backend     ├─ Kubernetes/Terraform/Istio   │
│  ├─ Kubernetes              ├─ 모니터링 (Grafana, Prometheus)│
│  └─ Terraform               ├─ 로깅 (Loki, ELK, 컴플라이언스)│
│                             └─ API/DB/Docker 패턴           │
│                                                             │
│  ⚡ Commands (29 files)      🔄 Session Management          │
│  ├─ /go review, lint        ├─ 자동 컨텍스트 저장           │
│  ├─ /backend test-gen       ├─ auto compact 대응            │
│  ├─ /k8s validate, secure   └─ /session save, end           │
│  ├─ /terraform plan-review                                  │
│  └─ /dx pr-create, release                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 지원 기술 스택

| 분야 | 기술 |
|------|------|
| **Languages** | Go (Gin), Java/Kotlin (Spring Boot) |
| **Infrastructure** | Kubernetes (Helm, Kustomize), Terraform |
| **Containers** | Docker (Multi-stage builds) |
| **Observability** | Prometheus, Grafana, OpenTelemetry |
| **Logging** | Loki (LogQL), ELK Stack (Elasticsearch) |
| **Database** | JPA, QueryDSL, 마이그레이션 (Flyway, Liquibase) |
| **Security** | PCI-DSS, 개인정보보호, 봇/매크로 탐지 |

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

## Skills (On-demand Knowledge)

필요할 때만 로드되는 도메인 지식 (47 files, ~11,000줄):

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
/k8s-security       # Pod Security Standards, RBAC
/k8s-helm           # Helm chart best practices
/k8s-traffic        # 트래픽 제어 허브 (Rate Limiting, 대기열)
  └─ /k8s-traffic-istio    # Istio Rate Limiting, Circuit Breaker
  └─ /k8s-traffic-ingress  # NGINX/Kong Rate Limiting
/terraform-modules  # Terraform module patterns
/terraform-security # Terraform security
```

### Istio Service Mesh
```
/istio-core         # Sidecar vs Ambient 모드 비교, 마이그레이션
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

### SRE
```
/sre-sli-slo           # SLI/SLO/SLA 정의, 에러 버짓, 다중 윈도우 알림
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
├── .claude/skills/           # On-demand domain knowledge (47 files)
│   ├── go-*.md              # Go 패턴 (4 files)
│   ├── spring-*.md          # Spring 패턴 (6 files)
│   ├── k8s-*.md             # Kubernetes (5 files, 허브-스포크)
│   ├── istio-*.md           # Istio Service Mesh (8 files, 허브-스포크)
│   ├── terraform-*.md       # Terraform (2 files)
│   ├── monitoring-*.md      # 모니터링 (4 files)
│   ├── logging-*.md         # 로깅/컴플라이언스 (4 files)
│   ├── observability*.md    # Observability (2 files)
│   ├── database*.md         # 데이터베이스 (2 files)
│   ├── refactoring-*.md     # 리팩토링 (3 files)
│   └── *.md                 # 기타 (API, Docker, Git 등)
├── global/CLAUDE.md          # Global settings
├── commands/
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
└── install.sh                # Installer script
```

---

## Design Principles

1. **Compact CLAUDE.md**: 50-80줄, 필수 규칙만
2. **On-demand Skills**: 필요할 때만 상세 패턴 로드
3. **Command Contracts**: 명확한 Input/Output/Verification
4. **Session Context**: auto compact 시에도 컨텍스트 유지
5. **Selective Install**: 필요한 모듈만 선택 설치

---

## Statistics

| 항목 | 수량 |
|------|------|
| Skills | 47 files (~11,000줄) |
| Commands | 29 files |
| Templates | 4 projects |
| **Total** | ~12,700줄 |

---

## Reference

- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- Key principle: "For each line, ask: 'Would removing this cause Claude to make mistakes?'"
