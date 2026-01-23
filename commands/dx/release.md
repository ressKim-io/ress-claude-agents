# Release Manager

버전 태그 및 GitHub Release를 자동 생성합니다.

## Instructions

1. 현재 버전을 확인합니다.
2. 커밋 히스토리를 분석하여 다음 버전을 결정합니다.
3. CHANGELOG를 업데이트합니다.
4. 버전 태그를 생성하고 푸시합니다.
5. GitHub Release를 생성합니다.

## Process

### 1. 현재 버전 확인
```bash
# 최신 태그
git describe --tags --abbrev=0

# 태그가 없는 경우
# → v0.0.0에서 시작
```

### 2. 버전 결정

#### Semantic Versioning
```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes (하위 호환 안 됨)
MINOR: 새 기능 (하위 호환)
PATCH: 버그 수정
```

#### 자동 버전 추천
```bash
# 커밋 분석
git log v1.0.0..HEAD --pretty=format:"%s"

# 분석 결과
feat!: ... → MAJOR bump (1.0.0 → 2.0.0)
feat: ...  → MINOR bump (1.0.0 → 1.1.0)
fix: ...   → PATCH bump (1.0.0 → 1.0.1)
```

### 3. Pre-release Checklist

```markdown
## Release Checklist

### Code Quality
- [ ] 모든 테스트 통과
- [ ] 코드 리뷰 완료
- [ ] 린트 에러 없음

### Documentation
- [ ] CHANGELOG.md 업데이트
- [ ] README.md 업데이트 (필요시)
- [ ] API 문서 업데이트 (필요시)

### Version Files
- [ ] package.json 버전 업데이트 (Node.js)
- [ ] build.gradle 버전 업데이트 (Java)
- [ ] setup.py 버전 업데이트 (Python)

### Final Verification
- [ ] 스테이징 환경 테스트
- [ ] 성능 테스트 (해당시)
- [ ] 보안 스캔 통과
```

### 4. Release 생성

#### Git Tag
```bash
# 태그 생성
git tag -a v1.1.0 -m "Release v1.1.0"

# 태그 푸시
git push origin v1.1.0
```

#### GitHub Release
```bash
gh release create v1.1.0 \
  --title "v1.1.0" \
  --notes "$(cat <<'EOF'
## What's Changed

### New Features
- Add user authentication (#123)
- Add password reset functionality (#124)

### Bug Fixes
- Fix token refresh issue (#126)
- Fix password validation regex

### Breaking Changes
- None

**Full Changelog**: https://github.com/user/repo/compare/v1.0.0...v1.1.0
EOF
)"
```

## Release Notes Template

```markdown
## v{VERSION}

Release date: {DATE}

### Highlights
{주요 변경 사항 1-2문장 요약}

### New Features
- {새 기능 1} (#이슈번호)
- {새 기능 2} (#이슈번호)

### Improvements
- {개선 사항 1}
- {개선 사항 2}

### Bug Fixes
- {버그 수정 1} (#이슈번호)
- {버그 수정 2} (#이슈번호)

### Breaking Changes
- {Breaking change 설명}
  - Migration: {마이그레이션 방법}

### Dependencies
- Bump {dependency} from {old} to {new}

### Contributors
@contributor1, @contributor2

**Full Changelog**: https://github.com/user/repo/compare/v{PREV}...v{VERSION}
```

## Version Bump Types

### Major (x.0.0)
```bash
/release major
# v1.2.3 → v2.0.0
```

### Minor (x.y.0)
```bash
/release minor
# v1.2.3 → v1.3.0
```

### Patch (x.y.z)
```bash
/release patch
# v1.2.3 → v1.2.4
```

### Pre-release
```bash
/release prerelease --preid alpha
# v1.2.3 → v1.2.4-alpha.0

/release prerelease --preid beta
# v1.2.3 → v1.2.4-beta.0

/release prerelease --preid rc
# v1.2.3 → v1.2.4-rc.0
```

## Auto-Detection

### 버전 파일 감지
```
package.json     → Node.js
build.gradle     → Java/Kotlin
pom.xml          → Maven
setup.py         → Python
Cargo.toml       → Rust
go.mod           → Go
```

### 버전 파일 업데이트
```bash
# package.json
npm version 1.1.0 --no-git-tag-version

# build.gradle
sed -i 's/version = ".*"/version = "1.1.0"/' build.gradle
```

## Output

```markdown
## Release Created Successfully

### Version
- Previous: v1.0.0
- New: v1.1.0
- Type: Minor (new features)

### Changes
- 5 new features
- 3 improvements
- 7 bug fixes
- 0 breaking changes

### Actions Completed
- ✅ CHANGELOG.md updated
- ✅ Version files updated
- ✅ Git tag created: v1.1.0
- ✅ Tag pushed to origin
- ✅ GitHub Release created

### Links
- Release: https://github.com/user/repo/releases/tag/v1.1.0
- Changelog: https://github.com/user/repo/blob/main/CHANGELOG.md
- Compare: https://github.com/user/repo/compare/v1.0.0...v1.1.0
```

## Usage

```
/release                    # 자동 버전 결정 후 릴리스
/release patch              # 패치 버전 릴리스
/release minor              # 마이너 버전 릴리스
/release major              # 메이저 버전 릴리스
/release --dry-run          # 미리보기 (실제 릴리스 안 함)
/release --version 1.2.3    # 특정 버전으로 릴리스
```
