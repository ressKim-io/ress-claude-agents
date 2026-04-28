# AGENTS.md

이 레포에서 작업하는 모든 AI 코딩 에이전트를 위한 가이드라인.
Claude Code, Cursor, GitHub Copilot, Codex, Gemini CLI, Windsurf 등 [Linux Foundation AGENTS.md 표준](https://agents.md/)을 지원하는 모든 도구에 적용된다.

상세 룰은 `.claude/rules/` 참조 (Claude Code 자동 로딩). Claude 전용 최적화는 [CLAUDE.md](CLAUDE.md) 참조.

---

## Project Overview

이 레포는 **AI 코딩 에이전트용 재사용 가능한 룰/스킬/에이전트 컬렉션**이다. 다른 프로젝트에 install되어 코딩 표준과 도메인 지식을 제공한다.

| 자산 | 위치 | 개수 |
|---|---|---|
| Skills (도메인 패턴) | `.claude/skills/` | 220개 (Go, Java/Spring, K8s, MSA, observability, business 등 18 카테고리) |
| Agents (전문 에이전트) | `.claude/agents/` | 46개 (database-expert, k8s-troubleshooter, saga-agent 등) |
| Rules (코딩/보안/워크플로우) | `.claude/rules/` | 14개 (이 AGENTS.md의 상세판) |
| Plugins (역할별 번들) | `plugins/*.yml` | 10 bundles |
| Workflows (시나리오 번들) | `.claude/workflows/*.yml` | 7 scenarios |

**중요**: K8s/Cloud/Monitoring 섹션의 룰은 **install된 프로젝트**에 적용된다 (이 메타 레포 자체엔 K8s 없음).

## Setup

```bash
./install.sh                      # 전체 설치
./install.sh --plugin go-stack    # 특정 번들만
./install.sh --list-plugins       # 사용 가능한 번들 목록
./install.sh --workflow msa       # 시나리오 번들
```

전체 인덱스: [.claude/inventory.yml](.claude/inventory.yml)

---

## Core Principles

> [Andrej Karpathy의 LLM 코딩 함정 관찰](https://x.com/karpathy/status/2015883857489522876) 기반. 모든 작업의 메타-행동 기준.

1. **Think Before Coding** — 가정을 명시하라. 모호하면 멈추고 묻는다. 여러 해석이 있으면 모두 제시한다. 더 단순한 접근이 있으면 push back한다.
2. **Simplicity First** — 200줄로 될 일을 1000줄로 만들지 마라. 요청되지 않은 추상화/유연성/에러 핸들링 추가 금지. "시니어 엔지니어가 과하다고 할 코드인가?"
3. **Surgical Changes** — 요청 범위 밖 코드/주석/포맷 건드리지 않는다. 발견한 죽은 코드는 언급만, 삭제는 별도 요청. 모든 변경 라인이 사용자 요청과 직접 연결되어야 한다.
4. **Goal-Driven Execution** — 검증 가능한 성공 기준을 먼저 정의한다. "make it work" 같은 약한 기준 금지. "Add validation" → "Write failing tests for invalid inputs, then make them pass."

---

## Workflow

모든 코드 작업은 다음 순서를 따른다:

1. **EXPLORE** — 관련 파일 읽기 (변경 없음). 같은 파일 2회 이상 읽지 않는다. 큰 파일은 `wc -l` 후 범위 지정.
2. **PLAN** — 변경 파일 목록, 영향 범위 정리. multi-file 변경은 plan 우선.
3. **IMPLEMENT** — 한 번에 최대 10개 파일. 기존 패턴/스타일 준수. 최소 변경으로 목적 달성.
4. **VERIFY** — 테스트 통과, lint/format 체크, `git diff` 리뷰.
5. **COMMIT** — Conventional Commits, 테스트 통과 후만.

EXPLORE/PLAN 생략한 multi-file 변경 금지.

---

## Code Style

| 규칙 | 기준 |
|---|---|
| 메서드 길이 | 20–50줄 권장, 50줄 초과 시 분할 검토, 100줄 초과 금지 |
| Cognitive Complexity | ≤ 15 (줄 수보다 중요) |
| Guard Clause | 중첩 조건 대신 조기 반환 (happy path 최외곽) |
| Tell, Don't Ask | 객체 상태 꺼내 외부 판단 금지, 객체에게 행동 위임 |
| 추상화 수준 (SLAP) | 한 메서드 안 모든 코드는 같은 추상화 수준 |
| 네이밍 | 의도 노출. Boolean은 `is/has/can/should`. 매직 넘버는 enum/상수. 도메인 용어 사용. |
| 주석 | **WHY만**. WHAT/HOW 주석 금지. 비즈니스 규칙, 비자명한 최적화 사유에만. |

---

## Git & Commits

**Conventional Commits 필수**: `<type>(<scope>): <description>`
- type: `feat | fix | docs | style | refactor | perf | test | build | chore | ci`
- description: 소문자 시작, 마침표 없음, 50자 이내
- Breaking change는 `feat!:` 또는 footer에 `BREAKING CHANGE:`

**브랜치 명명**: `feature/#123-short-desc`, `fix/#123-bug`, `hotfix/...`, `docs/...`. 소문자, 하이픈 구분.

**커밋 규율**:
- 하나의 목적 = 하나의 커밋. WIP 직접 커밋 금지.
- `git add .` 금지, 파일 명시적 스테이징.
- `.env`, credentials, `*.pem`, `*.key` 절대 커밋 금지.
- `main`/`master` 직접 push 금지, force push 금지.

---

## Pull Requests

- **Title**: Conventional Commits 형식 (`feat(auth): add OAuth2 support`)
- **Size**: 단일 PR ≤ 400줄. 초과 시 기능 단위로 분할.
- **Body**: Summary (1–3 bullets, why) + Test plan checklist + `Closes #issue`

---

## Testing

- **TDD**: Red → Green → Refactor. 테스트 없이 구현 금지.
- **Naming**: `should_행위_when_조건` 또는 `@DisplayName`. `test1()`, `testOk()` 금지.
- **Structure**: Given-When-Then 주석 명시. 한 테스트에 When 2번 = 분리.
- **Coverage**: 전체 80%+, 핵심 비즈니스 로직 95%+. happy/edge/error 케이스 모두.
- **Integration tests**: 실제 DB/외부 서비스 사용 (TestContainers). 프로덕션 의존성을 mock으로 대체 금지.
- **금지**: 순서 의존, `Thread.sleep()`, 테스트용 프로덕션 분기(`if (isTest)`), `@Disabled`로 실패 무시.

---

## Security

- **시크릿**: 코드 하드코딩 절대 금지. 환경변수/Secret Manager 사용. `.env`는 `.gitignore`. 코드 예시는 `YOUR_API_KEY` 같은 placeholder.
- **입력 검증**: 모든 외부 입력 불신.
  - SQL: PreparedStatement 사용. 문자열 연결 금지.
  - XSS: 이스케이핑 필수. `innerHTML` 직접 할당 금지.
  - Command Injection: shell 명령에 외부 입력 직접 사용 금지. Path traversal(`../`) 검증.
- **인증/인가**: JWT/session은 HttpOnly+Secure cookie (LocalStorage 금지). 비밀번호는 bcrypt/scrypt/Argon2. MD5/SHA-1 단독 금지. 모든 엔드포인트 인가 체크 (IDOR 방지).
- **로깅**: PII/시크릿/스택트레이스 응답 노출 금지.
- **의존성**: `npm audit`, `pip-audit`, `govulncheck`, `trivy` 정기 스캔.

---

## Debugging

원인 확인 없이 코드 수정 금지. 프로토콜:

1. **REPRODUCE** — 에러/스택트레이스 정독, 최소 재현 케이스 확보. 재현 안 되면 다음 단계 진행 금지.
2. **DIAGNOSE** — 가설 → 검증 → 다음 가설. 가설 검증 전 코드 수정 금지.
3. **ROOT CAUSE** — 증상 아닌 원인. "왜?" 반복.
4. **FIX** — 근본 원인만 수정. 회귀 테스트 추가. regression 점검.

**금지**: 추측 수정, 에러 suppress (`catch { /* ignored */ }`), 임시 workaround (TODO + 원인 분석 주석 없이), 여러 문제 동시 수정.

---

## User Approval — External Actions

외부 시스템 영향 작업은 **반드시 사용자 승인 후 실행**:

- **Git/GitHub**: `git push`, `gh pr create/comment/merge`, `gh issue create/close`, `gh release create`
- **외부 메시지**: Slack/Discord 메시지, 외부 API 상태 변경
- **GitOps**: ArgoCD sync 트리거
- **클라우드 리소스**: 생성/삭제/변경

**리뷰 결과 게시 프로세스**: 리뷰 실행 → 사용자에게 텍스트로 표시 → 사용자 확인/수정 → 승인 후 `gh pr comment`. 자동 게시 금지.

**서브 에이전트 위임 시**: 에이전트는 결과만 반환. 외부 게시 권한 위임 금지.

---

## Kubernetes Safety

`kubectl`로 K8s 리소스 직접 수정 금지 (읽기 전용만):
- **허용**: `get`, `describe`, `logs`, `top`, `port-forward`, `exec` (읽기용)
- **금지**: `edit`, `patch`, `apply`, `delete`, `set image`, `scale`, `rollout`

변경 경로: 소스 코드 수정 → git commit/push → ArgoCD sync.

**ServerSideApply=true 앱에 Force Sync 절대 금지** (`--force` + `--server-side` 비호환, 전체 sync stuck 위험).

---

## Cloud CLI Safety

위험한 클라우드 CLI 명령(AWS/GCP destructive operations)은 사전 승인 없이 실행 금지.
상세 목록: [.claude/rules/cloud-cli-safety.md](.claude/rules/cloud-cli-safety.md)

---

## Monitoring & Observability

- **PromQL/LogQL/TraceQL 안티패턴 회피** (high-cardinality label, `.*` regex 등)
- **OTel 시맨틱 컨벤션 v2** 준수 (`http.request.method`, `service.name`)
- **Grafana 변수**는 metric label과 정확히 일치
- 상세: [.claude/rules/monitoring.md](.claude/rules/monitoring.md)

---

## Documentation

`docs/` 하위에 문서 작성. 다음 상황에 **자동 생성**:

| 트리거 | 위치 |
|---|---|
| 기술 A vs B 선택 (대안 2개+) | `docs/adr/NNNN-제목.md` |
| 부하 테스트 완료 | `docs/load-test/YYYY-MM-DD-시나리오.md` |
| 프로덕션/스테이징 장애 | `docs/postmortem/YYYY-MM-DD-제목.md` |
| 환경/아키텍처 전환 완료 | `docs/migration/NNNN-제목.md` |
| CI/CD 신규/대폭 변경 | `docs/cicd/레포명-pipeline.md` |

상세 템플릿 11종: [.claude/rules/documentation.md](.claude/rules/documentation.md)

---

## Language-Specific

| 언어 | Rules | Skills |
|---|---|---|
| Go | [.claude/rules/go.md](.claude/rules/go.md) | `.claude/skills/go/` |
| Java/Spring | [.claude/rules/java.md](.claude/rules/java.md), [spring.md](.claude/rules/spring.md) | `.claude/skills/spring/` |
| Python | — | `.claude/skills/python/` |
| Frontend (React/Next.js/TS) | — | `.claude/skills/frontend/` |

---

## Business Patterns

신규 SaaS/서비스 부트스트랩 시 매번 0에서 만들지 않도록 검증된 비즈니스 패턴 모음.
**아이디어 → 신규 프로젝트** 흐름에 직접 매핑.

| 영역 | Skill | 핵심 |
|---|---|---|
| 멀티테넌시 | [`skills/business/multi-tenancy`](.claude/skills/business/multi-tenancy.md) | Team/Org, 데이터 격리(Row/Schema/DB), RBAC, 초대 |
| 인증 | [`skills/business/auth-oauth-social`](.claude/skills/business/auth-oauth-social.md) | Google/Apple/Kakao, PKCE, Magic Link, 2FA |
| 결제 | [`skills/business/payment-integration`](.claude/skills/business/payment-integration.md) | Stripe/Toss/PortOne, Token-first, Webhook, Saga |
| 알림 | [`skills/business/notification-multichannel`](.claude/skills/business/notification-multichannel.md) | Push/Email/SMS, Fallback, Notification Center |

**신규 프로젝트 시작 시 ADR 작성 순서** (이 순서대로 결정해야 변경 비용 ↓):
1. 멀티테넌시 격리 모델 (가장 비싼 결정)
2. 인증 Provider (시장에 따라 Kakao/Google/Apple)
3. 결제 Provider (한국=PortOne/Toss, 글로벌=Stripe)
4. 알림 채널 + Provider

각 skill에 ADR 템플릿 포함. `agents/tech-lead`로 위임 가능.

---

## Tool-Specific Optimization

| 도구 | 추가 설정 |
|---|---|
| **Claude Code** | [CLAUDE.md](CLAUDE.md) + `.claude/rules/`, `.claude/skills/`, `.claude/agents/` 자동 로딩 |
| **Cursor / Codex / Copilot / Gemini CLI / Windsurf** | 이 AGENTS.md 자동 인식 — 추가 설정 불필요 |

도구별 최적화는 선택. 핵심 룰은 모두 이 파일에 있다.

---

## Governance

**Source of Truth 계층** (충돌 시 위에서 아래로 우선):

1. **AGENTS.md** (이 파일) — 모든 도구 적용 보편 룰. **Single source of truth.**
2. **CLAUDE.md** — Claude Code 전용 메커니즘 (token budget, plugins, subagents).
3. **`.claude/rules/*.md`** — Claude Code 자동 로딩 상세 룰. AGENTS.md와 **반드시 일관**.

**룰 변경 절차**:
- **보편 룰** → AGENTS.md 먼저 수정 → 관련 `.claude/rules/`로 propagate
- **Claude 전용** → CLAUDE.md 또는 `.claude/rules/token-budget.md`만 수정
- **충돌 발견 시** → AGENTS.md 기준으로 다른 파일 정정

**드리프트 점검**: 룰 추가/변경 PR에서 양쪽 일관성 리뷰 필수.
