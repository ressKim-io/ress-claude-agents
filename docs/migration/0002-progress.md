# Migration 0002 — Phase Progress Tracker

> 매 Phase 시작/완료 시 이 파일을 갱신. 세션 휘발 시 첫 명령은 본 파일 cat.

## 재개 명령 (세션 끊겼을 때)

```bash
cd /Users/ress/my-file/ress-claude-agents
cat docs/migration/0002-standardization-and-control-plane.md   # plan 본문
cat docs/migration/0002-progress.md                            # 어디까지 진행했는지 (이 파일)
ls docs/dev-logs/ | tail -5                                    # 최근 작업 로그
git log --oneline -20                                          # 최근 commit
```

이후 본 파일의 **첫 `pending` Phase**부터 재개.

## Phase Status

| Phase | Status | Started | Completed | Branch / PR | Notes |
|---|---|---|---|---|---|
| P0. 영구 기록 + commit | **completed** | 2026-05-05 | 2026-05-05 | main | 0002 본문(`f6fb2fe`) + dev-log(`0043b12`, `e3e32ec`) + progress 트래커 |
| P1. Schema 동결 | **completed** | 2026-05-05 | 2026-05-05 | main | 3 schema + `scripts/validate-schemas.sh` + README. ajv-cli@5 Draft 2020-12 compile + sample validate 통과 (source-command-log-summary, code-reviewer) |
| P2. PoC 10개 변환 | **completed** | 2026-05-05 | 2026-05-05 | main | `assets/skills/{kubernetes,go}/<n>/SKILL.md` 10개 (commit `00128dd`). validate-schemas.sh PoC strict 게이트 + validate-skill-frontmatter.sh assets 섹션. 기존 5 lint 모두 green. 검증 게이트 (b) matching CLI dry-run은 P3 의존 |
| P3. Control plane PoC | **completed** | 2026-05-05 | 2026-05-06 | main | Step 1: scaffold. Step 2: probe. Step 3: match (precision=recall=1.0). Step 4: init (10x hash × 3 fixture). Step 5 (`810ac58`): lint shell delegation (validate-*.sh auto-discover, exit code aggregate). **모든 4 subcommand (probe/match/init/lint) 구현 완료**. **87/87 vitest**. CI drift green은 push 후 GitHub Actions가 step 6에서 검증 |
| P4. Multi-AI adapter | **completed** | 2026-05-06 | 2026-05-06 | main | Step A: codex spike (.codex/agents schema 3 키 동질성 확인). Step B: `control-plane/src/adapter.ts` 신설 (claude/codex/cursor 3 tool × write/dry-run/diff 3 mode, codex skills `manifest_yaml=''…''`로 9 키 보존). Step C: AGENTS.md primary 승격(254→312줄, §Claude Code-Specific 흡수), `CLAUDE.md→AGENTS.md` symlink, `.codex/AGENTS.md→../AGENTS.md` symlink, `.gitignore` `.codex/` ignore 해제. Step D: `init.ts` step 4 stub → 실제 adapter 호출 wiring (detection + LockFile.adapters.status p4-active/p4-skipped + runs[]). Step E: CI drift job에 adapter parity step (codex+cursor write + git diff 게이트), .claude/skills SKILL.md 디렉토리 형식은 dual-tree 충돌 회피로 gitignore. CLI parser `--tool=value` 형식 추가. **96/96 vitest** (87→96, +9), typecheck 0, build OK, **5 lint green** |
| P5. Enforcement hook | **next** | — | — | — | PreToolUse `admit` 1개. 초기 warning 모드(exit 0 + stderr). LockFile.hook.status `p5-stub` → `p5-active` |
| P6. Pilot 1 카테고리 | pending | — | — | — | kubernetes 카테고리 약 10개 전체 변환. activation rate / matching accuracy baseline 1주 수집 |
| P7. 전체 마이그레이션 | pending | — | — | — | 239개 모두 변환. 2 카테고리/주 페이스. 카테고리 PR 단독 revert 가능 |
| P8. Registry-ready 동결 | pending | — | — | — | signature/sandbox 메타 채움. skills.sh 포맷 export script. **Q8 결정**: sigstore cosign vs SLSA provenance |

## Verification 체크리스트 (PoC 10개 후)

- [x] Schema lint exit 0 — 2026-05-05 (`validate-schemas.sh` 3 schema + 2 sample + 10 PoC strict)
- [x] Probe determinism (10회 hash 일치) — 2026-05-06 (`probe-fixtures.test.ts` 10x SHA-256)
- [x] Matching accuracy precision ≥ 0.9, recall ≥ 0.85 — 2026-05-06 (precision=1.0, recall=1.0 across 3 fixture, `match-fixtures.test.ts`)
- [ ] Adapter parity (claude/codex/cursor diff 0) — P4
- [ ] Hook 동작 (deny 3건, allow 3건) — P5
- [x] End-to-end init 빈 디렉토리에서 성공 — 2026-05-06 (`init.test.ts` 'empty' fixture mkdtemp + 10x hash)
- [x] Adapter parity (claude/codex/cursor diff 0) — 2026-05-06 P4-E (`tests/adapter.test.ts` 8 케이스 + CI drift step)
- [ ] CI drift green — P4 push 후 GitHub Actions가 검증 (drift job에 adapter parity step 통합 완료)
- [x] Multi-AI 동시 사용 시뮬 — 2026-05-06 P4-D (`init.test.ts` "detects .claude/.codex/.cursor and records p4-active in lock")
- [ ] Hook 동작 (deny 3건, allow 3건) — P5

## Decision Log (Phase 진행 중 발견되는 추가 결정)

> 새 결정 발생 시 이 표에 1줄씩 추가. 큰 결정은 별도 ADR 권장.

| 일자 | Phase | 결정 | 사유 |
|---|---|---|---|
| 2026-05-05 | P0 | mono + 내부 재배치 (사용자 결정 1) | AI 시대 monorepo 정답 — Augment/Nx/Spectro Cloud 일치 |
| 2026-05-05 | P0 | Multi-AI 우선 Claude+Codex+Cursor (사용자 결정 2) | 8개 도구 자동 호환되므로 검증·문서만 3개 집중 |
| 2026-05-05 | P0 | Control plane 처음부터 별도 패키지 (사용자 결정 3) | 사용자 선택 — PoC와 빌드 동시 진행 부담 인정 |
| 2026-05-05 | P0 | Registry publish는 미래 옵션 (사용자 결정 4) | 보안 부담·마감 부담 회피, 100% 호환 포맷만 유지 |
| 2026-05-05 | P0 | adapter view git commit 유지 (Q1) | control-plane 미설치 사용자도 동작 |
| 2026-05-05 | P0 | matching threshold 50 시작 (Q2) | false positive가 hook deny로 더 비쌈 |
| 2026-05-05 | P0 | description ≥40자 P2부터 strict (Q3) | directive 강제는 일찍 |
| 2026-05-05 | P0 | `.cursor/rules/` P4에서 동시 (Q4) | 사용자 multi-AI 우선순위에 cursor 포함 |
| 2026-05-05 | P0 | PreToolUse hook 초기 warning 모드 (Q5) | activation baseline 잡힌 후 deny 전환 |
| 2026-05-05 | P0 | inventory.yml에 manifest 메타 흡수 (Q7) | generate-inventory.sh가 frontmatter 직접 파싱 |
| 2026-05-05 | P1 | JSON Schema Draft 2020-12 채택 (`$schema` 명시) | ajv-cli `--spec=draft2020` 1 옵션으로 작동, 미래 호환성 우위 |
| 2026-05-05 | P1 | `format: date-time` 대신 ISO 8601 정규식 pattern | `ajv-formats` 추가 의존성 회피, lint 환경 단순화 |
| 2026-05-05 | P1 | `description.minLength: 1` (P1) → strict 40은 P2 lint script flag로 운영 | schema는 영구 SSOT, 단계적 strict는 lint runner의 책임 (schema-drift 차단) |
| 2026-05-05 | P1 | produces/consumes 어휘 enum은 schema에 박지 않음 | `_handoff.yml` 변경 시 schema MAJOR bump 강제 회피, 어휘 검증은 `validate-agent-handoff.sh`가 전담 |
| 2026-05-05 | P2 | PoC frontmatter는 영문 description (≥40 chars) | directive 활성화 사례가 영문 위주, 한국어 효과는 P3~P4 baseline에서 비교 |
| 2026-05-05 | P2 | dual-tree 유지 — `assets/skills/` 신설 + `.claude/skills/` 보존 | P3 adapter 도입 전 호환성 유지. 10개 한정이라 sync 부담 작음 |
| 2026-05-05 | P2 | 기존 본문의 `# H1`을 그대로 SKILL.md에 포함 | Anthropic 공식은 H1 미권장이지만 본문 손대지 않는 게 PoC 단순성 우선. P3 adapter가 view 생성 시 정책 재결정 |
| 2026-05-05 | P2 | description 길이 strict는 lint script 단계별 flag로 운영 | schema는 `minLength: 1` 영구, `validate-schemas.sh`/`validate-skill-frontmatter.sh`에 P2 strict 함수 추가 → schema-drift 차단 |
| 2026-05-05 | P3 | runtime deps 2/5로 시작, lazy add | step 1엔 `zod`/`kleur`만 필요. `fast-glob`/`yaml`/`tomlify`는 step 2/3/4가 import할 때 추가 — 의존 그래프 최소화 |
| 2026-05-05 | P3 | `run(argv, opts)` 시그니처에 stdout/stderr 주입 | 테스트 capture 깔끔 + future JSON-RPC hook(P5)에서 같은 함수 재사용. `process.stdout` 직접 호출 회피 |
| 2026-05-05 | P3 | commander/yargs 미도입, switch 라우팅 | 4 subcommand 한정이라 의존성 1개 절약. CLI 파서 필요해지면 step 5(`init` confirm flow)에서 재평가 |
| 2026-05-05 | P3 | tsconfig `noUncheckedIndexedAccess: true` | probe/match가 array indexing 다수 사용 예정 → 컴파일러 강제로 결정성·boundary 안전성 확보 |
| 2026-05-06 | P3 | profile에 file list 미포함, match가 fast-glob으로 재스캔 | 큰 monorepo에서 yaml 출력 폭발 회피. profile은 metadata only, match는 profile + filesystem 조합 |
| 2026-05-06 | P3 | `--frozen-time <ISO>` flag로 generated_at 결정성 보장 | schema required 필드라 제거 불가. frozen-time을 결정성 테스트와 CI fixture 비교에서 강제 |
| 2026-05-06 | P3 | fixture 위치: `control-plane/tests/profiles/<n>/` | 본문 §검증 전략 명세 따름. step 4 gold expected.yml도 같은 위치에 추가 예정 |
| 2026-05-06 | P3 | Zod ↔ JSON Schema round-trip 테스트로 drift 차단 | `zod-to-json-schema` 의존성 회피. 동일 valid/invalid sample을 양쪽이 동일하게 판정해야 통과 |
| 2026-05-06 | P3 | yaml stringify에 `sortMapEntries:true` 강제 | probe() 객체 리터럴이 이미 결정적 순서지만 yaml 직렬화 단계 안전망 추가. 10x hash 일치 보장 |
| 2026-05-06 | P3 | `.git/HEAD` 파일을 직접 읽어 default_branch 추출 | git CLI 비의존, 결정성 + Node-only. 정확한 origin/HEAD 추적은 over-engineering으로 보고 현재 branch 사용 |
| 2026-05-06 | P3 | match는 fast-glob 패턴별 재호출, micromatch 직접 import 회피 | fast-glob의 transitive dep을 직접 사용하면 fragile. PoC 비용 (skill 10 × 패턴 ~5 = 50 호출) 충분히 빠름. 정확성은 fast-glob 자체 보증 |
| 2026-05-06 | P3 | `bucketScores` export로 selectSkills 분류 로직 단위 테스트 | score 함수는 fast-glob 의존 → 통합 테스트, 분류·정렬은 순수 함수로 분리해 단위 검증 |
| 2026-05-06 | P3 | gold dataset은 `tests/expected/<n>.yml` 별도 디렉토리 | fixture 안에 두면 'empty' fixture에 yaml이 카운트되어 probe 결과 오염 — 별도 위치로 격리 |
| 2026-05-06 | P3 | go-testing / go-errors PoC manifest 보강 (description 의도와 align) | step 3-C sanity 결과 false positive 2건 (`commit 6aab47c`). manifest는 living document, P3 검증 단계에서 보정은 본문 §검증 전략의 자연스러운 일부 |
| 2026-05-06 | P3 | init 산출물(`project-profile.yml` / `.claude-agents.yml`)은 root에 작성 + PROBE_IGNORES에 자체 ignore | 별도 디렉토리(`.claude-agents/lock.yml`) 대신 root 직접 작성으로 사용자 가시성 확보. 산출물이 다음 probe/match에 영향 없도록 ignore 리스트로 격리 |
| 2026-05-06 | P3 | init step 3 (confirm)은 P3에서 auto-accept (interactive prompt P5+ 위임) | P3 종료 게이트(diff snapshot)는 비대화형이어야 결정적. interactive 도입 시점에 별도 ADR |
| 2026-05-06 | P3 | LockSkillEntry score 출력은 round2 (소수점 2자리) | yaml 직렬화 시 float 정밀도 변동 차단. 결정성 + 사람 가독성 균형 |
| 2026-05-06 | P4-A | `.codex/agents/*.toml` schema = `name` + `description` + `developer_instructions` 3 키 only | 46개 전수 조사 결과 변형 0건. 처음 grep에서 보였던 100+ 키는 `developer_instructions` 본문 내 코드 블록(my.cnf, pgbouncer.ini 등)에 line-start `key =` 패턴 잡힌 false positive. 기존 toml `tools`/`model` frontmatter 키는 미존재 — Codex는 도구 권한 메커니즘 다름 |
| 2026-05-06 | P4-A | multi-line 디폴트 delimiter `'''` (TOML literal string) | 본문에 backslash·큰따옴표 다수, 한국어 안전, escape 불필요. 기존 분포는 27개 `"""` / 19개 `'''`이지만 변환 디폴트는 `'''` 강제 — body가 `'''` 포함 시에만 `"""` + escape fallback |
| 2026-05-06 | P4-A | source-target 1:1 매핑 = `.claude/agents/<n>.md` (frontmatter `name`/`description` + body) ↔ `.codex/agents/<n>.toml` 3 키 | 46↔46 파일명 set 완전 일치, 누락 0건. frontmatter `tools`/`model`은 변환 시 drop (Codex 무시) |
| 2026-05-06 | P4-B | round-trip 검증 게이트 = **의미 일치(parse→gen→parse 동일)**, byte-exact diff 0 아님 | TOML multi-line basic string 첫 `\n` 무시 규칙 + yaml frontmatter quoting/순서 차이 + trailing newline 변동으로 byte exact는 fragile. parse 후 데이터(`{name, description, developer_instructions}`) 일치를 게이트로. byte exact는 P4 종료 시 commit replace로 자연 수렴 |
| 2026-05-06 | P4-B | codex skills toml의 9 키 부착 첫 구현 = `manifest_yaml = '''<SKILL.md frontmatter 원문>'''` 단일 string 필드 | TOML table section + sub-table 형태(applies_when nested + files_contain record + exclude_when)는 stringify 50+ 줄 추가 + 결정성 까다로움. yaml inline 보관은 손실 0 + 구현 단순(20줄), P5 hook이 yaml parse하면 즉시 사용. TOML-native 풀어쓰기는 P4 후속 또는 P6 pilot에서 재결정 |
| 2026-05-06 | P4-C | CLAUDE.md → AGENTS.md symlink, `.codex/AGENTS.md` → `../AGENTS.md` symlink. AGENTS.md primary 승격 | LF AGENTS.md 표준 채택. CLAUDE.md 4 섹션(Auto-Loaded Rules / Token Budget / Claude-Only Features / Opus 4.7 Behavioral Notes)을 AGENTS.md §"Claude Code-Specific"로 압축 흡수(~30줄), 다른 도구는 자기에게 무관한 본 섹션 무시. AGENTS.md 254→312줄. Governance §SoT 계층에서 CLAUDE.md를 별개 SoT가 아닌 mirror로 정정 |
| 2026-05-06 | P4-C | `.gitignore`에서 `.codex/` 라인 제거, `.agents/`만 ignore 유지 | P4 plan §86-89 "`.codex/agents/`는 commit 유지" 명시 정합. 기존 46 .toml + 신규 P4 adapter 산출물 + `.codex/AGENTS.md` symlink 모두 commit 가능. `.agents/`는 P7까지 deprecate 단계라 ignore 유지 |
| 2026-05-06 | P4-D | `.claude/skills/<cat>/<n>/SKILL.md` 디렉토리 형식은 P7까지 commit 안 함 (gitignore) | adapter --tool=claude는 동작하지만 dual-tree 충돌 회피. `.claude/skills/<cat>/<n>.md` 단일 파일이 P7까지 SSoT view (plan §86-89 "P7까지 살아있음"). 대안 = lint(`validate-skill-frontmatter.sh`)+inventory(`generate-inventory-labels.sh`) 둘 다 SKILL.md 형식 인식하도록 갱신(~30줄) — 채택 X. CI drift는 codex+cursor만 검증 |
| 2026-05-06 | P4-D | `init.ts` step 4 stub → 실제 adapter 호출 wiring | `existsSync(.claude/.codex/.cursor)` 자동 detection, detected 도구마다 adapter() 호출(dryRun 모드 전파). LockFile schema: `adapters.status: p4-stub` → `p4-active|p4-skipped`, `runs?: AdapterRunSummary[]` 추가. init.test.ts L99-106 갱신 + 신규 detection 테스트 1건 |
| 2026-05-06 | P4-E | CI drift job에 adapter parity step 추가 | `.github/workflows/ci.yml` drift job에 Node setup + control-plane build + adapter --tool=codex/cursor write + `git diff --quiet` 게이트. cursor/codex view 변경 시 commit 강제. .claude/skills SKILL.md는 P4-D gitignore로 검증 대상에서 제외 |
| 2026-05-06 | P4-E | adapter CLI parser `--flag=value` 형식 지원 추가 | 기존엔 `--tool claude` 띄어쓰기만 가능. `--tool=claude`도 받아 표준 GNU long-opt 컨벤션 충족. 토큰 분리는 첫 `=` 위치 기준 |
| 2026-05-06 | P4-A | `tomlify` 의존성 미추가, 직접 stringify (50줄 미만) | 처리 대상이 3 string 키뿐이고 literal-string 디폴트라 escape 로직 단순. P3 정책 runtime deps ≤ 5 유지 (현재 4/5: zod·kleur·fast-glob·yaml). 의존성 1개 절약 + 변환 결정성 직접 통제 |
| 2026-05-06 | P4-A | `assets/skills/<cat>/<n>/SKILL.md` → `.codex/skills/<cat>/<n>.toml` 변환 시 부가 메타 9 키(`applies_when`/`portability`/`produces`/`consumes`/`security`/`version`/`license`) 그대로 toml에 부착 | 옵션 B(body 헤더 prepend)·C(drop)와 비교 후 채택. round-trip 손실 0 우선. Codex가 unknown 키 무시하는 관대한 reader 가정 — 문제 시 P5 hook 단계에서 회귀 |

## 알려진 위험 (해소되면 줄긋기)

- ~~`.codex/agents/*.toml` 변환 로직 소스 미식별~~ — P4-A spike(2026-05-06) 결과: 레포 내 변환 스크립트 부재 확인(외부/수작업 산출물). schema 3 키 동질성 + 1:1 매핑 확정 → P4가 첫 자동화. 기존 46개는 round-trip diff 0 fixture로 재활용
- ~~`.agents/skills/`와 `.claude/skills/` 차이~~ — diff 0 확인됨, 단일 SSOT 합치기 안전
- `applies_when.files_contain` regex의 큰 monorepo 성능 — fast-glob `--max-depth 4` cap 권장
- 이중 부담(레포 PoC + 패키지 빌드) 인력 50/50 — 사용자 결정 따른 부담 인정
