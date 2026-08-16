# 자산 티어 재배치 audit (2026-08-15)

## 요약

| 항목 | 수치 |
|---|---|
| Skills | 260 |
| Agents | 49 |
| Commands | 51 (`.claude/commands/`) / 35 (root `commands/` = 설치 소스) |
| Rules | 25 |
| Plugins | 12 |
| Workflows | 11 (+ `_base.yml`) |

사용자 요청("오래돼서 개선할 것 찾기 — skill 까지 안 가도 될 것들, agent 를 더 세분화할 것들")에 따라 자산 전수를 **티어 적합성** 축으로 측정했다.

핵심 결론 3가지:

1. **발견 메커니즘이 규모를 못 따라갔다.** 260개 skill 중 **224개(86%)가 동일한 템플릿 description 접미사**를 쓴다. `description` 은 Claude Code auto-invocation 의 primary signal 인데, 서로 구별이 안 되므로 실질 발견이 불가능하다. 2026-05-08 audit 이 측정한 "152/239(63.6%) 미참조" 의 실제 원인이 이것이다.
2. **spec 은 있으나 채택되지 않았다.** 2026-05-15 작성된 SKILL-SPEC / AGENT-SPEC 의 필수 항목 준수율이 0~18% 다. `## Verification Criteria` 는 skill 260개 중 **0개**, agent 49개 중 **1개**.
3. **자산이 잘못된 티어에 올라가 있다.** rule 로 충분한 상시 체크리스트가 독립 skill 로 존재하고(59개가 spec 하한 미달), 반대로 도메인이 여러 개인 agent 가 분할되지 않은 채 남아 있다(2개가 spec 상한 초과).

부수적으로 **설치 기능 결함 1건**(명령 16개 미설치)과 사실 오류 7건을 발견했다.

> 본 문서는 **측정과 백로그 정의까지**만 수행한다. 실제 병합 / 분할 / 수정은 각 항목별 후속 PR 로 진행한다. 티어 판정 기준의 상시 정책화는 [ADR 0008](../adr/0008-asset-tier-policy.md) 참조.

---

## 1. 측정 결과

전 항목 2026-08-15 실측. 재현 명령은 [부록 A](#부록-a-재측정-명령) 참조.

### 1.1 Skills (260개)

| 측정 항목 | 값 | 기준 |
|---|---|---|
| 템플릿 description 사용 | **224 / 260 (86%)** | SKILL-SPEC §1 "`What. Use when X.` 형식 의무" |
| `## Verification Criteria` 보유 | **0 / 260** | SKILL-SPEC §3 **필수** |
| `[[cross-link]]` 보유 | 8 / 260 (3%) | SKILL-SPEC §6 |
| `## Sources` 보유 | 45 / 260 (17%) | SKILL-SPEC §2 표준 섹션 |
| `applies_when` 보유 | **0 / 260** | control-plane 결정적 매칭 입력 (`assets/skills/` 에만 15개) |

크기 분포 (SKILL-SPEC §2 기준: 250-400줄 sweet spot):

| 버킷 | 개수 | spec 평가 |
|---|---|---|
| <250줄 | **59** | 하한 미달 — 강등 / 병합 후보 |
| 250-400줄 | 66 | ✅ sweet spot |
| 400-600줄 | **133** | 압축 후보 |
| >600줄 | 2 | 분할 필수 |

> sweet spot 에 있는 skill 이 **66 / 260 (25%)** 뿐이다.

### 1.2 Agents (49개)

AGENT-SPEC §5 가 정의한 필수 본문 섹션 준수율:

| 필수 섹션 | 보유 | 비고 |
|---|---|---|
| 역할 경계 (Boundary) | 9 / 49 | |
| Permission Boundary | **1 / 49** | `git-workflow` 만. 나머지 48개는 `validate-skill-frontmatter.sh` 의 `LEGACY_AGENTS_NO_BODY_SPEC` 화이트리스트로 **soft 경고(CI 비차단)** 처리 |
| Escalation | **1 / 49** | 동일 |
| Verification Criteria | **1 / 49** | 동일 |
| Pair Patterns (Hand-off) | **0 / 49** | |

크기 분포 (AGENT-SPEC §5 기준: 250-450줄 sweet spot):

| 버킷 | 개수 |
|---|---|
| 150-250줄 | 4 |
| 250-450줄 (sweet) | 25 |
| 450-600줄 (검토 필요) | 18 |
| **>600줄 (분할 필수)** | **2** — `go-expert` 605, `java-expert` 605 |

> AGENT-SPEC L137 이 이 둘을 **실명으로 지목**해 두었다: `>600 줄 | 분할 / 압축 필수 (현재 go-expert / java-expert 605 줄)`.

### 1.3 커밋 활동

| 월 | 커밋 수 |
|---|---|
| 2026-01 | 46 |
| 2026-02 | 47 |
| 2026-03 | 48 |
| 2026-04 | 10 |
| 2026-05 | 135 |
| 2026-06 ~ 08 | **0** |

마지막 커밋 `e4b3b18` (2026-05-20). 약 3개월 정지 상태.

---

## 2. 사실 오류 / drift (수정은 백로그)

| # | 위치 | 기재 내용 | 실제 | 심각도 |
|---|---|---|---|---|
| D1 | root `commands/` (install.sh:36 이 읽는 **설치 소스**) | 8개 모듈 디렉토리 | **명령 16개 누락** — `.claude/commands/` 에만 존재 | 🔴 기능 결함 |
| D2 | `AGENTS.md` L16, L295 | "274개 = 독립 `.md` 260 + 폴더형 `SKILL.md` 14" | 폴더형 14개 **부재**. `.gitignore` 가 `.claude/skills/*/*/SKILL.md` 를 P7까지 의도적 제외. **실제 260** | 🟡 |
| D3 | `AGENTS.md` L295 | "43 commands" | 51 (`.claude/commands/`) / 35 (root) | 🟡 |
| D4 | `rules/effort-guide.md` L3, `rules/token-budget.md` L36 | "273 skills" | 260 | 🟡 |
| D5 | `docs/adr/0006`, `schemas/README.md` | `.agents/skills/` (21 카테고리) 를 SSOT 로 기술 | 디렉토리 **부재** (`.gitignore`: "P7까지 deprecate 예정") | 🟡 dangling ref |
| D6 | `.claude/standards.yml` | `max_function_lines: 30` | `rules/clean-code.md` + AGENTS.md 는 "20–50줄 권장, 50줄 초과 분할 검토, 100줄 초과 금지" — **모순** | 🟡 |
| D7 | `TODO.md` | 2026-02-07 / 26 agents / 142 skills | 49 / 260 (6개월 경과) | 🟢 |
| D8 | `docs/migration/0002-progress.md` P6.5 | "Baseline due ≈ 2026-05-15" | **3개월 미수집**. P7·P8 pending. ADR 0005 는 placeholder 상태 | 🟡 |

### D1 상세 — 미설치 명령 16개

`install.sh:36` 은 root `commands/*/` 디렉토리를 순회해 모듈을 발견한다. 아래 16개는 `.claude/commands/` 최상위에 평면 파일로만 존재하고 root `commands/` 에 대응 모듈이 없어 **설치되는 프로젝트에서 사용할 수 없다**:

```
archive-devlog  consolidate-devlogs  consolidate-memory  log-decision
log-feedback    log-meta             log-summary         log-trouble
phase-start     promote-devlog       related             review-pr
review-pr-k8s   review-pr-monitoring review-pr-terraform where
```

커밋 `72a7412` / `b230814` 가 controller 에서 포팅한 메타 워크플로우 명령 전부가 여기 해당한다.

### drift 재발 구조

CI(`ci.yml`)는 rules↔AGENTS.md 상호참조, frontmatter, inventory 신선도, adapter parity 를 검사하지만 **산문에 박힌 숫자는 검사하지 않는다**. D2~D4 는 이 사각지대에서 발생했고, 커밋 `6ba921f docs: fix skill count drift in AGENTS.md (273→274)` 는 오히려 오차를 키웠다.

> **권고**: 자산 개수를 산문에 쓰지 말고 `.claude/inventory.yml` 참조 링크로 대체. 숫자가 꼭 필요하면 `generate-docs.sh` 가 주입하도록 한다.

---

## 3. 티어 판정 기준 — "skill 까지 안 가도 될 것" 의 답

현재 레포에는 5개 티어가 있으나 배치 기준이 문서화된 적 없다. 아래를 기준으로 삼는다.

| 신호 | 올바른 티어 | 비용 |
|---|---|---|
| 모든 작업에 무조건 적용, 분기 없음 | **rule** | 매 세션 자동 로딩 — 길면 묻힘 (100~150줄 권장) |
| 한 rule 에 딸린 짧은 상시 체크리스트 | **rule 섹션** — 독립 skill 아님 | 위와 동일 |
| 분기 있는 결정 트리 + 필요할 때만 참조 | **skill** | 발견 슬롯 1개 소비 |
| 이름으로 호출하는 단발 절차 | **command** | 사용자가 직접 호출 |
| 자체 컨텍스트 + 다단계 조사 필요 | **agent** | 별도 컨텍스트 윈도우 |

**판정 질문**: "이걸 매번 읽어야 하나?" → rule. "결정할 게 있나?" → skill. "직접 부를 건가?" → command. "따로 조사해야 하나?" → agent.

### 대표 오배치 — config 계열

| 자산 | 티어 | 줄 수 |
|---|---|---|
| `rules/config-contract-audit.md` | rule (자동 로딩) | 135 |
| `skills/architecture/config-explicit-defaults.md` | skill | 190 |
| `skills/go/viper-config-binding.md` | skill | 218 |
| `skills/kubernetes/multi-env-diff-checklist.md` | skill | 113 |
| `skills/migration/db-managed-service-checklist.md` | skill | 166 |

rule 이 이미 3단 검증 모델(명시값 / 라이브러리 기본값 / 환경별 override), Viper `SetDefault` 함정, Spring `@Value`, Helm `values-prod` 누락, 매니지드 DB superuser 차이를 **전부 담고 있다**. skill 4개(687줄)는 그 헤드라인의 확장판이라 발견 슬롯 4개를 소비하면서도 rule 을 읽은 시점에 이미 요지가 전달된 상태다.

→ **조치**: rule 이 판정 모델을 계속 보유하고, skill 은 언어·플랫폼 특수 예제만 담은 **1개**로 병합.

---

## 4. Skill 티어 재배치 백로그 (260 → 150 선)

| # | 대상 | 현재 | 조치 |
|---|---|---|---|
| S1 | config 계열 | 4개 687줄 | 1개로 병합. 3단 검증 모델은 rule 에 잔류 |
| S2 | pitfalls 계열 — `otel-pitfalls`(165) / `eks-pitfalls`(160) / `istio-pitfalls`(187) / `terraform-pitfalls`(206) | 4개, 전부 spec 하한 미달 | 각 도메인 본문에 흡수하거나 단일 pitfall 카탈로그로 통합 |
| S3 | deprecated stub — `go-errors` / `mlops-llmops` / `istio-kiali` (각 15줄) | 2026-05-08 마킹 후 3개월 방치 | 회수 + **보존 기간 정책 명문화** (예: 마킹 후 2사이클) |
| S4 | 2026-05-08 audit 미집행 5건 | `dx-onboarding` 4→1 (1,267줄), `istio-gateway` 3→1, `aws-eks-advanced` 흡수, `terraform-modules`/`terraform-security` 흡수, observability 계층화 | 그대로 승계 |
| S5 | prefix 클러스터 허브화 | istio 16 / observability 13 / k8s 12 / spring 9 / finops 8 / dx 8 / msa 7 / kafka 7 / go 6 / monitoring 6 / logging 5 | 허브 skill 1개 + 하위 섹션화. 단 `go-*` 는 언어별 독립 주제라 우선순위 낮음 |
| S6 | <250줄 59개 | spec 하한 미달 | 전수 판정: rule 강등 / 병합 / 유지 |
| S7 | 400-600줄 133개 | sweet spot 초과 | 압축. `/compact` 후 skill 당 5000 tokens 만 잔존하므로 후반부 손실 위험 (SKILL-SPEC §2) |

### 병합 시 지켜야 할 것

- 병합으로 사라지는 이름은 **deprecated stub 로 남기고 `replaced_by` 명시** (2026-05-08 에 확립된 표준 유지)
- 세분화된 검색성 상실은 `[[cross-link]]` 로 보완 — 현재 8/260 뿐이라 병합과 동시에 확충
- 카테고리 단위 PR 로 분할 (`rules/git.md`: 커밋당 4~5 파일, PR 400줄)

---

## 5. Agent 세분화 백로그

레포에는 이미 **검증된 분할 축 4종**이 있다. 신규 축을 만들지 말고 이것을 재사용한다.

| 축 | 선례 |
|---|---|
| 도구별 | `load-tester` → k6 / gatling / ngrinder |
| 엔진별 | `database-expert` → PostgreSQL / MySQL |
| 관점별 (일반 vs 공격자) | `k8s-reviewer` / `k8s-security-reviewer`, `cicd-reviewer` / `cicd-security-reviewer`, `dockerfile-reviewer` / `container-security-reviewer` |
| 단계별 (전략 vs 구현) | `platform-strategy-agent` / `platform-engineer`, `compliance-strategy-agent` / `compliance-auditor`, `business-decision-agent` / `tech-lead` |

### 축 1 — >600줄 강제 분할

| 현재 | 분할 제안 | 근거 |
|---|---|---|
| `go-expert` 605 | **런타임/성능** (High-Traffic L31 · Memory L172 · Connection L217 · Graceful Shutdown L253 · Profiling L283 · Perf Targets L332) + **리뷰** (Code Review L303 · Anti-Patterns L321 · Security L342 · Clean Code L589) | Security Checklist L342-492(150줄)가 `security-scanner` 와, L589 Clean Code 가 `rules/clean-code.md` 와 중복 |
| `java-expert` 605 | **런타임** (Virtual Threads L42 · WebFlux L113 · HikariCP L128 · Caching L164 · Resilience4j L187 · JVM L202) + **리뷰** (Code Review L239 · Anti-Patterns L256 · Security L288 · Clean Code L456/L589) | 동일 패턴, Security L288-456(168줄) |

두 agent 모두 **"도메인 전문성" + "리뷰 체크리스트"** 가 한 파일에 섞여 있고, 리뷰 절반은 기존 `code-reviewer` / `security-scanner` / clean-code rule 과 겹친다. 분할하면 중복 제거가 함께 이뤄진다.

### 축 2 — 엔진·도메인별 분할

| 현재 | 분할 제안 | 근거 (본문이 이미 분리돼 있음) |
|---|---|---|
| `messaging-expert` 475 | kafka / rabbitmq / nats | `## Kafka Troubleshooting` L64, `## RabbitMQ Troubleshooting` L162, `## NATS Troubleshooting` L238 |
| `service-mesh-expert` 547 | istio / linkerd | Istio 편중. `skills/service-mesh/linkerd.md` 518줄이 별도 존재 |
| `migration-expert` 598 | framework / database / infra (허브 유지) | Java·Spring L153 / Python L225 / Kubernetes L282 / Database L339 / Infrastructure L403 — 5개 독립 도메인 |
| `observability-reviewer` 528 | metrics-alerting / logging / tracing-otel | 9개 리뷰 도메인(L24-103). **TODO.md 미결 항목 `monitoring-expert` 를 여기에 흡수** |

### 축 3 — 보안 트윈 비대칭 보완

| 도메인 | general | security | 상태 |
|---|---|---|---|
| kubernetes | `k8s-reviewer` | `k8s-security-reviewer` | ✅ |
| cicd | `cicd-reviewer` | `cicd-security-reviewer` | ✅ |
| container | `dockerfile-reviewer` | `container-security-reviewer` | ✅ |
| network | (`k8s-reviewer`) | `network-security-reviewer` | ✅ |
| **terraform** | `terraform-reviewer` 333 | **없음** | ❌ |
| **gitops** | `gitops-reviewer` 461 | **없음** | ❌ |

terraform 은 IAM 와일드카드 / SG `0.0.0.0/0` / state 노출 같은 **가장 치명적인 오설정이 발생하는 도메인**인데 공격자 관점 트윈이 없다. 콘텐츠는 이미 존재한다 — `rules/terraform.md`, `skills/infrastructure/terraform-security.md`, `commands/terraform/security.md`, `standards.yml` 의 `forbidden_patterns`. **agent 만 없다.**

### 분할의 전제 조건

분할은 경계 문장이 없으면 오히려 혼란을 키운다. 현재 **49개 중 9개만 '역할 경계'** 를 갖고 있고 **Pair Patterns 는 0개**다.

→ 분할 대상 agent 에 한해 **역할 경계 + Permission Boundary + Escalation + Pair Patterns 를 동시 작성**하는 것을 분할 PR 의 수락 조건으로 삼는다. 이렇게 하면 `LEGACY_AGENTS_NO_BODY_SPEC` 화이트리스트도 점진 축소된다.

> **낮은 우선순위 기록**: `incident-responder`(346) / `k8s-troubleshooter`(260) / `debugging-expert`(452) 3개는 트리거가 인접한데 경계 문장이 없다. 분할이 아니라 **경계 명시**로 해결할 항목.

---

## 6. 실행 순서

| 순위 | 작업 | 비용 | 효과 |
|---|---|---|---|
| **P0** | §2 drift 수정. **D1(명령 16개 미설치) 최우선** — 유일한 기능 결함 | 낮음 | 설치 사용자가 메타 워크플로우 명령 사용 가능 |
| **P1** | **description 224개 재작성** — SKILL-SPEC 의 `What. Use when [구체 trigger].` 형식 | 중간 | **발견 문제 직격.** control-plane 없이 오늘 당장 효과 |
| **P2** | §4 skill 티어 재배치 (S1→S7 순) | 큼 | 260 → 150 선 |
| **P3** | §5 agent 분할 3축 | 중간 | spec 위반 해소 + 중복 제거 |
| **P4** | Migration 0002 재평가 | — | P1 효과 측정 후 `applies_when` 필요성 판단 |

### P1 을 먼저 하는 이유

`applies_when` 기반 결정적 매칭(Migration 0002 P7)이 더 근본적이지만 260개 변환 + control-plane 설치 종속이 전제다. 반면 description 재작성은 **Claude Code 기본 발견 메커니즘을 그대로 쓰면서 오늘 효과가 나고**, P7 을 나중에 하더라도 버려지지 않는다 (`applies_when` 은 description 을 대체하지 않고 보완한다).

P1 완료 후 재측정해서 발견율이 충분하면 0002 는 P8(registry) 목적으로만 재개하거나 공식 보류할 수 있다. 판단 근거는 [ADR 0008](../adr/0008-asset-tier-policy.md) §대안 C 참조.

### PR 분할 단위

`rules/git.md` 의 "커밋당 4~5 파일 / PR 400줄" 규율상:

- **P1**: 카테고리 1개 = PR 1개 (22개 카테고리 → 22 PR). 큰 카테고리(observability 31, dx 26)는 2분할
- **P2**: 백로그 항목 1개 = PR 1개 (S1~S7)
- **P3**: agent 1개 분할 = PR 1개. 신규 agent 는 `_handoff.yml` 등록 + `validate-agent-handoff.sh` 통과 필수

---

## 7. 재점검 일정

- **2026-11-15 (3개월 후)**: P1 완료 후 발견율 재측정
- 측정 지표:
  - 템플릿 description 잔존 수 (224 → 0 목표)
  - sweet spot 비율 (현 25% → 60% 목표)
  - skill 총수 (260 → 150 선)
  - agent spec 준수율 (Permission Boundary 1/49 → 분할 대상 전원)

---

## 부록 A: 재측정 명령

```bash
cd "$(git rev-parse --show-toplevel)"

# --- Skills ---
find .claude/skills -name '*.md' | wc -l                              # 총수
grep -rl '도메인의 패턴 / 구현 선택' .claude/skills/ | wc -l           # 템플릿 description
grep -rl '^## Verification Criteria' .claude/skills/ | wc -l          # spec 필수 섹션
grep -rl '\[\[' .claude/skills/ | wc -l                               # cross-link
grep -rl 'applies_when' .claude/skills/ | wc -l                       # 결정적 매칭 입력

# 크기 버킷 (SKILL-SPEC: 250-400 sweet spot)
find .claude/skills -name '*.md' -exec wc -l {} + | grep -v total | \
  awk '{if($1<250)a++; else if($1<=400)s++; else if($1<=600)b++; else c++}
       END{printf "<250:%d 250-400:%d 400-600:%d >600:%d\n",a,s,b,c+0}'

# --- Agents ---
for k in "Permission Boundary" "^## Escalation" "Verification Criteria" "Pair Patterns" "역할 경계"; do
  printf "%-24s %s\n" "$k" "$(grep -rl "$k" .claude/agents/*.md | wc -l)"
done

# --- Drift ---
# 설치 소스에 없는 명령 (D1)
for f in .claude/commands/*.md; do b=$(basename "$f"); [ -f "commands/$b" ] || echo "MISSING: $b"; done

# dangling .agents/ 참조 (D5)
grep -rln '\.agents/' --include='*.md' --include='*.sh' --include='*.yml' . | grep -v node_modules

# prefix 클러스터
find .claude/skills -name '*.md' -exec basename {} .md \; | \
  awk -F'-' '{print $1}' | sort | uniq -c | sort -rn | awk '$1>=5'
```

## 부록 B: 관련 문서

- [ADR 0008 — 자산 티어 판정 정책](../adr/0008-asset-tier-policy.md) — 본 문서 §3 의 상시 정책화
- [2026-05-08 자산 audit](2026-05-08-asset-audit.md) — §4 통합 권장 5건이 본 문서 S4 로 승계, deprecated 마킹 표준 확립
- [2026-05-08 deep audit](2026-05-08-deep-audit.md) — ADR 0001~0003 의 driver
- [2026-05-11 planning-agent gap](2026-05-11-planning-agent-gap.md) — orphan skill 60+ 분석, 재점검 예정일 2026-11-11
- [`.claude/templates/SKILL-SPEC.md`](../../.claude/templates/SKILL-SPEC.md) / [`AGENT-SPEC.md`](../../.claude/templates/AGENT-SPEC.md) — 본 audit 의 준수 기준
- [Migration 0002 진행 트래커](../migration/0002-progress.md) — P6.5 정지 상태 (baseline due 2026-05-15)
