---
date: 2026-05-06
type: meta
phase: 0002-P4-A
related:
  - ../migration/0002-standardization-and-control-plane.md
  - ../migration/0002-progress.md
  - 2026-05-06-control-plane-step1-5.md
---

# 0002 P4 Step A — Codex 변환 spike

P3까지 완료된 control-plane(probe/match/init/lint 4 subcommand, 87/87 vitest)이 다음으로 향할 곳은 P4 Multi-AI adapter. 진입 직전, progress.md L86의 알려진 위험 1건 — **".codex/agents/*.toml 변환 로직 소스 미식별 — P4 시작 시 1일 spike 필요"** — 을 해소해야 P4 Step B(adapter subcommand) 설계가 막히지 않는다.

본 dev-log는 spike의 조사 경로·발견·결정 5건을 narrative로 보존한다. 결정 자체는 progress.md Decision Log에 1줄씩 박았다.

## 진입 시점 상태

- P3 종료: commit `810ac58` (lint shell delegation), `f0b0c83`→`810ac58` 구간에 step 1~5
- P4 plan(`docs/migration/0002-standardization-and-control-plane.md` §226-236):
  - 출력: `.cursor/rules/`, AGENTS.md primary, CLAUDE.md→symlink, `.codex/skills/<cat>/<n>.toml` 신설
  - 검증: adapter parity diff 0 + CI drift green
  - 명시적 메모: "기존 `.codex/agents/*.toml` 변환 로직 흡수"
- 미해결: 흡수할 "변환 로직"의 소스 위치, 의존성 정책 영향, assets 9 키 frontmatter ↔ codex 3 키 toml의 메타 처리

## 조사 경로

### 1. 기존 .toml schema 전수 조사

```bash
for f in .codex/agents/*.toml; do
  grep -E '^[a-z_]+ ?=' "$f" | sed 's/ *=.*//' | sort -u
done | sort | uniq -c | sort -rn
```

처음 결과는 **100+ top-level 키**처럼 보였다 — `max_connections`, `work_mem`, `shared_buffers`, `innodb_*`, `mypy.ini`의 `disallow_*` 등이 잡혔다. database-expert·python-expert 같은 에이전트의 `developer_instructions` 본문 안에 코드 블록이 들어있었고, line-start `key =` 패턴이 grep에 걸린 false positive.

`name`/`description`/`developer_instructions` 3개만 정확히 46/46이고 나머지는 모두 1~2회 — 즉 본문 코드 블록 내부의 설정 라인. 실제 schema는 3 키 only.

### 2. 멀티라인 delimiter 분포

```bash
grep -l '"""' .codex/agents/*.toml | wc -l   # 27
ls .codex/agents/*.toml | wc -l              # 46
# → 19개는 ''' (literal string)
```

TOML 1.0:
- `"""..."""` = multi-line basic string (escape 처리)
- `'''...'''` = multi-line literal string (escape 없음, raw)

본문에 backslash·큰따옴표가 다수(코드 블록, regex, 한국어 quote) → **literal `'''` 디폴트**가 안전. body 자체가 `'''` 포함하는 corner case에만 `"""` + escape fallback.

### 3. 변환 로직 소스 검색 (네거티브 결과)

```bash
grep -rln "codex/agents\|developer_instructions" scripts/ .github/ Makefile* 2>/dev/null
git log --oneline --all -- .codex/
```

둘 다 비었다. `scripts/`에도 `.github/`에도 변환 코드 없음, git log도 commit history가 거대 단일 commit에 묻혔거나 외부에서 수작업 commit. 즉 기존 46개 .toml은 **외부/수작업 결과물만 commit** 상태.

→ "흡수할 로직"은 사실상 부재. P4 Step B가 첫 자동화. 기존 46개 .toml은 **round-trip 검증 fixture**(자동 변환 결과 vs commit된 toml diff 0 게이트)로 재활용한다.

### 4. source ↔ target 매핑 검증

```bash
comm -12 <(ls .claude/agents/*.md | xargs -n1 basename | sed "s/\.md$//" | sort) \
         <(ls .codex/agents/*.toml | xargs -n1 basename | sed "s/\.toml$//" | sort) | wc -l
# → 46
```

파일명 set 완전 일치, 누락 0건. `.claude/agents/code-reviewer.md` frontmatter는 `name`/`description`/`tools`/`model` 4 키 + body. 변환 매핑:

| `.claude/agents/<n>.md` | `.codex/agents/<n>.toml` |
|---|---|
| frontmatter `name` | `name` |
| frontmatter `description` | `description` |
| markdown body (frontmatter 제외) | `developer_instructions = '''…'''` |
| frontmatter `tools` / `model` | **drop** — Codex는 도구 권한 메커니즘이 다름 |

### 5. 의존성 영향 평가

control-plane 현재 deps: `zod`/`kleur`/`fast-glob`/`yaml` = **4/5** (정책 ≤ 5).

P3 plan(§238-248)이 박은 후보 `tomlify`를 도입하면 5/5로 ceil. 그런데 처리 대상이 3 string 키뿐이고 literal-string 디폴트라 stringify 로직이 단순:

```ts
// 의사코드 — adapter.ts에 50줄 미만으로 구현 가능
function stringifyCodex(name: string, description: string, body: string): string {
  const useBasic = body.includes("'''");
  const delim = useBasic ? '"""' : "'''";
  const safeBody = useBasic ? body.replace(/"""/g, '\\"\\"\\"') : body;
  return `description = ${quote1(description)}\n` +
         `developer_instructions = ${delim}\n${safeBody}\n${delim}\n` +
         `name = ${quote1(name)}\n`;
}
```

`tomlify` 미도입 → deps 4/5 유지. round-trip 검증이 stringify 결정성을 보장하니 의존성 1개 절약이 합리적.

### 6. assets 9 키 → codex toml 메타 처리 (3 옵션)

assets SKILL.md frontmatter는 9 키: `name`/`description`/`version`/`license`/`applies_when`/`portability`/`produces`/`consumes`/`security`. 기존 codex agents toml은 3 키뿐.

| 옵션 | 장점 | 단점 |
|---|---|---|
| **A. 9 키 그대로 toml에 부착** | round-trip 손실 0, 다른 도구도 같은 toml 재사용 가능 | Codex 미인식 키가 parse 에러 유발 가능성 (도구 정책 의존) |
| B. body 상단에 메타 헤더 prepend | Codex 100% 호환 (3 키만 인식) | round-trip 시 body에서 메타 회수가 비결정적, lint 규칙 복잡 |
| C. 부가 메타 drop, 3 키만 출력 | 가장 안전 | view 빈약, parity 검증 시 정보 손실, P5 hook이 applies_when 못 봄 |

**채택: A**. Codex toml reader는 일반적으로 unknown 키 무시(TOML 표준 자체는 strict이나 도구가 관대). round-trip 손실 0이 P4 검증 게이트(diff 0)와 가장 잘 맞는다. Codex parse 에러 발견 시 P5 hook 단계에서 회귀 — risk를 명시적으로 인지한 채 진행.

## 결정 5건 (Decision Log 반영)

본 spike의 5 결정은 progress.md Decision Log L84-88에 1줄씩 박았다. 요지:

1. **schema = 3 키 only** (기존 46개 변형 0건 확인)
2. **delimiter 디폴트 `'''`** (literal, escape 회피, 한국어 안전)
3. **1:1 매핑**(.claude/agents ↔ .codex/agents 46↔46), `tools`/`model` drop
4. **`tomlify` 미도입**, 직접 stringify (50줄 미만, deps 4/5 유지)
5. **9 키 그대로 toml에 부착** (옵션 A, round-trip 손실 0 우선)

알려진 위험 1건(L86) 줄긋기 갱신: spike 결과 메모 추가, 기존 46개를 round-trip fixture로 재활용한다고 명시.

## 다음 (Step B 진입 청사진)

`control-plane/src/adapter.ts` 신설:

```
adapter(input: AdapterInput): AdapterOutput
  - tool: "claude" | "codex" | "cursor"
  - source: assets/skills/<cat>/<n>/SKILL.md (또는 .claude/agents/<n>.md)
  - target: 도구별 view 경로
  - mode: "write" | "dry-run" | "diff"
```

CLI 라우팅: `claude-agents adapter --tool=<t> [--root=<p>] [--dry-run|--diff]`

검증 fixture 3종:
1. `.claude/agents/code-reviewer.md` → `.codex/agents/code-reviewer.toml` **round-trip diff 0** (기존 commit과 byte 동일)
2. `assets/skills/kubernetes/k8s-helm/SKILL.md` → `.codex/skills/kubernetes/k8s-helm.toml` **신규 생성**, 9 키 부착
3. 동일 source → `.cursor/rules/k8s-helm.mdc` **신규 생성**, frontmatter `globs:` ← `applies_when.files_present`

이후 Step C(AGENTS.md primary 승격 + CLAUDE.md→AGENTS.md symlink), Step D(init.ts step 4 stub → 실제 adapter 호출), Step E(CI drift job — adapter 결과 ↔ commit view diff 0 게이트).

## 비용

본 spike: ~30분 조사 + 결정 정리. 1일 예산(progress.md L86)의 6% 사용. 변환 로직 부재 확인이 빨랐고(grep 2회 + git log), schema 동질성도 1 query로 확정 — 16,400+ 줄 .toml 본문에 false-positive 키가 다수였지만 false-positive 판별 자체가 5분.
