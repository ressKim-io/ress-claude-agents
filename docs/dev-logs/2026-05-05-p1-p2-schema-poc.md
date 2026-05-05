---
date: 2026-05-05
type: meta
phase: 0002-P1+P2
related:
  - ../migration/0002-standardization-and-control-plane.md
  - ../migration/0002-progress.md
  - 2026-05-05-control-plane-poc-start.md
  - 2026-05-05-control-plane-discussion.md
---

# 0002 P1 동결 + P2 PoC 10개 변환

이전 세션에서 P0(영구 기록)까지 완료했고, 본 세션은 P1(Schema 동결)과 P2(PoC 10개)를 한 호흡에 진행했다.

## 진입 시점 상태

- `docs/migration/0002-progress.md`의 P0 행이 `in_progress`로 남아 있었지만, 산출물은 commit `f6fb2fe`(0002 본문) + `0043b12`/`e3e32ec`(dev-log)로 이미 완료된 상태였다 → 표만 갱신.
- 다음 진입 Phase는 P1 Schema 동결.

## P1 — Schema 동결

### 산출물 (commit `d01ce63`)

| 파일 | 줄 수 | 역할 |
|---|---|---|
| `schemas/skill-manifest.v1.json` | 161 | SKILL.md frontmatter SSOT (name/description/applies_when/portability/handoff/security) |
| `schemas/project-profile.v1.json` | 142 | `claude-agents probe` 출력 결정적 schema |
| `schemas/agent-manifest.v1.json` | 91 | agent frontmatter (model/tools 포함) |
| `schemas/README.md` | 53 | 단계별 strict 모드 표 + $id 정책 + 변경 정책 |
| `scripts/validate-schemas.sh` | 130 | Draft 2020-12 compile + sample validate (재현 가능 게이트) |

### 검증 게이트 결과

1. ajv-cli@5 `--spec=draft2020`로 3 schema 모두 compile valid.
2. `source-command-log-summary` frontmatter → `skill-manifest.v1` validate 통과 (P1 게이트).
3. `code-reviewer` frontmatter → `agent-manifest.v1` validate 통과 (보너스 sanity check).

### P1 결정 (4건)

`docs/migration/0002-progress.md` Decision Log에 1줄씩 기록.

- **Draft 2020-12 채택** — `$schema` 명시. ajv-cli `--spec=draft2020` 1 옵션으로 작동, 미래 호환성 우위.
- **`format: date-time` 대신 ISO 8601 정규식 pattern** — `ajv-formats` 추가 의존성을 회피하기 위함. lint 환경 단순.
- **`description.minLength: 1`** — schema는 영구 SSOT, 단계적 strict는 lint runner의 책임. P2 strict(≥40)는 lint script의 추가 체크로 분리. 이렇게 하면 schema 변경 없이 단계별 게이트 운영 가능.
- **`produces`/`consumes` 어휘 enum 미강제** — `_handoff.yml` 변경 시 schema MAJOR bump 강제 회피. 어휘 검증은 기존 `validate-agent-handoff.sh`가 전담.

## P2 — PoC 10개 변환

### 산출물 (commit `00128dd`)

```
assets/skills/kubernetes/{k8s-helm, k8s-autoscaling, k8s-security, k8s-scheduling, k8s-traffic}/SKILL.md
assets/skills/go/{go-testing, go-database, go-microservice, go-errors, go-gin}/SKILL.md
```

12 files changed / +3694 insertions. 본문은 기존 `.claude/skills/<cat>/<name>.md`에서 그대로 `cat` append, frontmatter만 손으로 작성.

### 각 frontmatter 구성

```yaml
name: <kebab-case>           # 디렉토리명과 일치
description: "Use when ..."  # 영문 directive 스타일, 60~250 chars
version: 1.0.0
license: MIT
applies_when:
  files_present: [...]       # k8s는 manifest glob, go는 go.mod / *_test.go 등
  files_contain:             # go.mod의 import 패턴, k8s manifest의 kind 패턴
    "**/...": '<regex>'
  language: [...] | frameworks: [...]
  exclude_when: { files_present: [...] }    # 충돌하는 도구 차단 (예: helm vs kustomize)
portability:
  level: universal
  tested_on: [claude-code, codex]
  model_dependency: none
  domain_specificity: focused
produces: [...]              # _handoff.yml 어휘 (helm-chart, k8s-manifest, code, unit-test, ...)
consumes: [...]              # 같은 어휘
security:
  signature: ""              # P8에서 sigstore/SLSA 채움
  sandbox: read-only
  network: none
```

### 변경된 lint script

| 스크립트 | 변경 |
|---|---|
| `scripts/validate-schemas.sh` | (a) nested YAML 파서로 교체 (이전 단순 1단계 파서로는 applies_when/portability 등 multi-level 처리 불가) (b) PoC 10개 strict 검증 섹션 추가: description ≥40 + applies_when 존재. (c) 강제 PoC 카운트(==10) 체크 |
| `scripts/validate-skill-frontmatter.sh` | `assets/skills/` shell-only fast lint 추가 (`assets` 또는 `all` 모드). description ≥40 + name==dirname + applies_when 존재 검사 |

### 검증 결과

```
=== Schema compile (Draft 2020-12) ===  3/3 PASS
=== P1 sample frontmatter validation ===  2/2 PASS
=== P2 PoC 10개 (strict: description >=40 + applies_when 필수) ===  10/10 PASS
=== 기존 5 lint ===
  - validate-rules-drift.sh        green
  - validate-agent-handoff.sh      green
  - validate-skill-frontmatter.sh  green (assets PoC 10/10 strict OK)
```

### Dual-tree 운영

- `assets/skills/<cat>/<name>/SKILL.md`가 SSOT
- `.claude/skills/<cat>/<name>.md`는 그대로 보존 (호환성 — Claude Code 사용자가 즉시 영향 받지 않음)
- P3 control-plane adapter 도입 후 `.claude/`는 자동 생성 view로 전환 → 그때 dual-tree 해소

이 기간 동안 기존 `.claude/skills/<n>.md` 변경 시 양쪽 sync 부담이 있다. P3까지 PoC 10개 한정이라 부담 작음. 그러나 PoC 외 skill 본문 수정 시에는 변경 영향 없음 (PoC 10개만 dual-tree).

### 알려진 한계

- Anthropic 공식 SKILL.md는 frontmatter 다음 H1 제목 권장 안 함 (frontmatter가 metadata). 기존 본문이 `# 제목`으로 시작해서 그대로 들어가 있음 — 이중 metadata 모양. P3 adapter가 view 생성 시 H1을 떼낼지(또는 그대로 둘지)는 별도 결정 필요.
- `applies_when.files_contain`의 regex는 control-plane 도입 전까지 실제 매칭이 검증되지 않았다. P3에서 4 gold profile에 대해 dry-run 실행 시 검증.
- description은 모두 영문. 한국어가 description로 더 잘 동작하는지는 P3~P4에서 activation rate baseline으로 확인.

## 다음 진입 — P3

### 핵심 작업

`@ress/claude-agents` CLI (TS + Node 18+ ESM) 신설.

- `control-plane/` 디렉토리 신설 (모노레포 내 별도 패키지)
- 4 subcommand: `probe`, `match`, `init`, `lint`
- 의존성 ≤ 5 (zod / fast-glob / yaml / kleur / tomlify), LLM SDK 불포함
- tsup ESM 번들 + pkg standalone binary
- `schemas/`를 SSOT로 import (별도 사본 금지)

### P3 검증 게이트

- 가짜 프로젝트 3종(k8s helm / go gin / 빈 디렉토리)에 init 결과 diff snapshot 일치
- 결정성: 동일 입력 → 10회 hash 일치
- 4 gold profile에 PoC 10개의 expected hit (precision ≥ 0.9, recall ≥ 0.85)

P3는 분량이 P1+P2 합보다 훨씬 크다 (TS 패키지 신설, 빌드 파이프라인, 테스트 등) → 다음 세션에서 단독 진행 권장.

## 변경된 파일 (요약)

```
docs/migration/0002-progress.md         (P0/P1/P2 status + Decision Log)
schemas/skill-manifest.v1.json          (신설)
schemas/project-profile.v1.json         (신설)
schemas/agent-manifest.v1.json          (신설)
schemas/README.md                       (신설)
scripts/validate-schemas.sh             (신설 → 확장)
scripts/validate-skill-frontmatter.sh   (assets/ 섹션 추가)
assets/skills/kubernetes/<5>/SKILL.md   (신설)
assets/skills/go/<5>/SKILL.md           (신설)
docs/dev-logs/2026-05-05-p1-p2-schema-poc.md   (본 파일)
```

## Commit

| Hash | 메시지 |
|---|---|
| `cb933d8` | docs(migration): mark 0002 P0 complete, P1 in_progress |
| `d01ce63` | feat(schemas): freeze skill-manifest/project-profile/agent-manifest v1 |
| `00128dd` | feat(assets): convert k8s 5 + go 5 to SKILL.md frontmatter (PoC) |
