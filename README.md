# ress-claude-agents

Personal Claude Code agents and configs for DevOps & backend development

## Structure

```
ress-claude-agents/
├── README.md
├── install.sh                    # symlink 자동 설정
├── global/
│   └── CLAUDE.md                 # 공통 기본 설정
├── commands/
│   ├── backend/                  # 백엔드 개발 명령어 (Java/Kotlin)
│   ├── go/                       # Go 백엔드 명령어
│   ├── k8s/                      # Kubernetes 명령어
│   ├── terraform/                # Terraform 명령어
│   └── dx/                       # DX 명령어
├── project-templates/
│   ├── backend-go/CLAUDE.md      # Go 백엔드 프로젝트용
│   ├── backend-java/CLAUDE.md    # Java 백엔드 프로젝트용
│   ├── k8s/CLAUDE.md             # Kubernetes 프로젝트용
│   └── terraform/CLAUDE.md       # Terraform 프로젝트용
└── mcp-configs/
    └── settings.json             # MCP 서버 설정
```

## Agents

### 1. Backend Development Agent
- 커밋/PR 단위 규칙
- 언어별 테스트 코드 규칙, 리팩토링 주기
- 단위별 README 및 문서 자동 업데이트

### 2. K8s Expert Agent
- manifest 검토, 보안, best practice

### 3. Terraform Agent
- plan 분석, security check

### 4. DX (Developer Experience) Agent
- GitHub/Jira 연동, 워크플로우 개선

## Installation

```bash
./install.sh
```

## Usage

### Global Settings
`~/.claude/CLAUDE.md`에 symlink로 연결되어 모든 프로젝트에 적용됩니다.

### Project Templates
새 프로젝트에 해당 타입의 `CLAUDE.md`를 복사해서 사용합니다.

```bash
# Go 백엔드 프로젝트
cp project-templates/backend-go/CLAUDE.md /path/to/your-project/

# Kubernetes 프로젝트
cp project-templates/k8s/CLAUDE.md /path/to/your-project/
```

### Commands
`~/.claude/commands/`에 symlink로 연결되어 `/명령어`로 실행 가능합니다.

## File Types

| 파일 | 용도 |
|------|------|
| `CLAUDE.md` | 정적 규칙/가이드라인 |
| `commands/` | `/명령어`로 트리거되는 작업 |
| `mcp-configs/` | 외부 시스템 연동 설정 |
