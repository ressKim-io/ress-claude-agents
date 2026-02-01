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
```

---

## GitHub Copilot 통합

### 조직 설정

```yaml
# .github/copilot-config.yml
copilot:
  features:
    code_completion: true
    chat: true
    cli: true
    coding_agent: true

  content_exclusions:
    - "**/.env*"
    - "**/secrets/**"
    - "**/*credentials*"
    - "**/private/**"

  code_references:
    enable_suggestions_matching_public_code: false
```

### Copilot Coding Agent 워크플로우

```yaml
# .github/workflows/copilot-agent.yaml
name: Copilot Agent Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
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

  ai-pr-validation:
    needs: detect-ai-pr
    if: needs.detect-ai-pr.outputs.is_ai_generated == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

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

---

## AI Agent 오케스트레이션

### 멀티 에이전트 협업 패턴

```
+------------------------------------------------------------------+
|                  Multi-Agent Orchestration                         |
+------------------------------------------------------------------+
|                                                                    |
|  ┌─────────────────────────────────────────────────────────────┐  |
|  │                    Orchestrator Agent                        │  |
|  │  - 작업 분해 및 할당                                         │  |
|  │  - 결과 통합                                                 │  |
|  │  - 품질 검증                                                 │  |
|  └─────────────────────────────────────────────────────────────┘  |
|                               │                                    |
|          ┌────────────────────┼────────────────────┐              |
|          │                    │                    │              |
|          ▼                    ▼                    ▼              |
|  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐        |
|  │ Code Agent   │    │ Test Agent   │    │ Review Agent │        |
|  │ - 코드 생성  │    │ - 테스트 작성│    │ - 코드 리뷰  │        |
|  │ - 리팩토링   │    │ - 테스트 실행│    │ - 보안 검사  │        |
|  └──────────────┘    └──────────────┘    └──────────────┘        |
|          │                    │                    │              |
|          └────────────────────┼────────────────────┘              |
|                               ▼                                    |
|  ┌─────────────────────────────────────────────────────────────┐  |
|  │                    Human Review Gate                         │  |
|  │  - 최종 승인/거부                                            │  |
|  │  - 피드백 제공                                               │  |
|  └─────────────────────────────────────────────────────────────┘  |
|                                                                    |
+------------------------------------------------------------------+
```

### 오케스트레이션 구현

```yaml
# ai-orchestrator-config.yaml
apiVersion: platform.company.io/v1
kind: AIOrchestrator
metadata:
  name: development-orchestrator
spec:
  # 에이전트 정의
  agents:
    - name: code-agent
      type: code-generation
      model: claude-3-opus
      capabilities:
        - code_generation
        - refactoring
        - bug_fix
      constraints:
        maxTokensPerRequest: 100000
        maxFilesModified: 10

    - name: test-agent
      type: test-generation
      model: claude-3-sonnet
      capabilities:
        - unit_test_generation
        - integration_test
        - test_execution
      constraints:
        maxTestFiles: 20
        timeout: 300s

    - name: review-agent
      type: code-review
      model: claude-3-opus
      capabilities:
        - security_review
        - performance_review
        - style_check
      constraints:
        reviewDepth: thorough

  # 워크플로우 정의
  workflows:
    feature-development:
      steps:
        - agent: code-agent
          action: generate_code
          input: ${{ issue.description }}
          output: code_changes

        - agent: test-agent
          action: generate_tests
          input: ${{ steps.code_changes }}
          output: test_files

        - agent: test-agent
          action: run_tests
          input: ${{ steps.test_files }}
          continueOnError: false

        - agent: review-agent
          action: review
          input: ${{ steps.code_changes }}
          output: review_comments

        - gate: human-approval
          condition: ${{ steps.review_comments.severity == 'high' }}
          timeout: 24h
          fallback: reject

  # 가드레일
  guardrails:
    - name: no-secrets
      check: "!contains(output, 'API_KEY') && !contains(output, 'SECRET')"
      action: reject

    - name: max-changes
      check: "changedFiles.length <= 20"
      action: require-approval

    - name: critical-files
      check: "!modifies(['**/security/**', '**/auth/**'])"
      action: require-senior-review
```

### 가드레일 상세 설정

```yaml
# ai-guardrails.yaml
apiVersion: platform.company.io/v1
kind: AIGuardrails
metadata:
  name: enterprise-guardrails
spec:
  # 입력 검증
  inputValidation:
    - name: prompt-injection-check
      type: regex
      patterns:
        - "ignore.*previous.*instructions"
        - "system.*prompt"
        - "jailbreak"
      action: block

    - name: pii-filter
      type: ml-classifier
      model: pii-detector
      threshold: 0.8
      action: mask

  # 출력 검증
  outputValidation:
    - name: secret-detection
      type: pattern
      patterns:
        - "\\bAKIA[0-9A-Z]{16}\\b"  # AWS Access Key
        - "\\b[A-Za-z0-9+/]{40}\\b"  # Generic secret
      action: redact

    - name: code-quality
      type: linter
      tools:
        - eslint
        - pylint
      minScore: 7.0
      action: warn

    - name: security-scan
      type: sast
      tools:
        - semgrep
        - bandit
      severity: high
      action: block

  # 행동 제한
  behaviorLimits:
    maxOutputTokens: 50000
    maxFileCreations: 5
    maxFileModifications: 15
    forbiddenOperations:
      - delete_branch
      - force_push
      - modify_workflow

  # 승인 게이트
  approvalGates:
    - name: production-changes
      trigger:
        paths:
          - "k8s/production/**"
          - "**/Dockerfile"
          - ".github/workflows/**"
      approvers:
        - team: platform
          minCount: 1
        - team: security
          minCount: 1
          conditions:
            - modifies("**/security/**")

    - name: database-changes
      trigger:
        paths:
          - "**/migrations/**"
          - "**/schema/**"
      approvers:
        - team: dba
          minCount: 1
```

### Self-Healing 인프라

```yaml
# ai-self-healing.yaml
apiVersion: platform.company.io/v1
kind: AISelfHealing
metadata:
  name: infrastructure-healer
spec:
  # 모니터링 연동
  monitoring:
    prometheus:
      url: http://prometheus:9090
    alertmanager:
      url: http://alertmanager:9093

  # 자동 복구 규칙
  healingRules:
    - name: pod-crash-loop
      trigger:
        alert: KubePodCrashLooping
        duration: 5m
      actions:
        - type: analyze
          agent: diagnostics-agent
          input: "${{ alert.labels }}"

        - type: remediate
          agent: remediation-agent
          options:
            - restart_pod
            - scale_replicas
            - rollback_deployment
          requireApproval: false
          maxAttempts: 3

    - name: high-error-rate
      trigger:
        alert: HighErrorRate
        threshold: "error_rate > 0.05"
      actions:
        - type: analyze
          agent: root-cause-agent

        - type: remediate
          agent: traffic-agent
          options:
            - shift_traffic
            - enable_circuit_breaker
          requireApproval: true
          approvalTimeout: 5m

    - name: resource-exhaustion
      trigger:
        alert: HighMemoryUsage
        threshold: "memory_usage > 0.9"
      actions:
        - type: scale
          direction: up
          increment: 2
          maxReplicas: 10

        - type: notify
          channel: "#platform-alerts"
          message: "Auto-scaled due to memory pressure"

  # 학습 및 개선
  learning:
    enabled: true
    feedbackLoop:
      - recordActions: true
      - evaluateOutcomes: true
      - improveDecisions: true
    retentionDays: 90
```

### 에이전트 메트릭 수집

```yaml
# ai-agent-metrics.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ai-agent-metrics
spec:
  selector:
    matchLabels:
      app: ai-orchestrator
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
---
# Grafana Dashboard 쿼리 예시

# 에이전트별 작업 성공률
sum(rate(ai_agent_tasks_total{status="success"}[1h])) by (agent)
/
sum(rate(ai_agent_tasks_total[1h])) by (agent)

# 평균 응답 시간
histogram_quantile(0.95,
  sum(rate(ai_agent_response_duration_seconds_bucket[5m])) by (le, agent)
)

# 토큰 사용량 (비용 추적)
sum(increase(ai_agent_tokens_used_total[1d])) by (agent, model)

# 가드레일 트리거 횟수
sum(increase(ai_guardrail_triggered_total[1h])) by (rule, action)
```

---

## AI Agent 오케스트레이션 체크리스트

### 설계
- [ ] 에이전트 역할 정의
- [ ] 워크플로우 설계
- [ ] 가드레일 규칙 정의
- [ ] 승인 게이트 설정

### 구현
- [ ] 오케스트레이터 배포
- [ ] 에이전트 연동
- [ ] 가드레일 적용
- [ ] 모니터링 설정

### 운영
- [ ] 메트릭 대시보드
- [ ] 알림 설정
- [ ] 비용 모니터링
- [ ] 피드백 수집

**관련 skill**: `/dx-ai-security` (보안/품질), `/dx-metrics`, `/cicd-devsecops`, `/finops-advanced`, `/aiops`
