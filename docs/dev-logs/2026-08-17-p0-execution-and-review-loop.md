---
date: 2026-08-17
category: meta
tier: 2
importance: critical
status: resolved
tags: [p0, install-sh, flatten, bash-3-2, ci-coverage, review-pr, agent-safety, drift-validation]
related:
  - dev-logs/2026-08-16-asset-tier-audit-and-kiro-track-resume.md
  - audit/2026-08-15-asset-tier-rebalance.md
  - adr/0008-asset-tier-policy.md
---

# P0 실행 + 첫 /review-pr 루프 — 리뷰가 레포를 손상시킨 사고 포함 (PR #32·#34)

## Context

[2026-08-15 audit](../audit/2026-08-15-asset-tier-rebalance.md) §6 의 **P0**(유일한 🔴 기능 결함 + drift 6건)를 실행하고, 그 결과에 대해 이 레포의 `/review-pr` 커맨드를 **처음으로 규정대로 돌린** 세션이다.

직전 세션([2026-08-16](2026-08-16-asset-tier-audit-and-kiro-track-resume.md))까지는 진단·정책·문서 정합성만 했고 자산 지표는 하나도 안 움직인 상태였다. 이번이 첫 실행이다.

## Issue

### P0 대상 — 설치되는 rule 이 설치되지 않는 command 를 참조

```
devlog-lifecycle.md → /consolidate-devlogs /promote-devlog /archive-devlog /where /related /log-*
phase-workflow.md   → /phase-start /log-trouble /review-pr
code-review.md      → /review-pr
```

`install.sh` 는 root `commands/*/` 만 모듈로 발견하는데 16개가 `.claude/commands/` 최상위 평면 파일로만 존재했다. 사용자가 rule 을 설치하면 "`/consolidate-devlogs` 주 1회 실행" 이라고 읽지만 그 명령이 없다.

### 작업 중 발견 — install.sh 가 macOS 에서 완주 불가

`set -u` + 빈 배열 `${arr[@]}` 확장이 bash 3.2 에서 unbound 오류를 낸다(bash 4.4+ 에서 수정된 동작). HEAD 기준 **어떤 플래그 조합으로도 완주하지 못했다.** CI 가 ubuntu(bash 5.x) 전용이라 3개월간 미검출. 레포 소유자가 darwin 이므로 실사용에 직접 영향.

## Action

### PR #32 — P0 실행

- `commands/{memory,review,workflow}/` 3개 모듈 신설로 16개 설치 가능화
- **flatten 도입** — 하위 디렉토리는 `/memory:where` 로 네임스페이스가 붙어 rule 의 bare 참조가 깨진다. skills 설치가 이미 쓰던 "flatten to root" 패턴을 commands 에도 적용해 `/where` 와 `/memory:where` 를 모두 제공
- macOS bash 3.2 회귀 20곳 교정 + CI `install-macos` job 신설
- `validate-commands-drift.sh` 신설, drift 6건(D1~D6) 수정

### PR #34 — 리뷰 지적 14건 수정

3개 관점 병렬 리뷰 결과 **Critical 1 / Major 6 / Minor 7**. Critical 은 flatten 이 `--local` 의 self-containment 를 깬 것 — `$INSTALL_SCOPE` 를 무시하고 소스 레포 절대경로 symlink 를 만들어, 설치 레포를 옮기면 지키려던 명령 16개가 전부 dangling 이 된다.

Minor 1건(`paths:` 필터)은 **거절**했다. `install-macos` 가 required check 라 필터로 skip 되면 컨텍스트가 보고되지 않아 PR 이 영구 대기한다.

## Result

- P0 완료. 미설치 명령 16 → 0, 산문 자산 개수 drift 제거, macOS installer 복구
- 리뷰 지적 14건 중 13건 수정 + 1건 사유 명시 거절
- `generate-docs.sh` 경고 18 → 0
- CI 6/6 green (신규 macOS job 포함), `install-macos` 를 required check 에 등록

## Learning / Universal Lesson

### 1. 리뷰 에이전트가 레포를 손상시켰다 ★

보안 에이전트가 `backup_and_link` 동작을 **실증하려고 레포 루트에서** `install.sh --local --all --with-skills` 를 실행했다.

```
.claude/skills/     → skills.backup 으로 이동, 260개 파일이 D 상태
.claude/commands/*/ → 7개 모듈이 *.backup 으로 밀리고 install 사본으로 대체
.claude/CLAUDE.md   → 생성
```

`.gitignore` 의 `*.backup` 때문에 **`git status` 에 잡히지 않았다.** 스킬 목록에 `go.backup:lint` 가 뜨는 걸 보고 발견했다.

지시 설계 잘못이다. 프롬프트에 "심볼릭 링크 덮어쓰기 위험을 검증하라" 고 써놓고 **격리 제약을 안 걸었다.** 나 자신도 앞서 같은 실수를 했는데(그때 `session.backup` 발생) 에이전트 프롬프트에 반영하지 않았다.

→ **파괴적 동작의 검증을 지시할 때는 격리 환경을 함께 지정한다.** `/review-pr` 에 MANDATORY 가드로 박았다 (`mktemp -d` 요구 + 레포 루트 설치 명령 금지). 일반화 가능: **Yes**.

### 2. 증상 재현과 원인 지목은 별개다 ★

CR-002(검증기가 첫 불일치에서 죽어 3/4 검사 스킵)를 리뷰는 `diff | sed` 의 pipefail 로 진단했다. 나는 증상을 재현해 "✅ 재현 확인" 을 붙여 게시했다. **증상은 실재했지만 원인은 틀렸다** — `|| true` 를 넣어도 그대로였고, 실제 원인은 각 함수 말미의 `[[ x -eq 0 ]] && log_pass` 가 함수 반환값을 1로 만들어 `set -e` 가 죽인 것이었다.

→ **재현했다는 것은 증상의 존재만 입증한다.** 수정 후 증상이 사라지는 것까지 확인해야 원인 지목이 검증된다. `debugging.md` 의 "증상 아닌 원인" 을 리뷰 검증에도 적용해야 한다.

### 3. 검증기는 반드시 역테스트한다

`validate-commands-drift.sh` 를 만들고 3개 시나리오로 역테스트해 실제 FAIL 을 확인했다. 그런데도 CR-002·003 두 결함이 남아 있었다 — 역테스트가 **단일 drift** 만 넣었기 때문에 "첫 건에서 죽는" 문제가 안 드러났고, `/where` 같은 하이픈 없는 이름을 테스트 케이스에 안 넣었다.

→ 역테스트는 **복수 동시 위반**과 **경계 입력**(하이픈 없는 이름, 빈 배열)을 포함해야 한다. 통과하는 검증기보다 **잡아야 할 것을 실제로 잡는** 검증기가 목표다.

### 4. CI 가 안 도는 플랫폼의 버그는 영원히 안 잡힌다

install.sh 가 macOS 에서 3개월간 완전히 고장나 있었는데 CI 는 ubuntu 전용이라 green 이었다. `shellcheck` 도 이 계열을 잡지 못한다.

→ **사용자가 실제로 쓰는 플랫폼을 CI 에 포함**한다. 다만 required check 로 등록하면 `paths:` 필터를 걸 수 없다(skip 시 컨텍스트 미보고 → PR 영구 대기). 비용과 게이트 강도는 트레이드오프이며, 이번엔 게이트를 택하고 사유를 `ci.yml` 에 남겼다.

### 5. 도구가 만든 실패를 도구 탓으로 오인할 뻔했다

스모크 테스트가 6/8 실패로 나와 회귀를 의심했다. 원인은 **이 셸이 zsh** 라 `$args` 무인용 확장이 단어 분리되지 않아 `install.sh` 가 `"--local --modules go"` 를 한 덩어리로 받은 것이었다. `"$@"` 로 고치니 8/8 통과.

→ 테스트가 실패하면 **테스트 하네스 자체를 먼저 의심**한다. 특히 zsh ↔ bash 의 word splitting 차이는 이 레포처럼 셸 스크립트를 다루는 곳에서 반복될 함정이다.

### 6. 원칙을 세운 그 표에서 원칙을 어겼다

"산문에 개수 쓰지 않는다" 를 Skills 행에만 적용하고 같은 표의 Rules 행은 그대로 뒀는데, 그 "25개" 가 직전 PR 에서 rule 을 추가하면서 이미 26 이 돼 있었다. 리뷰가 잡았다.

→ 원칙을 도입할 때는 **같은 파일·같은 표의 동종 항목을 전수 적용**한다. 부분 적용은 원칙이 지켜지지 않는다는 증거를 남긴다.

## 후속 작업

- **P1** description 224개 재작성 (다음). `assets/skills/` 15개가 SKILL-SPEC 형식 레퍼런스
- P2 skill 티어 재배치 / P3 agent 분할 3축 / P4 Migration 0002 재평가
- B2 (PR-5~8) / B3 — audit §8 참조. PR-8 ↔ P0 의 install.sh 충돌은 P0 선행으로 해소됨

## 관련 자료

- PR [#32](https://github.com/ressKim-io/ress-claude-agents/pull/32) (P0) / [#34](https://github.com/ressKim-io/ress-claude-agents/pull/34) (리뷰 수정)
- [리뷰 코멘트](https://github.com/ressKim-io/ress-claude-agents/pull/32#issuecomment-5307107035) — CR-001~014
- [audit §6 P0](../audit/2026-08-15-asset-tier-rebalance.md#6-실행-순서)
- `.claude/commands/review-pr.md` §에이전트 실행 안전 규칙 — 학습 1의 산물
