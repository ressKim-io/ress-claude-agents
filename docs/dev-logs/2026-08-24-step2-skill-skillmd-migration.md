---
date: 2026-08-24
category: migration
tier: 2
importance: critical
status: resolved
tags: [skill-format, skillmd, harness-engineering, install-sh, inventory, p7-correction, step2]
related:
  - audit/2026-08-24-agent-harness-readiness.md
  - dev-logs/2026-08-24-harness-engineering-audit.md
  - dev-logs/2026-08-24-step1-agent-spec-modernization.md
  - migration/0002-progress.md
---

# Step 2 — 죽은 skill 260개 복구: `<name>/SKILL.md` 이관

## Context

[2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) §6 **Step 2** 실행. F1(skill 260개 미로드) / F2(P7 목표 경로도 규격 위반) 복구.

사용자 결정: 카테고리는 **frontmatter `category:`** 로 보존, 커밋은 **카테고리 단위**.

## Issue

공식 규격은 `.claude/skills/<skill-name>/SKILL.md` — **한 단계 디렉토리 + `SKILL.md`**. 카테고리 하위 디렉토리는 지원되지 않는다.

레포 레이아웃은 `.claude/skills/<카테고리>/<이름>.md` 로 **두 단계 + flat 파일**이라 두 가지 모두 위반이었다. 260개 / 97,912줄이 3개월 이상 사문화 상태.

`.gitignore:39` 가 제외하던 P7 목표 경로 `.claude/skills/*/*/SKILL.md` 역시 skills/ 아래 **두 단계**라 같은 이유로 로드되지 않는다. **P7 을 설계대로 실행했다면 260개를 변환하고도 여전히 안 붙었다.**

## Action

### 1. 변환 스크립트 + 검증 게이트

`scripts/migrate-skills-to-skillmd.sh` 작성 (기본 dry-run, `git mv` 로 rename 추적, idempotent, bash 3.2 호환).

**게이트를 먼저 통과시켰다** — `go/effective-go` 1건만 이관 후 실제 로드 여부 확인. 사용자가 `/` 목록에서 `effective-go` 를 확인했고, 같은 시점에 세션 skill 목록에도 등재됐다. **F1 이 실측으로 확증됐고 수정 방식도 맞다는 것이 확인된 뒤에** 나머지를 진행했다.

### 2. 260개 이관 (22 카테고리 커밋)

`.claude/skills/<cat>/<name>.md` → `.claude/skills/<name>/SKILL.md`, frontmatter `name:` 바로 뒤에 `category: <cat>` 삽입.

이관 후 카테고리별 개수가 이관 전과 정확히 일치함을 확인 (합계 260).

### 3. 의존 스크립트 수정

| 파일 | 변경 |
|---|---|
| `generate-inventory.sh` | `find -name SKILL.md`, 이름은 디렉토리명, `categorize_skill` 이 frontmatter 우선 |
| `generate-inventory-labels.sh` | 동일 |
| `validate-skill-frontmatter.sh` | 카테고리 분포를 frontmatter 경계 안에서만 파싱 (헬퍼 3개 추가) |
| `install.sh` | `install_skills_by_category` 헬퍼 신설, individual 은 basename 해석, **flatten symlink 제거** |
| `validate-schemas.sh` | dangling `.agents/` 샘플 검증 삭제 |
| `.gitignore` | 규격 위반 경로였던 `.claude/skills/*/*/SKILL.md` 제외 규칙 삭제 |

`plugins/*.yml` 과 `.claude/workflows/*.yml` 의 표기(`categories: [go]`, `individual: [dx/spec-driven-development]`)는 **그대로 뒀다.** 설정 표면을 안정적으로 두고 install.sh 의 resolver 만 바꿨다.

### 4. 문서

- `docs/migration/0002-progress.md` — P7 행을 "범위 축소" 로 갱신, **P4-D 결정 정정** 항목을 decision log 에 추가
- `docs/architecture/multi-tool-mapping.md` — Skill 경로 + §개수 격차 문단 갱신. P7 남은 범위는 codex/cursor 변환분 확대뿐

## Result

✅ **Step 2 완료.**

| 검증 | 결과 |
|---|---|
| 구 레이아웃 잔여 | 0 |
| `SKILL.md` 개수 | 260 |
| frontmatter `category:` 보유 | 260 |
| 카테고리 수 / 합계 | 22 / 260 (이관 전과 동일) |
| `validate-rules-drift` / `-skill-frontmatter` / `-agent-handoff` / `-commands-drift` / `-schemas` | 전부 PASS |
| `shellcheck install.sh scripts/*.sh` | PASS |
| inventory 신선도 | PASS |
| 실제 로드 | ✅ 세션 skill 목록에 260개 등재 확인 |

install.sh 스모크:
- `--workflow compose-to-k8s` → 58개 설치 = dx(26) + kubernetes(14) + infrastructure(18). **카테고리 필터링이 frontmatter 로 정확히 동작**
- individual (`infrastructure/compose-to-k8s`) 해석 정상, 심볼릭 링크 내용 도달 확인
- 평면 `.md` 잔재 0건

skills `total_lines` 97,912 → 98,170 (+258 = `category:` 줄 260개 삽입분 − 이미 보유 2개).

## 작업 중 발견 (Step 2 범위 밖 — 기록만)

### 1. `--plugin X --with-skills` 가 260개 전부 설치한다

`--plugin backend-go --with-skills` 로 스모크했더니 38개(go+msa+architecture)가 아니라 260개가 설치됐다. `WITH_SKILLS` 전체 설치 블록이 plugin 블록의 산출물을 `backup_and_link ... "dir"` 로 **덮어쓴다**.

`git stash` 후 HEAD 에서도 261개가 설치됨을 확인 — **기존 동작이며 이번 변경의 회귀가 아니다.** plugin 의 범위 축소 기능이 사실상 죽어 있다. [ADR 0007](../adr/0007-install-sh-narrow-scope.md) / PR-8 영역.

### 2. 본문의 `category:` 줄이 카테고리로 오탐됐다

`awk '/^category:/'` 로 카테고리를 수집했더니 `payment` / `reactive` 가 카테고리로 잡혔다. `adr-retrospective` 와 `runbook-driven-ops` **본문**에 있던 줄이다. frontmatter 경계(`n==1`)를 강제해 차단했다. 같은 함정을 install.sh 헬퍼에도 동일하게 적용.

### 3. `validate-schemas.sh` 가 CI job 이 아니다

Step 1 에서 발견한 `.agents/` dangling ref 실패가 방치돼 있던 이유. 이번에 dangling ref 는 제거했지만 **스크립트를 CI 에 편입할지는 미결**이다. 편입하지 않으면 같은 일이 반복된다.

## 학습

1. **"파일이 존재하는가" 와 "도구가 로드하는가" 는 다른 질문이다.** inventory·CI·validator·2개의 선행 audit 이 전부 전자만 검사했고, 그래서 97,912줄이 3개월 넘게 죽어 있는 것을 아무도 못 잡았다. 자산 레포의 검증에는 **로드 가능성 검사**가 있어야 한다.
2. **게이트를 먼저 통과시킨 것이 옳았다.** 1건 이관 → 실측 확인 → 나머지 진행. 260개를 옮기고 안 붙었다면 전량 롤백이었다. 백로그에 게이트를 명시적으로 박아둔 것이 실제로 작동했다.
3. **미룬 결정은 만료된다.** P4-D 는 "dual-tree 충돌 회피" 라는 합리적 이유로 P7 까지 미뤘지만, 그 전제(둘 중 하나는 동작한다)가 애초에 틀렸다. 미루는 결정에는 **전제 재확인 시점**을 같이 박아야 한다.

## Related Files

- `scripts/migrate-skills-to-skillmd.sh` — 변환 스크립트 (신규)
- `.claude/skills/<name>/SKILL.md` — 260개
- `install.sh` — `install_skills_by_category` / `skill_frontmatter_category`
- `.gitignore` — 규격 위반 제외 규칙 삭제
- `docs/migration/0002-progress.md` — P7 범위 축소 + P4-D 정정
