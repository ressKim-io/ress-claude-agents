---
date: 2026-11-12
category: meta
tier: 2
importance: major
status: resolved
tags: [devlog, plugins, user-scope, frontmatter, rules]
related:
  - adr/0014-devlog-plugin.md
  - adr/0012-native-plugin-structure.md
---

# dev-log 자산을 `devlog` plugin 으로 분리하고 user scope 로 켰다

## Context

사용자가 dev-log 명령과 규칙을 모든 레포에서 쓰고 싶다고 했다. 기록 위치는 각 레포의 `docs/dev-logs/` 로 정했다. 확인해 보니 dev-log 자산은 `dx` 에 있었고, `dx` 는 이 레포의 `.claude/settings.json` 에서만 켜져 있었다. 레포 밖 디렉토리에서 `claude plugin list` 를 돌리면 `dx@ress ✘ disabled` 로 나왔다.

## Issue

- `dx` 를 user scope 로 통째로 켜면 dev-log 와 무관한 dx 자산까지 모든 레포에 실린다. `skillOverrides` 는 plugin skill 에 적용되지 않아서 일부만 끌 수 없다 (✅ 2026-11-12 공식 docs, [ADR 0014](../adr/0014-devlog-plugin.md) Context)
- dev-log frontmatter 가 세 곳에서 달랐다
  - `devlog-lifecycle.md` 는 `tier/importance/status` 가 필수다
  - `log-*` 명령에는 이 필드가 없고 `project` 가 있었다
  - `dev-logger` 의 두 템플릿은 `trouble` 과 `troubleshoot` 를 섞어 썼다
  - `log-feedback` 은 산출물 category 를 `meta` 로 적고 있었다
- `devlog-lifecycle.md` 의 "작성 시점 트리거" 는 `paths:` rule 안에 있다. 그래서 dev-log 파일을 열기 전에는 로드되지 않는다

## Action

- 커밋 1: frontmatter 를 rule 표준 하나로 맞추고 `feedback` category 를 표준에 더했다
- 커밋 2: 아래를 `plugins/devlog/` 로 옮겼다. `/dx:` 참조는 `/devlog:` 로 바꿨다. 이력 문서는 그대로 뒀다
  - 명령 8개: `log-*` 5개, `consolidate-devlogs`, `promote-devlog`, `archive-devlog`
  - agent: `dev-logger`
- 커밋 3: [ADR 0014](../adr/0014-devlog-plugin.md) 를 쓰고, ADR 0012 Status 에 §Decision 2 가 바뀐 것을 적었다
- 레포 밖 개인 설정 (git 미추적)
  - `claude plugin install devlog@ress --scope user` 로 설치했다
  - `~/.claude/rules/devlog-trigger.md` 를 만들었다. `paths` 없는 짧은 rule 이고, 조건이 맞으면 묻지 않고 `docs/dev-logs/` 에 쓰게 한다
  - 바꾸기 전 설정은 `~/.claude/backups/devlog-global-20261112/` 에 백업했다

## Result

- 로컬 게이트를 전부 통과했다: `validate-catalog`, inventory, README, rules-drift, `test-gates` 등. Cursor adapter 의 drift 도 0건이다
- `verify-plugins.sh devlog dx` 결과
  - devlog: skill+command 8/8, agent 1/1
  - dx: skill+command 44/44, agent 5/5
- 레포 밖 디렉토리에서 `devlog@ress ✔ enabled`, `dx@ress ✘ disabled` 를 확인했다
- 미확인 ⚠️: 자동 작성 트리거가 실제로 동작하는지. 이 rule 은 새 세션부터 로드돼서 이 세션에서는 확인할 수 없다. 다음 세션에서 다른 레포로 확인한다
- 주의: `ress` marketplace 는 작업 트리에서 plugin 을 읽는다. 머지 전에 `main` 을 checkout 하면 그동안은 전역 devlog 가 로드되지 않는다

## Related Files

- `plugins/devlog/` — 새 plugin
- `.claude/rules/process/devlog-lifecycle.md` — frontmatter 표준. `feedback` category 를 추가했다
- `docs/adr/0014-devlog-plugin.md` — 결정과 대안 비교
