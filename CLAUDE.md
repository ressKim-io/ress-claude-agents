# CLAUDE.md

> **Claude Code 전용 가이드.** 모든 AI 코딩 도구에 적용되는 보편 룰은 [AGENTS.md](AGENTS.md)에 있다.
> 이 파일은 Claude Code의 자동 로딩 메커니즘과 Claude 전용 최적화 규칙만 담는다.

---

## Auto-Loaded Rules

`.claude/rules/*.md`는 Claude Code 세션 시작 시 자동 로딩된다 (다른 도구는 자동 로드하지 않으므로 핵심은 AGENTS.md에 요약):

| Rule | 역할 | AGENTS.md 대응 |
|---|---|---|
| `clean-code.md` | 코드 가독성 원칙 | Code Style |
| `workflow.md` | EXPLORE→PLAN→IMPLEMENT→VERIFY→COMMIT | Workflow |
| `git.md`, `code-review.md` | git/PR 워크플로우 | Git & Commits, PRs |
| `security.md` | 시크릿/입력검증/인증 | Security |
| `testing.md` | TDD, Given-When-Then, 커버리지 | Testing |
| `debugging.md` | 4단계 프로토콜 | Debugging |
| `monitoring.md` | PromQL/OTel 컨벤션 | Monitoring |
| `documentation.md` | 11종 문서 템플릿 | Documentation |
| `user-approval.md` | 외부 작업 사전 승인 | User Approval |
| `cloud-cli-safety.md` | AWS/GCP 위험 명령 | Cloud CLI Safety |
| `go.md`, `java.md`, `spring.md` | 언어별 룰 | Language-Specific |
| **`token-budget.md`** | **Opus 4.7 전용** (아래 참조) | — |

---

## Token Budget (Opus 4.7 전용)

상세는 매 대화 자동 로딩되는 [.claude/rules/token-budget.md](.claude/rules/token-budget.md). 코드 예시·비용 계산은 `/token-budget` 스킬.

**핵심**:
- Context **80% 초과 → 세션 종료**, 무관 태스크 전환 시 `/clear`
- Effort 기본 `xhigh` (Claude Code 기본값), 단순 조회 `low`, frontier 문제만 `max`
- Tokenizer 4.6 → 4.7 변경: `max_tokens` **35% headroom**, prompt cache 재빌드 가정
- Subagent는 **명시 spawn** (Opus 4.7은 기본적으로 덜 spawn함). 10+ 파일 탐색은 subagent 위임.

---

## Claude-Only Features

| Feature | 위치 | 호출 방법 |
|---|---|---|
| **Skills** | `.claude/skills/` | 자동 발견 (description 매칭) |
| **Subagents** | `.claude/agents/` | `Agent` 도구 (`subagent_type=...`) |
| **Slash Commands** | `.claude/commands/` | `/command-name` |
| **Plugins** | `plugins/*.yml` | `install.sh --plugin <name>` |
| **Workflows** | `.claude/workflows/*.yml` | `install.sh --workflow <name>` |

**현재 자산** (2026-04-19 기준):
- Skills: 216개 (~83K줄), 17 카테고리
- Agents: 46개 (~18K줄)
- Commands: 43개
- Plugins: 10 bundles
- Workflows: 7 scenarios + `_base`

상세 인덱스: [.claude/inventory.yml](.claude/inventory.yml)

---

## Opus 4.7 Behavioral Notes

기존 프롬프트 재조정 포인트:
- **Literal interpretation** — 의도·제약·수락 기준 첫 턴 완전 명세
- **Subagent 명시 spawn** — fan-out 필요 시 "Use subagents to investigate X in parallel"
- **자체 검증 내장** — "double-check before returning" 같은 scaffolding 제거
- **응답 길이 자동 calibration** — 고정 verbosity 지시 재검토
- **Rules 100~150줄이 sweet spot** — 매 대화 자동 로딩이라 길면 묻힘. 상세는 skill로 분리.
