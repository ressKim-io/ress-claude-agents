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
| P0. 영구 기록 + commit | **in_progress** | 2026-05-05 | — | main | 본 문서 + 0002 본문 + dev log 생성 중 |
| P1. Schema 동결 | pending | — | — | — | `schemas/skill-manifest.v1.json` + `project-profile.v1.json` + `agent-manifest.v1.json`. JSON Schema lint + `source-command-log-summary` validate 통과 |
| P2. PoC 10개 변환 | pending | — | — | — | k8s 5 + go 5. 후보: k8s-autoscaling, k8s-helm, k8s-security, k8s-scheduling, k8s-traffic / go-testing, go-database, go-microservice, go-errors, go-gin |
| P3. Control plane PoC | pending | — | — | — | `@ress/claude-agents` CLI 4 subcommand (probe/match/init/lint), TS+Node 18+ ESM. tsup ESM 번들 |
| P4. Multi-AI adapter | pending | — | — | — | `.cursor/rules/` 자동 생성, AGENTS.md primary 승격, CLAUDE.md→symlink. 기존 `.codex/agents/*.toml` 변환 로직 흡수 |
| P5. Enforcement hook | pending | — | — | — | PreToolUse `admit` 1개. 초기 warning 모드(exit 0 + stderr) |
| P6. Pilot 1 카테고리 | pending | — | — | — | kubernetes 카테고리 약 10개 전체 변환. activation rate / matching accuracy baseline 1주 수집 |
| P7. 전체 마이그레이션 | pending | — | — | — | 239개 모두 변환. 2 카테고리/주 페이스. 카테고리 PR 단독 revert 가능 |
| P8. Registry-ready 동결 | pending | — | — | — | signature/sandbox 메타 채움. skills.sh 포맷 export script. **Q8 결정**: sigstore cosign vs SLSA provenance |

## Verification 체크리스트 (PoC 10개 후)

- [ ] Schema lint exit 0
- [ ] Probe determinism (10회 hash 일치)
- [ ] Matching accuracy precision ≥ 0.9, recall ≥ 0.85
- [ ] Adapter parity (claude/codex/cursor diff 0)
- [ ] Hook 동작 (deny 3건, allow 3건)
- [ ] End-to-end init 빈 디렉토리에서 성공
- [ ] CI drift green
- [ ] Multi-AI 동시 사용 시뮬

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

## 알려진 위험 (해소되면 줄긋기)

- ~~`.codex/agents/*.toml` 변환 로직 소스 미식별~~ — P4 시작 시 1일 spike 필요
- ~~`.agents/skills/`와 `.claude/skills/` 차이~~ — diff 0 확인됨, 단일 SSOT 합치기 안전
- `applies_when.files_contain` regex의 큰 monorepo 성능 — fast-glob `--max-depth 4` cap 권장
- 이중 부담(레포 PoC + 패키지 빌드) 인력 50/50 — 사용자 결정 따른 부담 인정
