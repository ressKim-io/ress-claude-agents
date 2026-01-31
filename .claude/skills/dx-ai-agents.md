# AI Agents 플랫폼 통합 가이드

AI 코딩 에이전트 거버넌스, Copilot/Claude 통합, 엔터프라이즈 AI 정책

## Quick Reference (결정 트리)

```
AI 에이전트 유형?
    │
    ├─ Copilot (보조) ────────> 실시간 코드 제안, 인간 입력 필수
    │       │
    │       └─ GitHub Copilot, Cursor, Codeium
    │
    ├─ Agent (자율) ──────────> 이슈 → PR 자동 생성, 비동기 작업
    │       │
    │       └─ Copilot Coding Agent, Claude Code, Devin
    │
    └─ 하이브리드 ────────────> 일부 자율 + 인간 검토
            │
            └─ 권장: PR 자동 생성 + 인간 머지
```

---

## CRITICAL: AI Agent 성숙도 모델

```
┌─────────────────────────────────────────────────────────────────┐
│                AI Agent Maturity Model (2026)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Level 1: Assisted       Level 2: Automated      Level 3: Autonomous │
│  ────────────────       ─────────────────       ─────────────────    │
│  - 코드 자동완성         - PR 자동 생성          - 이슈 할당 → 완료    │
│  - 인라인 제안          - 테스트 자동 작성       - 자체 코드 리뷰      │
│  - 문서 생성 보조        - 리팩토링 제안         - 배포 결정           │
│                                                                  │
│  인간 개입: 항상         인간 개입: 검토/승인     인간 개입: 예외만     │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 2026 권장: Level 2 (Automated) + 엄격한 거버넌스         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Copilot vs Agent 비교

| 특성 | Copilot (보조) | Agent (자율) |
|------|---------------|--------------|
| 작동 방식 | 실시간 제안 | 비동기 작업 |
| 인간 개입 | 매 줄마다 | 작업 완료 후 |
| 컨텍스트 | 현재 파일 | 전체 저장소 |
| 출력물 | 코드 스니펫 | PR, 커밋 |
| 리스크 | 낮음 | 중간~높음 |
| 거버넌스 | 기본 | **필수** |

---

## AI 에이전트 거버넌스

### CRITICAL: 엔터프라이즈 정책 프레임워크

```yaml
# ai-governance-policy.yaml
apiVersion: platform.company.io/v1
kind: AIAgentPolicy
metadata:
  name: enterprise-ai-policy
spec:
  # 1. 접근 제어
  access:
    allowedRepositories:
      - "org/*"                    # 전체 조직
      - "!org/secrets-*"           # 시크릿 저장소 제외
      - "!org/compliance-*"        # 컴플라이언스 저장소 제외

    allowedBranches:
      - "feature/*"
      - "fix/*"
      - "ai/*"                     # AI 전용 브랜치
    deniedBranches:
      - "main"
      - "release/*"
      - "hotfix/*"

  # 2. 권한 수준
  permissions:
    codeGeneration: true
    codeModification: true
    prCreation: true
    prMerge: false                 # 인간만 머지 가능
    issueCreation: true
    issueClose: false

  # 3. 리소스 제한
  resourceLimits:
    maxTokensPerRequest: 100000
    maxRequestsPerHour: 100
    maxConcurrentTasks: 5
    budgetPerMonth: 500            # USD

  # 4. 콘텐츠 정책
  contentPolicy:
    scanForSecrets: true
    scanForPII: true
    requireCodeReview: true
    minReviewers: 1

  # 5. 감사 로깅
  audit:
    logAllRequests: true
    logResponses: true
    retentionDays: 90
```

### RBAC for AI Agents

```yaml
# ai-agent-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ai-agent-developer
rules:
  # 읽기 권한
  - apiGroups: [""]
    resources: ["configmaps", "services", "pods"]
    verbs: ["get", "list", "watch"]

  # 제한된 쓰기 권한
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "patch"]
    # 삭제, 생성 권한 없음

  # Secret 접근 금지 (명시적)
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: []                      # 모든 동작 금지
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ai-agent-binding
  namespace: development
subjects:
  - kind: ServiceAccount
    name: ai-agent-sa
    namespace: ai-platform
roleRef:
  kind: ClusterRole
  name: ai-agent-developer
  apiGroup: rbac.authorization.k8s.io
```

---

## GitHub Copilot 통합

### 조직 설정

```yaml
# .github/copilot-config.yml
# 조직 수준 Copilot 설정
copilot:
  # 기능 활성화
  features:
    code_completion: true
    chat: true
    cli: true
    coding_agent: true            # Copilot Coding Agent

  # 콘텐츠 필터링
  content_exclusions:
    - "**/.env*"
    - "**/secrets/**"
    - "**/*credentials*"
    - "**/private/**"

  # 코드 참조 설정
  code_references:
    enable_suggestions_matching_public_code: false

  # 에디터 설정
  editor:
    enable_auto_completions: true
    show_code_references: true
```

### Copilot Coding Agent 워크플로우

```yaml
# .github/workflows/copilot-agent.yaml
name: Copilot Agent Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  # AI가 생성한 PR인지 확인
  detect-ai-pr:
    runs-on: ubuntu-latest
    outputs:
      is_ai_generated: ${{ steps.check.outputs.is_ai }}
    steps:
      - name: Check if AI-generated
        id: check
        run: |
          if [[ "${{ github.event.pull_request.user.login }}" == *"[bot]"* ]] || \
             [[ "${{ github.event.pull_request.head.ref }}" == "copilot/"* ]]; then
            echo "is_ai=true" >> $GITHUB_OUTPUT
          else
            echo "is_ai=false" >> $GITHUB_OUTPUT
          fi

  # AI PR에 대한 추가 검증
  ai-pr-validation:
    needs: detect-ai-pr
    if: needs.detect-ai-pr.outputs.is_ai_generated == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # 필수 리뷰어 자동 할당
      - name: Assign Human Reviewers
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.pulls.requestReviewers({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.payload.pull_request.number,
              reviewers: ['senior-dev-1', 'senior-dev-2']
            });

      # AI 생성 코드 라벨 추가
      - name: Add AI Label
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.pull_request.number,
              labels: ['ai-generated', 'needs-human-review']
            });

      # 보안 스캔 강화
      - name: Enhanced Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'MEDIUM,HIGH,CRITICAL'
          exit-code: '1'

      # 시크릿 스캔
      - name: Secret Scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          extra_args: --only-verified
```

---

## Claude Code 통합

### 프로젝트 설정 (CLAUDE.md)

```markdown
# CLAUDE.md - AI 에이전트 가이드라인

## 권한 범위
- 코드 생성: 허용
- 테스트 작성: 허용
- 리팩토링: 허용 (기존 동작 유지)
- 설정 파일 수정: 검토 필요
- 시크릿/인증 관련: 금지

## 코드 스타일
- 기존 패턴 준수
- 새 의존성 추가 전 확인 요청
- 주석은 복잡한 로직에만

## 금지 사항
- .env 파일 수정/생성 금지
- credentials, secrets 관련 코드 금지
- 프로덕션 데이터베이스 직접 접근 금지
- 외부 API 키 하드코딩 금지

## 작업 완료 기준
- 모든 테스트 통과
- 린트 에러 없음
- 기존 기능 회귀 없음
```

### MCP (Model Context Protocol) 서버 설정

```json
// .claude/mcp-config.json
{
  "mcpServers": {
    "github": {
      "command": "mcp-server-github",
      "args": ["--repo", "org/repo"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      },
      "permissions": {
        "read": ["issues", "pull_requests", "code"],
        "write": ["issues", "pull_requests"],
        "admin": []
      }
    },
    "kubernetes": {
      "command": "mcp-server-kubernetes",
      "args": ["--context", "development"],
      "permissions": {
        "read": ["pods", "deployments", "services"],
        "write": [],
        "admin": []
      }
    },
    "filesystem": {
      "command": "mcp-server-filesystem",
      "args": ["--root", "/workspace"],
      "permissions": {
        "read": ["**/*"],
        "write": ["src/**", "tests/**"],
        "deny": ["**/.env*", "**/secrets/**"]
      }
    }
  }
}
```

---

## AI 비용 관리 (FinOps)

### 토큰 예산 관리

```yaml
# ai-budget-policy.yaml
apiVersion: finops.company.io/v1
kind: AIBudget
metadata:
  name: team-backend-ai-budget
spec:
  team: backend
  period: monthly

  limits:
    # 총 예산
    totalBudget: 1000              # USD

    # 서비스별 할당
    services:
      github-copilot:
        budget: 400
        perUserLimit: 50
      claude-api:
        budget: 400
        tokenLimit: 10000000       # 10M tokens
      openai-api:
        budget: 200

  alerts:
    - threshold: 50                # 50% 사용 시
      action: notify
      channels: ["slack:#finops"]
    - threshold: 80                # 80% 사용 시
      action: notify
      channels: ["slack:#finops", "email:team-lead"]
    - threshold: 100               # 100% 도달 시
      action: throttle             # 속도 제한
      fallbackModel: "gpt-3.5-turbo"

  tracking:
    granularity: per-request
    attributes:
      - user
      - repository
      - task_type
```

### 비용 모니터링 대시보드

```promql
# AI 토큰 사용량 (일간)
sum(increase(ai_tokens_used_total[24h])) by (team, model)

# 팀별 AI 비용
sum(
  increase(ai_tokens_used_total[30d])
  * on(model) group_left(cost_per_token)
  ai_model_pricing
) by (team)

# 작업 유형별 토큰 효율성
sum(ai_tokens_used_total) by (task_type)
/
sum(ai_tasks_completed_total) by (task_type)

# 예산 소진율
sum(ai_cost_total) by (team)
/
sum(ai_budget_limit) by (team)
```

---

## 보안 가이드라인

### AI 생성 코드 보안 체크리스트

```yaml
# ai-security-checklist.yaml
checks:
  # 1. 시크릿 노출
  - name: secret-detection
    tools: [trufflehog, gitleaks]
    severity: critical
    block_merge: true

  # 2. 취약점 패턴
  - name: vulnerability-patterns
    patterns:
      - "eval("                   # 코드 실행
      - "exec("
      - "innerHTML"               # XSS
      - "dangerouslySetInnerHTML"
      - "SELECT.*FROM.*WHERE"     # SQL Injection 가능성
    severity: high
    block_merge: true

  # 3. 의존성 검증
  - name: dependency-check
    description: "새 의존성 추가 시 승인 필요"
    files: ["package.json", "go.mod", "requirements.txt", "pom.xml"]
    require_approval: true

  # 4. 권한 상승
  - name: privilege-escalation
    patterns:
      - "sudo"
      - "chmod 777"
      - "privileged: true"
      - "runAsRoot: true"
    severity: critical
    block_merge: true
```

### Kyverno AI 코드 정책

```yaml
# ai-code-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: ai-generated-code-review
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: require-human-review-for-ai-pr
      match:
        any:
          - resources:
              kinds:
                - PullRequest
              annotations:
                ai-generated: "true"
      validate:
        message: "AI 생성 PR은 최소 1명의 인간 리뷰어 승인이 필요합니다"
        deny:
          conditions:
            - key: "{{ request.object.spec.approvals }}"
              operator: LessThan
              value: 1
```

---

## 품질 보증

### AI 코드 품질 게이트

```yaml
# .github/workflows/ai-quality-gate.yaml
name: AI Code Quality Gate

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  quality-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # 1. 테스트 커버리지 (AI PR은 더 높은 기준)
      - name: Test Coverage Check
        run: |
          COVERAGE=$(go test -coverprofile=coverage.out ./... | grep total | awk '{print $3}' | sed 's/%//')
          if [[ "${{ github.event.pull_request.labels.*.name }}" == *"ai-generated"* ]]; then
            THRESHOLD=80  # AI PR: 80% 이상
          else
            THRESHOLD=70  # 일반 PR: 70% 이상
          fi
          if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
            echo "Coverage $COVERAGE% is below threshold $THRESHOLD%"
            exit 1
          fi

      # 2. 코드 복잡도 체크
      - name: Complexity Check
        run: |
          gocyclo -over 15 . && echo "Complexity OK" || exit 1

      # 3. AI 환각 감지 (존재하지 않는 API 호출 등)
      - name: Hallucination Detection
        run: |
          # import 검증
          go build ./... 2>&1 | tee build.log
          if grep -q "undefined:" build.log; then
            echo "Potential AI hallucination detected: undefined references"
            exit 1
          fi

      # 4. 문서화 검증
      - name: Documentation Check
        run: |
          # 새 public 함수에 주석 필수
          golint ./... | grep -v "should have comment" || true
```

### AI 코드 리뷰 자동화

```yaml
# ai-code-review.yaml
name: AI-Assisted Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # AI 리뷰어 (CodeRabbit, PR-Agent 등)
      - name: AI Code Review
        uses: coderabbitai/ai-pr-reviewer@latest
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          review_type: "comprehensive"
          focus_areas:
            - security
            - performance
            - best-practices
          language: "ko"           # 한국어 리뷰

      # 리뷰 결과 요약
      - name: Summarize Review
        uses: actions/github-script@v7
        with:
          script: |
            const reviews = await github.rest.pulls.listReviews({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.payload.pull_request.number
            });

            const aiReviews = reviews.data.filter(r =>
              r.user.login.includes('[bot]')
            );

            if (aiReviews.length > 0) {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                body: `## AI 리뷰 요약\n\nAI 리뷰어가 ${aiReviews.length}개의 리뷰를 작성했습니다. 인간 리뷰어의 최종 확인이 필요합니다.`
              });
            }
```

---

## 메트릭 & 모니터링

### AI 생산성 메트릭

```promql
# AI 어시스턴스 수용률
sum(ai_suggestions_accepted_total) by (team)
/
sum(ai_suggestions_total) by (team)

# AI 생성 코드 품질 (버그 발생률)
sum(bugs_from_ai_code_total) by (repository)
/
sum(ai_code_merged_total) by (repository)

# 개발자 시간 절약 추정
sum(ai_task_duration_saved_seconds) by (team, task_type) / 3600

# AI vs 인간 코드 비율
sum(lines_of_code_ai_generated) by (repository)
/
sum(lines_of_code_total) by (repository)
```

### 알림 규칙

```yaml
# ai-alerts.yaml
groups:
  - name: ai-agent-alerts
    rules:
      - alert: AIBudgetExceeded
        expr: |
          sum(ai_cost_total) by (team)
          /
          sum(ai_budget_limit) by (team)
          > 0.9
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "팀 {{ $labels.team }} AI 예산 90% 초과"

      - alert: AICodeQualityDrop
        expr: |
          sum(rate(bugs_from_ai_code_total[7d])) by (repository)
          /
          sum(rate(ai_code_merged_total[7d])) by (repository)
          > 0.1
        for: 24h
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.repository }} AI 생성 코드 버그율 10% 초과"

      - alert: AISuggestionAcceptanceDropped
        expr: |
          sum(rate(ai_suggestions_accepted_total[7d])) by (team)
          /
          sum(rate(ai_suggestions_total[7d])) by (team)
          < 0.3
        for: 7d
        labels:
          severity: info
        annotations:
          summary: "팀 {{ $labels.team }} AI 제안 수용률 30% 미만"
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| AI에게 프로덕션 접근 허용 | 심각한 보안 리스크 | 개발 환경만 허용 |
| AI PR 무검토 머지 | 품질/보안 문제 | 인간 리뷰 필수 |
| 토큰 예산 미설정 | 비용 폭증 | 팀별 예산 할당 |
| AI 생성 코드 구분 안함 | 품질 추적 불가 | 라벨링 필수 |
| 시크릿 필터링 미적용 | 키 노출 | 콘텐츠 필터 설정 |
| AI 메트릭 미수집 | ROI 증명 불가 | 사용량/품질 추적 |

---

## 체크리스트

### 거버넌스
- [ ] AI 에이전트 정책 문서화
- [ ] RBAC 설정 (저장소/브랜치 제한)
- [ ] 콘텐츠 필터링 (시크릿, PII)
- [ ] 감사 로깅 활성화

### 통합
- [ ] Copilot 조직 설정
- [ ] Claude CLAUDE.md 작성
- [ ] MCP 서버 설정
- [ ] CI/CD 파이프라인 연동

### 보안
- [ ] 시크릿 스캔 자동화
- [ ] AI PR 추가 검증 워크플로우
- [ ] 취약점 패턴 차단
- [ ] 인간 리뷰 필수화

### FinOps
- [ ] 팀별 토큰 예산 설정
- [ ] 비용 알림 설정
- [ ] 사용량 대시보드 구축

### 품질
- [ ] AI 코드 품질 게이트
- [ ] 커버리지 기준 강화
- [ ] AI 코드 리뷰 자동화
- [ ] 생산성 메트릭 수집

**관련 skill**: `/dx-metrics`, `/cicd-devsecops`, `/finops-advanced`
