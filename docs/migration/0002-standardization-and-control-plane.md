# Migration 0002 — Standardization & Control Plane

| Field | Value |
|---|---|
| Status | **Proposed** |
| Date | 2026-05-05 |
| Author | ressKim |
| Supersedes | — |
| Superseded by | — |
| Plan source | `~/.claude/plans/plan-rippling-spindle.md` (휘발 가능 — 본 문서가 영구 사본) |
| Progress tracker | [`0002-progress.md`](./0002-progress.md) |
| Start dev-log | [`../dev-logs/2026-05-05-control-plane-poc-start.md`](../dev-logs/2026-05-05-control-plane-poc-start.md) |

---

## Context

이 레포(`/Users/ress/my-file/ress-claude-agents`)는 현재 Claude Code 전용 skill(239개)·agent(46개) 모음이지만, **다른 프로젝트에 install해서 쓰는 "휴대용 표준 인덱스 패키지"**가 되는 게 진짜 목표다. 핵심 통찰 4가지로부터 출발:

1. **LLM은 비결정적 옵티마이저** → 자산 매칭을 LLM 밖으로 빼고 결정적 scheduler로 만들어야 표준화 가능. RDB 옵티마이저처럼 통계가 정확해서 결정적인 것과 같은 원리.
2. **K8s scheduler/admission webhook과 1:1 매칭됨** → klaw / Gas Town / Context Kubernetes 같은 선례가 이미 동일 방향. 비유 정확.
3. **Skill activation 50% "동전 던지기" 문제** (GitHub issue [anthropics/claude-code#38588](https://github.com/anthropics/claude-code/issues/38588) 외 다수) → directive description 스타일로 100%까지 끌어올린 사례 존재. 추가로 PreToolUse hook이 admission webhook 자리.
4. **Multi-AI 시대** → SKILL.md + AGENTS.md 조합이 사실상 8개 도구(Claude/Codex/Cursor/Copilot/Windsurf/Gemini/Cline/Goose) 자동 호환. Claude 락인 회피 가능.

5층 구조 채택: ① Asset Capability Manifest → ② Project Probe → ③ Matching Rule (scheduler) → ④ Bootstrap CLI → ⑤ Enforcement (PreToolUse hook).

## 검증된 전제

| 항목 | 확정 사실 |
|---|---|
| Skills frontmatter | 239개 중 **표준 1개**(`source-command-log-summary/SKILL.md`, name+description만) — 사실상 0%. PoC 시작점 |
| Agents frontmatter | **46개 100%** (name/description/tools/model). description은 directive 스타일 ("Use PROACTIVELY after K8s manifest changes") — 거의 ready |
| 도구별 디렉토리 | `.codex/agents/*.toml` **46개 이미 존재** (description + developer_instructions). adapter pipeline 부분 가동 중. `.cursor/rules/`만 신설 필요 |
| dual tree | `.claude/skills/go/go-testing.md` ≡ `.agents/skills/go/go-testing.md` (diff 0) — mirror 관계, 안전 통합 가능 |
| hooks | `.claude/settings.local.json` 에 permissions만, **hooks 블록 absent** — PreToolUse 자리 완전 공백 |
| 인프라 | 5종 lint + CI drift job 견고. `_handoff.yml`(43 artifact 어휘), `inventory-labels.yml`(portability/model_dependency/domain_specificity 라벨) 가동 중 |

## 사용자 결정 (확정)

1. **레포 구조**: monorepo 유지 + 내부 재배치. AGENTS.md primary 승격, CLAUDE.md → symlink
2. **Multi-AI 우선순위**: Claude + Codex + Cursor 3개 1차 검증·문서 집중 (어차피 8개 도구 자동 호환)
3. **Control plane 패키징**: 처음부터 별도 패키지(`@ress/claude-agents`). PoC와 빌드 파이프라인 동시 진행 — 이중 부담 인정
4. **Registry publish**: 포맷 100% 호환만 유지, 즉시 publish X. SKILL.md + AGENTS.md + applies_when 100% 준수해서 언제든 publish 가능 상태로. 보안 메타(signature, sandbox flag) 포맷에 미리 박아두기. publish 우선순위는 skills.sh > Lobehub. ClawHub 보류(crypto mining swarm 사건)

## Phase 분할 (입력/출력/검증 게이트)

| Phase | 출력 | 검증 게이트 |
|---|---|---|
| **P1. Schema 동결** | `schemas/skill-manifest.v1.json`, `project-profile.v1.json`, `agent-manifest.v1.json` | JSON Schema lint 통과, `source-command-log-summary`가 새 schema validate 통과 |
| **P2. PoC 10개 변환** | k8s 5 + go 5을 `<skill>/SKILL.md` 디렉토리화, frontmatter 채움 | (a) `validate-skill-frontmatter.sh` strict 통과, (b) matching CLI dry-run에서 4 gold profile에 기대 skill hit |
| **P3. Control plane PoC** | `@ress/claude-agents` CLI 4 subcommand (probe/match/init/lint), TS+Node 18+ ESM | 가짜 프로젝트 3종(k8s helm / go gin / 빈) init 결과 diff snapshot 일치 |
| **P4. Multi-AI adapter** | `.cursor/rules/` 자동 생성, AGENTS.md primary 승격, CLAUDE.md → symlink | adapter generate 후 3 도구에 동일 skill set 노출 (lint 신설) |
| **P5. Enforcement hook** | PreToolUse `block-non-applies-when` 1개 | 위배 3건 정확히 deny, 정상 3건 allow. **초기 warning 모드, baseline 후 deny 전환** |
| **P6. Pilot 1 카테고리** | kubernetes 카테고리(약 10개) 전체 변환 | activation rate / matching accuracy baseline 1주 수집 |
| **P7. 전체 마이그레이션** | 239개 모두 변환 (2 카테고리/주) | drift CI green 유지, 카테고리 PR 단독 revert 가능 |
| **P8. Registry-ready 동결** | signature/sandbox 메타 채움, packaging | skills.sh 포맷 export script zero-error |

각 phase 게이트 미달 시 다음 진입 금지(기존 5종 lint와 동일 원칙).

## 디렉토리 reshape

```
BEFORE                                AFTER (P4 종료 시)
ress-claude-agents/                   ress-claude-agents/
├─ AGENTS.md (254줄, primary)         ├─ AGENTS.md            ← primary (승격)
├─ CLAUDE.md (69줄, 분리)             ├─ CLAUDE.md → AGENTS.md (symlink)
├─ .claude/skills/<cat>/<n>.md        ├─ assets/                    ← 신설: AI-도구 중립 SSOT
├─ .claude/agents/<n>.md              │  ├─ skills/<cat>/<n>/SKILL.md  (frontmatter 필수)
├─ .agents/skills/...    (mirror)     │  │     └─ resources/, scripts/  (선택)
├─ .codex/agents/*.toml  (46개)       │  ├─ agents/<n>/AGENT.md
├─ plugins/*.yml                      │  └─ rules/<n>.md
├─ scripts/validate-*.sh              ├─ adapters/                  ← 신설: 도구별 view 자동 생성
├─ docs/inventory*.yml                │  ├─ claude/  (.claude/ 호환 layout)
└─ .github/workflows/ci.yml           │  ├─ codex/   (기존 .codex/ 갱신, 변환 로직 흡수)
                                      │  └─ cursor/  (.cursor/rules/*.mdc)
                                      ├─ control-plane/             ← 신설: 별도 npm 패키지
                                      │  ├─ package.json (@ress/claude-agents)
                                      │  ├─ src/{probe,match,init,lint,adapter}.ts
                                      │  ├─ schemas/*.json  (SSOT)
                                      │  └─ bin/claude-agents.mjs
                                      ├─ plugins/*.yml          (그대로)
                                      ├─ scripts/                (확장: lint/inventory)
                                      └─ .github/workflows/ci.yml (drift 추가)
```

**호환성 유지**:
- `.claude/skills/`, `.claude/agents/`, `.codex/agents/`는 P4부터 **adapter 출력**이지만 **commit 유지** (control-plane 미설치 사용자도 동작)
- `.agents/skills/`는 mirror 관계 확인됨 → SSOT를 `assets/skills/`로 이동 후 `.agents/`는 deprecate
- `.claude/skills/<cat>/<n>.md` 경로는 P7까지 adapter view로 항상 살아있음

## Manifest schema 초안 (`assets/skills/<cat>/<n>/SKILL.md`)

```yaml
---
# --- Anthropic SKILL.md 표준 (registry 호환) ---
name: k8s-helm                  # ≤ 64, kebab-case, regex ^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$
description: >-                 # ≤ 1024, ≥ 40 (directive 강제), passive 금지
  Use when modifying Helm charts (Chart.yaml, templates/*.tpl, values*.yaml)
  to enforce chart structure, values override hierarchy, and helper template
  patterns. Skip for raw K8s manifests without Helm.
version: 1.0.0
license: MIT

# --- applies_when (비공식 부가, 결정적 scheduler 입력) ---
applies_when:
  files_present:                # glob, OR 매칭
    - "**/Chart.yaml"
    - "**/values*.yaml"
  files_contain:                # path → regex (AND)
    "**/Chart.yaml": '^apiVersion:\s*v[12]'
  language: []                  # 비어있으면 무시
  frameworks: [helm]
  context_keywords: [helm, chart, "values.yaml"]
  exclude_when:
    files_present: ["**/kustomization.yaml"]    # kustomize 우선이면 skip
  # 4개 카테고리(files_present, files_contain, language, frameworks) 중 ≥1 필수

# --- portability (inventory-labels.yml 차용) ---
portability:
  level: universal              # universal | claude-only | codex-incompat
  tested_on: [claude-code, codex, cursor]
  model_dependency: none        # none | claude-features | tool-use
  domain_specificity: focused   # focused | general

# --- handoff (_handoff.yml artifact 어휘 차용) ---
produces: [helm-chart]
consumes: [k8s-manifest, service-boundary]

# --- security (P8 registry publish 대비 미리 박아둠) ---
security:
  signature: ""                 # P8에서 sigstore/cosign 채움
  sandbox: read-only            # read-only | exec-allowed
  network: none                 # none | egress-only | full
  secrets_required: []
---
```

## Project Probe schema (`project-profile.yml`, deterministic, no LLM)

```yaml
schema_version: 1
generated_at: 2026-05-05T10:00:00Z
generator: "@ress/claude-agents@1.0.0"
repo: { vcs: git, default_branch: main, monorepo: false }
languages: [{ name: go, files: 142, primary: true }, { name: yaml, files: 38 }]
frameworks: [gin, helm]
build_systems: [go-modules, helm]
files_signatures:
  helm_chart_present: true
  k8s_manifest_present: true
  dockerfile_present: true
  ci_provider: github-actions
  test_framework: go-test
domain_hints: [microservice, api-gateway]    # AGENTS.md/README heading
constraints: { exclude_skills: [], exclude_agents: [], pin_skills: [] }
```

probe 입력: `git ls-files`, `package.json`/`go.mod`/`pom.xml`, glob. 출력은 sort + deterministic, 같은 입력 → 같은 출력.

## Matching Rule 알고리즘 (`control-plane/src/match.ts`)

```typescript
function score(skill: SkillManifest, profile: ProjectProfile): number {
  if (matchExclude(skill.applies_when.exclude_when, profile)) return -Infinity;
  let s = 0;
  s += 40 * Math.min(1, hitRatio(skill.applies_when.files_present, profile.files));
  s += 30 * regexHits(skill.applies_when.files_contain, profile);
  if (skill.applies_when.language.some(l => profile.languages.find(p => p.name===l && p.primary))) s += 20;
  s += 15 * intersectRatio(skill.applies_when.frameworks, profile.frameworks);
  // context_keywords는 약한 신호, runtime hook에서만
  return s;     // 가중치 합 105
}

function selectSkills(skills, profile, threshold = 50) {
  const scored = skills.map(s => ({skill: s, score: score(s, profile)}));
  return {
    install: scored.filter(x => x.score >= 50).sort((a,b)=>b.score-a.score),
    suggest: scored.filter(x => x.score >= 25 && x.score < 50),
    skip:    scored.filter(x => x.score < 25),
  };
}
```

결정성: tie-breaker는 `name` 알파벳순. LLM 호출 0회. threshold 50은 보수적 시작값(P6 baseline 후 튜닝). 각 score component breakdown을 dry-run stdout 출력.

## Bootstrap CLI (`claude-agents init` 5 step)

```
$ npx @ress/claude-agents init
[1/5] probe         → project-profile.yml 생성/갱신
[2/5] match         → install/suggest/skip 분류 (threshold 50)
[3/5] confirm       → install 후보 표 출력 (--yes/--dry-run)
[4/5] adapter       → 사용자 도구 감지 (.claude/, .codex/, .cursor/) → 해당 view만 install
[5/5] hook install  → settings.local.json에 PreToolUse hook idempotent 머지

산출물:
  .claude-agents.yml    # pinned skills + version lock
  project-profile.yml   # probe 결과
  .claude/skills/...    # claude-code 사용 시
  AGENTS.md             # 없으면 생성, 있으면 머지
```

서브커맨드: `init | probe | match | sync | lint | adapter`. `sync`는 upstream skill 변경 시 lock 갱신.

## Enforcement Hook (PreToolUse, admission webhook 등가)

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "npx @ress/claude-agents admit --tool=$CLAUDE_TOOL --path=$CLAUDE_TOOL_INPUT_path --skill=$CLAUDE_ACTIVE_SKILL"
      }]
    }]
  }
}
```

`admit` 동작:
1. active skill의 `applies_when`을 현재 파일에 재평가, 매치 안 되면 `exit 2` (deny + reason stderr)
2. `security.sandbox: read-only`인데 Edit/Write 시도 → deny
3. P5 초기엔 warning 모드(exit 0 + stderr 메시지), baseline 후 deny(exit 2) 전환

## Multi-AI Adapter 매핑

| 도구 | source | adapter 출력 | 변환 |
|---|---|---|---|
| Claude Code | `assets/skills/<cat>/<n>/SKILL.md` | `.claude/skills/<cat>/<n>/SKILL.md` | symlink/copy |
| Codex | 동일 | `.codex/skills/<cat>/<n>.toml` | YAML→TOML, 기존 `.codex/agents/*.toml` 변환 로직 흡수 |
| Cursor | 동일 | `.cursor/rules/<n>.mdc` | frontmatter `globs:` ← `applies_when.files_present` |

AGENTS.md primary 승격: `ln -sf AGENTS.md CLAUDE.md` (P4). `.codex/AGENTS.md`도 동일.

adapter 단일 진입점: `claude-agents adapter --tool=cursor`. CI drift job이 명령 결과 ↔ commit된 view 차이를 fail.

## Control plane 패키징 (별도 패키지)

| 항목 | 값 |
|---|---|
| 위치 | `control-plane/` (모노레포 내) |
| 언어 | TypeScript + Node 18+ ESM (Bun 호환) |
| 패키지명 | `@ress/claude-agents` (npm), Homebrew tap, PyPI thin wrapper(후속) |
| 빌드 | `tsup` ESM 번들 + `pkg`로 standalone binary |
| 배포 | npm publish (provenance: true) → GitHub Releases binary → Homebrew formula auto-bump |
| 외부 인터페이스 | (a) CLI `claude-agents <subcmd>` (b) Node lib `import { probe, match }` (c) JSON-RPC stdin/stdout (hook용) |
| 의존성 정책 | runtime deps ≤ 5개 (zod/fast-glob/yaml/kleur/tomlify). **LLM SDK 불포함** (결정적 스케줄러는 LLM-free) |

이중 부담 완화: `schemas/`만 SSOT, control-plane과 레포 양쪽이 동일 schema import. CI에서 schema-drift 차단.

## 검증 전략 (gold profile 기반)

| 메트릭 | 정의 | PoC 목표 |
|---|---|---|
| Frontmatter compliance | schema validate 통과율 | 10/10 = 100% |
| Matching accuracy | gold profile 4종(k8s-only/go-only/full-stack/empty) 대비 일치율 | precision ≥ 0.9, recall ≥ 0.85 |
| Activation rate | install된 skill 중 hook이 admit한 비율 | ≥ 70% (1주 baseline) |
| Determinism | 동일 profile에 동일 결과 (10회 hash 일치) | 100% |
| Adapter parity | 3 도구 view 노출 skill 일치 | diff 0 |
| CI drift | adapter 출력 ↔ commit view | green |

gold dataset: `tests/profiles/<n>.yml` + `tests/profiles/<n>.expected.yml`. 사람이 작성, code review 갱신.

## 마이그레이션 호환성 3 원칙

1. **path stability** — P7 종료 전까지 `.claude/skills/<cat>/<n>.md`는 adapter view로 항상 살아있음
2. **frontmatter optional 단계** — P2~P6 동안 `validate-skill-frontmatter.sh`는 변환된 skill만 strict, 미변환은 lint warning(CI fail X)
3. **rollback path** — 카테고리 PR은 단독 revert 가능, control-plane은 `--legacy-mode` 플래그로 frontmatter 없는 skill도 keyword-only fallback

## 미결정 사항 (P8까지 확정)

| # | 항목 | P8 시점 결정 근거 |
|---|---|---|
| Q8 | signature/sandbox 표준 (sigstore cosign vs SLSA provenance) | skills.sh가 어떤 signature를 요구하는지 P7~P8 사이 확인 필요 |

권고대로 즉시 박는 결정: adapter view commit (Q1=A), threshold 50 시작 (Q2=A), description ≥40자 P2부터 strict (Q3=A), `.cursor/rules/` P4 동시 (Q4=A), hook warning 후 deny (Q5=A), inventory.yml에 manifest 메타 흡수 (Q7=A).

## Phase별 commit 컨벤션

- P1: `feat(schemas): freeze skill-manifest/project-profile/agent-manifest v1`
- P2: `feat(assets): convert k8s 5 + go 5 to SKILL.md frontmatter (PoC)`
- P3: `feat(control-plane): add @ress/claude-agents CLI (probe/match/init/lint)`
- P4: `feat(adapters): multi-AI view generator (claude/codex/cursor) + AGENTS.md primary`
- P5: `feat(hooks): add PreToolUse admit hook (warning mode)`
- P6: `feat(assets): pilot kubernetes category full migration + baseline metrics`
- P7: `feat(assets): full 239-skill migration (categories per week)`
- P8: `feat(security): registry-ready signature/sandbox metadata + skills.sh export`

매 commit 메시지에 `Refs: docs/migration/0002` 푸터 추가.

## Critical Files (재사용 / 확장 대상)

- `.agents/skills/source-command-log-summary/SKILL.md` — 유일 표준 frontmatter 선례, P2 PoC 템플릿 시작점
- `.claude/agents/_handoff.yml` — artifact 어휘 SSOT, manifest produces/consumes 그대로 차용
- `scripts/validate-skill-frontmatter.sh` — P1 schema 동결 후 strict 모드 확장
- `scripts/generate-inventory-labels.sh` — portability 라벨 생성 로직, manifest portability 블록 통합
- `.codex/agents/code-reviewer.toml` — 변환 로직 reverse-engineering 출발점 (P4 1일 spike)
- `.github/workflows/ci.yml` — drift job에 adapter parity / probe determinism 추가 위치
- `AGENTS.md` (254줄) — primary 승격 대상
- `CLAUDE.md` (69줄) — symlink 전환 대상

## End-to-End Verification (PoC 10개 변환 후)

1. **Schema lint**: `node control-plane/bin/claude-agents.mjs lint --strict assets/skills/k8s/* assets/skills/go/*` → exit 0
2. **Probe determinism**: `claude-agents probe tests/projects/k8s-helm-repo` 10회 실행, 결과 hash 일치
3. **Matching accuracy**: `claude-agents match --gold=tests/profiles/k8s-only.yml --expected=tests/profiles/k8s-only.expected.yml` → precision/recall 출력, 임계 통과
4. **Adapter parity**: `claude-agents adapter --tool=claude && --tool=codex && --tool=cursor` 후 `diff -r adapters/claude/skills adapters/codex/skills`의 이름 set 일치
5. **Hook 동작**: `tests/projects/go-gin-repo`에서 k8s-helm skill 강제 활성화 후 `apps/api/main.go` Edit 시도 → admit가 deny + 이유 stderr
6. **End-to-end init**: 빈 디렉토리에서 `npx @ress/claude-agents init --yes` → `.claude-agents.yml` + `project-profile.yml` + `AGENTS.md` 생성, `.claude/skills/`에 매칭된 skill만
7. **CI drift green**: PR 올린 후 `.github/workflows/ci.yml`의 5+α job 모두 green
8. **Multi-AI 동시 시뮬**: tests/projects 1개에 Claude Code + Codex CLI + Cursor 동시 활성화, 같은 skill set 노출

게이트 통과 시 P6(kubernetes 카테고리 전체) 진입.

## Sources (조사 근거)

- [Skills not invoked on first turn — anthropics/claude-code#38588](https://github.com/anthropics/claude-code/issues/38588)
- [How to Make Claude Code Skills Actually Activate (650 Trials)](https://medium.com/@ivan.seleznov1/why-claude-code-skills-dont-activate-and-how-to-fix-it-86f679409af1)
- [Claude Skills Have Two Reliability Problems](https://medium.com/@marc.bara.iniesta/claude-skills-have-two-reliability-problems-not-one-299401842ca8)
- [Claude Code Hooks: The Deterministic Control Layer](https://www.dotzlaw.com/insights/claude-hooks/)
- [Anthropic Skills (skill-creator SKILL.md)](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [A2A Protocol Specification](https://a2a-protocol.org/latest/specification/)
- [agent-manifest.txt — proposed web standard](https://dev.to/jaspervanveen/agentstxt-a-proposed-web-standard-for-ai-agents-20lb)
- [klaw — Kubernetes for AI Agents](https://medium.com/illumination/someone-just-built-kubernetes-for-ai-agents-and-it-might-change-how-we-deploy-everything-d07681ee1770)
- [Gas Town: Kubernetes for AI Coding Agents](https://cloudnativenow.com/features/gas-town-what-kubernetes-for-ai-coding-agents-actually-looks-like/)
- [Will AI turn 2026 into the year of the monorepo? (Spectro Cloud)](https://www.spectrocloud.com/blog/will-ai-turn-2026-into-the-year-of-the-monorepo)
- [Monorepo vs Polyrepo: AI's New Rules (Augment)](https://www.augmentcode.com/learn/monorepo-vs-polyrepo-ai-s-new-rules-for-repo-architecture)
- [AGENTS.md vs CLAUDE.md: Cross-Tool Standard](https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard)
- [Skills.sh Marketplace (Vercel)](https://virtualuncle.com/agent-skills-marketplace-skills-sh-2026/)
- [30 ClawHub skills crypto swarm (The Register)](https://www.theregister.com/2026/04/29/30_clawhub_skills_mine_crypto/)
- [ADL — Agent Definition Language](https://github.com/inference-gateway/adl)
- [Harness Engineering for AI Coding Agents (Augment)](https://www.augmentcode.com/guides/harness-engineering-ai-coding-agents)
- [Context Engineering for Coding Agents (Martin Fowler)](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html)
- [AI Gone Rogue: Authorization vs Instructions (Oso)](https://www.osohq.com/post/why-authorization-keeps-llms-in-check)
