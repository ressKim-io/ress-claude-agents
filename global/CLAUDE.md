# Global Claude Code Settings

## Language
- Response: 한국어
- Code comments: English
- Commit messages: English

## CRITICAL Rules

1. **No Secrets in Code** - Verify: `grep -r "password\|secret\|api_key" .`
   - Use environment variables or secret managers
   - Never commit .env files

2. **PR Size Limit** - Max 400 lines changed
   - Split large features into multiple PRs

3. **Test Coverage** - Minimum 80%
   - All new features must include tests

## Git Conventions

### Commit Format
```
<type>(<scope>): <subject>
```
Types: feat, fix, docs, style, refactor, test, chore

### Branch Naming
```
feature/#123-description
fix/#456-description
```

## Common Mistakes

| Mistake | Correct | Why |
|---------|---------|-----|
| `git add .` blindly | Review changes first | Avoid secrets |
| Large PRs (1000+ lines) | Split into smaller PRs | Review quality |
| No issue reference | Link to issue | Traceability |
| Vague commit messages | Descriptive messages | History clarity |

## Session Context Auto-Management

### 자동 생성 조건
다음 상황에서 `.claude/session-context.md` 자동 생성:
- TodoWrite로 3개 이상 태스크 생성 시
- 특정 MCP 서버나 테스트 환경 설정이 언급될 때
- 멀티스텝 복잡한 작업 시작 시
- 사용자가 "이거 기억해", "설정 저장해" 등 요청 시

### 파일 내용
```markdown
# Session Context (auto-generated)
## 현재 작업
## 환경 설정
## 진행 상황
## 중요 결정사항
```

### 자동 업데이트
- 새로운 설정/환경 정보가 나올 때마다 업데이트
- 중요한 결정사항 발생 시 기록
- auto compact 후 이 파일 먼저 읽기

### 자동 삭제 조건
- 모든 TodoWrite 태스크 완료 시
- 사용자가 "작업 끝", "완료" 등 명시적 종료 시
- `/session end` 명령 시

### 수동 명령
- `/session save` - 현재 상태 강제 저장
- `/session end` - 세션 종료 및 정리

## Skills Reference
- `/git-workflow` - Git conventions and patterns

## DX Commands
- `/pr-create` - Create PR from commits
- `/issue-create` - Create GitHub Issue
- `/changelog` - Generate CHANGELOG
- `/release` - Create release with tag

---
*Project-specific settings in project CLAUDE.md*
