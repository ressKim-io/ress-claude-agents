# Developer Onboarding: 개발 환경 자동화

Dev Container를 활용한 개발 환경 자동화

## Quick Reference

```
개발 환경 자동화 방식?
    │
    ├─ Dev Container ─────> VS Code + Docker, 로컬 개발
    │       │
    │       └─ 팀 표준화 + 오프라인 가능
    │
    ├─ Gitpod ───────────> 클라우드 IDE, 브라우저 개발
    │       │
    │       └─ 즉시 시작 + 리소스 무제한
    │
    └─ 셋업 스크립트 ────> 기존 환경에 설치
            │
            └─ 유연함 + 기존 워크플로우 유지
```

---

## Dev Container 설정

### devcontainer.json

```json
// .devcontainer/devcontainer.json
{
  "name": "Development Environment",
  "build": {
    "dockerfile": "Dockerfile",
    "args": {
      "VARIANT": "1.22",
      "NODE_VERSION": "20"
    }
  },

  // VS Code 설정
  "customizations": {
    "vscode": {
      "settings": {
        "go.useLanguageServer": true,
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "[go]": {
          "editor.defaultFormatter": "golang.go"
        }
      },
      "extensions": [
        "golang.go",
        "ms-azuretools.vscode-docker",
        "ms-kubernetes-tools.vscode-kubernetes-tools",
        "github.copilot",
        "eamodio.gitlens",
        "esbenp.prettier-vscode"
      ]
    }
  },

  // 포트 포워딩
  "forwardPorts": [8080, 5432, 6379],

  // 환경 변수
  "containerEnv": {
    "DATABASE_URL": "postgres://dev:dev@localhost:5432/dev",
    "REDIS_URL": "redis://localhost:6379",
    "ENV": "development"
  },

  // 추가 서비스 (docker-compose)
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",

  // 초기화 스크립트
  "postCreateCommand": "bash .devcontainer/setup.sh",
  "postStartCommand": "bash .devcontainer/start.sh",

  // 기능 추가
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {},
    "ghcr.io/devcontainers/features/aws-cli:1": {}
  }
}
```

### Dev Container Dockerfile

```dockerfile
# .devcontainer/Dockerfile
FROM mcr.microsoft.com/devcontainers/go:1.22

ARG NODE_VERSION="20"

# Node.js 설치
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION}"

# 추가 도구 설치
RUN apt-get update && apt-get install -y \
    postgresql-client \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# Go 도구 설치
RUN go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
    && go install github.com/air-verse/air@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest
```

### docker-compose.yml

```yaml
# .devcontainer/docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ..:/workspace:cached
    command: sleep infinity
    network_mode: service:db

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: dev
    volumes:
      - postgres-data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    network_mode: service:db

volumes:
  postgres-data:
```

---

## 셋업 스크립트

### setup.sh (초기 설정)

```bash
#!/bin/bash
# .devcontainer/setup.sh
set -euo pipefail

echo "개발 환경 설정 시작..."

# 1. 의존성 설치
echo "의존성 설치 중..."
if [[ -f "go.mod" ]]; then
    go mod download
fi
if [[ -f "package.json" ]]; then
    npm ci
fi
if [[ -f "requirements.txt" ]]; then
    pip install -r requirements.txt
fi

# 2. 로컬 도구 설치
echo "개발 도구 설치 중..."
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/air-verse/air@latest

# 3. Pre-commit hooks 설정
echo "Git hooks 설정 중..."
if [[ -f ".pre-commit-config.yaml" ]]; then
    pre-commit install
fi

# 4. 환경 설정 파일 생성
echo "환경 설정 중..."
if [[ ! -f ".env" ]]; then
    cp .env.example .env
    echo ".env 파일 생성됨 (필요시 수정)"
fi

# 5. 데이터베이스 마이그레이션
echo "데이터베이스 설정 중..."
until pg_isready -h localhost -p 5432 -q; do
    echo "PostgreSQL 대기 중..."
    sleep 1
done
make db-migrate || true

# 6. 테스트 실행으로 환경 검증
echo "환경 검증 중..."
make test-unit || {
    echo "일부 테스트 실패. 환경 설정을 확인하세요."
}

echo ""
echo "개발 환경 설정 완료!"
echo ""
echo "시작하기:"
echo "  make run          # 앱 실행"
echo "  make test         # 테스트 실행"
echo "  make help         # 모든 명령어 보기"
```

### start.sh (매 시작 시)

```bash
#!/bin/bash
# .devcontainer/start.sh
set -euo pipefail

echo "서비스 확인 중..."

# 데이터베이스 연결 확인
until pg_isready -h localhost -p 5432 -q; do
    echo "PostgreSQL 대기 중..."
    sleep 1
done
echo "PostgreSQL 연결됨"

# Redis 연결 확인
until redis-cli ping > /dev/null 2>&1; do
    echo "Redis 대기 중..."
    sleep 1
done
echo "Redis 연결됨"

echo "개발 환경 준비 완료!"
```

---

## 체크리스트

### Dev Container
- [ ] devcontainer.json 설정
- [ ] docker-compose.yml 작성
- [ ] setup.sh 스크립트
- [ ] 필수 extension 목록
- [ ] 포트 포워딩 설정

### 셋업 스크립트
- [ ] 의존성 자동 설치
- [ ] 환경 변수 템플릿
- [ ] DB 마이그레이션
- [ ] 환경 검증 테스트

**관련 skill**: `/dx-onboarding` (허브), `/dx-onboarding-gitpod` (Gitpod, 포털)
