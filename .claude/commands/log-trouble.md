---
description: "트러블슈팅 과정을 기록합니다. 에러 원인 분석, 해결 과정, 회귀 테스트."
---

# /log-trouble

트러블슈팅(버그 수정, 에러 해결) 과정을 기록하라.

## 수집할 정보

현재 대화 맥락에서 아래 정보를 추출하라. 부족한 정보는 사용자에게 질문하라.

1. **Context**: 어떤 환경/작업에서 문제가 발생했는지
2. **Issue**: 에러 메시지, 증상, 스택트레이스. 재현 조건
3. **Action**: 진단 과정 (가설 → 검증 사이클). 근본 원인(root cause). 적용한 수정
4. **Result**: 수정 후 결과. 회귀 테스트 추가 여부. 동일 이슈 재발 방지책
5. **Tags**: 관련 기술 키워드 (예: nullpointer, timeout, race-condition)
6. **Related Files**: 수정된 파일 경로

## 실행 절차

1. 위 정보를 대화 맥락에서 최대한 자동 추출한다
2. 부족한 정보가 있으면 사용자에게 간단히 질문한다
3. slug를 생성한다 (에러/문제 키워드 기반)
4. `docs/dev-logs/YYYY-MM-DD-{slug}.md` 파일을 생성한다
5. 생성된 파일 경로를 사용자에게 알려준다

## 출력 형식

```markdown
---
date: {today}
category: troubleshoot
project: {project-name or repo-name}
tags: [{tag1}, {tag2}]
---

# {제목: 문제와 해결을 한 줄로}

## Context
{환경, 작업 배경}

## Issue
{에러 메시지 또는 증상}

```
{stack trace or error log if available}
```

{재현 조건}

## Action
{진단 과정}
1. 가설 1: ... → 결과: ...
2. 가설 2: ... → 결과: ...

{근본 원인 (Root Cause)}

{적용한 수정}
- 수정 1
- 수정 2

## Result
{수정 후 검증 결과}
{회귀 테스트 추가 여부}
{재발 방지책}

## Related Files
- path/to/file
```

오늘 날짜: $CURRENT_DATE
인자가 주어지면 해당 내용을 제목/Context로 활용하라: $ARGUMENTS
