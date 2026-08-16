---
description: "기술/아키텍처 의사결정을 기록합니다. A vs B 선택, 트레이드오프, 근거 등."
---

# /log-decision

기술 또는 아키텍처 의사결정 내용을 기록하라.

## 수집할 정보

현재 대화 맥락에서 아래 정보를 추출하라. 부족한 정보는 사용자에게 질문하라.

1. **Context**: 어떤 상황에서 결정이 필요했는지
2. **Issue**: 어떤 선택지들이 있었는지 (AI 제안 vs 사용자 선택 포함)
3. **Action**: 최종 선택과 그 근거. 트레이드오프 분석
4. **Result**: 선택의 결과. 이후 영향, 제약 사항
5. **Tags**: 관련 기술 키워드
6. **Related Files**: 결정이 반영된 파일 경로

## 실행 절차

1. 위 정보를 대화 맥락에서 최대한 자동 추출한다
2. 부족한 정보가 있으면 사용자에게 간단히 질문한다
3. slug를 생성한다 (결정 주제 기반)
4. `docs/dev-logs/YYYY-MM-DD-{slug}.md` 파일을 생성한다
5. 생성된 파일 경로를 사용자에게 알려준다

## 출력 형식

```markdown
---
date: {today}
category: decision
project: {project-name or repo-name}
tags: [{tag1}, {tag2}]
---

# {제목: 결정 내용을 한 줄로}

## Context
{결정이 필요했던 배경}

## Issue
{선택지들과 각각의 장단점}

### Option A: {이름}
- 장점: ...
- 단점: ...

### Option B: {이름}
- 장점: ...
- 단점: ...

## Action
{최종 선택: Option X}
{선택 근거}

## Result
{결정 후 영향과 후속 작업}

## Related Files
- path/to/file
```

오늘 날짜: $CURRENT_DATE
인자가 주어지면 해당 내용을 제목/Context로 활용하라: $ARGUMENTS
