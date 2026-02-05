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

## Token Efficiency Rules
- 파일 줄 수 확인은 `wc -l` 사용 (전체 Read 금지)
- Agent 위임 전 대상 파일 미리 읽지 않기 (경로만 전달)
- Write 후 검증은 `wc -l` + `head`/`tail` (전체 Read-back 금지)
- 동일 파일 2회 이상 읽기 금지 (1회 Read + Edit 패턴 사용)
- Write→Read→Rewrite 반복 루프 금지 (한 번에 올바르게 작성)
- WebSearch는 타겟 3-4회 이내 (광범위 7-10회 금지)
- 독립적인 Agent 작업은 병렬 실행 (순차 실행 금지)
- Skill 참조: `/token-efficiency`

## Repository Structure
- 저장소 전체 구조는 `.claude/inventory.yml` 참조 (모든 스킬/에이전트 목록 + 줄 수)

## Skills Reference
- `/git-workflow` - Git conventions and patterns

## DX Commands
- `/pr-create` - Create PR from commits
- `/issue-create` - Create GitHub Issue
- `/changelog` - Generate CHANGELOG
- `/release` - Create release with tag

---
*Project-specific settings in project CLAUDE.md*
