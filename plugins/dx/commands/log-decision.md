---
description: "기술/아키텍처 의사결정을 기록합니다. A vs B 선택, 트레이드오프, 근거 등."
---

# /dx:log-decision

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
category: decision   # 환경·버전·아키텍처 전환 완료를 기록하면 migration
tier: {1|2}
importance: {critical|major|minor}
status: {open|resolved}
tags: [{tag1}, {tag2}]
related: []
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

## frontmatter 값

[`devlog-lifecycle`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/devlog-lifecycle.md) 표준을 따른다.

- `status`: 끝난 일이면 `resolved`, 진행 중이면 `open`
- `tier`: `open` 이면 `1`, `resolved` 면 `2`. 이후 재산출은 `/dx:consolidate-devlogs` 가 한다
- `importance`: 직접 판단한다. `critical` 프로덕션 장애·핵심 결정 / `major` 재발 가능한 패턴·교훈 / `minor` 단순 작업 기록
- `related`: 관련 dev-log·ADR 경로. 없으면 `[]`

## 사용법

```
/dx:log-decision                         # 현재 대화의 결정 내용 자동 추출
/dx:log-decision Kafka vs RabbitMQ       # 결정 주제 전달
```

ADR 수준의 큰 결정은 `docs/adr/` 로, 그보다 가벼운 결정은 본 명령으로 기록한다.
산출물: `docs/dev-logs/YYYY-MM-DD-{slug}.md` (`category: decision`, 전환 완료 기록이면 `migration`).

오늘 날짜: $CURRENT_DATE
인자가 주어지면 해당 내용을 제목/Context로 활용하라: $ARGUMENTS
