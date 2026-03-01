---
date: 2026-03-01
category: meta
project: ress-claude-agents
tags: [agent, command, dev-logger, workflow, documentation]
---

# dev-logger 에이전트 및 /log-* 커맨드 추가

## Context
Claude Code와 협업하면서 개발 과정을 체계적으로 기록할 방법이 필요했다.
AI 수정 요청, 아키텍처 결정, 트러블슈팅 과정 등을 기록해두면 나중에 블로그 글로 변환하거나 포트폴리오로 활용할 수 있다.
Claude 웹에서 설계 방향을 정리한 뒤, Claude Code에서 구현했다.

## Issue
- AI가 생성한 코드를 수정 요청한 이력이 대화 세션이 끝나면 사라짐
- 아키텍처 결정의 근거(왜 A 대신 B를 선택했는지)가 기록되지 않음
- rule/skill 추가 사유가 커밋 메시지에만 남아 맥락 파악이 어려움
- 트러블슈팅 과정(가설 → 검증 → 근본 원인)이 휘발됨

## Action
Agent 1개 + Command 5개를 추가했다.

- `dev-logger` 에이전트: Context → Issue → Action → Result 구조로 기록을 생성하는 전문 에이전트
- `/log-feedback`: AI 출력 수정 요청 기록 (패턴 불일치, 누락, 잘못된 접근)
- `/log-decision`: 기술/아키텍처 의사결정 기록 (선택지, 트레이드오프, 근거)
- `/log-meta`: Rule/Skill/Agent 추가/변경 사유 기록 (이 로그가 그 예시)
- `/log-trouble`: 트러블슈팅 과정 기록 (에러, 진단, 근본 원인, 수정)
- `/log-summary`: 세션 활동 자동 요약

로그 저장 구조:
```
docs/dev-logs/
├── YYYY-MM-DD-{slug}.md          # 개별 기록
└── sessions/
    └── YYYY-MM-DD-session.md     # 세션 요약
```

README도 함께 업데이트했다 (Agents 26→27, Commands 35→40, Lines 66K→67K).

## Result
- 개발 과정 기록을 `/log-*` 커맨드 한 줄로 즉시 생성 가능
- 대화 맥락에서 정보를 자동 추출하므로 기록 마찰 최소화
- 기록이 git에 커밋되어 영구 보존 + GitHub에서 열람 가능
- 블로그 변환에 적합한 구조화된 마크다운 형식

## Related Files
- .claude/agents/dev-logger.md
- .claude/commands/log-feedback.md
- .claude/commands/log-decision.md
- .claude/commands/log-meta.md
- .claude/commands/log-trouble.md
- .claude/commands/log-summary.md
- docs/dev-logs/ (신규 디렉토리)
- README.md (업데이트)
