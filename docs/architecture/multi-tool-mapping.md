# 다도구 자산 매핑 (Claude Code / Cursor / Kiro)

이 레포의 자산을 3개 AI 코딩 도구에 배치하는 매핑 표와 변환 규칙.

> ⛔ **Codex 지원 중단 (2026-08-25, [ADR 0010](../adr/0010-drop-codex-support.md))**: `.codex/` 산출물과 adapter 의 codex 경로를 제거했다. Codex 는 `AGENTS.md` 를 자동 인식하므로 **추가 설정 없이 계속 쓸 수 있다** — 없어진 것은 `.toml` view 뿐이다.
[ADR 0006](../adr/0006-kiro-adapter-strategy.md) PR-2 산출물. 거버넌스 원칙은 [`.claude/rules/multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md) 참조.

> **검증일 2026-08-16** — Kiro 사양은 공식 docs WebFetch 로 확인 (ADR 0006 §분기 review 2026-08 회차). 항목별 ✅/⚠️ 는 [§5](#5-검증-상태) 참조.

---

## 1. SOT 계층

```
AGENTS.md                    ← 보편 가이드. 모든 도구가 자동 인식 (Linux Foundation 표준)
  └── CLAUDE.md              symlink
.claude/**                   ← Claude Code 원본 자산 (SSOT view)
assets/skills/**/SKILL.md    ← tool-agnostic source. adapter 입력 (Migration 0002 목표 SSOT)
  ├── .cursor/   (자동)      adapter --tool=cursor
  └── .kiro/     (수동)      ADR 0006 Option 1 — adapter 미지원
```

**변환 주체**: `control-plane/src/adapter.ts`. 지원 도구는 **`cursor` 하나뿐**이다.

- **Kiro** 는 의도적으로 제외됐다 (ADR 0006 Option 1 — AGENTS.md·SKILL.md 표준을 그대로 인식해 변환 ROI 가 낮다)
- **Codex** 는 2026-08-25 에 제거됐다 ([ADR 0010](../adr/0010-drop-codex-support.md) — 같은 이유 + 유지 실패 실적)
- **`claude` 는 애초에 adapter 대상이 아니다.** `.claude/**` 는 view 가 아니라 SSOT 다 (AGENTS.md §Governance). 이전 구현은 `.claude/skills/<category>/<name>/SKILL.md` 라는 **Claude Code 가 로드하지 않는 2단계 경로**(audit F1/F2)에 파일을 만들었고, Step 2 가 그 경로의 `.gitignore` 규칙까지 지워서 `init` 한 번에 죽은 파일이 커밋 대상이 됐다 — 2026-08-26 PR #36 리뷰에서 제거

---

## 2. 자산 종류별 매핑

> 개수는 이 표에 박지 않는다 (drift 원인). 현재 수치는 `yq '.summary' .claude/inventory.yml`.

| 자산 | Claude Code | Cursor | Kiro | Codex / Copilot / Gemini CLI / Windsurf |
|---|---|---|---|---|
| **보편 가이드** | `AGENTS.md` (`CLAUDE.md` symlink) | `AGENTS.md` 자동 인식 | `AGENTS.md` 워크스페이스 루트 자동 인식 | `AGENTS.md` 자동 인식 |
| **Agent** | `.claude/agents/*.md` | — (대응 개념 없음) | `.kiro/agents/*.{md,json}` (수동) | — |
| **Skill** | `.claude/skills/<name>/SKILL.md` | `.cursor/rules/*.mdc` | `.kiro/skills/<name>/SKILL.md` (수동) | — |
| **Rule** | `.claude/rules/*.md` | `.mdc` frontmatter `globs`/`alwaysApply` | `.kiro/steering/*.md` (`inclusion` 4 모드) | AGENTS.md 에 흡수 |
| **Command** | `.claude/commands/**/*.md` | — | — | — |
| **MCP** | `mcp-configs/settings.json` (설치용 템플릿, `mcpServers` 키) | — | `.kiro/settings/mcp.json` (workspace) / `~/.kiro/settings/mcp.json` (global) | 도구별 자체 설정 |
| **Spec/워크플로우** | `.claude/workflows/*.yml` | — | `.kiro/specs/<feat>/` (requirements/design/tasks) ⚠️ | — |

### 개수 격차의 원인

Cursor 쪽 `.mdc` 가 Claude 쪽 skill 보다 훨씬 적은 것은 누락이 아니다. adapter 는 `assets/skills/` 를 입력으로 받는데 **Migration 0002 P7(전체 변환)이 미완**이라 일부만 변환돼 있다.

**2026-08-24 갱신**: Claude 쪽 260개는 `.claude/skills/<name>/SKILL.md` 규격으로 이관을 마쳤다. 이전의 `<카테고리>/<이름>.md` 레이아웃은 Claude Code 가 로드하지 않는 경로였다 — 즉 260개가 실제로는 동작하지 않았다. 카테고리는 frontmatter `category:` 로 보존한다.

따라서 P7 의 남은 범위는 **Claude 레이아웃 이관이 아니라 `assets/skills/` → cursor 변환분 확대**뿐이다 (codex 는 ADR 0010 으로 범위에서 빠졌다).

→ 추적: [2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) (F1 / F2), [2026-08-15 audit §8](../audit/2026-08-15-asset-tier-rebalance.md#8-선행-백로그-인수-b-트랙)

---

## 3. Kiro 수동 port 규칙

Kiro 는 Anthropic Agent Skills 표준과 AGENTS.md 표준을 그대로 인식하므로 **본문 변환이 거의 없다.** 경로 이동과 frontmatter 키 대응만 필요하다.

### 3.1 Skill → `.kiro/skills/`

```
.claude/skills/<cat>/<name>.md   →   .kiro/skills/<name>/SKILL.md
assets/skills/<cat>/<name>/SKILL.md →  .kiro/skills/<name>/SKILL.md   (그대로 복사)
```

| Kiro 요구사항 | 이 레포 자산 | 조치 |
|---|---|---|
| 폴더명 = `name` | `assets/` 는 이미 폴더형 | 그대로 |
| `name` 필수, ≤64자, 소문자+숫자+하이픈 | `skill-manifest.v1.json` 이 동일 제약 (`^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$`) | **호환** |
| `description` 필수, ≤1024자 | 동일 schema 에 `maxLength: 1024` | **호환** |
| 선택 필드 `license` / `compatibility` / `metadata` | `license` 만 대응 | 나머지 무시 |

> 이 레포의 skill schema 가 Kiro 요구사항의 상위집합이라 **`assets/skills/` 자산은 무변환 복사로 동작한다.** 단일 파일 형식(`.claude/skills/<cat>/<name>.md`)은 폴더로 감싸야 한다.

### 3.2 Rule → `.kiro/steering/`

Kiro steering 의 `inclusion` 4 모드에 이 레포 rule 성격을 대응시킨다.

| 이 레포 rule 성격 | Kiro `inclusion` | frontmatter |
|---|---|---|
| 항상 적용 (`clean-code`, `workflow`, `security`, `deep-thinking` 등) | `always` (기본) | `inclusion: always` |
| path-scoped (`istio`, `k8s-manifest`, `terraform`, `devlog-lifecycle`) | `fileMatch` | `inclusion: fileMatch` + `fileMatchPattern: "<glob>"` |
| 드물게 참조 (`professional-writing`) | `manual` | `inclusion: manual` → 채팅에서 `#<name>` |
| 설명 매칭으로 자동 (`effort-guide` 류) | `auto` | `inclusion: auto` + `name` + `description` |

AGENTS.md §Auto-Loaded Rules 표의 "path-scoped" 표기가 `fileMatchPattern` 으로 그대로 옮겨진다.

### 3.3 Agent → `.kiro/agents/`

`.kiro/agents/` 는 **JSON 과 Markdown 양쪽**을 지원한다. Markdown 형식이 이 레포 자산과 가깝다.

| 이 레포 (`.claude/agents/*.md`) | Kiro | 비고 |
|---|---|---|
| `name` | `name` | 생략 시 파일명에서 유도 |
| `description` | `description` | 그대로 |
| 본문 (system prompt) | 본문 또는 `prompt` | `file://` URI 도 가능 |
| `tools:` 목록 | `tools` | 도구명 체계가 다르므로 **수동 대조 필요** |
| `model: sonnet` | `model` | 모델 ID 표기 상이 — 미지원 시 기본값 fallback |
| (없음) | `allowedTools` / `permissions` | Kiro 고유. `permissions` 로 shell/fs 규칙 표현 |
| (없음) | `hooks` / `resources` / `mcpServers` | Kiro 고유 |

> ⚠️ **2026-08 변경**: `toolsSettings` 는 deprecated 이며 `permissions` 로 대체됐다. 2026-05-20 검증본에는 없던 필드가 다수 추가됐으므로 port 시 [configuration-reference](https://kiro.dev/docs/custom-agents/configuration-reference/) 를 재확인한다.
>
> 이 레포의 AGENT-SPEC §"Permission Boundary" 섹션은 **산문 규약**이고 Kiro `permissions` 는 **실행 강제**다. port 시 산문을 `permissions` 규칙으로 옮기면 강제력이 생긴다.

---

## 4. 자동 변환 세부 (Cursor)

`control-plane/src/adapter.ts` 동작:

| 도구 | 산출 | 형식 |
|---|---|---|
| `cursor` | `.cursor/rules/<name>.mdc` | frontmatter `description` + `globs` + `alwaysApply`, 이후 본문 |

**Cursor `globs` 는 `applies_when.files_present` 에서 파생된다** (`adapter.ts` L161). 따라서 `applies_when` 이 없는 skill 은 Cursor 에서 자동 활성화 트리거를 갖지 못한다. 현재 `.claude/skills/` 260개 중 `applies_when` 보유는 0개다.

`alwaysApply` 는 **항상 `false` 로 하드코딩**된다 (`adapter.ts` L285). 즉 현재 adapter 는 Cursor 의 "항상 적용" 룰을 생성하지 않으며, 이 레포의 always-on rule 25개는 Cursor 에서 `AGENTS.md` 자동 인식에만 의존한다.

```bash
node control-plane/dist/cli.js adapter --tool=cursor --diff    # 변경 미리보기
node control-plane/dist/cli.js adapter --tool=cursor   # 반영
```

CI drift job 이 `.cursor/` 산출물의 git diff 를 게이트한다.

---

## 5. 검증 상태

| 항목 | 상태 | 출처 (검증일 2026-08-16) |
|---|---|---|
| Steering 4 모드 + 경로 | ✅ | https://kiro.dev/docs/steering/ |
| Skills 폴더+SKILL.md, 필수 2키 | ✅ | https://kiro.dev/docs/skills/ |
| MCP 경로 (workspace 우선 merge) | ✅ | https://kiro.dev/docs/mcp/configuration/ |
| Agent 디렉토리·형식·필드 | ✅ | https://kiro.dev/docs/custom-agents/configuration-reference/ |
| Subagents 문서 위치 | ⚠️ 이동 | 구 `/docs/chat/subagents/` → https://kiro.dev/docs/custom-agents/subagents/ |
| Specs 경로 `.kiro/specs/<feat>/` + EARS | ⚠️ **미검증** | `/docs/specs/` 에 3파일 구성만 기재. 디렉토리 경로·EARS 언급 없음. `/docs/specs/concepts/` 는 HTTP 404 |
| Cursor 산출 형식 | ✅ | `control-plane/src/adapter.ts` + 실제 산출물 직접 확인 |

**미검증 항목 처리**: Specs 는 PR-7(`.claude/templates/kiro-spec/` 3종) 착수 전 재확인한다. 본 문서는 Specs 를 매핑 대상에서 잠정 제외한다 — 이 레포에 대응 자산(`workflows/*.yml`)이 있으나 형식이 달라 1:1 매핑이 성립하지 않는다.

다음 분기 review: **2026-11** (ADR 0006 Sources 일정).

---

## 6. 참조

- [ADR 0006 — Kiro 어댑터 전략](../adr/0006-kiro-adapter-strategy.md) — Option 1(수동) 채택 근거 + 분기 review 기록
- [ADR 0007 — install.sh 축소](../adr/0007-install-sh-narrow-scope.md) — `--skill` 옵션이 자산 port 1단계로 결합 (PR-8 미착수)
- [`.claude/rules/multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md) — 거버넌스 원칙 (본 문서의 rule 판)
- [2026-08-15 audit §8](../audit/2026-08-15-asset-tier-rebalance.md#8-선행-백로그-인수-b-트랙) — PR-5~8 백로그 추적
- [ADR 0010 — Codex 지원 중단](../adr/0010-drop-codex-support.md) — `.codex/` 및 adapter codex 경로 제거 근거
- `control-plane/src/adapter.ts` — 자동 변환 구현
