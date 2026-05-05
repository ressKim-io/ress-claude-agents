# schemas/ — Manifest SSOT

Migration 0002 P1 결과물. JSON Schema Draft 2020-12 기반.

## 파일

| Schema | 검증 대상 | Required 필드 |
|---|---|---|
| `skill-manifest.v1.json` | `assets/skills/<cat>/<name>/SKILL.md` (P2~), 현재 `.claude/skills/**/*.md`, `.agents/skills/**/SKILL.md` | `name`, `description` |
| `project-profile.v1.json` | `claude-agents probe` 출력 (`project-profile.yml`) | 8개 (schema_version/generated_at/generator/repo/languages/frameworks/build_systems/files_signatures) |
| `agent-manifest.v1.json` | `.claude/agents/*.md`, `assets/agents/<name>/AGENT.md` (P4~) | `name`, `description` |

## 사용처

- **레포 lint**: `scripts/validate-skill-frontmatter.sh` (P2 strict 모드 시 본 schema 직접 참조)
- **CI drift**: `.github/workflows/ci.yml` drift job
- **Control plane**: `control-plane/` 패키지가 동일 파일을 import (별도 사본 금지 — schema-drift 방지)

## 검증 (로컬)

```bash
# JSON Schema 자체 lint (meta-schema 통과 여부)
npx --yes ajv-cli@5 compile -s schemas/skill-manifest.v1.json
npx --yes ajv-cli@5 compile -s schemas/project-profile.v1.json
npx --yes ajv-cli@5 compile -s schemas/agent-manifest.v1.json

# 기존 frontmatter가 schema를 통과하는지 (P1 검증 게이트)
#   source-command-log-summary는 minimal frontmatter (name, description) 만으로 통과해야 함
yq -o=json '.' .agents/skills/source-command-log-summary/SKILL.md > /tmp/scls.json   # frontmatter만 추출 별도 변환 필요
npx --yes ajv-cli@5 validate -s schemas/skill-manifest.v1.json -d /tmp/scls.json
```

> Frontmatter → JSON 변환은 P3 control plane CLI가 자동화. P1에서는 수동 검증 + 스크립트 일회성.

## 단계별 strict 모드

| Phase | description minLength | applies_when 필요 | portability 필요 | security.signature 필요 |
|---|---|---|---|---|
| P1 (현재) | 1 | optional | optional | optional |
| P2~ (PoC strict) | 40 | required | optional | optional |
| P8 (registry-ready) | 40 | required | required | required (sigstore/SLSA) |

각 Phase 진입 시 schema 자체는 그대로 유지하고, lint script(`scripts/validate-skill-frontmatter.sh`)에 strict flag를 추가한다 (schema-drift 방지).

## $id 정책

`https://github.com/ressKim/ress-claude-agents/schemas/<file>` 형태. 실제 fetch 가능한 URL일 필요는 없음 (JSON Schema $id는 식별자). Registry publish 시(P8) 변경 가능.

## 수정 정책

- **MAJOR bump (v2)**: required 필드 추가, enum 값 제거, type 변경 → 레포의 모든 frontmatter 마이그레이션 필요
- **MINOR (호환)**: optional 필드 추가, enum 값 추가 → 자동 호환
- **PATCH**: $comment, description 텍스트만 변경 → 자동 호환

각 변경은 `docs/migration/`에 ADR 또는 본 0002 후속 문서로 기록.
