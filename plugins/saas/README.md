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
| `/saas:admin-api-keys` | Admin API Keys — API Keys / Personal Access Tokens / Service Tokens — 외부 통합·CLI·자동화·서비스 간 인증. 발급/회전/폐기, scope … |
| `/saas:audit-log` | Audit Log — Audit Log — 누가 언제 무엇을 어떻게 변경했는가. Append-only 이벤트 로그, tenant-scoped 격리, 규제 대응(GDPR/SOC2/HIPAA), … |
| `/saas:auth-oauth-social` | OAuth Social Login — OAuth 2.0 / OIDC 소셜 로그인 통합 — Google/Apple/Kakao, PKCE, State CSRF 방지, Magic Link, 2FA. … |
| `/saas:credit-system` | AI/사용량 모네타이징 — 토큰/API 호출 과금, prepaid credit, 잔액 원장, threshold 알림, free tier 차감, hybrid(seat+usage), LLM … |
| `/saas:feature-flags` | Feature Flags / Toggles — 코드 배포와 기능 노출 분리. Release toggle / Experiment / Ops kill-switch / Permissioning |
| `/saas:media-handling` | 미디어 자산 처리 — 이미지/영상/문서 업로드, S3·Cloudflare R2·Naver Cloud presigned URL, libvips/imgproxy 변환, 한국 CDN(Naver … |
| `/saas:media-streaming` | 라이브 미디어 스트리밍 — LL-HLS / WebRTC ingest / RTMP / SRT, Live transcoding, ABR, DRM (Widevine/PlayReady/FairPlay), … |
| `/saas:multi-tenancy` | Multi-Tenancy — 멀티테넌시 아키텍처 — Team/Org 관리, 데이터 격리(Schema/Row/Database), 멤버 권한, 초대 흐름, 컨텍스트 전파. SaaS 부트스트랩 핵심. … |
| `/saas:notification-multichannel` | Multi-Channel Notification — 멀티채널 알림 시스템 — Push/Email/SMS/Slack/In-App. User Preferences, Fallback chain, … |
| `/saas:payment-integration` | Payment Integration — 결제 통합 패턴 — Stripe/Toss/PortOne, Token-first, Webhook 처리, 분산 트랜잭션. 한국 시장 우선 + 글로벌 옵션. … |
| `/saas:rate-limiting` | Rate Limiting — API 요청 제한. Token Bucket / Sliding Window / Leaky Bucket / Fixed Window 알고리즘, Redis 구현, 429 응답 |
| `/saas:search-recommend` | 사용자 노출용 검색 + 추천 — Elasticsearch/OpenSearch/Algolia/Typesense Provider, 한국어 형태소 분석(nori), Saga 기반 인덱스 sync, … |
| `/saas:subscription-billing` | Subscription Billing Hub — SaaS 구독 결제. Provider 매트릭스, 빌링 사이클 상태 머신, Webhook + idempotency, 보안 |
| `/saas:subscription-billing-flows` | Subscription Billing Flows (운영 흐름) — Proration, Dunning, Plan Change, Invoice + Multi-currency, Metered, … |
| `/saas:subscription-billing-metrics` | Subscription Billing — Metrics & Dashboards — 구독 비즈니스 메트릭 — MRR/ARR/Churn/Cohort SQL + Grafana 대시보드 + 외부 도구. … |
| `/saas:virtual-waiting-room` | 대규모 티켓팅 — Redis 대기열 기반 Virtual Waiting Room, SSE 입장 알림, 좌석 분산 잠금, 결제 Saga 연동, 100만 동접 Capacity Planning |
| `/saas:webhook-delivery` | 발신자 관점 webhook 표준 — HMAC 서명, exponential backoff + jitter 재시도, per-subscriber 순서 보장, DLQ + replay, … |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `saas:business-decision-agent` | 신규 SaaS 부트스트랩의 4 ADR 일관성 orchestration 에이전트 — 멀티테넌시, 인증 Provider, 결제 Provider, 알림 채널 결정을 순서대로 수행해 일관된 ADR … |
