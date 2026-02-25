---
description: "현재 세션의 주요 활동을 자동 요약합니다. 세션 종료 전에 실행 권장."
---

# /log-summary

현재 세션에서 수행한 주요 활동을 요약하여 기록하라.

## 수집할 정보

현재 대화 전체 맥락을 스캔하여 아래를 추출한다:

1. **Activities**: 수행한 주요 작업 목록 (카테고리별 분류)
   - `[feedback]` AI 수정 요청
   - `[decision]` 기술/아키텍처 결정
   - `[meta]` rule/skill/agent 추가/변경
   - `[troubleshoot]` 에러 해결
   - `[implement]` 기능 구현
   - `[refactor]` 리팩토링
2. **Key Changes**: 주요 변경 파일과 변경 내용
3. **Logs Created**: 이 세션에서 `/log-*` 커맨드로 생성한 로그 목록
4. **Notes**: 추가 관찰, 후속 작업 항목

## 실행 절차

1. 대화 맥락 전체를 스캔한다
2. 카테고리별로 활동을 분류한다
3. `git diff --stat`으로 실제 변경된 파일을 확인한다
4. `docs/dev-logs/sessions/YYYY-MM-DD-session.md` 파일을 생성한다
   - 같은 날 이미 세션 파일이 있으면 `-2`, `-3` 등 suffix를 붙인다
5. 생성된 파일 경로를 사용자에게 알려준다

## 출력 형식

```markdown
---
date: {today}
type: session-summary
---

# Session Summary — {today}

## Activities
- [{category}] {brief description}
- [{category}] {brief description}
- [{category}] {brief description}

## Key Changes
- path/to/file1 — {what changed}
- path/to/file2 — {what changed}

## Logs Created
- [{log title}](../YYYY-MM-DD-slug.md)

## Notes
{추가 관찰, 미완료 작업, 후속 할 일}
```

## 참고

- 세션 요약은 간결하게 작성한다 (bullet point 위주)
- 활동이 없는 카테고리는 생략한다
- git diff 결과가 없으면 Key Changes 섹션을 "변경 없음"으로 표시한다

오늘 날짜: $CURRENT_DATE
