# Release Manager

버전 태그 및 GitHub Release를 자동 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 버전 타입 (major/minor/patch) 또는 특정 버전 |
| Output | Git 태그, GitHub Release |
| Required Tools | git, gh |
| Verification | `gh release view` 로 확인 |

## Process

1. 현재 버전 확인
2. 커밋 분석으로 다음 버전 결정
3. CHANGELOG 업데이트
4. 태그 생성 및 푸시
5. GitHub Release 생성

## Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes
MINOR: New features (backwards compatible)
PATCH: Bug fixes
```

## Pre-release Checklist

- [ ] 모든 테스트 통과
- [ ] 코드 리뷰 완료
- [ ] CHANGELOG.md 업데이트
- [ ] 버전 파일 업데이트

## Release Notes Template

```markdown
## v1.1.0

### Highlights
{1-2문장 요약}

### New Features
- {기능} (#이슈)

### Bug Fixes
- {수정} (#이슈)

**Full Changelog**: compare/v1.0.0...v1.1.0
```

## Output

```markdown
## Release Created

- **Version:** v1.1.0
- **URL:** https://github.com/user/repo/releases/tag/v1.1.0

### Actions Completed
- ✅ CHANGELOG.md updated
- ✅ Git tag created
- ✅ GitHub Release created
```

## Usage

```
/release              # 자동 버전 결정
/release patch        # 패치 릴리스
/release minor        # 마이너 릴리스
/release major        # 메이저 릴리스
/release --dry-run    # 미리보기
```
