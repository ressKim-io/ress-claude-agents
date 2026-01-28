# GitHub Issue Creator

템플릿 기반으로 GitHub Issue를 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 이슈 유형 및 내용 |
| Output | GitHub Issue |
| Required Tools | gh |
| Verification | `gh issue view` 로 확인 |

## Checklist

### Issue Templates

#### Bug Report
```markdown
## Bug Description
{버그 설명}

## Steps to Reproduce
1. {단계 1}
2. {단계 2}

## Expected vs Actual
- Expected: {예상 동작}
- Actual: {실제 동작}

## Environment
- OS: {운영체제}
- Version: {버전}
```

#### Feature Request
```markdown
## Feature Description
{기능 설명}

## Background
{필요한 이유}

## Acceptance Criteria
- [ ] {기준 1}
- [ ] {기준 2}
```

### Auto-Labeling

| Type | Labels |
|------|--------|
| bug | bug, priority:high |
| feature | feature, enhancement |
| task | task |

## Output Format

```markdown
## Issue Created

**URL:** https://github.com/user/repo/issues/789
**Number:** #789
**Labels:** bug, priority:high
```

## Usage

```
/issue-create            # 대화형
/issue-create bug        # 버그 리포트
/issue-create feature    # 기능 요청
```
