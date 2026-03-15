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

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `command not found: gh` | GitHub CLI 미설치 | `brew install gh` |
| `gh auth` 에러 | 인증 안됨 | `gh auth login` 실행 |
| 권한 부족 에러 | 저장소 접근 권한 없음 | 저장소 권한 확인 또는 fork에서 작업 |
| 라벨 적용 실패 | 라벨 미존재 | 저장소에 해당 라벨 먼저 생성 |
| 템플릿 적용 안됨 | `.github/ISSUE_TEMPLATE` 미설정 | 저장소에 이슈 템플릿 추가 |
| assignee 지정 실패 | 사용자명 오류 또는 권한 없음 | GitHub 사용자명 정확히 입력, collaborator 여부 확인 |
