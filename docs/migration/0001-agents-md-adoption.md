# 0001 — AGENTS.md 표준 도입 + 디자인 시스템 위계 완성

**기간**: 2026-04-27 ~ 2026-05-04 (9 세션)
**상태**: Completed
**작성일**: 2026-05-04

## Background

2026-04 기준 AI 코딩 도구 시장 현황:

- **시장 점유율** (JetBrains 2026-01): GitHub Copilot 29% / Cursor 18% / Claude Code 18% / Windsurf 8%
- **SWE-bench Verified 모델 격차**: 6개 모델이 0.8점 차이로 경쟁
  - Claude Code (Opus 4.6) 80.9% / Claude Opus 4.6 80.8% / MiniMax M2.5 80.2% / Gemini 3.1 Pro 78.80% / GLM-5 77.8%

→ **단일 도구 lock-in이 위험한 구조**. Claude Code 점유율 18%, 모델 성능 격차 미미.

[forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (92K stars, 60줄 CLAUDE.md) 분석 + Linux Foundation **AGENTS.md** 표준 (60K+ repos 채택) 발견 → 미니멀리즘 + 표준화 양 축으로 시스템 재설계 결정.

## Before / After (정량 비교)

| 지표 | Before (2026-04-27) | After (2026-05-04) | 변화 |
|---|---|---|---|
| **AGENTS.md** | 없음 | 232줄 (Linux Foundation 표준) | 신규 |
| **CLAUDE.md** | 단일 통합 파일 | 69줄 (Claude 전용만) | 분리 + 압축 |
| **Skills** | 216 | **239** (~92,600줄, 21 카테고리) | +23 |
| **Agents** | 46 | 46 | — |
| **Rules** | 14 | 14 (~1,840줄, 모두 sweet spot) | 정리 |
| **Workflows** | 7 (bundle) | **10** (bundle 7 + handoff-flow 3) | +3 |
| **Lint scripts** | 0 | **5** (drift / frontmatter / inventory / labels / handoff) | 신규 |
| **CI jobs** | 4 | 5 (drift job 추가) | +1 |
| **Plugin bundles** | 12 | 12 | — |
| **Lock-in 위험** | 높음 (Claude only) | **낮음** (30+ 도구 호환) | 해소 |
| **Drift 자동 검증** | 없음 | 매 PR/push 자동 | 신규 |

## 트랙별 결과

### P0 — 갭 매트릭스 (1차 세션)

3축 매트릭스 도입: **도메인 × 단계 × 시간불변성/이식성**.

- 도메인 axis: 부트스트랩 / 운영 공통 / Cross-cutting / 인증 / 알림 / 결제 / 미디어 / 검색 / Webhook / 회고 메타
- 단계 axis: 기획 → 설계 → 구현 → 운영 → 회고
- 라벨: model-dependent vs independent / universal vs claude-only

매트릭스로 빈 cell 시각화 → P1~P3 우선순위 결정 근거.

### P1 — 비즈니스 부트스트랩 (1차 세션)

| Skill | 줄 수 | 핵심 |
|---|---|---|
| `business/multi-tenancy.md` | 339 | Row/Schema/DB 격리, RBAC, 초대 |
| `business/auth-oauth-social.md` | 346 | Google/Apple/Kakao, PKCE, Magic Link, 2FA |
| `business/payment-integration.md` | 292 | Stripe/Toss/PortOne, Token-first, Webhook 수신, Saga |
| `business/notification-multichannel.md` | 332 | Push/Email/SMS, Fallback, Notification Center |

### P2-B — Cross-cutting (2차 세션)

| Skill | 줄 수 | 핵심 |
|---|---|---|
| `business/audit-log.md` | 393 | append-only, tenant-scoped, GDPR/SOC2, pg_partman |
| `business/rate-limiting.md` | 417 | Sliding Window/Token Bucket, multi-layer, fail-open/close |
| `business/feature-flags.md` | 363 | OpenFeature, kill-switch, stale flag 정리 |
| `business/admin-api-keys.md` | 434 | PAT/Service Token, Opaque vs JWT, zero-downtime 회전 |

### P2-A — 수익화 + 미디어 (3~5차 세션)

| Skill | 줄 수 | 핵심 |
|---|---|---|
| `business/subscription-billing.md` | 348 | Hub. Plan/PlanVersion, 상태 머신, Multi-currency, SubscriptionGateway |
| `business/subscription-billing-flows.md` | 295 | Proration / Dunning / Plan Change / Metered / Trial / Seat |
| `business/subscription-billing-metrics.md` | 193 | MRR Movement / Cohort / Voluntary vs Involuntary SQL |
| `business/credit-system.md` | 472 | CreditGateway, PriceBook=PlanVersion, 의사코드 2개, free tier 차감 |
| `business/media-handling.md` | 467 | StorageGateway, Provider 매트릭스, EXIF/AV 스캔, 정통망법 2026-07 |

**외부 검색 적극 활용** — 정통망법 2026-07 이미지 차단 의무, R2 vs S3 정량 가격 (R2=$0/S3=$0.085 egress), imgproxy AVIF Graviton3 벤치, presigned URL 보안.

### P2-C — 시스템 엔지니어링 (6차 세션)

자산 안정화를 위한 자동화:

| 산출물 | 검증 항목 |
|---|---|
| `scripts/validate-rules-drift.sh` | Phase D 모델 ID 마커 + AGENTS.md↔rules 양방향 + Critical 룰 11개 + sweet spot |
| `scripts/validate-skill-frontmatter.sh` | Agents 100% (46/46) + Skills hybrid (frontmatter + H1 컨벤션) |
| `scripts/generate-inventory-labels.sh` | 휴리스틱 분류 (model_dependency / portability / domain_specificity) |
| Drift fix 2건 | `agents/otel-expert.md` frontmatter, `skills/dx/documentation-templates.md` name 필드 |

CI drift job 추가. 라벨 분포: high=24, claude-only=3, project-specific=18.

### P2-D — 회고 메타-자산 (7차 세션)

EXPLORE 결정: postmortem-automation은 기존 `operations/incident-postmortem.md` (470줄, blameless/5 Whys/PIPA 24h)와 **중복으로 drop**. 차별화 가능한 2개만 작성.

| Skill | 줄 수 | 핵심 |
|---|---|---|
| `dx/adr-retrospective.md` | 368 | 6/12개월 재평가, hit rate / lifespan / supersede frequency, retrospective-ready ADR 템플릿 |
| `dx/quarterly-review.md` | 417 | DORA 4 metrics SQL, SLO 달성률, 인시던트 패턴, MRR cohort, 한국 회계연도/PG 수수료 |

### P2 추가 — 비즈니스 (8차 세션)

| Skill | 줄 수 | 핵심 |
|---|---|---|
| `business/search-recommend.md` | 543 | SearchGateway, 한국어 nori, Outbox 인덱스 sync, Hybrid BM25+vector, 추천 3패턴 |
| `business/webhook-delivery.md` | 458 | **발신자 관점**, WebhookGateway, HMAC + jitter + Circuit breaker + SSRF 방지 + DLQ |
| `business/media-streaming.md` | 428 | StreamingGateway, LL-HLS/WebRTC/RTMP, DRM 3대, Multi-CDN, Live→VOD |

**Gateway 패턴 6번째 정착**: Subscription / Credit / Storage / Search / Webhook / Streaming.

### P3 — 위계 트랙 (9차 세션)

agent 간 산출물 흐름을 데이터로 표현 — 디자인 시스템 위계 완성.

| 산출물 | 핵심 |
|---|---|
| `.claude/agents/_handoff.yml` | 43 artifact vocabulary + 46 agent produces/consumes 매핑 |
| `.claude/workflows/feature-development.yml` | 요구사항 → 설계 → ADR → 구현 → 리뷰(병렬) → 모니터링 → 부하테스트 → 기록 |
| `.claude/workflows/incident-to-action.yml` | triage → RCA → postmortem → 재발방지 ADR → monitoring 강화 → runbook |
| `.claude/workflows/new-domain.yml` | discovery → bounded-context → api-design → cost-decision → domain expert 분기 |
| `scripts/validate-agent-handoff.sh` | (1) 등록 (2) vocabulary 일관성 (3) workflow 핸드오프 valid |

**디자인 시스템 4계층**:
1. AGENTS.md (Layer 1, universal)
2. SKILL.md frontmatter (Layer 2, 30+ 도구 호환)
3. Claude-only (Layer 3, agents/commands/plugins)
4. **handoff** (Layer 4, 산출물 흐름 데이터화) — P3 신규

## 거버넌스 도입

매 PR/push에서 자동 검증 (5종 lint, CI drift job):

```
1. Rules drift (validate-rules-drift.sh)
   - Phase D 모델 ID 마커 (claude-3-* / claude-*-4-2025* = 0건)
   - AGENTS.md ↔ .claude/rules/ 양방향 참조 무결성
   - Critical 룰 11개 키워드 일관성
   - Sweet spot ≤ 200줄 (경고)

2. Frontmatter (validate-skill-frontmatter.sh)
   - Agents 100% YAML frontmatter 강제
   - Skills hybrid (frontmatter or H1 컨벤션)

3. Inventory freshness (generate-inventory.sh validate)
4. Inventory labels freshness (generate-inventory-labels.sh validate)
5. Agent handoff (validate-agent-handoff.sh)
   - 모든 agent _handoff.yml 등록
   - vocabulary 일관성
   - workflow 핸드오프 valid (external_inputs 필드)
```

## 학술 근거

### Anthropic SkillsBench (arxiv 2602.12670)

- **인간 큐레이션 skill: +16.2pp 평균 향상**
- **AI 자체 생성 skill: -1.3pp (악화)**
- 모델별 편차 +13.6pp ~ +23.3pp → **점수는 시간 가변**
- **Focused 2-3 모듈 > Comprehensive** → karpathy 미니멀리즘 검증

### AGENTS.md (Linux Foundation 표준)

- 2025-12 Linux Foundation 산하 Agentic AI Foundation에 기증
- 60,000+ repo 채택
- Claude Code, Cursor, Codex, Copilot, Windsurf, Devin, Gemini CLI 모두 지원

## Gateway 패턴 정착 (6번째)

P2-A subscription-billing에서 시작한 lock-in 회피 추상화 — 6번 반복으로 패턴 확립.

```
SubscriptionGateway   (subscription-billing)
CreditGateway          (credit-system)
StorageGateway         (media-handling)
SearchGateway          (search-recommend)
WebhookGateway         (webhook-delivery)
StreamingGateway       (media-streaming)
```

비즈니스 로직은 Gateway 인터페이스만 알아야 하고, Provider 구현은 교체 가능 — Stripe/Toss/PortOne, Algolia/OpenSearch/Naver, S3/R2/GCS/Naver 등 자유 교체.

## Lessons Learned

### 메타 회고 사전 반영 (5차 세션부터)

`tmp/04-reviews.md`에 self-review 프로세스 도입 후, 매 skill 작성 시작 전에 이전 회고 결과를 적용 — 재작업 회피.

- 의사코드 2개 처음부터 (sync 코드 + 비동기 worker)
- 한국 시장 깊이 박스 (법령 + Provider + 청소년/PIPA)
- Multi-currency / 통화별 PriceBook + 반올림 ADR
- Provider 매트릭스 정량 ($/GB, latency 수치 포함)
- Gateway 추상화 (lock-in 회피)
- metrics SQL hook (subscription-billing-metrics 패턴 확장)

### 외부 검색 적극 활용 (5차 세션부터)

P2-A media-handling에서 외부 검색 5건으로 "교과서에 없는" 한국 차별화 발견:
- 정통망법 2026-07-01 이미지 차단 의무 확대 (KDI/국가법령정보센터)
- R2 vs S3 vs GCS 정량 가격 (Vantage/Mixpeek 2026)
- imgproxy AVIF Graviton3 벤치
- presigned URL 보안 (AWS prescriptive guidance, IMDSv2)
- Naver Cloud CDN+ 망내 latency

### EXPLORE 우선 (P2-D 학습)

postmortem-automation 작성하려다 EXPLORE 단계에서 `operations/incident-postmortem.md` (470줄)이 이미 cover하는 것을 발견. **중복 회피로 1개 skill drop**. EXPLORE 없이 PLAN 진입 금지 룰의 가치 검증.

### CI 결정성 (P2-D 직후 fix)

`inventory-labels.yml`의 `last_modified` 필드가 `git log -1` 기반인데, staging 직전 generate 시 commit 전 author date를 반환. CI fresh clone에서 새 commit 날짜 → 영구 outdated. 필드 제거로 결정성 회복 (commit `e138025`).

→ **자동 생성 자산은 환경 간 결정적이어야 한다**. timestamp / git log 같은 환경 의존 값은 generated 파일에서 제거하거나 비교에서 제외.

### Rules sweet spot (Opus 4.7 cleanup)

`rules/documentation.md`가 785줄로 sweet spot(≤200줄) 5배 초과 → 묻힘. **127줄로 축약** + 12종 템플릿은 `skills/dx/documentation-templates.md`(241줄)로 분리 (Phase D, commit `de69415`). 모든 rules sweet spot 통과.

→ **rules는 매 대화 자동 로딩이라 길면 효과 ↓**. 상세는 skill로 분리.

## 작업 이력 (9 세션)

| # | 일자 | 트랙 | 산출물 |
|---|---|---|---|
| 1 | 2026-04-27 | AGENTS.md 도입 + P0 갭매트릭스 + P1 4개 | AGENTS.md (232줄), gap-matrix v1, business/* P1 |
| 2 | 2026-04-28 | P2-B Cross-cutting | audit-log, rate-limiting, feature-flags, admin-api-keys |
| 3 | 2026-04-28 | P2-A subscription-billing | hub/flows/metrics 3 분할 (836줄) |
| 4 | 2026-04-28 | P2-A credit-system | CreditGateway 추상화, PriceBook=PlanVersion |
| 5 | 2026-05-04 | P2-A 종결 + Phase D | media-handling, Opus 4.7 cleanup |
| 6 | 2026-05-04 | P2-C 시스템 엔지니어링 | 4 lint scripts + CI drift job |
| 7 | 2026-05-04 | P2-D 회고 메타-자산 | adr-retrospective, quarterly-review (postmortem drop) |
| 8 | 2026-05-04 | P2 비즈니스 추가 | search-recommend, webhook-delivery, media-streaming |
| 9 | 2026-05-04 | P3 위계 | _handoff.yml, 3 workflows, handoff lint |

## 보류 (Out of Scope)

- **외부 도구 검증**: Cursor / Codex / Copilot / Windsurf에서 AGENTS.md 작동 확인. 사용자가 직접 도구 설치 후 테스트 필요. ~30분 예상.
- **Top-down workflow 추가 시나리오**: 현재 3개 (feature-development / incident-to-action / new-domain). 추가 후보로 release-cycle, security-incident, db-migration 등 가능 (P3 후속).
- **agent별 frontmatter produces/consumes**: 단일 `_handoff.yml`로 통합 정의했지만, 각 agent .md에도 동일 정보를 frontmatter로 복사하는 안이 있었다. 작업량 (46개) 대비 lint가 단일 파일로 검증되는 이점이 있어 보류.

## 핵심 트레이드오프 (영구 기록)

1. **AGENTS.md 232줄 vs 권장 140줄** — 정보 가치로 수용. 압축 시 손실
2. **karpathy 4원칙 vs 우리 룰 일부 중복** — 강조 효과로 수용
3. **P2-D postmortem drop** — `operations/incident-postmortem.md` 충분, 추가 작성 시 중복
4. **inventory-labels 휴리스틱** — false positive 가능 (예: business/credit-system이 high model_dependency). 사람 검증 필요
5. **search-recommend 543줄** — sweet spot 살짝 초과지만 핵심 내용 압축 회피 룰 우선

## 결과 (Summary)

```
Before: 216 skills + 14 rules + 7 workflows + 0 lint + lock-in 위험
After:  239 skills + 14 rules + 10 workflows + 5 lint + lock-in 회피 (AGENTS.md)
        + 디자인 시스템 4계층 + 6 Gateway 추상화 + CI drift job
        + 매트릭스 회고/검색/Webhook/Live 4행 [●] 진입
```

**총 작업량**: ~9시간 (9 세션, ~1시간/세션 평균)
**총 신규 자산**: 16 skills + 1 vocabulary + 3 workflows + 5 scripts
**총 코드 변경**: ~10,000줄 (skills + workflows + scripts + AGENTS.md/CLAUDE.md)
