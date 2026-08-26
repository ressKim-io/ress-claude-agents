---
date: 2026-08-24
category: meta
tier: 2
importance: major
status: resolved
tags: [harness-engineering, agent-spec, effort-field, skill-format, spec-verification, step1]
related:
  - audit/2026-08-24-agent-harness-readiness.md
  - dev-logs/2026-08-24-harness-engineering-audit.md
  - adr/0006-kiro-adapter-strategy.md
---

# Step 1 — spec 최신화: `effort` 사실 오류 정정 + frontmatter 16필드 반영

## Context

[2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) §6 **Step 1**(사실 최신화) 실행. 자산 변경 없이 **spec / rule 문서만** 현행 공식 사양에 맞춘다.

직전 세션([측정 audit](2026-08-24-harness-engineering-audit.md))에서 확정한 F3(effort 필드 사실 오류)과 F1(skill 경로 규격 위반)을 문서 계층에 반영하는 단계다. 실제 자산 이동은 Step 2 이후.

## Issue

### F3 — `effort` 는 공식 frontmatter 필드인데 아니라고 적혀 있었다

`.claude/rules/effort-guide.md:45` 원문:

> Claude Code 는 frontmatter 의 `effort` 필드를 직접 읽지 않으므로 (model 만 표준 — F6) 본 표가 사람 / 스크립트 / agent prompt 의 SOT.

공식 문서에는 명시적으로 있다 — *"Effort level when this subagent is active. **Overrides the session effort level.**"*

이 한 줄이 **"매핑표만 맞추면 된다"** 는 운영 방식을 만들었고, 결과적으로 대부분의 agent 가 `effort` 미명시 = 세션 기본값 방치 상태로 남았다.

### F1 — skill 경로 규격이 문서 어디에도 없었다

`AGENTS.md` §Claude-Only Features 는 skill 위치를 `.claude/skills/` 라고만 적었다. 실제 규격은 `.claude/skills/<skill-name>/SKILL.md` 이고, 현재 레포 레이아웃은 이를 벗어나 로드되지 않는다.

### 부수 — 산문 규약을 승격할 자리가 spec 에 없었다

`multi-tool-adapter.md` 는 "산문 규약을 대상 도구의 강제 메커니즘으로 승격하라" 고 규정하면서 그 예를 **Kiro `permissions`** 로만 든다. Claude Code 자체의 `permissionMode` / `disallowedTools` / `maxTurns` 는 `AGENT-SPEC.md` 에 언급조차 없었다.

## Action

### 1. `.claude/rules/effort-guide.md`

- 출처 블록을 2개로 분리 — effort 단계 정의(2026-05-15) / subagent frontmatter `effort` 필드(**2026-08-24**)
- L45 "Outlier note" → **"`effort` 는 공식 frontmatter 필드다"** 로 교체. 표는 기준, frontmatter 가 강제라는 관계를 명시
- ⚠️ 정정 박스 추가 — 오기 기간(2026-05-15 ~ 2026-08-24)과 파급(대부분 agent 가 미명시로 방치)을 기록. `deep-thinking.md` §3 검증 상태 마킹 의무 적용
- §적용 방법 1·2 갱신 — frontmatter `effort:` 우선, 신규 agent 는 표에서 고른 값을 **frontmatter 에 명시**
- `model` × `effort` 정합성 한 줄 추가 (`xhigh` 는 Opus 4.7 계열만)

### 2. `.claude/templates/AGENT-SPEC.md`

- 출처 F6 검증일 2026-05-15 → **2026-08-24**, **다음 재검증 2026-11** 명시 (`multi-tool-adapter.md` 분기 재검증 의무)
- §1 을 3분할:
  - **§1.1 본 레포 표준 필드** — `effort` 를 선택 → **✅ 필수**로 승격, `disallowedTools` 조건부 필수 추가
  - **§1.2 실행 강제 필드** (신설) — `disallowedTools` / `permissionMode` / `maxTurns` 를 각각 어떤 산문 규약의 승격 대상인지 매핑
  - **§1.3 선택 필드** — `skills` / `memory` / `hooks` / `mcpServers` / `isolation` / `background` / `color` / `initialPrompt`
- §5 본문 구조 표준에 원칙 추가 — **도메인 레퍼런스를 본문에 인라인하지 않는다.** 코드 샘플은 skill 로 두고 `skills:` 로 주입. 코드블록 비중 60%+ 면 그 agent 는 skill 이어야 한다

### 3. `AGENTS.md`

- §Claude-Only Features 표 — Skills 위치를 `.claude/skills/<name>/SKILL.md` 로 정정, Slash Commands 에 skills 병합 사실 표기
- ⚠️ skill 경로 규격 박스 추가 — 현재 레이아웃이 로드되지 않는다는 사실 + Step 2 복구 절차 링크
- subagent frontmatter 16필드 / 실행 강제 3필드 문단 추가 — §User Approval 의 산문 제약을 frontmatter 로 승격 검토하라는 지시

## Result

✅ **Step 1 완료.** 자산(agents / skills) 파일은 변경하지 않았다 — spec·rule·index 3개 문서만.

### 검증

| 스크립트 | 결과 |
|---|---|
| `validate-rules-drift.sh` | ✅ 통과 (모델 ID / 양방향 참조 / Critical 룰 일관성 / sweet spot) |
| `validate-skill-frontmatter.sh` | ✅ 통과 |
| `validate-agent-handoff.sh` | ✅ 통과 |
| `validate-commands-drift.sh` | ✅ 통과 |
| 신규 상대 링크 해석 | ✅ 깨짐 0건 |
| `validate-schemas.sh` | ❌ **1건 실패 — 기존 결함, 본 작업과 무관** |

`validate-schemas.sh` 실패:

```
source-command-log-summary → skill-manifest.v1:
  .agents/skills/source-command-log-summary/SKILL.md (file not found)
```

`git stash` 후 HEAD 에서 실행해도 **동일하게 실패**함을 확인했다. `.agents/` 는 gitignore 대상이며 "P7 까지 deprecate 예정" 인 경로다 — [2026-08-15 audit D5](../audit/2026-08-15-asset-tier-rebalance.md) 의 dangling ref 와 같은 건이다. CI 에는 `validate-schemas.sh` job 이 없어 그동안 드러나지 않았다.

→ Step 2 백로그에 편입 (`.agents/` 경로 정리와 함께 처리).

## 학습

1. **잘못된 한 줄이 운영 방식을 만든다.** "frontmatter 를 안 읽는다" 는 오기 하나가 "매핑표만 관리하면 된다" 는 3개월짜리 운영으로 굳었다. spec 문서의 사실 오류는 그 spec 을 따르는 모든 자산에 복리로 퍼진다.
2. **검증일과 다음 재검증일을 같이 적어야 한다.** 기존 F6 은 "검증일 2026-05-15" 만 있었다. 검증일만 있으면 "언제 다시 봐야 하는가" 가 아무의 책임도 아니게 된다. 이번에 **다음 재검증 2026-11** 을 명시했다.
3. **CI 에 없는 검증 스크립트는 없는 것과 같다.** `validate-schemas.sh` 는 레포에 존재하지만 CI job 이 아니라 실패가 방치돼 있었다. 스크립트 작성과 CI 편입은 별개 작업이다.

## Related Files

- `.claude/rules/effort-guide.md` — F3 정정
- `.claude/templates/AGENT-SPEC.md` — §1.1~1.3 재구성, §5 보강
- `AGENTS.md` — §Claude-Only Features (symlink: `CLAUDE.md`, `.codex/AGENTS.md`)
- `docs/audit/2026-08-24-agent-harness-readiness.md` — §6 Step 1 체크 완료
