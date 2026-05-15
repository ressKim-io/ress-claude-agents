# AGENTS.md

이 레포에서 작업하는 모든 AI 코딩 에이전트를 위한 가이드라인.
Claude Code, Cursor, GitHub Copilot, Codex, Gemini CLI, Windsurf 등 [Linux Foundation AGENTS.md 표준](https://agents.md/)을 지원하는 모든 도구에 적용된다.

상세 룰은 `.claude/rules/` 참조 (Claude Code 자동 로딩). Claude Code 전용 최적화는 본 파일 §Claude Code-Specific 참조. `CLAUDE.md`는 본 파일의 symlink (다도구 호환성 유지).

---

## Project Overview

이 레포는 **AI 코딩 에이전트용 재사용 가능한 룰/스킬/에이전트 컬렉션**이다. 다른 프로젝트에 install되어 코딩 표준과 도메인 지식을 제공한다.

| 자산 | 위치 | 개수 |
|---|---|---|
| Skills (도메인 패턴) | `.claude/skills/` | 273개 = 독립 `.md` 259 + 폴더형 `SKILL.md` 14 (Go, Java/Spring, K8s, MSA, observability, business, legal, operations 등 22 카테고리) |
| Agents (전문 에이전트) | `.claude/agents/` | 49개 (database-expert, k8s-troubleshooter, saga-agent, business-decision-agent 등) |
| Rules (코딩/보안/워크플로우) | `.claude/rules/` | 24개 (이 AGENTS.md의 상세판, effort-guide 포함) |
| Templates (작성 표준) | `.claude/templates/` | SKILL-SPEC, AGENT-SPEC + 7개 template (신규 자산 작성 spec) |
| Plugins (역할별 번들) | `plugins/*.yml` | 12 bundles |
| Workflows (시나리오 번들) | `.claude/workflows/*.yml` | 11 scenarios |

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

각 skill에 ADR 템플릿 포함. **0→1 신규 프로젝트는 [`bootstrap-new-saas`](.claude/workflows/bootstrap-new-saas.yml) workflow가 `agents/business-decision-agent`로 4 ADR을 자동 orchestration**한다 (compliance-strategy-agent / platform-strategy-agent와 함께). 기존 프로젝트에 새 도메인 추가만 필요하면 [`new-domain`](.claude/workflows/new-domain.yml) workflow 사용.

---

## Tool-Specific Optimization

| 도구 | 추가 설정 |
|---|---|
| **Claude Code** | 본 파일 §Claude Code-Specific + `.claude/rules/`, `.claude/skills/`, `.claude/agents/` 자동 로딩 |
| **Codex** | `.codex/AGENTS.md` (본 파일의 symlink) + `.codex/agents/`, `.codex/skills/` (P4 adapter 산출물) |
| **Cursor** | 본 파일 자동 인식 + `.cursor/rules/*.mdc` (P4 adapter 산출물) |
| **Copilot / Gemini CLI / Windsurf** | 본 파일 자동 인식 — 추가 설정 불필요 |

도구별 최적화는 선택. 핵심 룰은 모두 본 파일에 있다.

---

## Claude Code-Specific

> Claude Code가 본 파일을 읽는다 (Linux Foundation AGENTS.md 표준). `CLAUDE.md`는 본 파일의 symlink — 동일 내용을 본다. 다른 도구는 자기에게 무관한 본 섹션을 무시.

### Auto-Loaded Rules

`.claude/rules/*.md`는 Claude Code 세션 시작 시 자동 로딩 (다른 도구는 자동 로드하지 않으므로 핵심은 본 파일에 요약).

| Rule | 역할 | 본 파일 대응 섹션 |
|---|---|---|
| `clean-code.md` | 가독성 원칙 | Code Style |
| `workflow.md` | EXPLORE→PLAN→IMPLEMENT→VERIFY→COMMIT | Workflow |
| `git.md`, `code-review.md` | git/PR | Git & Commits, PRs |
| `security.md` | 시크릿/입력검증/인증 | Security |
| `testing.md` | TDD, 커버리지 | Testing |
| `debugging.md` | 4단계 프로토콜 | Debugging |
| `monitoring.md` | PromQL/OTel | Monitoring |
| `documentation.md` | 11종 템플릿 | Documentation |
| `user-approval.md` | 외부 작업 승인 | User Approval |
| `cloud-cli-safety.md` | AWS/GCP 위험 명령 | Cloud CLI Safety |
| `go.md`, `java.md`, `spring.md` | 언어별 | Language-Specific |
| `version-compatibility.md` | 의존성 매트릭스 관리 (K8s/Istio/ArgoCD/OTel) | (path-scoped: Chart.yaml, values, build.gradle 등) |
| `config-contract-audit.md` | 명시값+기본값+환경별 override 3단계 검증 | (universal — 모든 config 작업) |
| `professional-writing.md` | 포트폴리오/슬라이드 카피 원칙 | (rare — 자기 어필 글쓰기 시) |
| `istio.md` | VirtualService/AuthZ/PeerAuth/Gateway FQDN 규칙 | (path-scoped: istio/, virtualservice, authorizationpolicy 등) |
| `k8s-manifest.md` | ArgoCD Application/AppProject/NetworkPolicy/RBAC | (path-scoped: application, networkpolicy, clusterrole 등) |
| `terraform.md` | SG/IAM/state/secret 운영 규칙 | (path-scoped: *.tf, *.tfvars) |
| `devlog-lifecycle.md` | dev-logs 4-Tier 정책 + frontmatter 표준 | (path-scoped: docs/dev-logs/*) |
| `phase-workflow.md` | SDD Phase 게이트 워크플로우 | (path-scoped: sdd-*.md, phase-start*) |
| `token-budget.md` | Opus 4.7 전용 | (아래) |
| `effort-guide.md` | low/medium/xhigh/max 단계별 사용 가이드 + 49 agents / 273 skills 카테고리별 매핑 | (universal — 모든 작업) |
| `deep-thinking.md` | 얕은 추측 / 추정 명시 금지, WebFetch 검증 의무, ⚠️ unverified 마킹 | (universal — 모든 작업) |

### Token Budget (Opus 4.7)

- Context **80% 초과 → 세션 종료**, 무관 태스크 전환 시 `/clear`
- Effort 기본 `xhigh` (Claude Code 기본값), 단순 조회 `low`, frontier 문제만 `max`
- Tokenizer 4.6 → 4.7: `max_tokens` **35% headroom**, prompt cache 재빌드 가정 (최소 4096 tokens)
- Subagent는 명시 spawn (Opus 4.7은 기본적으로 덜 spawn함). 10+ 파일 탐색은 subagent 위임
- 상세: `.claude/rules/token-budget.md` + 카테고리별 매핑 `.claude/rules/effort-guide.md`, 코드 예시·비용 계산은 `/token-budget` skill

### Claude-Only Features

| Feature | 위치 | 호출 |
|---|---|---|
| Skills | `.claude/skills/` | 자동 발견 (description 매칭) |
| Subagents | `.claude/agents/` | `Agent` 도구 (`subagent_type=...`) |
| Slash Commands | `.claude/commands/` | `/command-name` |
| Plugins | `plugins/*.yml` | `install.sh --plugin <name>` |
| Workflows | `.claude/workflows/*.yml` | `install.sh --workflow <name>` |

자산 통계: [.claude/inventory.yml](.claude/inventory.yml). 현재 273 skills (inventory.yml 의 259 + 폴더형 SKILL.md 14 — script 카운트 차이) / 49 agents / 43 commands / 12 plugins / 11 workflows. `scripts/generate-inventory.sh` 로 자동 재생성.

**신규 skill / agent 작성 표준**: [`.claude/templates/SKILL-SPEC.md`](.claude/templates/SKILL-SPEC.md) / [`AGENT-SPEC.md`](.claude/templates/AGENT-SPEC.md). frontmatter / description 패턴 / Verification Criteria 섹션 강제.

### Opus 4.7 Behavioral Notes

기존 프롬프트 재조정 포인트:
- **Literal interpretation** — 의도·제약·수락 기준 첫 턴 완전 명세
- **Subagent 명시 spawn** — fan-out 필요 시 "Use subagents to investigate X in parallel"
- **자체 검증 내장** — "double-check before returning" 같은 scaffolding 제거
- **응답 길이 자동 calibration** — 고정 verbosity 지시 재검토
- **Rules 100~150줄이 sweet spot** — 매 대화 자동 로딩이라 길면 묻힘. 상세는 skill로 분리

---

## Governance

**Source of Truth 계층** (충돌 시 위에서 아래로 우선):

1. **AGENTS.md** (본 파일) — 모든 도구 적용 보편 룰 + §Claude Code-Specific. **Single source of truth.**
2. **`.claude/rules/*.md`** — Claude Code 자동 로딩 상세 룰. 본 파일과 **반드시 일관**.
3. **Mirrors**:
   - `CLAUDE.md` → 본 파일 symlink (Claude Code 호환)
   - `.codex/AGENTS.md` → 본 파일 symlink (Codex 호환)

**룰 변경 절차**:
- **보편 룰 또는 Claude Code-Specific** → 본 파일 수정 → 관련 `.claude/rules/`로 propagate
- **충돌 발견 시** → 본 파일 기준으로 다른 파일 정정
- mirror symlink는 직접 편집 금지 (실제 파일 = AGENTS.md)

**드리프트 점검**: `scripts/validate-rules-drift.sh`가 AGENTS.md ↔ `.claude/rules/` 양방향 참조 자동 검증. CI drift job 통합.
