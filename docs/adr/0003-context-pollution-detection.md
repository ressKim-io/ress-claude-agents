# ADR 0003 — Context 오염 감지 기준

- **Status**: Proposed
- **Date**: 2026-05-08
- **Driver**: deep audit (`docs/audit/2026-05-08-deep-audit.md` §5-1)

## Context

`.claude/rules/token-budget.md`에 일부 가이드가 있다:
- "Context 80% 초과 → 세션 종료"
- "2회 이상 같은 실수 교정 시 `/clear` + 재프롬프트"
- "Kitchen sink session — 무관 태스크 축적 → `/clear`"

그러나 **자동 감지 기준**은 명시되지 않았다. "2회 이상" 같은 정성적 기준은 LLM이 자체 판단해야 하는데, **오염된 context 자체가 자체 판단을 흐리게 한다** (chicken-egg).

deep audit에서 발견된 문제:
- 본 audit 세션에서 subagent #4가 install.sh dedup을 추정으로 판단 → main agent가 직접 검증해 부분 정정. 만약 main도 oversight했으면 false positive로 ship됐을 것
- 동일 에러 N회 반복 시 LLM 자가 진단은 신뢰성 낮음 (오염된 추론 사슬이 self-validating)
- session 시작부터 누적된 오염도 측정 어려움

## Decision (Proposed)

### A. 오염 신호 (자동 감지)

다음 중 **2개 이상 매칭**되면 `/clear` 권장 출력:

| 신호 | 임계값 |
|---|---|
| 동일 에러 메시지 반복 | 3회 이상 |
| 같은 파일 read | 3회 이상 (중복 읽기 = 정보 retention 실패) |
| 사용자 correction | 같은 주제 2회 이상 ("아니 그게 아니라...") |
| TODO 누적 (작업 시작 후 task list 길이) | 10개 초과 |
| Context window 사용률 | 70% 초과 (80%는 강제 종료) |
| Tool error rate | 최근 10회 중 4회 이상 |

### B. 측정 위치

- **자체 측정 한계**: LLM이 실시간 self-monitoring하기 어려움 → control-plane 또는 외부 hook이 측정 권장
- **차선책**: turn 시작 시 main agent가 task list / 최근 tool result 검토하여 신호 자가 진단
- 이상 신호 감지 시 사용자에게 "현재 context 오염 가능성 신호: X. /clear를 권장합니다" 출력

### C. /clear 권장 vs 강제

- **권장만** (Tier 1): Context 사용률 70%, correction 2회, file 중복 read 3회
- **강제 종료** (Tier 2): Context 사용률 80%, 동일 에러 5회 반복

## Consequences

### Positive
- 오염된 context로 잘못된 decision ship 방지
- 명시적 임계값 → 디버그 가능
- 사용자가 "왜 /clear 권장됐나"를 알 수 있어 신뢰 향상

### Negative / Trade-off
- false positive 가능성 (정상 작업에서 동일 파일 read는 발생 가능 — workflow 내 다중 검증)
- 임계값 적정화 필요 (초기 임계값은 추정. 6개월 사용 후 조정)
- 자가 측정의 신뢰성 한계 — control-plane 또는 외부 측정 권장

## Alternatives Considered

| 대안 | Reject 이유 |
|---|---|
| 사용자 자율 판단 | 사용자가 LLM의 오염 상태를 외부 관찰할 수단 없음. 객관 신호 필요 |
| 매 turn마다 강제 self-check | turn 비용 ↑, 작은 작업도 무거워짐. 신호 기반 trigger가 효율적 |
| Anthropic SDK의 token 사용률만 사용 | 그건 양적 측정뿐, 질적 오염(반복 에러, 잘못된 추론 사슬)은 못 잡음 |

## Implementation (별도 PR)

1. `.claude/rules/context-pollution.md` 작성 (신호 + 임계값, 50-100줄)
2. control-plane에 `monitor` 서브명령 PoC (turn별 신호 누적 측정)
3. settings.json hook으로 `monitor` 결과 표시 (Stop event 시)
4. dev-logs에 실제 오염 케이스 기록 (임계값 조정 데이터)
5. ADR 0001 (subagent)과 통합 — subagent timeout/error도 본 ADR 신호로 합산

## Review Schedule

- 6개월 후 (2026-11-08) 재검토: 임계값 적정성 + false positive 빈도
- 새 모델 출시(예: Opus 5) 후 즉시 재검토 — context 처리 동작 변경 가능성

## Related

- `.claude/rules/token-budget.md` — context 80% 종료 룰 (본 ADR이 70% 권장 기준 추가)
- ADR 0001 — Subagent 운영 (subagent timeout/error를 본 ADR 신호로 합산)
- ADR 0002 — Tool 안전 (tool error rate 본 ADR 신호 중 하나)
- `docs/audit/2026-05-08-deep-audit.md` §5-1 — 빠진 영역 식별
