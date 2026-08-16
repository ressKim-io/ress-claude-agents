---
description: "Rule, Skill, Agent 추가/변경 사유를 기록합니다. AI 워크플로우 자체의 개선 기록."
---

# /log-meta

AI 워크플로우(rule, skill, agent, command) 추가/변경 사유를 기록하라.

## 수집할 정보

현재 대화 맥락에서 아래 정보를 추출하라. 부족한 정보는 사용자에게 질문하라.

1. **Context**: 어떤 작업 중에 개선 필요성을 느꼈는지
2. **Issue**: 반복적으로 발생한 마찰이 뭐였는지. 매번 같은 말을 해야 했던 패턴
3. **Action**: 뭘 추가/변경했는지 (rule, skill, agent, command). 구체적 내용
4. **Result**: 개선 후 변화. 재요청 횟수 감소, 자동화 효과 등
5. **Tags**: 관련 키워드 (예: rule, skill, kafka, convention)
6. **Related Files**: 추가/변경된 파일 경로

## 실행 절차

1. 위 정보를 대화 맥락에서 최대한 자동 추출한다
2. 부족한 정보가 있으면 사용자에게 간단히 질문한다
3. slug를 생성한다 (변경 대상 기반, 예: add-kafka-rule)
4. `docs/dev-logs/YYYY-MM-DD-{slug}.md` 파일을 생성한다
5. 생성된 파일 경로를 사용자에게 알려준다

## 출력 형식

```markdown
---
date: {today}
category: meta
project: {project-name or repo-name}
tags: [{tag1}, {tag2}]
---

# {제목: 변경 내용을 한 줄로}

## Context
{어떤 작업 중이었는지}

## Issue
{반복 마찰 또는 개선 필요성}

## Action
{구체적 변경 내용}
- 추가/변경된 파일과 내용
- 핵심 규칙 또는 패턴 요약

## Result
{개선 효과}

## Related Files
- path/to/file
```

오늘 날짜: $CURRENT_DATE
인자가 주어지면 해당 내용을 제목/Context로 활용하라: $ARGUMENTS
