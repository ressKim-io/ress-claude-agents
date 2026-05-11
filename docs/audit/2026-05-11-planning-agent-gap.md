# Planning-Stage Agent Gap 점검 (2026-05-11)

## 요약

| 항목 | 수치 |
|---|---|
| Skills | 234 (deprecated 3 제외) |
| Agents | 46 |
| Workflows | 10 |
| 계획 단계 cover 평균 | **약 49% (전략 카테고리 기준)** |

사용자 요청("agents로 안 묶인 skill이 새 프로젝트 계획 단계에서 잘 활용되는지 점검")에 따라 Explore 2개 + 직접 검증으로 다음을 발견했다.

- **AGENTS.md §220-226 "신규 프로젝트 4단계 ADR" chain**: 실제로는 **1단계(멀티테넌시)만 동작**. 인증/결제/알림 stage 부재
- **`platform-engineer` / `infra-roadmap-planner` / `finops-advisor` / `compliance-auditor`** 4 agent는 정의돼 있지만 어떤 workflow도 부르지 않음
- **Skills 60+ 개가 어떤 agent에도 묶여 있지 않음** (특히 business 11/16, platform 16/16, legal 3/3, architecture 8/10, ai 4/5)

→ 후속 조치: 신규 agent 3개(`business-decision` / `platform-strategy` / `compliance-strategy`) + 신규 workflow `bootstrap-new-saas.yml` 도입으로 60+ orphan skill을 계획 단계 chain에 통합.

---

## 1. 카테고리 cover 매트릭스

| 카테고리 | Skills | 매핑된 agent | 상태 | 비고 |
|---|---|---|---|---|
| business (16) | 5 covered / 11 orphan | tech-lead(부분) | 🔴 | 4 ADR chain 대부분 끊김 |
| platform (16) | 0 covered | platform-engineer 존재하나 workflow 미연결 | 🔴 | MLOps/IDP/GPU 전부 사장 |
| legal (3) | 0 covered | — | 🔴 | 사전 설계 owner 부재 |
| architecture (10) | 2 covered (hexagonal, modular-monolith) | architect-agent | 🟡 | data-mesh/strangler-fig/cell-based 등 8개 orphan |
| ai (5) | 1 covered (vector-db) | — | 🟡 | agentic/rag/langchain orphan |
| dx (26) | 6 covered | tech-lead | 🟡 | token-budget/team-topologies 등 20 orphan |
| sre (15) | covered 부분 | finops-advisor(미연결) | 🟡 | finops 전체 미매핑 |
| security (5) | 2 covered | security-scanner, compliance-auditor | 🟡 | compliance-frameworks orphan |
| operations (2) | 1 covered (runbook) | — | 🟡 | incident-postmortem 미매핑 |
| msa (15) | 13 covered | architect-agent, saga-agent, messaging-expert | 🟢 | |
| 언어 카테고리 (go/java/python/frontend/spring) | 거의 전부 | language experts | 🟢 | |
| kubernetes (20) | 거의 전부 | k8s-* agents | 🟢 | |
| observability (28) | 거의 전부 | otel-expert, observability-reviewer | 🟢 | |
| infrastructure (16) | 거의 전부 | terraform-reviewer 등 | 🟢 | |

---

## 2. AGENTS.md §220-226 "신규 프로젝트 4단계 ADR" chain 검증

AGENTS.md 명시:
> 1. 멀티테넌시 격리 모델 (가장 비싼 결정)
> 2. 인증 Provider (시장에 따라 Kakao/Google/Apple)
> 3. 결제 Provider (한국=PortOne/Toss, 글로벌=Stripe)
> 4. 알림 채널 + Provider
> 각 skill에 ADR 템플릿 포함. agents/tech-lead로 위임 가능.

**`new-domain.yml` 실제 구현**:

| 단계 | 명시 stage | 실제 위치 | 상태 |
|---|---|---|---|
| 1. 멀티테넌시 | `multi-tenancy-decision` | L92-97 (workflow 마지막 phase) | ⚠️ 존재하지만 순서가 늦음 |
| 2. 인증 | (없음) | — | ❌ stage 부재 |
| 3. 결제 | `domain-expert-billing` | L37-43 (optional) | ⚠️ optional + payment 한정 |
| 4. 알림 | (없음) | — | ❌ stage 부재 |

**L117-122**:
```yaml
# 신규 도메인 시작 시 ADR 작성 권장 순서 (business/ 패턴):
#   1. multi-tenancy 격리 모델 (가장 비싼 결정)
#   2. 인증 Provider (Kakao/Google/Apple)
#   3. 결제 Provider (PortOne/Toss/Stripe)
#   4. 알림 채널 + Provider
```
→ **주석으로만 명시, 실제 stage로 매핑 안 됨**. tech-lead가 직접 호출되도록 workflow 강제력 없음.

**결론**: AGENTS.md 가이드와 실제 자동화 간 디스패리티. 사용자가 "새 SaaS 시작" prompt를 줘도 4 ADR 자동 orchestration은 불가능.

---

## 3. Orphan skill 전체 목록

### Business (11 orphan)

- `.claude/skills/business/admin-api-keys.md` — B2B SaaS Admin/API Key 패턴
- `.claude/skills/business/audit-log.md` — 감사 추적 (compliance 요구사항 충족)
- `.claude/skills/business/auth-oauth-social.md` — Kakao/Google/Apple 로그인 (AGENTS.md 2순위 ADR)
- `.claude/skills/business/feature-flags.md` — Feature Toggle 패턴
- `.claude/skills/business/media-handling.md` — 이미지/파일 업로드
- `.claude/skills/business/media-streaming.md` — 라이브/VOD 스트리밍
- `.claude/skills/business/notification-multichannel.md` — Push/Email/SMS/카카오톡 (AGENTS.md 4순위 ADR)
- `.claude/skills/business/rate-limiting.md` — Rate Limit 패턴
- `.claude/skills/business/subscription-billing-flows.md` — 결제 흐름 (체험→유료 전환)
- `.claude/skills/business/subscription-billing-metrics.md` — MRR/Churn 지표
- `.claude/skills/business/webhook-delivery.md` — Webhook 발신자 패턴 (HMAC, 재시도)

### Platform (16 orphan)

전체 디렉토리. `platform-engineer` agent는 있지만 어느 workflow에서도 호출 안 됨.

- backstage / platform-backstage / developer-self-service / golden-paths / golden-paths-infra
- mlops / ml-serving / mlops-tracking / llmops / k8s-gpu / k8s-gpu-scheduling
- kratix / secrets-management / wasm-edge / wasm-edge-iot
- (mlops-llmops는 deprecated 마킹됨, 제외)

### Legal (3 orphan, 전체)

- `.claude/skills/legal/child-data-protection.md`
- `.claude/skills/legal/data-subject-rights.md` (GDPR Art. 12-22)
- `.claude/skills/legal/kr-location-info-act.md` (한국 위치정보법)

### Architecture (8 orphan)

- agentic-ai-architecture / cell-based-architecture / composable-architecture
- data-mesh / kafka-msa-patterns / state-machine / strangler-fig-pattern / vertical-slice-architecture

### AI (4 orphan)

- agentic-coding / langchain-langgraph / prompt-engineering / rag-patterns

### DX (20 orphan, 발췌)

token-budget / team-topologies / dx-metrics / product-thinking / quarterly-review / adr-retrospective / dx-onboarding* (4종) / ai-first-playbook / dx-ai-agents / dx-ai-agents-orchestration / dx-ai-security / local-dev-makefile / refactoring-principles / token-efficiency 등.

### SRE/FinOps/Operations (발췌)

- finops/finops-ai/finops-showback/finops-automation 등 6개 (finops-advisor agent는 있으나 workflow 미연결)
- incident-postmortem (compliance-auditor와 분리됨)

---

## 4. 시나리오 dry-run — "한국 B2C SaaS 시작합니다"

현재 자산으로 step-by-step 실행했을 때:

| Step | 이상적 agent | 현 상태 |
|---|---|---|
| 요구사항 / MVP scope | product-engineer | ✅ |
| 도메인 모델 | architect-agent | ✅ |
| 멀티테넌시 ADR (Row/Schema/DB) | (전담 agent 없음) | ⚠️ tech-lead에 명시 부재, new-domain.yml 마지막 phase |
| 인증 ADR (Kakao/Google/Apple) | (전담 agent 없음) | ❌ 사용자가 직접 skill 호출해야 함 |
| 결제 ADR (PortOne/Toss/Stripe) | (전담 agent 없음) | ⚠️ domain-expert-billing optional |
| 알림 ADR (카카오톡 알림톡/SMS/Push) | (전담 agent 없음) | ❌ skill만 존재 |
| PIPA 사전 컴플라이언스 | (전담 agent 없음) | ❌ compliance-auditor는 사후 감사용 |
| 인프라 로드맵 (EC2 → kind → EKS) | infra-roadmap-planner | ❌ workflow에서 안 부름 |
| 사전 SLO 설계 | otel-expert | ❌ workflow 미연결 |
| 사전 FinOps 추정 | finops-advisor | ❌ workflow 미연결 |
| 구현 | go/java/python/frontend-expert | ✅ |
| 코드 리뷰 / 보안 | code-reviewer / security-scanner | ✅ |

→ **12 step 중 7개가 ❌/⚠️**. 사용자가 매번 수동으로 skill을 끌어와야 함.

---

## 5. 권장 신규 자산

### 5-1. 신규 agent 3개

| Agent | 책임 | 시나리오 가중치 | Consumes | Produces |
|---|---|---|---|---|
| **business-decision-agent** | 4 ADR(tenancy/auth/payment/notification) 일관성 orchestration | 한국 B2C: Kakao 1순위 / PortOne·Toss 1순위 / KakaoTalk 알림톡 / PIPA 동의 | user-story, mvp-scope, bounded-context | adr×4, tech-radar-entry |
| **platform-strategy-agent** | IDP/Backstage/MLOps/GPU/WASM 도입 결정 | Backstage IDP, Golden Path, 셀프서비스 카탈로그 | mvp-scope, bounded-context | adr, tech-radar-entry |
| **compliance-strategy-agent** | 설계 단계 built-in compliance | PIPA 24h / 위치정보법 / GDPR / PCI-DSS | mvp-scope, bounded-context, geo-target | adr, compliance-blueprint |

**Boundary 명시** (기존 agent와 분담):
- tech-lead = *전사 governance* (Tech Radar / Build vs Buy / RFC), business-decision-agent = *프로젝트 1개의 4 ADR 일관성*
- platform-engineer = *helm/k8s 구현*, platform-strategy-agent = *도입 결정*
- compliance-auditor = *사후 audit / evidence*, compliance-strategy-agent = *사전 설계*

### 5-2. 신규 workflow

**`bootstrap-new-saas.yml`** — 0→1 부트스트랩 12 stage:

```
external_inputs: [idea, geo-target]
 1. requirements          product-engineer
 2. compliance-baseline   compliance-strategy-agent
 3. bounded-context       architect-agent
 4. business-adr-chain    business-decision-agent
 5. platform-strategy     platform-strategy-agent      (optional)
 6. infra-roadmap         infra-roadmap-planner
 7. slo-design            otel-expert
 8. finops-estimate       finops-advisor
 9. api-design            architect-agent
10. implementation        go|java|python|frontend-expert
11. code-review           code-reviewer
12. security-baseline     security-scanner (parallel)
```

기존 `new-domain.yml`은 "기존 SaaS에 도메인 추가" 시나리오로 scope 재정의.

### 5-3. 기존 미연결 agent 통합

| Agent | 현 상태 | 신규 workflow에서 호출 |
|---|---|---|
| infra-roadmap-planner | 정의 있음, 미사용 | bootstrap-new-saas stage 6 |
| finops-advisor | 정의 있음, 미사용 | bootstrap-new-saas stage 8 |
| compliance-auditor | audit 전용 | compliance-strategy-agent와 handoff chain로 연결 (사후 검증) |

---

## 6. Out of Scope (별도 라운드)

다음은 본 라운드에서 다루지 않는다.

| 영역 | 사유 | 다음 라운드 권장 |
|---|---|---|
| ai-arch-decision-agent | Agentic AI 시나리오는 일반 SaaS 부트스트랩과 분리 | AI 프로젝트 도입 시 |
| dx-framework-agent | DX는 *팀 내부* 결정 (조직 운영), 새 프로젝트 부트스트랩과 결합도 낮음 | 팀 토폴로지 재편 시 |
| 신규 rules 작성 | `docs/adr/` 3 ADR Proposed 상태 (subagent/tool-safety/context-pollution) | ADR Accept 후 |

---

## 7. 재점검 일정

- **2026-11-11 (6개월 후)**: 본 보고서 권장 사항 도입 후 사용 패턴 재측정
- 측정 지표:
  - bootstrap-new-saas workflow 호출 횟수
  - 신규 3 agent 실제 호출 빈도 (각각 ≥ 3회 / 6개월 목표)
  - orphan skill 수 (현 60+ → 30 이하 목표)
- 6개월 시점 ADR 재평가는 `dx/adr-retrospective` skill 사용

---

## 부록: 검증 명령

```bash
# 1. agent 등록 확인
yq '.agents | length' .claude/inventory.yml          # 46 → 49
yq '.workflows | length' .claude/inventory.yml       # 10 → 11

# 2. handoff lint
bash scripts/validate-agent-handoff.sh

# 3. orphan skill 재측정 (참조 grep)
for d in business platform legal architecture ai; do
  for f in .claude/skills/$d/*.md; do
    refs=$(grep -rl "$(basename $f .md)" .claude/agents/ .claude/workflows/ 2>/dev/null | wc -l)
    [ "$refs" = "0" ] && echo "ORPHAN: $f"
  done
done
```
