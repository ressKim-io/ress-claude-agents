---
date: 2026-05-06
type: migration
phase: 0002-P3
related:
  - ../migration/0002-standardization-and-control-plane.md
  - ../migration/0002-progress.md
  - 2026-05-05-p1-p2-schema-poc.md
---

# 0002 P3 — Control plane PoC (probe / match / init / lint)

P0~P2(영구 기록 → schema 동결 → PoC 10개)에 이어 본 세션은 P3 전체를 한 흐름에 종료했다. 본문 §Phase 분할이 요구한 "`@ress/claude-agents` CLI 4 subcommand probe/match/init/lint"가 모두 구현되었고, 검증 게이트 4 항목(schema lint / probe determinism / matching accuracy / end-to-end empty init) 모두 통과했다.

## 진입 시점 상태

- P2 종료 직후. `assets/skills/{kubernetes,go}/<n>/SKILL.md` 10개 frontmatter 동결, `schemas/` 3종 SSOT, lint 5종 green.
- main 대비 origin/main 4 commits ahead, working tree clean.
- 다음 진입 Phase는 P3 = Control plane PoC. 본문 권고는 별도 패키지(`control-plane/`)로 분리.

## Step 1 — 패키지 골격 (`f0b0c83` → `daced4c`)

`control-plane/` 디렉토리 신설. ESM + Node 18+, tsup ESM 번들, vitest, tsconfig strict + `noUncheckedIndexedAccess`. 4 subcommand router(`probe/match/init/lint`)는 일단 stub("not implemented") + 8 vitest 라우팅 케이스. 빌드된 `dist/cli.js`에 shebang 보존 확인.

### Step 1 결정 (4건)

| 결정 | 사유 |
|---|---|
| runtime deps **2/5로 시작, lazy add** (zod, kleur만) | step 2 이후 fast-glob/yaml/tomlify를 import할 때 추가. 의존 그래프 최소화 |
| `run(argv, opts)` 시그니처에 stdout/stderr 주입 | 테스트 capture + future JSON-RPC hook(P5)에서 같은 함수 재사용. `process.stdout` 직접 호출 회피 |
| commander/yargs **미도입**, switch 라우팅 | 4 subcommand 한정. CLI 파서 필요해지면 step 4(`init` confirm flow)에서 재평가 |
| tsconfig `noUncheckedIndexedAccess: true` | probe/match가 array indexing 다수 사용 → 컴파일러 강제로 결정성·boundary 안전성 확보 |

## Step 2 — Probe (`9966bd3` → `9f2bd24`)

zod로 `schemas/project-profile.v1.json`을 mirror하고 round-trip 테스트(zod ↔ ajv 6 case 일치). probe 본체는 repo / languages / build_systems / frameworks / files_signatures / domain_hints 6 영역. fixture 3종(empty/go-gin/k8s-only)을 `tests/profiles/` 아래 commit하고 10x SHA-256 해시 일치 검증.

### Step 2 결정 (6건)

| 결정 | 사유 |
|---|---|
| profile에 file list **미포함**, match가 fast-glob 재스캔 | 큰 monorepo에서 yaml 출력 폭발 회피. profile은 metadata only |
| `--frozen-time <ISO>` flag로 `generated_at` 결정성 보장 | schema required 필드라 제거 불가. frozen-time을 결정성 테스트와 CI fixture 비교에서 강제 |
| fixture 위치: `control-plane/tests/profiles/<n>/` | 본문 §검증 전략 명세 따름. step 4 gold expected.yml과 같은 위치 |
| Zod ↔ JSON Schema **round-trip 테스트로 drift 차단** | `zod-to-json-schema` 의존성 회피. 동일 valid/invalid sample을 양쪽이 동일 판정 |
| yaml stringify에 `sortMapEntries:true` 강제 | probe() 객체 리터럴이 이미 결정적 순서지만 직렬화 단계 안전망 추가 |
| `.git/HEAD` 파일을 직접 읽어 default_branch 추출 | git CLI 비의존, 결정성 + Node-only |

go-gin fixture에서 `main.go`만으로는 다른 단일 파일(Dockerfile / README / ci.yml) 동률 → 알파벳 순으로 **dockerfile**이 primary가 되는 corner case. `handler.go` 한 개 추가로 go가 primary로 안정. 실제 Go 프로젝트는 .go 파일 다수라 무시 가능한 fixture 한정 이슈.

## Step 3 — Match (`541d005` → `1b8f04e`)

skill-manifest zod(anyOf via `.refine()`), skill-loader(`assets/skills/<cat>/<n>/SKILL.md` 10개 무결 로드), score 함수(가중치 40/30/20/15 = 105 만점, threshold 50), match CLI. gold dataset 3개 작성(empty / go-gin / k8s-only).

### 발견 — false positive 2건

go-gin fixture에 대해 정확도 측정 중 다음이 발견되었다.

| Skill | 점수 | 원인 |
|---|---|---|
| `go-testing` | 70 → install | files_contain `'^module\s'`이 모든 go.mod와 매치. description의 "Skip for non-_test.go files" 의도와 충돌 |
| `go-errors` | 60 → install | files_present `**/*.go` + `**/go.mod`만으로 40점 + language 20 = 60. errors 패턴 미매치 (files_contain 0)인데도 install |

precision = 0.5로 P3 게이트(0.9) 미달. 사용자에게 옵션 3개 제시(manifest 보강 / threshold 상향 / algorithm 페널티) → A(manifest 보강) 선택.

### 보정 (`6aab47c`)

- `go-testing`: files_present에서 `**/go.mod` 제거(`*_test.go` 단독), files_contain key를 `**/*_test.go`로 옮기고 value를 `(testing\.[TBM]|stretchr/testify|testcontainers|^func Test[A-Z])`로 좁힘.
- `go-errors`: files_present 자체 제거(anyOf는 files_contain + language로 충족). errors.X 패턴이 *.go 안에 실제 존재해야 매치.

보정 후 정확도: **precision 1.0 / recall 1.0** (TP=3, FP=0, FN=0).

### Step 3 결정 (5건)

| 결정 | 사유 |
|---|---|
| match는 fast-glob 패턴별 재호출, micromatch 직접 import 회피 | transitive dep 직접 사용은 fragile. PoC 비용(skill 10 × 패턴 ~5 = 50 호출) 충분히 빠름 |
| `bucketScores` export로 selectSkills 분류 로직 단위 테스트 | score 함수는 fast-glob 의존(통합 테스트), 분류·정렬은 순수 함수로 분리 |
| gold dataset은 `tests/expected/<n>.yml` 별도 디렉토리 | fixture 안에 두면 'empty' fixture에 yaml 카운트 → probe 결과 오염 |
| go-testing/go-errors PoC manifest는 living document | step 3-C sanity 결과 false positive → P3 검증 단계 보정은 본문 §검증 전략의 자연스러운 일부 |
| anyOf JSON 게이트는 zod에서 `.refine()`로 표현 | `applies_when`이 빈 객체일 수 있는 상황을 zod가 거부 — JSON Schema와 동일 시맨틱 |

## Step 4 — Init (`bb07648` → `787fa38`)

5-step orchestration: probe → match → confirm(auto-accept) → adapter(P4 stub) → hook(P5 stub). 산출물 2종(`project-profile.yml` + `.claude-agents.yml`)을 `--root`에 작성. `--dry-run` 모드는 stdout 미리보기만.

P3 종료 게이트("가짜 프로젝트 3종 init 결과 diff snapshot 일치, 10회 재실행 동일")는 매 호출마다 fresh `mkdtemp` + `cpSync` 디렉토리에서 실행 → 산출물 SHA-256 hash 10× 일치 across 3 fixture로 검증.

### Step 4 결정 (3건)

| 결정 | 사유 |
|---|---|
| 산출물(`project-profile.yml` / `.claude-agents.yml`)은 root에 작성 + PROBE_IGNORES에 자체 ignore | 별도 `.claude-agents/lock.yml` 대신 root 직접 작성으로 사용자 가시성 확보. ignore로 다음 probe/match 영향 차단 |
| init step 3 (confirm)은 P3에서 auto-accept (interactive prompt P5+ 위임) | P3 종료 게이트(diff snapshot)는 비대화형이어야 결정적 |
| `LockSkillEntry.score`는 round2 (소수점 2자리) | yaml 직렬화 시 float 정밀도 변동 차단. 결정성 + 사람 가독성 균형 |

기존 probe.ts / match.ts에서 중복 정의되던 VENDOR_IGNORES도 `src/ignores.ts`로 통합(`bb07648`)했다.

## Step 5 — Lint (`810ac58`)

`scripts/validate-*.sh` 자동 발견 → bash spawn → exit code aggregate. validate prefix만 picking(generator script 자동 제외). 자체 레포 sanity:

```
✓ scripts/validate-agent-handoff.sh (exit 0)
✓ scripts/validate-rules-drift.sh (exit 0)
✓ scripts/validate-schemas.sh (exit 0)
✓ scripts/validate-skill-frontmatter.sh (exit 0)
```

## CI 복구 — Shellcheck SC2016 / SC2155 (`0588751`)

P3 step 5 push 직후 GitHub Actions가 fail. 분석 결과 P1에서 작성한 `validate-schemas.sh`의 **두 shellcheck warning이 P1 push부터 누적**되어 있었다.

| 위치 | 코드 | 원인 / 처리 |
|---|---|---|
| line 69 | SC2016 (info) | `node -e '...'` 안 JS literal에서 single quote 의도된 사용. `# shellcheck disable=SC2016` directive + 의도 주석 |
| line 141 | SC2155 (warning) | `local out="...$(printf ...)..."` 패턴이 subshell exit code masking. `local out` + `out=...` 분리 |

로컬 shellcheck 0.11.0는 둘 다 통과했지만 CI ubuntu의 더 엄격한 default가 fail 처리. 두 issue 모두 직접 fix.

> **교훈**: shellcheck local pass ≠ CI pass. ubuntu apt shellcheck는 다른 default를 가질 수 있으므로 .github/workflows/ci.yml에 명시적 `--severity=warning --shell=bash` 같은 flag를 박아두면 환경 차이 줄어든다 (별도 ADR 후보).

## 검증 게이트 통과 요약

| 게이트 | 결과 | 증거 |
|---|---|---|
| Schema lint | ✅ | `validate-schemas.sh` (5/5 lint green) |
| Probe determinism | ✅ | `probe-fixtures.test.ts` 10× SHA-256 일치 |
| Matching accuracy ≥ 0.9 / 0.85 | ✅ | precision = 1.0, recall = 1.0 (`match-fixtures.test.ts`) |
| End-to-end init in empty dir | ✅ | `init.test.ts` 'empty' fixture mkdtemp + 10× hash |
| CI drift green | ✅ | `0588751` 후 GitHub Actions 통과 |
| Adapter parity | — | P4 |
| Hook 동작 | — | P5 |
| Multi-AI 동시 사용 시뮬 | — | P4 |

87/87 vitest pass (cli 12 + probe 14 + probe-fixtures 6 + schema 6 + skill-manifest 8 + skill-loader 11 + match 9 + match-fixtures 4 + init 13 + lint 4).

## 교훈

1. **Manifest는 living document**. P2에서 freeze한 PoC라도 P3 검증 단계에서 의도와 어긋난 applies_when이 발견되면 보정이 정공법. threshold나 algorithm 가중치를 조정하기 전에 manifest를 먼저 의심한다.
2. **결정성은 다층 방어**가 안전. probe()의 객체 리터럴 순서 + yaml `sortMapEntries:true` + `--frozen-time` flag + fixture mkdtemp 격리. 각 층이 다른 종류의 drift를 막는다.
3. **deps 정책 cap(≤5)이 의사결정 강제**. micromatch transitive 사용 vs fast-glob 재호출, 글로브 패턴 matcher 자체 작성 vs lib 도입 같은 결정에서 cap이 가드레일 역할.
4. **CI lint는 push마다 머신에서 다시 돌려야 안전**. local shellcheck pass ≠ CI pass. 향후 pre-push hook에서 동일 환경(`act` 또는 docker)으로 lint 호출 검토.
5. **단계별 commit 분할은 review 비용을 낮춘다**. step 3을 4 commit(A: zod, B: loader, C: algorithm, D: gold)으로 분할 + 사용자가 각 단계마다 sanity check를 요청 → false positive 발견이 step 3-D 직전에 가능했다. 단일 step 3 commit이었다면 게이트 미달이 P3 종료 시점에야 노출됐을 것.

## 다음 phase 진입점

P4 — Multi-AI adapter:

- `claude-agents adapter --tool=<claude|codex|cursor>` 단일 진입점
- view 생성: `assets/skills/<cat>/<n>/SKILL.md` → `.claude/skills/<cat>/<n>/SKILL.md` (symlink/copy) / `.codex/skills/<cat>/<n>.toml` (yaml→toml, tomlify dep 추가) / `.cursor/rules/<n>.mdc` (frontmatter `globs:` ← applies_when.files_present)
- AGENTS.md primary 승격(`ln -sf AGENTS.md CLAUDE.md`), `.codex/AGENTS.md` 동일 처리
- CI drift job에 `claude-agents adapter` 결과 ↔ commit된 view 차이 검증 추가
- P3 lock의 `adapters.status:p4-stub` 마커를 실제 detection + 출력으로 교체

해소된 위험:
- ✅ Probe determinism (10x hash) — step 2-D
- ✅ Matching accuracy (gold dataset) — step 3-D
- ✅ End-to-end init (empty / go-gin / k8s-only) — step 4-B

남은 위험 (P4 진입 시):
- `.codex/agents/*.toml` 변환 로직 소스 미식별 — 1일 spike 필요 (P4 시작)
- Cursor `.mdc` frontmatter spec 검증 — Cursor 공식 문서 기반
