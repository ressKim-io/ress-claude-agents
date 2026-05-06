---
date: 2026-05-06
type: meta
phase: 0002-P4-B+C+D+E
related:
  - ../migration/0002-standardization-and-control-plane.md
  - ../migration/0002-progress.md
  - 2026-05-06-p4-step-a-codex-spike.md
  - 2026-05-06-control-plane-step1-5.md
---

# 0002 P4 Multi-AI Adapter 종결 — Step B/C/D/E

P4 Step A spike(`2026-05-06-p4-step-a-codex-spike.md`) 직후 동일 세션에서 B/C/D/E를 한 호흡에 진행. 사용자 의향("쓸데없이 단계 많은 거 아니지?")에 따라 B는 단독, C/D/E는 단일 commit 단위로 묶었다. 본 dev-log는 4 step을 narrative로 보존하고, step별 결정·trade-off·검증 결과를 정리한다.

## 진입 시점 상태

- P3 종료 (commit `810ac58`): control-plane 4 subcommand probe/match/init/lint, 87/87 vitest
- P4 Step A 종료: spike 결과 `.codex/agents/*.toml` 46개 schema 3 키 동질성 + 1:1 매핑 + tomlify 미도입 결정 (progress.md L84-88 P4-A 결정 5건)

## Step B — adapter.ts + 8 vitest

### 파일

- `control-plane/src/adapter.ts` (232줄, 신설)
- `control-plane/src/index.ts` (+~120줄, COMMANDS에 `adapter` 추가, switch + runAdapter + parseAdapterArgs)
- `control-plane/tests/adapter.test.ts` (374줄, 8 케이스)

### API

```ts
export async function adapter(opts: {
  tool: "claude" | "codex" | "cursor";
  root: string;
  assets: string;
  mode?: "write" | "dry-run" | "diff";
}): Promise<AdapterResult>;
```

3 도구 매핑:

| Tool | 입력 | 출력 |
|---|---|---|
| `claude` | `assets/skills/<cat>/<n>/SKILL.md` | `.claude/skills/<cat>/<n>/SKILL.md` (byte-equal copy) |
| `codex` | `.claude/agents/<n>.md` | `.codex/agents/<n>.toml` (3 키 의미 round-trip) |
| `codex` | `assets/skills/<cat>/<n>/SKILL.md` | `.codex/skills/<cat>/<n>.toml` (3 키 + `manifest_yaml='''…'''`로 9 키 보존) |
| `cursor` | `assets/skills/<cat>/<n>/SKILL.md` | `.cursor/rules/<n>.mdc` (`globs: ←applies_when.files_present`, `alwaysApply: false`) |

### 검증 게이트 — byte-exact → 의미 round-trip 정정

Step B 진입 직전 P4-A 결정 #3은 "기존 46개 toml과 round-trip diff 0 게이트"였다. Step B 설계 중 byte-exact는 fragile하다고 판단:

- TOML multi-line basic string 첫 `\n` 무시 규칙 (TOML 1.0 spec)
- yaml frontmatter 인용/순서/quoting 차이가 source 도구마다 다름
- trailing newline 변동

→ **의미 일치 round-trip(parse→data 일치)** 게이트로 변경. progress.md Decision Log P4-B에 정정 박음.

### 의존성 — `tomlify` 미도입

P3 plan(§238-248)에서 후보로 박은 `tomlify`를 도입하지 않고 직접 stringify(50줄 미만, literal `'''` 디폴트, 충돌 시 `"""` + escape fallback). control-plane runtime deps **4/5 유지**(zod·kleur·fast-glob·yaml).

### 9 키 보존 — `manifest_yaml=''…''` 단순화

assets SKILL.md frontmatter는 9 키(`name`/`description`/`version`/`license`/`applies_when`/`portability`/`produces`/`consumes`/`security`). codex toml의 기존 패턴은 3 키. 부착 옵션:

| 옵션 | 코드 | 채택 |
|---|---|---|
| A. TOML table section + sub-table 형태로 풀어쓰기 | 50+ 줄, files_contain record 결정성 까다로움 | ✗ |
| B. body 상단에 메타 헤더 prepend | round-trip 비결정적 | ✗ |
| C. `manifest_yaml='''<frontmatter>'''` 단일 string 보존 | 20줄, 손실 0, P5 hook이 yaml parse 즉시 사용 | ✓ |

Decision log P4-B에 박음. TOML-native 풀어쓰기는 P4 후속 또는 P6 pilot에서 재결정.

### 8 vitest 케이스

1. codex agent 의미 round-trip (parse→data + body 일치, .claude/agents/code-reviewer.md fixture)
2. 재실행 idempotent (status `unchanged`)
3. codex skill `manifest_yaml`로 9 키 보존 (k8s-helm fixture)
4. cursor `globs:` ← applies_when.files_present 4 entries
5. cursor 빈 `globs: []` (synthetic frameworks-only fixture)
6. claude byte-equal copy
7. dry-run 파일 미생성, change 보고만
8. 10x determinism (codex skill content hash 1개)

vitest 87→**95 통과**.

## Step C — AGENTS.md primary 승격 + symlinks

### 흡수

CLAUDE.md(69줄) 4 섹션을 AGENTS.md §"Claude Code-Specific"로 압축 흡수(~30줄):
- Auto-Loaded Rules (12행 표)
- Token Budget (5 bullet)
- Claude-Only Features (5행 표)
- Opus 4.7 Behavioral Notes (5 bullet)

AGENTS.md 254→**312줄**. sweet spot 200줄 룰은 `.claude/rules/`에만 적용되고 AGENTS.md는 별도 — 합리적 크기.

### Self-reference 정정

- L6 ("Claude 전용 최적화는 [CLAUDE.md](CLAUDE.md) 참조") → "본 파일 §Claude Code-Specific 참조. CLAUDE.md는 본 파일의 symlink."
- §Tool-Specific Optimization 표 갱신 (Codex `.codex/AGENTS.md` symlink 추가, Cursor `.cursor/rules/` 추가)
- §Governance SoT 계층: CLAUDE.md를 별개 SoT(L246-247)에서 §Mirrors로 정정

### Symlink 생성

```bash
rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md
ln -s ../AGENTS.md .codex/AGENTS.md
```

git status에서 `T CLAUDE.md` (type changed: 정규 파일 → symlink) 정확히 detect.

### `.gitignore` 정합 — `.codex/` 해제

P4 plan §86-89 ".codex/agents/는 commit 유지" 명시인데 기존 `.gitignore` L34에 `.codex/` 등록되어 46개 .toml + 새 symlink 모두 untracked. **`.codex/` 라인 제거**, `.agents/`만 ignore 유지(P7까지 deprecate).

Decision log P4-C 2건 박음.

## Step D — init.ts step 4 wiring

### 변경

`init.ts` L100-105 stub:
```ts
logs.push({ step: 4, name: "adapter", status: "stub",
  detail: "tool detection deferred to P4" });
```

→
```ts
const detected = detectTools(opts.root);
const adapterRuns: AdapterRunSummary[] = [];
for (const tool of detected) {
  const r = await adapter({ tool, root, assets,
    mode: opts.dryRun ? "dry-run" : "write" });
  adapterRuns.push({ tool, create: ..., update: ..., unchanged: ... });
}
logs.push({ step: 4, name: "adapter",
  status: detected.length > 0 ? "ok" : "skipped",
  detail: ... });
```

`detectTools(root)` = `existsSync(.claude/.codex/.cursor)` 기반 결정적 detection.

### LockFile schema 확장

```ts
adapters: { detected: string[]; status: "p4-stub" }
```

→

```ts
adapters: {
  detected: AdapterTool[];
  status: "p4-active" | "p4-skipped";
  runs?: AdapterRunSummary[];
}
```

`init.test.ts` L99-106 갱신 (`p4-stub` → `p4-skipped` for fixtures without `.claude/.codex/.cursor`) + 신규 detection 테스트 1건. vitest 95→**96 통과**.

## Step E — CI drift job + dual-tree gitignore

### CI workflow 추가

`.github/workflows/ci.yml`의 `drift` job에 4 step 추가:

```yaml
- Setup Node v20 (cache: control-plane/package-lock.json)
- Install control-plane deps (npm ci)
- Build control-plane (npm run build)
- Adapter parity drift (P4):
    for tool in codex cursor; do node dist/cli.js adapter --tool=$tool ...; done
    git diff --quiet -- .codex/skills/ .codex/agents/ .cursor/
```

drift 발견 시 `::error::` + 재현 명령 출력 + exit 1.

### Dual-tree 충돌 회피 — `.claude/skills/<cat>/<n>/SKILL.md` gitignore

첫 로컬 generate 결과 lint 2개 fail:
1. `validate-skill-frontmatter.sh`: `name='k8s-helm'` vs basename `'SKILL'` 불일치 (10건)
2. `generate-inventory-labels.sh validate`: inventory에 `name: SKILL` 항목 추가로 outdated

옵션 A(lint+inventory 갱신 ~30줄) vs 옵션 B(.gitignore + CI drift는 codex/cursor만 검증). plan §86-89는 ".claude/skills/<cat>/<n>.md 단일 파일이 P7까지 살아있음" 명시이므로 단일 파일이 P4 시점 SSoT view. **옵션 B 채택** — `.claude/skills/*/*/SKILL.md` ignore, lint/inventory 무영향. P7 카테고리 마이그레이션 시 단일 파일 삭제와 동시 SKILL.md commit 시작.

Decision log P4-D, P4-E 박음.

### CLI parser `--tool=value` 지원

기존엔 `--tool claude` 띄어쓰기만 가능. 첫 generate 시 사용자(나)가 `--tool=claude`로 호출했다가 "unknown adapter flag" — 즉시 보강. raw 토큰을 첫 `=` 위치에서 분리하는 단순 로직.

## 최종 검증

| 항목 | 결과 |
|---|---|
| `npm run typecheck` | 0 |
| `npm test` | **96/96** (87→96, +9) |
| `npm run build` | ESM 44.71KB, DTS 17.12KB OK |
| `validate-schemas.sh` | 3 schema + 2 sample + 10 PoC PASS |
| `validate-skill-frontmatter.sh all` | OK (Agents 46/46, Skills 25/249, Assets PoC 10/10 strict) |
| `validate-rules-drift.sh` | OK (Phase D 마커 0, AGENTS↔rules 양방향, Critical 11/11) |
| `validate-agent-handoff.sh` | OK (10 workflow 핸드오프 valid) |
| `generate-inventory-labels.sh validate` | OK (inventory-labels.yml up to date) |

push 후 CI drift step에서 actions/setup-node@v4 + control-plane build + adapter parity 검증.

## 결정 8건 (Decision Log 반영)

progress.md Decision Log L84-91에 P4-A(5) + P4-B(2) + P4-C(2) + P4-D(2) + P4-E(2) = **누적 13건** (Step B/C/D/E에서 8건 추가).

## P4 검증 게이트 종결

progress.md Verification 체크리스트:
- [x] Adapter parity (claude/codex/cursor diff 0) — 2026-05-06 P4-E
- [x] Multi-AI 동시 사용 시뮬 — 2026-05-06 P4-D (`init.test.ts` detection 테스트)
- [ ] CI drift green — push 후 GitHub Actions가 검증 (구현 완료, 실행 미)
- [ ] Hook 동작 — P5

## P5 진입 청사진

`adapters.status: p4-active`까지 도달. P5 = `hook.installed: false, status: p5-stub` → `p5-active`.

- PreToolUse hook 1개 (`admit-non-applies-when`)
- 초기 warning 모드 (exit 0 + stderr) — P0 결정 Q5
- Decision log P0의 hook 정책 따라 baseline 1주 후 deny 전환 (P6 pilot 단계)
- LockFile schema에 hook detail 추가 (`installed_path`, `mode: "warn"|"deny"`)

본 commit은 P4 종결. P5는 별도 세션 또는 다음 commit에서 진입.

## 비용

총 작업: ~3시간 (사용자 turn 기준 12 turn 내외, 코드 ~700줄 추가/변경, lint/CI 갱신 ~50줄, dev-log 2건). 단계 4개 묶어 1 commit으로 통합 — 사용자 ROI 우선 정책의 결과.
