# Token Budget 원칙 (Claude 5.5 세대 기준)

모든 대화에서 공통 적용되는 컨텍스트·토큰 운영 원칙.
Rules는 매 대화마다 주입되므로 핵심만 유지 — 상세는 `/token-budget` 스킬 참조.

> 출처·검증 상태: [2026-11-04 사양 검증](../../../docs/audit/2026-11-04-claude-spec-verification.md)

## Context Window 관리 (Claude Code)

- MUST 컨텍스트 **80% 초과 시** 세션 종료 후 재시작
- MUST **무관한 태스크 전환** 시 `/clear`로 context reset
- PREFER **마일스톤 완료 직후** `/compact` 선제 실행 (차기 전)
- MUST 2회 이상 같은 실수 교정 시 `/clear` + 재프롬프트 — context 오염 방지
- NEVER 같은 파일 2회 이상 읽기 (`workflow.md` §Context 효율화 참조)

## Subagent를 Context 절약 도구로

- MUST **10+ 파일 탐색/조사**는 subagent에 위임 — 주 context 보호
- MUST 병렬 fan-out이 필요하면 프롬프트에 명시 — 예: "Use subagents to investigate X in parallel"
- NEVER 단일 함수 리팩토링·이미 읽은 파일 수정에 subagent 사용 (오버헤드만 발생)

## Effort 선택

| 레벨 | 사용 상황 |
|------|---------|
| `low` | 단순 조회·분류·속도 우선 |
| `medium` | 범위가 명확한 코딩·분석. Opus 5.5 시작점 |
| `high` | 어렵거나 긴 작업, 리뷰, 조사. **본 레포 agent 기본** |
| `xhigh` / `max` | 품질 향상을 **측정한** 작업만 |

- MUST 얕은 추론 관찰 시 prompting 우회 대신 effort 레벨 **상향**
- MUST agent frontmatter 에 `effort` 를 **명시**한다 — 생략하면 모델 기본값으로 돈다 (Claude Code 의 Opus·Sonnet·Haiku 5.5 는 `medium`)
- NEVER skill 에 `effort` 를 넣는다 — 그 턴이 끝날 때까지 세션 설정을 덮어쓴다

> 카테고리별 매핑과 모델별 지원: [`effort-guide.md`](effort-guide.md)

## Tokenizer & Prompt Cache

- Opus 4.7 부터 쓰는 tokenizer: 같은 텍스트가 이전 모델보다 **최대 약 35%** 더 많은 토큰 사용. Opus 5.5·Sonnet 5.5 도 동일 계열
- MUST `max_tokens` 에 여유를 둔다 — 공식 제안은 agentic 코딩 128,000 (상한 128K)
- MUST 클라이언트 쪽 토큰 추정 로직 **재검증** (fixed ratio 가정 파기)
- **최소 cacheable 길이**: 512 (Opus 5.5 / Sonnet 5.5 / Haiku 5.5 / Fable 5.1), 2,048 (Opus 4.7), 4,096 (Opus 4.6 / 4.5 / Haiku 4.5). 짧은 prompt 는 cache 안 됨 (no error)
- **캐시 단가**: 쓰기 5분 1.25x, 1시간 2x. 읽기 0.05x (Opus·Sonnet 5.5), 0.025x (Fable 5.1), 0.1x (Haiku 5.5 및 이전)
- 요청 사이에 top-level effort 를 바꾸면 캐시가 깨진다
- 5-min TTL (default, 자동 refresh) / 1-hour TTL

## API 파라미터 (직접 호출 시)

Claude Code 는 런타임이 관리하므로 **신경 쓰지 않는다.** Messages API 를 직접 호출할 때:

| 항목 | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 | Fable 5.1 |
|---|---|---|---|---|
| `temperature` / `top_p` / `top_k` | 400 | 400 | 생략 권장 | 400 |
| assistant prefill | 400 | 400 | 400 | 400 |
| forced `tool_choice` (`any`, `tool`) | 400 | 400 | 허용 | 400 |

- `thinking.budget_tokens` 는 Opus·Sonnet 5.5 에서 400. 깊이는 `output_config.effort` 로 제어한다
- Opus 5.5 는 thinking 이 항상 켜져 있다. `thinking` 생략 = adaptive, `disabled` 는 400
- Sonnet 5.5 에서 thinking 을 끄려면 `{"type": "between_tools"}`

## 토큰 절약 실전

- PREFER 독립 파일은 **병렬 Read 호출** (한 응답에 묶기)
- MUST 큰 파일은 `wc -l` 선확인 후 범위 지정 읽기
- MUST 의도·제약·수락 기준·파일 경로 **첫 턴에 완전 명세** — 다회 왕복 금지
- PREFER 일반화가 필요하면 "유사 케이스에도 적용" **명시**

## 5가지 실패 패턴 (공식 문서)

- **Kitchen sink session** — 무관 태스크 축적 → `/clear`
- **Over-correction** — 2회 실패 시 `/clear` + 재프롬프트
- **Over-specified CLAUDE.md** — 룰 묻힘, 가지치기 필요
- **Trust-then-verify gap** — 검증(tests/scripts) 없이 ship 금지
- **Infinite exploration** — 범위 미설정 → subagent로 격리

---

상세 가이드, 코드 예시, Task Budget API, Prompt Caching 구조: `/token-budget` 스킬 참조
