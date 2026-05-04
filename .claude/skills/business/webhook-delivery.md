---
name: webhook-delivery
description: 발신자 관점 webhook 표준 — HMAC 서명, exponential backoff + jitter 재시도, per-subscriber 순서 보장, DLQ + replay, idempotency (event_id), circuit breaker, SSRF 방지. payment-integration의 수신자 관점과 짝, WebhookGateway 추상화.
license: MIT
---

# Webhook Delivery — 발신자 관점

우리 서비스가 **외부에 webhook을 발신할 때** 표준화된 안정성·보안·운영 패턴. 외부에서 받는 webhook(Stripe/Toss 등)은 [`business/payment-integration.md`](payment-integration.md), [`business/subscription-billing.md`](subscription-billing.md)이 cover.

> 핵심 결정: (1) 순서 보장(per-subscriber queue) vs 처리량(병렬), (2) 동기 vs 비동기 발신, (3) 서명 표준 (HMAC vs JWS), (4) DLQ + replay 정책.

## When to Use

- B2B 플랫폼이 고객 시스템에 이벤트 알림 발신
- SaaS event API (예: Stripe-style webhooks)
- Integration platform (Zapier-like)
- 마이크로서비스에서 외부 partner API 호출 (안정성 패턴 동일)
- Multi-tenant 환경에서 tenant별 endpoint
- 회계/세무 시스템 연동 (실시간 동기화 의무)

**관련 skill (cross-link)**:
- `business/payment-integration.md` — Stripe/Toss webhook **수신자** 관점 (이 skill의 미러)
- `business/subscription-billing.md` — billing event publish source
- `business/admin-api-keys.md` — subscriber 인증, secret 회전
- `business/notification-multichannel.md` — Push/Email과 webhook 채널 통합
- `business/audit-log.md` — delivery 기록 (event reconstruct)
- `business/rate-limiting.md` — 수신자 endpoint 보호
- `messaging/kafka-streams.md` — 내부 이벤트 → 외부 webhook 어댑터

---

## WebhookGateway 추상화 (Gateway 패턴 5번째)

`SubscriptionGateway` / `CreditGateway` / `StorageGateway` / `SearchGateway` 패턴 정착 후 5번째.

```
interface WebhookGateway {
    publish(tenantId, eventType, payload, opts) -> Promise<EventId>
    register(tenantId, url, eventTypes[], secret) -> Subscriber
    deactivate(subscriberId, reason)
    replay(deliveryId)
    listDeliveries(subscriberId, filter) -> Delivery[]
}

implementations:
    InHouseWebhookGateway     // 자체 구현
    SvixWebhookGateway        // SaaS (managed webhook infra)
    HookdeckWebhookGateway    // SaaS
```

**부트스트랩**: 자체 구현 (PostgreSQL outbox + worker) → 트래픽 증가 시 Svix/Hookdeck로 위임.

---

## 도메인 모델

```
Subscriber (구독자)
   ├─ id, tenant_id, url, secret_hash, status (active/disabled)
   ├─ event_types[] (filter)
   ├─ created_at, last_success_at, last_failure_at
   └─ failure_count, circuit_state (closed/open/half_open)

Event (이벤트)
   ├─ id (uuid), tenant_id, type, payload (JSON)
   ├─ created_at
   └─ idempotency_key (사용자가 재시도해도 같은 event)

Delivery (전달 시도)
   ├─ id, event_id, subscriber_id
   ├─ attempt (1..N)
   ├─ status (pending/success/failed/dead)
   ├─ http_status, response_body (truncated)
   ├─ requested_at, completed_at, next_retry_at
   └─ duration_ms
```

**핵심 분리**: Event(불변, 한 번 생성) ↔ Delivery(재시도 = 새 row).

---

## 재시도 정책 (Exponential Backoff + Jitter)

```
attempt 1: 즉시
attempt 2: 30s + jitter(0~30s)
attempt 3: 2min + jitter(0~60s)
attempt 4: 10min + jitter
attempt 5: 1h + jitter
attempt 6: 6h + jitter
attempt 7: 24h + jitter
→ 7회 실패 시 dead (circuit open + DLQ)
```

```
delay = min(MAX_DELAY, BASE * 2^(attempt-1)) + random(0, BASE * 2^(attempt-2))
```

- **Jitter 필수**: thundering herd 방지 (같은 시점 다수 실패 시)
- **Max 7 attempts**: Stripe/Twilio 표준 (이상은 무의미)
- **Total window 24h**: 그 이상은 사용자가 manual replay

### 재시도 트리거 (HTTP status 기준)

| Status | 재시도? | 비고 |
|---|---|---|
| 2xx | ❌ (성공) | success |
| 3xx | ❌ | redirect 따라가지 말고 fail (보안) |
| 4xx | ❌ (영구 실패) | client error, dead immediately. 단 408/429는 재시도 |
| 5xx | ✅ | server error, 재시도 |
| network error / timeout | ✅ | 재시도 |
| TLS / DNS error | ✅ (제한적) | 3회 후 dead |

### Timeout

- **Per-attempt timeout**: 10초 (수신자가 천천히 응답해도 cut-off)
- **Connect timeout**: 5초

---

## 서명 (HMAC-SHA256)

수신자가 webhook이 **진짜 우리에게서 왔는지** + **변조되지 않았는지** 검증할 수 있어야 한다.

### 서명 헤더 (Stripe 스타일)

```
POST /webhook HTTP/1.1
Content-Type: application/json
X-Webhook-Id: evt_abc123
X-Webhook-Timestamp: 1714780800
X-Webhook-Signature: sha256=a1b2c3d4...

{ "type": "subscription.updated", ... }
```

서명 계산:
```
signed_payload = "{timestamp}.{request_body}"
signature = HMAC-SHA256(subscriber_secret, signed_payload)
header = "sha256=" + hex(signature)
```

### 수신자 검증 의무 (문서화)

```
1. X-Webhook-Timestamp가 ±5분 이내인지 (replay 방지)
2. signed_payload 재구성
3. HMAC-SHA256 계산 후 X-Webhook-Signature와 constant-time 비교
4. 일치하면 처리, 불일치하면 401 반환 후 무시
```

### Secret 회전 (zero-downtime)

[`business/admin-api-keys.md`](admin-api-keys.md) §회전 패턴 재사용:
```
1. 새 secret 생성 → DB에 active=false로 저장
2. 다음 발신부터 두 secret으로 서명 (X-Webhook-Signature, X-Webhook-Signature-Next)
3. 수신자에게 알림 + 일정 (예: 7일)
4. 7일 후 구 secret 비활성화, 새 secret만 사용
```

---

## 순서 보장 (Per-subscriber Queue)

이벤트 순서가 중요한 경우 (예: subscription.created → subscription.updated):

```
Per-subscriber queue (Redis Streams 또는 RabbitMQ consistent hashing)
- key: subscriber_id
- 같은 subscriber는 single-threaded 처리
- 다른 subscriber는 병렬

장점: 순서 보장
단점: 한 subscriber 느리면 backlog
```

**선택 가이드**:

| 시나리오 | 순서 보장 | 정책 |
|---|---|---|
| Subscription/Account state change | ✅ 필수 | per-subscriber queue |
| Webhook 형 알림 (one-shot) | ❌ | unordered, 병렬 |
| Audit log shipping | ✅ optional | timestamp 포함, 수신자가 정렬 |
| Real-time activity feed | ❌ | 병렬, latency 우선 |

순서 보장 안 하면 payload에 `sequence_number` 또는 `created_at` 포함 권장 (수신자가 정렬 가능).

---

## Idempotency

수신자는 **같은 event를 중복 처리하면 안 된다**. 발신자 책임:

```
- event_id: 영구 unique (UUID v4)
- delivery_id: 시도별 unique
- 재시도 시 event_id 동일, delivery_id만 변경
- 수신자는 event_id를 기록하고 중복 시 skip
```

수신자가 idempotent하지 않으면 우리 책임이 아니지만, **명세에 명시**:
```
"동일 event_id는 최소 1회 ~ 최대 N회 전달될 수 있습니다.
 수신자는 event_id를 기준으로 idempotency를 보장해야 합니다."
```

---

## Circuit Breaker (Endpoint Health)

특정 subscriber endpoint가 반복 실패하면 발신을 일시 중단 → 우리 큐 보호.

```
state: closed (정상)
  ├─ 연속 실패 ≥ 10 → open
  └─ delivery 진행

state: open (차단)
  ├─ 5분 동안 발신 보류 (DLQ에 적재)
  ├─ 5분 후 → half_open
  └─ 사용자에게 알림 (이메일/UI)

state: half_open (탐색)
  ├─ 다음 1건만 시도
  ├─ 성공 → closed
  └─ 실패 → open (5분 더)
```

24시간 open 지속 시 subscriber 자동 비활성화 + 운영자 alert.

---

## DLQ (Dead Letter Queue) + Replay

```
DLQ 진입 조건:
  - 7회 재시도 모두 실패
  - 4xx (영구 실패)
  - Subscriber 비활성화 상태

DLQ 보관:
  - PostgreSQL `deliveries_dead` 테이블 (90일)
  - S3 archive (1년, 컴플라이언스)
  - PII 처리: payload 일부 마스킹

Replay UI:
  - 운영자가 deliveries_dead에서 선택 → 새 delivery_id로 재발신
  - 또는 사용자(고객)가 dashboard에서 수동 replay
  - rate limit: subscriber 당 100/min (DDoS 방지)
```

---

## 보안 (필수)

### SSRF 방지

수신자 URL이 **내부 네트워크에 접근 못 하도록**:

```
URL 검증:
  - 스킴은 https만 (http는 부트스트랩 외 금지)
  - 호스트 IP resolve → private range 차단
    - 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
    - 169.254.0.0/16 (link-local, AWS metadata)
    - 127.0.0.0/8 (loopback)
    - ::1, fe80::/10 (IPv6)
  - DNS rebinding 방지: resolve 후 같은 IP로 connect (두 번 resolve 금지)
```

```python
# 의사코드
def validate_subscriber_url(url):
    parsed = urlparse(url)
    if parsed.scheme != "https":
        raise InvalidURL("https만 허용")
    ip = socket.gethostbyname(parsed.hostname)  # resolve 1회
    if is_private(ip):
        raise InvalidURL("private network 차단")
    return ip  # connect는 이 IP로 (rebinding 방지)
```

AWS IMDSv2, GCP metadata server 등 cloud metadata는 항상 차단.

### TLS 검증

- 인증서 검증 필수 (`verify=True`)
- self-signed 거부 (B2B 요구 시 명시적 allowlist 옵션)
- TLS 1.2 이상

### Redirect 차단

3xx redirect 자동 follow 금지. 수신자 endpoint는 **고정 URL**.

### Header 검증 (응답)

응답 body 크기 제한 (예: 1MB) — 수신자가 거대한 응답으로 우리 메모리 공격 방지.

---

## 관리 API (Subscriber CRUD)

```
POST   /api/webhooks/subscribers
  body: { url, event_types[], secret? }
  → secret 미제공 시 자동 생성 (한 번만 노출)

GET    /api/webhooks/subscribers
PATCH  /api/webhooks/subscribers/:id
  body: { url?, event_types?, status? }
DELETE /api/webhooks/subscribers/:id

POST   /api/webhooks/subscribers/:id/rotate-secret
  → 새 secret 생성, 7일 grace period

GET    /api/webhooks/deliveries?subscriber_id=...&status=failed
POST   /api/webhooks/deliveries/:id/replay
```

API 인증은 [`business/admin-api-keys.md`](admin-api-keys.md) 패턴 적용.

---

## 메트릭 + 알람

```
- delivery_total{tenant, subscriber, status}
- delivery_duration_seconds (p50/p95/p99)
- delivery_retry_count (히스토그램)
- circuit_state{subscriber} (closed/open/half_open)
- dlq_depth (gauge)
- subscriber_failure_rate (rolling 5min)
```

알람 룰:
- `delivery_failure_rate > 50% for 5min` → on-call
- `dlq_depth > 1000` → DLQ replay 검토
- `circuit_open count > N` → endpoint 품질 저하 (대규모 사고 가능)
- `p95 duration > 10s` → 수신자 felomada 또는 우리 worker 부하

분기 회고에서 delivery 성공률, MTTR을 [`dx/quarterly-review.md`](../dx/quarterly-review.md)에 통합.

---

## 안티패턴

| 안티패턴 | 왜 나쁜가 | 대신 |
|---|---|---|
| Synchronous webhook (request 처리 안에서 발신) | request latency ↑, 수신자 다운 시 우리 다운 | async (outbox + worker) |
| 재시도 jitter 없음 | thundering herd | exponential + random jitter |
| 4xx도 재시도 | client error를 무한 재시도 | 408/429만 재시도 |
| 3xx redirect follow | open redirect → SSRF | 고정 URL, redirect 차단 |
| HTTP 허용 (https 강제 X) | MITM, payload 노출 | https only |
| 서명 없이 발신 | 수신자 위조 검증 불가 | HMAC-SHA256 필수 |
| 서명에 timestamp 미포함 | replay 공격 | timestamp + ±5분 window |
| `==` 비교 (변형) | timing attack | constant-time 비교 |
| event_id 없음 | 수신자 idempotency 불가능 | UUID v4 필수 |
| 모든 subscriber 단일 큐 | head-of-line blocking | per-subscriber queue (순서 필요) 또는 병렬 (독립) |
| Circuit breaker 없음 | 다운된 endpoint에 무한 재시도, 큐 폭발 | 연속 실패 N회 → open |
| DLQ 없음 | dead delivery 추적 불가 | 90일 보관 + replay UI |
| Subscriber URL private IP 허용 | SSRF (내부 metadata server 노출) | private range 차단 |
| Response body size 무제한 | OOM 공격 | 1MB cap |
| Per-attempt timeout 없음 | 수신자 hang → worker 점유 | 10s timeout |
| Secret 평문 DB 저장 | leak 시 즉시 위조 | hash (SHA-256), 생성 시 1회만 노출 |
| Delivery log에 PII 풀로 저장 | GDPR / PIPA 위반 | 마스킹 또는 hash |
| Webhook 받는 SDK만 제공, 발신 안 함 | Integration 가치 ↓ | 표준 발신 SDK + receiver 가이드 |
| 재시도 무한 (max 없음) | 좀비 delivery | max 7회, total 24h |

---

## 한국 시장 특수성

- **세무 시스템 연동** — 국세청 홈택스, 카드사 매출 동기화는 실시간 webhook 발신 의무 (24시간 룰)
- **PIPA 데이터 영토** — 한국 사용자 PII가 webhook payload에 포함될 시 수신자 endpoint도 국내 서버 권장
- **금융권 webhook** — 금감원 가이드 (금융 데이터는 TLS 1.3 + 국가표준 암호화 추가 검토)
- **카카오/네이버 talk biz** — 알림톡/채널 메시지 발송 webhook은 별도 표준 (자체 SDK)

법령 추적: [`legal/data-subject-rights.md`](../legal/data-subject-rights.md)

---

## ADR 템플릿 (Self-host vs SaaS)

```markdown
## Context
- subscriber 수: N
- 일 event 수: M
- ops 인력: ...
- 컴플라이언스: PIPA / SOC2 ...

## Options
A. 자체 구현 (PG outbox + worker) — 초기 부트스트랩
B. Svix (managed webhook infra) — $79~$1000/월
C. Hookdeck — destination-side queue

## Decision
[선택] 이유: ...

## Consequences
- 운영 부담: ...
- 비용: ...
- migration cost: WebhookGateway 추상화로 ...

## Predicted Outcomes
- delivery success rate ≥ 99.5%
- p95 < 2s
- DLQ replay 자동화 도구 제공

## Review Schedule
- Tier 1, 6개월
- Auto-trigger: 실패율 5%+, 비용 2x, scale 10x
```

[`dx/adr-retrospective.md`](../dx/adr-retrospective.md) 참조.

---

## Quick Start (1일 부트스트랩)

```
1. WebhookGateway 인터페이스 정의
2. PostgreSQL 테이블: subscribers, events, deliveries, deliveries_dead
3. Outbox 패턴: 비즈니스 transaction에서 events INSERT
4. Worker (1~2 인스턴스): events SELECT FOR UPDATE SKIP LOCKED → 발신
5. HMAC 서명 + timestamp 헤더
6. 재시도 워커: deliveries WHERE next_retry_at <= NOW() AND status='pending'
7. SSRF 방어: URL 검증 + IP allowlist (private 차단)
8. 관리 API: subscriber CRUD + delivery list + replay
9. Grafana: delivery_total, success_rate, dlq_depth, p95
10. Subscriber 가이드 문서 (서명 검증, idempotency 명세)
```

---

## 다음 단계 (After Adoption)

- Subscriber portal (자체 dashboard, delivery 로그 조회, replay)
- Per-event-type subscription (filter)
- Webhook payload schema versioning (v1, v2 호환성)
- Polyfill SDK (Node, Python, Go, Java) — 서명 검증 helper
- 부하 테스트 ([`load-tester-k6`](../sre/load-test-k6.md)이 있으면): 100K event/min 시뮬레이션
- Hookdeck/Svix로 마이그레이션 (Gateway 추상화 활용)
- mTLS subscriber (B2B 고객 요구 시)
- E2E 테스트: webhook.site mock receiver

---

## 관련 자원

- Stripe Webhooks API docs — 업계 표준 reference
- "Designing Data-Intensive Applications" §11 (Stream Processing) — at-least-once delivery
- Svix Documentation — managed webhook infra 패턴
- AWS WAF SSRF prevention guide
- IETF RFC 9116 — security.txt
- "The Standard Webhooks" spec (standardwebhooks.com) — 호환성 권장
