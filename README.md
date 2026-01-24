# ress-claude-agents

Personal Claude Code agents and configs for DevOps & backend development.

## Quick Start

```bash
# 전역 설치 (모든 프로젝트에 적용)
./install.sh --global

# 또는 대화형 설치
./install.sh
```

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

## Skills (On-demand Knowledge)

필요할 때만 로드되는 도메인 지식:

### Go
```
/go-errors          # Go error handling patterns
/go-gin             # Gin framework patterns
/go-testing         # Go testing patterns
/concurrency-go     # 동시성 패턴 (Mutex, Channel, Worker Pool)
```

### Spring (Java/Kotlin)
```
/spring-data        # JPA, QueryDSL 패턴 및 조합
/spring-cache       # Redis 캐싱 전략
/spring-security    # Security, OAuth2, JWT 인증
/spring-testing     # JUnit, Mockito, Testcontainers
/concurrency-spring # 동시성 문제 해결 (락킹, 데드락 방지)
```

### Infrastructure & DevOps
```
/k8s-security       # Kubernetes security
/k8s-helm           # Helm best practices
/terraform-modules  # Terraform module patterns
/terraform-security # Terraform security
/git-workflow       # Git conventions
/distributed-lock   # MSA 분산 락 (Redis, Redisson)
/conventional-commits # 커밋 규칙 + 자동 버전/CHANGELOG
/observability      # 로깅 + OpenTelemetry + 메트릭
/docker             # Dockerfile 최적화, 멀티스테이지 빌드
/api-design         # REST API 설계, 에러 처리 (RFC 9457)
/database           # 인덱스, N+1 해결, 쿼리 최적화
/database-migration # Flyway, Liquibase, 스키마 변경 패턴
```

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

## Structure

```
ress-claude-agents/
├── .claude/skills/           # On-demand domain knowledge (21 files)
├── global/CLAUDE.md          # Global settings
├── commands/
│   ├── help/                 # Help commands
│   ├── session/              # Session context commands
│   ├── go/                   # Go commands
│   ├── backend/              # Java/Kotlin commands
│   ├── k8s/                  # Kubernetes commands
│   ├── terraform/            # Terraform commands
│   └── dx/                   # DX commands
├── project-templates/        # Project-specific CLAUDE.md templates
├── mcp-configs/              # MCP server settings
└── install.sh                # Installer script
```

## Design Principles

1. **Compact CLAUDE.md**: 50-80줄, 필수 규칙만
2. **On-demand Skills**: 필요할 때만 상세 패턴 로드
3. **Command Contracts**: 명확한 Input/Output/Verification
4. **Session Context**: auto compact 시에도 컨텍스트 유지
5. **Selective Install**: 필요한 모듈만 선택 설치

## Reference

- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- Key principle: "For each line, ask: 'Would removing this cause Claude to make mistakes?'"
