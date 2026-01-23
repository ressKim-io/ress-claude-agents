# Global Claude Code Settings

이 설정은 모든 프로젝트에 공통으로 적용됩니다.

## Language

- 기본 응답 언어: 한국어
- 코드 주석: 영어 (국제 협업 기준)
- 커밋 메시지: 영어

## Code Style

### General
- 명확하고 읽기 쉬운 코드 우선
- 과도한 추상화 지양
- 필요한 경우에만 주석 작성

### Naming
- 변수/함수: 의미를 명확히 전달
- 약어 최소화 (일반적으로 통용되는 것 제외)

## Git Conventions

### Commit Message Format
```
<type>(<scope>): <subject>

<body>
```

Types: feat, fix, docs, style, refactor, test, chore

### Branch Naming
- feature/: 새 기능
- fix/: 버그 수정
- refactor/: 리팩토링
- docs/: 문서 작업

## Security

- 민감 정보(API 키, 비밀번호 등)는 절대 코드에 하드코딩 금지
- 환경변수 또는 시크릿 매니저 사용
- .env 파일은 .gitignore에 포함

## Documentation

- 새로운 기능/API는 사용법 문서화
- 복잡한 비즈니스 로직은 주석으로 의도 설명
- README는 프로젝트 시작에 필요한 정보 포함

---

# Developer Experience (DX)

개발 워크플로우 자동화 및 생산성 향상을 위한 설정입니다.

## Issue Tracking

GitHub Issues 사용 기준:

### Issue 템플릿
- **Bug Report**: 버그 리포트 (재현 단계, 예상 동작, 실제 동작)
- **Feature Request**: 기능 요청 (배경, 제안 솔루션)
- **Task**: 일반 작업 항목

### Issue 라벨
```
bug          - 버그
feature      - 새 기능
enhancement  - 기존 기능 개선
documentation- 문서
priority:high- 높은 우선순위
priority:low - 낮은 우선순위
good first issue - 입문자용
```

### Issue 연결
- 커밋 메시지에 `#이슈번호` 포함
- PR 본문에 `Closes #이슈번호` 또는 `Fixes #이슈번호`

## Pull Request

### PR 생성 규칙
- **IMPORTANT:** PR 크기는 400줄 이하 권장
- 하나의 PR = 하나의 논리적 변경
- Draft PR로 시작하여 WIP 공유 가능

### PR 템플릿
```markdown
## Summary
변경 사항 요약 (1-3문장)

## Changes
- 변경 1
- 변경 2

## Test Plan
- [ ] 테스트 항목 1
- [ ] 테스트 항목 2

## Related Issues
Closes #123
```

### 리뷰어 자동 할당
- CODEOWNERS 파일로 자동 리뷰어 할당
- 최소 1명 승인 필수

### PR 체크리스트
- [ ] 테스트 통과
- [ ] 코드 스타일 준수
- [ ] 문서 업데이트 (필요시)
- [ ] Breaking change 없음 (또는 명시)

## Automation

### GitHub Actions 워크플로우

#### CI (Pull Request)
```yaml
name: CI
on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          # 프로젝트별 테스트 명령어
```

#### CD (Release)
```yaml
name: Release
on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true
```

### 자동화 대상
- PR 생성 시 라벨 자동 추가
- 리뷰어 자동 할당 (CODEOWNERS)
- 머지 후 브랜치 자동 삭제
- 릴리스 노트 자동 생성

## Release Management

### 버전 규칙 (Semantic Versioning)
```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes
MINOR: 새 기능 (하위 호환)
PATCH: 버그 수정
```

### 릴리스 프로세스
1. 버전 태그 생성: `git tag v1.2.3`
2. 태그 푸시: `git push origin v1.2.3`
3. GitHub Actions가 자동으로 릴리스 생성
4. CHANGELOG 자동 업데이트

### CHANGELOG 형식
```markdown
## [1.2.3] - 2025-01-23

### Added
- 새 기능 설명

### Changed
- 변경된 기능 설명

### Fixed
- 수정된 버그 설명

### Removed
- 제거된 기능 설명
```

## Productivity Tips

### 효율적인 개발 흐름
1. Issue 생성/할당
2. 브랜치 생성 (`feature/#123-기능명`)
3. 작은 단위로 커밋
4. PR 생성 및 리뷰 요청
5. 리뷰 반영 및 머지
6. Issue 자동 닫힘

### 컨텍스트 스위칭 최소화
- 관련 Issue, PR, 코드를 한 화면에서 확인
- GitHub CLI (`gh`) 활용으로 터미널에서 작업
- 알림 설정 최적화

## DX Commands

다음 명령어 사용 가능:
- `/pr-create` - 커밋 기반 PR 자동 생성
- `/issue-create` - GitHub Issue 템플릿 기반 생성
- `/changelog` - 커밋 기반 CHANGELOG 자동 생성
- `/release` - 버전 태그 및 릴리스 노트 생성

---

*프로젝트별 상세 규칙은 각 프로젝트 루트의 CLAUDE.md에서 정의*
