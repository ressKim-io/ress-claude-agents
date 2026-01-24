# DX Commands

Developer Experience 향상을 위한 명령어입니다.

## 명령어

### `/dx pr-create`
Pull Request를 생성합니다.

```
/dx pr-create                       # 현재 브랜치로 PR
/dx pr-create --draft               # Draft PR
/dx pr-create --base develop        # base 브랜치 지정
```

**자동 생성:**
- 커밋 분석 기반 제목
- 변경 요약
- 테스트 체크리스트

---

### `/dx issue-create`
GitHub Issue를 생성합니다.

```
/dx issue-create                    # 대화형
/dx issue-create --bug              # 버그 템플릿
/dx issue-create --feature          # 기능 요청 템플릿
```

**템플릿 항목:**
- 설명
- 재현 단계 (버그)
- 예상 동작
- 스크린샷

---

### `/dx changelog`
CHANGELOG를 생성합니다.

```
/dx changelog                       # 마지막 태그 이후
/dx changelog v1.0.0..v1.1.0        # 범위 지정
/dx changelog --unreleased          # 미릴리스 변경사항
```

**형식:**
- [Keep a Changelog](https://keepachangelog.com) 형식
- Added, Changed, Fixed, Removed 분류

---

### `/dx release`
릴리스를 생성합니다.

```
/dx release                         # 대화형 (버전 선택)
/dx release v1.2.0                  # 특정 버전
/dx release --patch                 # 패치 버전 증가
/dx release --minor                 # 마이너 버전 증가
```

**수행 작업:**
1. 버전 태그 생성
2. CHANGELOG 업데이트
3. GitHub Release 생성
4. 릴리스 노트 자동 작성

---

## Skills (상세 지식)

| 명령어 | 내용 |
|--------|------|
| `/git-workflow` | Git 컨벤션, 브랜치 전략, 커밋 메시지 |
| `/conventional-commits` | Conventional Commits, semantic-release, 자동 버전 |

---

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
