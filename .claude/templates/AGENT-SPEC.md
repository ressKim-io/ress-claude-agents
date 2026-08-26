# Agent 작성 표준 — AGENT-SPEC

이 레포의 모든 `.claude/agents/**/*.md` 가 따라야 할 frontmatter / description / hand-off / 본문 표준.
신규 agent 추가 시 본 spec 을 그대로 카피해 사용.

> **출처 (F6)**: https://code.claude.com/docs/en/sub-agents (검증일 **2026-08-24**, 직전 2026-05-15)
>
> 핵심 1: sub-agent 의 `description` 은 Agent 도구가 invocation 결정 시 매칭하는 primary trigger. universal "always use sonnet" 룰 없음 — task 복잡도 기반 model 선택.
> 핵심 2: frontmatter 는 **16개 필드**를 지원한다. 이 중 실행 강제력이 있는 것은 `disallowedTools` / `maxTurns` / `hooks` 이고, `permissionMode` 는 부모 세션에 따라 무시될 수 있다. **명령 단위 강제는 frontmatter 가 아니라 `.claude/settings.json` 의 `permissions` 에서 한다** — 경계는 §1.2 참조.
>
> ⚠️ 외부 사양은 분기별 재검증 대상이다 ([`multi-tool-adapter.md`](../rules/multi-tool-adapter.md) §외부 도구 사양). 2026-05-15 → 2026-08-24 사이에 실제로 `effort` 필드 관련 기술이 drift 했다 — 경위는 [2026-08-24 audit](../../docs/audit/2026-08-24-agent-harness-readiness.md) 참조. **다음 재검증 예정: 2026-11**.

---

## 1. 필수 Frontmatter

```yaml
---
name: agent-name                                # kebab-case, `:` 사용 불가 (plugin 예약)
description: |
  [Domain / 역할 1 줄]. [Specialty / 특화 도구]. Use PROACTIVELY when [구체 trigger 시나리오 1-3 개].
  [Hand-off pair / 관련 agent 명시 — 필요 시].
tools: Read, Grep, Glob, Bash                  # 명시적 listing (전체 `*` 회피)
model: sonnet                                   # haiku | sonnet | opus | fable | inherit
effort: xhigh                                   # 세션 effort 를 override — 본 레포는 전 agent 명시
# disallowedTools: [Write, Edit]                # 도구 단위 차단만 가능 — §1.2 의 경계를 읽고 쓸 것
---
```

### 1.1 본 레포 표준 필드

| 필드 | 필수 | 설명 |
|---|---|---|
| `name` | ✅ | kebab-case, 파일명과 동일 (레포 규약). 공식적으로 파일명 일치는 불필요하나 `:` 는 금지 |
| `description` | ✅ | 50-200 단어, F1 패턴 — "What. Use [PROACTIVELY] when X." + hand-off |
| `tools` | ✅ | 명시적 도구 listing. 보안상 `*` (전체) 회피. WebFetch / Write 는 필요 시만 |
| `model` | ✅ | haiku (단순) / sonnet (대다수) / opus (frontier) — outlier 정당화 본문에 명시 |
| `effort` | ✅ | **세션 effort override.** [`effort-guide.md`](../rules/effort-guide.md) 에서 고른 값을 명시. 생략하면 세션 기본값에 방치됨 |
| `disallowedTools` | 조건부 | 도구 단위 denylist. `tools` 허용목록과 중복되면 no-op — 실제 효과가 있을 때만 쓴다 (§1.2) |

### 1.2 실행 강제 필드 — 무엇이 실제로 강제되는가

[`multi-tool-adapter.md`](../rules/multi-tool-adapter.md) 는 "산문 규약을 대상 도구의 **강제 메커니즘으로 승격**하라" 고 규정한다. 다만 **어디까지 승격되는지에 경계가 있다.**

| 필드 | 강제력 | 경계 (2026-08-25 공식 docs 확인) |
|---|---|---|
| `disallowedTools` | ✅ 런타임 강제 | **도구 이름 / MCP 패턴 단위만.** `Bash(gh pr comment:*)` 같은 명령 단위 지정자는 **지원하지 않는다** (settings.json 문법과 다르다). `tools` 허용목록에 이미 없는 도구를 적으면 no-op |
| `maxTurns` | ✅ 런타임 강제 | 턴 상한. 조사 범위가 발산할 수 있는 agent 에 |
| `hooks` | ✅ 런타임 강제 | `PreToolUse` 가 `permissionDecision: deny` 로 개별 호출 차단. frontmatter 필드 중 명령 단위에 닿는 유일한 것 (**frontmatter 밖에는 settings.json 의 `permissions.deny` 가 있다 — 아래 정정**). `bypassPermissions` 하에서도 실행·차단된다 (공식 문서엔 기술 없음, [ADR 0009](../../docs/adr/0009-enforcement-layer-placement.md) 실측 P3). ⚠️ **exit 1 / 실행 실패 / timeout 은 전부 비차단** — 깨진 hook 은 조용히 통과시킨다 (F11) |
| `permissionMode` | ⚠️ 조건부 | 부모가 `bypassPermissions` / `acceptEdits` 면 **override 불가**. 부모가 auto mode(Pro/Max/Team 기본)면 frontmatter 값이 **무시된다** |

> ⚠️ **정정 (2026-08-25)**: 2026-08-24 판은 `disallowedTools` 를 "§Permission Boundary(gh / git push 직접 실행 금지)의 승격 자리" 라고 적었다. **스펙상 성립하지 않는다** — `disallowedTools` 도 `permissionMode` 도 `Bash` 안쪽의 `gh` / `git push` / `argocd sync` 에 닿지 못한다.
>
> **다만 "그래서 산문으로 남는다" 는 결론도 틀렸다.** 강제력은 frontmatter 밖에 있다 — [`.claude/settings.json`](../settings.json) 의 `permissions.deny` / `ask` 는 명령 단위 지정자(`Bash(gh pr comment *)`)를 지원하고, **`bypassPermissions` 에서도 subagent 의 `Bash` 안쪽에서도 유지된다** ([ADR 0009](../../docs/adr/0009-enforcement-layer-placement.md) 실측 P2/P5).
>
> 따라서 §Permission Boundary 의 승격 자리는 **agent frontmatter 가 아니라 세션 설정**이다. agent 마다 다른 경계가 정말 필요할 때만 frontmatter `hooks` 를 쓰고, 그때는 **위반 fixture 를 같은 커밋에** 둔다 (F11: fixture 없는 hook 은 3.5개월간 0% 로 작동했다).

> MUST 신규 필드를 넣기 전에 **그게 실제로 무엇을 막는지** 확인한다. 막지 못하는 것을 막는다고 적은 frontmatter 는 산문보다 나쁘다 — 지켜지고 있다고 착각하게 만든다.

### 1.3 선택 필드 (필요 시)

| 필드 | 용도 |
|---|---|
| `skills` | 시작 시 skill **전문(全文)** 을 context 에 주입. 도메인 레퍼런스를 본문에 인라인하는 대신 이쪽을 쓴다 (§5 참조) |
| `memory` | `user` / `project` / `local` — 세션 간 학습. 같은 실수의 재발을 구조적으로 막는 자리 |
| `hooks` | 이 agent 스코프의 lifecycle hook |
| `mcpServers` | 이 agent 가 쓸 MCP 서버 |
| `isolation` | `worktree` — 격리된 repo 사본에서 실행 |
| `background` | 항상 백그라운드 실행 |
| `color` | 태스크 목록 표시 색 |
| `initialPrompt` | `--agent` 로 메인 세션 agent 로 쓸 때의 첫 턴 |

> 전체 16개 필드의 정확한 의미는 공식 문서를 확인한다 — 본 표는 **본 레포에서 쓰는 관점**의 요약이지 사양 사본이 아니다.

> **본문 필수 섹션**: frontmatter 외에, 본문에 `Permission Boundary` / `Escalation` /
> `Verification Criteria` 3 개 H2 섹션이 필수다 (§5 표준 섹션 순서 + Verification 상세는 §6).
> `scripts/validate-skill-frontmatter.sh` 가 신규 agent 에 대해 이를 검증한다 — 누락 시 CI 실패.

### description 패턴 (의무)

✅ **Good** (현재 49 중 9 개의 패턴 — 18% / 100% 로 확장 필요):
```
description: |
  K8s manifest / Helm chart / Kustomize 종합 리뷰어 — Pod Security Standards, RBAC, 리소스 관리,
  고가용성, 이미지 정책. Use PROACTIVELY when K8s manifest files change. Red team 관점 공격 시나리오
  (MITRE ATT&CK, container escape, lateral movement) 는 k8s-security-reviewer 를 함께 호출.
```

❌ **Bad** (현재 49 중 20 개 — 40%):
```
description: AI-powered FinOps cost analyzer. Use to analyze cloud spending.
```
(trigger 모호, hand-off 없음, <30 단어)

---

## 2. Description 구조 (3 요소)

```
[1] Role + Specialty (한 문장)
[2] Use [PROACTIVELY] when [구체 trigger 1-3 개]
[3] Hand-off: [관련 agent + 호출 조건]
```

**예시 (architect-agent)**:
```
[1] MSA 아키텍처 설계 에이전트. 서비스 경계 정의, API 계약(protobuf/OpenAPI) 설계, Bounded Context
    매핑, 의존성 분석에 특화.
[2] Use for microservice architecture design, service decomposition, and API contract definition.
[3] compliance-strategy-agent 의 compliance-blueprint 를 consume 하여 data-model 에 규제 제약
    (PIPA/GDPR) 반영. business-decision-agent 의 4 ADR(tenancy/auth/payment/notification) 을
    consume 하여 api-contract 설계.
```

### Trigger 패턴

| 패턴 | 사용 상황 |
|---|---|
| `Use PROACTIVELY when [file change]` | 파일 변경 자동 review (cicd-reviewer, k8s-reviewer, terraform-reviewer 등 9 개) |
| `Use when [user intent]` | 사용자 명시 호출 (대다수) |
| `MUST BE USED for [domain]` | 강제 매칭 (드물게, 예: 보안 critical) |

---

## 3. Model 선택 가이드

> F6: Anthropic 공식 universal rule 없음 — task complexity 기반.

| Model | Effort | 사용 상황 | 본 레포 예 |
|---|---|---|---|
| `haiku` | `low` | 단순 자동화, 기록, template 적용 | dev-logger / git-workflow |
| `sonnet` | `xhigh` (default) | 일반 expert / reviewer / 분석 (대다수) | code-reviewer / k8s-reviewer / terraform-reviewer 등 |
| `opus` | `max` | cascade failure / 트레이드오프 / 전사 RFC | architect-agent / debugging-expert / tech-lead |

**model 선택 self-check**:
- 단순 lookup / template 만? → haiku
- 일반 코딩 / 도메인 분석? → sonnet
- cross-service cascade / 큰 ADR / 트레이드오프? → opus

---

## 4. Hand-off 명시 (필수, 100% 적용 목표)

agent 가 다른 agent / skill 과 협력하는 경우 description 에 명시 (현재 27% → 100% 목표).

### 패턴

| Hand-off 종류 | 표현 |
|---|---|
| Upstream consume | "X agent 의 [산출물] 을 consume" |
| Downstream produce | "Y agent 가 본 agent 의 [산출물] 을 consume" |
| Parallel pair | "Z agent 를 함께 호출 (관점 분리: ...)" |
| Specialist delegation | "[domain] 특화 검증은 W agent 사용" |

### 예시 (code-reviewer)

```
Cross-language 시니어 코드 리뷰어 — correctness, readability, 명명, 중복, 테스트 커버리지,
일반 best practice. Use PROACTIVELY after any code change as the default reviewer.
언어 특화 깊은 검증(Go concurrency, Java JVM/Virtual Threads, Python asyncio, React Server
Components) 은 go-/java-/python-/frontend-expert 를 함께 호출.
```

---

## 5. 본문 구조 표준

### 권장 줄 수: 250-450 줄

| 길이 | 평가 |
|---|---|
| <150 줄 | 너무 짧음 — 도메인 패턴 / output format 부족 |
| 150-250 줄 | OK |
| **250-450 줄** | **Sweet spot** |
| 450-600 줄 | 검토 필요 — 일부 섹션 skill 로 분리 |
| >600 줄 | 분할 / 압축 필수 (2026-08-24 Step 3 에서 605 줄 go-expert / java-expert 를 skill 로 분할해 소진) |

> **도메인 레퍼런스를 본문에 인라인하지 않는다.** 코드 샘플·패턴 카탈로그는 skill 로 두고 frontmatter `skills:` 로 주입한다 (시작 시 전문이 주입되므로 본문에 붙여 쓰는 것과 동일한 효과에 재사용까지 얻는다).
> agent 본문은 **"언제 무엇을 판단하고 무엇을 반환하는가"** — 조사 프로토콜과 출력 계약만 남긴다. 본문이 코드블록 비중 60%+ 면 그 agent 는 skill 이어야 한다 ([2026-08-24 audit §3](../../docs/audit/2026-08-24-agent-harness-readiness.md)).

### 표준 섹션 순서

```markdown
# Agent Title

## 역할 경계 (Boundary)

[이 agent 가 하는 것 / 안 하는 것 — hand-off 명시]

## Permission Boundary (외부 작업 경계)

[필수 — 모든 agent 동일. 아래 문구를 그대로 사용]
- 이 agent 는 결과(분석 / 리뷰 / 패치 제안)만 반환한다.
- gh pr create / gh pr comment / gh issue create / gh release create / git push /
  Slack·Discord 전송 / 외부 API 상태 변경 / argocd sync 를 직접 실행하지 않는다.
  필요하면 "메인 에이전트가 승인 후 실행할 명령"으로 output 에 제시만 한다.
- kubectl 은 읽기 전용(get / describe / logs / top)만.

## Escalation (중단·이관 기준)

[필수 — 모든 agent 동일. 아래 문구를 그대로 사용]
다음 중 하나라도 해당하면 작업을 중단하고, 추측으로 진행하지 말고
메인 에이전트에 결과 + 차단 사유를 반환한다:
- 권한 밖 — 외부 상태 변경(§Permission Boundary)이 필요한 단계
- 입력 불충분 — 결정에 필요한 파일·맥락이 프롬프트에 없음
- 범위 밖 — 다른 도메인 agent 책임. 해당 agent 를 명시해 이관
- 모순 — rules/ 또는 다른 agent 결과와 충돌해 단독 판단 불가
반환 형식: `[BLOCKED] <사유> — 필요한 것: <X> / 제안: <다음 agent 또는 사용자 액션>`

## Quick Reference (또는 Decision Tree)

[ASCII 결정 트리]

## [도메인 패턴 1]
## [도메인 패턴 2]
...

## Review Process / Checklist

[step-by-step 실행 절차]

## Output Format

[정해진 output 형식 — table / JSON / markdown]

## Verification Criteria

[F7 — 본 agent 결과가 만족해야 할 기준]

## Pair Patterns (Hand-off)

[다른 agent 와의 협력 패턴 — description 의 hand-off 와 일관성]

## Examples

[1-2 개 input/output 예]
```

---

## 6. Verification Criteria 섹션 (필수, F7)

```markdown
## Verification Criteria

이 agent 의 산출물이 다음 조건을 만족해야 한다:

1. **[정확성]** — 모든 검토 항목이 코드/manifest 의 실제 상태 기반
2. **[완전성]** — Checklist 의 모든 항목 다룸
3. **[실행 가능성]** — output 의 모든 권장이 구체 명령 / 패치 / 라인 번호 동반
4. **[일관성]** — 다른 agent / rule 과 모순 없음 (예: clean-code.md 와 일관)

### Self-verification (제출 전 자가 점검)

- [ ] 모든 주장이 실제로 읽은 파일·라인 근거 (추측·기억 기반 0건)
- [ ] 확인 못 한 항목은 단정하지 않고 "미확인"으로 표기
- [ ] §Permission Boundary 위반 명령을 직접 실행하지 않았음
```

---

## 7. 검증 스크립트

```bash
# Hand-off 정합성 (모든 agent 가 _handoff.yml 또는 description 에 등록)
scripts/validate-agent-handoff.sh

# Frontmatter 검증 (model / tools / description)
scripts/validate-skill-frontmatter.sh  # agents 도 검증 (skill 과 동일 frontmatter 표준)
```

---

## 8. 예시 (완전한 agent)

```markdown
---
name: example-expert
description: |
  [Domain] 전문가 에이전트. [Specialty 1, 2, 3] 에 특화.
  Use PROACTIVELY when [구체 file change / trigger].
  일반 코드 품질은 code-reviewer 와 함께 호출. [Pair pattern].
tools: Read, Grep, Glob, Bash
model: sonnet
---

# Example Expert

## 역할 경계
- 하는 것: [...]
- 안 하는 것 (hand-off): [...]

## Permission Boundary (외부 작업 경계)
- 결과(분석 / 리뷰 / 패치 제안)만 반환. gh / git push / 외부 API 상태 변경 / argocd sync 직접 실행 금지.
- kubectl 은 읽기 전용(get / describe / logs / top)만.

## Escalation (중단·이관 기준)
- 권한 밖 / 입력 불충분 / 범위 밖 / 모순 시 중단 → `[BLOCKED] <사유> — 필요한 것: <X> / 제안: <다음 agent 또는 사용자 액션>`

## Quick Reference
...

## [도메인 패턴]
...

## Verification Criteria
1. ...

## Pair Patterns
- code-reviewer: 일반 review 와 함께 호출
- security-scanner: 보안 cross-check
```

---

## 관련 문서

- Effort 매핑: [`../rules/effort-guide.md`](../rules/effort-guide.md)
- Skill spec: [`SKILL-SPEC.md`](SKILL-SPEC.md)
- Token / context 룰: [`../rules/token-budget.md`](../rules/token-budget.md)
- 코드 리뷰 룰: [`../rules/code-review.md`](../rules/code-review.md)
