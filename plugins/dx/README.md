<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# dx

개발 공통 — 코드 리뷰, Git·PR 워크플로우, ADR·문서 템플릿, 온보딩, 토큰 운영

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install dx@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/dx/skills/<이름> <프로젝트>/.claude/skills/
```

## 필요한 plugin

`/dx:review-pr-terraform` 은 `infra` 의 `terraform-reviewer` 와 `sre` 의 `cost-analyzer` 를 호출한다. 이 명령을 쓰려면 두 plugin 도 설치한다.

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`ai`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/ai/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`platform`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/platform/README.md)
- [`java`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/java/README.md)
- [`security`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/security/README.md)
- [`go`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/go/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`python`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/python/README.md)
- [`devlog`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/devlog/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`core/workflow.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/workflow.md)
- [`core/git.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/git.md)
- [`core/security.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/security.md)
- [`process/code-review.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/code-review.md)
- [`process/debugging.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/debugging.md)
- [`process/testing.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/testing.md)
- [`process/documentation.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/documentation.md)
- [`process/phase-workflow.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/phase-workflow.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (26)

| 이름 | 설명 |
|---|---|
| `/dx:adr-retrospective` | Accepted ADR 사후 검토 — 6/12개월 재평가 트리거, 예측 vs 실측 비교, Superseded·Deprecated 판단, decision log 누적 분석 |
| `/dx:agent-autonomy-tiers` | 에이전트 행동을 조사·제안·승인 후 실행·열거된 자동 실행 단계로 나누고 단계마다 승격 조건과 실제로 막는 강제 수단을 짝짓는다 |
| `/dx:claude-unattended-ops` | Claude Code를 사람 없이 돌릴 때 실행 경로, 권한 배치, MCP 로딩, 실패한 run 판정을 정한다 |
| `/dx:clean-code` | Clean Code 실전 — Composed Method, Cognitive Complexity, Guard Clause, 네이밍, WHY 주석, Tell Don't Ask 를 BAD/GOOD … |
| `/dx:conventional-commits` | Conventional Commits — type·scope 규칙, 커밋 메시지 포맷, commitlint·semantic-release 자동화, Go 프로젝트 설정, PR 전략 |
| `/dx:docs-as-code` | Docs as Code 사이트 구축 — MkDocs Material, Docusaurus, Backstage TechDocs, Mermaid 다이어그램, 문서 CI |
| `/dx:docs-as-code-automation` | 문서 자동화 — OpenAPI 기반 API 문서 생성, 문서 품질 측정, Vale 린터 |
| `/dx:documentation-templates` | 프로젝트 문서 템플릿 — ADR, 프로젝트 개요서, 부하테스트, 포스트모템, 마이그레이션, CI/CD, SLI/SLO 등 |
| `/dx:dx-metrics` | 개발자 생산성 측정 — DORA, SPACE, DevEx, DX Core 4 프레임워크 비교와 메트릭 수집 구조 |
| `/dx:dx-onboarding` | 개발자 온보딩 자동화 전체 개요 — Time-to-First-Deploy 등 온보딩 메트릭 수집, 안티패턴, 체크리스트 |
| `/dx:dx-onboarding-deploy` | 신규 개발자 첫 배포 — 첫 과제 템플릿, 안전장치, AI 어시스트 온보딩, Grafana 대시보드 |
| `/dx:dx-onboarding-environment` | 개발 환경 자동화 — Dev Container 설정(devcontainer.json)과 셋업 스크립트 |
| `/dx:dx-onboarding-gitpod` | 클라우드 개발 환경·셀프서비스 포털 — Gitpod 설정, Backstage 온보딩 템플릿, TechDocs 문서 자동화 |
| `/dx:engineering-strategy` | 기술 전략 수립 — Tech Radar, Build vs Buy 분석, Engineering OKR, Strategy Doc, Now/Next/Later 로드맵, 기술 부채 관리 |
| `/dx:git-workflow` | Git 워크플로우 — 브랜치 네이밍, 커밋 가이드라인, PR 템플릿(Summary·Test Plan), 유용한 git 명령, 안티패턴 |
| `/dx:local-dev-makefile` | Makefile 로컬 개발 — make up 한 번으로 프론트·백엔드·DB 실행, self-documenting Makefile, docker-compose, Dockerfile.dev, hot … |
| `/dx:negative-path-coverage` | Happy path bias 방지 — 에러 경로·장애 시나리오·리소스 한계·타이밍 race 를 테스트 케이스로 만드는 체크리스트와 에러 경로 카탈로그 |
| `/dx:pr-review-automation` | AI PR 자동 리뷰 도입 — GitHub Copilot Code Review / CodeRabbit / Claude Code Action / Claude Security Review / Qodo … |
| `/dx:product-thinking` | 프로덕트 사고 프레임워크 — RICE 스코어링, MoSCoW, Shape Up, JTBD, Story Mapping, MVP 정의, A/B 테스트 기초 |
| `/dx:quarterly-review` | 분기 엔지니어링 회고 — DORA 4 metrics 추이, SLO 달성률, 인시던트 패턴, ADR hit rate, FinOps·MRR cohort, 회고 미팅 진행, 1페이지 보고서 |
| `/dx:refactoring-principles` | 리팩토링 기본 — 황금률, 코드 스멜 카탈로그, SOLID 적용, 점진적 리팩토링, 테스트 주도 리팩토링, 우선순위 |
| `/dx:rfc-adr` | RFC·ADR 작성 워크플로우 — RFC vs ADR 비교, Google Design Doc·Uber 스타일 RFC 템플릿, 리뷰·관리 프로세스 |
| `/dx:spec-driven-development` | 명세 기반 개발 — Research → Spec → Plan → Execute → Review 흐름, SPEC.md 작성(Problem·Solution·Non-Goals·Success … |
| `/dx:team-topologies` | Team Topologies — 4가지 팀 유형, 3가지 인터랙션 모드, Conway's Law, 인지 부하, Team API, 팀 구조 진화 |
| `/dx:token-budget` | Claude 5.5 세대 토큰·컨텍스트·effort 운영 심화 가이드 — Subagent 위임, Effort, Task Budget, Prompt Caching, Thinking, … |
| `/dx:token-efficiency` | Claude Code 토큰 절약 — 컨텍스트 윈도우 관리, 파일 읽기·쓰기·검색 최적화, Agent 위임, 프롬프트 효율, 세션 관리 |

## Agents (5)

| 이름 | 설명 |
|---|---|
| `dx:code-reviewer` | Cross-language 시니어 코드 리뷰어 — correctness, readability, 명명, 중복, 테스트 커버리지, 일반 best practice |
| `dx:git-workflow` | Git 워크플로우 자동화 에이전트. 커밋 메시지 생성, PR 자동화, Changelog 생성, 브랜치 전략 가이드 |
| `dx:product-engineer` | 요구사항 분석, 유저스토리 작성, 우선순위 결정, MVP 스코핑 에이전트. 비즈니스 목표와 기술 구현 사이의 번역자 |
| `dx:security-scanner` | AI-powered security vulnerability scanner |
| `dx:tech-lead` | 기술 전략 수립, RFC/ADR 주도, 팀 오케스트레이션 에이전트. Claude Code Team의 리더 역할 |

## Commands (18)

| 이름 | 설명 |
|---|---|
| `/dx:backend-api-doc` | OpenAPI/Swagger 어노테이션을 추가합니다 |
| `/dx:backend-refactor` | 코드 품질 개선을 위한 리팩토링을 제안합니다 |
| `/dx:backend-review` | Java/Kotlin 백엔드 코드를 리뷰합니다 |
| `/dx:backend-test-gen` | JUnit 테스트 코드를 생성합니다 |
| `/dx:changelog` | 커밋 히스토리 기반으로 CHANGELOG를 생성합니다 |
| `/dx:consolidate-memory` | MEMORY.md + memory/*.md 정리. stale/duplicate/orphan/repo-card 이관 후보 분류. dry-run 기본, 사용자 승인 후 적용 |
| `/dx:issue-create` | 템플릿 기반으로 Issue를 생성합니다 |
| `/dx:phase-start` | Phase 기반 작업(SDD 게이트 강제) 시작. 11항목 체크리스트 출력 + Gate 1-5 흐름 안내 |
| `/dx:pr-create` | 커밋 기반으로 PR을 자동 생성합니다 |
| `/dx:related` | 개념/주제로 dev-logs + ADR + memory + repo-cards를 timeline 순으로 묶어 반환. 컨텍스트 복원용 |
| `/dx:release` | 버전 태그 및 GitHub Release를 생성합니다 |
| `/dx:review-pr-k8s` | K8s/Helm/ArgoCD 영역 PR을 3개 전문 관점으로 병렬 리뷰합니다 |
| `/dx:review-pr-monitoring` | 모니터링 영역 PR을 3개 전문 관점으로 병렬 리뷰합니다 |
| `/dx:review-pr-terraform` | Terraform PR을 3개 전문 관점으로 병렬 리뷰합니다 |
| `/dx:review-pr` | PR 코드 리뷰를 3개 관점의 에이전트로 병렬 실행해 종합합니다 |
| `/dx:session-end` | 세션을 종료하고 컨텍스트 파일을 정리합니다 |
| `/dx:session-save` | 현재 세션 컨텍스트를 저장합니다 |
| `/dx:where` | 키워드로 INDEX.md + repo-cards + MEMORY + dev-logs 횡단 검색. '어디에 있지?' 질문에 1분 안에 답 |
