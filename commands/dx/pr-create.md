# Pull Request Creator

커밋 히스토리를 기반으로 PR을 자동 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 현재 브랜치의 커밋 히스토리 |
| Output | GitHub Pull Request |
| Required Tools | git, gh |
| Verification | `gh pr view` 로 PR 확인 |

## Checklist

### Process
1. 브랜치 정보 확인
2. 커밋 분석 및 분류
3. PR 제목/본문 생성
4. `gh pr create` 실행

### Auto-Detection
- [ ] 이슈 번호: 브랜치명/커밋에서 추출 (#123)
- [ ] 라벨: 커밋 타입 기반 (feat->feature, fix->bug)
- [ ] 리뷰어: CODEOWNERS 기반

### PR Template
```markdown
## Summary
{커밋 기반 1-3문장 요약}

## Changes
- {커밋 1 설명}
- {커밋 2 설명}

## Test Plan
- [ ] {테스트 항목}

## Related Issues
Closes #123
```

## Output Format

```markdown
## PR Created

**URL:** https://github.com/user/repo/pull/456
**Title:** [Feature] Add authentication
```

## Usage

```
/pr-create              # 현재 브랜치로 PR
/pr-create --draft      # Draft PR
/pr-create --base dev   # develop 브랜치 대상
```
