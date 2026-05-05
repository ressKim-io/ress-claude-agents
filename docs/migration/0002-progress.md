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
| P3. Control plane PoC | **next** | — | — | — | `@ress/claude-agents` CLI 4 subcommand (probe/match/init/lint), TS+Node 18+ ESM. tsup ESM 번들 |
| P4. Multi-AI adapter | pending | — | — | — | `.cursor/rules/` 자동 생성, AGENTS.md primary 승격, CLAUDE.md→symlink. 기존 `.codex/agents/*.toml` 변환 로직 흡수 |
| P5. Enforcement hook | pending | — | — | — | PreToolUse `admit` 1개. 초기 warning 모드(exit 0 + stderr) |
| P6. Pilot 1 카테고리 | pending | — | — | — | kubernetes 카테고리 약 10개 전체 변환. activation rate / matching accuracy baseline 1주 수집 |
| P7. 전체 마이그레이션 | pending | — | — | — | 239개 모두 변환. 2 카테고리/주 페이스. 카테고리 PR 단독 revert 가능 |
| P8. Registry-ready 동결 | pending | — | — | — | signature/sandbox 메타 채움. skills.sh 포맷 export script. **Q8 결정**: sigstore cosign vs SLSA provenance |

## Verification 체크리스트 (PoC 10개 후)

- [x] Schema lint exit 0 — 2026-05-05 (`validate-schemas.sh` 3 schema + 2 sample + 10 PoC strict)
- [ ] Probe determinism (10회 hash 일치) — P3
- [ ] Matching accuracy precision ≥ 0.9, recall ≥ 0.85 — P3
- [ ] Adapter parity (claude/codex/cursor diff 0) — P4
- [ ] Hook 동작 (deny 3건, allow 3건) — P5
- [ ] End-to-end init 빈 디렉토리에서 성공 — P3
- [ ] CI drift green — P3 (drift job에 validate-schemas.sh 통합)
- [ ] Multi-AI 동시 사용 시뮬 — P4

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

## 알려진 위험 (해소되면 줄긋기)

- ~~`.codex/agents/*.toml` 변환 로직 소스 미식별~~ — P4 시작 시 1일 spike 필요
- ~~`.agents/skills/`와 `.claude/skills/` 차이~~ — diff 0 확인됨, 단일 SSOT 합치기 안전
- `applies_when.files_contain` regex의 큰 monorepo 성능 — fast-glob `--max-depth 4` cap 권장
- 이중 부담(레포 PoC + 패키지 빌드) 인력 50/50 — 사용자 결정 따른 부담 인정
