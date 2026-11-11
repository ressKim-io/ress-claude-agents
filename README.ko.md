[English](README.md) | **한국어**

<div align="center">

# ress-claude-agents

![Claude](https://img.shields.io/badge/Claude_Code-D97757?style=for-the-badge&logo=claude&logoColor=white)

[![CI](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml/badge.svg)](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/ressKim-io/ress-claude-agents?style=social)](https://github.com/ressKim-io/ress-claude-agents)

### AI가 동료가 되는 개발 환경을 설계합니다

DevOps · Backend · SRE · MLOps를 위한 Claude Code plugin 모음. 필요한 영역만 골라 설치합니다.

[Why AI-First](#-why-ai-first) · [어떤 plugin 을 가져갈까](#-어떤-plugin-을-가져갈까) · [설치](#-설치) · [Guides](#-사용-가이드) · [Rules](#-rules) · [Automation](#-automation-infrastructure)

</div>

---

## 🧪 Why AI-First

> *"Google 검색 → StackOverflow → 복사 → 적용 → 디버깅"*
> *이 반복 루프를 끊을 수 있다면?*

저는 Claude Code를 단순 코드 자동완성이 아닌, **도메인 전문가로** 만들어 함께 일하는 방식을 실험합니다.
각 분야의 Best Practices를 Skills로 구조화하고, 전문 Agents가 판단하고 실행합니다.

```
🔄 기존 방식                          ⚡ AI-Augmented 방식
──────────────────                    ──────────────────
Google/StackOverflow 검색              → /k8s:k8s-security 로 즉시 패턴 적용
Runbook 찾아서 수동 실행               → incident-responder 가 자동 진단
"이거 어떻게 해요?" 반복 질문          → 요청에 맞는 skill 을 골라 답변
100만 VU 테스트 시나리오 수동 작성     → /sre:load-testing skill 이 템플릿 제공
```

**이 레포가 해결하는 문제:**
- 매번 같은 패턴을 검색하고 복사하는 비효율
- 팀원마다 다른 코딩 스타일과 아키텍처 결정
- 장애 대응 시 Runbook을 찾느라 낭비되는 MTTR
- 새로운 기술 도입 시 러닝 커브

---

## 🧭 어떤 plugin 을 가져갈까

각 plugin 의 README 에 skill, agent, command 목록과 함께 쓰면 좋은 plugin, 복사해 갈 rule 이 있습니다.

| 영역 | Plugin | 이런 일을 할 때 |
|---|---|---|
| 언어 | [`go`](plugins/go/README.md) | Go 동시성, DB 접근, Gin, 마이크로서비스, 성능, 테스트 |
| | [`java`](plugins/java/README.md) | Java·Spring Data·Security·Cache, jOOQ, JVM 성능, 테스트 |
| | [`python`](plugins/python/README.md) | FastAPI, Django, asyncio, 성능, 테스트 |
| | [`frontend`](plugins/frontend/README.md) | React, Next.js, TypeScript, 상태 관리, CSS, 웹 성능 |
| 설계 | [`architecture`](plugins/architecture/README.md) | MSA, DDD, Saga, CQRS, API 설계, gRPC, 모듈러 모놀리스, 대규모 트래픽 |
| | [`messaging`](plugins/messaging/README.md) | Kafka, RabbitMQ, NATS, Redis Streams, AWS 메시징, 브로커 장애 |
| 인프라 | [`k8s`](plugins/k8s/README.md) | 스케줄링, 오토스케일링, 트래픽, Helm, 보안, GPU, manifest 리뷰 |
| | [`service-mesh`](plugins/service-mesh/README.md) | Istio Core·Ambient·Gateway·보안·관측, Linkerd |
| | [`infra`](plugins/infra/README.md) | Terraform, AWS·EKS, Docker, Crossplane, DB 운영, 클라우드 CLI 안전 |
| | [`cicd`](plugins/cicd/README.md) | GitHub Actions, ArgoCD, 배포 전략, 프리뷰 환경, 파이프라인 리뷰 |
| 운영 | [`observability`](plugins/observability/README.md) | OpenTelemetry, Prometheus, Grafana, Loki, eBPF, AIOps |
| | [`sre`](plugins/sre/README.md) | SLI/SLO, 장애 대응, 포스트모템, 카오스, DR, 부하 테스트, FinOps |
| | [`platform`](plugins/platform/README.md) | Backstage, Golden Path, 셀프서비스, Kratix, IDP 전략 |
| 보안·제품 | [`security`](plugins/security/README.md) | OWASP, 위협 모델링, 인증 패턴, 공급망, 시크릿, PIPA·GDPR·SOC2 |
| | [`saas`](plugins/saas/README.md) | 멀티테넌시, 소셜 로그인, 결제, 구독, 알림, Webhook |
| | [`ai`](plugins/ai/README.md) | RAG, Vector DB, LLMOps, MLOps, 모델 서빙, Agentic 아키텍처 |
| 공통 | [`dx`](plugins/dx/README.md) | 코드 리뷰, Git·PR 워크플로우, ADR·문서 템플릿, 토큰 운영 |
| | [`devlog`](plugins/devlog/README.md) | 트러블슈팅·결정·meta·피드백 dev-log 기록, Tier 정리 |

---

## 🚀 설치

Claude Code 안에서:

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install go@ress
```

터미널에서는 `claude plugin marketplace add`, `claude plugin install` 을 씁니다.

skill 은 description 을 보고 자동으로 선택되고, `/go:go-testing` 처럼 직접 부를 수도 있습니다. agent 이름은 `<plugin>:<agent>` 입니다.

```bash
"보안 취약점 검사해줘"             → dx:security-scanner
"프로덕션 파드가 죽어요"           → k8s:k8s-troubleshooter
"100만 동시접속 아키텍처 설계해줘" → /saas:virtual-waiting-room
"K6로 부하테스트 시나리오 작성해줘" → /sre:load-testing
```

**쓰는 것만 설치합니다.** 켠 plugin 은 매 세션 skill 목록을 추가하고(`claude plugin details <plugin>` 으로 비용 확인), 목록이 예산을 넘으면 description 이 빠지기 시작합니다.

### 하나만 복사하기

```bash
cp -r plugins/go/skills/go-testing       /path/to/project/.claude/skills/
cp    plugins/dx/agents/code-reviewer.md /path/to/project/.claude/agents/
cp    .claude/rules/core/security.md     /path/to/project/.claude/rules/
```

복사한 skill 에는 plugin 접두사가 붙지 않고(`/go-testing`), 원본 변경을 따라가지 않습니다. skill 은 `<skill-name>/SKILL.md` 레이아웃을 유지해야 합니다. Claude Code 는 다른 형태를 로드하지 않습니다.

### plugin 에 실리지 않는 것

- **Rules**: [`.claude/rules/`](.claude/rules/) 에서 복사합니다. plugin README 에 관련 rule 을 적어 두었습니다.
- **권한 규칙** (`permissions.deny`): 설치본에서 agent 의 Permission Boundary 는 강제되지 않는 안내문입니다.

### 이 레포에서 작업할 때

폴더를 신뢰하면 `dx`·`devlog` 가 켜집니다. 다른 plugin 은 `claude --plugin-dir plugins/<plugin>` 으로 띄웁니다. 클라우드 세션과 worktree 의 수정분도 `--plugin-dir plugins/dx` 가 필요합니다. 구조를 이렇게 정한 이유는 [ADR 0012](docs/adr/0012-native-plugin-structure.md) 에 있습니다.

---

## 📖 사용 가이드

> "내 상황에 뭘 써야 하지?" — 페르소나별 추천 조합 + 실전 시나리오

| 페르소나 | 가이드 | 핵심 도구 |
|----------|--------|----------|
| **백엔드 개발자** (Java/Go) | [personas/backend-dev.md](docs/guides/personas/backend-dev.md) | `/java:jvm-performance`, `/go:go-performance`, `/architecture:msa-ddd` |
| **DevOps / SRE** | [personas/devops-sre.md](docs/guides/personas/devops-sre.md) | `incident-responder`, `terraform-reviewer`, `/cicd:gitops-argocd` |
| **풀스택 / 제너럴리스트** | [personas/fullstack-generalist.md](docs/guides/personas/fullstack-generalist.md) | `code-reviewer`, `architect-agent`, `/architecture:api-design` |

| 시나리오 | 워크스루 | 소요 시간 |
|----------|---------|----------|
| 신규 MSA 서비스 개발 | [scenarios/new-microservice.md](docs/guides/scenarios/new-microservice.md) | 2-3시간 |
| 프로덕션 장애 대응 | [scenarios/production-incident.md](docs/guides/scenarios/production-incident.md) | 30-60분 |
| 플랫폼 팀 환경 구축 | [scenarios/platform-bootstrap.md](docs/guides/scenarios/platform-bootstrap.md) | 1-2일 |

**[콤보 레퍼런스](docs/guides/quick-reference.md)** — 상황별 에이전트+스킬 추천 조합 한눈에 보기 | [한국어 가이드](docs/guides/ko/README.md)

---

## 📏 Rules

**자동 적용**되는 규칙입니다. Skills와 달리 호출하지 않아도 활성화되고, plugin 에는 실리지 않아 필요하면 복사합니다. 폴더: `core/` · `process/` · `lang/` · `infra/` · `harness/`.

### Project Workflow (전체 적용)

| Rule | Description | Key Points |
|------|-------------|------------|
| 📝 `git` | Git 워크플로우 | Conventional Commits, Branch 네이밍, PR 400줄 제한 |
| 🧪 `testing` | 테스트 규칙 | TDD, Given-When-Then, 커버리지 80%+, @Disabled 금지 |
| 🔄 `workflow` | 작업 순서 | Explore → Plan → Code → Verify → Commit (MANDATORY) |
| 🔒 `security` | 보안 규칙 | 시크릿 하드코딩 금지, 입력 검증, PII 로깅 금지 |
| 🐛 `debugging` | 디버깅 프로토콜 | Reproduce → Diagnose → Root Cause → Fix |
| ✨ `clean-code` | Clean Code 원칙 | Composed Method, Cognitive Complexity, Guard Clause, 네이밍 |
| 👀 `code-review` | 코드 리뷰 워크플로우 | 멀티 관점 리뷰, 심각도 매트릭스 |
| 📡 `monitoring` | 모니터링 룰 | PromQL/LogQL/TraceQL 안티패턴, OTel 시맨틱 컨벤션 |
| 📚 `documentation` | 문서 자동 트리거 | ADR/postmortem/migration/load-test 자동 작성 |
| ☁️ `cloud-cli-safety` | 클라우드 CLI 안전 | AWS/GCP 위험 명령 차단 (사고 사례 기반) |
| ✅ `user-approval` | 외부 작업 승인 | gh/git push, ArgoCD sync 등 사전 승인 |
| 🪙 `token-budget` | 토큰 운영 | context 80%, subagent 명시 spawn, effort 레벨 |

### Language-Specific (경로 자동 매칭)

| Rule | Path Pattern | Description |
|------|-------------|-------------|
| ☕ `java` | `**/*.java` | Effective Java: Record, Builder, DI, 불변 객체, Modern Java |
| 🦫 `go` | `**/*.go` | Go Proverbs: 인터페이스, 에러 래핑, Context, Functional Options |
| 🌱 `spring` | `**/*.java` | Spring Boot: @Transactional, DTO/Entity, 예외 전략, 계층 구조 |

> **Skills vs Rules**: Rules는 "항상 자동 적용"되는 짧은 지시문, Skills는 "필요 시 로드"되는 상세 가이드입니다.
> `.java` 파일 편집 시 `java.md` + `spring.md`가 자동 적용되고, 상세 내용은 `/java:effective-java`, `/java:spring-patterns` 스킬을 참조합니다.

---

## 🏗️ Automation Infrastructure

이 레포는 컨텐츠만이 아니라, **컨텐츠를 관리하는 시스템** 자체도 자동화했습니다.

### 자동 생성

```bash
make inventory        # .claude/inventory.yml: 전체 skill·agent 목록
make plugin-readmes   # plugins/*/README.md: frontmatter 에서 생성
```

손으로 쓴 목록과 개수는 반드시 어긋납니다. 생성물은 CI 가 신선도를 검사합니다.

### CI/CD Pipeline

GitHub Actions 가 PR 마다 4개 Job 을 실행합니다:

| Job | Description |
|-----|-------------|
| **Docs** | 자산 목록, plugin 구성, 참조, 내부 링크 |
| **Inventory** | `inventory.yml`, plugin README 신선도 |
| **Lint** | ShellCheck으로 모든 스크립트 정적 분석 |
| **Drift** | rules ↔ AGENTS.md, frontmatter, 스키마, 강제 규칙, control-plane 테스트, 게이트 음성 테스트, adapter parity |

### Pre-commit Hooks & Quality Gates

```bash
make setup-hooks   # validate + lint 자동 실행
make all           # 전체 검증
make test-gates    # 사본을 일부러 망가뜨려 게이트가 의도한 사유로 실패하는지 확인
```

---

## 🛠️ Tech Stack

<div align="center">

**Languages & Frameworks**

![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white)
![Java](https://img.shields.io/badge/Java-ED8B00?style=flat-square&logo=openjdk&logoColor=white)
![Spring](https://img.shields.io/badge/Spring_Boot-6DB33F?style=flat-square&logo=springboot&logoColor=white)
![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=kotlin&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)

**Infrastructure & Orchestration**

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=flat-square&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS_EKS-FF9900?style=flat-square&logo=amazoneks&logoColor=white)
![Crossplane](https://img.shields.io/badge/Crossplane-0080FF?style=flat-square&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat-square&logo=helm&logoColor=white)

**GitOps & CI/CD**

![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=flat-square&logo=argo&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white)
![KEDA](https://img.shields.io/badge/KEDA-326CE5?style=flat-square&logoColor=white)

**Service Mesh & Networking**

![Istio](https://img.shields.io/badge/Istio-466BB0?style=flat-square&logo=istio&logoColor=white)
![Linkerd](https://img.shields.io/badge/Linkerd-2BEDA7?style=flat-square&logo=linkerd&logoColor=white)
![Envoy](https://img.shields.io/badge/Envoy-AC6199?style=flat-square&logoColor=white)

**Observability**

![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat-square&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?style=flat-square&logo=grafana&logoColor=white)
![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-000000?style=flat-square&logo=opentelemetry&logoColor=white)

**Messaging & Database**

![Kafka](https://img.shields.io/badge/Apache_Kafka-231F20?style=flat-square&logo=apachekafka&logoColor=white)
![RabbitMQ](https://img.shields.io/badge/RabbitMQ-FF6600?style=flat-square&logo=rabbitmq&logoColor=white)
![NATS](https://img.shields.io/badge/NATS-27AAE1?style=flat-square&logo=natsdotio&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-DC382D?style=flat-square&logo=redis&logoColor=white)

**AI/ML**

![Kubeflow](https://img.shields.io/badge/Kubeflow-2196F3?style=flat-square&logoColor=white)
![MLflow](https://img.shields.io/badge/MLflow-0194E2?style=flat-square&logo=mlflow&logoColor=white)
![LangChain](https://img.shields.io/badge/LangChain-1C3C3C?style=flat-square&logo=langchain&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)

</div>

---

## 🎯 Design Philosophy

[Anthropic의 Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)를 따라 설계했습니다:

### Progressive Disclosure

```
세션 시작 → AGENTS.md + 상시 rule
         → 켠 plugin 의 skill 이름과 description 목록
         → 요청과 맞는 skill 본문만 로드
```

매 세션 전체를 읽는 대신, **필요한 순간에 필요한 지식만** 로드합니다.

### Token Efficiency

| Rule | Description |
|------|-------------|
| 파일 크기 확인 | `wc -l` 사용 (전체 Read 금지) |
| Agent 위임 | 대상 파일 미리 읽지 않기 (경로만 전달) |
| Write 검증 | `wc -l` + `head`/`tail` (전체 Read-back 금지) |
| 동일 파일 | 2회 이상 읽기 금지 (1회 Read + Edit 패턴) |

### 설계 원칙

- **영역별 plugin** - 켠 영역만 목록 예산을 쓴다
- **Description 규칙** - `무엇. Use when 상황.` 을 게이트가 강제한다
- **Multi-Agent Architecture** - 전문화된 에이전트가 협력
- **실행 강제** - `git push`, 변경형 `kubectl` 을 산문이 아니라 `deny`/`ask` 규칙으로 막는다

> *"For each line, ask: 'Would removing this cause Claude to make mistakes?'"*

---

## 📁 Structure

```
ress-claude-agents/
├── AGENTS.md                 # 보편 룰 (CLAUDE.md 는 이 파일의 symlink)
├── .claude-plugin/
│   └── marketplace.json      # marketplace: ress
├── plugins/<plugin>/
│   ├── .claude-plugin/plugin.json
│   ├── skills/<name>/SKILL.md  # 한 단계 디렉터리 + SKILL.md 만 로드된다
│   ├── agents/
│   ├── commands/
│   └── README.md             # frontmatter 에서 자동 생성
├── .claude/
│   ├── rules/<그룹>/         # 자동 로딩 룰 (paths: frontmatter 로 조건부 로딩)
│   ├── templates/            # SKILL-SPEC / AGENT-SPEC / 문서 템플릿
│   ├── settings.json         # permissions deny/ask, dx·devlog 활성화
│   ├── agent-handoff.yml     # agent 산출물 어휘
│   ├── inventory.yml         # 자산 인덱스 (자동 생성)
│   └── standards.yml
├── .cursor/rules/            # Cursor view (adapter 산출물, 직접 편집 금지)
├── control-plane/            # probe / match / init / lint / adapter (TypeScript)
├── scripts/                  # validator + generator
├── docs/                     # adr / audit / migration / dev-logs / architecture / guides
├── project-templates/        # Go, Java, K8s, Terraform
└── global/CLAUDE.md
```

> **개수는 여기 쓰지 않는다** — 산문에 박힌 숫자는 CI 가 검사하지 않아 반드시 어긋난다.
> 현재 수치: `yq '.summary' .claude/inventory.yml`

---

## 🧪 Development

```bash
make validate             # 자산 목록, plugin 구성, 참조
make validate-enforcement # settings.json ↔ user-approval.md 규칙 드리프트
make validate-links       # 내부 링크 유효성
make test-gates           # 게이트 음성 테스트
make inventory            # .claude/inventory.yml 재생성
make plugin-readmes       # plugins/*/README.md 재생성
make lint                 # ShellCheck 정적 분석
make all                  # validate + enforcement + links
make setup-hooks          # Pre-commit hook 설치

make verify-plugins       # 실제 로드 확인 (claude CLI 필요, 모델 호출 없음)
make verify-enforcement   # 규칙이 실제로 발동하는지 (claude CLI 필요, 로컬 전용)
```

---

## 🔗 Related Resources

### Awesome Claude Code
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) - Skills, hooks, slash-commands 모음
- [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) - 100+ subagents 컬렉션
- [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills) - Skills 및 도구 모음
- [anthropics/skills](https://github.com/anthropics/skills) - Anthropic 공식 Skills

### Official Documentation
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices) - Anthropic 공식 가이드
- [Claude Code Docs](https://code.claude.com/docs) - Skills, Plugins, MCP
- [Agent Skills Standard](https://agentskills.io/) - Skills 표준

---

## 🤝 Contributing

AI-augmented development에 관심이 있다면 이슈나 PR 환영합니다. 작성 표준: [SKILL-SPEC](.claude/templates/SKILL-SPEC.md), [AGENT-SPEC](.claude/templates/AGENT-SPEC.md).

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/ress-claude-agents.git

# Create branch
git checkout -b feature/your-feature

# Run tests before commit
make all
```

---

## 📜 License

MIT

---

<div align="center">

**Built with Claude Code**

*AI를 도구가 아닌 동료로*

[![GitHub Stars](https://img.shields.io/github/stars/ressKim-io/ress-claude-agents?style=for-the-badge&color=yellow)](https://github.com/ressKim-io/ress-claude-agents)

</div>
