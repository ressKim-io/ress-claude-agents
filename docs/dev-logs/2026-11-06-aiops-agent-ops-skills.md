---
date: 2026-11-06
category: meta
tier: 1
importance: major
status: open
tags: [aiops, agent-ops, mcp, permissions, claude-p, skills, verification]
related:
  - adr/0013-ops-perspective-placement.md
  - audit/2026-11-06-aiops-agent-ops-verification.md
  - adr/0009-enforcement-layer-placement.md
---

# AIOps·에이전트 운영 skill 3개 추가: 조사, 검증, 브랜치 스택

외부 AIOps·에이전트 운영 사례를 조사해 레포의 빈자리를 skill 3개로 채웠다. 배치 결정은 [ADR 0013](../adr/0013-ops-perspective-placement.md), skill이 인용하는 외부 사실과 로컬 실측은 [검증 기록](../audit/2026-11-06-aiops-agent-ops-verification.md)에 있다. 여기에는 경위, 실측 요약, 남은 일을 남긴다. `ask` 재측정(PR-A)이 끝나지 않아 `status: open`이다.

## 조사와 계획

- 2026-11-05 조사(로컬 자료, 커밋하지 않음)에서 외부 근거는 세 갈래로 모였다: read-only 조사·제안, 좁게 열거된 실행, 모델 밖의 강제.
- 레포 감사에서 빈 곳 세 개를 찾았다.
  - 행동 단위 자율성 등급과 강제 수단: 자율성·성숙도 척도가 여러 skill에 따로 있고, 단계마다 무엇이 실제로 막는지 짝지은 것이 없다.
  - Claude Code 무인 실행: `plugins/`에 `claude -p`, `--bare`, Agent SDK, 예약 실행 언급이 없다.
  - 운영 MCP 연결 보안: `security` plugin에 MCP, prompt injection 언급이 없다.
- 사용자 결정(2026-11-06)
  - 1~3순위만 새 skill로 만든다. 4~7순위는 후속으로 둔다.
  - ADR 0009 `ask` 재측정을 선행 단계(PR-A)로 둔다. 이 순서는 뒤에 바꿨다(§브랜치 스택의 순서 변경).
  - 기존 자산은 무승인 실행 예시 2건만 고친다.
  - 검증 기록만 `docs/audit`에 커밋한다. 조사 원문과 초안은 로컬에 둔다.

## 브랜치 스택

PR 하나에 목적 하나를 둔다. 앞 PR이 머지되기 전이라 로컬에서 브랜치를 쌓았다. `blob/main` 링크 게이트는 로컬 파일만 보므로 쌓인 상태에서 통과한다. 앞 PR이 머지되면 다음 브랜치의 base를 최신 `main`으로 옮긴다. push와 PR 생성은 아직 하지 않았다.

순서 변경: PR-A를 먼저 머지할 계획이었지만, 사용자가 모바일 Remote Control로 작업하고 있어 대화형 측정을 실행할 수 없었다. 그래서 PR-B~F를 먼저 올리고 PR-A는 후속으로 미뤘다. 그때까지 세 skill의 `ask` 행은 `⚠️ 재측정 대기`로 둔다. [ADR 0013](../adr/0013-ops-perspective-placement.md) §진행 순서도 이 순서로 고쳤다.

| PR | 브랜치 | 내용 |
|---|---|---|
| PR-B | `docs/update-aiops-agent-ops-verification` | 검증 기록, ADR 0013 |
| PR-C | `feature/security-ops-mcp-security` | `/security:ops-mcp-security`, skill 하한 270 |
| PR-D | `feature/dx-agent-autonomy-tiers` | `/dx:agent-autonomy-tiers`, 하한 271 |
| PR-E | `feature/dx-claude-unattended-ops` | `/dx:claude-unattended-ops`, 앞 두 skill에 역참조, 하한 272 |
| PR-F | `fix/unapproved-remediation-examples` | 무승인 실행 예시 2건 수정, 이 dev-log |
| PR-A (후속) | `docs/update-adr-0009-ask-remeasure` | ADR 0009 `ask` 재측정 반영. **아직 없다** (아래 남은 일) |

- 각 브랜치에서 생성기 3종을 다시 돌리고, 생성 파일은 원인이 된 변경과 같은 커밋에 넣었다.
- 각 브랜치에서 CI 게이트 전부와 `test-gates.sh`를 돌렸다. 마지막 브랜치에서는 `verify-plugins.sh`도 돌렸다.

## 검증 기록을 만들며 고친 것

- 초안 기록에 skill 초안 독립 검토분(행 38개)을 관련 행 뒤에 합쳤다.
- 2.1.245~2.1.318 CHANGELOG 목록은 PR-A 자료라 기록에서 뺐다. skill이 인용한 항목(2.1.257, 2.1.259, 2.1.268, 2.1.280, 2.1.285, 2.1.299, 2.1.302, 2.1.309, 2.1.316)과 "bypass의 ask 동작을 바꾼 항목 없음"은 행으로 남겼다. 그래서 `agent-autonomy-tiers` Sources의 "검증 기록 §6"을 그 행이 있는 §2로 고쳤다.
- 정정한 분류
  - BiAn: shadow A/B로 잰 조사 시간 단축이고, 수치는 `customer-stated`가 아니라 저자 보고값이다. 켜기 전 정밀도의 예는 Defender audit mode다.
  - CVE-2025-65719: read-only 우회가 아니라 악성 HTML을 통한 코드 실행이다.
  - kubernetes-mcp-server #1415: PR #1442는 http 모드만 고쳤고, stdio에서 `configuration_view`가 남는 것을 v0.1.2 소스로 확인했다.
- 기록은 ADR과 합쳐 400줄 안이라 PR-B를 나누지 않았다.

## 로컬 실측 (CLI 2.1.318)

레포 밖 임시 디렉토리에서 `--setting-sources local`, Haiku 5.5로 1회씩 측정했다. 상세는 [검증 기록](../audit/2026-11-06-aiops-agent-ops-verification.md) §3.1.

| 측정 | 결과 |
|---|---|
| T1 `dontAsk` + allow + deny | deny가 allow보다 우선해 막았다. run은 exit 0, `subtype: "success"`. 거부는 `permission_denials`에만 남았다 |
| T2 없는 실행 파일의 MCP 서버 | `mcp_servers[].status`가 `failed`, `mcp_server_errors`·`plugin_errors`는 `null`(문서는 "omitted"). run은 exit 0, `success` |
| T2 모드 미지정 `-p` | init `permissionMode`는 `"default"` |
| T3 `--max-turns` 초과 | exit 1, `subtype: "error_max_turns"` |
| T4 `--verbose` 없는 `stream-json` | exit 1 |
| T5 API 키 없는 `--bare` | 모델 호출 없이 exit 1 |

- 교훈: 무인 run은 exit code로 성공을 판정할 수 없다. `/dx:claude-unattended-ops`의 게이트는 `permission_denials`, `mcp_servers[].status`, 오류 키(`// []`)를 본다.
- ⚠️ `--bare`에서 `--settings`로 넘긴 deny가 적용되는지는 API 키가 없어 측정하지 못했다.

## 결정

- 배치: `dx` 2개와 `security` 1개. 새 plugin과 새 agent는 만들지 않는다. 근거와 대안 비교는 [ADR 0013](../adr/0013-ops-perspective-placement.md).
- skill의 외부 사실은 검증 기록에 행이 있는 것만 쓴다. 기록에 없는 문장은 넣지 않거나 ⚠️로 둔다.
- `ask`는 재측정 전까지 강제 근거로 세지 않는다. 권한 규칙 중에서는 deny 만 강제 근거로 쓴다.
- PR-F는 승인 게이트(`requireApproval: true`, `approvalTimeout: 5m`)와 문구만 바꿨다. `scale` 단계에도 `approvalTimeout`을 붙여 세 승인 단계의 형태를 맞췄다. 키는 예시의 가상 스키마라 동작 검증 대상이 아니다.

## 남은 일

- **PR-A `ask` 재측정 (사용자가 대화형으로 실행).** 비대화형 `-p`로는 대화형 bypass를 재현할 수 없다.
  - 준비: `claude --version` 기록, `.claude/settings.local.json`이 없는지 확인. 측정 중 "don't ask again"을 고르지 않는다.
  - 양성 대조: `claude --permission-mode manual --allowedTools "Bash(git *)" "Bash(gh *)" "Bash(kubectl *)"`에서 `/permissions` 출력을 남기고, allow·deny·ask 대조 명령마다 다이얼로그 여부를 기록한다. ask 대조군에 다이얼로그가 뜨지 않으면 측정이 무효다.
  - 측정: 같은 명령을 `--permission-mode bypassPermissions`로, 평소 쓰는 형태라면 `--dangerously-skip-permissions`로도 실행한다. auto 모드는 선택이다.
  - 결과가 나오면 아래를 고친다.
    - 검증 기록의 `ask` 행
    - ADR 0013 §진행 순서의 순서 메모
    - 세 skill의 `ask` 행(지금은 ⚠️ 재측정 대기)
    - ADR 0009
    - `.claude/rules/core/user-approval.md`
    - `AGENTS.md`
    - `.claude/templates/AGENT-SPEC.md:54`
    - `README.ko.md:291`
    - `scripts/verify-enforcement-runtime.sh`의 주석과 메시지
    - `docs/audit/2026-11-04-claude-spec-verification.md`에 후속 메모
  - CHANGELOG 자료: 이번에 뽑은 ask·bypass CHANGELOG 목록은 레포 밖(로컬 자료)에 두었다. ADR 0009를 고칠 때 CHANGELOG에서 다시 뽑는다.
- `--bare` deny 적용 측정: API 키를 둔 환경에서 skill의 Verification Criteria 1 dry-run을 `--bare`로 돌린다.
- description 목록 예산: 대화형 `/doctor`, `/skill-doctor`로 사용자가 확인한다.
- push, PR 생성, 리뷰 코멘트, 머지는 PR마다 사용자 승인을 받는다.

## 범위 밖 (발견만 함)

- Permission Boundary 선언과 본문이 어긋난 agent: `incident-responder`(:328-345), `k8s-troubleshooter`(:239-255), `cost-analyzer`(:356, :397-412)
- plugin 예시 오류
  - `pr-review-automation`: `trigger_phrase: ""`가 틀렸을 가능성, PR 코멘트 자동 게시가 `user-approval.md`와 충돌
  - `gitops-argocd-ai:156-173`: `anthropic/` org, 없는 `model:` 입력
  - `spec-driven-development:234-245`: hook 이벤트명 오류, exit 1이라 차단되지 않음
  - `dx-ai-agents:305-340`: 서버별 `permissions` 키 미검증
  - `go-ai:235-247`: MCP 설정 위치
  - `ai-first-playbook:221`: `install.sh` 언급
- 문서 문제
  - ADR 0009: 끊긴 상대 링크(:8, :12, :72, :101, :142), :34 deny 목록이 실제와 다름
  - `agent-handoff.yml` 헤더의 agent 수, `verify-enforcement-runtime.sh` 헤더의 probe 수가 실제와 다름
  - 브랜치 규칙 위반 선례(PR #44)
- PR-F에서 손대지 않은 무승인 실행 지점: `aiops-remediation`의 description·Level 4 체크리스트·상한 없는 `memory * 1.5`, `dx-ai-agents-orchestration`의 `improveDecisions: true`, `aiops`의 결정 트리 4단계
- 후속 로드맵 4~7순위: replay 평가 스위트(`claude plugin eval`), `runbook-driven-ops`·`incident-postmortem` 확장, `llmops`·AI SLO·메트릭 이름 정렬, 코딩 에이전트 fleet 정리
