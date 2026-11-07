---
name: claude-unattended-ops
description: "Claude Code를 사람 없이 돌릴 때 실행 경로, 권한 배치, MCP 로딩, 실패한 run 판정을 정한다. Use when CI·cron·알림으로 claude -p, Agent SDK, GitHub Actions, 예약 작업을 설정하거나 무인 run이 조용히 실패한 원인을 볼 때."
---

# Claude Code 무인 실행 운영

사람이 지켜보지 않는 Claude Code run의 실행 경로를 고르고, 강제력이 있는 층에 권한을 두고, exit code가 아니라 출력 내용으로 성공을 판정한다.
외부 사실은 2026-11-06 원문 대조 기록과 같은 날 로컬 실측에서 확인된 것만 싣는다. 기준은 검증일 시점의 최신 Claude Code와 현행 문서다.

## Quick Reference (결정 트리)

```
무인 run 설계
    │
    ├─ 1) 트리거 → 실행 경로
    │       ├─ PR·issue 이벤트 ─────────────> GitHub Actions (claude-code-action@v1, 옵션은 claude_args)
    │       ├─ 주기 실행
    │       │     ├─ 팀이 소유·감사해야 함 ───> CI cron job 안의 claude -p
    │       │     ├─ 개인 작업 ──────────────> cloud scheduled task (개인 계정 소유, research preview)
    │       │     └─ 세션 안 단기 반복 ──────> /loop (세션당 50개, 반복 작업은 7일 후 만료)
    │       ├─ 알림·webhook ────────────────> CI job 안의 claude -p
    │       └─ 내 코드가 호출 ──────────────> Agent SDK
    │
    ├─ 2) 권한 배치 (위에서부터 채운다)
    │       ├─ deny ─> managed settings 또는 신뢰 경로의 --settings·--disallowedTools
    │       │          (PR 체크아웃의 project settings는 PR이 바꿀 수 있다)  ← 모든 모드에서 남는 유일한 권한 규칙
    │       ├─ mode ─> --permission-mode 항상 명시 (기본값이 버전마다 달랐다)
    │       │     ├─ 기본 ─────────────────> dontAsk + allowedTools (열거한 도구만)
    │       │     └─ bypassPermissions ────> deny 있음 + 컨테이너·VM·sandbox + 비 root 일 때만
    │       ├─ ask ──> ⚠️ bypass 동작 재측정 대기. 강제 근거로 세지 않는다
    │       └─ hook ─> 보조 수단 (fail-open)
    │                  --bare 에서는 settings 와 plugin 의 hook 이 실행되지 않는다(--settings 로 넘긴 hook 포함)
    │
    └─ 3) 결과 판정 (exit 0 ≠ 성공. deny 차단·MCP 연결 실패도 exit 0)
            ├─ exit code ≠ 0 ────────────────────────────> 실패 (143 = SIGTERM, --max-turns 초과 = 1)
            ├─ result 의 is_error 또는 subtype ≠ success ──> 실패
            ├─ result 의 permission_denials 비어 있지 않음 ─> 실패
            ├─ --json-schema 사용 + structured_output 없음 ─> 실패
            └─ system/init 의 plugin_errors·mcp_server_errors 비어 있지 않음
               또는 mcp_servers[].status 가 connected 아님 ─> 실패 (일부러 끈 disabled 만 예외)
```

## 실행 경로 비교

| 경로 | 트리거 | 소유·인증 | 권한 기본값 | hook·plugin 로딩 | 상한·수명 | 상태 |
|---|---|---|---|---|---|---|
| `claude -p` (CI job) | CI가 실행 | runner에 둔 자격 증명 | Manual (승인이 필요한 호출은 거부) | bare가 아니면 project hook 실행·`.mcp.json` 연결, plugin monitor 미시작 | `--max-turns`(기본 무제한), `--max-budget-usd` | 문서에 preview 표기 없음 (2026-11-06) |
| Agent SDK | 내 코드 | — | Manual, `canUseTool` 콜백 | `--bare` 권장 | — | 문서에 preview 표기 없음 (2026-11-06) |
| GitHub Actions (`claude-code-action@v1`) | PR·issue 이벤트, schedule | 저장소 workflow. 이슈·PR 이벤트는 write 권한 사용자만 (예외 `allowed_non_write_users`) | schedule 평문 프롬프트는 도구를 줄 때까지 shell·GitHub API 없음 | — | `claude_args`의 `--max-turns`. schedule은 공개 저장소에서 60일 비활성 시 꺼짐 (GitHub Docs) | 문서에 preview 표기 없음 (2026-11-06) |
| cloud scheduled task | 일정, Run now, API fire, GitHub 이벤트 | 개인 claude.ai 계정, 결과물은 소유자 명의 | auto 모드로 시작, 연결된 connector 전부 포함 (쓰기 포함) | — | §예약·클라우드 실행 | research preview |
| `/loop` | 세션 안 주기 실행 | 그 세션 | — | — | 세션당 50개, 반복 작업은 7일 후 만료 | 문서에 preview 표기 없음 (2026-11-06) |
| Managed Agents | API (헤더 `managed-agents-2026-04-01`) | — | — | — | — | beta |
| agent teams | — | — | — | — | — | experimental (기본 비활성) |

`—` 칸은 검증 기록에 없는 항목이다. "문서에 preview 표기 없음"은 해당 문서 페이지에 preview·beta·experimental 표기가 없다는 뜻이고, GA 선언이 아니다.

GitHub Actions의 CLI 옵션은 `claude_args`로 넘긴다. `claude-code-action@v1`에는 `model`, `allowed_tools` 입력이 없다(action.yml 재대조 2026-11-06). 문서는 `claude_args`가 "accepts any Claude Code CLI argument"라고 쓰고, 비용을 줄이는 방법으로 "Set `--max-turns` in `claude_args` to limit iterations"를 든다. deny도 `claude_args`의 `--disallowedTools`로 넘긴다. `--max-budget-usd`는 문서에 이름이 없다. Action 코드는 이 플래그를 CLI로 그대로 넘기지만, Action 안에서 효과가 있는지는 ⚠️ 측정하지 않았다.

```yaml
# 발췌 — 인증 입력·workflow 구성은 pr-review-automation 참조
- uses: anthropics/claude-code-action@v1
  with:
    claude_args: >-
      --model claude-sonnet-5-5
      --max-turns 10
      --allowedTools "Bash(gh pr diff *)"
```

## 권한 배치

평가 순서(Agent SDK 문서): Hooks → Deny rules → Ask rules → Permission mode → Allow rules → `canUseTool` callback. hook이 허용해도 규칙은 남는다: "A hook that returns `allow` doesn't skip the deny and ask rules below".

| 층 | 무인 run에서의 효과 | 두는 곳 |
|---|---|---|
| deny | "Deny rules block in every mode, including `bypassPermissions`." 단 문자열 패턴이라 `Bash(git push *)`는 `git -C . push origin main`과 매칭되지 않는다. `-p`에서 `--settings`의 deny가 `--allowedTools "Bash(echo *)"`보다 우선해 막았다(✅ 로컬 실측 2026-11-06) | managed settings, 신뢰 경로의 `--settings`, `--disallowedTools` |
| ask | ⚠️ 재측정 대기 (아래) | 강제 근거로 세지 않는다 |
| mode | 기본값이 버전마다 달랐다 (아래) | `--permission-mode`로 항상 명시 |
| allow | "Allow rules have no effect in `bypassPermissions`." | `dontAsk` + `--allowedTools` |
| hook | 실패하거나 timeout이 나면 대부분 그대로 실행된다 | 보조 수단 (§hook·plugin이 돌지 않는 경우) |

- **mode 기본값.** 모드를 지정하지 않은 `claude -p`와 Agent SDK run은 Manual 모드로 시작한다. 이 모드에서는 "Calls needing approval are denied unless you approve them with an allow rule, hook, `canUseTool` callback, or `--permission-prompt-tool`." 모드를 주지 않은 `-p`의 `system/init`은 `"permissionMode":"default"`였다(✅ 로컬 실측 2026-11-06). 이 기본값은 버전에 따라 바뀐 적이 있으므로 모드는 플래그로 적는다.
- **잠근 run.** Agent SDK 문서의 권장 조합은 `allowedTools` + `dontAsk`다. `dontAsk`는 CLI `--permission-mode` 값으로도 받는다(✅ 로컬 실측 2026-11-06, `--help`. cli-reference도 같은 값을 나열한다). SDK에서 "`allowed_tools` does not constrain `bypassPermissions`." 그래서 "If you need `bypassPermissions` but want specific tools blocked, use `disallowed_tools`."
- **bypass.** `-p`에서는 "In this `-p` run, the few calls that would still prompt are denied instead". 문서는 이 형태에 컨테이너·VM·sandbox runtime과 비 root 사용자를 요구한다. `.claude/settings.json`·`.claude/settings.local.json`의 `defaultMode: "bypassPermissions"`는 무시된다. user·managed settings나 `--permission-mode`로 켠다.
- **bypass 차단.** `permissions.disableBypassPermissionsMode`를 `"disable"`로 둔다. "These are most useful in managed settings where they can't be overridden."
- **auto.** "Auto mode reduces permission prompts but does not guarantee safety." 분류기는 실제 overeager 행동 n=52에서 "17% FNR"이다(`vendor-claimed`). `-p`에서 차단이 "3 times in a row or 20 times total"에 이르러도 "Claude Code doesn't stop the run." 이 문장은 반복 차단 임계값에만 해당한다. 분류기가 답을 주지 못하면 10회 연속 뒤 턴이 멈춘다.
- **`--permission-prompts none`.** "Anything that would prompt is denied unless a `PermissionRequest` hook allows it". 활성 모드(auto 포함)는 계속 판정한다.
- **subagent.** "The subagent inherits `plan`, `acceptEdits`, `auto`, or `bypassPermissions` from the main session". 메인이 `default`나 `dontAsk`이면 subagent에 지정한 `bypassPermissions`는 적용되지 않는다.
- **mod 예외.** "With neither managed settings nor a Team or Enterprise `/login` as the session's credential, the mod can approve a call that a deny rule refuses or a `PreToolUse` hook blocked." managed settings 없이 API 키나 `CLAUDE_CODE_OAUTH_TOKEN`으로 도는 무인 run이 여기에 해당한다. runner에 mod를 설치하지 않거나 managed settings를 둔다.

### ask 규칙 — ⚠️ 재측정 대기

- 공식 permission-modes 문서: "Claude Code doesn't auto-approve the following in any mode, including `bypassPermissions`". 그 목록의 첫 항목이 "Tools matched by an explicit ask rule"이다.
- 이 레포의 ADR 0009 P8(2026-08-25 실측, 대화형 bypass)은 ask 규칙에 걸린 명령이 그대로 실행되는 것을 관찰했다. 그 뒤 검증일까지 CHANGELOG에는 이 동작을 바꿨다는 항목이 없다.
- 재측정 전까지 무인 run의 강제 근거는 deny뿐이다. ask에 기대는 승인 절차를 설계하지 않는다. 재측정 결과는 [ADR 0009](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/adr/0009-enforcement-layer-placement.md)에 기록된다.

## hook·plugin이 돌지 않는 경우

| 조건 | 결과 |
|---|---|
| `--bare` | "Hooks still don't run in bare mode when you pass them with `--settings`" 문서는 이어서 "Don't use bare mode for a run that needs them."라고 쓴다 |
| `--bare` 기본값 전환 | "`--bare` is the recommended mode for scripted and SDK calls, and will become the default for `-p` in a future release." 시점은 문서에 없다 |
| bare가 아닌 `-p` | "a `-p` session runs the hooks in a project's `.claude/settings.json` and connects the servers in its `.mcp.json`, even in a folder you've never trusted." |
| `-p`의 plugin monitor | "plugin monitors don't start in non-interactive mode with the `-p` flag" |
| plugin `settings.json` | "Two keys take effect, `agent` and `subagentStatusLine`, and every other key is dropped." |
| plugin agent frontmatter | `hooks`, `mcpServers`, `permissionMode`는 무시된다 |
| hook 실패·timeout | "On most events, when a hook fails or times out, Claude Code still carries out the action." command hook 기본 timeout은 600초다 |

- 정책 hook은 "If your hook is meant to enforce a policy, use `exit 2`." 실패를 차단으로 바꾸려면 `onFailure: "block"`을 쓴다.
- `PermissionRequest`는 "Exit code 2 isn't honored for this event"라서 decision 객체로 거부한다. 프롬프트를 띄울 수 없는 세션에서도 "Claude Code still runs these hooks, and if no hook returns a decision, it denies the tool call."
- settings 파일·managed policy·plugin의 hook은 subagent 안에서도 돈다: "Hooks from settings files, managed policy settings, and plugins also run inside subagents." 무시되는 것은 plugin agent frontmatter의 `hooks`다.
- 외부 PR을 체크아웃한 job에서 bare가 아닌 `-p`를 돌리면, PR이 바꾼 hook과 `.mcp.json`이 그대로 실행·연결된다(위 문서 문장에서 바로 나오는 결과). 이런 job은 `--bare`로 돌린다. bare에서 settings는 `--settings`로 넘긴다.
- bare는 "never reads OAuth credentials or the system keychain"이라 `ANTHROPIC_API_KEY`나 `--settings`의 `apiKeyHelper`가 있어야 한다. 구독 OAuth 토큰만으로 인증하는 job은 bare로 돌릴 수 없다. 키 없이 돌린 bare run은 모델을 부르지 않고 exit 1로 끝났다(✅ 로컬 실측 2026-11-06).
- ⚠️ bare에서 `--settings`로 넘긴 deny가 적용되는지는 측정하지 못했다. 위 실측은 API 키가 없어 모델 호출 전에 끝났고, 문서에도 이 내용이 없다. bare job은 §Verification Criteria 1의 dry-run을 `--bare`로도 돌려 `permission_denials`를 확인한다.

정리하면, 가드레일은 deny에 두고 hook은 기록·알림 같은 보조 용도로 쓴다.

## MCP 로딩 (`-p`·SDK)

- `-p`와 Agent SDK는 `.mcp.json` 승인 프롬프트를 띄울 수 없어서 "it loads project-scoped servers without asking".
- 막는 수단: `disabledMcpjsonServers`("blocks it in every permission mode"), `--setting-sources`, `--strict-mcp-config`. `--bare`에서는 "only servers supplied on the command line connect". 필요한 서버는 `--mcp-config`로만 넘긴다.
- runner에 `managed-mcp.json`이 있으면 `--strict-mcp-config`는 시작 시 종료된다. 이 파일은 배타 제어다: "Users can't add, modify, or use any other MCP servers, including plugin-provided servers and servers passed with the `--mcp-config` CLI flag."
- OAuth: "A `claude -p` or Agent SDK run has no `/mcp` panel, so Claude Code can't run the OAuth flow there." OAuth가 필요한 서버는 `-p`에서 인증을 끝낼 수 없으므로 게이트에서 `mcp_servers[].status`가 `"connected"`가 아닌 것으로 잡는다.
- 권한 규칙: 서버 전체는 `mcp__<server>__*`, 도구 하나는 `mcp__<server>__<tool>`. "To match a parameter on an MCP tool, pass a deny rule with `--disallowedTools`. When Claude Code loads a settings file, it skips any `mcp__` rule that has parentheses."
- 운영 MCP 서버의 자격 증명 경계, 서버 read-only 모드, 운영 데이터 불신은 `/security:ops-mcp-security`에서 다룬다.

## 실패한 run 판정

exit 0은 성공의 증거가 아니다. deny에 막힌 run과 MCP 서버 연결에 실패한 run은 둘 다 exit 0, `subtype: "success"`로 끝났고, 흔적은 `permission_denials`와 `mcp_servers[].status`에만 남았다(✅ 로컬 실측 2026-11-06). 문서도 `--mcp-config` 항목이 검증에서 빠질 때 "The run continues and exits cleanly"라고 쓴다.

| 신호 | 위치 | 실패 조건 |
|---|---|---|
| exit code | 프로세스 | 0이 아님. `--max-turns` 초과는 exit 1이었다(✅ 로컬 실측). SIGTERM이면 "Claude Code exits with code 143"이고 진행 중이던 턴은 "records no result for it" |
| `is_error`, `subtype` | result 메시지 | `is_error`가 true이거나 `subtype`이 `"success"`가 아님. `--max-turns` 초과는 `is_error: true`, `subtype: "error_max_turns"`였다(✅ 로컬 실측). SDK 레퍼런스의 오류 subtype은 이것과 `error_during_execution`, `error_max_budget_usd`, `error_max_structured_output_retries`이고, `is_error`는 성공·오류 양쪽에서 `boolean`으로만 선언돼 있다 |
| `permission_denials` | 마지막 result 메시지 | 비어 있지 않음. "the final result message lists them in `permission_denials`". 스트림의 거부 이벤트는 best-effort라서 SDK 레퍼런스는 이 필드를 "the authoritative record"라고 쓴다 |
| `structured_output` | result 메시지 | `--json-schema`(print mode only)를 썼는데 없음. "Before your script uses `structured_output`, check that the field is present." |
| `plugin_errors` | `system/init` | 비어 있지 않음 |
| `mcp_server_errors` | `system/init` | 비어 있지 않음("so a CI gate can fail on a non-empty array"). 단 "`--mcp-config` entries skipped by config validation"만 담고, 연결 실패는 여기 오지 않았다(✅ 로컬 실측) |
| `mcp_servers[].status` | `system/init` | `"connected"`가 아님. 실행 파일이 없는 서버는 `"failed"`였다(✅ 로컬 실측) |

- **빈 값.** 문서는 오류가 없으면 `plugin_errors`·`mcp_server_errors` 키를 생략한다고 쓰지만, 실측에서는 두 키가 `null`로 나왔다(❌ 문서와 불일치, ✅ 로컬 실측 2026-11-06). 게이트는 둘 다 `// []`로 받는다.
- **status 값.** SDK 레퍼런스의 `McpServerStatus`는 `"connected" | "failed" | "needs-auth" | "pending" | "disabled"`다. `system/init` 타입은 `status: string`으로만 선언하므로 게이트는 `"connected"`가 아닌 값을 모두 실패로 본다. `disabled`는 독자가 일부러 끈 서버만 이름을 `disabled_ok`에 적어 통과시킨다. 문서상 도구 목록이 캐시된 원격 서버는 init에 `pending`으로 나오고 첫 도구 호출 때 연결되는데, 이 게이트는 그것도 실패로 본다.
- **출력 형식.** 문서는 `system/init`을 `stream-json`의 이벤트("the first event in the stream")로 설명한다. `-p`에서 `stream-json`은 `--verbose` 없이 exit 1로 끝난다(✅ 로컬 실측). 게이트는 출력 줄을 `jq -s`로 모아서 보고, init이 없으면 실패한다.

```bash
# run.sh — 값은 예시. --max-budget-usd 산정은 token-budget 참조
rc=0
claude -p "$PROMPT" \
  --output-format stream-json --verbose \
  --permission-mode dontAsk \
  --allowedTools "Read" "Grep" "Bash(kubectl get *)" \
  --max-turns 20 --max-budget-usd 2 \
  --model claude-sonnet-5-5 > run.jsonl || rc=$?
gate=0
# --json-schema 를 썼으면 schema 를 true 로. disabled_ok 는 일부러 끈 MCP 서버 이름
jq -rs --argjson schema false --argjson disabled_ok '[]' \
  -f gate.jq run.jsonl || gate=$?
if [ "$rc" -ne 0 ] || [ "$gate" -ne 0 ]; then
  echo "run 실패: claude exit $rc, gate exit $gate" >&2
  exit 1
fi
```

```jq
# gate.jq — 위반을 모아 error 로 끝낸다 (jq exit 5)
(map(select(.type == "system" and .subtype == "init")) | first) as $init
| (map(select(.type == "result")) | last) as $res
| [ (if $init == null then "system/init 없음" else empty end),
    (if $res == null then "result 없음" else empty end),
    (if ($res.is_error // false) or (($res.subtype // "success") != "success")
       then "result: \($res.subtype) (is_error=\($res.is_error))" else empty end),
    (($res.permission_denials // [])[] | "permission_denials: \(tojson)"),
    (($init.plugin_errors // [])[] | "plugin_errors: \(tojson)"),
    (($init.mcp_server_errors // [])[] | "mcp_server_errors: \(tojson)"),
    (($init.mcp_servers // [])[]
       | select(.status != "connected")
       | select((.status == "disabled" and (.name | IN($disabled_ok[]))) | not)
       | "mcp_servers: \(tojson)"),
    (if $schema and (($res // {}) | has("structured_output") | not)
       then "structured_output 없음" else empty end)
  ]
| if length == 0 then "gate: ok" else error("gate: " + join("; ")) end
```

- run.sh는 claude가 0이 아닌 코드로 끝나도 게이트를 돌려 원인을 로그에 남긴다. 게이트 인자 `schema`·`disabled_ok`를 빠뜨리면 jq가 컴파일 오류(exit 3)로 끝나 닫힌 쪽으로 실패한다. 두 파일은 실측 출력(deny 차단, MCP 연결 실패, `--max-turns` 초과, 빈 출력)에서 옮긴 형태와 통과 표본으로 확인했다(2026-11-06, jq 1.7.1, `bash -n`).
- 상한: `--max-turns`는 "No limit by default." `--max-budget-usd`는 "Stop the run once estimated spend on API calls reaches this amount (print mode only)." 추정치는 "can differ from your bill"이고, "Spend can pass the cap, so leave headroom." ⚠️ `--max-budget-usd`에 걸린 run의 exit code와 result는 측정하지 않았다. SDK 레퍼런스의 `error_max_budget_usd` subtype으로 끝나면 게이트의 subtype 조건이 잡는다.
- auto 모드 run은 반복 차단 임계값을 넘어도 멈추지 않는다. 차단을 run 종료로 알아챌 수 없으니 출력과 이벤트에서 찾는다.

## 예약·클라우드 실행

### cloud scheduled task (research preview)

Pro, Max, Ultra, Team, Enterprise 플랜에서 쓸 수 있다.

| 항목 | 동작 |
|---|---|
| 소유 | "Scheduled tasks belong to your individual claude.ai account. They are not shared with teammates". 커밋·PR·Slack 메시지는 소유자 명의로 나간다 |
| 승인 | "The fired prompt is therefore not live user input and can't act as approval or consent for actions during the run." |
| fire payload | `<routine-fire-payload>` 블록에 담기며 이 블록은 "labels it as untrusted data". 그 텍스트대로 행동하려면 "a routine's saved prompt must opt in to acting on fire text" |
| 권한 | "that session begins in auto mode unless auto mode is unavailable". ask 규칙에 걸리거나 반복 차단되면 "a permission prompt appears in the run's session and waits until someone answers it" |
| connector | "All of your connected MCP connectors are included by default." "Claude can use an included connector during a run, including writes." |
| 네트워크 | Default 환경은 허용 목록 밖 호스트에 `403`과 `x-deny-reason: host_not_allowed`를 돌려준다. connector 트래픽은 Anthropic 서버를 거친다 |
| GitHub 연결 | "After 72 hours without a connection, the task turns off" |

| 상한 대상 | 상한 | 넘으면 |
|---|---|---|
| 예약 실행 | 계정당 100/시간 | 대기 |
| Run now·API fire·재실행 | task당 30/시간 | 실패 |
| API fire | 계정당 100/시간 | 실패 |
| GitHub 이벤트 | task별·계정별 시간당 상한. ⚠️ 수치는 문서에 없다(한도 표도 같은 절을 가리킨다) | "Events beyond the limit are dropped until the window resets." |
| cron 식 | "Expressions that run more often than once per hour are rejected." | — |

쓰기까지 되는 connector가 기본으로 붙으므로 run에 필요 없는 connector는 뺀다. ask나 반복 차단이 run을 사람 응답 대기로 세울 수 있다는 점도 전제로 둔다.

### `/loop`

"A session can hold up to 50 scheduled tasks at once." "Recurring tasks automatically expire 7 days after creation." 세션에 묶이고 7일이면 끝나므로 상시 운영 경로가 아니다.

### GitHub Actions schedule

- "In a public repository, scheduled workflows are automatically disabled when no repository activity has occurred in 60 days." GitHub Docs의 규칙이며 공개 저장소에만 해당한다. code.claude.com 문서에는 이 문장이 없다.
- schedule의 평문 프롬프트는 "Claude has no shell or GitHub API access until you grant the tools the prompt needs". 필요한 도구만 `claude_args`의 `--allowedTools`로 준다.

### Managed Agents·agent teams

Managed Agents는 `status: beta`(헤더 `managed-agents-2026-04-01`)이고, "Agent teams are experimental and disabled by default." 무인 운영의 기본 경로로 삼지 않는다.

## 관측

- 저장소 `.claude/settings.json`에 둔 OTel exporter 변수는 무시된다("so a repository can't use them to turn telemetry on"). 텔레메트리는 runner 쪽에서 켠다.
- 무인 run에서 볼 이벤트:

| 이벤트 | 보는 이유 |
|---|---|
| `claude_code.tool_decision` | 도구 허용·거부 판정 추적 |
| `claude_code.permission_mode_changed` | run 도중 모드가 바뀌었는지 |
| `claude_code.hook_execution_start`, `claude_code.hook_execution_complete` | 정책 hook이 실제로 돌았는지 (fail-open 감시) |
| `claude_code.api_retries_exhausted` | API 재시도 소진으로 끝난 run |

- "Claude Code doesn't set `gen_ai.usage.*` attributes." `gen_ai.usage.*`로 토큰 사용량을 모으는 대시보드에는 Claude Code run이 잡히지 않는다.

## Anti-Patterns

| 안티패턴 | 왜 깨지는가 | 대신 |
|---|---|---|
| `-p`·`--bare` run의 가드레일을 hook으로만 둔다 | `--bare` 에서는 settings 와 plugin 의 hook 이 실행되지 않는다(`--settings` 로 넘긴 hook 포함). `--bare`는 앞으로 `-p` 기본값이 된다. hook은 실패·timeout이면 대부분 그대로 실행한다 | deny로 옮기고 hook은 보조로 쓴다 |
| CI에서 deny 없이 `--dangerously-skip-permissions` | bypass에서는 allow가 효과가 없어 열거한 도구만 쓰게 할 수 없다. ask 동작은 재측정 대기다 | deny + 컨테이너·비 root, 아니면 `dontAsk` + `--allowedTools` |
| exit 0을 성공으로 판정 | deny에 막힌 run과 MCP 연결에 실패한 run도 exit 0, `subtype: "success"`였다(✅ 로컬 실측). 흔적은 `permission_denials`와 `mcp_servers[].status`에만 남는다 | §실패한 run 판정의 게이트 |
| 개인 cloud scheduled task를 팀 on-call로 쓴다 | 개인 계정 소유라 팀원과 공유되지 않고, 결과물이 소유자 명의로 나가고, ask·반복 차단이면 사람을 기다린다. GitHub 연결이 72시간 끊기면 꺼진다 | 팀이 소유하는 CI cron |
| `allowed_non_write_users: "*"`에 Bash까지 준다 | Cline post-mortem(2026-02-23): triage workflow가 `claude-code-action`에 이 조합을 줬고, 탈취된 토큰으로 `cline@2.3.0`이 게시됐다. "The exposure window was approximately 8 hours."(`vendor-claimed`, 자사 사후 보고) | write 권한 없는 사용자가 부르는 workflow에는 상태를 바꾸는 도구를 주지 않는다 |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[기능 검증]** — deny 대상 명령을 일부러 시킨 dry-run에서 `permission_denials`가 비어 있지 않고 게이트가 0이 아닌 코드로 끝난다. claude 자신은 exit 0, `subtype: "success"`로 끝나도 정상이다(✅ 로컬 실측)
   예: `--allowedTools "Bash(echo *)"`와 deny `Bash(echo PROBE_DENY *)`를 담은 `--settings`, `--permission-mode dontAsk`, `--output-format stream-json --verbose`로 `echo PROBE_DENY ok`를 시키는 `-p` run(`--max-turns 3 --max-budget-usd 0.05 --model claude-haiku-5-5`). bare job이면 `--bare`로도 돌린다
2. **[성능 / 안전성]** — deny 없는 bypass run이 0건이고, 모든 `claude -p` run에 `--max-budget-usd`와 `--max-turns`가, 모든 Action run의 `claude_args`에 `--max-turns`가 있다
   예: CI 정의에서 `bypassPermissions`·`--dangerously-skip-permissions`를 쓰는 job마다 deny 출처(managed settings, `--settings`, `--disallowedTools`)를 대조
3. **[일관성]** — 무인 run에 넘기는 deny·ask가 사용자 자신의 settings·승인 규칙과 같은 범위이고, ask에 기대는 부분은 ADR 0009 재측정 결과를 따른다
   예: plugin은 이 레포의 rule과 settings를 싣지 않으므로 설치한 쪽 settings가 기준이다. 이 레포라면 [settings.json](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/settings.json)의 deny를 무인 job의 `--settings`에도 싣고, ask 판정은 [ADR 0009](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/adr/0009-enforcement-layer-placement.md) 재측정 결과를 따른다

## 참조 스킬

- [pr-review-automation](../pr-review-automation/SKILL.md) — PR 리뷰 workflow 전체 구성. Action 옵션은 `claude_args`로 넘긴다
- [agent-autonomy-tiers](../agent-autonomy-tiers/SKILL.md) — 무인 run에 맡길 행동을 등급으로 나누고 등급마다 강제 수단을 고른다
- [token-budget](../token-budget/SKILL.md) — `--max-budget-usd`·`--max-turns` 값을 정할 때의 비용 계산
- `/security:ops-mcp-security` — 운영 MCP 서버의 자격 증명 경계, deny 규칙, 운영 데이터 불신

## Sources / Verified

전체 대조 기록과 정정 내역: [2026-11-06 AIOps·에이전트 운영 사실 검증](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-06-aiops-agent-ops-verification.md). 아래는 이 skill이 인용한 출처다.

- [headless](https://code.claude.com/docs/en/headless.md) — 검증일 2026-11-06 · ✅ verified · subagent. bare 인증·MCP 범위, init 키 생략 문장(❌ 실측과 불일치), `pending`, preview 표기 없음
- [permission-modes](https://code.claude.com/docs/en/permission-modes.md) — 검증일 2026-11-06 · ✅ verified · subagent. ⚠️ ask 규칙의 bypass 동작은 ADR 0009 재측정 대기
- [permissions](https://code.claude.com/docs/en/permissions.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [Agent SDK permissions](https://code.claude.com/docs/en/agent-sdk/permissions.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview.md) — 검증일 2026-11-06 · ✅ verified · subagent. preview 표기 없음
- [Agent SDK TypeScript reference](https://code.claude.com/docs/en/agent-sdk/typescript.md) — 검증일 2026-11-06 · ✅ verified · subagent. `McpServerStatus`, `SDKResultMessage`, `SDKPermissionDeniedMessage`
- [hooks](https://code.claude.com/docs/en/hooks.md) — 검증일 2026-11-06 · ✅ verified (대조한 항목 한정) · subagent
- [sub-agents](https://code.claude.com/docs/en/sub-agents.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [plugin components](https://code.claude.com/docs/en/plugins/components.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [mcp](https://code.claude.com/docs/en/mcp.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [managed-mcp](https://code.claude.com/docs/en/managed-mcp.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [cli-reference](https://code.claude.com/docs/en/cli-reference.md) — 검증일 2026-11-06 · ✅ verified · subagent. `--json-schema`, `--max-budget-usd` headroom, `--permission-mode` 값
- [routines](https://code.claude.com/docs/en/routines.md) — 검증일 2026-11-06 · ✅ verified · subagent. ⚠️ GitHub 이벤트 상한 수치는 문서에 없음
- [scheduled-tasks](https://code.claude.com/docs/en/scheduled-tasks.md) — 검증일 2026-11-06 · ✅ verified · subagent. preview 표기 없음
- [github-actions](https://code.claude.com/docs/en/github-actions.md) — 검증일 2026-11-06 · ✅ verified · subagent. `claude_args`, preview 표기 없음. ⚠️ `--max-budget-usd`는 문서에 없음
- [monitoring-usage](https://code.claude.com/docs/en/monitoring-usage.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [agent-teams](https://code.claude.com/docs/en/agent-teams.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [Managed Agents overview](https://platform.claude.com/docs/en/managed-agents/overview.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [GitHub Docs: events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) — 검증일 2026-11-06 · ✅ verified · subagent. 60일 규칙의 출처(code.claude.com 아님)
- [Claude Code CHANGELOG (raw)](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode) — 검증일 2026-11-06 · ✅ verified · subagent. 수치는 `vendor-claimed`, 글은 `/research/` 경로로 이동
- [Cline post-mortem](https://cline.bot/blog/post-mortem-unauthorized-cline-cli-npm) — 검증일 2026-11-06 · ✅ verified · subagent
- [claude-code-action action.yml](https://raw.githubusercontent.com/anthropics/claude-code-action/main/action.yml), [parse-sdk-options.ts](https://github.com/anthropics/claude-code-action/blob/main/base-action/src/parse-sdk-options.ts) — 검증일 2026-11-06 · ✅ verified · subagent. 입력 목록과 `claude_args` 처리(코드 확인, 동작 측정 아님)
- [로컬 실측](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-06-aiops-agent-ops-verification.md) — 검증일 2026-11-06 · ✅ 로컬 실측 · Claude (메인 세션). deny 차단, MCP 연결 실패, `--max-turns` 초과, `stream-json`과 `--verbose`, 키 없는 `--bare`, `--help`. ⚠️ bare에서 `--settings` deny 적용은 미측정
