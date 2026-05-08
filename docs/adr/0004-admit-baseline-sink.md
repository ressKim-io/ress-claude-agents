# ADR 0004 — admit warn-mode baseline sink + 메트릭 정의

- **Status**: Accepted
- **Date**: 2026-05-08
- **Driver**: Migration 0002 P6 (`docs/migration/0002-progress.md`) — kubernetes 카테고리 pilot 후 1주 baseline 수집을 위한 sink 결정 미해결
- **Phase**: P6 진입 (5/8) → P6 종결 게이트 입력
- **Supersedes**: 없음
- **Related**: ADR 0005 (Proposed) — baseline 결과 후 deny 전환 결정

## Context

P5 종료 시점에 admit subcommand는 동작하나 **결정 결과를 stderr로만 emit**한다. baseline 메트릭(activation rate / matching accuracy / false positive 비율)을 1주 수집하려면 결정 이벤트를 어딘가에 영속화해야 한다.

P0 plan §"미해결 항목" 그리고 P5 dev-log에서 sink 결정을 미뤘던 이유:
- Claude Code PreToolUse hook이 stderr 출력을 어떻게 logging하는지 불명확
- 영속 sink는 권한/rotation/사용자 프라이버시 고려가 필요
- baseline 분석 메트릭이 sink schema와 결합되어 있어 한 번에 결정해야 함

P6 변환 5개 (gateway-api / gateway-api-migration / k8s-autoscaling-advanced / k8s-scheduling-advanced / k8s-traffic-ingress) 가 base PoC와 의도적으로 매처가 overlap한다 (사용자 결정, P6 Decision Log). 이 overlap이 false positive로 이어지는지가 P6 핵심 메트릭이라, sink가 없으면 baseline 자체가 불가능.

## Considered Options

### Option A — JSONL append, 환경변수 옵트인 (Accepted)

- 환경변수 `CLAUDE_AGENTS_ADMIT_LOG=<path>` 설정 시에만 admit 결정마다 1 라인 append
- schema: `{ts, tool, path, skill, mode, decision, reason, version}`
- 디폴트 off — 명시적 활성화 없으면 stderr 동작 그대로 유지
- 분석은 jq one-liner 또는 `scripts/analyze-admit-baseline.sh`

**장점**:
- 사용자 명시 동의 후 수집 — 프라이버시 우선
- JSONL = grep / jq 분석 단순, 외부 도구 의존성 없음
- admit.ts (pure function)는 손대지 않음, side-effect는 cli layer만
- rotation 불필요 (1주 baseline + 사용자 수동 비우기)

**단점**:
- 사용자가 환경변수 안 set하면 baseline 시작도 안 됨 → P6 가이드(progress.md)에 setup 단계 명시 필요

### Option B — 디폴트 sink = `~/.claude/claude-agents-admit.jsonl`, 옵트아웃

- Claude Code 자체 영역이라 자연스러움
- 옵트아웃: `CLAUDE_AGENTS_ADMIT_LOG=off`로만 끔

**거부 이유**: ~/.claude/는 Claude Code 자체 자산 영역(settings.json 등), third-party CLI(`@ress/claude-agents`)가 디폴트로 파일 만드는 것 부적절. 사용자 결정 4 (Registry publish 미래 옵션) 정신과 일관 — 명시 동의 후 수집.

### Option C — 외부 텔레메트리 endpoint

- 중앙 집계 가능
- 거부: 외부 호출은 사용자 결정 4 정신 위반, 본 레포는 LLM-free 결정적 스케줄러 정책 (P3 plan §"의존성 정책")

### Option D — stderr만 유지, 사용자가 shell `2>>` redirect

- sink 결정 미루기
- 거부: PreToolUse hook stderr이 Claude Code 어디로 가는지 사용자가 모름. 디버깅 불가능. P6 baseline 자체가 깨짐.

## Decision (Accepted)

**Option A 채택**.

### 구현 명세

```typescript
// control-plane/src/index.ts admit handler 안
const sinkPath = process.env.CLAUDE_AGENTS_ADMIT_LOG;
if (sinkPath) {
  appendBaselineRecord(sinkPath, {
    ts: new Date().toISOString(),
    tool: parsed.tool,
    path: parsed.path ?? null,
    skill: parsed.skill ?? null,
    mode: parsed.mode,
    decision: decision.allow ? "allow" : (parsed.mode === "warn" ? "warn" : "deny"),
    reason: decision.reason,
    version: VERSION,
  });
}
```

- append 실패는 silently swallow (logging이 admit 자체를 깨뜨리면 안 됨, hook 환경에서 권한 문제 가능)
- file open mode = `a` (append-only), 디렉토리 미존재 시 mkdir -p
- write는 JSON.stringify + `\n` 단일 라인

### Schema (v1, 확정)

```json
{
  "ts": "2026-05-08T14:30:00.000Z",
  "tool": "Edit",
  "path": "charts/myapp/templates/deployment.yaml",
  "skill": "k8s-helm",
  "mode": "warn",
  "decision": "allow",
  "reason": "'charts/myapp/templates/deployment.yaml' matches applies_when.files_present",
  "version": "0.1.0"
}
```

| 필드 | 의미 | 분석 활용 |
|---|---|---|
| `ts` | ISO 8601 UTC | activation 빈도 추이 |
| `tool` | Edit/Write/NotebookEdit | mutating tool 분포 |
| `path` | 대상 파일 (root-relative) | high-traffic 파일 식별 |
| `skill` | 활성 skill name | per-skill activation rate |
| `mode` | warn / deny | baseline vs enforcement 구분 |
| `decision` | allow / warn / deny | 핵심 메트릭 |
| `reason` | admit() 반환 reason | false positive 분류 |
| `version` | control-plane 버전 | 시간축 비교 시 호환성 |

### 메트릭 정의 (P6 baseline + P7+ 운영)

P6 종결 게이트(1주 baseline) 통과 기준:

| 메트릭 | 정의 | jq 계산 | P6 → deny 전환 임계 |
|---|---|---|---|
| **Total activations** | 모든 admit 이벤트 | `wc -l $LOG` | 의미 있는 데이터 = ≥ 50 events/주 |
| **Activation rate** | mutating tool call 중 skill 매칭 비율 | `jq -r '.skill' $LOG \| grep -cv null \| awk '{print $1/N}'` | ≥ 70% (plan §검증 전략) |
| **Allow rate** | decision=allow / total | `jq -s 'map(select(.decision=="allow")) \| length / (.\|length)' $LOG` | ≥ 90% (warn으로 들어가는 이벤트 < 10%) |
| **Per-skill warn rate** | 각 skill별 warn 비율 | `jq -s 'group_by(.skill) \| map({skill:.[0].skill, warn:(map(select(.decision=="warn"))\|length)/(.\|length)})' $LOG` | 모든 skill < 15% |
| **Deny readiness** | 위 모두 통과 + 사용자 검수 | 정성 판단 | P5 결정 Q5 정합 — baseline 후 deny 전환 |

### 분석 명령 예시

```bash
# 활성화 빈도 (top 10)
jq -r '.skill' "$CLAUDE_AGENTS_ADMIT_LOG" | sort | uniq -c | sort -rn | head -10

# 시간대별 activation 추이
jq -r '.ts[0:13]' "$CLAUDE_AGENTS_ADMIT_LOG" | sort | uniq -c

# Per-skill warn 비율 (false positive 후보)
jq -s '
  group_by(.skill) | map({
    skill: .[0].skill,
    total: length,
    warn: map(select(.decision=="warn")) | length
  }) | map(. + {warn_rate: (.warn / .total)})
' "$CLAUDE_AGENTS_ADMIT_LOG"

# 매처 false positive: warn인데 path가 명백히 다른 도메인 (수동 inspection)
jq -s 'map(select(.decision=="warn")) | .[]' "$CLAUDE_AGENTS_ADMIT_LOG"
```

## Consequences

### Positive
- 1주 baseline이 수집 가능 → P6 종료 게이트의 deny 전환 결정에 정량 근거 확보
- ADR 0005(Proposed)에서 위 임계 비교만으로 결정 — 정성 판단 의존 최소
- pure function admit.ts 안 건드림 → P5 코드 안정성 유지
- 향후 P7+ 카테고리 마이그레이션마다 동일 sink로 회귀 메트릭 비교 가능

### Negative
- 환경변수 옵트인 = 사용자가 P6 setup 단계에서 명시 활성화 필요 (`progress.md` setup 섹션 추가)
- silently swallow append error = 사용자가 sink 깨진 걸 알아채려면 별도 sanity check 필요. 1주 후 line count 0이면 setup 미완료로 의심.
- jq 의존성 (분석용). 미설치 시 `brew install jq` 필요 — README에 명시.

### Mitigations
- `progress.md` P6 진입 가이드에 환경변수 setup + sanity check (`wc -l $CLAUDE_AGENTS_ADMIT_LOG > 0`) 명시
- ADR 0005에서 baseline 결과가 충분(`≥ 50 events`)인지 우선 게이트 확인 → 미달 시 baseline 기간 연장

## Validation

- vitest 신규 1건: 환경변수 set 시 line append, unset 시 no-op
- 1주 후 ADR 0005 작성 시 위 jq 명령 실제 실행 결과를 본문에 인용

## Alternatives Considered (요약)

| Option | 채택 여부 | 결정적 이유 |
|---|---|---|
| A: JSONL + 옵트인 환경변수 | **Accepted** | 프라이버시 + jq 분석 단순 + admit.ts pure 보존 |
| B: 디폴트 sink + 옵트아웃 | Rejected | ~/.claude/는 Claude Code 자산 영역 |
| C: 외부 텔레메트리 | Rejected | LLM-free / Registry-publish 미래 옵션 정신 위반 |
| D: stderr 유지 | Rejected | hook stderr 행방 불명 → 분석 불가 |

## Implementation Checklist

- [x] ADR 0004 작성 (본 문서)
- [ ] `control-plane/src/index.ts` admit handler에 sink 추가
- [ ] `control-plane/src/admit.ts` 시그니처 영향 0 (pure function 보존 검증)
- [ ] vitest: env set / unset 양쪽 케이스
- [ ] `docs/migration/0002-progress.md` P6 setup 가이드 추가
- [ ] ADR 0005 placeholder 작성 (1주 후 채움)

## Sources

- Migration 0002 plan §"미해결 항목" + P5 dev-log
- Decision Log Q5 (P0 결정): "PreToolUse hook 초기 warning 모드, baseline 후 deny 전환"
- P6 plan §54: "kubernetes 카테고리 ~10개 전체 변환 + warn 모드 baseline 1주 수집"
