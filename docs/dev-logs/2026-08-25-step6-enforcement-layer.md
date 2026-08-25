---
date: 2026-08-25
category: decision
tier: 2
importance: critical
status: resolved
tags: [harness, enforcement, permissions, hooks, settings, audit, postmortem]
related:
  - audit/2026-08-24-agent-harness-readiness.md
  - adr/0009-enforcement-layer-placement.md
  - dev-logs/2026-08-25-step4-harness-retrofit.md
  - migration/0002-progress.md
---

# Step 6 — 실행 강제 레이어 + 죽은 hook 부검

## 요약

audit Step 6(F4 / F10)에 착수하다가 **이미 있던 강제력 레이어가 3.5개월째 0% 로 작동했다**는 사실을 발견했다 (F11). 그것을 폐기하고, 강제력을 `.claude/settings.json` 의 `permissions.deny` / `ask` 로 다시 세웠다.

| | 착수 전 | 완료 후 |
|---|---|---|
| 강제되는 외부 작업 | **0건** (산문만) | **22건** (deny 11 / ask 11) |
| 강제력 자산의 검증 | `admit()` 순수 함수만 | 정적 게이트(CI) + 런타임 25/25 + 음성 테스트 6/6 |
| control-plane vitest CI 실행 | **없음** | drift job 에 추가 |
| 문서 미기재 영역 | V12 / V13 미확인 | 실측으로 해소 |

## 무엇이 죽어 있었나 (F11)

Migration 0002 P5(2026-05-06)가 도입한 PreToolUse `admit` hook:

```
npx @ress/claude-agents admit --tool="$CLAUDE_TOOL" \
  --path="$CLAUDE_TOOL_INPUT_path" --skill="$CLAUDE_ACTIVE_SKILL" --mode=warn
```

두 군데가 동시에 틀렸다.

1. **`$CLAUDE_TOOL` 계열 환경변수는 존재하지 않는다.** hook 입력은 stdin JSON 이고, Claude Code 가 설정하는 건 `CLAUDE_PROJECT_DIR` / `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA` / `CLAUDE_CODE_REMOTE` / `CLAUDE_CODE_BRIDGE_SESSION_ID` / `CLAUDE_EFFORT` 뿐이다.
2. **`@ress/claude-agents` 는 npm 미배포다** (`E404`). 명령 자체가 실행되지 않는다.

그리고 P6.5 는 "1주 baseline 수집 중" 으로 3.5개월 멈춰 있었는데, 실측해 보니 **수집이 시작된 적이 없었다** — 싱크 파일 없음 / `.claude/settings.local.json` 없음 / `~/.zshrc` export 없음 / lock 파일 없음. progress 문서에는 "setup 완료 (a)(b)(c)(d)" 로 적혀 있었다.

**왜 3.5개월간 아무도 몰랐나** — 세 겹이다.

- `PreToolUse` 는 exit 1 / 실행 실패 / timeout 을 **전부 비차단으로 처리하고 그대로 진행**한다. 깨진 hook 은 아무 소리도 내지 않는다.
- vitest 111건이 전부 green 이었다. `admit()` **순수 함수만** 테스트하고 배선은 테스트하지 않았다.
- 그 111건조차 **CI 에서 돈 적이 없다.** CI 는 `bats tests/install.bats` 만 돌린다.

## 교훈

1. **선언형 설정을 스크립트 hook 보다 선호한다.** 같은 위협을 막을 수 있으면 실패가 드러나는 쪽을 고른다. 무효한 permission 규칙은 startup warning 을 내지만 깨진 hook 은 침묵한다.
2. **순수 함수 테스트는 배선 결함을 못 잡는다.** 강제력 자산에는 "일부러 위반하는" fixture 가 필요하다.
3. **로컬에서만 도는 테스트는 회귀를 막지 못한다.**
4. **문서에 "완료" 라고 적는 것과 완료된 것은 다르다.** P6.5 setup 4항목은 전부 미실행이었다. 상태를 적을 때 실측을 붙인다.

## 실측 (문서에 없던 것)

공식 문서가 답하지 않는 영역이 두 개 있었다. sentinel 명령(`echo ENFORCE_PROBE_*`)만으로 격리 측정했다 — CLI v2.1.245.

| 질문 | 문서 | 실측 |
|---|---|---|
| `bypassPermissions` 하에서 PreToolUse hook 이 도는가 | 기술 없음 | **돈다. 차단도 된다** (P3) |
| `ask` 가 `bypassPermissions` 에서 유지되는가 | 기술 없음 | **유지된다. 자동승인 안 됨** (P4) |
| deny 가 subagent 의 `Bash` 에 닿는가 | hook 상속만 명시 | **닿는다** (P5) |
| 복합 명령 / 여분 공백으로 우회되는가 | "인자 제약 패턴은 취약" 경고 | **이 두 변형으로는 우회 안 됨** (P6/P7, 음성 대조군으로 확인) |

마지막 행은 공식 Warning 의 **범위를 좁힌다**: 취약한 것은 인자 *값* 을 제약하는 패턴이고, 명령 접두 단위 deny 는 견뎠다. 인용 우회(`e''cho`) / 변수 치환은 **시험하지 않았다** — 그래서 deny 를 유일한 방어선으로 삼지 않는다.

## 왜 두 층(deny / ask)인가

`deny` 는 **사용자 본인에게도 적용된다.** `git push` 를 deny 로 막으면 사용자가 승인한 push 조차 실행할 수 없다. 그래서:

- `deny` = 세션에서 실행할 정당한 경우가 없는 것 — 변경형 `kubectl`, ArgoCD Force Sync
- `ask` = 승인 프로세스가 존재하는 것 — `git push`, `gh pr/issue/release`, `argocd app sync`

이 구분은 새로 만든 게 아니라 `user-approval.md` 산문에 이미 있던 구조다 ("절대 금지" vs "사전 승인 필수"). 그 구조를 그대로 기계에 옮겼다.

## 남긴 것 (범위 밖, 목록만)

- **`.codex/agents/` 가 2026-05-18 이후 재생성되지 않았다.** Step 3/4 의 agent 본문 변경이 codex view 에 반영되지 않아 adapter parity drift 33파일 / ~1,500줄. [`multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md) 는 "같은 PR 에서 변환 재실행" 을 MUST 로 규정한다 — Step 3/4 가 이를 놓쳤다.
- **CI 가 이 브랜치에서 한 번도 돌지 않았다.** `ci.yml` 은 `push: branches: [main]` + `pull_request` 에서만 트리거된다. PR 이 없으니 drift job 이 위 항목을 잡을 기회가 없었다. 게이트는 있는데 발화 조건이 없는 것 — F11 과 같은 계열의 문제다.
- `user-approval.md` 가 201줄이 됐다 (매핑 표 +38줄). always-on rules 예산(13개 / 1,503줄 + AGENTS.md 340줄 ≈ 90KB)이 그만큼 늘었다. Step 7 의 산문→강제 이관 분류에서 상계될 자리다.
- `security.sandbox` (skill manifest) 는 소비자가 사라져 orphan 이다. 스키마 MAJOR bump 회피로 필드는 유지, 주석만 달았다.

## 검증 결과

```
control-plane   typecheck 통과 / vitest 97 passed (111 → 97, admit 관련 14건 제거)
validators      rules-drift / skill-frontmatter / agent-handoff / commands-drift /
                schemas / enforcement / generate-docs 전부 PASS
shellcheck      install.sh + scripts/*.sh 전부 PASS
inventory       최신 (재생성 후 diff 없음)
enforcement     정적 음성 테스트 6/6 검출 · 런타임 25/25 (음성 대조군 3 포함)
```

`bats tests/install.bats` 는 **실행 안 함** — 로컬에 bats 미설치 (CI 에서 실행됨).
