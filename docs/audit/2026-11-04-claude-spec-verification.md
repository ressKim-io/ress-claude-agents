# Claude 사양 검증 기록 (2026-11-04)

이 레포의 규칙과 사양 문서를 현행 Claude 기준으로 맞추며 확인한 사실을 기록한다. 직전 재검증은 2026-08-25다.

| 항목 | 값 |
|---|---|
| 검증일 | 2026-11-04 |
| 검증 방법 | 공식 문서 WebFetch, `claude --help`, 로컬 스크립트 실행 |
| 검증자 | Claude (subagent 조사 + 메인 세션 확인) |
| Claude Code | 2.1.318 (`claude --version`) |
| 다음 재검증 | 2027-02 |

상태 표기: ✅ 공식 문서에 직접 기술 / ⚠️ 문서에 없거나 추론 / 🧪 로컬 실측

---

## 1. 모델과 가격

출처: [models overview](https://platform.claude.com/docs/en/models/overview), [pricing](https://platform.claude.com/docs/en/about-claude/pricing), [deprecations](https://platform.claude.com/docs/en/about-claude/model-deprecations)

| 모델 | ID | Context / 최대 출력 | 입력 | 5분 쓰기 | 1시간 쓰기 | 읽기 | 출력 | 상태 |
|---|---|---|---|---|---|---|---|---|
| Fable 5.1 | `claude-fable-5-1` | 1M / 128K | $10 | $12.50 | $20 | $0.25 | $50 | ✅ |
| Opus 5.5 | `claude-opus-5-5` | 1M / 128K | $4 | $5 | $8 | $0.20 | $20 | ✅ |
| Sonnet 5.5 | `claude-sonnet-5-5` | 1M / 128K | $2 | $2.50 | $4 | $0.10 | $10 | ✅ |
| Haiku 5.5 | `claude-haiku-5-5` | 1M / 128K | $0.10 | $0.125 | $0.20 | $0.01 | $0.50 | ✅ |

- 단위는 $/MTok. Haiku 5.5 는 100k 토큰 초과 프롬프트에 더 높은 단가가 적용된다 ✅
- 캐시 읽기 배수는 Opus·Sonnet 5.5 가 0.05x, Fable 5.1 이 0.025x, 그 외 0.1x 다 ✅
- Sonnet 4.5 는 2026-11-30 은퇴 예정이다. 대체 모델은 `claude-sonnet-5-5` 다 ✅

## 2. Effort

출처: [effort](https://platform.claude.com/docs/en/build-with-claude/effort), [model-config](https://code.claude.com/docs/en/model-config), [Opus 5.5 prompting](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5), [Sonnet 5.5 prompting](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5)

| 사실 | 상태 |
|---|---|
| Opus 5.5 시작점: "Start at `medium`, the default on Claude Opus 5.5" | ✅ |
| Sonnet 5.5: "start with `medium` for well-specified tasks and move to `high` for harder or longer ones" | ✅ |
| "Reserve `xhigh` and `max` for work where you've measured a quality gain." | ✅ |
| 기본값: Fable 5.1 `high`/`high`, Opus 5.5 `medium`/`medium`, Sonnet 5.5 `high`/`medium`, Haiku 5.5 `medium`/`medium` (API / Claude Code) | ✅ |
| 레벨 간 비용 배수 | ⚠️ 문서에 없음. 이전 판의 `~25%`, `~50%`, `~200%`, `+3%p` 를 삭제했다 |
| skill `effort`: "Effort level for the rest of the current turn. Overrides the session effort level" | ✅ |
| "Changing the top-level effort value between requests invalidates the prompt cache" | ✅ |

## 3. API 파라미터

출처: [Opus 5.5 migration](https://platform.claude.com/docs/en/models/opus-5-5/migration-guide), [Sonnet 5.5 migration](https://platform.claude.com/docs/en/models/sonnet-5-5/migration-guide), [2026-10-21 migration](https://platform.claude.com/docs/en/api/migration-2026-10-21), [prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching), [task budgets](https://platform.claude.com/docs/en/build-with-claude/task-budgets)

| 항목 | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 | Fable 5.1 |
|---|---|---|---|---|
| `temperature` / `top_p` / `top_k` | ✅ 400 | ✅ 400 | ⚠️ "Omit" 만 기술 | ✅ 400 |
| `thinking.budget_tokens` | ✅ 400 | ✅ 400 | ⚠️ 미확인 | ⚠️ 미확인 |
| assistant prefill | ✅ 400 | ✅ 400 | ✅ 400 | ✅ 400 |
| forced `tool_choice` | ✅ 400 | ✅ 400 | ✅ **허용** | ✅ 400 |
| 최소 cacheable | ✅ 512 | ✅ 512 | ✅ 512 | ✅ 512 |

- 최소 cacheable 은 Opus 4.7 이 2,048, Opus 4.6·4.5·Haiku 4.5 가 4,096 이다 ✅
- API version `2026-10-21` 은 샘플링 파라미터를 기본값이어도 거부하고, `2023-06-01` 은 기본값이 아닌 값만 거부한다 ✅
- Task budget 은 여전히 beta(`task-budgets-2026-03-13`)이고 최소값은 20,000 토큰이다. Sonnet 5, Opus 4.6, Sonnet 4.6, Haiku 4.5 는 미지원이다 ✅
- `max_tokens` 는 "give additional headroom" 이라고만 쓰여 있고 agentic 코딩에 128,000 을 제안한다. 이전 판의 "35% headroom" 은 공식 지시가 아니어서 삭제했다 ✅

## 4. Claude Code 자산 사양

출처: [skills](https://code.claude.com/docs/en/skills), [sub-agents](https://code.claude.com/docs/en/sub-agents), [memory](https://code.claude.com/docs/en/memory), [plugins manifest](https://code.claude.com/docs/en/plugins/manifest-reference), [marketplace reference](https://code.claude.com/docs/en/plugins/marketplace-reference), [components](https://code.claude.com/docs/en/plugins/components), [install](https://code.claude.com/docs/en/plugins/install), [org](https://code.claude.com/docs/en/plugins/org), [tools reference](https://code.claude.com/docs/en/tools-reference)

| 영역 | 사실 | 상태 |
|---|---|---|
| Skill | 공식 frontmatter 20개. `category`, `deprecated` 는 없다. 미지 필드는 Claude Code 가 무시하고, 패키징·업로드 시 오류가 된다 | ✅ |
| Skill | 목록 예산은 컨텍스트의 1% (`skillListingBudgetFraction`, 기본 0.01), 대체값 8,000자. description + `when_to_use` 는 1,536자에서 잘린다 | ✅ |
| Skill | 예산 초과 시 이름은 남고 덜 쓰는 skill 부터 description 이 빠진다 | ✅ |
| Skill | compact 후 skill 당 5,000 tokens, 전체 25,000 tokens 공유. 이전 판의 "25KB" 는 오기였다 | ✅ |
| Skill | `.claude/skills/<카테고리>/<이름>/` 중첩 탐색 | ⚠️ 문서에 없음 |
| Agent | 공식 frontmatter 19개. 하위 디렉터리는 재귀 탐색된다. 이름은 경로가 아니라 `name` 에서 온다 | ✅ |
| Rule | 하위 디렉터리는 재귀 탐색된다. `paths` 가 유일한 frontmatter 다 | ✅ |
| AGENTS.md | v2.1.277 부터 직접 읽되, `CLAUDE.md` 가 없을 때만이다. symlink 는 한 번만 읽힌다 | ✅ |
| Plugin | 한 레포에 여러 plugin 을 담는 marketplace 가 가능하다. 설치는 `/plugin marketplace add`, `/plugin install x@y` | ✅ |
| Plugin | rules 와 root `CLAUDE.md` 는 실리지 않는다. plugin `settings.json` 은 `agent`, `subagentStatusLine` 만 적용된다 | ✅ |
| Plugin | plugin agent 에서 `permissionMode`, `hooks`, `mcpServers`, `initialPrompt` 는 무시된다 | ✅ |
| Plugin | 설치본은 plugin 별로 캐시되므로 경계 밖 상대 링크는 깨진다 | ⚠️ 캐시 규칙에서 추론 |
| 도구 | `TaskCreate` 등은 Opus 4.7, Sonnet 4.6, Haiku 4.5 이하에서만 기본 제공되고 그 외는 `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 이 필요하다 | ⚠️ 문서 요약본 경유 |
| Action | `claude-code-action@v1` 에 `model`, `allowed_tools` 입력이 없다. `claude_args: --model`, `--allowedTools` 로 대체한다 ([action.yml](https://raw.githubusercontent.com/anthropics/claude-code-action/main/action.yml), [migration guide](https://github.com/anthropics/claude-code-action/blob/main/docs/migration-guide.md)) | ✅ |

## 5. 이전 기록과 달라진 점

| 이전 기록 | 현행 | 반영 |
|---|---|---|
| 레포 기본 effort `xhigh` | agent `high`, skill 은 effort 없음 | `effort-guide.md`, `token-budget.md`, `AGENTS.md`, agent 28개 |
| "Literal interpretation", "Subagent 덜 spawn" | Opus·Sonnet 5.5 가이드에 없음 | `AGENTS.md`, `prompt-engineering`, `agentic-coding`, `token-budget` skill |
| "자체 검증 내장 → scaffolding 제거" | Sonnet 5.5 는 오히려 검증 지시가 필요하다 | 위와 동일 |
| 최소 cacheable 4,096 | 5.5 세대 512 | `token-budget.md`, `token-budget` skill |
| 캐시 읽기 0.1x (90% 절감) | Opus·Sonnet 5.5 0.05x (95% 절감) | `token-budget` skill, `credit-system` |
| Opus $5/$25, Frontier $15-25/$75-100 | Opus 5.5 $4/$20 | `token-budget` skill, `finops-ai`, `credit-system` |
| subagent 필드 16개 | 19개 | `AGENT-SPEC.md`, `AGENTS.md` |
| `model`, `allowed_tools` action 입력 | `claude_args` | `pr-review-automation` |
| `temperature` 예시 | Sonnet 5.5 는 400 | `spring-ai`, `langchain-langgraph`, `observability-genai` |
| 모델 ID `*-4-*` | `*-5-5` | skill 8개 |

## 6. 검증하지 못한 것

| 항목 | 상태 | 이유와 다음 행동 |
|---|---|---|
| 중첩 skill 경로 동작 | ⚠️ | 문서에 없다. plugin 파일럿에서 임시 디렉터리로 시험한다 |
| `extraKnownMarketplaces` 의 `path: "."` | ⚠️ | 상대 경로는 문서에 있으나 `"."` 자체는 없다. plugin 파일럿에서 시험한다 |
| 목록 예산 초과량 | ⚠️ | 세션 목록에서 272개 중 94개만 description 이 보였다. 토큰-문자 환산은 문서에 없어 추정치다. `/doctor`, `/skill-doctor` 로 확인한다 (대화형) |
| Spring AI 가 unset `temperature` 를 보내는가 | ⚠️ | 문서에 없다. Chat Options 표의 기본값은 "1.0". 실제 호출로만 확인 가능하다 |
| `ChatAnthropic` 기본 temperature | ⚠️ | 문서에 기본값과 생략 여부가 없다 |
| Haiku 4.5 에서 frontmatter `effort` 처리 | ⚠️ | 문서에 없다 |
| skill effort 전환이 Claude Code 프롬프트 캐시를 깨는가 | ⚠️ | API 에 대한 서술만 있다 |
| `auto` 모드에서 `ask` 규칙 동작 | ⚠️ | v2.1.284 부터 대화형 기본이 auto 지만 이 레포에서 미시험이다 ([ADR 0009](../adr/0009-enforcement-layer-placement.md)) |
| Changelog 2.1.246~2.1.318 | ⚠️ | 긴 페이지라 요약을 거쳤다. 의존하는 항목은 구현 시 원문을 다시 본다 |

## 7. 권한 규칙 재측정 🧪

`scripts/verify-enforcement-runtime.sh` 를 CLI 2.1.318 에서 실행했다.

| 층 | 프로브 | 결과 |
|---|---|---|
| `deny` | 11 | 전부 BLOCKED |
| `ask` | 11 | 전부 BLOCKED (비대화형이라 규칙 매칭만 증명) |
| 허용 | 3 | 전부 RAN |

통과 25 / 실패 0. [ADR 0009](../adr/0009-enforcement-layer-placement.md) 의 결론을 바꿀 결과가 아니어서 `user-approval.md` 와 ADR 은 고치지 않았다. 대화형 `bypassPermissions` 측정(P8)은 다시 하지 않았다.
