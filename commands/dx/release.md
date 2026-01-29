# Release Manager

버전 태그 및 GitHub Release를 자동 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 버전 타입 (major/minor/patch) 또는 특정 버전 |
| Output | Git 태그, GitHub Release |
| Required Tools | git, gh |
| Verification | `gh release view` 로 확인 |

## Checklist

### Process
1. 현재 버전 확인
2. 커밋 분석으로 다음 버전 결정
3. CHANGELOG 업데이트
4. 태그 생성 및 푸시
5. GitHub Release 생성

### Semantic Versioning
```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes
MINOR: New features (backwards compatible)
PATCH: Bug fixes
```

### Pre-release Checklist
- [ ] 모든 테스트 통과
- [ ] 코드 리뷰 완료
- [ ] CHANGELOG.md 업데이트
- [ ] 버전 파일 업데이트

### Release Notes Template
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

## Output Format

```markdown
## Release Created

- **Version:** v1.1.0
- **URL:** https://github.com/user/repo/releases/tag/v1.1.0

### Actions Completed
- CHANGELOG.md updated
- Git tag created
- GitHub Release created
```

## Usage

```
/release              # 자동 버전 결정
/release patch        # 패치 릴리스
/release minor        # 마이너 릴리스
/release major        # 메이저 릴리스
/release --dry-run    # 미리보기
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| 태그 push 실패 | 태그 보호 규칙 | GitHub 저장소 설정에서 태그 보호 확인 |
| 이전 버전 찾을 수 없음 | 태그 형식 불일치 | `v1.0.0` 형식으로 통일 (v prefix) |
| release 생성 권한 없음 | GitHub 권한 부족 | 저장소 maintainer 권한 필요 |
| CHANGELOG 업데이트 충돌 | 동시 수정 발생 | main 브랜치 pull 후 재시도 |
| 버전 파일 업데이트 누락 | package.json 등 미수정 | 버전 파일 목록 설정 확인 |
| pre-release 플래그 누락 | alpha/beta 버전 인식 안됨 | `--prerelease` 플래그 명시 |
