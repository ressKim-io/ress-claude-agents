# Changelog Generator

커밋 히스토리를 기반으로 CHANGELOG를 자동 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 마지막 태그 이후의 커밋 히스토리 |
| Output | CHANGELOG.md 파일 업데이트 |
| Required Tools | git |
| Verification | CHANGELOG.md 내용 확인 |

## Checklist

### Process
1. 마지막 태그 이후 커밋 수집
2. Conventional Commits로 분류
3. Keep a Changelog 형식으로 생성

### Commit Classification

| Type | Category |
|------|----------|
| feat | Added |
| fix | Fixed |
| refactor, perf | Changed |
| deprecate | Deprecated |
| remove | Removed |
| security | Security |

### Version Suggestion

| Commits | Version |
|---------|---------|
| feat!: (breaking) | MAJOR |
| feat: | MINOR |
| fix: only | PATCH |

## Output Format

```markdown
## [1.1.0] - 2025-01-23

### Added
- Add user authentication (#123)

### Fixed
- Fix token refresh issue (#126)
```

## Usage

```
/changelog                 # 생성/업데이트
/changelog --version 1.2.0 # 특정 버전
/changelog --dry-run       # 미리보기
```
