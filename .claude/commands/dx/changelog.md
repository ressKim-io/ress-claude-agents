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

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| 태그를 찾을 수 없음 | Git 태그 미존재 | `git tag -l`로 확인, 없으면 첫 번째 커밋부터 분석 |
| 커밋 분류 실패 | Conventional Commits 미준수 | `type: description` 형식으로 커밋 메시지 작성 |
| CHANGELOG 덮어쓰기 | 기존 내용 유실 | 새 버전을 파일 상단에 추가 (기존 유지) |
| 버전 추천 부정확 | breaking change 미감지 | `feat!:` 또는 `BREAKING CHANGE:` 푸터 사용 |
| 이슈 번호 링크 안됨 | PR/이슈 참조 형식 오류 | `(#123)` 형식으로 커밋에 명시 |
| 중복 엔트리 발생 | 머지 커밋 포함됨 | `--no-merges` 옵션으로 머지 커밋 제외 |
