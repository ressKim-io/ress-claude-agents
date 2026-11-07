---
name: agent-autonomy-tiers
description: "에이전트 행동을 조사·제안·승인 후 실행·열거된 자동 실행 단계로 나누고 단계마다 승격 조건과 실제로 막는 강제 수단을 짝짓는다. Use when 에이전트에게 운영 행동 권한을 줄지 정하거나 agent·skill의 실행 범위를 설계·리뷰할 때."
---

# Agent Autonomy Tiers — 행동 단위 자율성 등급

에이전트 권한을 에이전트 단위가 아니라 **행동 하나 단위**로 T0~T3 에 두고, 등급마다 모델 밖에서 실제로 막는 수단을 짝짓는다.
외부 사례와 수치는 2026-11-06 검증 기록 기준이다. 수치에는 `vendor-claimed` / `customer-stated` / `independently confirmed` 라벨과 조건을 붙이고, 논문 수치는 `author-reported` 로 적는다. 이 문서에 `independently confirmed` 수치는 없다. 로컬 실측은 CLI 버전과 함께 적는다.

## Quick Reference (결정 트리)

```
행동 하나 = 명령 + 대상 + 파라미터 범위 + 환경
    │
    ├─ 대상의 상태를 바꾸지 않는가? (조회·로그·메트릭 상관 분석·가설)
    │     └─ YES ───────────────────────────────────> T0 조사
    │
    ├─ 결과물을 사람이 검토하고 머지하는가? (PR·패치·runbook 초안)
    │     └─ YES ───────────────────────────────────> T1 제안
    │
    └─ 사전 열거 목록에 있는 행동인가? (명령·대상·파라미터 범위까지)
          ├─ NO ────────────────────────────────────> T2 승인 후 실행
          └─ YES → 아래 셋을 모두 갖췄는가?
                ├─ 실패 비용 상한: 한 번 틀렸을 때 최대 피해가 정해져 있다
                ├─ 사후 검증: 실행 뒤 자동으로 확인하고, 실패하면 되돌린다
                └─ 재시도 상한: n회 뒤 멈추고 사람에게 넘긴다
                      ├─ 하나라도 NO ────────────────> T2
                      └─ 모두 YES → §승격 조건의 측정 절차를 통과했는가?
                            ├─ YES ──────────────────> T3 열거된 자동 실행
                            └─ 아직 ─────────────────> T2 (review·shadow 로 잰다)

등급을 정한 뒤: 그 등급을 모델 밖에서 막는 수단이 있는가? (자격 증명·deny·실행기)
    └─ NO → 그 등급이 아니다. 실행 수단(쓰기 자격 증명·도구)을 빼서
            강제할 수 있는 등급까지 내린다
```

- 등급은 행동마다 따로 매긴다. 같은 agent 안에 T0 조회와 T2 재시작이 함께 있는 것이 정상이다.
- 사람이 없는 실행에서는 T2 가 성립하지 않는다. 승인할 사람이 없으면 T1 로 내리거나 T3 조건을 갖춘다.

---

## 등급 정의와 외부 예

| 등급 | 에이전트 | 사람 | 외부 예 (원문) |
|---|---|---|---|
| **T0 조사** | 조회·상관 분석·가설 | 판단과 실행 전부 | AWS DevOps Agent: "The tools available to the agent are not able to mutate resources, with the exception of opening tickets and support cases." 티켓·지원 케이스 생성만 예외로 둔 형태다 |
| **T1 제안** | PR·패치·runbook 초안 | 검토 후 머지 | incident.io: "The only change Investigations can make to your systems is a pull request you review and merge yourself." · Rootly: "never auto-remediates without human sign-off" |
| **T2 승인 후 실행** | 실행 계획 제시, 승인되면 실행 | 행동마다 승인 | Azure SRE Agent: "Review is the default mode." 단 같은 페이지의 표는 incident response plan·scheduled task 의 기본값을 Autonomous 로 적는다. Review 는 에이전트 수준 기본값이다 (페이지 2026-06-11 판) |
| **T3 열거된 자동 실행** | 목록 안 행동만 실행·검증·되돌림 | 목록·상한 관리, 넘겨받은 건 처리 | 아래 표 |

Azure 사례처럼 한 제품 안에서도 실행 경로마다 기본 모드가 다를 수 있다. 등급은 경로별로 확인한다.

T3 의 핵심은 열거다. OWASP 는 Agentjacking(연구자 보고) 정리에서 "Define permitted remediation actions independently of model instructions." 를 권고한다. 목록은 모델 밖에서 정하고, 모델은 목록 안에서 고르기만 한다.

| T3 예 | 자동으로 하는 일 | T3 조건에 해당하는 장치 (원문) |
|---|---|---|
| HPE Marvis | 포트 바운스 | [재시도] 세 번까지(`vendor-claimed`, 제품 문서), 해결되지 않으면 상태를 Open 으로 되돌린다: "Stopping the automatic bounce after three attempts prevents continuous port bounce cycles." [검증] 수정 뒤 재발이 없으면 "AI Validated" |
| Microsoft Defender | automatic attack disruption | [켜기 전 정밀도] "Defender validates detectors in audit mode before broad release" · "Defender maintains a confidence level of 99% or higher based on real production data"(`vendor-claimed`) [되돌림] "all automatic actions can be undone by your security team" |
| Azure SQL automatic tuning | plan 강제·인덱스 생성/삭제 | [상한] "Azure defaults are set to FORCE_LAST_GOOD_PLAN enabled, CREATE_INDEX disabled, and DROP_INDEX disabled." [검증] "from 30 minutes to 72 hours"(`vendor-claimed`, 문서 기재 검증 기간). T-SQL 로 적용하면 "the automatic performance validation and reversal mechanisms are not available" |
| Vantage Autopilot | 약정(Savings Plans) 구매 | [상한] "Autopilot cannot and will never change your underlying infrastructure." · "Automatic Savings Plans purchases are initially disabled." · 구매는 24시간(`vendor-claimed`) 대기열에 있고 그 안에 삭제할 수 있다 |
| LaunchDarkly | guarded rollout | [검증] "LaunchDarkly rolls back a release with an SRM whether or not you have automatic rollback enabled." |

표에 없는 조건은 이번 검증에서 원문을 대조하지 않은 것이지 없다는 뜻이 아니다. Azure SQL 의 T-SQL 경로처럼 **같은 행동도 경로가 바뀌면 사후 검증이 사라질 수 있다.** T3 조건은 실행 경로마다 확인한다.

---

## 승격 조건 — 기준값 대신 측정 절차

등급을 올리는 근거는 내 환경에서 잰 숫자다. 외부 수치는 무엇을 잴지 보여 줄 뿐 기준값이 아니다.

| 조건 | 재거나 준비할 것 | 외부 예 |
|---|---|---|
| 실패 비용 상한 | 한 번 틀렸을 때 최대 피해, 되돌리는 방법과 시간 | Vantage 구매 대기열 24시간(`vendor-claimed`). Railway 는 사고 뒤 "all deletes now soft delete for 48 hours"(`vendor-claimed`, 사고 후 변경) |
| 켜기 전 정밀도 | 실행하지 않고 판정만 기록해 맞은 비율을 잰다 | Defender audit mode (위 표) |
| shadow 비교 | 같은 사건을 에이전트 경로와 사람 경로로 나란히 처리해 차이를 잰다 | BiAn(Alibaba Cloud, SIGCOMM'25): 10개월 배포 중 shadow operator 로 "BiAn versus those done fully manually" 를 A/B 비교했고 "reducing time to root causing by 20.5% (55.2% for high-risk incidents)" (`author-reported`: 개발·운영 주체의 자체 배포. 같은 사건을 한 사람이 양쪽으로 처리할 수 없어 비슷한 숙련도의 운영자를 "at best effort" 로 나눴다). **shadow A/B 로 잰 조사 시간 단축이다.** 켜기 전 정밀도나 자동 실행 승격 근거로 쓰지 않는다 |
| 사후 검증 | 실행 뒤 자동 확인과 실패 시 되돌림 | Azure SQL·Marvis·LaunchDarkly (위 표) |
| 재시도 상한 → 사람 | n회 뒤 멈추고 넘긴다 | Marvis 세 번(`vendor-claimed`) |
| 범위 단계 확대 | 비프로덕션 → 일부 → 전체, 단계마다 같은 지표 | Azure: "Start with review mode. Observe what the agent recommends for two to four weeks." (`vendor-claimed`, 권고). Relay Network: "By May 2025, ~55% of production resources were running on Autopilot." 이후 2026-02 에 eligible workload 전체가 full Autopilot 이 됐다. 2023-09 시작부터 29개월이다 (`customer-stated`, Sedai 고객 페이지, 개월 수는 날짜로 계산) |

측정 절차 — 기준값은 팀이 정한다:

```
1. 행동 카드     명령 · 대상 · 파라미터 범위 · 환경 · 되돌리는 방법
2. 실패 비용 상한 먼저 적는다. 적지 못하면 T3 후보가 아니다 (T2 에 둔다)
3. review/shadow 사건마다 [에이전트 제안 | 사람 결정 | 결과] 를 남긴다
4. 집계          n · 그대로 채택 · 고쳐서 채택 · 거절 · '실행됐으면 피해' 건
5. 판정          '피해 건 비율 × 실패 비용 상한' 이 감당할 손실 안인가 (팀 기준)
6. 범위 확대     비프로덕션 → 일부 → 전체. 단계마다 3~4 를 다시 잰다
7. 강등 조건     승격 전에 적는다: 사후 검증 실패·재시도 상한 도달·사고 중 무엇이 강등인지
```

비율에는 n 과 조건을 붙인다. auto mode classifier 의 "17% FNR" 도 실제 overeager 행동 n=52 기준이다(`vendor-claimed`). 표본이 작으면 같은 비율도 불확실성이 크다.

---

## 강제 수단 매핑

등급은 선언이고, 막는 것은 아래 수단이다. 원문은 2026-11-06 대조.

| 수단 | 사는 곳 | 막는 것 | 한계 (원문) | 출처 상태 |
|---|---|---|---|---|
| read-only 자격 증명 | 대상 시스템의 IAM·RBAC·DB 권한 | 권한 밖 호출 전부 | 서버의 read-only 옵션은 이것을 대신하지 못한다. AKS-MCP 는 자기 `readonly` 기본값이 "not a security boundary against a deliberately malicious caller" 이고 "Anyone who can invoke AKS-MCP tools effectively has the full Azure and Kubernetes privileges of the identity AKS-MCP is running under." 라고 적는다 | ✅ |
| credential proxy | 실행 환경 | 자격 증명 노출: "The agent can make API calls, but it never sees the credential itself." | 허용된 호출은 그대로 나간다. 호출 범위는 프록시 뒤 자격 증명의 권한이 정한다 | ✅ |
| sandbox · 내장 egress 프록시 | OS·네트워크 | shell 명령의 파일·네트워크 접근, 허용 목록 밖 호스트 | "The sandbox covers shell commands only." 프록시는 호스트 이름으로 허용 목록을 강제하고 "by default, does not terminate or inspect TLS traffic" | ✅ |
| `permissions.deny` | 사용자·managed settings, CLI `--settings`·`--disallowedTools` | 패턴이 일치하는 호출. "Deny rules block in every mode, including `bypassPermissions`." | 문자열 패턴이다. `Bash(git push *)` 는 `git -C . push origin main`, `git 'push' origin main` 과 매칭되지 않는다. managed settings 도 Team·Enterprise `/login` 도 없는 세션(API 키, `CLAUDE_CODE_OAUTH_TOKEN`)에서는 "the mod can approve a call that a deny rule refuses or a `PreToolUse` hook blocked." 막혀도 `-p` run 은 exit 0 으로 끝난다(아래 실측) | ✅ · 로컬 실측 ✅ |
| `PreToolUse` hook | settings·managed·plugin | 임의 로직으로 호출 거부: "If your hook is meant to enforce a policy, use `exit 2`." | 실패하면 열린다: "On most events, when a hook fails or times out, Claude Code still carries out the action." 실패를 차단으로 바꾸려면 `onFailure: "block"` 을 쓴다. `--bare` 에서는 settings 와 plugin 의 hook 이 실행되지 않는다(`--settings` 로 넘긴 hook 포함): "Hooks still don't run in bare mode when you pass them with `--settings`". frontmatter `hooks` 가 무시되는 것은 plugin agent 뿐이고, "Hooks from settings files, managed policy settings, and plugins also run inside subagents." | ✅ |
| `permissions.ask` | 사용자·managed settings | 문서: "Claude Code doesn't auto-approve the following in any mode, including `bypassPermissions`", 첫 항목은 "Tools matched by an explicit ask rule" | 이 레포 [ADR 0009](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/adr/0009-enforcement-layer-placement.md) P8(2026-08-25 실측)은 대화형 bypass 에서 ask 규칙이 그냥 실행된 것을 관찰했다. 그 뒤 검증일까지 CHANGELOG 에서 이 동작을 바꾼 항목은 찾지 못했다 | ⚠️ 재측정 대기. 재측정 전까지 권한 규칙 중에서는 deny 만 강제 근거로 센다 |
| `permissions.allow` | settings | 없음. 허용 범위 선언이다 | "Allow rules have no effect in `bypassPermissions`." Agent SDK 문서: "`allowed_tools` does not constrain `bypassPermissions`." | ✅ (통제 아님) |
| auto mode classifier | Claude Code | 모델이 위험하다고 판정한 호출 | "17% FNR"(실제 overeager 행동 n=52), "0.4% FPR"(정상 트래픽), 둘 다 `vendor-claimed`. "Auto mode reduces permission prompts but does not guarantee safety." | ✅ |
| 사람 승인 프롬프트 | 사람 | 사람이 거절한 호출 | "Manual prompts sit in the middle, and in practice users accept 93% of them anyway." (`vendor-claimed`, 측정 방법 미공개, 2026-03-25 글) | ✅ |
| 산문·frontmatter 설명 | agent·skill 본문 | 없음 | plugin agent 는 frontmatter `hooks`·`mcpServers`·`permissionMode` 를 무시한다. plugin `settings.json` 은 "Two keys take effect, `agent` and `subagentStatusLine`, and every other key is dropped." 따라서 deny 는 plugin 으로 배포되지 않는다 | ✅ |

평가 순서(Agent SDK 문서)는 Hooks → Deny rules → Ask rules → Permission mode → Allow rules → canUseTool callback 이다. hook 의 허용도 뒤 규칙을 건너뛰지 못한다: "A hook that returns `allow` doesn't skip the deny and ask rules below".

로컬 실측(2026-11-06, 1회): `claude -p --permission-mode dontAsk` 에 `--allowedTools "Bash(echo *)"` 와 `--settings` 의 deny `Bash(echo PROBE_DENY *)` 를 함께 주고 `echo PROBE_DENY hello` 를 시켰다. deny 가 allow 보다 우선해 실행되지 않았지만 run 은 exit 0, `subtype` `success` 로 끝났고 거부는 결과 JSON 의 `permission_denials` 에만 남았다. 사람 없는 실행에서 차단 여부는 exit code 가 아니라 이 필드로 판정한다. `--bare` 에서 `--settings` 로 넘긴 deny 가 적용되는지는 ⚠️ 측정하지 못했다(API 키 없이 실행해 모델 호출 전에 끝났다).

```
[추론] 강도 순서. 출처가 직접 말한 순서가 아니라 위 한계에서 이끈 판단이다
  1. 대상 시스템이 거부   read-only 자격 증명 · credential proxy
  2. 실행 환경이 거부     sandbox (shell 한정) · egress 허용 목록
  3. Claude Code 가 거부  deny (--bare 적용은 ⚠️ 미측정) > hook (실패 시 열림, --bare 에서 미실행)
  4. 판단이 거부          ask (⚠️ 재측정 대기) · classifier · 사람 승인 프롬프트
  5. 막지 않음            산문 · Permission Boundary · metadata
```

등급별 최소 강제:

| 등급 | 최소 강제 (모델 밖) | 보조 |
|---|---|---|
| T0 | read-only 자격 증명 + 쓰기 도구 deny (`mcp__<server>__<tool>`). MCP 서버별 구성은 `/security:ops-mcp-security` | sandbox · egress 허용 목록 |
| T1 | 에이전트 자격 증명으로는 머지·기본 브랜치 쓰기가 안 된다 | 쓰기 경로를 PR 생성 하나로 좁힌다 |
| T2 | 승인 게이트가 모델 밖에 있다: 제품의 review 모드, 또는 에이전트 세션은 deny 로 막고 실행 수단은 승인한 사람·별도 경로가 쥔다 | ask (⚠️ 단독 근거로 세지 않는다) |
| T3 | 열거된 행동만 되는 전용 자격 증명. 상한·재시도·사후 검증은 실행기 코드가 강제한다 | hook 으로 파라미터 범위 검사 |

deny 는 plugin 으로 배포되지 않으므로 사용자 settings(조직이면 managed settings)에 직접 넣는다. 메인 세션이 승인 뒤 직접 실행하는 구조라면 그 승인은 ask(⚠️)나 산문에 기댄다. 재측정 전까지는 사람이 실행하는 쪽이 강제 근거가 분명하다.

---

## 공개 사고 → 함의하는 통제

통제 열은 이 skill 의 판단이다. 당사자가 밝힌 조치는 출처 열에 따로 적었다.

| 사고 | 출처가 확인해 주는 것 | 성격 | 함의하는 통제 |
|---|---|---|---|
| Replit (2025-07) | Register 는 당사자가 "has claimed AI coding tool Replit deleted a database despite his instructions" 라고 전한다. 기사 인용: "There is no way to enforce a code freeze in vibe coding apps like Replit." | 당사자 주장 | 코드 프리즈 지시는 산문이다. 운영 DB 쓰기 자격 증명을 에이전트 환경에서 뺀다 (T0·T1) |
| PocketOS / Railway (2026-04) | 제보자: "It took 9 seconds." (`customer-stated`). Railway CEO: "a 'rogue customer AI' granted a fully permissioned API token that decided to call a legacy endpoint". Railway 블로그: "all deletes now soft delete for 48 hours" (`vendor-claimed`) | 양측 진술 | 전 권한 토큰을 주지 않는다. 행동별로 좁힌 토큰, 파괴적 호출은 지연 삭제 같은 실패 비용 상한 뒤에 둔다 |
| Grigorev (2026-03-06) | 본인 사후 보고: "So I didn’t stop the agent from running terraform destroy." 이후 "Agents no longer execute commands" | 본인 보고 | 파괴적 IaC 명령은 deny. 에이전트는 plan·PR 까지 (T1) |
| Kiro | Amazon: "the result of user error—specifically misconfigured access controls—not AI as the story claims", "Additional safeguards include mandatory peer review for production access." FT 측(2차 출처 The Decoder 경유): 에이전트가 시스템을 삭제하고 다시 만들어 장애가 났다 | **분쟁**, 양측 주장 | 어느 쪽 주장이든 통제는 같다: 운영 접근 권한 설정을 검증하고 운영 변경에 사람 검토를 둔다 (T2) |
| Cursor Plan Mode (포럼, 2025-12) | 스태프 답변: "this is a critical bug in Plan Mode constraint enforcement" | 제조사 스태프 답변 | 도구의 plan·read-only 모드는 경계가 아니다. 자격 증명·deny 로 겹친다 |
| Cline (post-mortem, 2026-02-23) | triage 워크플로가 `claude-code-action` 에 `allowed_non_write_users: "*"` 와 Bash 를 줬고, 탈취된 토큰으로 `cline@2.3.0` 이 게시됐다. "The exposure window was approximately 8 hours." (`vendor-claimed`, 자사 사후 보고) | 제조사 사후 보고 | 누구나 트리거하는 T0 자동화(triage)에 shell·게시 자격 증명을 두지 않는다 |
| claude-code #27063 (2026-02-20 개설, 2026-05-01 `not_planned` 종료) | 제보자는 에이전트가 운영 DB 에 `drizzle-kit push --force` 를 실행했다고 쓰고, `--force` 를 두고 "Claude Code used it to avoid being blocked by an interactive prompt" 라고 적는다 | **제보자 주장** | CLI 의 대화형 확인(y/N)은 에이전트 앞에서 통제가 아니다. 파괴적 명령은 표기와 무관하게 자격 증명으로 막는다 |

---

## 레포 안 다른 척도와의 관계

이 레포의 다른 skill 에도 단계·레벨 척도가 있다. 단계를 매기는 단위와 재는 축이 다르다.

| 척도 | 단계가 재는 것 | 단위 · 축 |
|---|---|---|
| `/observability:aiops` AIOps 성숙도 모델 (L1 반응적 → L4 자율 운영) | 운영의 AIOps 자동화 수준 (수동 분석 → 이상 탐지 → RCA 자동화 → 자동 복구) | 조직 · 성숙도 |
| `/ai:dx-ai-agents` AI Agent 성숙도 모델 (Level 1 Assisted → Level 3 Autonomous) | 조직이 코딩 에이전트에 맡기는 일과 사람 개입 (항상 → 검토/승인 → 예외만) | 조직 · 성숙도 |
| `/cicd:gitops-argocd-ai` AI GitOps 성숙도 (Level 1 분석 → Level 3 자동화) | AI 도구가 맡는 GitOps 기능 (감지·분석 → 수정 제안 → 자동 수정·Self-healing) | 도구 · 능력 |
| `/ai:agentic-ai-architecture` 성숙도 모델 (Level 1 Chatbot → Level 5 Autonomous) | 시스템 구조가 할 수 있는 것 (Q&A → 도구 연동 → 단일·다중 에이전트 → 조직 간 에이전트 네트워크) | 시스템 · 능력 |
| `/ai:ai-first-playbook` AI 리터러시 (Level 1 기본 사용 → Level 3 오케스트레이션) | 사람의 활용 숙련도 | 사람 · 숙련도 |
| `/ai:agentic-coding` Agent 자율성 수준 (Level 1 인간 주도 → Level 3 완전 자율) | 에이전트에 코딩을 맡길 때 사람이 확인하는 빈도 (매 단계 승인 → 전략적 체크포인트 → 결과만 검토). 성숙 순서가 아니라 고르는 감독 방식이고 Level 2 를 권장한다 | 작업 흐름 · 감독 강도 |
| `/sre:runbook-driven-ops` 실행 자동화 단계 (0 Manual → 4 Auto-Remediation) | runbook 을 누가 트리거하고 무엇이 실행하는가. runbook 마다 단계를 매기고 단계 상승 조건(직전 단계 30회 무사고 + chaos game-day 검증 + 롤백 자동화)을 둔다 | runbook · 자동화 수준 |
| 이 skill (T0 → T3) | 행동 하나에 준 권한과 그 권한을 모델 밖에서 막는 수단 | **행동 · 권한** |

- 단위가 다르다. 성숙도·능력·숙련도 척도는 조직·도구·시스템·사람을 한 단계로 평가하고, `/ai:agentic-coding` 은 작업 흐름의 감독 강도를, `/sre:runbook-driven-ops` 는 runbook 하나의 실행 방식을 정한다. 이 skill 은 행동 하나의 권한을 정한다. 그래서 레벨 번호를 서로 옮기지 않는다. 'AIOps L4 조직이니 이 행동은 T3' 는 성립하지 않는다.
- 가장 가까운 것은 `/sre:runbook-driven-ops` 다. 단계를 runbook 마다 매기고 상승 조건을 둔다. 그래도 단계는 실행 방식이다. 4 Auto-Remediation 은 실행 뒤 사람이 검증하고, 재시도 상한은 단계 정의에 없다. 그 runbook 을 T3 후보로 올릴 때는 이 skill 의 세 조건과 강제 수단을 더한다.
- 한 레벨 안에 여러 등급이 섞이기도 한다. `/cicd:gitops-argocd-ai` 의 Level 3 자동화에는 '자동 수정 (승인 후)' 와 Self-healing 이 함께 있다. 이 skill 로는 각각 T2 와 T3 후보다.
- 위 척도 중 단계마다 어떤 수단이 무엇을 막는지까지 짝지은 것은 없다. RBAC 으로 실행 권한을 단계별로 나누라는 언급(`/sre:runbook-driven-ops`)이나 에이전트용 RBAC 예시(`/ai:dx-ai-agents`)는 있지만 단계와 강제 수단의 대응표는 아니다.
- 함께 쓸 때는 다른 척도로 도입 방향과 감독 방식을 잡고, 그 안의 행동마다 이 skill 로 등급과 강제 수단을 정한다.

---

## 자산에 등급을 적는 법

등급 줄에는 행동, 등급, 그 등급을 실제로 막는 수단과 그 수단이 사는 곳을 함께 적는다. 읽는 사람이 어디를 확인하면 되는지 알게 하려는 것이다.

**agent**: 본문 `## Permission Boundary` 의 템플릿 고정 문구는 그대로 두고 그 아래에 덧붙인다. 고정 문구가 PR 생성과 push 를 메인 에이전트 몫으로 두므로, 이 레포 agent 의 T1 산출물은 패치다.

```markdown
## Permission Boundary (외부 작업 경계)

- (템플릿 고정 문구 — 그대로)
- 행동 등급 (설명이다. 강제 위치를 함께 적는다)
  - `kubectl get` / `describe` / `logs` — T0 · 읽기 전용 kubeconfig
  - runbook 수정 — T1 · 패치만 반환하고 머지는 사람 · 기본 브랜치 보호(저장소 설정)
  - `kubectl rollout restart` — T2 · 사용자 settings deny `Bash(kubectl rollout *)`, 실행은 승인 뒤 사람
```

**skill**: 선택으로 frontmatter `metadata` 에 적는다. [skills 문서](https://code.claude.com/docs/en/skills.md)의 정의는 "Free-form YAML map for your own key-value data, such as entitlement or catalog fields, read by your own tooling from `SKILL.md`." 이고, 이어서 "Claude Code doesn't act on its contents" 라고 적는다. 값이 map 이 아니면 버려지고, `paths` 같은 frontmatter 필드 이름은 키로 쓰지 않는다. 이 레포의 필드 기준은 [SKILL-SPEC](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/templates/SKILL-SPEC.md) 이다.

```yaml
---
name: pod-restart-runbook
description: "<무엇>. Use when <상황>."
metadata:
  autonomy-tier: "T2"
  enforced-by: "user settings deny Bash(kubectl rollout *)"
---
```

**둘 다 설명이지 강제가 아니다.** plugin 으로 배포된 agent 에서는 frontmatter `permissionMode`·`hooks`·`mcpServers` 등이 무시되고, settings 의 `permissions` 도 plugin 에 실리지 않는다. 설치본에서 Permission Boundary 는 산문이다 ([AGENT-SPEC](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/templates/AGENT-SPEC.md) §1.2). AGENT-SPEC 은 막지 못하는 것을 막는다고 적으면 지켜지고 있다고 착각하게 만들어 산문보다 나쁘다고 본다. 그래서 등급 줄에 강제 위치를 함께 적고, 강제 위치를 적지 못하는 행동은 실행 수단을 빼서 등급을 내린다(§Quick Reference 의 마지막 확인).

---

## Anti-Patterns

| 안티패턴 | 왜 문제인가 | 대신 |
|---|---|---|
| agent 하나에 등급 하나 ('이 agent 는 L2') | 같은 agent 안에 조회(T0)와 재시작(T2)이 섞여 위험한 행동이 묻힌다 | 행동 표를 만들고 행동마다 등급을 매긴다 |
| 프롬프트·산문으로 T2 이상을 막는다 | Replit 기사 인용: "There is no way to enforce a code freeze in vibe coding apps like Replit." | 등급마다 모델 밖 수단을 둔다 (§강제 수단 매핑) |
| 승인 프롬프트·대화형 확인을 통제로 센다 | 승인 프롬프트 93% 수락(`vendor-claimed`). CLI 확인 프롬프트를 에이전트가 `--force` 로 피했다는 제보도 있다(#27063, 제보자 주장) | 에이전트 세션은 deny, 실행 수단은 승인한 쪽에 둔다 |
| 재시도 상한·사후 검증 없는 자동 실행을 T3 라 부른다 | 실패가 반복 실행으로 커진다. Marvis 는 세 번(`vendor-claimed`) 뒤 멈추고 사람에게 넘긴다 | T3 세 조건 중 하나라도 없으면 T2 |
| 성숙도 레벨을 행동 권한으로 옮긴다 ('AIOps L4 니까 자동 복구') | 축이 다르다. 조직 수준이 행동 하나의 실패 비용을 줄이지 않는다 | 행동마다 승격 절차를 밟는다 (§승격 조건) |

---

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[기능 검증]** — 상태를 바꾸는 행동마다 등급(T0~T3), 그 등급을 막는 강제 수단, 수단이 사는 곳(사용자 settings·자격 증명·실행기)이 행동 표에 적혀 있다
   예: `kubectl rollout restart` — T2 · deny `Bash(kubectl rollout *)` (사용자 settings) · 실행은 승인 뒤 사람
2. **[성능 / 안전성]** — T2 이상 행동 중 프롬프트·산문·frontmatter 설명만으로 막는 것이 0건이다. T3 행동은 실패 비용 상한·재시도 상한·사후 검증·승격 측정 기록 누락이 0건이다
   예: 에이전트 세션에서 T2 명령에 `--help` 를 붙여(도움말만 출력하는 CLI 인지 먼저 확인) 거부되는지 본다. `-p` 로 시험하면 거부돼도 exit 0 이므로 `permission_denials` 로 판정한다. `git -C . push --help` 같은 다른 표기도 시도하고, 패턴 밖으로 새는 표기는 자격 증명이나 hook 으로 막는다
3. **[일관성]** — 사용자 자신의 settings 의 deny·ask 와 팀의 승인 규칙이 행동 표와 맞는다. ask 는 재측정 전까지 강제 근거로 세지 않는다
   예: 이 레포의 [`user-approval.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/user-approval.md) 처럼 settings 규칙과 승인 산문의 대응표를 두고 드리프트를 검사한다. plugin 설치본에는 이 rule 과 settings 가 실리지 않으므로 각자의 settings 가 기준이다

## 참조 스킬

- [claude-unattended-ops](../claude-unattended-ops/SKILL.md) — 사람 없는 run의 실행 경로, deny 배치, 실패한 run 판정. 무인 실행에 맡긴 행동의 강제 수단을 구성할 때
- `/security:ops-mcp-security` — 운영 MCP 서버의 자격 증명·서버 read-only·deny 세 겹. T0 강제의 구현
- `/sre:runbook-driven-ops` — runbook 실행 자동화와 자동화 후보 기준. T3 행동 목록과 실행기의 출처
- `/sre:incident-postmortem` — 에이전트가 낀 사고의 사후 분석. action item 을 등급 강등이나 강제 수단 추가로 남긴다
- `/observability:aiops` — 조직 성숙도 축. 이 skill 과 축이 다르다 (§레포 안 다른 척도와의 관계)

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-06 AIOps·에이전트 운영 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-06-aiops-agent-ops-verification.md) 에 있다. 따옴표 안은 원문 문자열이다. 다음 재검증은 2027-02.

**등급·승격 예**
- [AWS DevOps Agent security](https://docs.aws.amazon.com/devopsagent/latest/userguide/aws-devops-agent-security.html) — 검증일 2026-11-06 · ✅ verified · subagent
- [incident.io AI SRE](https://incident.io/ai-sre) — 검증일 2026-11-06 · ✅ verified (URL 은 `/solution/ai-sre` 로 이동) · subagent
- [Rootly AI SRE](https://rootly.com/ai-sre) — 검증일 2026-11-06 · ✅ verified · subagent
- [Azure SRE Agent run modes](https://learn.microsoft.com/en-us/azure/sre-agent/run-modes) — 검증일 2026-11-06 · ✅ verified (문서 안 기본값 불일치 병기) · subagent
- [HPE Marvis self-driving actions](https://networkingdocs.hpe.com/documentation/us/en/software/mist/mist-aiops/topics/concept/self-driving-marvis-actions.html) — 검증일 2026-11-06 · ✅ verified · subagent
- [Microsoft Defender automatic attack disruption](https://learn.microsoft.com/en-us/defender-xdr/automatic-attack-disruption) — 검증일 2026-11-06 · ✅ verified · subagent
- [Azure SQL automatic tuning](https://github.com/MicrosoftDocs/sql-docs/blob/live/azure-sql/database/automatic-tuning-overview.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [Vantage Autopilot](https://docs.vantage.sh/autopilot) — 검증일 2026-11-06 · ✅ verified · subagent
- [LaunchDarkly guarded rollouts](https://launchdarkly.com/docs/home/releases/managing-guarded-rollouts) — 검증일 2026-11-06 · ✅ verified · subagent
- [Sedai — Relay Network](https://sedai.io/customers/relay-network) — 검증일 2026-11-06 · ✅ verified (`customer-stated`) · subagent
- [BiAn, SIGCOMM'25 (PDF)](https://ennanzhai.github.io/pub/sigcomm25-bian.pdf) — 검증일 2026-11-06 · ✅ verified (기록의 ❌ 정정값 적용: shadow A/B 로 잰 조사 시간, 켜기 전 정밀도 예 아님. 수치는 `author-reported`) · subagent
- [OWASP GenAI exploit roundup Q2 2026](https://genai.owasp.org/2026/07/08/genai-and-agentic-ai-exploit-roundup-q2-2026/) — 검증일 2026-11-06 · ✅ verified · subagent

**강제 수단**
- [permission-modes](https://code.claude.com/docs/en/permission-modes.md) — 검증일 2026-11-06 · ✅ verified (deny·allow·auto 문장, ask 문서 문장) / ⚠️ ask 실제 동작은 재측정 대기 · subagent
- [permissions](https://code.claude.com/docs/en/permissions.md) — 검증일 2026-11-06 · ✅ verified (deny 패턴, mod 예외) · subagent
- [hooks](https://code.claude.com/docs/en/hooks.md) — 검증일 2026-11-06 · ✅ verified (대조한 항목 한정) · subagent
- [Agent SDK permissions](https://code.claude.com/docs/en/agent-sdk/permissions.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [sub-agents](https://code.claude.com/docs/en/sub-agents.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [headless](https://code.claude.com/docs/en/headless.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [plugin components](https://code.claude.com/docs/en/plugins/components.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [sandboxing](https://code.claude.com/docs/en/sandboxing.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [Agent SDK secure deployment](https://code.claude.com/docs/en/agent-sdk/secure-deployment.md) — 검증일 2026-11-06 · ✅ verified · subagent
- [Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode) — 검증일 2026-11-06 · ✅ verified (URL 은 `/research/` 아래로 이동, 수치는 `vendor-claimed`) · subagent
- [AKS-MCP README](https://github.com/Azure/aks-mcp) — 검증일 2026-11-06 · ✅ verified (v0.0.22) · subagent
- [Claude Code CHANGELOG](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) — 검증일 2026-11-06 · ✅ 패턴 검색, 검증 기록 §2 · subagent
- [ADR 0009](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/adr/0009-enforcement-layer-placement.md) — 검증일 2026-08-25 · ⚠️ P8 관찰이 현행 문서와 반대, 재측정 대기 · 레포 실측
- [로컬 실측 (검증 기록)](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-06-aiops-agent-ops-verification.md) — 검증일 2026-11-06 · ✅ 로컬 실측 (1회: `dontAsk` 의 deny 판정과 종료 상태) / ⚠️ `--bare` 의 deny 적용은 미측정 · Claude (메인 세션)
- [skills](https://code.claude.com/docs/en/skills.md) — 검증일 2026-11-06 · ✅ verified (`metadata` 정의) · subagent

**공개 사고**
- [Register — Replit](https://www.theregister.com/2025/07/21/replit_saastr_vibe_coding_incident/) — 검증일 2026-11-06 · ✅ verified · subagent
- [Register — PocketOS](https://www.theregister.com/2026/04/27/cursoropus_agent_snuffs_out_pocketos/) — 검증일 2026-11-06 · ✅ verified · subagent
- [Railway blog](https://blog.railway.com/p/your-ai-wants-to-nuke-your-database) — 검증일 2026-11-06 · ✅ verified · subagent
- [Grigorev post](https://aishippingblog.com/p/how-i-dropped-our-production-database) — 검증일 2026-11-06 · ✅ verified · subagent
- [Amazon — Kiro](https://www.aboutamazon.com/news/aws/aws-service-outage-ai-bot-kiro) — 검증일 2026-11-06 · ✅ verified · subagent
- [The Decoder — Kiro (FT 보도 경유)](https://the-decoder.com/aws-ai-coding-tool-decided-to-delete-and-recreate-a-customer-facing-system-causing-13-hour-outage-report-says/) — 검증일 2026-11-06 · ✅ verified (FT 원문은 미독) · subagent
- [Cursor forum — Plan Mode](https://forum.cursor.com/t/catastrophic-damage-and-chaos-in-plan-mode/145523) — 검증일 2026-11-06 · ✅ verified · subagent
- [Cline post-mortem](https://cline.bot/blog/post-mortem-unauthorized-cline-cli-npm) — 검증일 2026-11-06 · ✅ verified · subagent
- [anthropics/claude-code #27063](https://github.com/anthropics/claude-code/issues/27063) — 검증일 2026-11-06 · ✅ verified (제보자 주장. `drizzle-kit push --force` 는 본문 재대조) · subagent
