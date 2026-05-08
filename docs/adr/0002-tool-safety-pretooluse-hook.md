# ADR 0002 — Tool 안전 룰 (PreToolUse hook 기반)

- **Status**: Proposed
- **Date**: 2026-05-08
- **Driver**: deep audit (`docs/audit/2026-05-08-deep-audit.md` §5-1) + Migration 0002 control-plane PoC

## Context

Migration 0002 P3에서 control-plane의 `admit` 서브명령(PreToolUse 훅)이 도입됨 (commit `2b26852`). 그러나 **어떤 위험 도구 패턴을 차단할지**는 룰로 명시되지 않았다.

기존 자산:
- `.claude/rules/cloud-cli-safety.md` — AWS/GCP 위험 CLI 패턴 (모듈식 활성화, 주석 토글)
- `.claude/rules/user-approval.md` — 외부 시스템 영향 작업 사전 승인 룰
- `.claude/rules/security.md` — 시크릿/입력검증/인증

부재한 영역:
- **자동 차단 가능한 위험 도구 패턴 카탈로그** — 사용자 승인 룰을 hook으로 enforce할 때 차단 대상
- **권한 우회 시도 차단** (예: `--no-verify`, `--force`, `commit.gpgsign=false` 같은 내장 정책 우회)
- **외부 데이터 유출 방지** (예: secret를 외부 webhook으로 POST)

## Decision (Proposed)

### A. 차단 대상 카테고리

**Tier 1 (항상 차단)** — 명백한 destructive / policy bypass:
- `git push --force` to main/master
- `git commit --no-verify`, `--no-gpg-sign`
- `kubectl delete`, `kubectl apply` (cloud-cli-safety가 적용된 cluster context)
- `rm -rf /` 또는 절대 경로 (workspace 외)
- `curl ... | bash` 같은 임의 코드 실행 패턴

**Tier 2 (사용자 승인 후 통과)** — risky but legitimate:
- `git push` to remote
- `gh pr merge`, `gh issue close`
- AWS/GCP 위험 CLI (cloud-cli-safety.md 패턴)
- production secret manager 접근

**Tier 3 (경고만, 통과)** — informational:
- `git rebase -i` (interactive 미지원)
- 디스크 공간 5GB 초과 작업

### B. PreToolUse hook 동작

```
Tool call 발생
  ├─ Tier 1 매칭 → 차단 + 사용자에게 사유 표시
  ├─ Tier 2 매칭 → 사용자 승인 prompt
  └─ Tier 3 매칭 → 경고 출력 후 진행
  └─ 매칭 없음 → 그대로 통과
```

### C. 패턴 정의 위치

- `.claude/rules/tool-safety.md` (신규, 50-150줄 sweet spot)
- 차단 패턴은 control-plane의 `admit` 서브명령이 읽는 정책 파일에 별도 저장 (예: `assets/tool-safety-policies.json`)
- 패턴 추가/수정은 ADR을 통해 추적

## Consequences

### Positive
- 사용자 명시 승인 룰을 enforce 가능 (memory만으론 hook 처리 안 됨, settings.json 필요)
- 의도치 않은 destructive 작업 사전 차단
- 정책의 deterministic 적용 (LLM의 변동성 무관)

### Negative / Trade-off
- 정책 maintenance 비용 (패턴 false positive/negative 지속 모니터링)
- 사용자 워크플로우에 friction (Tier 2 prompt 빈도 적정화 필요)
- control-plane 의존성 (npm/Node.js 필요)

## Alternatives Considered

| 대안 | Reject 이유 |
|---|---|
| `.claude/rules/`만으로 처리 | rule은 LLM context에 주입될 뿐 **enforce 없음**. 사용자 명시 승인 룰을 hook으로 강제하는 것이 본 ADR 핵심 |
| Anthropic 기본 permission 모드만 사용 | 조직 특화 정책(예: 본 레포의 cloud-cli-safety 모듈식 활성화) 미지원 |
| 모든 위험 명령 차단 (whitelist) | 워크플로우 마비. blacklist + 승인 prompt 조합이 실용적 |

## Implementation (별도 PR)

1. `.claude/rules/tool-safety.md` 작성 (Tier 1/2/3 카테고리 + 예시)
2. `assets/tool-safety-policies.json` 신설 (control-plane이 읽는 정책 파일)
3. control-plane `admit` 서브명령에 정책 매칭 로직 통합 (이미 PoC 존재)
4. settings.json template에 PreToolUse hook 등록 예시 추가
5. dev-logs에 false positive/negative 사례 누적 → 정책 보강 사이클

## Review Schedule

- 3개월 후 (2026-08-08) 1차 재검토: false positive 빈도 / 사용자 friction 평가
- 보안 사고 발생 시 즉시 재검토

## Related

- `.claude/rules/cloud-cli-safety.md` — AWS/GCP 위험 CLI 패턴 (Tier 2 후보)
- `.claude/rules/user-approval.md` — 외부 시스템 영향 작업 (Tier 2 base)
- `docs/migration/0002-*` — control-plane admit 서브명령 도입 기록
- ADR 0001 — Subagent 운영 (subagent도 tool 호출자라 동일 hook 적용)
