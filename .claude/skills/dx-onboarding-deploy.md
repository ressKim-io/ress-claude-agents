# Developer Onboarding: 첫 배포 가이드

Day 1 Deploy 실현을 위한 첫 과제 템플릿, 안전장치, AI 어시스트

## Quick Reference

```
첫 배포 과제 선택?
    │
    ├─ README 업데이트 ───> 가장 쉬움, 전체 사이클 경험
    │
    ├─ 설정 값 변경 ─────> 코드 이해 시작
    │
    ├─ 로그 메시지 추가 ──> 코드 탐색 필요
    │
    └─ 작은 기능 추가 ───> 도전적, 멘토 지원 필요
```

---

## 첫 배포 과제 템플릿

### Backstage 첫 과제 템플릿

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

---

## 첫 배포 안전장치

### 첫 PR 자동 검증

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

### 온보딩 PR 추가 체크

```yaml
# .github/workflows/onboarding-pr-checks.yaml
name: Onboarding PR Checks

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  onboarding-checks:
    if: contains(github.event.pull_request.labels.*.name, 'first-contribution')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # 변경 범위 제한 확인
      - name: Check Change Scope
        uses: actions/github-script@v7
        with:
          script: |
            const files = await github.rest.pulls.listFiles({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.payload.pull_request.number
            });

            const sensitiveFiles = files.data.filter(f =>
              f.filename.includes('.env') ||
              f.filename.includes('secret') ||
              f.filename.includes('credential') ||
              f.filename.includes('Dockerfile') ||
              f.filename.includes('k8s/')
            );

            if (sensitiveFiles.length > 0) {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                body: `⚠️ **민감한 파일 변경 감지**\n\n첫 PR에서 다음 파일들을 변경하고 있습니다:\n${sensitiveFiles.map(f => `- ${f.filename}`).join('\n')}\n\n멘토의 추가 검토가 필요합니다.`
              });

              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                labels: ['needs-security-review']
              });
            }

      # 도움 리소스 제공
      - name: Provide Help Resources
        uses: actions/github-script@v7
        with:
          script: |
            const comments = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.pull_request.number
            });

            const hasHelpComment = comments.data.some(c =>
              c.body.includes('온보딩 리소스')
            );

            if (!hasHelpComment) {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                body: `## 📚 온보딩 리소스\n\n- [코드 스타일 가이드](https://docs.company.com/style-guide)\n- [PR 작성 가이드](https://docs.company.com/pr-guide)\n- [CI/CD 파이프라인 설명](https://docs.company.com/cicd)\n- [트러블슈팅 FAQ](https://docs.company.com/faq)\n\n막히는 부분이 있으면 \`#dev-help\` 채널에 질문하세요!`
              });
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

## Grafana 대시보드

### TTFD 대시보드

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

## 체크리스트

### 첫 과제 시스템
- [ ] 과제 유형별 템플릿
- [ ] 자동 이슈 생성
- [ ] 멘토 자동 할당
- [ ] 진행 상황 추적

### 안전장치
- [ ] 첫 PR 자동 감지
- [ ] 멘토 리뷰 필수화
- [ ] 민감 파일 변경 알림
- [ ] 도움 리소스 자동 제공

### AI 어시스트
- [ ] CLAUDE.md 컨텍스트 작성
- [ ] 온보딩 봇 설정
- [ ] 막힘 감지 알림

### 측정
- [ ] TTFD 자동 측정
- [ ] Grafana 대시보드
- [ ] 만족도 설문

**관련 skill**: `/dx-onboarding` (허브), `/dx-onboarding-environment` (개발 환경), `/dx-ai-agents`
