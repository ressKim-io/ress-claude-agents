# 2026-05-08 — Migration 0002 P6.5 baseline setup

P6 종료(`fe1e4da`) 직후 세션에서 P6.5 진입 점검 → setup 누락 4건 발견 → 한 세션에 마무리.

## 발견된 setup 누락 (점검 결과)

P6.5는 progress.md 상 "next" 상태였고, 메모리 상 사용자 1회 setup 작업으로 정의되어 있었으나 다음 4건이 모두 미이행:

| 항목 | 점검 결과 | 영향 |
|---|---|---|
| (a) P6 commit push | `fe1e4da` 로컬 only, `main` ahead by 1 | CI run으로 P6 종결 게이트 검증 미완 |
| (b) Hook installation | `.claude/settings.local.json`에 `hooks` 키 부재 | admit handler 호출 자체가 안 됨 |
| (c) Sink 환경변수 | `CLAUDE_AGENTS_ADMIT_LOG` unset | 환경변수 옵트인이라 sink JSONL 생성 안 됨 |
| (d) Lock file commit policy | `.claude-agents.yml` / `project-profile.yml` `.gitignore` 없음 | init 산출물이 untracked로 남음, fork/clone 시 충돌 가능 |

P6.5 setup 가이드(`progress.md` §"P6.5 Baseline 수집 setup")는 (c)만 명시. (b)는 P5에서 깔린다고 가정했으나 실제로 본 메타 레포에선 init이 한 번도 실행되지 않은 상태. (a)/(d)는 가이드 누락.

## 작업 순서

### 1. Lock file 처리 결정 (사용자 결정 — Option A 채택)

세 옵션 검토:
- A. 별도 commit + 같이 push (Recommended) — `.gitignore` commit + P6 commit 묶어서 push, CI 일괄 검증
- B. P6만 먼저 push, .gitignore 나중에 — CI run 빨리 보지만 step 2회
- C. .gitignore stash + P6만 push — lock 파일은 untracked로 남음

사용자 결정: A. 이유는 메타 레포 self-bootstrap 산출물은 fork/clone 시 각자 init 재실행이 의도된 흐름이라 영구 ignore가 맞다.

### 2. 실행

```bash
# (b) hook 설치 (dry-run 미리보기 후 적용)
node control-plane/dist/cli.js init --root . --assets ./assets --dry-run
# → 3 skill match (go-gin 70 / k8s-helm 65 / go-microservice 50), claude 15c gitignored
node control-plane/dist/cli.js init --root . --assets ./assets
# → settings.local.json에 PreToolUse admit warn-mode hook 추가, lock 2개 root 생성

# (d) gitignore commit
# .claude-agents.yml + project-profile.yml 추가 (메타 레포 self-bootstrap ignore 정책)
git add .gitignore
git commit -m "chore(gitignore): ignore control-plane init self-bootstrap artifacts"
# → a220e8e

# (a) push
git push origin main
# → fe1e4da + a220e8e 둘 다 origin

# CI 검증 (background watch)
gh run watch 25539882702 --exit-status
# → 5/5 success: Drift / Inventory / Documentation / Shellcheck / Test (BATS 22s)

# (c) ~/.zshrc 추가
# export CLAUDE_AGENTS_ADMIT_LOG="$HOME/.claude-agents-admit.jsonl"
# + ADR 0004 마커 주석 (1주 후 라인 제거 또는 유지 결정)

# Sink prewarm
touch "$HOME/.claude-agents-admit.jsonl"
```

## 결과

| 전제 | 상태 |
|---|---|
| (a) P6 push → CI 검증 | ✓ run 25539882702 5/5 success (`a220e8e` HEAD) |
| (b) Hook installation | ✓ `.claude/settings.local.json` PreToolUse warn-mode, 3 skill 활성 |
| (c) Sink 환경변수 | ✓ `~/.zshrc` export 추가 + ADR 0004 마커 주석, `~/.claude-agents-admit.jsonl` prewarm |
| (d) Lock file 격리 | ✓ `.gitignore`에 `.claude-agents.yml` / `project-profile.yml` 추가 commit `a220e8e` |

## 다음 게이트

**Baseline due ≈ 2026-05-15** (1주 wall-clock).

ADR 0004 임계 4개 측정:

| 메트릭 | 임계 |
|---|---|
| Total activations | ≥ 50 |
| Activation rate | ≥ 70% |
| Allow rate | ≥ 90% |
| Per-skill warn rate (max) | < 15% |

전부 통과 → ADR 0005 Option A (deny 전환). 미통과 → B (매처 튜닝 후 재baseline) / C (warn 영구 유지).

## 한계 인지 (Decision Log P6.5-2)

본 메타 레포는 자산을 만드는 곳이라 K8s/Go 일상 작업 노출도가 낮음. baseline이 약한 신호일 가능성 — total < 50 시 다음 셋 중 결정:
1. baseline 기간 연장 (추가 1주)
2. 사용자 K8s 프로젝트에 install 후 baseline 재시작
3. 임계 완화 후 ADR 0005 Option A 진행

ADR 0005 본문 채울 때 결정.

## 새 세션 진입 가이드

세션 나갔다 다시 진입 시 첫 명령:

```bash
cat docs/migration/0002-progress.md                    # P6.5 row "in_progress (collecting)" 확인
cat /Users/ress/.claude/projects/-Users-ress-my-file-ress-claude-agents/memory/project_0002_migration.md
                                                       # §"1주 후 첫 명령" 섹션 jq one-liner 사용
```

Setup 재실행 불필요 — 이미 (a)~(d) 완료.

## 회고 (1줄)

setup 가이드(progress.md)가 (b)/(d)를 누락했던 것이 본 세션의 핵심 발견. 새 host에서 init이 한 번도 안 돌면 hook 자체가 없으니 sink 환경변수만으로는 baseline이 시작되지 않는다 — 가이드는 "init 1회 실행 + zshrc + sink prewarm" 3-step으로 명시되어야 했음. memory `project_0002_migration.md`에 setup 완료 상태 + 트러블슈팅 재진입 명령 추가로 보강.
