# Payment Integration

결제 통합 패턴 — Stripe/Toss/PortOne, Token-first, Webhook 처리, 분산 트랜잭션. 한국 시장 우선 + 글로벌 옵션. SaaS 신규 프로젝트의 수익화 부트스트랩.

신규 SaaS/서비스에 결제를 붙일 때 반복되는 패턴 모음.
**언제든 0에서 시작하지 않도록** 검증된 통합 흐름, 보안, 멱등성, Webhook, 분산 트랜잭션을 한 곳에 정리.

## When to Use

- 통학차량/심리상담 같은 신규 도메인에 결제 붙이기
- 일회성 결제 vs 정기 결제(구독) 결정
- 한국 사용자 대상 (카드/계좌이체/간편결제) → **PortOne 또는 Toss Payments**
- 글로벌 사용자 → **Stripe**
- 기획자가 "결제 어떻게 할까요?" 물어볼 때

**관련 skill**: `msa/msa-saga.md`, `msa/distributed-lock.md`, `security/secure-coding.md`
**관련 agent**: `saga-agent`, `tech-lead` (결제 ADR 작성)

---

## 1. Provider 결정 매트릭스

| 시장 / 요구 | 추천 | 이유 |
|---|---|---|
| 한국 + 카드/간편결제 통합 | **PortOne (구 Iamport)** | 국내 PG 6개 + 토스/카카오/네이버페이 한 SDK |
| 한국 + 토스 단독 (UX 일관성) | **Toss Payments** | 결제 위젯 UX 우수, 단일 PG |
| 글로벌 / SaaS 구독 | **Stripe** | 구독 빌링, Customer Portal, Webhook 성숙 |
| EU 매출 (VAT 자동) | **Lemon Squeezy / Paddle** | Merchant of Record (세금 대신 처리) |
| 큰 거래 + B2B | **Adyen** | 엔터프라이즈, 글로벌 |
| Korean B2C + 글로벌 동시 | **PortOne (한국) + Stripe (글로벌) 듀얼** | 라우팅 레이어 필요 |

> **2026 트렌드**: Payment Orchestration. 단일 PG 대신 라우터를 두고 PG 장애 시 자동 fallback. 처음부터 추상화 레이어 두면 후기 전환 비용 ↓.

---

## 2. 핵심 아키텍처 패턴

### Pattern A — Hosted Checkout (가장 단순)

```
Client → /checkout (서버) → Provider Hosted Page → Webhook → /webhook (서버) → DB
```

**적합**: MVP, 결제 빈도 낮음, PCI 부담 회피
**Provider**: Stripe Checkout, Toss Payments 위젯, PortOne 결제창

### Pattern B — Direct API (커스텀 UX)

```
Client → 카드 입력 (SDK) → 토큰화 → 서버 → Provider API → Webhook → 서버
```

**적합**: 결제 UX를 자체 컨트롤, 모바일 native
**주의**: PCI-DSS 인증 부담 ↑. 카드 raw 데이터는 절대 우리 서버 거치지 않게.

### Pattern C — Orchestration (Multi-PG)

```
Client → /pay → Router (PG 선택) → Primary PG
                                    ↓ 실패 시
                                  Fallback PG
       → 통합 Webhook 정규화 → DB
```

**적합**: 매출 규모 ↑, PG 장애 리스크, 한국+글로벌 듀얼
**구현 핵심**: 각 PG의 Webhook을 **정규화된 내부 이벤트**로 변환. PG 추가 시 어댑터만 작성.

---

## 3. 결제 도메인 모델 (필수)

```
Order (1) ─── (N) PaymentAttempt
              ├─ provider: stripe|portone|toss
              ├─ provider_payment_id  (PG의 결제 식별자)
              ├─ idempotency_key      (멱등성 보장)
              ├─ status: pending|succeeded|failed|refunded
              ├─ amount, currency
              └─ raw_response (JSON, 감사용)

Order:
  ├─ id (uuid, 멱등 보장)
  ├─ status: created|paid|refunded|cancelled
  ├─ user_id, items, amount
  └─ paid_attempt_id (성공 결제 참조)
```

**핵심 원칙**:
- **Order ≠ Payment**: 1 Order → N PaymentAttempt (재시도/실패 모두 추적)
- **idempotency_key**: 동일 키로 재시도 시 중복 결제 방지 (Stripe 표준, 우리 Order ID 사용 가능)
- **raw_response 보관**: PG 분쟁/디버깅 시 필수. 6개월~1년 보관 (개인정보 마스킹).

---

## 4. Webhook 처리 — 가장 흔한 사고 발생 지점

### 필수 체크리스트

- [ ] **서명 검증** — 모든 PG가 webhook signature 제공. 검증 안 하면 임의 위변조 가능
- [ ] **HTTPS only**
- [ ] **멱등 처리** — 동일 webhook event 2번 와도 OK여야 함 (PG가 재전송함)
- [ ] **빠른 응답** — 5초 내 200 반환, 무거운 작업은 큐로 위임
- [ ] **순서 보장 안 됨** — `payment.succeeded` 전에 `payment.refunded` 도착 가능. 상태 머신으로 처리.
- [ ] **재시도 정책** — PG가 일정 시간 내 재시도. 우리 서버 다운 시간 고려.

### 안전한 구조

```
Webhook 수신
  ├─ 서명 검증 (실패 → 401)
  ├─ event_id 중복 확인 (DB 또는 Redis SET)
  │   ├─ 처음: 처리 진행
  │   └─ 중복: 200 즉시 반환
  ├─ 200 응답 (5초 내)
  └─ 비동기 큐로 비즈니스 로직 위임 (Kafka/SQS/Redis Streams)
```

**안티패턴**:
- ❌ Webhook 핸들러에서 직접 외부 API 호출 → 타임아웃 → 재전송 폭주
- ❌ 서명 검증 생략 ("일단 IP 화이트리스트")
- ❌ event_id 멱등 체크 생략

---

## 5. 분산 트랜잭션 (Saga 활용)

결제는 본질적으로 분산 트랜잭션. 결제 성공 후 재고 차감/포인트 적립/이메일 발송 등이 따라옴.

```
Step 1: 재고 임시 예약 (compensation: 예약 취소)
Step 2: 결제 시도 (compensation: 환불)
Step 3: 재고 확정 (compensation: 재고 복원)
Step 4: 포인트 적립 (compensation: 포인트 회수)
Step 5: 알림 발송 (idempotent)
```

**중간 실패 시**: 역순으로 compensation 실행.

→ 상세: [.claude/skills/msa/msa-saga.md](.claude/skills/msa/msa-saga.md)
→ 오케스트레이션: `agents/saga-agent` 호출

**한국 결제 특수성**:
- 카드 결제 후 **취소 가능 시간 제한** (당일 vs 당월 vs 30일)
- 일부 PG는 **부분 취소 미지원**
- → ADR로 "취소 정책" 명시 필수

---

## 6. 보안 — 절대 금지 사항

- ❌ **카드 PAN/CVV를 우리 서버에 저장/로깅** — PCI-DSS 위반, 사고 시 회사 위험
- ❌ **Provider Secret Key 코드 하드코딩** — 환경변수/Secret Manager만
- ❌ **클라이언트가 amount 결정** — 반드시 서버에서 amount 계산. 클라이언트 값 신뢰 금지.
- ❌ **Webhook 서명 검증 생략**
- ❌ **결제 완료 판단을 클라이언트 응답으로** — 반드시 Webhook 또는 서버 사이드 verify

### 안전한 amount 흐름

```
Client: "주문 ID 123 결제 시작"
Server: Order 123 조회 → amount=10000원 → PG에 amount 전달
PG → Client: 결제 페이지 (서버가 정한 amount 표시)
PG → Webhook: 결제 완료 (amount 검증 가능)
Server: Order amount == Webhook amount 비교 → 불일치면 alert
```

---

## 7. 한국 시장 — Provider별 핵심

### PortOne (구 Iamport / Channel.io 산하)

```
강점: 국내 PG 6개 통합 (NICE/KG이니시스/KCP/토스페이먼츠/카카오페이/네이버페이 등)
      한 SDK로 다 처리
약점: 글로벌 (해외 카드, 환율) 약함
적합: 한국 B2C, 다양한 PG 옵션 필요
```

### Toss Payments

```
강점: 결제 위젯 UX 최고 수준, 한국 표준이 됨
      단일 PG라 운영 단순
약점: 다른 PG 옵션 없음
적합: 한국 B2C, UX 우선, 단일 PG로 충분
```

### Stripe (한국 진출)

```
강점: 글로벌 표준, 구독 빌링, Customer Portal
약점: 한국 카드사 일부 제약, 한국 직불결제 약함
적합: 한국 + 글로벌 동시, SaaS 구독
```

---

## 8. 글로벌 — Stripe 핵심

### 구독 빌링 표준 흐름

```
1. Stripe Customer 생성 (이메일)
2. Subscription 생성 (Price ID)
3. Customer Portal 링크 제공 (해지/카드 변경 셀프 서비스)
4. Webhook 수신:
   - invoice.paid → 정상 갱신
   - invoice.payment_failed → Dunning (재시도 + 이메일)
   - customer.subscription.deleted → 해지 처리
```

**Token-first (2026 표준)**:
- Stripe Network Tokens 활성화 → 카드사 직접 토큰화
- 카드 갱신/만료 시 자동 업데이트
- 결제 성공률 +2~5% (Stripe 자체 데이터)

---

## 9. 안티패턴 모음

| 안티패턴 | 왜 위험 | 올바른 방법 |
|---|---|---|
| 결제 완료 = 클라이언트 응답으로 판단 | 사용자가 응답 위변조 가능 | Webhook 또는 서버 verify |
| 모든 PG에 동일 amount 가정 | PG마다 통화/단위 다름 | 명세서별 단위 확인 (KRW=정수, USD=cents) |
| Webhook 핸들러에서 무거운 작업 | 타임아웃 → 재전송 폭주 | 즉시 200 + 큐 위임 |
| Order ID = Payment ID | 재시도 시 ID 충돌 | Order(1):PaymentAttempt(N) 분리 |
| 환불을 단일 트랜잭션으로 | 환불 후 후처리 실패 시 일관성 깨짐 | Saga 패턴, compensation 명시 |
| `if (status == 1) ...` 매직 넘버 | 의미 불명, 유지보수 ↓ | enum 사용 |
| amount를 float | 부동소수점 오차 | int (최소 단위) 또는 BigDecimal |

---

## 10. ADR 템플릿 — 결제 결정

신규 프로젝트 시작 시 작성할 ADR 항목:

```markdown
## 결제 ADR

| 항목 | 결정 | 대안 | 근거 |
|---|---|---|---|
| Provider | PortOne | Toss / Stripe | 국내 PG 다양성 필요 |
| 통합 방식 | Hosted Checkout | Direct API | PCI 부담 회피 |
| 멱등 키 | Order ID | UUID 별도 | 재시도 추적 단순 |
| 환불 정책 | 결제 후 7일 부분 취소 | 전체만 / 무제한 | 비즈니스 정책 |
| Webhook 큐 | Redis Streams | Kafka / SQS | 기존 인프라 재사용 |
| 분산 TX | Saga (orchestration) | Choreography | 추적 가능성 |
```

→ `agents/tech-lead` 호출하여 ADR 작성 위임.

---

## 11. Quick Start Checklist (신규 프로젝트)

- [ ] Provider 결정 (시장/규모/UX 매트릭스)
- [ ] Order/PaymentAttempt 도메인 모델 설계
- [ ] Webhook 엔드포인트 + 서명 검증 + 멱등 처리
- [ ] amount 서버 사이드 계산 (클라이언트 신뢰 금지)
- [ ] raw_response 보관 정책 (6개월~1년, 개인정보 마스킹)
- [ ] 환불 정책 ADR 작성
- [ ] 분산 TX 필요 여부 판단 → Saga 도입 결정
- [ ] 모니터링: 결제 성공률, Webhook 처리 시간, PG별 에러율 (Grafana 대시보드)
- [ ] 테스트: PG sandbox + integration test (실제 PG 미달 시 contract test)

---

## 12. 관련 자원

**우리 시스템 내부**:
- `skills/msa/msa-saga.md` — 분산 트랜잭션 패턴
- `skills/msa/distributed-lock.md` — 동시 결제 시 잠금
- `skills/security/secure-coding.md` — 입력 검증, 시크릿 관리
- `skills/messaging/redis-streams.md` — Webhook 큐
- `agents/saga-agent` — Saga 오케스트레이션 위임
- `agents/tech-lead` — 결제 ADR 작성
- `rules/security.md` — 보안 룰 (PCI 관련)

**외부 표준**:
- PCI-DSS v4.0
- Stripe Network Tokens 가이드
- PortOne / Toss / Stripe 각 공식 문서

---

## 13. 다음 단계 (이 skill 적용 후)

1. **구독 빌링이 필요하다면** → `business/subscription-billing.md` (P2 예정)
2. **AI 사용량 과금이라면** → `business/credit-system.md` (P2 예정)
3. **다국가 매출이라면** → Merchant of Record 검토 (Lemon Squeezy/Paddle)
4. **B2B 인보이스 결제라면** → 별도 패턴 (PG 외 송금/세금계산서)
