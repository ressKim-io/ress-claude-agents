<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# saas

SaaS 비즈니스 — 멀티테넌시, 소셜 로그인, 결제, 구독, 알림, Webhook, Audit Log, Feature Flag

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install saas@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/saas/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`security`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/security/README.md)
- [`messaging`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/messaging/README.md)
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`ai`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/ai/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (17)

| 이름 | 설명 |
|---|---|
| `/saas:admin-api-keys` | API Key·Personal Access Token·Service Token — 발급·회전·폐기, scope 설계, 해시 저장, prefix 노출, rate limit, 유출 대응 |
| `/saas:audit-log` | 감사 로그 — append-only 이벤트 모델, action 네이밍, tenant 격리, 저장소 선택, 보존·삭제, 검색·export UI |
| `/saas:auth-oauth-social` | 소셜 로그인 — Google·Apple·Kakao OAuth 2.0/OIDC, PKCE, state CSRF 방지, id_token 검증, Magic Link, 2FA·Passkey |
| `/saas:credit-system` | AI 사용량 과금 — 크레딧 모델, idempotent UsageRecord, 한도·auto-refill, LLM 원가+마진 가격, Free Tier, immutable ledger 환불 |
| `/saas:feature-flags` | Feature Flag — release·experiment·ops kill-switch·permission 4종류, OpenFeature, … |
| `/saas:media-handling` | 미디어 자산 처리 — presigned URL 직접 업로드, 변환 파이프라인, CDN 배포, EXIF·SSRF·transcoding DoS 방어, 만료 관리 |
| `/saas:media-streaming` | 라이브 스트리밍과 DRM — 프로토콜 선택, ingest, live transcoding·ABR, 콘텐츠 보호, CDN multi-tier, Live→VOD 변환, 비용 |
| `/saas:multi-tenancy` | 멀티테넌시 — Schema·Row·Database 격리 모델, Team/Org 도메인 모델, tenant context 전파, 멤버 권한, 초대, 테넌트 단위 과금 |
| `/saas:notification-multichannel` | 멀티채널 알림 — Push·Email·SMS·Slack·In-App, 사용자 선호, fallback chain, 템플릿, Notification Center, digest, 카카오 알림톡 |
| `/saas:payment-integration` | 결제 통합 — Stripe·Toss·PortOne, token-first 구조, webhook 처리, Saga 분산 트랜잭션, 결제 도메인 모델, 보안 금지 사항 |
| `/saas:rate-limiting` | API 요청 제한 — Token Bucket·Sliding Window·Leaky Bucket 알고리즘, Redis 구현, user·tenant·IP 다층 키, 429 응답·헤더, 분산 동기화 |
| `/saas:search-recommend` | 사용자 노출 검색·추천 — 검색 엔진 선택, SearchGateway, 한국어 형태소 분석, DB↔검색 인덱스 일관성, 추천 3패턴, 검색 분석 |
| `/saas:subscription-billing` | SaaS 구독 결제 허브 — provider 매트릭스, SubscriptionGateway, 한국 정기결제, 빌링 사이클 상태 머신, webhook·idempotency |
| `/saas:subscription-billing-flows` | Subscription Billing Flows (운영 흐름) — Proration, Dunning, Plan Change, Invoice + Multi-currency, Metered, … |
| `/saas:subscription-billing-metrics` | 구독 메트릭 — MRR·ARR·Churn, MRR movement·Cohort retention SQL, voluntary vs involuntary churn, Grafana 패널, build … |
| `/saas:virtual-waiting-room` | 대규모 티켓팅 — Redis 대기열 기반 Virtual Waiting Room, SSE 입장 알림, 좌석 분산 잠금, 결제 Saga 연동, 100만 동접 Capacity Planning |
| `/saas:webhook-delivery` | webhook 발신 — 재시도(exponential backoff+jitter), HMAC-SHA256 서명, 구독자별 순서 보장, circuit breaker, DLQ·replay, 관리 API |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `saas:business-decision-agent` | 신규 SaaS 부트스트랩의 4 ADR 일관성 orchestration 에이전트 — 멀티테넌시, 인증 Provider, 결제 Provider, 알림 채널 결정을 순서대로 수행해 일관된 ADR … |
