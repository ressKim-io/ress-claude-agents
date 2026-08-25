# Multi-Tool Adapter Rules

이 레포의 자산을 여러 AI 코딩 도구(Claude Code / Codex / Cursor / Kiro 등)에 배치할 때 지키는 거버넌스 원칙.
상세 매핑 표와 도구별 변환 규칙은 [`docs/architecture/multi-tool-mapping.md`](../../docs/architecture/multi-tool-mapping.md) 참조.

---

## 원본은 하나 (MANDATORY)

- **SSOT 는 `AGENTS.md` + `.claude/**` + `assets/skills/**`** 뿐이다. 도구별 디렉토리(`.cursor/` `.kiro/`)는 **전부 산출물(view)** 이다.
- NEVER 도구별 디렉토리를 직접 편집. 원본을 고치고 변환을 다시 돌린다.
- `CLAUDE.md` 는 `AGENTS.md` 의 symlink — 직접 편집 금지.
- 도구별 view 만 고친 변경은 다음 변환에서 **소실**된다.

## 자동 변환 vs 수동 port

| 도구 | 방식 | 근거 |
|---|---|---|
| Cursor | **자동** — `control-plane/src/adapter.ts` | 형식 변환 필요 (`.mdc`) |
| Kiro | **수동** | AGENTS.md·SKILL.md 표준을 그대로 인식 → 자동화 ROI 낮음 ([ADR 0006](../../docs/adr/0006-kiro-adapter-strategy.md) Option 1) |
| Codex / Copilot / Gemini CLI / Windsurf | **불필요** | `AGENTS.md` 자동 인식 |

```bash
node control-plane/dist/cli.js adapter --tool=cursor --mode=diff   # 미리보기
node control-plane/dist/cli.js adapter --tool=cursor --mode=write  # 반영
```

- MUST 원본 자산 변경 후 **같은 PR에서** 변환을 재실행한다. CI drift job 이 `.cursor/` 산출물의 git diff 를 게이트하므로 누락 시 fail.
- NEVER adapter 에 도구를 추가하기 전에 ADR 로 ROI 를 먼저 판단한다 (Kiro 선례).

### 도구를 뺄 때도 ADR 을 쓴다

Codex 는 2026-08-25 에 제거됐다 ([ADR 0010](../../docs/adr/0010-drop-codex-support.md)). **추가할 때만 판단하고 뺄 때는 방치하면, 유지되지 않는 산출물이 SSOT 인 척 남는다** — 실제로 `.codex/agents/` 는 3개월간 재생성되지 않아 원본과 다른 내용을 담고 있었다. 도구별 view 는 **재생성 실적이 유지 근거**다. 분기 review 에서 "이 도구의 산출물이 최근 원본 변경을 따라갔는가" 를 함께 본다.

## 신규 도구 합류 절차

1. 공식 docs 로 자산 형식 **검증** — `deep-thinking.md` 의 출처 기록 의무 적용 (URL + 검증일 + ✅/⚠️)
2. 기존 표준(AGENTS.md / SKILL.md) 인식 여부 확인 → 인식하면 **수동 가이드**, 아니면 adapter 확장 검토
3. ADR 작성 (대안 비교 + 트레이드오프)
4. `docs/architecture/multi-tool-mapping.md` 에 열 추가
5. 본 파일과 AGENTS.md §Tool-Specific 에 1줄 추가
6. **분기별 사양 review 일정을 ADR Sources 에 명시** — 외부 도구 사양은 변한다

## 외부 도구 사양은 분기별 재검증 (MANDATORY)

도구 사양은 cutoff 이후 바뀐다. 실제 사례 — 2026-08 Kiro review 에서 3개월 만에 발견된 변경:

- Subagents 문서 URL 이동 (`/docs/chat/subagents/` → `/docs/custom-agents/subagents/`)
- agent 설정 필드 대폭 확장, `toolsSettings` **deprecated** → `permissions`

MUST 매핑 문서의 각 항목에 **✅ verified / ⚠️ unverified + 사유**를 표기하고 검증일을 남긴다. 미검증 항목은 해당 자산 port 착수 전 재확인한다.

## 자산 단위로 가져간다 (picky 운영)

- PREFER 도구에 자산을 옮길 때 **필요한 것만** 고른다. 묶음 전체 복사 금지 — "안 쓰는 것까지 다 깔린다" 가 [ADR 0007](../../docs/adr/0007-install-sh-narrow-scope.md) 의 출발점이었다.
- `install.sh --skill <cat>/<name>` / `--agent <name>` / `--rule <name>` 이 이 용도다 (⚠️ PR-8 미착수 — 현재는 수동 복사).

## 도구 간 강제력 차이 인지

같은 규약이라도 도구에 따라 **강제력이 다르다.**

| 이 레포 | 성격 | Kiro 대응 | 성격 |
|---|---|---|---|
| AGENT-SPEC §Permission Boundary | 산문 규약 (모델이 읽고 따름) | `permissions` | **실행 강제** |
| rule 의 "path-scoped" 표기 | 산문 | steering `fileMatch` + `fileMatchPattern` | **자동 로딩 조건** |

MUST port 시 산문 규약을 대상 도구의 **강제 메커니즘으로 승격**할 수 있는지 검토한다. 강제로 옮기면 규약 위반이 구조적으로 차단된다.

---

## 관련 문서

- [`docs/architecture/multi-tool-mapping.md`](../../docs/architecture/multi-tool-mapping.md) — 3 도구 매핑 표 + Kiro port 규칙 + 검증 상태
- [ADR 0006](../../docs/adr/0006-kiro-adapter-strategy.md) — Kiro 수동 매핑 결정 + 분기 review 기록
- [ADR 0007](../../docs/adr/0007-install-sh-narrow-scope.md) — install.sh 자산 단위 옵션
- [ADR 0010](../../docs/adr/0010-drop-codex-support.md) — Codex 지원 중단
- [`deep-thinking.md`](deep-thinking.md) — 외부 사양 검증 의무
- `control-plane/src/adapter.ts` — 자동 변환 구현
