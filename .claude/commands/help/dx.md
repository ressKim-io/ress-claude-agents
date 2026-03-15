# DX Commands

Developer Experience 향상을 위한 명령어입니다.

## 명령어

| 명령어 | 설명 |
|--------|------|
| `/dx pr-create` | PR 생성 |
| `/dx issue-create` | Issue 생성 |
| `/dx changelog` | CHANGELOG 생성 |
| `/dx release` | 릴리스 생성 |

## 관련 Skills

| Skill | 내용 |
|-------|------|
| `/git-workflow` | Git 컨벤션, 브랜치 전략 |
| `/conventional-commits` | Conventional Commits, 자동 버전 |

## Quick Reference

```bash
# PR
gh pr create --title "feat: ..." --body "..."
gh pr list
gh pr view 123

# Issue
gh issue create --title "..." --body "..."
gh issue list

# Release
gh release create v1.0.0 --notes "..."
```
