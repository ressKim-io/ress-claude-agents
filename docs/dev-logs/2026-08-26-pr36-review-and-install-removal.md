---
date: 2026-08-26
category: decision
tier: 2
importance: critical
status: resolved
tags: [review, install, plugins, workflows, enforcement, parser, links, ci]
related:
  - adr/0011-remove-install-sh.md
  - adr/0010-drop-codex-support.md
  - dev-logs/2026-08-25-step6-enforcement-layer.md
  - audit/2026-08-24-agent-harness-readiness.md
---

# PR #36 리뷰 대응 → install 계열 제거

## 요약

`/code-review` 가 PR #36 에 15건을 냈다. 고위험 8건을 직접 재현했고 **7건은 정확, 1건은 과장**이었다. 대응 중 리뷰가 놓친 16번째를 발견했고, 그것이 **install.sh 계열 전체 제거**로 이어졌다.

## 리뷰 검증 — 액면 그대로 받지 않았다

| # | 지적 | 검증 |
|---|---|---|
| 링크 79건 깨짐 | Step 2 의 skill 이관이 상호 참조를 안 고침 | ✅ 재현 (AGENTS.md 4건 포함) |
| `adapter --tool=claude` 가 죽은 경로 생성 | 이 PR 이 "로드 불가" 로 판정한 2단계 경로 | ✅ 재현 + gitignore 해제 확인 |
| phantom 카테고리 | 파서 4벌 중 2벌에 early-exit 누락 | ✅ 24종 vs 22종 |
| `--workflow` 가 범위 게이트 무시 | | ✅ 71 vs 0 |
| 검증기 2종 false green | | ✅ 재현 |
| `--mode=diff` 가 CLI 에 없음 | | ✅ `unknown adapter flag` |
| `set -e` 로 런타임 검증기 중단 | "deny 프로브마다 터진다" | ⚠️ **과장**. 실측상 `claude -p` 는 deny·max-turns 소진에도 exit 0 이다. 셸 취약점은 실재하나 트리거가 다름 (네트워크·인증 실패) |

**과장 1건을 그대로 relay 하지 않은 것이 중요하다.** 서브에이전트 결과도 검증 대상이다.

## 16번째 — 리뷰가 놓친 것

파서를 공유 라이브러리로 빼면서 12개 plugin 전부를 `yq` 결과와 대조했다. 2개가 어긋났다:

```
compliance.yml  lib=[business/audit-log, business/multi-tenancy, legal,
                     observability/logging-compliance, security]
                yq =[legal, security]
```

`resolve_plugin` 이 `individual:` 블록의 항목을 **카테고리로 오인**하고 있었다. 실제 동작:

```
Skill category not found: business/audit-log [plugin:compliance]
```

`compliance` / `ops` 가 선언한 개별 skill 6개가 **도입 이래 설치된 적이 없다.** 아무도 그 경로를 실행하지 않았다는 증거였고, 사용자 판단은 "리뷰가 문제가 아니라 install 이게 필요가 없어, 안 써" 였다.

## 제거 범위

`install.sh`(924줄) / `tests/install.bats` / `mcp-configs/` / `plugins/*.yml` 12 / `.claude/workflows/*.yml` 11 / CI `test`·`install-macos` job / validator 3종의 install 의존 검사 / `migrate-skills-to-skillmd.sh`.

**`plugins/` 와 `.claude/workflows/` 를 함께 지운 근거**: 실측 결과 install.sh 외 런타임 소비자가 0이었다. (`probe.ts` 가 참조하는 건 `.github/workflows/` 이지 `.claude/workflows/` 가 아니다. inventory 도 이 둘을 세지 않는다.) 남기면 검증되지 않는 설정 파일만 남고, **이번 세션에서 세 번 반복된 패턴**을 또 만든다.

## 이번 세션에서 네 번 나온 같은 형태

> **통제가 존재하는데 작동하지 않으면서, 작동하는 것처럼 보였다.**

1. `control-plane` 의 PreToolUse hook — 존재하지 않는 env var 로 배선, 3.5개월 발동 0건
2. `ask` 규칙 11건 — 대화형 `bypassPermissions` 에서 무력. 내가 비대화형 프로브 1건으로 일반화해 문서에 "강제된다" 고 적었다
3. `.codex/` — 3개월 미재생성. drift job 은 있었으나 CI 트리거가 `pull_request` 뿐이라 발화 안 함
4. plugin `individual:` — 선언한 skill 6개가 설치되지 않고 경고만 냄

네 건 다 **테스트나 게이트가 있었는데 그것이 실제 경로를 지나가지 않았다.** 이번에 넣은 대응:

- `scripts/validate-links.sh` + CI — 링크를 보는 job 이 하나도 없었다
- `validate-enforcement.sh` 에 `MIN_RULE_COUNT` — 빈 규칙이 "0건 일치" 로 통과하던 것
- `verify-enforcement-runtime.sh` 에 실행 건수 가드 — 프로브 0건에 "통과" 를 찍던 것
- CI drift job 에 control-plane vitest — 로컬에서만 돌던 테스트
- `scripts/lib/skill-category.sh` — 파서 4벌 → 1벌

## 검증

```
validator 8종 PASS · shellcheck PASS · inventory 최신
control-plane typecheck PASS · vitest 93/93
enforcement 정적 음성 6/6 · 런타임 25/25
CI job: test/install-macos 제거 → docs / inventory / lint / drift 4개
```

## 남은 문제

- **branch protection 갱신 필요.** `Test` 와 `install.sh smoke (macOS bash 3.2)` 가 main 의 required status check 다. job 을 지웠으므로 두 컨텍스트를 목록에서 빼지 않으면 **PR 이 머지 불가로 영구 대기**한다.
- **macOS bash 3.2 회귀 검증 공백.** `install-macos` job 이 그 유일한 방어였다. `scripts/*.sh` 는 여전히 사용자 환경 bash 로 도는데 shellcheck 은 버전 호환을 보지 않는다.
- **루트 `commands/`** (52 파일) 는 install.sh 가 읽던 레이아웃이다. `.claude/commands/` 와 내용이 같고, 지금은 **자기를 검증하는 스크립트 3개만이 소비자**다. 통합 여부는 별도 판단.
- **CI 트리거**는 여전히 `push:[main]` + `pull_request` 다 (ADR 0010 §남은 문제와 동일).
