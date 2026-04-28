# Subscription Billing

SaaS 구독 결제 패턴 — Stripe Subscriptions, proration, dunning, smart retry, plan change, invoice. 일회성 결제(payment-integration)의 자연 연장. 신규 SaaS의 정기 수익화 부트스트랩.

신규 SaaS 프로젝트에 정기 구독을 붙일 때 반복되는 패턴 모음.
**언제든 0에서 시작하지 않도록** 검증된 빌링 사이클, proration, dunning, plan change, multi-tenant 결합을 한 곳에 정리.

## When to Use

- MVP 결제 완료 후 정기 수익 모델로 확장 (`payment-integration.md` 다음 단계)
- B2B SaaS — Free/Pro/Team/Enterprise tier 설계
- B2C 멤버십 — 월간/연간 구독, 광고 제거, 프리미엄 기능
- AI 제품 — 토큰/seat 혼합 (`credit-system.md`와 결합)
- 기획자가 "월 9,900원 구독 모델로 가요" 물어볼 때

**관련 skill**: `business/payment-integration.md`, `business/multi-tenancy.md`, `business/notification-multichannel.md`, `business/feature-flags.md`, `business/audit-log.md`
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
- **`tenant_id` 일찍 박는다**: B2B는 거의 항상 multi-tenant. 후행 추가 시 backfill 지옥. → `business/multi-tenancy.md`

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
- 모든 state change는 `audit-log`에 기록 (`business/audit-log.md`)
- 차단 시 `feature-flags`로 fallback UI 결정 (`business/feature-flags.md`)

---

## 4. Proration (가장 흔한 버그 발생 지점)

플랜 변경/취소가 주기 중간에 일어나면 차액을 계산해 다음 invoice에 반영.

### 시나리오 매트릭스

| 시나리오 | 처리 | UX 신호 |
|---|---|---|
| **Upgrade (mid-cycle)** | 즉시 차액 청구 또는 다음 invoice에 prorated charge | "지금 차액만 결제됩니다" |
| **Downgrade (mid-cycle)** | 다음 주기부터 적용 (잔여 기간 환불 X) 또는 credit balance 적립 | "다음 결제일부터 적용됩니다" |
| **Cancel mid-cycle** | 보통 주기 끝에 종료 (refund X). B2C는 즉시+환불 옵션 | "MM-DD까지 이용 가능" |
| **Quantity change (seat)** | mid-cycle 즉시 prorated. 추가 시 charge, 감소 시 credit | "5 → 7 seat 추가 차액" |
| **Trial → Paid 도중 변경** | trial 종료 시 새 plan으로 전환 | UI에 명시 |

### Stripe proration_behavior 옵션

| 값 | 동작 | 적합 |
|---|---|---|
| `create_prorations` (default) | 차액을 invoice item으로 추가, 다음 invoice에 합산 | B2B SaaS 표준 |
| `always_invoice` | 즉시 invoice 발행 + 결제 시도 | 즉시 차액 받고 싶을 때 |
| `none` | proration 없음, 다음 주기부터만 적용 | 단순 모델, downgrade 표준 |

### 주의

- **연간 구독에서 월간으로 downgrade**: 잔여 기간을 어떻게 처리할지 ADR 필수. credit balance / 환불 / 만료까지 유지 — 비즈니스 정책 사항.
- **세금/할인 함께 proration**: Stripe Tax는 자동 계산하지만, 자체 구현 시 매우 까다롭다. **Tax SaaS (Stripe Tax / Avalara) 사용 권장**.
- **시간대**: subscription의 `current_period_end`는 UTC. 사용자 표시는 tenant timezone으로 변환.

---

## 5. Dunning (결제 실패 → 회수)

결제 실패 시 자동 재시도 + 사용자 통지 + 점진적 강제. **dunning 설계가 LTV의 핵심 변수.**

### Smart Retry 흐름 (Stripe 표준)

```
payment_failed
  └─ Smart Retry 1회차 (1~3일)
       └─ 실패 → 이메일 1차 (soft reminder)
            └─ Retry 2회차 (3~5일)
                 └─ 실패 → 이메일 2차 (urgency)
                      └─ Retry 3회차 (7일)
                           └─ 실패 → 이메일 3차 (final notice)
                                └─ 4회차 (10~14일)
                                     └─ 실패 → unpaid → 기능 차단
```

**Stripe Smart Retries**: ML로 카드사별 성공 확률 높은 시점에 재시도. 자체 cron보다 +20~40% 회수율.

### 카드 라이프사이클 대응

| 실패 원인 | Stripe 자동 처리 | 자체 구현 시 |
|---|---|---|
| 만료 카드 | **Card Account Updater** (Visa/MC/Amex) — 자동 갱신 | 사용자에게 카드 재등록 요청 |
| 카드 분실/재발급 | Network Tokens로 새 PAN 자동 매핑 | 유저 액션 필요 |
| 한도 초과/잔액 부족 | Smart Retry 시점 분산 | 직접 cron + 백오프 |
| 사기 의심/승인 거절 | Stripe Radar | 별도 사기 탐지 |
| 카드 정지 | 사용자 통지 | 사용자 통지 |

→ **결론**: 가능하면 Stripe/PG 내장 dunning 사용. 자체 구현 시 retry 일정 + 카드 사이클 모두 처리해야 함.

### Dunning 이메일 템플릿 (3-stage)

| 단계 | 시점 | 톤 | 액션 버튼 |
|---|---|---|---|
| Soft (1차) | 실패 직후 | 친절, "일시적일 수 있어요" | "결제 정보 확인" |
| Urgent (2차) | 3~5일 후 | 명확, "기능 제한이 임박" | "지금 카드 업데이트" |
| Final (3차, 7일+) | 차단 직전 | 최종, "MM-DD에 차단 예정" | "결제 / 해지" 동시 노출 |

→ 다채널 통지: 이메일 + 인앱 + 옵션 SMS. `business/notification-multichannel.md` 결합.

### 운영 메트릭 (필수 대시보드)

- **Involuntary churn rate**: 미회수로 인한 cancellation / 전체 cancellation
- **Recovery rate**: dunning으로 회수된 invoice / past_due 발생 invoice
- **Smart Retry 단계별 성공률**: 1차/2차/3차 회수 비율
- **MRR loss from past_due**: 회수 실패로 인한 MRR 감소

---

## 6. Plan Change (Upgrade / Downgrade / Quantity)

### 결정 매트릭스

| 변경 유형 | 기본 정책 | 예외 |
|---|---|---|
| Upgrade (가격↑) | **즉시 적용** + prorated charge | 명시적으로 "다음 주기부터" 옵션 |
| Downgrade (가격↓) | **다음 주기부터 적용** | B2C는 즉시 옵션 (UX) |
| Seat 추가 | 즉시 + prorated charge | (없음) |
| Seat 감소 | 다음 주기부터 / credit balance | 즉시 환불은 비추 |
| Annual ↔ Monthly | ADR 필수 (할인율/잔여) | — |
| Add-on 추가/제거 | upgrade와 동일 | — |
| Trial 도중 변경 | trial 유지, 종료 시 새 plan | — |

### 구현 패턴

```
PUT /subscriptions/{id}
  body: { items: [{ price: "price_pro_monthly", quantity: 1 }] }

서버:
  1. 권한 검증 (tenant admin만)
  2. 변경 가능 상태 확인 (active / trialing만)
  3. Stripe API: subscription.update + proration_behavior 명시
  4. 응답에서 upcoming_invoice 미리보기 → 사용자 확인 (선택)
  5. audit-log: plan_changed 이벤트
  6. feature-flags 평가 즉시 갱신 (캐시 무효화)
```

**미리보기 필수**: `POST /invoices/upcoming` (Stripe)으로 변경 후 청구액 미리보기 → 사용자 동의 후 실제 변경. "예상치 못한 청구" 컴플레인 최대 차단.

---

## 7. Invoice 처리

### 라이프사이클

```
draft → finalize → open → (paid | uncollectible | void)
```

| 상태 | 의미 | 가능 액션 |
|---|---|---|
| `draft` | 생성 중, 변경 가능 | line item 추가/삭제, 발행 |
| `open` | 발행됨, 미결제 | 결제 시도, void, 부분 결제 |
| `paid` | 전액 결제 완료 | 환불(credit note) |
| `uncollectible` | 회수 포기 (write-off) | (terminal) |
| `void` | 무효 처리 | (terminal) |

### 핵심 원칙

- **Invoice는 immutable**: 발행 후 line item 수정 금지. 오류 시 credit note 발행.
- **PDF/legal text는 PG에 위임**: 자체 PDF 생성은 폰트/세금 표기/회계 기준 등 함정 多.
- **세금 자동화**: Stripe Tax / Avalara / TaxJar. 자체 구현은 EU/US sales tax/한국 부가세 모두 비추.
- **이메일 첨부 vs 링크**: 링크 + 영구 보관 URL 권장. 첨부는 큰 PDF + spam 위험.
- **회계 시스템 연동**: invoice ID = 회계 시스템 invoice number 매핑. 한국은 세금계산서 별도 발행 필요 (B2B).

### 한국 특수성

- **세금계산서**: 부가세 별도 발행 (Bill36524 / 더존 / 자체 ERP 연동)
- **현금영수증**: B2C 의무 발행 (PG가 처리하기도 함)
- **카드 영수증 vs 세금계산서**: 동일 거래에 둘 다 발행 금지 (이중 처리)

---

## 8. Usage-based Billing (Metered)

`credit-system.md`와 깊이 연결되지만, 구독 컨텍스트에서의 핵심.

### 패턴

```
사용 발생 (API call / token / GB)
  ▼
UsageRecord 생성 (idempotency_key 필수)
  ▼
배치 또는 실시간으로 PG에 report
  ▼
주기 종료 시 invoice에 합산
```

### Stripe Meters (2025+)

기존 `usage_records` API → **Meters + Events** 모델로 전환. 1초당 1k+ 이벤트 처리, 집계 함수 (sum/count/last/max).

### 주의

- **Idempotency**: 같은 사용 이벤트가 재시도로 2번 와도 1번만 카운트. `idempotency_key` 필수.
- **Late events**: 주기 종료 후 도착하는 이벤트는 **다음 주기로** 또는 `void` (정책 결정 필요).
- **Cap/Threshold**: 사용량 폭증 방지. Threshold 도달 시 알림 + 자동 차단 옵션 (`business/rate-limiting.md` 결합).
- **Free tier (예: 월 1만 콜 무료)**: usage_record 자체는 다 기록, invoice 계산 시 차감.

---

## 9. Trial 관리 + 어뷰즈 방지

| 패턴 | 적합 | 어뷰즈 위험 |
|---|---|---|
| Free trial (카드 등록 안 받음) | 전환율↑, B2C | 멀티계정 어뷰즈 高 |
| Free trial (카드 등록 받음) | B2B SaaS 표준 | 어뷰즈 低, 전환율 다소↓ |
| Reverse trial (Pro로 시작 → 만료 후 Free) | "기능 맛보기" UX | 어뷰즈 中 |
| Pay-and-trial (소액 결제 후 시작) | 어뷰즈 최소화 | 전환율↓ |

### 어뷰즈 방지

- **Email/도메인 제한**: 같은 회사 도메인은 1 trial. (`business/multi-tenancy.md` tenant 결합)
- **Device fingerprint / IP 제한**: `agents/anti-bot` 활용
- **Card fingerprint**: Stripe `card.fingerprint`로 동일 카드 탐지 (PCI 안전)
- **Rate limiting**: trial 시작 endpoint에 IP/계정 단위 limit (`business/rate-limiting.md`)

---

## 10. Multi-tenancy 결합 (B2B SaaS 핵심)

| 모델 | 구독 위치 | 적합 |
|---|---|---|
| **Tenant 단위 구독** | Subscription.tenant_id | B2B SaaS 표준. 회사가 결제. |
| **사용자 단위 구독** | Subscription.user_id | B2C, individual 라이센스 |
| **Seat 모델** | Subscription.quantity = 사용자 수 | B2B 팀 라이센스 |
| **Hybrid** | base seat + usage | 2026 트렌드 (AI 제품) |

### Seat 관리

```
Tenant: 5 seat 구입
  ├─ 사용자 4명 active → 1 seat 여유
  ├─ 6번째 invite 시도 → "seat 부족, 추가하시겠습니까?"
  └─ admin이 추가 → quantity=6, prorated charge
```

- **Active seat 정의**: 30일 내 로그인 / 마지막 로그인 / 명시적 active 토글 — ADR 필수
- **Seat 회수**: 사용자 deactivate → 즉시 seat 반환 vs 주기 끝에 반환
- **Owner/Admin**: 결제 권한은 admin only. `business/auth-oauth-social.md` + RBAC.

→ 상세: `business/multi-tenancy.md`

---

## 11. Webhook / 동기화 (payment-integration 패턴 재사용)

`payment-integration.md` §4의 webhook 원칙 모두 적용. 추가 이벤트 타입:

| Stripe Event | 처리 |
|---|---|
| `customer.subscription.created` | 구독 생성, audit-log |
| `customer.subscription.updated` | 상태/plan 변경 동기화 |
| `customer.subscription.deleted` | 해지 처리, 기능 차단 (grace period 후) |
| `customer.subscription.trial_will_end` (3일 전) | trial 종료 알림 |
| `invoice.created` | 다가오는 청구 미리보기 |
| `invoice.finalized` | 발행됨, 결제 시도 직전 |
| `invoice.paid` | 결제 성공, 다음 주기 활성 |
| `invoice.payment_failed` | dunning 시작 |
| `invoice.payment_action_required` | 3DS 등 추가 인증 필요 |
| `customer.subscription.paused/resumed` | 일시정지/재개 |

**핵심**: PG webhook이 source of truth. 자체 DB와 drift 시 reconciliation job 정기 실행.

---

## 12. 보안 (payment-integration §6 + 추가)

- ❌ **클라이언트가 plan/quantity 결정 → 즉시 적용**: 반드시 서버에서 권한/요금 검증
- ❌ **Subscription 직접 status 수정**: 항상 PG API → webhook → DB 흐름
- ❌ **Trial을 클라이언트 시간/state로 결정**: 서버 시간 + PG `trial_end` 기준
- ❌ **무료 plan 사용자에게 PG customer 안 만들기**: 추후 upgrade 시 마이그레이션 함정. 가입 시 customer 생성, free는 무료 price.
- ✅ **결제 권한 RBAC**: admin/owner만 plan change. `audit-log`에 actor/IP 기록.
- ✅ **API key scope 제한**: subscription 변경 endpoint는 별도 scope (`business/admin-api-keys.md`)

---

## 13. 안티패턴 모음

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

## 14. ADR 템플릿 — 구독 결정

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

## 15. Quick Start Checklist (신규 SaaS)

- [ ] `payment-integration.md`로 일회성 결제 인프라 먼저 구축
- [ ] Plan/PlanVersion/Price 도메인 모델 설계 (immutable PlanVersion)
- [ ] Subscription 상태 머신 + audit-log 통합
- [ ] Stripe Customer = 가입 즉시 생성 (free 사용자도 포함)
- [ ] Subscription/Invoice/Item 도메인 + tenant_id 결합
- [ ] Webhook 13개 이벤트 핸들러 (이 문서 §11)
- [ ] Smart Retries + Card Account Updater 활성화
- [ ] Dunning 3-stage 이메일 + notification-multichannel 결합
- [ ] Customer Portal 링크 (해지/카드 변경 self-serve)
- [ ] Plan change 미리보기 (`upcoming_invoice`)
- [ ] feature-flags + plan-based gating 결합
- [ ] Trial 어뷰즈 방지 (도메인/카드 fingerprint/rate-limit)
- [ ] 모니터링: MRR/ARR, churn rate, recovery rate, dunning 단계별 전환율
- [ ] 한국 세금계산서/현금영수증 워크플로우 (B2B/B2C 분기)
- [ ] Reconciliation job: PG ↔ DB 일일 비교

---

## 16. 관련 자원

**우리 시스템 내부** (cross-link):
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
- Stripe Billing, Stripe Tax, Stripe Meters
- Paddle / Lemon Squeezy (MoR)
- Chargebee / Recurly (엔터프라이즈)
- Lago / Killbill (open-source)
- PortOne 정기결제 / Toss 자동결제 (한국)
- ProfitWell / ChartMogul (구독 분석)

---

## 17. 다음 단계 (이 skill 적용 후)

1. **AI 사용량/토큰 모네타이징** → `business/credit-system.md` (P2-A 3순위 예정)
2. **B2B 인보이스 결제 (수동)** → 별도 패턴 (송금/세금계산서 워크플로우)
3. **다국가 매출 → MoR 검토** → Paddle/Lemon Squeezy 마이그레이션 ADR
4. **사용량 폭증 대응** → metered billing + usage cap + `rate-limiting.md`
5. **회계/ERP 연동** → invoice → NetSuite/더존/자체 회계 시스템
