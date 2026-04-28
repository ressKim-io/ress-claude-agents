# Subscription Billing — Hub

SaaS 구독 결제 메인 hub — Provider 매트릭스(+SubscriptionGateway 추상화), 한국 정기결제, 도메인 모델, 빌링 사이클 상태 머신, Webhook+idempotency, 보안, 안티패턴, ADR, Quick Start. 일회성 결제(`payment-integration.md`)의 자연 연장. 신규 SaaS 정기 수익화 부트스트랩.

> **이 skill은 hub다.** 운영 흐름(Proration/Dunning/Plan Change/Multi-currency/Metered/Trial/Seat) → `subscription-billing-flows.md`. 메트릭/대시보드 → `subscription-billing-metrics.md`. 신규 SaaS 시작 시 이 hub부터 읽고 필요 시 sub 파일로 분기.

## When to Use

- MVP 결제 완료 후 정기 수익 모델로 확장 (`payment-integration.md` 다음 단계)
- B2B SaaS — Free/Pro/Team/Enterprise tier 설계
- B2C 멤버십 — 월간/연간 구독, 광고 제거, 프리미엄 기능
- AI 제품 — 토큰/seat 혼합 (`credit-system.md`와 결합)
- 기획자가 "월 9,900원 구독 모델로 가요" 물어볼 때

**관련 skill**: `payment-integration.md`, `multi-tenancy.md`, `notification-multichannel.md`, `feature-flags.md`, `audit-log.md`, `rate-limiting.md`, `admin-api-keys.md`, `auth-oauth-social.md`
**관련 agent**: `saga-agent`, `tech-lead` (구독 모델 ADR), `database-expert` (invoice schema), `messaging-expert` (Webhook 큐)

---

## 1. Provider 결정 매트릭스

`payment-integration.md`가 일회성·국내 PG 라우팅 중심이라면, 구독은 **반복 빌링 인프라가 핵심**이다.

| 시장 / 요구 | 추천 | 이유 |
|---|---|---|
| 글로벌 SaaS, B2B 표준 | **Stripe Billing** | Subscriptions/Invoicing/Tax/Smart Retries 통합. de facto 표준. |
| EU/글로벌 + VAT/MoR 자동 | **Paddle / Lemon Squeezy** | Merchant of Record. 세금/송장/규제 대신 처리. |
| 엔터프라이즈 B2B (수동 인보이스 포함) | **Chargebee / Recurly / Maxio** | 견적-계약-인보이스 워크플로우 우수, NetSuite 통합 |
| 한국 정기결제 (자동 카드 빌링) | **PortOne 정기결제 / Toss 자동결제 / KCP 빌링키** | 국내 PG는 빌링키(billing_key) 방식. 카드 등록 1회 후 매월 청구. |
| 한국 + 글로벌 듀얼 | **Stripe (글로벌) + PortOne (국내)** | 라우팅 + 통합 invoice 도메인 필요 |
| Indie/소규모 + 빠른 출시 | **Lemon Squeezy / Polar.sh** | MoR + Stripe 인프라, VAT 무신경 |
| Open-source self-hosted | **Lago / Killbill** | metered billing, 커스터마이즈 가능 (운영 부담↑) |

> **2026 트렌드**: AI/usage-based billing 폭증. Stripe Meters API, Lago, Orb이 표준화. 정액(seat) + 사용량(token/API call) 혼합 모델이 디폴트화.

> **함정**: Provider lock-in 가장 심한 영역. 빌링키/customer ID/subscription ID는 PG 외부 추출 어렵다. **시작 전 ADR로 마이그레이션 시나리오까지 검토**.

### Provider 추상화 — Lock-in 회피 (`payment-integration.md` Pattern C 연장)

PG 1개로 시작해도 **인터페이스로 격리**하면 후행 PG 추가/마이그레이션 비용 ↓. 여러 PG에서 공통적으로 필요한 동작:

```
SubscriptionGateway (interface)
  ├─ create_customer(email, currency) → ProviderCustomerId
  ├─ attach_payment_method(customer, token)
  ├─ create_subscription(customer, plan, trial_days?) → ProviderSubscriptionId
  ├─ change_plan(sub, new_plan, proration: enum)
  ├─ cancel(sub, at_period_end: bool)
  ├─ preview_upcoming(sub, changes) → InvoicePreview
  ├─ report_usage(sub, meter, quantity, idempotency_key)  # metered
  └─ verify_webhook(payload, signature) → NormalizedEvent

Adapters:
  ├─ StripeAdapter        (글로벌)
  ├─ PortOneAdapter       (한국 빌링키)
  ├─ TossBillingAdapter   (한국 자동결제)
  └─ PaddleAdapter        (MoR)

NormalizedEvent (PG 무관):
  { event_type, subscription_id, customer_id, amount, currency, occurred_at, raw }
```

**원칙**:
- 도메인 코드는 `SubscriptionGateway`만 의존. PG SDK 직접 호출 금지.
- Webhook은 어댑터에서 정규화된 이벤트로 변환. 비즈니스 로직은 정규화 이벤트만 처리.
- 모든 PG 식별자(provider_*_id)는 `provider`(stripe/portone/...)와 함께 저장. 마이그레이션 시 분리 가능.

> 단일 PG로 시작 → 인터페이스만 정의 → 두 번째 PG 필요 시 어댑터 추가. **처음부터 다중 PG 추상화 구현하지 말 것** (YAGNI).

### 한국 정기결제 깊이 (Stripe와 다른 포인트)

| 항목 | Stripe | 한국 PG (PortOne/Toss/KCP) |
|---|---|---|
| 카드 토큰화 | `SetupIntent` → `PaymentMethod` | **빌링키(billing_key)** 발급 (등록 1회 후 재사용) |
| 카드 만료 자동 갱신 | Card Account Updater (Visa/MC/Amex) | **없음** — 사용자에게 재등록 요청 필수 |
| Smart Retry (ML) | 내장 | **없음** — 자체 cron + 백오프 직접 구현 |
| 부분 환불 | 표준 지원 | **PG별 상이** — 일부 미지원, 당월 한정 |
| 정기결제 승인 시간 | 24/7 | **PG별 점검 시간 존재** (보통 새벽 2~6시) |
| 세금계산서/현금영수증 | 미지원 (Stripe Tax는 sales tax) | **PG에서 발급 또는 별도 ERP** (Bill36524/더존) |
| Webhook 재시도 정책 | 최대 3일 | **PG별 다름** (수 시간~1일) |

**구현 함정**:
- 빌링키 발급 실패 처리: 카드 검증 실패 vs PG 점검 시간. 에러 코드 매핑 필수.
- 빌링키 만료 = 카드 만료. 갱신 자동화 없으므로 **만료 D-7 알림 + 재등록 UI** 필수 (`notification-multichannel.md`).
- 한국 PG는 보통 **익일 정산**. invoice.paid → 실제 정산 사이 1영업일 갭. 회계 매핑 시 주의.
- 세금계산서/현금영수증 발행은 **PG와 ERP 이중 발행 금지**. 누가 책임지는지 ADR 필수.

→ 한국 단일 시장이면 Stripe 무시 가능. 한국+글로벌 듀얼이면 SubscriptionGateway 추상화 필수.

---

## 2. 도메인 모델 (필수)

```
Plan ─────────── PlanVersion ─────── Price
  └ id            └ effective_at      └ amount, currency, interval
  └ name          └ feature_set       └ usage_type: licensed|metered

Customer (1) ── (N) Subscription (1) ── (N) SubscriptionItem
                  ├─ status: trialing|active|past_due|canceled|unpaid|paused
                  ├─ provider_subscription_id  (Stripe sub_...)
                  ├─ current_period_start/end  (단일 source of truth)
                  ├─ cancel_at_period_end      (해지 예약)
                  ├─ tenant_id                 (multi-tenancy 결합)
                  └─ trial_end

Subscription (1) ── (N) Invoice (1) ── (N) InvoiceLineItem
                       ├─ status: draft|open|paid|uncollectible|void
                       ├─ amount_due, amount_paid, amount_remaining
                       ├─ period_start/end
                       ├─ tax_amount, discount_amount
                       └─ provider_invoice_id

Invoice (1) ── (N) PaymentAttempt   ← payment-integration.md 모델 재사용
                   └ idempotency_key, raw_response, provider_payment_id

UsageRecord (metered)
  ├─ subscription_item_id
  ├─ quantity, timestamp
  └─ idempotency_key  (중복 집계 방지)
```

**핵심 원칙**:
- **Plan ≠ PlanVersion ≠ Price**: 가격/혜택은 시간에 따라 바뀐다. 기존 가입자는 grandfather된 PlanVersion 유지.
- **Subscription = 상태 머신**: 임의로 status 바꾸지 말고 transition 메서드만 노출.
- **Invoice는 immutable이 원칙**: 발행 후 수정 금지. 오류 시 credit note(환불 invoice) 발행.
- **`current_period_*`은 PG에서 받는다**: 자체 계산 시 timezone/leap year/부분 환불로 drift 발생.
- **`tenant_id` 일찍 박는다**: B2B는 거의 항상 multi-tenant. 후행 추가 시 backfill 지옥. → `multi-tenancy.md`

---

## 3. 빌링 사이클 상태 머신

```
              create
   ┌────────────────────┐
   ▼                    │
trialing ──trial_end──▶ active ◀───retry success───┐
   │                     │                          │
   │ trial_end+미결제    │ payment_failed            │
   │                     ▼                          │
   │                  past_due ──────dunning───────┤
   │                     │                          │
   │                     │ retries 모두 실패         │
   │                     ▼                          │
   └─trial_end+미결제──▶ unpaid / canceled
                          │
                          ▼
                      (기능 차단, 데이터 보존 N일)
```

| 상태 | 의미 | 기능 접근 | 다음 상태 |
|---|---|---|---|
| `trialing` | 체험 기간 | 전체 또는 제한 | `active` (결제) / `canceled` (미결제+미해지) |
| `active` | 정상 구독 | 전체 | `past_due` (결제 실패) / `canceled` (해지 예약 후 만료) |
| `past_due` | 결제 실패, 재시도 중 | 전체 또는 grace period | `active` (재시도 성공) / `unpaid` (모두 실패) |
| `unpaid` | 재시도 모두 실패 | 차단 | `active` (수동 결제) / `canceled` (정리) |
| `canceled` | 해지 완료 | 차단 | (terminal) |
| `paused` | 사용자/관리자가 일시정지 | 차단 또는 read-only | `active` (재개) |

**전이 규칙**:
- 모든 state change는 `audit-log`에 기록 (`audit-log.md`)
- 차단 시 `feature-flags`로 fallback UI 결정 (`feature-flags.md`)

→ Proration/Dunning/Plan Change 등 **상태 전이를 일으키는 운영 흐름**은 `subscription-billing-flows.md` 참조.

---

## 4. Webhook / 동기화 (payment-integration 패턴 재사용)

`payment-integration.md` §4의 webhook 원칙 모두 적용. 구독 추가 이벤트:

| Stripe Event | 처리 |
|---|---|
| `customer.subscription.created` | 구독 생성, audit-log |
| `customer.subscription.updated` | 상태/plan/quantity 변경 동기화 |
| `customer.subscription.deleted` | 해지 완료, 기능 차단 (grace period 후) |
| `customer.subscription.trial_will_end` | trial 종료 3일 전 알림 |
| `customer.subscription.paused` | 일시정지, 기능 차단 |
| `customer.subscription.resumed` | 재개, 기능 복원 |
| `customer.subscription.pending_update_applied` | scheduled change 적용 시점 동기화 |
| `invoice.upcoming` | 다가오는 청구 사전 통지 (보통 7일 전) |
| `invoice.created` | 신규 invoice 생성 |
| `invoice.finalized` | 발행 확정, 결제 시도 직전 |
| `invoice.paid` | 결제 성공, 다음 주기 활성 |
| `invoice.payment_failed` | dunning 시작 → `subscription-billing-flows.md` §2 |
| `invoice.payment_action_required` | 3DS 등 추가 인증 필요 |

**핵심**: PG webhook이 source of truth. 자체 DB와 drift 시 reconciliation job 정기 실행.

### Webhook idempotency (필수 의사코드)

```python
# 동일 event_id 재전송 시 1회만 처리
@webhook_handler("invoice.paid")
def handle(event):
    # SET NX EX = 24h 단일 명령 → race condition 차단
    if redis.set(f"stripe:event:{event.id}", "1", nx=True, ex=86400) is None:
        return 200  # 이미 처리됨, 즉시 ACK

    try:
        sync_invoice_paid(event.data.object)  # 비즈니스 로직
    except Exception as e:
        redis.delete(f"stripe:event:{event.id}")  # 재시도 가능하도록 해제
        raise

    audit_log.write("invoice_paid", event.data.object.id)
    return 200
```

**원칙**: ACK는 5초 내. 무거운 처리는 큐(`messaging/redis-streams.md`)로 위임. event_id 중복 키는 Stripe `event.id`(`evt_...`) 그대로 사용.

### 테스트 전략 (Stripe Test Clocks)

구독은 시간 흐름이 본질이라 wall-clock 테스트 불가. **Stripe Test Clocks**로 시간 가속 시뮬레이션 표준화.

```bash
# trial 종료 + dunning 단계 검증 흐름
stripe test_clocks create --frozen-time=$(date +%s)
stripe customers create --test-clock=clock_xxx ...
stripe subscriptions create --customer=cus_xxx --trial-period-days=14 ...
# 14일 + 1초 advance → trial_will_end → trial_end → invoice.payment_failed 순차 발생
stripe test_clocks advance --frozen-time=$(date -d "+15 days" +%s)
```

| 도구 | 용도 |
|---|---|
| `stripe test_clocks` | 구독 주기 가속, trial/dunning/proration 결정론적 검증 |
| `stripe-cli listen` | 로컬 webhook 포워딩, 서명 검증 + 재전송 시뮬레이션 |
| `stripe-mock` | API 호출 unit test (네트워크 없이) |
| `stripe trigger <event>` | 특정 이벤트 강제 발생 (CI 회귀 테스트) |

→ `payment-integration.md` §11 sandbox 가이드와 결합. Reconciliation job도 Test Clock으로 회귀 검증.

---

## 5. 보안 (payment-integration §6 + 추가)

- ❌ **클라이언트가 plan/quantity 결정 → 즉시 적용**: 반드시 서버에서 권한/요금 검증
- ❌ **Subscription 직접 status 수정**: 항상 PG API → webhook → DB 흐름
- ❌ **Trial을 클라이언트 시간/state로 결정**: 서버 시간 + PG `trial_end` 기준
- ❌ **무료 plan 사용자에게 PG customer 안 만들기**: 추후 upgrade 시 마이그레이션 함정. 가입 시 customer 생성, free는 무료 price.
- ✅ **결제 권한 RBAC**: admin/owner만 plan change. `audit-log`에 actor/IP 기록.
- ✅ **API key scope 제한**: subscription 변경 endpoint는 별도 scope (`admin-api-keys.md`)

---

## 6. 안티패턴 모음

| 안티패턴 | 왜 위험 | 올바른 방법 |
|---|---|---|
| Subscription status를 cron으로 매일 체크해서 동기화 | webhook 누락/race | webhook + 정기 reconciliation 병행 |
| Free tier 사용자는 PG에 customer 안 만듦 | 추후 upgrade 시 migration 헬 | 가입 시점에 customer 생성, free price 부여 |
| Plan을 enum string ("FREE"/"PRO")으로만 관리 | 가격/혜택 바뀌면 기존 사용자 영향 | Plan + PlanVersion + Price 분리 |
| Proration을 자체 계산 | timezone/leap year/할인 결합 시 drift | PG에 위임 (`proration_behavior`) |
| Invoice를 직접 수정 | 회계/legal 위험 | credit note(환불 invoice) 발행 |
| Dunning 이메일을 단일 템플릿으로 | 회수율↓ | 3-stage (soft/urgent/final) + 다채널 |
| Trial 종료를 클라이언트 시간으로 | 위변조 가능 | 서버 + PG `trial_end` |
| 사용량 record를 즉시 PG report | spike 시 PG rate limit | 배치/aggregator 패턴 |
| `cancel_at_period_end` 무시하고 즉시 차단 | 사용자 신뢰 파괴 | 주기 만료까지 active 유지 |
| Seat 감소를 즉시 환불 | 어뷰즈 (월말 충전 → 월초 감소) | 다음 주기부터 / credit balance |

---

## 7. ADR 템플릿 — 구독 결정

```markdown
## 구독 빌링 ADR

| 항목 | 결정 | 대안 | 근거 |
|---|---|---|---|
| Provider | Stripe Billing | Paddle / Chargebee / 자체 | 글로벌 표준, MoR 불필요 |
| Plan 모델 | Free + Pro + Team + Enterprise | 단일/이중 tier | B2B SaaS 표준 |
| 빌링 단위 | Tenant | User / Seat | B2B 팀 라이센스 |
| 결제 주기 | 월간 + 연간(20% 할인) | 월간만 / 분기 | LTV 향상 |
| Trial | 14일 + 카드 등록 | 7일 / 카드 미등록 | 어뷰즈 방지 + 전환율 |
| Proration | upgrade 즉시 / downgrade 다음 주기 | 모두 즉시 / 모두 다음 주기 | UX + 회계 단순 |
| Dunning | Stripe Smart Retries + 자체 3-stage 이메일 | 단일 이메일 | 회수율 |
| 해지 정책 | 주기 끝에 종료, 환불 X | 즉시 + 환불 | B2B 표준 |
| 세금 | Stripe Tax (글로벌) + 자체 부가세 (한국) | 자체 / Avalara | 비용/한국 별도 |
| 미수 | 4회 재시도 후 unpaid → 30일 grace → 데이터 보존 90일 | 즉시 차단 | 사용자 신뢰 |
```

→ `agents/tech-lead` 호출하여 ADR 작성 위임.

---

## 8. Quick Start Checklist (신규 SaaS)

- [ ] `payment-integration.md`로 일회성 결제 인프라 먼저 구축
- [ ] Plan/PlanVersion/Price 도메인 모델 설계 (immutable PlanVersion)
- [ ] Subscription 상태 머신 + audit-log 통합
- [ ] PG Customer = 가입 즉시 생성 (free 사용자도 포함)
- [ ] Subscription/Invoice/Item 도메인 + tenant_id 결합
- [ ] Webhook 13개 이벤트 핸들러 (이 문서 §4)
- [ ] Smart Retries + Card Account Updater 활성화 (Stripe), 한국 PG는 자체 dunning
- [ ] Dunning 3-stage 이메일 + notification-multichannel 결합 → `subscription-billing-flows.md` §2
- [ ] Customer Portal 링크 (해지/카드 변경 self-serve)
- [ ] Plan change 미리보기 (`upcoming_invoice`) → `subscription-billing-flows.md` §3
- [ ] feature-flags + plan-based gating 결합
- [ ] Trial 어뷰즈 방지 (도메인/카드 fingerprint/rate-limit) → `subscription-billing-flows.md` §6
- [ ] 모니터링: MRR/ARR/churn/recovery → `subscription-billing-metrics.md`
- [ ] 한국 세금계산서/현금영수증 워크플로우 (B2B/B2C 분기)
- [ ] Reconciliation job: PG ↔ DB 일일 비교

---

## 9. 관련 자원

**같은 카테고리 (subscription-billing 시리즈)**:
- `business/subscription-billing-flows.md` — Proration/Dunning/Plan Change/Multi-currency/Metered/Trial/Seat 운영 흐름
- `business/subscription-billing-metrics.md` — MRR/Churn/Cohort SQL + Grafana 대시보드 + 외부 도구

**우리 시스템 내부 (cross-link)**:
- `business/payment-integration.md` — 일회성 결제, webhook 기본, 도메인 모델 부모
- `business/multi-tenancy.md` — tenant 단위 billing, seat 모델, 결제 권한 RBAC
- `business/notification-multichannel.md` — dunning 이메일/SMS, trial ending 통지
- `business/audit-log.md` — subscription state change, plan change 추적
- `business/feature-flags.md` — plan-based gating, kill-switch (결제 이슈 시)
- `business/rate-limiting.md` — trial 어뷰즈, usage threshold
- `business/admin-api-keys.md` — billing endpoint scope, webhook 서명
- `business/auth-oauth-social.md` — Customer Portal 인증, admin 권한
- `skills/msa/msa-saga.md` — invoice + 후처리 분산 트랜잭션
- `skills/messaging/redis-streams.md` / `kafka-*` — webhook 큐
- `agents/saga-agent` — Saga 오케스트레이션
- `agents/tech-lead` — 구독 모델 ADR
- `agents/database-expert` — invoice partition, archival
- `agents/anti-bot` — trial 어뷰즈 탐지
- `rules/security.md`, `rules/documentation.md` — ADR/회계 문서

**외부 표준 / 도구**:
- Stripe Billing, Stripe Tax, Stripe Meters, Stripe Test Clocks
- Paddle / Lemon Squeezy (MoR)
- Chargebee / Recurly (엔터프라이즈)
- Lago / Killbill (open-source)
- PortOne 정기결제 / Toss 자동결제 / KCP 빌링키 (한국)
- ProfitWell / ChartMogul / Stripe Sigma (구독 분석)

---

## 10. 다음 단계 (이 hub 적용 후)

1. **운영 흐름에 막혔다면** → `subscription-billing-flows.md` (Proration/Dunning/Plan Change 등)
2. **메트릭 대시보드 구축** → `subscription-billing-metrics.md`
3. **AI 사용량/토큰 모네타이징** → `business/credit-system.md` (P2-A 후속 예정)
4. **B2B 인보이스 결제 (수동)** → 별도 패턴 (송금/세금계산서 워크플로우)
5. **다국가 매출 → MoR 검토** → Paddle/Lemon Squeezy 마이그레이션 ADR
6. **회계/ERP 연동** → invoice → NetSuite/더존/자체 회계 시스템
