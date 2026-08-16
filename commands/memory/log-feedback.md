---
description: "AI 출력 수정 요청을 기록합니다. 코드 패턴 불일치, 누락, 잘못된 접근 등을 기록."
---

# /log-feedback

개발 과정에서 AI의 출력을 수정 요청한 내용을 기록하라.

## 수집할 정보

현재 대화 맥락에서 아래 정보를 추출하라. 부족한 정보는 사용자에게 질문하라.

1. **Context**: 어떤 작업을 하고 있었는지
2. **Issue**: AI가 처음에 뭘 잘못 생성했는지 (패턴 불일치, 기능 누락, 잘못된 접근)
3. **Action**: 사용자가 어떤 수정을 요청했는지, 실제로 뭘 바꿨는지
4. **Result**: 수정 후 결과. rule/skill 추가로 이어졌으면 그것도 기록
5. **Tags**: 관련 기술 키워드 (예: kafka, consumer-pattern, dead-letter)
6. **Related Files**: 변경된 파일 경로

## 실행 절차

1. 위 정보를 대화 맥락에서 최대한 자동 추출한다
2. 부족한 정보가 있으면 사용자에게 간단히 질문한다
3. slug를 생성한다 (핵심 키워드 기반, lowercase, hyphen 구분)
4. `docs/dev-logs/YYYY-MM-DD-{slug}.md` 파일을 생성한다
5. 생성된 파일 경로를 사용자에게 알려준다

## 출력 형식

```markdown
---
date: {today}
category: feedback
project: {project-name or repo-name}
tags: [{tag1}, {tag2}]
---

# {제목: 수정 요청 내용을 한 줄로}

## Context
{배경 설명}

## Issue
{AI가 뭘 잘못했는지}

## Action
{어떻게 수정했는지}
- 변경 1
- 변경 2

## Result
{결과와 후속 영향}

## Related Files
- path/to/file
```

오늘 날짜: $CURRENT_DATE
인자가 주어지면 해당 내용을 제목/Context로 활용하라: $ARGUMENTS
