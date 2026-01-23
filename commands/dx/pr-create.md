# Pull Request Creator

커밋 히스토리를 기반으로 PR을 자동 생성합니다.

## Instructions

1. 현재 브랜치의 커밋 히스토리를 분석합니다.
2. 변경된 파일과 커밋 메시지를 요약합니다.
3. PR 템플릿에 맞춰 제목과 본문을 생성합니다.
4. `gh pr create` 명령어로 PR을 생성합니다.

## Process

### 1. 브랜치 정보 확인
```bash
# 현재 브랜치
git branch --show-current

# 베이스 브랜치와의 차이
git log main..HEAD --oneline

# 변경된 파일
git diff main --stat
```

### 2. 커밋 분석
- feat: 새 기능 → "Add" 또는 "Implement"
- fix: 버그 수정 → "Fix"
- refactor: 리팩토링 → "Refactor"
- docs: 문서 → "Update documentation"
- test: 테스트 → "Add tests"

### 3. PR 제목 생성
```
# 패턴: [타입] 간단한 설명

# 단일 커밋
feat(auth): add login functionality
→ [Feature] Add login functionality

# 다중 커밋 (주요 변경 요약)
feat(auth): add login
feat(auth): add logout
fix(auth): fix token refresh
→ [Feature] Add authentication (login, logout, token refresh)
```

### 4. PR 본문 생성
```markdown
## Summary
{커밋 메시지 기반 1-3문장 요약}

## Changes
- {커밋 1 설명}
- {커밋 2 설명}
- {커밋 3 설명}

## Test Plan
- [ ] {테스트 항목 자동 생성}

## Related Issues
{브랜치명 또는 커밋에서 이슈 번호 추출}
Closes #123
```

## PR Creation

### gh CLI 사용
```bash
gh pr create \
  --title "[Feature] Add authentication" \
  --body "$(cat <<'EOF'
## Summary
사용자 인증 기능을 추가합니다.

## Changes
- 로그인/로그아웃 API 구현
- JWT 토큰 발급 및 검증
- 리프레시 토큰 로직 추가

## Test Plan
- [ ] 로그인 성공 테스트
- [ ] 로그인 실패 테스트 (잘못된 비밀번호)
- [ ] 토큰 만료 시 리프레시 테스트

## Related Issues
Closes #123
EOF
)" \
  --reviewer @team-backend
```

### 옵션
- `--draft`: Draft PR로 생성
- `--reviewer`: 리뷰어 지정
- `--assignee`: 담당자 지정
- `--label`: 라벨 추가

## Auto-Detection

### 이슈 번호 추출
```
# 브랜치명에서
feature/#123-login → #123

# 커밋 메시지에서
feat(auth): add login (#123) → #123
```

### 라벨 자동 추가
```
feat → feature
fix → bug
docs → documentation
refactor → refactor
test → test
```

### 리뷰어 추천
- CODEOWNERS 파일 기반
- 변경된 파일 경로에 따라 자동 추천

## Output

```markdown
## PR Created Successfully

**Title:** [Feature] Add authentication
**URL:** https://github.com/user/repo/pull/456

**Summary:**
- 3 commits
- 5 files changed
- +200 / -50 lines

**Auto-assigned:**
- Reviewers: @reviewer1, @reviewer2
- Labels: feature, backend
- Linked Issue: #123
```

## Usage

```
/pr-create                  # 현재 브랜치로 PR 생성
/pr-create --draft          # Draft PR로 생성
/pr-create --base develop   # develop 브랜치 대상
```
