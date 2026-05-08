# ADR 0005 — admit warn → deny 전환 결정 (placeholder)

- **Status**: Proposed (1주 baseline 수집 후 채움)
- **Date**: 2026-05-08 (placeholder 작성), TBD (실제 결정)
- **Driver**: Migration 0002 P6 종료 게이트 — baseline 결과 기반 deny 전환 가부 판단
- **Phase**: P6 종결 전제 / P7 진입 전제
- **Depends on**: ADR 0004 (sink + 메트릭 정의)
- **Related**: P5 결정 Q5 (P0 Decision Log) — "warn 후 deny 전환"

## Context (placeholder)

ADR 0004에서 정의한 sink로 1주(`{시작일} ~ {종료일}`) baseline 수집. 본 ADR은 그 결과를 검토 후 다음 셋 중 하나를 결정한다:

1. **deny 전환** — false positive 임계 통과
2. **warn 유지 + 매처 튜닝** — 임계 미통과, applies_when 정밀화 후 재baseline
3. **warn 유지 영구** — admit 자체가 신호 약하면 deny 도입 보류, P7+에서 재검토

## Baseline Data (1주 수집 후 채움)

| 메트릭 | 임계 (ADR 0004) | 실측 | 통과 |
|---|---|---|---|
| Total activations | ≥ 50 | TBD | TBD |
| Activation rate | ≥ 70% | TBD | TBD |
| Allow rate | ≥ 90% | TBD | TBD |
| Per-skill warn rate (max) | < 15% | TBD | TBD |

수집 명령:
```bash
export CLAUDE_AGENTS_ADMIT_LOG=~/.claude-agents-admit.jsonl
# 1주 후
jq -s 'map(select(.decision)) | length' "$CLAUDE_AGENTS_ADMIT_LOG"  # total
jq -s 'group_by(.skill) | map({skill:.[0].skill, total:length, warn:(map(select(.decision=="warn"))|length)})' "$CLAUDE_AGENTS_ADMIT_LOG"
```

## Per-Skill Warn 분석 (P6 변환 5개에 특히 주목)

P6에서 base ↔ advanced 매처 overlap을 의도적으로 인정 (Decision Log P6-1). 다음 페어가 동시 활성화되었는지 확인:

| Pair | 동시 활성 | 의도 |
|---|---|---|
| k8s-autoscaling ↔ k8s-autoscaling-advanced | Karpenter NodePool에서 둘 다 매칭? | 둘 다 의도 — Claude가 description에서 advanced 우선 선택해야 |
| k8s-traffic ↔ k8s-traffic-ingress | Ingress + Gateway 동시 = 마이그레이션 | gateway-api-migration이 이상적, 둘만 매칭이면 false positive |
| gateway-api ↔ gateway-api-migration | Ingress + Gateway 모두 있을 때 | 마이그레이션 컨텍스트는 둘 다 매칭 정상 |
| k8s-scheduling ↔ k8s-scheduling-advanced | topologySpread 사용 시 둘 다 | 매처 차별화 약함 — 1주 후 통합 재고려 |

## Decision (TBD)

### Option A — deny 전환

조건:
- 위 임계 모두 통과
- per-skill warn 분석에서 의도된 overlap 외 false positive 없음
- 사용자 검수 OK

작업:
- `init.ts` hookMode 디폴트 `'warn'` → `'deny'`
- `progress.md` P6 → completed, P7 → next
- 회귀 테스트: 기존 fixture에서 deny 모드도 통과

### Option B — warn 유지 + 매처 튜닝

조건:
- per-skill warn rate ≥ 15% 1개 이상 skill
- false positive가 매처 광범위함 때문 (description으로 차별 못함)

작업:
- 해당 skill의 applies_when 정밀화 (files_present narrow / files_contain regex 보강 / exclude_when 추가)
- baseline 추가 1주 재수집 → ADR 0005 수정 (Decision 갱신)

### Option C — warn 영구 유지

조건:
- baseline 데이터가 충분한데 (`≥ 50`) deny가 의미 있는 게 1건도 없음
- admit 신호가 사용자 행동에 영향 없음

작업:
- ADR 0005 Status: Accepted (Option C)
- P7+ 카테고리 마이그레이션은 진행하되 admit hook은 정보성으로만
- 차후 더 정밀한 enforcement 메커니즘 ADR 별도

## Validation (1주 후)

- baseline JSONL 라인 수 ≥ 50
- jq 분석 결과 본문 인용 (실측치)
- 사용자 정성 검수 ("매처가 합리적인가")

## Sources

- ADR 0004 (sink + 메트릭 정의)
- Migration 0002 P6 plan §54
- P0 Decision Q5 (warn 후 deny)
