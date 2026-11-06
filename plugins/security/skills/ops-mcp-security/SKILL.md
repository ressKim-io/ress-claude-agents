---
name: ops-mcp-security
description: "운영 시스템에 붙는 MCP 서버를 자격 증명 경계, 서버 read-only 모드, Claude Code deny 규칙의 세 겹으로 묶고 운영 데이터를 신뢰하지 않는 입력으로 다룬다. Use when 에이전트에 Kubernetes·관측·CI 같은 운영용 MCP 서버를 연결하거나 그 권한과 보안 권고를 점검할 때."
---

# 운영 MCP 서버 보안

Kubernetes·관측·CI 같은 운영 시스템에 MCP 서버를 붙일 때 권한을 세 겹으로 묶고, 서버가 돌려주는 운영 데이터를 신뢰하지 않는 입력으로 다루는 기준이다. 경계는 서버 플래그가 아니라 서버가 쓰는 자격 증명이다.
외부 사실은 2026-11-06 원문 대조 기록 기준이다. 점수와 수치에는 입력 주체를 붙인다: `maintainer-entered`(저장소·제조사 권고에 maintainer 측이 넣은 점수), CNA 입력, 전역 DB 기재, `researcher experiment`(논문·연구자 보고의 실험값). 독립 검증된 수치는 없다.

## Quick Reference (결정 트리)

```
운영 MCP 서버를 에이전트에 연결한다
│
├─ Q1 쓰기 도구가 있는가? (서버의 tools/list 기준)
│     ├─ 있음 ──> 쓰기 도구 목록을 만든다 → Q4 의 deny 대상
│     └─ 없음 ──> 그래도 Q2 로. 읽기 도구로 kubeconfig·토큰이 새어 나간 사례가 있다
│
├─ Q2 서버가 쓰는 자격 증명이 read-only 인가?   ★ 실제 경계 (권한 조회로 확인)
│     ├─ 아니오 ─> 연결하지 않는다. 서버 전용 read-only 자격 증명을 만든다
│     └─ 예 ────> Q3
│
├─ Q3 서버 기본값은? (§서버별 기본 권한 표)
│     ├─ 쓰기가 기본으로 열림 ─> read-only 플래그·환경변수를 명시한다 (가드레일)
│     └─ 표에 없는 서버 ───────> 문서와 권고에서 표의 항목을 확인해 기록한다
│
├─ Q4 Claude Code deny 규칙이 있는가?
│     ├─ 없음 ──────> settings 에 mcp__<server>__<쓰기 도구> deny (괄호 없이)
│     └─ 인자 단위 ─> settings 가 아니라 --disallowedTools 로 넘긴다
│
├─ Q5 원격(http)으로 노출되는가?
│     ├─ loopback 만 ─> 기본 바인드가 유지되는지 확인한다
│     └─ 그 밖 ───────> 인증 필수. --allow-unauthenticated 금지 (§MCP 인가)
│
└─ Q6 한 세션에 [A] 신뢰할 수 없는 입력 · [B] 민감 시스템 접근 · [C] 상태 변경·외부 통신이
      모두 있는가? (Rule of Two. 운영 MCP 를 붙인 세션은 [B] 로 본다)
      ├─ 예 ──────> 세션을 나눈다. 조사 [AB] = 쓰기·외부 전송 deny / 실행 [BC] = 사람 승인, 원문 데이터 없이
      └─ 아니오 ──> 연결한다. 분기마다 서버 표와 권고를 다시 본다
```

## 세 겹 구성

세 겹은 서로 다른 것을 막는다. 한 겹이 뚫려도 나머지가 남도록 셋 다 건다.

| 겹 | 막는 것 | 막지 못하는 것 |
|---|---|---|
| 1. 자격 증명 | 서버가 무엇을 호출하든 API 단계의 쓰기 | 읽기 권한 안의 조회와 유출 |
| 2. 서버 read-only 모드 | 쓰기 도구의 노출과 호출 (구현이 맞을 때만) | 서버 구현 결함, 읽기 도구를 통한 자격 증명 노출 |
| 3. Claude Code deny | 이 에이전트의 쓰기 도구 호출 | 같은 서버에 붙는 다른 클라이언트, 서버 내부 결함 |

### 1. 자격 증명 — 실제 경계

서버 문서가 경계를 직접 자격 증명에 둔다.

- kubernetes-mcp-server: `read_only`·`require_oauth` 옵션은 "best-effort guardrails"이고 "They do not change the cluster permissions of the identity the server authenticates as."
- AKS-MCP: "Anyone who can invoke AKS-MCP tools effectively has the full Azure and Kubernetes privileges of the identity AKS-MCP is running under."

운영 기준:

- 서버마다 전용 identity를 만들고 쓰기 권한을 주지 않는다. 사람이 쓰는 admin kubeconfig나 클라우드 자격 증명을 재사용하지 않는다.
- 서버 프로세스가 읽을 수 있는 곳에 더 강한 자격 증명을 두지 않는다. 읽기 도구가 kubeconfig를 내보내 전체 클러스터 권한으로 이어진 사례가 있다(아래 사례 표의 #1415).
- 권한은 쓰기 요청을 보내 보지 말고 권한 조회로 확인한다. Kubernetes는 `kubectl auth can-i`("Check whether an action is allowed.")를 쓴다.

```bash
# RO_KUBECONFIG: 서버에 넘길 kubeconfig. NS·SA: 서버가 쓰는 서비스 어카운트
kubectl auth can-i --list --namespace="$NS" --kubeconfig="$RO_KUBECONFIG"   # 허용 동작 전체를 사람이 검토한다
# 쓰기 동작은 하나씩 물어 모두 거부되는지 본다. --as 는 묻는 쪽에 impersonation 권한이 필요하다
kubectl auth can-i delete pods -A --as="system:serviceaccount:$NS:$SA"
kubectl auth can-i create deployments.apps -A --as="system:serviceaccount:$NS:$SA"
```

- 에이전트가 셸로 자격 증명 파일에 닿을 수 있으면 자격 증명 프록시를 검토한다. Agent SDK 배포 문서의 설명은 "The agent can make API calls, but it never sees the credential itself."이다.
- 자격 증명의 발급·주입·회전은 [secrets-management](../secrets-management/SKILL.md)를 따른다.

### 2. 서버 read-only 모드 — 가드레일

- 켜 두되 경계로 세지 않는다. AKS-MCP 문서도 기본값 `readonly`를 "guardrail to reduce accidental damage"라고 부르고 "not a security boundary against a deliberately malicious caller"라고 적는다.
- 대부분 opt-in이다. 아래 표에서 기본이 제한 쪽인 서버는 AKS-MCP와 terraform-mcp-server뿐이다.
- 서버 플래그로 끈 쓰기 도구도 겹 3의 deny에 같이 적는다. 플래그 구현이 틀렸던 사례가 있다.

### 3. Claude Code deny 규칙 — 모델 밖의 차단

권한 모드와 상관없이 남는 것은 deny다. "Deny rules block in every mode, including `bypassPermissions`." 반면 "Allow rules have no effect in `bypassPermissions`."라서, allow 목록으로만 MCP 도구를 좁힌 구성은 bypass 세션에서 아무것도 막지 않는다.

문법(permissions 문서):

- "To match every tool from an MCP server, write `mcp__<server>__*`. To match one tool, write its full name, `mcp__<server>__<tool>`."
- deny·ask는 도구 이름 자리에 glob을 받는다. `mcp__*`는 모든 서버의 MCP 도구다. allow glob은 `mcp__<server>__` 접두어 뒤에서만 인정되고, 접두어 없는 allow glob은 건너뛴다.
- "To match a parameter on an MCP tool, pass a deny rule with `--disallowedTools`. When Claude Code loads a settings file, it skips any `mcp__` rule that has parentheses."

```json
{
  "permissions": {
    "deny": [
      "mcp__kubernetes__configuration_view",
      "mcp__kubernetes__resources_delete",
      "mcp__kubernetes__pods_delete",
      "mcp__argocd__<쓰기 도구>",
      "mcp__terraform__*"
    ]
  }
}
```

- `kubernetes`·`argocd`·`terraform`은 `claude mcp add`로 붙인 서버 이름이다. `resources_delete`·`pods_delete`는 kubernetes-mcp-server 문서의 `disabled_tools` 예시에 나오는 도구이고, 쓰기 도구 전부가 아니다.
- `<쓰기 도구>`에는 서버의 `tools/list`에 나온 이름을 그대로 쓴다. 이름을 나열한 deny는 새 버전에 추가된 쓰기 도구를 막지 못하므로, 서버를 올릴 때마다 목록을 다시 대조한다.
- 조사에 필요 없는 서버는 `mcp__<server>__*`로 통째로, MCP가 아예 필요 없는 무인 job은 `mcp__*`로 막는다.
- settings에 `mcp__<server>__<tool>(…)`처럼 괄호를 붙인 규칙은 로드할 때 건너뛴다. 적혀 있어도 막지 않는다.
- 서버 이름에 `__`를 넣지 않는다. 정규화된 서버 이름에 이중 밑줄이 있으면 v2.1.299 전에는 그 서버의 deny·ask가 적용되지 않았다(CHANGELOG 2.1.299).
- deny는 자신의 user·project settings나 조직의 managed settings에 둔다. 외부 PR을 체크아웃하는 무인 run이라면 PR이 바꿀 수 있는 project settings 대신 managed settings나 신뢰 경로의 `--settings`·`--disallowedTools`에 둔다. plugin으로는 배포되지 않는다. plugin `settings.json`은 "Two keys take effect, `agent` and `subagentStatusLine`, and every other key is dropped."
- 예외가 있다. "With neither managed settings nor a Team or Enterprise `/login` as the session's credential, the mod can approve a call that a deny rule refuses or a `PreToolUse` hook blocked." API 키나 `CLAUDE_CODE_OAUTH_TOKEN`으로 도는 세션이 여기에 해당한다.
- ask 규칙은 경계로 쓰지 않는다. 공식 문서는 "Claude Code doesn't auto-approve the following in any mode, including `bypassPermissions`"의 첫 항목으로 "Tools matched by an explicit ask rule"을 든다. 그러나 이 레포의 [ADR 0009](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/adr/0009-enforcement-layer-placement.md) P8 측정(CLI v2.1.245, 대화형 `bypassPermissions`)에서는 ask 규칙에 걸린 명령이 프롬프트 없이 실행됐고, 2.1.245~2.1.318 CHANGELOG에는 이 동작을 바꿨다는 항목이 없다. ⚠️ 재측정 대기 — 결과가 나올 때까지 쓰기 차단의 근거는 deny다.
- sandbox는 이 세 겹에 들어가지 않는다. "The sandbox covers shell commands only."

### 등록 범위와 조직 통제

- **범위:** "Local scope is the default." local 범위 서버는 `~/.claude.json`에 저장된다. 범위는 `-s` 또는 `--scope`로 정하고, `project`는 "shared with everyone in the project via the `.mcp.json` file"이다. 문서는 local을 "servers with credentials you don't want in version control"에 쓰라고 한다. 운영 자격 증명을 쓰는 서버는 local에 두고 `.mcp.json`에 넣지 않는다.

```bash
# SERVER_BIN: 버전·해시로 고정해 설치한 서버 실행 파일(§공급망). 서버의 read-only 플래그는 그 뒤에 붙인다
claude mcp add kubernetes --scope local --env KUBECONFIG="$RO_KUBECONFIG" -- "$SERVER_BIN"
```

- **무인 실행과 `.mcp.json`:** `claude -p`·Agent SDK는 `.mcp.json` 승인 프롬프트를 띄울 수 없어 "it loads project-scoped servers without asking". 막는 수단은 `disabledMcpjsonServers`("blocks it in every permission mode"), `--setting-sources`, `--strict-mcp-config`(승인 프롬프트 생략은 v2.1.246+)다.
- **조직 배타 제어:** `managed-mcp.json`을 배포하면 "Users can't add, modify, or use any other MCP servers, including plugin-provided servers and servers passed with the `--mcp-config` CLI flag." 경로는 macOS `/Library/Application Support/ClaudeCode/managed-mcp.json`, Linux·WSL `/etc/claude-code/managed-mcp.json`이다. 이 파일이 있으면 `--strict-mcp-config`는 시작 시 종료되므로 CI 스크립트와 함께 점검한다.
- **조직 허용·거부 목록:** 키는 `allowedMcpServers`와 `deniedMcpServers`이고, 항목마다 `serverUrl`·`serverCommand`·`serverName` 중 한 키를 쓴다. 허용 목록을 강제하려면 "set `allowedMcpServers` and `allowManagedMcpServersOnly: true` together". 잠그지 않으면 사용자 설정의 허용 목록이 병합돼 범위를 넓힐 수 있다. 거부 목록은 모든 범위에서 병합되고 "Nothing overrides a denylist match." `--strict-mcp-config`도 두 목록을 우회하지 못한다.

```json
{
  "allowManagedMcpServersOnly": true,
  "allowedMcpServers": [
    { "serverCommand": ["npx", "-y", "<패키지>@<고정 버전>"] },
    { "serverUrl": "https://mcp.internal.example.com/*" }
  ]
}
```

- 위 예는 managed settings 파일에 둔다. `serverName`으로는 막거나 허용하지 않는다: "A `serverName` entry, in either list, is not a security control." 사용자가 붙이는 이름이라 어떤 서버에든 같은 이름을 붙일 수 있다.
- `serverCommand`는 인자까지 순서대로 정확히 비교하고 "The `env` block isn't compared." 고정 버전이 든 명령만 허용하면 다른 버전의 실행은 로드되지 않는다. 그러나 서버에 넘기는 자격 증명은 이 목록이 보지 않으므로 겹 1에서 따로 확인한다.

## 서버별 기본 권한 표

> 검증일 2026-11-06 · **분기 재검증 대상**(다음 2027-02). 서버 기본값과 버전은 릴리스마다 바뀔 수 있으니, 버전을 올리면 그 행부터 다시 대조한다.

| 서버 | 확인 버전 (릴리스일) | 쓰기 제한 수단과 기본값 | 원격 바인드·인증 기본값 | 문서의 단서 |
|---|---|---|---|---|
| kubernetes-mcp-server (containers) | v0.1.2 (2026-11-04) | `read_only` 기본 `false`. 도구별 제외는 `disabled_tools` | `require_oauth` 기본 `false` | 옵션은 "best-effort guardrails". `configuration_view`는 HTTP 모드에서만 기본으로 빠진다 |
| mcp-server-kubernetes (Flux159) | v4.2.1 (2026-10-26) | opt-in 환경변수 `ALLOWED_TOOLS`, `ALLOW_ONLY_READONLY_TOOLS`, `ALLOW_ONLY_NON_DESTRUCTIVE_TOOLS` | — | `ALLOWED_TOOLS`·`ALLOW_ONLY_READONLY_TOOLS`는 README가 아니라 ADVANCED_README에 있다 |
| kubectl-mcp-server (rohitg00) | v2.0.0 (2026-10-22) | `--read-only` 기본 off | "HTTP binds `127.0.0.1` by default. Binding any other address requires OAuth or `--allow-unauthenticated`" | 켜면 쓰기 도구가 "removed from `tools/list` and rejected if called" |
| mcp-grafana (grafana) | v2.2.0 (2026-11-02) | `--disable-write`로 쓰기 도구를 끈다. 플래그가 없으면 쓰기 도구가 등록된다 | `--server-auth-token` 없이 non-loopback에 바인드하면 "starts but logs a security error" | 문서는 이 플래그를 "read-only mode"라고 부른다 |
| argocd-mcp (argoproj-labs) | v0.9.0 (2026-08-11) | `MCP_READ_ONLY` opt-in | bind 기본 `127.0.0.1`, `MCP_AUTH_TOKEN` 기본 unset. "Widening the bind requires `MCP_AUTH_TOKEN` or `--allow-unauthenticated`." | — |
| AKS-MCP (Azure) | v0.0.22 (2026-10-26) | `--access-level` 기본 `readonly` | — | "not a security boundary against a deliberately malicious caller" |
| terraform-mcp-server (hashicorp) | v1.4.1 (2026-10-23) | `ENABLE_TF_OPERATIONS` 기본 `false` | — | 이 변수의 설명은 "Enable tools that require explicit approval" |

`—`는 이번 검증에서 대조하지 않은 항목이다. 관리형 GKE MCP는 GA 여부가 ⚠️ unverified다(레퍼런스, how-to, supported products 표 어디에도 GA 문구나 Preview 표기가 없다). 기본 권한도 대조하지 않아 표에 넣지 않았다.

## read-only가 경계가 아니었던 사례

| 사례 | 무엇이 뚫렸나 | 범위·수정 |
|---|---|---|
| mcp-server-kubernetes (Flux159) CVE-2026-46519 / GHSA-cr22-wjx7-2w6m | read-only 제한이 `tools/list`에만 걸리고 `tools/call`에는 없었다. "The access control was effectively cosmetic." | `< 3.6.0`. high 8.8 (`maintainer-entered`, 저장소 권고). 공개일은 저장소 권고 2026-05-17, 전역 DB 2026-05-21 |
| kubernetes-mcp-server #1415 (2026-09-05) | read-only 모드에서 "with the `configuration_view` tool my agent gained full cluster access by exporting the kubeconfig" | PR #1442(2026-09-25 merge)는 http 모드만 바꿨다: "This by default disables the configuration_view tool in http mode." v0.1.2 소스도 HTTP일 때만 거른다(`!isHTTP \|\| …`). 기본 toolset `config`에 있고 `ReadOnlyHint: true`라 stdio에서는 `read_only`를 켜도 남는다 |
| awslabs postgres-mcp-server CVE-2026-87911 / GHSA-fph8-pg5w-78fv (2026-09-09) | "Read-only enforcement bypass enabling operating system command execution" | `< 1.1.7`. critical 9.6 (`maintainer-entered`, 저장소 권고) |
| AKS-MCP README | 결함이 아니라 설계 설명이다. 기본값 `readonly`가 경계가 아니라고 문서가 스스로 밝힌다(§세 겹 구성 2) | v0.0.22 기준 |

결론은 같다. 서버 플래그는 실수를 줄이는 장치이고, 의도적인 호출과 서버 결함, 읽기 도구를 통한 자격 증명 노출은 겹 1의 권한에서 멈춘다. stdio로 쓰는 kubernetes-mcp-server는 서버 설정 `disabled_tools`와 겹 3의 deny 양쪽에 `configuration_view`를 넣는다.

## 운영 데이터를 신뢰하지 않는 입력으로 다루기

로그·메트릭·알림·오류 이벤트·대시보드 텍스트에는 외부에서 쓴 문자열이 섞인다. Claude Code MCP 문서도 "Verify you trust each server before connecting it. Servers that fetch external content can expose you to prompt injection risk."라고 적는다.

| 연구·보고 | 보인 것 (원문) | 수치 라벨과 조건 |
|---|---|---|
| AIOpsDoom (arXiv 2508.06394 v2) | 오류를 유발하는 요청으로 텔레메트리를 오염시킨다. "adversaries can manipulate system telemetry to mislead AIOps agents into taking actions that compromise the integrity of the infrastructure they manage" | 평균 성공률 90%: `researcher experiment`, 연구 testbed (AIOpsLab 36개 조합 × 5회 = 180회) |
| LogJack (arXiv 2604.15368, 2026-04-15) | "verbatim command execution rates range from 0% (Claude Sonnet 4.6) to 86.2% (Llama 3.3 70B)". "Azure Prompt Shield detected only the most obvious payload (1/32), while GCP Model Armor detected none" | `researcher experiment`. 모델과 탐지기에 따라 크게 갈린다 |
| LogInject (arXiv 2607.14493, 2026-07-16) | "up to 88.2% attack success rate (83.4% average across models)". 다층 방어 후에도 "90.4% attack reduction, although 8.4% residual vulnerability persists" | `researcher experiment` |
| Agentjacking (Tenet, 2026-06-17) | 공개된 write-only Sentry DSN으로 가짜 오류를 넣는다. "Prompt-layer defenses failed." | "2,388 organizations found exposed with valid injectable DSNs": `researcher experiment`(연구자 스캔). OWASP Q2: "These are researcher-reported results, not a count of confirmed criminal breaches." |
| GrafanaGhost (Noma, 2026-04-07) | 로그에 심은 지시로 Grafana AI를 거쳐 데이터를 유출하는 체인 | 수치 없음. 제조사 반박(Grafana CISO, CyberScoop): "the end user would have to repeatedly instruct our AI assistant to follow malicious instructions contained in logs" |
| mcp-grafana #680 (2026-03-24 개설) | "Dashboard titles, panel descriptions, annotation text, or alert rule names can carry injected instructions" | 수치 없음. 2026-11-06 기준 open, `stale` 라벨 |

대응:

1. **프롬프트 층 방어를 경계로 쓰지 않는다.** Azure Prompt Shield와 GCP Model Armor가 거의 잡지 못했고(LogJack), "Prompt-layer defenses failed."(Agentjacking), 다층 방어 뒤에도 잔여 취약성이 남았다(LogInject).
2. **허용 조치는 모델 밖에서 정한다.** OWASP Q2 권고는 "Define permitted remediation actions independently of model instructions."이다. 이 skill에서 그 정의는 겹 1의 자격 증명과 겹 3의 deny다.
3. **세션을 나눈다.** Meta의 Rule of Two(2025-10-31)는 "agents must satisfy no more than two of the following three properties within a session"이다.
   - 세 속성은 [A] "An agent can process untrustworthy inputs", [B] "An agent can have access to sensitive systems or private data", [C] "An agent can change state or communicate externally"다.
   - 운영 MCP를 붙인 세션은 [B]로 본다. 그래서 운영 데이터를 읽는 조사 세션([AB])은 쓰기 도구와 외부로 보내는 도구를 deny한다. 상태 변경([BC])은 사람이 승인한 뒤, 원문 데이터를 넣지 않은 별도 세션이나 경로에서 한다.
   - 셋이 다 필요하면 원문은 새 세션 없이는 "the agent should not be permitted to operate autonomously and at a minimum requires supervision — via human-in-the-loop approval or another reliable means of validation"이라고 쓴다.
   - 운영 계열 예(High-Velocity Internal Coder [BC])는 "Hypothetical Examples and Implementations of the Agents Rule of Two" 절에 있어 배포 사례가 아니다. Meta는 이 규칙을 "a supplement — and not a substitute — for common security principles such as least-privilege"라고 하므로 겹 1을 대신하지 않는다.
4. **도구 메타데이터를 믿지 않는다.** MCP 사양은 "clients MUST consider tool annotations to be untrusted unless they come from trusted servers."라고 쓴다. 도구 설명도 서버가 보내는 텍스트이므로, annotation이나 설명을 근거로 deny를 빼지 않는다.

## 권고 추적과 공급망

### 권고 추적

운영 MCP 서버의 권고는 GitHub 전역 권고 DB에 늦게 오르거나 오르지 않고, 거꾸로 저장소 권고에 없는 것도 있다. 한 경로만 보는 스캐너는 아래 일부를 놓친다.

| 권고 | 대상·범위 | 내용 (원문) | 점수 (입력 주체) | 전역 DB |
|---|---|---|---|---|
| CVE-2026-63473 / GHSA-6m4w-cmhp-f95f | HolmesGPT (pip `holmesgpt`), 0.34.0 이상으로 올린다 | "When the built-in `bash` toolset is enabled, this becomes unauthenticated command execution as the HolmesGPT server process." | critical 9.8 (`maintainer-entered`, 저장소 권고) | `cve_id` 조회 결과 `[]` (`type` 무관) |
| GHSA-rp45-5x3v-48mr | argocd-mcp (npm `argocd-mcp`) `= 0.8.0` → `0.9.0` | "a network caller can create an MCP session without presenting any inbound credential" | critical 10.0 (`maintainer-entered`, 저장소 권고) | CVE 없음, 조회 404 |
| CVE-2026-19516 / GHSA-fr94-7cqc-vjrq | mcp-grafana, 수정 `>=1.1.0` (2026-08-11 공개) | `grafana_api_request`의 `X-Grafana-URL` 헤더로 목적지를 바꾸는 SSRF. 호출자가 "direct requests at internal, loopback, and link-local network services (including metadata endpoints) and read the responses" | CVSS 9.1 (`maintainer-entered`, Grafana Labs 권고) | `unreviewed`, 저장소 권고 0건 |
| CVE-2026-61459 / GHSA-wmg3-h8mf-wgvr | mcp-server-kubernetes (Flux159, npm) `< 3.9.0` → `3.9.0` | "Attackers can inject the --server flag to redirect kubectl commands to an attacker-controlled API server" | critical 9.8 (CNA 입력, VulnCheck) | reviewed. 저장소 권고 목록에는 없다 |
| CVE-2025-65719 / GHSA-94gr-w3q5-rfqr | kubectl-mcp-server `< 1.2.0` | "arbitrary code execution via user interaction with crafted HTML page" | critical 9.8 (전역 DB 기재) | reviewed |

- CVE-2025-65719는 악성 HTML 페이지를 통한 코드 실행이고 read-only 우회 사례가 아니다. kubectl-mcp-server의 `--read-only`는 쓰기 도구를 호출 단계에서도 거부한다.
- CVE-2026-61459는 `kubectl_get`·`kubectl_describe`·`kubectl_delete` 인자 주입이고, 결과는 "the operator's bearer token to be transmitted externally"다. 읽기 도구도 자격 증명을 내보내는 통로가 된다.
- 저장소 권고와 전역 DB를 둘 다 조회한다. 전역 DB는 다른 파라미터 없이 부르면 "only GitHub-reviewed advisories that are not malware"를 돌려주고, `cve_id`로 물으면 unreviewed도 나온다.

```bash
gh api --paginate "repos/$OWNER/$REPO/security-advisories" \
  --jq '.[] | [.ghsa_id, (.cve_id // "-"), .severity, .published_at, .summary] | @tsv'
gh api "/advisories?cve_id=$CVE" --jq '.[] | [.ghsa_id, .type, .severity] | @tsv'
```

- GitHub 문서는 게시된 저장소 권고를 검토해 전역 DB에 넣는 과정이 "can take up to 72 hours"라고 쓴다. 그러나 2026-11-06 조회에서 GHSA-6m4w(2026-07-26 게시), GHSA-rp45(2026-08-11), GHSA-fph8(2026-09-09)은 전역 DB에서 404였다.
- 제조사가 따로 권고 페이지를 두면 그것도 본다. CVE-2026-19516은 Grafana 권고에 있었고 저장소 권고는 0건이었다.
- 점수는 입력 주체와 함께 옮긴다. 저장소 권고는 "repository maintainers can publish the security advisory"이고, 전역 DB에만 있는 권고의 점수는 CNA가 넣은 값일 수 있다. 공개일은 어느 DB 기준인지 밝힌다.

### 공급망 — 버전과 해시 고정

- PyPI `litellm`: 공식 공지(상태 "Active investigation")는 "The compromised PyPI packages were litellm==1.82.7 and litellm==1.82.8."라고 쓴다.
- ⚠️ `1.107.0`은 제3자 신고이고 공식 확인이 없다. 전역 권고 GHSA-92x9-889m-jgmw(type `malware`, 2026-10-29 갱신)의 버전 목록에 `= 1.107.0`이 있지만, 근거인 #47826의 작성자는 `author_association: NONE`이고 댓글 가운데 MEMBER·OWNER·COLLABORATOR 댓글이 없다(2026-11-06 조회). LiteLLM 공식 공지나 maintainer 확인은 찾지 못했다.
- MCP 서버와 gateway·프록시는 정확한 버전과 해시로 고정한다. 그래야 권고의 영향 범위(`< 3.6.0`, `= 0.8.0` 같은)와 대조할 수 있고, 오염된 새 배포가 다음 설치에 조용히 들어오지 않는다.

```text
# requirements.txt (pip 문서 예시). --hash 가 하나라도 있으면 모든 요구사항이 고정(== 등)되고 해시를 가져야 한다
FooProject==1.2 \
    --hash=sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
```

```bash
pip install --require-hashes --only-binary :all: -r requirements.txt
npm ci   # package-lock.json 그대로 설치한다. package.json 과 맞지 않으면 lockfile 을 고치지 않고 오류로 끝난다
```

- pip: "Hashes are required for all dependencies." 그리고 "Requirements must be pinned (either to a URL, filesystem path or using ==)." pip 문서의 secure install은 `--require-hashes`와 소스 배포를 막는 `--only-binary :all:`을 함께 쓴다.
- npm: lockfile에는 패키지마다 `integrity`("A sha512 or sha1 Standard Subresource Integrity string")가 기록되고, `npm ci`는 "It will never write to package.json or any of the package-locks".
- `npx -y <패키지>@<버전>` 형태의 등록 명령에는 해시가 없다. 해시까지 고정하려면 서버 전용 디렉토리에 lockfile이나 해시가 든 requirements로 설치하고, 그 실행 파일을 `claude mcp add`에 등록한다.
- 고정 버전을 올릴 때는 그 구간의 권고와 §서버별 기본 권한 표를 같이 본다.

## MCP 인가 — 사양 2026-07-28

"The current protocol version is 2026-07-28." 운영 서버 연결에 닿는 조항만 옮긴다.

- **인가는 선택이다.** "Authorization is OPTIONAL for MCP implementations." 원격 서버가 인증 없이 떠 있어도 사양 위반이 아니므로, 바인드 주소와 인증을 서버마다 확인한다(§서버별 기본 권한 표).
- **STDIO는 환경변수 자격 증명을 쓴다.** STDIO 구현은 이 사양을 "SHOULD NOT follow this specification, and instead retrieve credentials from the environment". 로컬 서버의 경계는 환경변수로 넘긴 자격 증명이고, 그것이 겹 1이다.
- **인가를 구현하면** 서버는 RFC 9728, 클라이언트는 RFC 8707을 MUST로 구현한다. "MCP servers MUST NOT accept or transit any other tokens."
- **토큰을 전달하지 않는다.** "The MCP server MUST NOT pass through the token it received from the MCP client." 상류 API에는 클라이언트 토큰이 아니라 서버 쪽 자격 증명이 쓰여야 하고, 그 권한이 겹 1이다. 원격 서버나 gateway를 평가할 때 클라이언트 토큰을 상류로 넘기는지 확인한다.
- **확장도 선택이다.** "MCP extensions are optional additions to the specification". OAuth Client Credentials와 Enterprise-Managed Authorization은 둘 다 `Stable`이지만, 쓰려는 서버와 클라이언트가 지원하는지는 따로 확인한다.
- **무인 실행에서는 OAuth를 돌릴 수 없다.** "A `claude -p` or Agent SDK run has no `/mcp` panel, so Claude Code can't run the OAuth flow there." OAuth가 필요한 원격 서버를 무인 경로에 넣기 전에 이 제약부터 본다.

## Anti-Patterns

| 안티패턴 | 왜 문제인가 | 대신 |
|---|---|---|
| 서버 read-only 플래그를 경계로 센다 | `tools/list`만 거른 구현(CVE-2026-46519), 읽기 도구를 통한 kubeconfig 노출(#1415), OS 명령 실행으로 이어진 read-only 우회(CVE-2026-87911)가 있었다 | 자격 증명을 read-only로 만들고 플래그는 가드레일로만 센다 |
| 사람이 쓰는 운영 admin kubeconfig를 서버에 준다 | 도구를 부를 수 있는 쪽이 그 identity의 권한 전부를 갖는다(AKS-MCP 문서) | 서버 전용 read-only identity |
| 인증 없이 non-loopback에 바인드한다 | 인가는 사양상 선택이다. argocd-mcp `0.8.0`은 자격 증명 없이 세션을 열 수 있었다(GHSA-rp45-5x3v-48mr) | loopback을 유지하고, 넓힐 때는 토큰이나 OAuth를 건다. `--allow-unauthenticated`는 쓰지 않는다 |
| tool 설명·annotation을 보고 deny를 뺀다 | 사양은 신뢰하지 않는 서버의 annotation을 불신하라고 한다. 설명도 서버가 보내는 텍스트다 | 도구 이름 기준으로 deny하고, 업그레이드마다 `tools/list`를 다시 대조한다 |
| 버전을 고정하지 않은 서버·gateway | 오염 배포(`litellm==1.82.7`·`1.82.8`)가 다음 설치에 그대로 들어오고, 권고의 영향 범위와 대조할 수도 없다 | 정확한 버전과 해시로 고정하고, 올리기 전에 권고를 대조한다 |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[기능 검증]** — 운영 MCP 서버마다 read-only 자격 증명과 `mcp__<server>__<쓰기 도구>` deny 규칙이 있고, 쓰기 도구 호출이 거부된다
   예: 같은 settings와 서버 설정을 비운영 대상에 붙여 deny한 쓰기 도구를 호출하게 하고 거부되는지 본다. 자격 증명은 쓰기 요청을 보내지 말고 권한 조회로 확인한다. Kubernetes라면 `kubectl auth can-i <쓰기 동사> <리소스> -A`가 모두 거부되고, `--list`로 본 허용 동작을 사람이 검토했다
2. **[성능 / 안전성]** — 허용 목록 밖의 쓰기 도구 노출, 인증 없는 non-loopback 바인딩, 버전 미고정 서버와 gateway가 모두 0건이다
   예: 서버마다 `tools/list`의 쓰기 도구, 바인드 주소와 인증 설정, 설치 명세의 버전·해시(pip `--hash`, npm lockfile `integrity`)를 한 표로 점검한다
3. **[일관성]** — 사용자 자신의 settings에 있는 deny 범위와 서버 쪽 설정(read-only 모드, `disabled_tools`, 자격 증명 권한)의 범위가 일치한다
   예: 서버 플래그나 `disabled_tools`로 끈 도구가 deny에도 있다. plugin으로는 deny를 배포할 수 없으므로 기준은 사용자 settings와 팀의 승인 규칙이다. 이 레포의 [settings.json](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/settings.json)과 [user-approval.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/user-approval.md)는 예시일 뿐이다

## 참조 스킬

- [secrets-management](../secrets-management/SKILL.md) — 서버에 넘길 read-only 자격 증명을 K8s Secret·Vault 등으로 주입하고 회전할 때
- [threat-modeling](../threat-modeling/SKILL.md) — 운영 MCP 연결의 공격 표면을 STRIDE로 정리해 위협 모델 문서로 남길 때
- `/ai:agentic-ai-architecture` — MCP·A2A 비교와 가드레일 아키텍처. 이 skill은 그중 운영 서버 연결의 권한과 보안만 다룬다

## Sources / Verified

외부 사실은 모두 [AIOps·에이전트 운영 사실 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-06-aiops-agent-ops-verification.md)에서 원문과 대조한 행을 옮겼다. 따옴표 안은 원문 문자열이다. 서버 기본값·버전·권고는 분기마다 다시 본다.

**Claude Code 문서**
- [permissions](https://code.claude.com/docs/en/permissions.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [permission-modes](https://code.claude.com/docs/en/permission-modes.md) — 검증일 2026-11-06 · ✅ verified (문서 문구) · subagent. ⚠️ ask 규칙의 bypass 실제 동작은 재측정 대기
- [mcp](https://code.claude.com/docs/en/mcp.md) — 검증일 2026-11-06 · ✅ verified (`--scope` 포함) · subagent
- [managed-mcp](https://code.claude.com/docs/en/managed-mcp.md) — 검증일 2026-11-06 · ✅ verified (허용·거부 목록 키 포함) · subagent
- [plugins/components](https://code.claude.com/docs/en/plugins/components.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [sandboxing](https://code.claude.com/docs/en/sandboxing.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [agent-sdk/secure-deployment](https://code.claude.com/docs/en/agent-sdk/secure-deployment.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [Claude Code CHANGELOG (raw)](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) — 검증일 2026-11-06 · ✅ verified (2.1.245~2.1.318 구간, 2.1.299 포함) · subagent
- [ADR 0009](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/adr/0009-enforcement-layer-placement.md) — 검증일 2026-08-25 · ⚠️ P8(v2.1.245) 관찰이 현행 문서와 반대, 재측정 대기 · 레포 실측

**MCP 서버 문서·소스**
- [kubernetes-mcp-server configuration.md](https://github.com/containers/kubernetes-mcp-server/blob/main/docs/configuration.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [kubernetes-mcp-server v0.1.2 tool_filter.go](https://github.com/containers/kubernetes-mcp-server/blob/v0.1.2/pkg/mcp/tool_filter.go), [configuration.go](https://github.com/containers/kubernetes-mcp-server/blob/v0.1.2/pkg/toolsets/config/configuration.go) — 검증일 2026-11-06 · ✅ verified (소스 대조, 실행 측정 아님) · subagent
- [mcp-server-kubernetes ADVANCED_README](https://github.com/Flux159/mcp-server-kubernetes/blob/main/ADVANCED_README.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [kubectl-mcp-server README](https://github.com/rohitg00/kubectl-mcp-server) — 검증일 2026-11-06 · ✅ verified · subagent
- [mcp-grafana README](https://github.com/grafana/mcp-grafana) — 검증일 2026-11-06 · ✅ verified (v2.2.0) · subagent
- [argocd-mcp README](https://github.com/argoproj-labs/mcp-for-argocd) — 검증일 2026-11-06 · ✅ verified · subagent
- [AKS-MCP README](https://github.com/Azure/aks-mcp) — 검증일 2026-11-06 · ✅ verified · subagent
- [terraform-mcp-server README](https://github.com/hashicorp/terraform-mcp-server) — 검증일 2026-11-06 · ✅ verified · subagent
- [GKE MCP reference](https://docs.cloud.google.com/kubernetes-engine/docs/reference/mcp), [how-to](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/use-gke-mcp), [supported products](https://docs.cloud.google.com/mcp/supported-products) — 검증일 2026-11-06 · ⚠️ GA 명시 문구도 Preview 표기도 없음 · subagent

**권고·이슈**
- [GHSA-cr22-wjx7-2w6m](https://github.com/Flux159/mcp-server-kubernetes/security/advisories/GHSA-cr22-wjx7-2w6m) — 검증일 2026-11-06 · ✅ verified · subagent
- [kubernetes-mcp-server #1415](https://github.com/containers/kubernetes-mcp-server/issues/1415), [PR #1442](https://github.com/containers/kubernetes-mcp-server/pull/1442) — 검증일 2026-11-06 · ✅ verified (stdio 잔존은 v0.1.2 소스로 확인) · subagent
- [GHSA-fph8-pg5w-78fv](https://github.com/awslabs/mcp/security/advisories/GHSA-fph8-pg5w-78fv) — 검증일 2026-11-06 · ✅ verified · subagent
- [GHSA-6m4w-cmhp-f95f](https://github.com/HolmesGPT/holmesgpt/security/advisories/GHSA-6m4w-cmhp-f95f) — 검증일 2026-11-06 · ✅ verified (구조화 필드와 본문의 패치 버전이 달라 0.34.0 이상으로만 적는다) · subagent
- [GHSA-rp45-5x3v-48mr](https://github.com/argoproj-labs/mcp-for-argocd/security/advisories/GHSA-rp45-5x3v-48mr) — 검증일 2026-11-06 · ✅ verified · subagent
- [Grafana CVE-2026-19516](https://grafana.com/security/security-advisories/cve-2026-19516/), [GHSA-fr94-7cqc-vjrq](https://github.com/advisories/GHSA-fr94-7cqc-vjrq) — 검증일 2026-11-06 · ✅ verified · subagent
- [GHSA-wmg3-h8mf-wgvr](https://github.com/advisories/GHSA-wmg3-h8mf-wgvr), [CVE-2026-61459 레코드](https://cveawg.mitre.org/api/cve/CVE-2026-61459) — 검증일 2026-11-06 · ✅ verified · subagent
- [GHSA-94gr-w3q5-rfqr](https://github.com/advisories/GHSA-94gr-w3q5-rfqr) — 검증일 2026-11-06 · ✅ verified (분류는 기록의 ❌ 정정값: 코드 실행, read-only 우회 아님) · subagent
- [mcp-grafana #680](https://github.com/grafana/mcp-grafana/issues/680) — 검증일 2026-11-06 · ✅ verified · subagent
- [GitHub REST: repository advisories](https://docs.github.com/en/rest/security-advisories/repository-advisories), [global advisories](https://docs.github.com/en/rest/security-advisories/global-advisories) — 검증일 2026-11-06 · ✅ verified · subagent
- [GitHub Docs: About repository security advisories](https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/about-repository-security-advisories) — 검증일 2026-11-06 · ✅ verified · subagent
- [LiteLLM 보안 공지](https://docs.litellm.ai/blog/security-update-march-2026) — 검증일 2026-11-06 · ✅ verified · subagent
- [GHSA-92x9-889m-jgmw](https://github.com/advisories/GHSA-92x9-889m-jgmw), [litellm #47826](https://github.com/BerriAI/litellm/issues/47826) — 검증일 2026-11-06 · ⚠️ 권고 기재만 확인, LiteLLM 공식 공지나 maintainer 확인 없음 · subagent

**공급망·권한 조회**
- [pip secure installs](https://pip.pypa.io/en/stable/topics/secure-installs/) — 검증일 2026-11-06 · ✅ verified · subagent
- [npm ci](https://docs.npmjs.com/cli/v11/commands/npm-ci), [package-lock.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json) — 검증일 2026-11-06 · ✅ verified · subagent
- [kubectl auth can-i](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/) — 검증일 2026-11-06 · ✅ verified · subagent

**연구·보고**
- [AIOpsDoom abs](https://arxiv.org/abs/2508.06394), [html v2](https://arxiv.org/html/2508.06394v2) — 검증일 2026-11-06 · ✅ verified · subagent
- [LogJack](https://arxiv.org/abs/2604.15368) — 검증일 2026-11-06 · ✅ verified · subagent
- [LogInject](https://arxiv.org/abs/2607.14493) — 검증일 2026-11-06 · ✅ verified · subagent
- [Tenet — Agentjacking](https://tenetsecurity.ai/blog/agentjacking-coding-agents-with-fake-sentry-errors/) — 검증일 2026-11-06 · ✅ verified · subagent
- [OWASP GenAI exploit roundup Q2 2026](https://genai.owasp.org/2026/07/08/genai-and-agentic-ai-exploit-roundup-q2-2026/) — 검증일 2026-11-06 · ✅ verified · subagent
- [Noma — GrafanaGhost](https://noma.security/blog/grafana-ghost/) — 검증일 2026-11-06 · ✅ verified · subagent
- [CyberScoop — Grafana 반박](https://cyberscoop.com/grafanaghost-grafana-prompt-injection-vulnerability-data-exfiltration/) — 검증일 2026-11-06 · ✅ verified · subagent
- [Meta — Rule of Two](https://ai.meta.com/blog/practical-ai-agent-security/) — 검증일 2026-11-06 · ✅ verified (세 속성 포함) · subagent

**MCP 사양**
- [versioning](https://modelcontextprotocol.io/specification/versioning.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [authorization 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [authorization security-considerations](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/security-considerations.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [tools 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/server/tools.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [extensions overview](https://modelcontextprotocol.io/extensions/overview.md) — 검증일 2026-11-06 · ✅ verified · subagent
