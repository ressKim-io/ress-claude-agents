# Changelog Generator

커밋 히스토리를 기반으로 CHANGELOG를 자동 생성합니다.

## Instructions

1. 마지막 릴리스 태그 이후의 커밋을 분석합니다.
2. Conventional Commits 형식으로 분류합니다.
3. Keep a Changelog 형식으로 CHANGELOG.md를 생성/업데이트합니다.

## Process

### 1. 커밋 히스토리 수집
```bash
# 마지막 태그 찾기
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# 마지막 태그 이후 커밋
if [ -n "$LAST_TAG" ]; then
  git log ${LAST_TAG}..HEAD --pretty=format:"%s"
else
  git log --pretty=format:"%s"
fi
```

### 2. 커밋 분류

#### Added (새 기능)
```
feat: ...
feat(scope): ...
```

#### Changed (변경)
```
refactor: ...
perf: ...
style: ...
```

#### Fixed (버그 수정)
```
fix: ...
fix(scope): ...
```

#### Deprecated (지원 종료 예정)
```
deprecate: ...
```

#### Removed (제거)
```
remove: ...
```

#### Security (보안)
```
security: ...
```

### 3. CHANGELOG 형식

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Add user authentication (#123)
- Add password reset functionality (#124)

### Changed
- Improve login page performance (#125)
- Update error messages for better clarity

### Fixed
- Fix token refresh issue (#126)
- Fix password validation regex

## [1.2.0] - 2025-01-15

### Added
- Add social login support
- Add remember me option

### Fixed
- Fix session timeout handling

## [1.1.0] - 2025-01-01
...
```

## Commit Message Parsing

### 기본 형식
```
<type>(<scope>): <description>

[body]

[footer]
```

### 파싱 예시
```
Input:  feat(auth): add login functionality (#123)
Output: 
  - Type: Added
  - Description: Add login functionality (#123)
  - Issue: #123

Input:  fix: resolve memory leak in cache module
Output:
  - Type: Fixed
  - Description: Resolve memory leak in cache module
```

### Breaking Changes
```
Input:  feat!: change API response format
        
        BREAKING CHANGE: response.data is now response.result

Output:
  - Type: Changed (with ⚠️ BREAKING)
  - Description: Change API response format
  - Note: response.data is now response.result
```

## Version Suggestion

### 커밋 분석 기반 버전 추천
```
# Breaking change 있음 → MAJOR
feat!: ... → 1.0.0 → 2.0.0

# 새 기능만 → MINOR  
feat: ... → 1.0.0 → 1.1.0

# 버그 수정만 → PATCH
fix: ... → 1.0.0 → 1.0.1
```

## CHANGELOG Update

### 신규 생성
```markdown
# Changelog

## [Unreleased]

### Added
- Initial release
- Add core functionality
```

### 기존 파일 업데이트
```markdown
# Before
## [Unreleased]
(empty or existing items)

## [1.0.0] - 2025-01-01

# After
## [Unreleased]

## [1.1.0] - 2025-01-23

### Added
- New feature 1
- New feature 2

### Fixed
- Bug fix 1

## [1.0.0] - 2025-01-01
```

## Output

```markdown
## Changelog Generated

### Summary
- Period: v1.0.0 (2025-01-01) → Current
- Total commits: 15
- Suggested version: 1.1.0

### Categories
- Added: 5 items
- Changed: 3 items
- Fixed: 7 items

### Preview

## [1.1.0] - 2025-01-23

### Added
- Add user authentication (#123)
- Add password reset functionality (#124)
- Add social login support (#125)
- Add remember me option (#126)
- Add two-factor authentication (#127)

### Changed
- Improve login page performance (#128)
- Update error messages for better clarity
- Refactor authentication module

### Fixed
- Fix token refresh issue (#129)
- Fix password validation regex
- Fix session timeout handling
- Fix CORS configuration
- Fix rate limiting logic
- Fix email verification flow
- Fix logout redirect

---
CHANGELOG.md updated successfully.
```

## Usage

```
/changelog                      # CHANGELOG 생성/업데이트
/changelog --version 1.2.0      # 특정 버전으로 생성
/changelog --dry-run            # 미리보기만 (파일 수정 안 함)
/changelog --since v1.0.0       # 특정 태그 이후부터
```
