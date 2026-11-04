<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# dx

개발 공통 — 코드 리뷰, Git·PR 워크플로우, ADR·문서 템플릿, dev-log, 온보딩, 토큰 운영

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

- [`platform`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/platform/README.md)
- [`java`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/java/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`ai`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/ai/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`go`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/go/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`python`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/python/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`security`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/security/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`core/workflow.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/workflow.md)
- [`core/git.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/git.md)
- [`core/security.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/security.md)
- [`process/code-review.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/code-review.md)
- [`process/debugging.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/debugging.md)
- [`process/testing.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/testing.md)
- [`process/documentation.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/documentation.md)
- [`process/devlog-lifecycle.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/devlog-lifecycle.md)
- [`process/phase-workflow.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/phase-workflow.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (24)

| 이름 | 설명 |
|---|---|
| `/dx:adr-retrospective` | ADR 사후 검토 패턴 — 6/12개월 재평가, Superseded 트리거 결정, 예측 vs 실측 검증, decision log 누적 분석. dx/rfc-adr (작성)의 짝, "이 결정이 … |
| `/dx:clean-code` | Clean Code 실전 가이드. Composed Method, Cognitive Complexity, Guard Clause, 네이밍, 주석 철학, Tell Don't Ask 패턴을 언어별 … |
| `/dx:conventional-commits` | Conventional Commits — 커밋 메시지 규칙 및 자동화 패턴 |
| `/dx:docs-as-code` | Docs as Code 가이드 — MkDocs, Docusaurus, Backstage TechDocs, API 문서 자동화 |
| `/dx:docs-as-code-automation` | Docs as Code 자동화 가이드 — API 문서 자동화 (OpenAPI), 문서 품질 측정, Vale 린터 |
| `/dx:documentation-templates` | 프로젝트 문서 템플릿 모음 — ADR, 부하테스트, 포스트모템, 마이그레이션, CI/CD, SLI/SLO 등 14종 |
| `/dx:dx-metrics` | Developer Experience Metrics 가이드 — DORA, SPACE, DevEx, DX Core 4 프레임워크를 활용한 개발자 생산성 측정 |
| `/dx:dx-onboarding` | Developer Onboarding 자동화 가이드 — 개발자 온보딩 자동화, Time-to-First-Deploy 최적화, 셀프서비스 환경 구축 |
| `/dx:dx-onboarding-deploy` | Developer Onboarding: 첫 배포 가이드 — Day 1 Deploy 실현을 위한 첫 과제 템플릿, 안전장치, AI 어시스트 |
| `/dx:dx-onboarding-environment` | Developer Onboarding: 개발 환경 자동화 — Dev Container를 활용한 개발 환경 자동화 |
| `/dx:dx-onboarding-gitpod` | Developer Onboarding: Gitpod & 셀프서비스 포털 — Gitpod 설정, Backstage 온보딩 템플릿, TechDocs 자동화 |
| `/dx:engineering-strategy` | Engineering Strategy 가이드 — 기술 전략 수립: Tech Radar, Build vs Buy, OKR, 로드맵, 기술 부채 관리 |
| `/dx:git-workflow` | Git Workflow Patterns — Git 워크플로우 패턴 및 best practices |
| `/dx:local-dev-makefile` | Local Dev with Makefile: make up으로 풀스택 실행 — Docker를 몰라도 `make up` 하나로 프론트+백엔드+DB가 로컬에서 실행되는 환경 구축 가이드 |
| `/dx:negative-path-coverage` | Happy path bias로 인한 운영 사고 방지. 에러 경로/장애 시나리오/리소스 한계/타이밍 race를 명시적으로 테스트 케이스화하는 체크리스트. Wikipedia "Happy path" + … |
| `/dx:pr-review-automation` | AI PR 자동 리뷰 도입 — GitHub Copilot Code Review / CodeRabbit / Claude Code Action / Claude Security Review / Qodo … |
| `/dx:product-thinking` | Product Thinking 가이드 — RICE, MoSCoW, Shape Up, JTBD, Story Mapping 기반 프로덕트 사고 |
| `/dx:quarterly-review` | 분기 엔지니어링 회고 패턴 — DORA 4 metrics 추이, SLI/SLO 달성률, 인시던트 패턴, ADR hit rate, FinOps 추이, MRR cohort. … |
| `/dx:refactoring-principles` | Refactoring Principles — 리팩토링 기본 원칙, 코드 스멜 식별, 점진적 개선 전략 |
| `/dx:rfc-adr` | RFC/ADR 워크플로우 — RFC(Request for Comments)와 ADR(Architecture Decision Record) 작성, 리뷰, 관리 프로세스 가이드 |
| `/dx:spec-driven-development` | Spec-Driven Development with Claude Code — Claude Code에서 명세 기반 개발 워크플로우. Research → Spec → Plan → Execute → … |
| `/dx:team-topologies` | Team Topologies 가이드 — Team Topologies, Conway's Law, 팀 구조 설계, 인터랙션 모드 |
| `/dx:token-budget` | Claude 5.5 세대 토큰·컨텍스트·effort 운영 심화 가이드 — Subagent 위임, Effort, Task Budget, Prompt Caching, Thinking, … |
| `/dx:token-efficiency` | Token & Context Efficiency — Claude Code 세션에서 토큰 낭비를 줄이고 컨텍스트 윈도우를 효율적으로 사용하는 패턴 |

## Agents (6)

| 이름 | 설명 |
|---|---|
| `dx:code-reviewer` | Cross-language 시니어 코드 리뷰어 — correctness, readability, 명명, 중복, 테스트 커버리지, 일반 best practice |
| `dx:dev-logger` | 개발 과정 기록 에이전트. AI 수정 요청(feedback), 아키텍처 결정(decision), 시스템 개선(meta), 트러블슈팅(trouble) 기록을 구조화된 마크다운으로 저장 |
| `dx:git-workflow` | Git 워크플로우 자동화 에이전트. 커밋 메시지 생성, PR 자동화, Changelog 생성, 브랜치 전략 가이드 |
| `dx:product-engineer` | 요구사항 분석, 유저스토리 작성, 우선순위 결정, MVP 스코핑 에이전트. 비즈니스 목표와 기술 구현 사이의 번역자 |
| `dx:security-scanner` | AI-powered security vulnerability scanner |
| `dx:tech-lead` | 기술 전략 수립, RFC/ADR 주도, 팀 오케스트레이션 에이전트. Claude Code Team의 리더 역할 |

## Commands (26)

| 이름 | 설명 |
|---|---|
| `/dx:archive-devlog` | Tier 4 dev-log를 _archive/ 로 이동, replaced_by 링크 보존. superseded 처리 |
| `/dx:backend-api-doc` | OpenAPI/Swagger 어노테이션을 추가합니다 |
| `/dx:backend-refactor` | 코드 품질 개선을 위한 리팩토링을 제안합니다 |
| `/dx:backend-review` | Java/Kotlin 백엔드 코드를 리뷰합니다 |
| `/dx:backend-test-gen` | JUnit 테스트 코드를 생성합니다 |
| `/dx:changelog` | 커밋 히스토리 기반으로 CHANGELOG를 생성합니다 |
| `/dx:consolidate-devlogs` | docs/dev-logs/*.md tier 자동 산출, 클러스터 발견, superseded 식별. dry-run 기본, 사용자 승인 후 적용 |
| `/dx:consolidate-memory` | MEMORY.md + memory/*.md 정리. stale/duplicate/orphan/repo-card 이관 후보 분류. dry-run 기본, 사용자 승인 후 적용 |
| `/dx:issue-create` | 템플릿 기반으로 Issue를 생성합니다 |
| `/dx:log-decision` | 기술/아키텍처 의사결정을 기록합니다. A vs B 선택, 트레이드오프, 근거 등 |
| `/dx:log-feedback` | AI 출력 수정 요청을 기록합니다. 코드 패턴 불일치, 누락, 잘못된 접근 등을 기록 |
| `/dx:log-meta` | Rule, Skill, Agent 추가/변경 사유를 기록합니다. AI 워크플로우 자체의 개선 기록 |
| `/dx:log-summary` | 현재 세션의 주요 활동을 자동 요약합니다. 세션 종료 전에 실행 권장 |
| `/dx:log-trouble` | 트러블슈팅 과정을 기록합니다. 에러 원인 분석, 해결 과정, 회귀 테스트 |
| `/dx:phase-start` | Phase 기반 작업(SDD 게이트 강제) 시작. 11항목 체크리스트 출력 + Gate 1-5 흐름 안내 |
| `/dx:pr-create` | 커밋 기반으로 PR을 자동 생성합니다 |
| `/dx:promote-devlog` | Tier 2 dev-log를 ADR/skill로 승격 (Episodic → Semantic). 패턴 정착 시 사용 |
| `/dx:related` | 개념/주제로 dev-logs + ADR + memory + repo-cards를 timeline 순으로 묶어 반환. 컨텍스트 복원용 |
| `/dx:release` | 버전 태그 및 GitHub Release를 생성합니다 |
| `/dx:review-pr-k8s` | K8s/Helm/ArgoCD 영역 PR을 3개 전문 관점으로 병렬 리뷰합니다 |
| `/dx:review-pr-monitoring` | 모니터링 영역 PR을 3개 전문 관점으로 병렬 리뷰합니다 |
| `/dx:review-pr-terraform` | Terraform PR을 3개 전문 관점으로 병렬 리뷰합니다 |
| `/dx:review-pr` | PR 코드 리뷰를 3개 관점의 에이전트로 병렬 실행해 종합합니다 |
| `/dx:session-end` | 세션을 종료하고 컨텍스트 파일을 정리합니다 |
| `/dx:session-save` | 현재 세션 컨텍스트를 저장합니다 |
| `/dx:where` | 키워드로 INDEX.md + repo-cards + MEMORY + dev-logs 횡단 검색. '어디에 있지?' 질문에 1분 안에 답 |
