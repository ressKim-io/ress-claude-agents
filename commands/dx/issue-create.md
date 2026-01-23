# GitHub Issue Creator

템플릿 기반으로 GitHub Issue를 생성합니다.

## Instructions

1. 이슈 유형을 확인합니다 (bug, feature, task).
2. 해당 템플릿에 맞춰 이슈 내용을 구성합니다.
3. 적절한 라벨을 자동 추가합니다.
4. `gh issue create` 명령어로 이슈를 생성합니다.

## Issue Templates

### Bug Report
```markdown
## Bug Description
{버그에 대한 간단한 설명}

## Steps to Reproduce
1. {첫 번째 단계}
2. {두 번째 단계}
3. {세 번째 단계}

## Expected Behavior
{예상되는 동작}

## Actual Behavior
{실제 동작}

## Environment
- OS: {운영체제}
- Version: {앱 버전}
- Browser: {브라우저} (해당 시)

## Screenshots
{스크린샷 첨부 (있는 경우)}

## Additional Context
{추가 정보}
```

### Feature Request
```markdown
## Feature Description
{기능에 대한 간단한 설명}

## Background
{왜 이 기능이 필요한지 배경 설명}

## Proposed Solution
{제안하는 솔루션}

## Alternatives Considered
{고려한 대안들}

## Acceptance Criteria
- [ ] {기준 1}
- [ ] {기준 2}
- [ ] {기준 3}

## Additional Context
{추가 정보}
```

### Task
```markdown
## Task Description
{작업에 대한 설명}

## Objectives
- [ ] {목표 1}
- [ ] {목표 2}
- [ ] {목표 3}

## Technical Details
{기술적 세부 사항}

## Dependencies
{의존성 또는 선행 작업}

## Estimated Effort
{예상 소요 시간/노력}
```

## Issue Creation

### gh CLI 사용
```bash
# Bug
gh issue create \
  --title "[Bug] 로그인 시 500 에러 발생" \
  --body "$(cat <<'EOF'
## Bug Description
로그인 시도 시 500 Internal Server Error 발생

## Steps to Reproduce
1. 로그인 페이지 접속
2. 이메일과 비밀번호 입력
3. 로그인 버튼 클릭

## Expected Behavior
로그인 성공 후 대시보드로 이동

## Actual Behavior
500 에러 페이지 표시

## Environment
- OS: macOS 14.0
- Version: 1.2.3
- Browser: Chrome 120
EOF
)" \
  --label "bug,priority:high"

# Feature
gh issue create \
  --title "[Feature] 소셜 로그인 추가" \
  --body "..." \
  --label "feature,enhancement"
```

## Auto-Labeling

### 이슈 유형별 라벨
```
bug     → bug
feature → feature, enhancement
task    → task
```

### 우선순위
```
--priority high   → priority:high
--priority medium → priority:medium
--priority low    → priority:low
```

### 컴포넌트
```
--component auth     → component:auth
--component frontend → component:frontend
--component backend  → component:backend
```

## Interactive Mode

사용자에게 필요한 정보를 질문:

1. **이슈 유형**: bug / feature / task
2. **제목**: 간단한 설명
3. **상세 내용**: 템플릿에 맞춰 입력 유도
4. **우선순위**: high / medium / low
5. **담당자**: 할당할 사람 (선택)

## Output

```markdown
## Issue Created Successfully

**Title:** [Bug] 로그인 시 500 에러 발생
**URL:** https://github.com/user/repo/issues/789
**Number:** #789

**Labels:** bug, priority:high
**Assignee:** @developer

**Next Steps:**
1. 브랜치 생성: `git checkout -b fix/#789-login-error`
2. 수정 후 PR 생성
```

## Usage

```
/issue-create                    # 대화형으로 이슈 생성
/issue-create bug                # 버그 리포트 생성
/issue-create feature            # 기능 요청 생성
/issue-create task               # 작업 항목 생성
/issue-create --title "제목"     # 제목 지정
```
