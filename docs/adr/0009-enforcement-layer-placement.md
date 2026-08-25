# ADR 0009 — 실행 강제(enforcement) 레이어 배치: `permissions.deny`/`ask` 우선

- **Status**: Accepted
- **Date**: 2026-08-25
- **Driver**: [2026-08-24 harness 적합성 audit](../audit/2026-08-24-agent-harness-readiness.md) F4 (산문으로만 막는 외부 작업) / F10 (frontmatter 필드로는 `Bash` 안쪽 명령에 못 닿음) / F11 (이미 있던 hook 이 3.5개월째 0% 작동)
- **Depends on**: 없음
- **Supersedes**: [ADR 0004](0004-admit-baseline-sink.md) (admit baseline sink — 대상 hook 폐기로 무의미)
- **Related**: [ADR 0002](0002-tool-safety-pretooluse-hook.md) / [ADR 0005](0005-admit-deny-transition.md) (둘 다 본 ADR 과 함께 Rejected), [`user-approval.md`](../../.claude/rules/user-approval.md), [`multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md)

## Context

이 레포의 harness 는 **guides 만 있고 enforcement 는 0** 이었다. agent 34개 전부가 무제한 `Bash` 를 갖고, `gh pr comment` / `git push` / 변경형 `kubectl` / `argocd app sync` 를 기술적으로 실행할 수 있으며, [`user-approval.md`](../../.claude/rules/user-approval.md) §"에이전트에 외부 게시 권한 위임 금지" 가 **산문으로만** 이를 막고 있다 (F4).

Step 4 에서 이를 subagent frontmatter 의 `disallowedTools` / `permissionMode` 로 닫으려다 스펙상 불가임이 확인됐다 (F10):

| 수단 | 왜 안 되는가 |
|---|---|
| `disallowedTools` | 도구 이름 / MCP 패턴 단위만. `Bash` 안쪽 명령 단위 지정자 미지원 |
| `permissionMode` | 부모가 `bypassPermissions`/`acceptEdits` 면 override 불가, 부모가 auto mode 면 무시 |
| `disallowedTools: Bash` (전면 차단) | 리뷰어가 `terraform validate` / `helm template` / `trivy` / `git diff` 를 못 쓴다 |

그리고 착수 조사에서 **이미 강제력 레이어가 있었고 도입 이래 한 번도 발동한 적이 없다**는 사실이 드러났다 (F11). `control-plane` 의 PreToolUse `admit` hook 이 존재하지 않는 환경변수로 배선돼 있었고, hook 이 부르는 npm 패키지도 미배포였다. vitest 111건은 전부 green 이었는데 **순수 함수만 테스트하고 배선은 아무도 테스트하지 않았기 때문**이다.

F11 이 본 ADR 의 판단 기준을 하나 추가한다: **"강제된다"고 주장하는 자산은 그 주장이 거짓이 됐을 때 즉시 드러나야 한다.** 깨진 hook 은 0% 로 작동하면서 100% 로 보인다 — 산문보다 나쁘다.

## Decision

**A. `.claude/settings.json` 의 `permissions.deny` / `permissions.ask` 를 1순위 강제 수단으로 삼는다.** PreToolUse hook 은 이 둘로 표현할 수 없는 잔여분에만 쓰고, 쓸 때는 반드시 위반 fixture 를 함께 둔다.

### 두 층으로 나눈다

| 층 | 대상 | 근거 |
|---|---|---|
| **`deny`** — 세션 내에서 실행할 정당한 경우가 없는 것 | 변경형 `kubectl`(`apply`/`delete`/`patch`/`edit`/`scale`/`rollout`/`set image`/`annotate`/`label`), `argocd app sync`, `git push --force`, `git commit --no-verify`, `git branch -D` | `user-approval.md` 가 "소스 수정 → git → ArgoCD sync" 경로를 강제하므로 세션에서 직접 실행할 이유가 없다 |
| **`ask`** — 승인 프로세스가 존재하는 것 | `git push`, `gh pr create/comment/merge/close`, `gh issue create/close`, `gh release create` | 승인 흐름을 프롬프트로 구조화한다. `deny` 로 막으면 **사용자가 승인한 push 조차 불가능**해진다 |

### 왜 `permissions.deny` 인가

| 속성 | `permissions.deny` | PreToolUse hook |
|---|---|---|
| `Bash` 안쪽 명령 단위에 닿는가 | ✅ `Bash(git push *)` | ✅ |
| `bypassPermissions` 에서 유지되는가 | ✅ `deny` 는 공식 명시 + 실측 P2. ⚠️ **`ask` 는 대화형에서 무력** (실측 P8) | ✅ 실측 P3 (공식 문서엔 **기술 없음**) |
| subagent 에 적용되는가 | ✅ 실측 P5 | ✅ 실측 P5 |
| allow 규칙을 이기는가 | ✅ deny-first | ⚠️ hook 결정은 permission 규칙을 우회하지 못한다 |
| **조용히 죽는가** | ❌ 선언형 — 무효 규칙은 startup warning | ⚠️ **exit 1 / 실행 실패 / timeout 이 전부 비차단**. F11 이 이것 |

마지막 행이 결정적이다. 같은 일을 할 수 있으면 **실패가 드러나는 쪽**을 고른다.

## 실측 (2026-08-25)

격리된 임시 디렉터리에서 sentinel 명령(`echo ENFORCE_PROBE_*`)으로만 측정했다. 파괴적 명령은 사용하지 않았다. 하니스: `claude -p --settings <probe> --model claude-haiku-4-5-20251001`, CLI **v2.1.245**.

probe 설정: `deny: ["Bash(echo ENFORCE_PROBE_DENY *)"]`, `ask: ["Bash(echo ENFORCE_PROBE_ASK *)"]`, `PreToolUse` matcher `Bash` → `ENFORCE_PROBE_HOOK` 포함 시 `permissionDecision: deny`.

| # | 모드 | 입력 | 결과 | 답한 질문 |
|---|---|---|---|---|
| **P0** | bypass | `echo ENFORCE_PROBE_CONTROL ok` (+ allow) | **실행됨** | 음성 대조군 — 하니스가 전부 막는 게 아님 |
| **P1** | default | `echo ENFORCE_PROBE_DENY ok` + `--allowedTools "Bash(echo *)"` | **차단** | deny 가 allow 를 이긴다 (V8) |
| **P2** | **bypass** | 동일 | **차단** | "Deny rules block in every mode" 실증 (V5) |
| **P3** | **bypass** | `echo ENFORCE_PROBE_HOOK ok` | **차단** + `permissionDecisionReason` 이 모델에 전달 | ⚠️→✅ **PreToolUse hook 은 `bypassPermissions` 에서도 실행되고 차단한다** (공식 문서 미기재, V12) |
| **P4** | bypass, **비대화형 `-p`** | `echo ENFORCE_PROBE_ASK ok` + allow | **자동 승인 안 됨 — 승인 요구** | `-p` 에는 승인할 사람이 없어 차단으로 귀결 |
| **P4b** | default, 비대화형 | 동일 | 승인 요구 | 동일 |
| **P8** | bypass, **대화형 실세션** | `gh release create --help` / `gh issue close --help` / `gh pr comment --help` / `git push` (ask 층 4건) | **전부 그냥 실행됨** | 🔴 **`ask` 는 대화형 `bypassPermissions` 에서 무력이다** — 아래 §ask 층의 한계 |
| **P5** | bypass | **subagent 에 위임**해 `echo ENFORCE_PROBE_DENY ok` | **차단** | deny 가 subagent 의 `Bash` 에도 적용된다 (M1) |
| **P6 / P6c** | bypass | `true && echo …DENY` / `…CONTROL` | 차단 / **통과** | **복합 명령으로 우회되지 않는다** |
| **P7 / P7c** | bypass | `echo␣␣…DENY` / `…CONTROL` | 차단 / **통과** | **여분 공백으로 우회되지 않는다** |

hook 은 P1(default) / P2·P3·P5(bypass) 전부에서 발동했고, stdin JSON 에 `permission_mode` 와 `tool_input.command` 가 실제로 들어왔다 — **F11 이 참조하던 `$CLAUDE_TOOL` 계열 환경변수가 필요 없었다는 사실의 반증**이기도 하다.

P6/P6c · P7/P7c 는 공식 Warning("인자를 제약하는 Bash 패턴은 취약")의 **범위를 좁힌다**: 취약한 것은 URL·인자 *값* 을 제약하는 패턴이고, **명령 접두 단위 deny 는 복합·공백 변형에 견딘다.** 다만 이는 이번에 시험한 두 변형에 한정된 결과다 — 인자 값 제약은 여전히 쓰지 않는다.

> ⚠️ 미검증: 인용 우회(`e''cho`), 변수 치환(`C=kubectl; $C apply`), 스크립트 경유 실행. 그래서 `deny` 를 **유일한** 방어선으로 삼지 않는다 — [`user-approval.md`](../../.claude/rules/user-approval.md) 산문이 계속 1차 방어선이고 `deny` 는 그 아래 그물이다.

### ⚠️ `ask` 층의 한계 — 대화형 `bypassPermissions` 에서 무력 (2026-08-25 정정)

본 ADR 초판은 P4(비대화형 `-p`) 결과를 근거로 "`ask` 는 `bypassPermissions` 에서 유지된다" 고 적었다. **과잉 일반화였다.** 실세션에서 확인한 결과(P8):

| 실행 형태 | `ask` 규칙 |
|---|---|
| 대화형 + `default` / `auto` | 프롬프트가 뜬다 (공식 동작, 본 레포에서 미시험) |
| 대화형 + **`bypassPermissions`** | **그냥 실행된다.** 이 모드는 프롬프트 자체를 건너뛰므로 `ask` 의 유일한 효과가 사라진다 |
| 비대화형 `claude -p` | 승인할 사람이 없어 **차단**으로 귀결 (모드 무관) |

공식 문서가 "Deny rules block in every mode, including `bypassPermissions`" 와 "Allow rules have no effect in `bypassPermissions`" 는 명시하면서 **`ask` 는 언급하지 않는 것**이 이 동작과 일치한다.

**따라서 `ask` 층 11건은 본 레포의 상시 모드(대화형 bypassPermissions)에서 강제되지 않는다.** 산문 규약과 같은 수준이다. 이 사실을 숨기지 않고 표기하는 것이 F11 재발 방지의 요점이다 — "강제되는 것처럼 보이지만 아무것도 막지 않는" 상태를 만들지 않는다.

**선택지** (사용자 결정 대기):
1. 그대로 두고 한계를 명시 — `ask` 는 `default`/`auto` 모드와 비대화형 실행에서만 작동하는 층
2. 세션 모드를 `default` 또는 `auto` 로 바꾼다 — `ask` 가 의도대로 작동한다
3. `permissions.disableBypassPermissionsMode: "disable"` 을 settings.json 에 넣어 bypass 자체를 봉쇄 — `ask` 가 항상 작동하지만 사용자가 bypass 모드를 못 쓴다
4. `ask` 항목 일부를 `deny` 로 올린다 — 승인받은 작업조차 세션에서 못 하게 된다 (§Decision 의 두 층 근거와 충돌)

## 대안 비교

| 안 | 내용 | 채택 |
|---|---|---|
| **A. `permissions.deny`/`ask` 우선 + hook 보조** | 명령 단위 선언 규칙을 SSOT 로. hook 은 선언으로 표현 불가능한 것만 | ✅ |
| B. PreToolUse hook 단독 | 모든 판정을 스크립트 하나로 | ❌ F11 이 이 안의 실패다. 조용히 죽고, 공식 문서가 bypass 하 동작을 보장하지 않으며(실측으로만 확인), 배선 결함을 테스트가 못 잡는다 |
| C. agent 에서 `Bash` 제거, 메인이 검증 명령을 실행해 결과 주입 | 구조적으로 가장 강함 | ❌ 비용이 실질적이다. 리뷰어 11개(`code-reviewer` `k8s-reviewer` `terraform-reviewer` `gitops-reviewer` `observability-reviewer` `cicd-reviewer` `cicd-security-reviewer` `dockerfile-reviewer` `container-security-reviewer` `network-security-reviewer` `k8s-security-reviewer`)가 `terraform validate` / `helm template` / `trivy` / `git diff` 를 잃고, 메인이 무엇을 실행할지 미리 알 수 없어 왕복이 폭증한다. **A 가 같은 위협을 더 싸게 막는다** |

A 가 C 를 대체하는 근거: C 가 막으려는 것은 "agent 가 외부 상태를 바꾸는 것" 인데, P5 가 **deny 규칙이 subagent 의 `Bash` 안쪽까지 닿는다**는 것을 보였다. 도구 자체를 뺄 필요가 없다.

## Consequences

**얻는 것**
- `user-approval.md` 의 금지 항목 중 명령으로 표현 가능한 것이 **산문 → 실행 강제**로 승격된다
- agent 34개 전부에 별도 작업 없이 적용된다 (세션 단위 규칙이라 자산 수와 무관)
- `bypassPermissions` 세션(이 레포의 상시 모드)에서도 유지된다

**잃는 것 / 위험**
- **`ask` 층은 대화형 `bypassPermissions` 에서 아무것도 막지 않는다** (실측 P8). 본 레포의 상시 모드가 그것이라 `ask` 11건은 현재 산문과 동급이다 — §ask 층의 한계 참조
- `ask` 층은 반대로 비대화형(`claude -p`) 실행에서는 **승인 불가 = 사실상 차단**이 된다. CI/자동화에서 `git push` 가 필요하면 그 경로는 Claude 세션 밖에 둬야 한다
- `deny` 는 **사용자 본인에게도 적용**된다. 잘못 넣으면 승인받은 작업까지 막힌다 → 그래서 두 층으로 나눴다
- 인용/변수 우회는 미검증이다. 방어선이지 담장이 아니다

**착수 조건 (F11 재발 방지)**
- 강제 규칙은 [`scripts/validate-enforcement.sh`](../../scripts/validate-enforcement.sh) 가 `user-approval.md` 와 대조하고 CI `drift` job 이 게이트한다
- hook 을 추가할 경우 **위반 fixture 를 같은 커밋에** 넣는다. fixture 없는 hook 은 도입하지 않는다
- 런타임 검증(`make verify-enforcement`)은 `claude` CLI 가 필요해 **CI 에서 돌지 않는다**. 이 한계를 명시한 채로 로컬 게이트로 운용한다

## 검증

```bash
./scripts/validate-enforcement.sh     # 규칙 ↔ user-approval.md 드리프트 (CI)
make verify-enforcement               # sentinel 위반 시도 → 거절 단언 (로컬 전용)
```

## Sources

전 항목 **2026-08-25 fetch**. [`deep-thinking.md`](../../.claude/rules/deep-thinking.md) §2 출처 기록 의무 적용. **다음 재검증 2026-11** (분기).

| 출처 | 확인 내용 | 상태 |
|---|---|---|
| [code.claude.com/docs/en/permission-modes](https://code.claude.com/docs/en/permission-modes) | "Deny rules block in every mode, including `bypassPermissions`." / allow 규칙은 bypass 에서 무효 | ✅ |
| [code.claude.com/docs/en/permissions](https://code.claude.com/docs/en/permissions) | `Bash(git push *)` 지정자, `:*` 동치, `Bash(command:…)` 무시+warning, deny-first, "Hook decisions don't bypass permission rules" | ✅ |
| [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks) | hook event 31개, 입력=stdin JSON, exit 2=차단 / exit 1=비차단, PostToolUse 차단 불가, subagent frontmatter hooks | ✅ |
| [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) | frontmatter 16필드, settings.json hook 이 subagent 안에서도 실행, plugin subagent 는 `hooks`/`permissionMode` 무시 | ✅ |
| 본 ADR §실측 (P0~P8, CLI v2.1.245) | `bypassPermissions` 하 hook 동작 / subagent 적용 / 복합·공백 우회 불가 / **`ask` 는 대화형 bypass 에서 무력** | ✅ 실측 |
| 인용·변수 치환 우회 | 시험하지 않음 — 방어선의 상한을 주장하지 않기 위해 명시 | ⚠️ unverified |
