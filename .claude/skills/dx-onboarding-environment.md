# Developer Onboarding: 개발 환경 자동화

Dev Container, Gitpod, 셋업 스크립트를 활용한 개발 환경 자동화

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

echo "🚀 개발 환경 설정 시작..."

# 1. 의존성 설치
echo "📦 의존성 설치 중..."
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
echo "🔧 개발 도구 설치 중..."
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/air-verse/air@latest

# 3. Pre-commit hooks 설정
echo "🪝 Git hooks 설정 중..."
if [[ -f ".pre-commit-config.yaml" ]]; then
    pre-commit install
fi

# 4. 환경 설정 파일 생성
echo "⚙️ 환경 설정 중..."
if [[ ! -f ".env" ]]; then
    cp .env.example .env
    echo "✅ .env 파일 생성됨 (필요시 수정)"
fi

# 5. 데이터베이스 마이그레이션
echo "🗄️ 데이터베이스 설정 중..."
until pg_isready -h localhost -p 5432 -q; do
    echo "PostgreSQL 대기 중..."
    sleep 1
done
make db-migrate || true

# 6. 테스트 실행으로 환경 검증
echo "✅ 환경 검증 중..."
make test-unit || {
    echo "⚠️ 일부 테스트 실패. 환경 설정을 확인하세요."
}

echo ""
echo "🎉 개발 환경 설정 완료!"
echo ""
echo "시작하기:"
echo "  make run          # 앱 실행"
echo "  make test         # 테스트 실행"
echo "  make help         # 모든 명령어 보기"
echo ""
echo "문제가 있으면: #dev-help 채널에 문의하세요"
```

### start.sh (매 시작 시)

```bash
#!/bin/bash
# .devcontainer/start.sh
set -euo pipefail

echo "🔄 서비스 확인 중..."

# 데이터베이스 연결 확인
until pg_isready -h localhost -p 5432 -q; do
    echo "PostgreSQL 대기 중..."
    sleep 1
done
echo "✅ PostgreSQL 연결됨"

# Redis 연결 확인
until redis-cli ping > /dev/null 2>&1; do
    echo "Redis 대기 중..."
    sleep 1
done
echo "✅ Redis 연결됨"

echo "🚀 개발 환경 준비 완료!"
```

---

## Gitpod 설정

### .gitpod.yml

```yaml
# .gitpod.yml
image:
  file: .gitpod/Dockerfile

tasks:
  - name: Setup
    init: |
      # 의존성 설치
      go mod download
      npm ci

      # 데이터베이스 마이그레이션
      gp await-port 5432
      make db-migrate

      # 초기 빌드
      make build
    command: |
      echo "🎉 환경 준비 완료!"
      make run

  - name: Database
    command: |
      docker-compose up postgres redis

ports:
  - port: 8080
    onOpen: open-preview
    visibility: public
  - port: 5432
    onOpen: ignore
  - port: 6379
    onOpen: ignore

vscode:
  extensions:
    - golang.go
    - ms-azuretools.vscode-docker
    - github.copilot

gitConfig:
  core.autocrlf: "false"
```

### Gitpod Dockerfile

```dockerfile
# .gitpod/Dockerfile
FROM gitpod/workspace-full

# Go 버전 설정
RUN bash -c ". /home/gitpod/.sdkman/bin/sdkman-init.sh && sdk install java 21.0.1-tem"

# Go 도구
RUN go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
RUN go install github.com/air-verse/air@latest

# kubectl & helm
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && sudo mv kubectl /usr/local/bin/

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## 셀프서비스 온보딩 포털

### Backstage 온보딩 템플릿

```yaml
# backstage-onboarding-template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: developer-onboarding
  title: 신규 개발자 온보딩
  description: 신규 개발자를 위한 자동 온보딩 프로세스
spec:
  owner: platform-team
  type: onboarding

  parameters:
    - title: 개발자 정보
      required:
        - name
        - email
        - team
        - role
      properties:
        name:
          title: 이름
          type: string
        email:
          title: 이메일
          type: string
          format: email
        team:
          title: 소속 팀
          type: string
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: Group
        role:
          title: 역할
          type: string
          enum:
            - backend
            - frontend
            - fullstack
            - devops
            - data

    - title: 개발 환경
      properties:
        preferredIDE:
          title: 선호 IDE
          type: string
          enum:
            - vscode
            - intellij
            - cursor
          default: vscode
        useDevContainer:
          title: Dev Container 사용
          type: boolean
          default: true

  steps:
    # 1. GitHub 조직 초대
    - id: github-invite
      name: GitHub 조직 초대
      action: github:invite-member
      input:
        org: mycompany
        email: ${{ parameters.email }}
        teams:
          - ${{ parameters.team }}
          - developers

    # 2. 클라우드 IAM 설정
    - id: aws-iam
      name: AWS IAM 설정
      action: aws:create-iam-user
      input:
        username: ${{ parameters.email | replace('@.*', '') }}
        groups:
          - developers
          - ${{ parameters.team }}

    # 3. Kubernetes 접근 권한
    - id: k8s-rbac
      name: K8s RBAC 설정
      action: kubernetes:apply
      input:
        manifest: |
          apiVersion: rbac.authorization.k8s.io/v1
          kind: RoleBinding
          metadata:
            name: dev-${{ parameters.email | replace('@.*', '') }}
            namespace: ${{ parameters.team }}-dev
          subjects:
            - kind: User
              name: ${{ parameters.email }}
          roleRef:
            kind: ClusterRole
            name: developer
            apiGroup: rbac.authorization.k8s.io

    # 4. 온보딩 저장소 생성
    - id: create-sandbox
      name: 개인 샌드박스 저장소 생성
      action: publish:github
      input:
        repoUrl: github.com?owner=mycompany&repo=sandbox-${{ parameters.email | replace('@.*', '') }}
        description: "${{ parameters.name }}의 학습/실험 저장소"
        template: mycompany/sandbox-template

    # 5. 슬랙 채널 초대
    - id: slack-invite
      name: Slack 채널 초대
      action: slack:invite
      input:
        email: ${{ parameters.email }}
        channels:
          - general
          - ${{ parameters.team }}
          - dev-help
          - announcements

    # 6. 온보딩 가이드 이메일
    - id: send-welcome
      name: 웰컴 이메일 발송
      action: email:send
      input:
        to: ${{ parameters.email }}
        template: onboarding-welcome
        variables:
          name: ${{ parameters.name }}
          team: ${{ parameters.team }}
          sandboxRepo: ${{ steps['create-sandbox'].output.remoteUrl }}

  output:
    links:
      - title: 온보딩 체크리스트
        url: https://wiki.company.com/onboarding
      - title: 개인 샌드박스
        url: ${{ steps['create-sandbox'].output.remoteUrl }}
      - title: 팀 대시보드
        url: https://backstage.company.com/catalog/${{ parameters.team }}
```

---

## 온보딩 문서 자동화

### TechDocs 온보딩 사이트

```yaml
# docs/mkdocs.yml
site_name: 개발자 온보딩 가이드
site_description: 신규 개발자를 위한 종합 가이드

nav:
  - 홈: index.md
  - Day 0 - 시작하기:
      - 계정 설정: day0/accounts.md
      - 접근 권한: day0/access.md
      - 필수 도구: day0/tools.md
  - Day 1 - 개발 환경:
      - 로컬 환경 설정: day1/local-setup.md
      - Dev Container: day1/devcontainer.md
      - 첫 빌드: day1/first-build.md
  - Day 2-3 - 첫 기여:
      - Git 워크플로우: contribution/git-workflow.md
      - PR 가이드: contribution/pr-guide.md
      - 코드 리뷰: contribution/code-review.md
  - 아키텍처:
      - 시스템 개요: architecture/overview.md
      - 서비스 맵: architecture/services.md
      - 데이터 흐름: architecture/data-flow.md
  - 운영:
      - 배포 프로세스: operations/deployment.md
      - 모니터링: operations/monitoring.md
      - 온콜: operations/oncall.md
  - FAQ: faq.md

plugins:
  - techdocs-core
  - search
  - mermaid2

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
```

### 인터랙티브 온보딩 체크리스트

```markdown
<!-- docs/index.md -->
# 개발자 온보딩 가이드

환영합니다! 이 가이드를 따라 빠르게 팀에 합류하세요.

## 온보딩 진행 상황

!!! tip "목표: Day 1 Deploy"
    첫날 프로덕션에 코드를 배포하는 것이 목표입니다!

### Day 0: 시작하기 (2-4시간)

- [ ] GitHub 조직 초대 수락
- [ ] Slack 채널 참여
- [ ] AWS SSO 설정
- [ ] VPN 설정 (필요시)
- [ ] 1Password/Vault 접근

### Day 0.5: 개발 환경 (1-2시간)

- [ ] 저장소 클론
- [ ] Dev Container 실행 또는 로컬 설정
- [ ] 앱 로컬 실행 확인
- [ ] 테스트 실행 확인

### Day 1: 첫 기여 (4-8시간)

- [ ] 첫 과제 이슈 확인
- [ ] 브랜치 생성
- [ ] 변경사항 구현
- [ ] PR 생성
- [ ] 코드 리뷰 요청

### Day 2-3: 첫 배포

- [ ] 리뷰 피드백 반영
- [ ] CI 통과
- [ ] 스테이징 배포 확인
- [ ] 프로덕션 배포 🎉
- [ ] 배포 확인

## 도움이 필요하면

| 채널 | 용도 |
|------|------|
| #dev-help | 기술 질문 |
| #onboarding | 온보딩 관련 |
| @your-mentor | 1:1 질문 |
```

---

## 체크리스트

### Dev Container
- [ ] devcontainer.json 설정
- [ ] docker-compose.yml 작성
- [ ] setup.sh 스크립트
- [ ] 필수 extension 목록

### Gitpod
- [ ] .gitpod.yml 설정
- [ ] Dockerfile 작성
- [ ] 포트 설정
- [ ] 프리빌드 설정

### 문서화
- [ ] 온보딩 가이드 작성
- [ ] 트러블슈팅 문서
- [ ] FAQ 정리

**관련 skill**: `/dx-onboarding` (허브), `/dx-onboarding-deploy` (첫 배포)
