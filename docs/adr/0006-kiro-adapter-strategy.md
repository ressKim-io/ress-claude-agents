# ADR 0006 — Kiro IDE 어댑터 전략: 수동 매핑 가이드 only

- **Status**: Accepted
- **Date**: 2026-05-20
- **Driver**: Kiro IDE 추가 운영 욕구 + ressKim 본인 자산 다도구 활용
- **Depends on**: 없음 (신규 도구 합류 결정)
- **Related**: ADR 0007 (install.sh 축소), `.claude/rules/multi-tool-adapter.md` (PR-3), `docs/architecture/multi-tool-mapping.md` (PR-2)
- **관련 plan**: `/Users/ress/.claude/plans/install-sh-staged-blossom.md`

## Context

ress-claude-agents 는 현재 4 도구 호환을 다음 SOT 구조로 운영한다:

| 자산 | 위치 | 책임 |
|---|---|---|
| 보편 가이드 | `AGENTS.md` (325 줄) | Linux Foundation 표준, 모든 도구 자동 인식 |
| 상세 룰 (Claude) | `.claude/rules/` (25 개) | Claude Code 자동 로딩 |
| Universal 자산 | `.agents/skills/` (21 카테고리) | tool-agnostic source |
| 어댑터 변환기 | `control-plane/src/adapter.ts` (307 줄) | claude / codex / cursor 3 도구 byte-equal 또는 형식 변환 |

여기에 **Kiro IDE 를 추가 운영**하려는 욕구가 있다. Kiro 공식 docs 검증 결과 (2026-05-20):

1. **AGENTS.md 자동 인식** — 워크스페이스 루트 또는 `~/.kiro/steering/` 에 두면 자동 로딩. Linux Foundation 표준 합류.
2. **Skills 표준 호환** — Anthropic Agent Skills 표준 (폴더 + `SKILL.md` + YAML front-matter) 직접 인식. ress 폴더형 14 개는 그대로 작동.
3. **Subagents `.md` 호환** — `.kiro/agents/*.md` 가 front-matter `.md` 표준. `tools` 필드만 Claude Code 표기 (`Read,Bash`) → Kiro 그룹 표기 (`[read, shell]`) 변환 필요.
4. **Steering 4 inclusion 모드** — `.kiro/steering/*.md` 가 `always / fileMatch / manual / auto` 로 룰을 분류. ress `.claude/rules/` 의 frontmatter `applies_when` 과 의미 호환.
5. **Specs 고유** — `.kiro/specs/<feat>/{requirements,design,tasks}.md` 가 Kiro 만의 EARS notation 워크플로우. ress 의 `spec-driven-development` skill 과 정신적 대응.

즉 **Kiro 는 변환량이 매우 적은 도구**다. claude / codex 처럼 형식 변환 (`.md` → `.toml`) 이 없고, ressKim 본인이 자산을 골라 가져가는 picky 운영도 자연스럽다. 이 상황에서 어댑터 방향성을 결정한다.

## Decision

### 선택한 옵션: **Option 1 — 수동 매핑 가이드 only**

`control-plane/src/adapter.ts` 에 Kiro 케이스를 **추가하지 않는다**. 대신:

- `docs/architecture/multi-tool-mapping.md` (PR-2) — 4 도구 매핑 표 + Kiro 변환 규칙
- `.claude/rules/multi-tool-adapter.md` (PR-3) — universal 거버넌스 룰
- `.agents/skills/dx/multi-tool-asset-port.md` (PR-6) — 자산 1 개 port 7 단계 절차

위 3 산출물로 사용자가 필요한 자산만 직접 `.kiro/` 로 옮긴다.

## Considered Options

### Option 1 — 수동 매핑 가이드 only (채택)

- **장점**:
  - Kiro 표준 호환성이 높아 변환 자체가 거의 불필요. claude / codex 처럼 형식 변환 (`.md` → `.toml`) 없음
  - 자산 picky 운영과 자연 결합 (사용자가 필요한 것만 port)
  - adapter.ts 복잡도 증가 없음 (현재 307 줄 유지)
  - CI drift 검증 부담 없음 (`.kiro/` 산출물 Git 미커밋)
- **단점**:
  - 수동 변환은 drift 발생 가능 → multi-tool-adapter rule + drift 스크립트로 통제
  - 자산 30+ 개 port 시 반복 작업 부담 (반면 picky 운영 정신과 일관)
- **비용**: docs + rule + skill 작성 (8 PR 중 P0/P1/P2)
- **위험**: 낮음 — 기존 SOT 영향 없음

### Option 2 — adapter.ts Kiro 케이스 자동화

- **장점**: claude / codex / cursor 와 일관된 운영, 일괄 변환
- **단점**:
  - 사용자가 명시적으로 "install / 자동화 거부". 같은 정신 부담 발생
  - Kiro 가 표준 호환이라 자동화 ROI 낮음 (변환할 게 거의 없음)
  - `.kiro/` Git 커밋 + CI drift 검증 추가 부담
  - 자산 picky 운영 정신과 배치 (일괄 변환은 광범위 install 의 다른 형태)
- **비용**: adapter.ts +50-100 줄, vitest +1, CI 통합
- **위험**: 중간 — 자동 생성물 drift 위험

### Option 3 — 하이브리드 (가이드 + 선택적 자동화)

- **장점**: 가이드로 시작 후 필요 시 자동화 확장 가능
- **단점**: 의사결정 지연. 자동화 시점이 모호하면 가이드 유지보수만 누적
- **비용**: Option 1 + 추후 Option 2 도 더해질 가능성
- **위험**: 중간 — 두 트랙 동시 운영 시 SOT 혼란

## Consequences

### 긍정 (Pros)

- ress-claude-agents 의 SOT 계층 변경 없음 (AGENTS.md / `.agents/` / adapter.ts 그대로)
- ressKim 본인 자산 picky 운영 가능 (필요한 것만 `.kiro/` 로)
- Kiro 사양 변경 시 가이드 / 룰 / skill 만 갱신, 코드 영향 없음

### 부정 (Cons / Trade-offs)

- 자산 다수 port 시 수동 반복. 30+ skill 옮길 일 생기면 다시 Option 2 재고
- `.kiro/` 산출물이 Git 미커밋이면 ressKim 머신 외 환경에서 재생성 부담
- Kiro 의 `tools` 필드 변환 (Claude `Read,Bash` → Kiro `[read, shell]`) 같은 매핑 규칙을 사람이 매번 적용

### 중립 (Neutral)

- AGENTS.md §Tool-Specific 테이블에 Kiro 행 추가 (PR-4)
- inventory-labels.yml 의 portability 라벨에 Kiro 운영 표현 추가 (PR-5)

## Implementation Notes

PR 분할은 `/Users/ress/.claude/plans/install-sh-staged-blossom.md` 참조. 본 ADR 채택으로 다음 PR 실행:

| PR | 산출물 | Stage |
|---|---|---|
| PR-2 | `docs/architecture/multi-tool-mapping.md` | P0 |
| PR-3 | `.claude/rules/multi-tool-adapter.md` | P0 |
| PR-4 | `AGENTS.md` §Tool-Specific Kiro 행 + §Governance | P1 |
| PR-5 | `inventory-labels.yml` tools_supported 필드 | P1 |
| PR-6 | `.agents/skills/dx/multi-tool-asset-port.md` | P2 |
| PR-7 | `.claude/templates/kiro-spec/` 3 종 | P2 |

본 ADR 범위 외:
- `control-plane/src/adapter.ts` Kiro 케이스 추가 — Option 1 결정으로 보류
- 향후 자산 30+ 개 port 필요 발생 시 본 ADR 재검토 (Option 2 채택 가능성)

### 롤백 계획

- 본 ADR 결정 자체는 docs / rule / skill 추가만이라 롤백 = 해당 파일 삭제 + AGENTS.md 의 Kiro 행 제거
- `.kiro/` 산출물은 ressKim 머신에만 존재 → 롤백 시 ressKim 수동 정리

## Validation / Success Criteria

- [ ] PR-2 ~ PR-7 머지 완료 + drift 스크립트 통과
- [ ] ressKim 가 Kiro 워크스페이스에서 ress 자산 (skill 1 개 + agent 1 개) 정상 작동 확인
- [ ] AGENTS.md §Governance drift 검증 통과
- [ ] 6 개월 후 회고 — 수동 port 빈도 / 반복 작업 부담 / Option 2 재검토 가부

## Sources

Kiro 공식 docs (Verified-by: Claude WebFetch + WebSearch cross-check, 2026-05-20):

- https://kiro.dev/docs/steering/ — Steering inclusion 4 모드 (always / fileMatch / manual / auto)
- https://kiro.dev/docs/specs/ — Specs 3 파일 (requirements / design / tasks) + EARS notation
- https://kiro.dev/docs/hooks/ — Hooks JSON 형식 (`*.kiro.hook`)
- https://kiro.dev/docs/skills/ — Agent Skills 표준 (Anthropic 호환, 폴더 + SKILL.md)
- https://kiro.dev/docs/chat/subagents/ — Subagents front-matter (`name`, `description`, `tools`, `model`)
- https://kiro.dev/docs/mcp/configuration/ — MCP 설정 경로 (`.kiro/settings/mcp.json`)
- https://kiro.dev/changelog/ide/0-9/ — Kiro 0.9 Subagents / Skills / Hook trigger 추가

⚠️ Kiro 사양은 cutoff 이후 변경 가능. 본 ADR 결정 후 사양 변경 시 review schedule: **분기별** (2026-08, 2026-11, 2027-02).

## References

- `/Users/ress/.claude/plans/install-sh-staged-blossom.md` — 본 ADR 의 plan 원본
- ADR 0007 — install.sh 축소 (자산 picky 운영의 다른 측면)
- AGENTS.md §Tool-Specific Optimization L231-240
- AGENTS.md §Governance L312-325
- `.claude/rules/deep-thinking.md` — 출처 검증 의무
