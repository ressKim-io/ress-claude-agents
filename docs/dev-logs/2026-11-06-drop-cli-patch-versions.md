---
date: 2026-11-06
category: meta
tier: 2
importance: major
status: resolved
tags: [versioning, claude-code, skills, rules, verification-date]
related:
  - dev-logs/2026-11-06-aiops-agent-ops-skills.md
  - audit/2026-11-06-aiops-agent-ops-verification.md
---

# Claude Code 패치 버전 대신 검증일로 기준 시점 표기

skill·rule 본문에서 Claude Code 패치 버전(`2.1.x`)을 지우고, 기준 시점은 검증일로 남기기로 했다. 측정 기록은 그대로 둔다.

## 배경

- AIOps skill 3개를 머지한 2026-11-06 저녁에 CLI가 2.1.318에서 2.1.319로 올라갔다. skill 본문의 "CHANGELOG는 2.1.318까지 대조" 같은 문장은 릴리스가 나올 때마다 낡는다.
- ADR 0009 실측(2026-08-25, 2.1.245)과 사양 검증(2026-11-04, 2.1.318) 사이에 CHANGELOG에 오른 릴리스가 61개다. 본문에 버전 번호를 두면 이 속도로 고쳐야 한다.
- 사용자 결정(2026-11-06): 패치 버전까지 들고 가면 너무 자주 관리해야 하니 본문에 쓰지 않는다.

## 결정

| 문서 | 방침 |
|---|---|
| skill, rule, `AGENTS.md`처럼 계속 읽히는 문서 | 버전 번호를 쓰지 않는다. 본문은 검증일 시점의 최신 버전을 기준으로 쓰고, 기준 시점은 Sources의 검증일로 남긴다. 예전 동작이 여전히 위험할 때만 "이전 버전에서는"으로 적는다 |
| `docs/audit`, ADR, dev-log 같은 시점 기록 | 그대로 둔다. 측정 환경의 버전은 증거다. ADR 0009 P8과 현행 문서가 어긋났을 때도 두 버전 사이의 CHANGELOG만 좁혀 볼 수 있었다 |

검토한 대안:
- 버전 번호를 두고 릴리스마다 고친다: 위 속도로는 관리할 수 없다.
- `2.1`까지만 적는다: 2.1 계열이 계속 이어지고 있어서 아무것도 구분하지 못한다.

## 바꾼 것

- skill 3개(`agent-autonomy-tiers`, `claude-unattended-ops`, `ops-mcp-security`): "vX+", "X에서 고쳐졌다", "CLI X 실측" 표기를 날짜로 바꾸거나 지웠다.
  - 최신 버전에서 이미 고쳐진 버그 3건은 뺐다: `--print`에서 `PermissionRequest` hook이 발화하지 않던 문제, 꺼 둔 MCP 서버가 다시 연결되던 문제, cloud scheduled task가 실패로 표시되지 않던 문제.
  - `-p` 기본 모드처럼 버전에 따라 바뀐 적이 있는 값은 번호 없이 "모드는 플래그로 적는다"는 권고만 남겼다.
- `AGENTS.md`, `effort-guide.md`: "vX 부터"를 지웠다.
- SKILL-SPEC §2: 위 방침을 한 단락으로 넣었다.
- 2026-11-06에 확인한 최신 CHANGELOG는 맨 위가 2.1.318이었다. 그래서 새로 반영할 항목은 없었다.

## 앞으로

- ADR 0009 `ask` 재측정(PR-A) 기록에는 측정 환경으로 버전을 한 번 남긴다. skill 본문에는 날짜만 쓴다.
