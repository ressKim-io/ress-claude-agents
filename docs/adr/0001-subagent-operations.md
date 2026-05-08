# ADR 0001 — Subagent 운영 룰 (fallback / timeout / parallel 결과 병합)

- **Status**: Proposed
- **Date**: 2026-05-08
- **Driver**: deep audit (`docs/audit/2026-05-08-deep-audit.md` §5-1)

## Context

`.claude/rules/token-budget.md`에 "10+ 파일 탐색은 subagent 위임" 정도 가이드만 있고, **subagent 운영 자체에 대한 룰**(언제 fallback, 언제 timeout, parallel 결과 병합 방식)은 부재.

실제 운영에서 발견된 문제:
- subagent가 stale data로 응답하면 main agent가 그대로 신뢰 → 잘못된 결정
- subagent timeout 기준 불명확 — 4개 subagent 병렬 실행 시 한 개가 stuck이면 어떻게?
- parallel subagent 결과 병합 시 **충돌하는 결론**을 어떻게 reconcile할지 정책 없음
- subagent의 추정과 직접 검증이 다를 때 (deep audit 사례: install.sh dedup 우려는 부분 과장됐음)

## Decision (Proposed)

### A. Subagent fallback 정책

- subagent가 timeout, error, 또는 명백히 불완전한 결과 반환 시 **main agent가 직접 수행**
- "subagent 결과만으로 ship 금지" 원칙 — 코드 수정 전 main agent가 핵심 발견을 **직접 grep/read로 spot-check**
- subagent 결과의 정확도는 **본문 직접 인용**이 있는지로 판단 (추정 vs 검증 구분)

### B. Timeout 가이드

- 단일 subagent 호출: **5분 이내** 응답 기대. 초과 시 cancel + fallback
- parallel fan-out: 가장 느린 agent의 timeout이 전체 turn을 잡지 않도록 비동기 처리
- subagent에 prompt에서 "under N words" 제약을 명시하여 자체 timeout 유도

### C. Parallel 결과 병합

- 충돌하는 결론은 **main agent가 직접 검증** (예: subagent A는 "버그", B는 "정상" → main이 grep으로 결정)
- 동일 영역에 다중 agent 결과가 있으면 **도메인 깊이 우월 agent 결과 우선** (commit `ecb3f6e`의 reviewer boundary 룰과 동일 원칙)
- 결과를 main agent가 재구성하여 사용자에게 보고 (raw subagent 출력 그대로 노출 X)

## Consequences

### Positive
- 잘못된 subagent 결론에 의한 회귀 감소
- timeout으로 인한 turn 묶임 방지
- 사용자 신뢰성 향상 (main agent가 책임자)

### Negative / Trade-off
- main agent가 모든 결과를 검증해야 해서 token 사용량 증가
- 단순 lookup 작업까지 spot-check가 과해질 위험 → 룰에 "검증 강도는 결정 영향도에 비례" 명시 필요

## Alternatives Considered

| 대안 | Reject 이유 |
|---|---|
| subagent 결과 무조건 신뢰 | 본 audit 진행 중 subagent가 false positive 다수 발생 (orphan 152개 추정 등). 추정과 검증 분리 필요 |
| 모든 작업을 main agent가 직접 | token 비효율 + context 오염. subagent의 fan-out 가치 포기 |
| timeout을 agent 별로 다르게 | 운영 복잡도 증가. 일관된 5분 default + 명시 override가 합리적 |

## Implementation (별도 PR)

- `.claude/rules/subagent-operations.md` 신설 (50-100줄 sweet spot, token-budget.md와 짝)
- `/subagent-operations` skill 작성 (상세 예시 + parallel fan-out 패턴)
- AGENTS.md 본 파일 §"Tool-Specific Optimization"에 한 줄 추가

## Review Schedule

- 6개월 후 (2026-11-08) 재검토: 실제 운영 데이터(timeout 발생 빈도, fallback 호출 빈도) 기반 정책 조정
- subagent 사용 패턴 변경(예: Anthropic SDK 변경) 시 즉시 재검토

## Related

- `.claude/rules/token-budget.md` — subagent context 절약 원칙 (본 ADR과 짝)
- `docs/audit/2026-05-08-deep-audit.md` §5-1 — 빠진 영역 식별
- ADR 0003 — Context 오염 감지 (subagent 호출 빈도 N회 초과 시 트리거)
