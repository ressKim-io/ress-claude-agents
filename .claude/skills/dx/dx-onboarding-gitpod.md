# Developer Onboarding: Gitpod & 셀프서비스 포털

Gitpod 설정, Backstage 온보딩 템플릿, TechDocs 자동화

## Quick Reference

```
클라우드 IDE?
    │
    └─ Gitpod ───────────> 브라우저에서 즉시 개발
            │
            ├─ .gitpod.yml ───> 환경 정의
            ├─ Dockerfile ────> 커스텀 이미지
            └─ 프리빌드 ──────> 빠른 시작

셀프서비스?
    │
    └─ Backstage ────────> 온보딩 자동화
            │
            ├─ GitHub 초대
            ├─ AWS IAM 설정
            ├─ K8s RBAC
            └─ 샌드박스 저장소 생성
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
      echo "환경 준비 완료!"
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
  - 운영:
      - 배포 프로세스: operations/deployment.md
      - 모니터링: operations/monitoring.md
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
- [ ] 프로덕션 배포
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

### Gitpod
- [ ] .gitpod.yml 설정
- [ ] Dockerfile 작성
- [ ] 포트 설정
- [ ] 프리빌드 설정

### Backstage 온보딩
- [ ] 템플릿 정의
- [ ] GitHub 초대 액션
- [ ] AWS IAM 액션
- [ ] K8s RBAC 액션
- [ ] 웰컴 이메일 템플릿

### 문서화
- [ ] 온보딩 가이드 작성
- [ ] 트러블슈팅 문서
- [ ] FAQ 정리
- [ ] TechDocs 설정

**관련 skill**: `/dx-onboarding` (허브), `/dx-onboarding-environment` (Dev Container), `/backstage`
