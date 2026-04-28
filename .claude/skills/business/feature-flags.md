# Feature Flags

Feature Flags / Toggles — 코드 배포와 기능 노출 분리. Release toggle / Experiment / Ops kill-switch / Permissioning 4 종류, OpenFeature 표준, LaunchDarkly/Unleash/Flagsmith, 점진 롤아웃, 타겟팅. SaaS 부트스트랩 추천.

배포 ≠ 릴리스. **트렁크 기반 개발의 전제 조건**. 잘못 사용하면 영구 if-else 지옥, 잘 사용하면 안전한 빠른 출시.

## When to Use

- Trunk-based development 도입 (Gitflow 탈출)
- Canary 배포·점진 롤아웃 (1% → 10% → 100%)
- A/B 테스트, 실험적 기능 (실험 결과로 ON/OFF)
- Kill-switch (사고 시 즉시 끄기)
- Plan-gating (Pro 전용 기능)
- Beta 프로그램 (특정 사용자만 접근)
- Dark launching (배포만, 노출 X)

**관련 skill**: `cicd/deployment-canary.md`, `business/multi-tenancy.md`, `dx/spec-driven-development.md`, `observability/observability-incident-playbook.md`
**관련 agent**: `tech-lead`, `architect-agent`

---

## 1. 4종류 분류 (Pete Hodgson)

| 종류 | 수명 | 변경 빈도 | 예시 |
|---|---|---|---|
| **Release** | 단기 (~수주) | 1~2회 (배포 시) | 신기능 점진 출시 |
| **Experiment** | 중기 (~수개월) | 자주 (실험 분석) | A/B 테스트 |
| **Ops** | 장기 (영구) | 사고 시만 | Kill-switch, circuit breaker |
| **Permission** | 영구 | 가끔 | Pro plan, 베타 access |

> **수명 명시 X = 안티패턴**. flag 만들 때 "언제 제거할지" 같이 결정.

### 종류별 설계 차이

```
Release: 단순 boolean, 배포 후 100% → 즉시 제거
Experiment: 변형 N개 (variant A/B/C), 통계 수집 (events 발행)
Ops: 즉시 반영 (cache TTL 0), 알림 통합
Permission: 사용자 attribute 기반 (plan, role, tenant)
```

---

## 2. OpenFeature 표준 (벤더 중립)

> CNCF 인큐베이팅 프로젝트. 2026 기준 사실상 표준.

```
OpenFeature SDK
  ├─ Provider 플러그인 (LaunchDarkly / Unleash / Flagsmith / 자체 구현)
  ├─ EvaluationContext (user, tenant, attributes)
  ├─ Hooks (before/after/error, telemetry 통합)
  └─ Boolean / String / Number / Object flag

코드:
  client.getBooleanValue("new-checkout", false, evaluationContext)
```

**장점**: 벤더 lock-in 회피, OTel hook 자동 연동, 다언어 SDK
**단점**: 작은 SaaS는 직접 구현이 더 가벼움

### Frontend SDK vs Backend SDK (착각 금지)

| 측면 | Backend SDK | Frontend SDK (Web/Mobile) |
|---|---|---|
| 평가 위치 | 서버 (전체 룰셋 보유) | 클라이언트 (특정 사용자 컨텍스트만 받음) |
| 룰셋 노출 | 안전 | **클라이언트 디컴파일 가능** → Permission flag는 절대 X |
| 캐싱 | local LRU 5s + 서버 인메모리 | localStorage / SecureStorage + 폴링·SSE |
| 네트워크 | provider 직접 | provider edge 또는 **bootstrap from backend** (권장) |
| 평가 빈도 | 매 요청 | 세션 시작 + flag 변경 push |
| 사용자 식별 | session/JWT 기반 | anonymous → 로그인 후 식별자 변경 (sticky 깨짐 주의) |

> **핵심**: Permission/Plan-gating은 **반드시 backend에서** 평가. Frontend flag는 UI 토글·실험에만. 클라이언트 응답을 신뢰하지 말 것.

---

## 3. 솔루션 비교

| 솔루션 | 가격 | 특징 | 적합 |
|---|---|---|---|
| **LaunchDarkly** | $$$ | enterprise 표준, RBAC↑, audit↑ | 큰 조직, 규제 |
| **Unleash** (OSS) | $ / Cloud | self-host 가능, OpenFeature 1급 지원 | 비용·격리 우선 |
| **Flagsmith** (OSS) | $ / Cloud | self-host, 단순 UI | MVP, 작은 팀 |
| **GrowthBook** (OSS) | 무료 / Cloud | A/B 통계 분석 강함 | 실험 중심 |
| **PostHog Feature Flags** | $ | 분석/세션 통합 | 통합 분석 도구 사용 시 |
| **자체 구현 (Postgres + Redis)** | 무인프라 | 핵심만 | 초기 MVP, 단순 토글 |
| **AWS AppConfig** | $ | AWS 통합, validation | AWS 락인 OK |

**MVP 추천**: GrowthBook 또는 Unleash self-host (둘 다 OpenFeature provider 있음). 자체 구현은 4~5개 flag까지만.

---

## 4. 자체 구현 (MVP — 100줄 코어)

### 데이터 모델

```
flag
  ├─ key (unique, "new-checkout")
  ├─ description, owner, type (release/experiment/ops/permission)
  ├─ default_variant
  ├─ variants (JSON: [{name, value}])
  ├─ rules (JSON: [{condition, variant}])
  ├─ rollout_percentage (0-100)
  ├─ kill_switch (boolean)
  ├─ expires_at  ← 수명 강제
  └─ updated_at, updated_by

flag_evaluation_log (선택, 분석용)
```

### 평가 알고리즘

```
1. flag.kill_switch == true → variant=off, return
2. rules 순회: condition match → variant 반환
3. rollout_percentage check:
   hash(flag.key + user.id) % 100 < percentage → variant=on
4. default_variant 반환
```

**핵심**: hash(flag_key + user_id)로 같은 사용자 = 항상 같은 variant. **flicker 방지**.

### 캐싱

```
Redis: flag:{key} → JSON (TTL 30s)
Local LRU: in-process 5s
배포 변경 시: pub/sub으로 cache invalidation
```

---

## 5. 평가 컨텍스트 (Targeting)

```
EvaluationContext:
  user.id
  user.email
  user.plan       (free/pro/enterprise)
  user.role       (admin/member)
  user.country
  user.created_at (cohort 분류)
  tenant.id
  tenant.tier
  request.ip
  request.country
  custom attributes
```

**Targeting 룰 예시**:
- `plan == "pro"` → variant=on
- `country IN ["KR", "JP"]` → variant=on
- `tenant.id == "abc-corp"` → variant=experimental
- `email ENDS_WITH "@company.com"` → variant=on (직원 dogfood)

---

## 6. 점진 롤아웃 (Progressive Rollout)

```
Phase 1: 직원 dogfood (email @company.com)        — 3 days
Phase 2: 1% sticky (hash bucket)                  — 1 day, error/latency 모니터
Phase 3: 10%                                      — 2 days
Phase 4: 50%                                      — 1 day
Phase 5: 100%                                     — flag 제거 PR
```

**자동화**: CI/CD에서 메트릭 정상 시 자동 ramp up (Argo Rollouts, Flagger 통합).

→ 배포 전략: [.claude/skills/cicd/deployment-canary.md](.claude/skills/cicd/deployment-canary.md)

---

## 7. Kill-Switch (Ops Toggle)

> **모든 외부 의존성 호출에 kill-switch**. 사고 시 5초 안에 끄기.

```
flag: external-payment-provider.enabled
default: true

if (!ff.eval("external-payment-provider.enabled")) {
  // bypass 또는 fallback (캐시된 응답, queue로 적재)
  return fallbackBehavior()
}
```

**적용 대상**:
- 외부 API 호출 (결제, 알림, 메일)
- 비싼 기능 (LLM, 추천)
- 신규 코드 경로 (배포 직후 1주일)
- 데이터 export
- 광고/분석 SDK (성능 문제 시)

**Ops flag 운영 규칙**:
- TTL 매우 짧게 (cache 5초)
- 변경 시 #incident Slack 자동 알림
- 변경 권한: 온콜만 + audit 필수
- 정기 훈련 (kill-switch 작동 테스트)

→ incident: [.claude/skills/observability/observability-incident-playbook.md](.claude/skills/observability/observability-incident-playbook.md)

---

## 8. A/B 실험 통합

```
client.getStringValue("checkout-flow", "control", ctx)  // → "control" or "variant_a"

이벤트 발행:
  experiment.exposure { user_id, flag, variant, ts }
  experiment.conversion { user_id, flag, variant, action, value }

분석: GrowthBook, PostHog, Statsig 등이 자동 통계
```

**주의**:
- **Sticky bucketing** 필수 (user.id hash). 같은 사용자가 다른 variant 보면 데이터 오염.
- SRM (Sample Ratio Mismatch) 모니터링 — 50/50 분배인데 60/40 나오면 버그
- Multi-flag 실험 시 상호작용 주의

---

## 9. 안티패턴

| 안티패턴 | 위험 | 올바른 방법 |
|---|---|---|
| 수명 명시 X | 영구 if-else 지옥 | `expires_at` 강제, dashboard alert |
| Release flag 100% 후 미제거 | 코드 복잡도↑ | 100% 도달 → 제거 PR 자동 생성 |
| 한 flag로 여러 기능 묶음 | 부분 롤백 불가 | 1 기능 = 1 flag |
| Permission flag를 코드 if-else | 권한 모델 흩어짐 | 권한 시스템(RBAC) 활용 |
| flag 변경 audit 없음 | 누가 켜고 껐는지 불명 | audit log 통합 |
| 환경별 flag 다름 (dev/prod) 별도 | 동기화 안 됨 | environment 속성으로 한 flag 관리 |
| flag 평가 매번 외부 API | latency↑, 가용성↓ | 로컬 캐시 + pub/sub invalidation |
| 동일 사용자 다른 variant | A/B 데이터 오염 | hash(flag+user_id) sticky |
| Ops flag = Release flag 혼용 | 사고 시 못 끔 | 종류 분리, 권한·알림 다름 |
| flag로 비즈니스 로직 복잡화 | 테스트 케이스 폭발 | flag 수 모니터, 50개 초과 경고 |
| 테스트 환경에서 flag 없이 동작 | "내 컴퓨터선 됐는데" | flag default 명시 + CI 양 variant 테스트 |

---

## 10. 거버넌스 (장기 운영)

### Flag 수 관리

```
KPI: 활성 flag 수 < 50개 / 서비스
경고: 90일 변경 X → 제거 후보
경고: 100% 도달 후 30일 → 제거 PR 자동 생성
```

### Code Review 룰

- 신규 flag 추가 PR → owner / type / expires_at 필수
- flag 평가 코드는 lint (직접 if 대신 helper 강제)
- 100% 롤아웃 + 1주 안정 → cleanup PR

### Stale Flag 자동 정리 도구

| 도구 | 기능 | 대상 |
|---|---|---|
| **LaunchDarkly Code References** | git 통합, `ldcli` CLI로 코드 내 flag 사용처 자동 매핑, 미사용 flag 보고서 | LaunchDarkly 사용자 |
| **Unleash Code References** (`unleash-code-refs`) | LD와 동일 패턴, OSS | Unleash 사용자 |
| **GrowthBook stale-flag detection** | 대시보드에서 100% rollout + 30일 미변경 자동 표시 | GrowthBook |
| **자체 grep 스크립트** + CI | `rg "flagKey\\(\"" src/`로 사용처 추출 + flag DB와 join | 자체 구현 |
| **PR bot 자동 cleanup PR** | 100% 도달 + 안정 후 N일 → bot이 cleanup PR 자동 생성 | 모든 도구 |

> **자동화 없으면 stale flag 누적 = 영구 if-else 지옥**. CI 파이프라인에 통합 필수.

### Audit

- 모든 flag 변경 audit log
- 변경자, 시점, before/after, 변경 사유 필수
- → audit-log: [.claude/skills/business/audit-log.md](.claude/skills/business/audit-log.md)

---

## 11. 모니터링

```
지표:
  flag_evaluations_total{flag, variant}      — 호출 수
  flag_evaluation_duration                   — 평가 latency
  flag_provider_errors_total                 — 외부 SDK 에러
  flag_active_count                          — 활성 flag 수
  flag_age_days{flag}                        — 노화 추적

알림:
  - flag 평가 실패율 > 1% (default fallback 비율↑)
  - 100% 도달 30일 후 미제거 → 정리 알림
  - 신규 flag 90일 변경 X → owner에게
```

---

## 12. ADR 템플릿 — Feature Flag 결정

```markdown
## Feature Flag ADR

| 항목 | 결정 | 대안 | 근거 |
|---|---|---|---|
| 솔루션 | Unleash self-host (OpenFeature provider) | LaunchDarkly / 자체 | 비용·OSS·표준 호환 |
| SDK | OpenFeature SDK | 벤더 SDK | 벤더 교체 가능 |
| 캐싱 | local LRU 5s + Redis 30s | 매번 SDK | latency ↓, 가용성 ↑ |
| 종류별 정책 | Release/Exp/Ops/Permission 분리 | 단일 | 권한·수명 차등 |
| 수명 강제 | expires_at 필수 + 자동 알림 | 자율 | 영구 toggle 방지 |
| 평가 sticky | hash(flag+user_id) | random | flicker·실험 데이터 |
| 변경 권한 | dev: 자유, prod-Ops: 온콜만 | 전체 자유 | 사고 방지 |
| Audit | 모든 변경 audit log | 벤더 의존 | 규제 + 추적 |
```

---

## 13. Quick Start Checklist

- [ ] Feature Flag ADR (솔루션, 종류 분류, 수명 정책)
- [ ] OpenFeature SDK 도입
- [ ] Provider 설정 (LaunchDarkly / Unleash 등)
- [ ] EvaluationContext 표준화 (user/tenant/request)
- [ ] 캐싱 (local + Redis + invalidation)
- [ ] 종류별 dashboard (Release/Experiment/Ops/Permission 구분)
- [ ] expires_at 필수화 + 자동 알림
- [ ] Audit log 통합 (변경 추적)
- [ ] 권한 정책 (dev/prod, 일반/Ops)
- [ ] 외부 의존성에 kill-switch
- [ ] 점진 롤아웃 가이드 (1% → 10% → 100%)
- [ ] A/B 실험: sticky bucketing + SRM 모니터
- [ ] 100% 후 cleanup PR 자동 생성 (CI)
- [ ] flag 평가 메트릭 + 알림
- [ ] CI에서 양 variant 테스트

---

## 14. 관련 자원

**우리 시스템 내부**:
- `skills/cicd/deployment-canary.md` — Canary와 결합
- `skills/business/multi-tenancy.md` — tenant 단위 타겟팅
- `skills/business/audit-log.md` — flag 변경 audit
- `skills/business/admin-api-keys.md` — flag 변경 API
- `skills/observability/observability-incident-playbook.md` — kill-switch 운영
- `skills/dx/spec-driven-development.md` — flag 명세
- `agents/tech-lead` — flag 거버넌스 결정
- `agents/architect-agent` — 종류 분류

**외부 자원**:
- OpenFeature 공식 (CNCF)
- Pete Hodgson — Feature Toggles (Martin Fowler blog)
- Unleash docs (OSS, OpenFeature 1급)
- LaunchDarkly Best Practices
- GrowthBook (실험 통계)

---

## 15. 다음 단계

1. **Argo Rollouts/Flagger 통합** — 메트릭 기반 자동 ramp up
2. **GitOps 통합** — flag YAML로 PR 리뷰 (감사 강화)
3. **Cost-aware flag** — 비싼 기능(LLM)에 budget 기반 ON/OFF
4. **Mobile/Edge 평가** — CDN edge 평가 (Cloudflare Workers)
5. **Multi-armed bandit** — 자동 최적 variant 선택 (실험 고도화)
