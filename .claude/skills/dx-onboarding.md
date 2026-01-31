# Developer Onboarding 자동화 가이드

개발자 온보딩 자동화, Time-to-First-Deploy 최적화, 셀프서비스 환경 구축

## Quick Reference (결정 트리)

```
온보딩 자동화 수준?
    │
    ├─ Level 1: 문서화 ─────> README, Wiki 정리
    │       │
    │       └─ 수동 설정, 1-2주 소요
    │
    ├─ Level 2: 스크립트 ───> 셋업 스크립트, dotfiles
    │       │
    │       └─ 반자동, 2-3일 소요
    │
    ├─ Level 3: 플랫폼 ────> IDP, Dev Container, Gitpod
    │       │
    │       └─ 완전 자동화, 수 시간 내
    │
    └─ Level 4: AI 어시스트 ─> AI 가이드, 컨텍스트 자동 주입
            │
            └─ 즉시 생산성, Day 1 배포 가능
```

---

## CRITICAL: 온보딩 메트릭

```
┌─────────────────────────────────────────────────────────────────┐
│                  Developer Onboarding Metrics                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Time to First Deploy (TTFD)                                    │
│  ─────────────────────────                                      │
│  입사 → 첫 프로덕션 배포까지 시간                                 │
│                                                                  │
│  Elite:    < 1 day     (Day 1 Deploy)                           │
│  Good:     < 1 week                                             │
│  Medium:   < 2 weeks                                            │
│  Poor:     > 2 weeks   ← 많은 조직이 여기                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 목표: TTFD < 1 day = 개발자 경험 & 생산성 핵심 지표       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Additional Metrics:                                             │
│  - Time to First Commit: 첫 커밋까지 시간                        │
│  - Time to First PR: 첫 PR까지 시간                              │
│  - Environment Setup Time: 로컬 환경 구축 시간                   │
│  - Onboarding Satisfaction: 온보딩 만족도 (설문)                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 온보딩 단계별 목표

| 단계 | 목표 시간 | 완료 기준 |
|------|----------|-----------|
| Day 0 | 계정/접근 권한 | 모든 시스템 접근 가능 |
| Day 0.5 | 개발 환경 | 로컬에서 앱 실행 |
| Day 1 | 첫 커밋 | 작은 변경 커밋 |
| Day 1-2 | 첫 PR | 코드 리뷰 받기 |
| Day 2-3 | 첫 배포 | 프로덕션 배포 |
| Week 1 | 독립 작업 | 티켓 혼자 처리 |

---

## 자동화 온보딩 체크리스트

### 셀프서비스 온보딩 포털

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

## 개발 환경 자동화

### Dev Container 설정

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

### 셋업 스크립트

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

### Gitpod 설정

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

---

## 첫 배포 가이드 (Day 1 Deploy)

### 온보딩 첫 과제 템플릿

```yaml
# first-task-template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: first-deploy-task
  title: 첫 배포 과제
  description: 신규 개발자의 첫 프로덕션 배포 과제
spec:
  owner: platform-team
  type: task

  parameters:
    - title: 과제 선택
      properties:
        taskType:
          title: 과제 유형
          type: string
          enum:
            - readme-update        # README 오타 수정
            - config-change        # 설정 값 변경
            - log-message          # 로그 메시지 추가
            - small-feature        # 작은 기능 추가
          enumNames:
            - "README 업데이트 (가장 쉬움)"
            - "설정 값 변경"
            - "로그 메시지 추가"
            - "작은 기능 추가 (도전적)"

  steps:
    - id: create-issue
      name: GitHub 이슈 생성
      action: github:create-issue
      input:
        repoUrl: github.com?owner=mycompany&repo=main-service
        title: "[온보딩] ${{ parameters.taskType }} - ${{ user.entity.metadata.name }}"
        body: |
          ## 첫 배포 과제

          **개발자**: ${{ user.entity.metadata.name }}
          **과제 유형**: ${{ parameters.taskType }}

          ### 목표
          이 과제를 통해 전체 개발-배포 사이클을 경험합니다.

          ### 체크리스트
          - [ ] 브랜치 생성 (`feature/onboarding-${{ user.entity.metadata.name }}`)
          - [ ] 변경사항 구현
          - [ ] 로컬 테스트 통과
          - [ ] PR 생성
          - [ ] 코드 리뷰 받기
          - [ ] CI 통과
          - [ ] 스테이징 배포 확인
          - [ ] 프로덕션 배포 🎉

          ### 도움이 필요하면
          - 멘토: @assigned-mentor
          - Slack: #dev-help

    - id: assign-mentor
      name: 멘토 할당
      action: slack:send-message
      input:
        channel: mentors
        message: |
          🆕 신규 개발자 첫 배포 과제 시작!
          - 개발자: ${{ user.entity.metadata.name }}
          - 이슈: ${{ steps['create-issue'].output.issueUrl }}
          자원하실 멘토는 이슈에 댓글 남겨주세요.

  output:
    links:
      - title: 과제 이슈
        url: ${{ steps['create-issue'].output.issueUrl }}
```

### 첫 배포 안전장치

```yaml
# .github/workflows/first-deploy-safety.yaml
name: First Deploy Safety Check

on:
  pull_request:
    types: [opened]

jobs:
  check-first-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Check if First PR
        id: check
        uses: actions/github-script@v7
        with:
          script: |
            const prs = await github.rest.pulls.list({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'all',
              creator: context.payload.pull_request.user.login
            });

            const isFirst = prs.data.length === 1;
            core.setOutput('is_first', isFirst);

            if (isFirst) {
              // 첫 PR 라벨 추가
              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                labels: ['first-contribution', 'needs-mentor-review']
              });

              // 환영 메시지
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                body: `## 🎉 첫 PR을 축하합니다!

                Welcome to the team, @${context.payload.pull_request.user.login}!

                ### 다음 단계:
                1. CI가 통과하는지 확인하세요
                2. 멘토가 리뷰를 진행할 예정입니다
                3. 피드백을 반영하세요
                4. 승인 후 머지됩니다!

                질문이 있으면 언제든 댓글로 남겨주세요. 🚀`
              });

              // 멘토 자동 할당
              await github.rest.pulls.requestReviewers({
                owner: context.repo.owner,
                repo: context.repo.repo,
                pull_number: context.payload.pull_request.number,
                reviewers: ['mentor-1', 'mentor-2']
              });
            }
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

## 온보딩 메트릭 수집

### 자동 TTFD 측정

```yaml
# .github/workflows/onboarding-metrics.yaml
name: Onboarding Metrics

on:
  pull_request:
    types: [closed]

jobs:
  track-first-deploy:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - name: Check First Merged PR
        uses: actions/github-script@v7
        with:
          script: |
            const author = context.payload.pull_request.user.login;

            // 이전 머지된 PR 조회
            const prs = await github.rest.pulls.list({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'closed',
              creator: author
            });

            const mergedPRs = prs.data.filter(pr => pr.merged_at);

            if (mergedPRs.length === 1) {
              // 첫 머지!
              const user = await github.rest.users.getByUsername({
                username: author
              });

              // 계정 생성일 기준 TTFD 계산 (실제로는 입사일 사용)
              const createdAt = new Date(user.data.created_at);
              const mergedAt = new Date(context.payload.pull_request.merged_at);
              const ttfdDays = (mergedAt - createdAt) / (1000 * 60 * 60 * 24);

              // 메트릭 전송
              await fetch(process.env.METRICS_ENDPOINT, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                  metric: 'time_to_first_deploy',
                  developer: author,
                  ttfd_days: ttfdDays,
                  first_pr_url: context.payload.pull_request.html_url
                })
              });

              // 축하 메시지
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                body: `## 🎊 첫 프로덕션 배포 완료!

                축하합니다 @${author}! 첫 코드가 프로덕션에 배포되었습니다!

                **Time to First Deploy**: ${ttfdDays.toFixed(1)} days

                이제 팀의 정식 기여자입니다! 🚀`
              });
            }
```

### Prometheus 메트릭

```promql
# 평균 TTFD (Time to First Deploy)
avg(onboarding_ttfd_days) by (team)

# TTFD 분포
histogram_quantile(0.5, sum(rate(onboarding_ttfd_days_bucket[30d])) by (le))
histogram_quantile(0.95, sum(rate(onboarding_ttfd_days_bucket[30d])) by (le))

# 환경 설정 시간
avg(onboarding_env_setup_minutes) by (method)  # devcontainer, local, gitpod

# 온보딩 완료율
sum(onboarding_completed_total) by (team)
/
sum(onboarding_started_total) by (team)

# 온보딩 만족도
avg(onboarding_satisfaction_score) by (team, quarter)
```

### Grafana 대시보드

```json
{
  "title": "Developer Onboarding",
  "panels": [
    {
      "title": "Time to First Deploy (Days)",
      "type": "stat",
      "targets": [{
        "expr": "avg(onboarding_ttfd_days)"
      }],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              {"value": 0, "color": "green"},
              {"value": 3, "color": "yellow"},
              {"value": 7, "color": "red"}
            ]
          },
          "unit": "d"
        }
      }
    },
    {
      "title": "TTFD Trend",
      "type": "timeseries",
      "targets": [{
        "expr": "avg(onboarding_ttfd_days) by (team)",
        "legendFormat": "{{team}}"
      }]
    },
    {
      "title": "Environment Setup Time",
      "type": "bargauge",
      "targets": [{
        "expr": "avg(onboarding_env_setup_minutes) by (method)"
      }],
      "fieldConfig": {
        "defaults": {
          "unit": "m"
        }
      }
    },
    {
      "title": "Onboarding Satisfaction",
      "type": "gauge",
      "targets": [{
        "expr": "avg(onboarding_satisfaction_score)"
      }],
      "fieldConfig": {
        "defaults": {
          "max": 5,
          "thresholds": {
            "steps": [
              {"value": 0, "color": "red"},
              {"value": 3, "color": "yellow"},
              {"value": 4, "color": "green"}
            ]
          }
        }
      }
    }
  ]
}
```

---

## AI 어시스트 온보딩

### Claude/Copilot 컨텍스트 자동 주입

```markdown
<!-- CLAUDE.md - 온보딩 컨텍스트 -->
# 프로젝트 컨텍스트

## 신규 개발자를 위한 안내

이 저장소는 [서비스명]의 백엔드 서비스입니다.

### 핵심 개념
- **도메인**: 주문 처리 시스템
- **아키텍처**: 마이크로서비스 (이벤트 드리븐)
- **주요 기술**: Go, PostgreSQL, Kafka, Kubernetes

### 코드 탐색 가이드
```
cmd/           # 애플리케이션 진입점
internal/
  domain/      # 비즈니스 로직 (여기서 시작)
  handler/     # HTTP 핸들러
  repository/  # 데이터 접근
  service/     # 유스케이스
pkg/           # 공유 라이브러리
```

### 자주 묻는 질문
Q: 로컬에서 어떻게 실행하나요?
A: `make run` 또는 Dev Container 사용

Q: 테스트는 어떻게 실행하나요?
A: `make test` (단위), `make test-integration` (통합)

Q: 배포는 어떻게 하나요?
A: main 브랜치 머지 시 자동 배포 (ArgoCD)

### 온보딩 첫 과제 추천
1. README 오타 수정
2. 로그 메시지 개선
3. 단위 테스트 추가
```

### AI 온보딩 봇

```yaml
# ai-onboarding-bot.yaml
name: AI Onboarding Assistant

triggers:
  - event: member_joined
  - event: first_commit
  - event: stuck_for_hours

actions:
  member_joined:
    - send_welcome_message
    - create_personalized_learning_path
    - schedule_checkin

  first_commit:
    - celebrate
    - suggest_next_steps

  stuck_for_hours:
    - offer_help
    - connect_with_mentor
    - suggest_resources

prompts:
  welcome: |
    안녕하세요 {name}님! 팀에 오신 것을 환영합니다.

    저는 온보딩을 도와드릴 AI 어시스턴트입니다.

    현재 진행 상황:
    - 계정 설정: {account_status}
    - 개발 환경: {env_status}
    - 첫 과제: {task_status}

    도움이 필요하시면 언제든 물어보세요!

  stuck_help: |
    {name}님, {hours}시간 동안 진행이 없는 것 같아요.

    혹시 막히는 부분이 있으신가요?

    - 환경 설정 문제 → /help setup
    - 코드 이해 문제 → /explain [파일경로]
    - 기타 → 멘토 연결해드릴까요?
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 문서만 던져주기 | 컨텍스트 부족 | 인터랙티브 가이드 |
| 수동 계정 설정 | 1-2일 지연 | 셀프서비스 자동화 |
| 복잡한 로컬 설정 | 환경 불일치 | Dev Container |
| 첫 과제 난이도 높음 | 좌절감 | 단순한 첫 과제 |
| 멘토 미배정 | 질문 못함 | 자동 멘토 매칭 |
| TTFD 미측정 | 개선 불가 | 자동 메트릭 수집 |

---

## 체크리스트

### 자동화
- [ ] 셀프서비스 온보딩 포털
- [ ] 계정/권한 자동 프로비저닝
- [ ] Dev Container 또는 Gitpod 설정
- [ ] 첫 과제 자동 생성

### 문서화
- [ ] 인터랙티브 온보딩 가이드
- [ ] 아키텍처 다이어그램
- [ ] FAQ 문서
- [ ] 트러블슈팅 가이드

### 메트릭
- [ ] TTFD 자동 측정
- [ ] 환경 설정 시간 추적
- [ ] 온보딩 만족도 설문
- [ ] 대시보드 구축

### 멘토링
- [ ] 멘토 자동 할당
- [ ] 첫 PR 리뷰 가이드라인
- [ ] 정기 체크인 스케줄

**관련 skill**: `/dx-metrics`, `/platform-backstage`, `/dx-ai-agents`
