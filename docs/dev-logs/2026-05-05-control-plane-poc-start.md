# 2026-05-05 — Control Plane PoC 시작

> Migration 0002 (`docs/migration/0002-standardization-and-control-plane.md`)의 시작 시점 작업 로그.
> 진행 추적은 [`docs/migration/0002-progress.md`](../migration/0002-progress.md).

## 시작 컨텍스트

이 레포를 단순 Claude Code 자산 모음에서 **휴대용 표준 인덱스 패키지**로 격상하는 대규모 작업의 첫날. 5개 turn에 걸친 사용자와의 대화 + 외부 검색 5회를 통해 그림이 잡힘.

### 핵심 통찰 (대화에서 결정)

1. **LLM은 비결정적 옵티마이저** → RDB 옵티마이저 비유는 부분만 맞음. 업계 표준은 결정적 retrieval + LLM reasoning 분리. Ollama 가설은 옵티마이저 자리가 아닌 embedder/router 자리에 어울림.
2. **K8s scheduler 비유 1:1 매칭** — etcd ↔ inventory, kube-scheduler ↔ Matching Rule, admission webhook ↔ PreToolUse Hook. klaw, Gas Town, Context Kubernetes 같은 선례 검증.
3. **Skill activation 50% 동전 던지기** — directive description으로 100% 가능. PreToolUse hook이 결정적 강제 레이어.
4. **Multi-AI 시대** — AGENTS.md(LF 표준) + SKILL.md 조합이 8개 도구 자동 호환. Claude 락인 회피 가능.
5. **Description budget 1-2% 시한폭탄** — 239 skills 전부 install 시 truncate. 계층화/selective install/Tool Search 패턴 필수.

### 사용자 결정 (4개)

| # | 결정 | 채택 |
|---|---|---|
| 레포 구조 | mono + 내부 재배치 | AGENTS.md primary, CLAUDE.md→symlink |
| Multi-AI | Claude+Codex+Cursor 우선 | 8개 자동 호환 위에 3개 집중 검증·문서 |
| Control plane | 처음부터 별도 패키지 | `@ress/claude-agents` npm/PyPI/Homebrew |
| Registry | 포맷만 호환, publish 미래 | skills.sh > Lobehub. ClawHub 보류 |

### 검증된 전제 (Phase 1·3 Explore + 직접 read)

- Skills frontmatter **사실상 0%** (1개 표준 선례: `source-command-log-summary/SKILL.md`)
- Agents frontmatter **100%** (46개 모두 directive 스타일)
- `.codex/agents/*.toml` **46개 이미 존재** — adapter pipeline 부분 가동
- `.claude/skills/` ≡ `.agents/skills/` (diff 0, mirror 관계)
- hooks **absent** (settings.local.json엔 permissions만)

## 5층 그림 (확정)

```
Layer 1: Asset Capability Manifest    SKILL.md frontmatter + applies_when 비공식 부가
Layer 2: Project Probe                 deterministic, no LLM (git ls-files + glob)
Layer 3: Matching Rule (scheduler)     cost-based scoring (40+30+20+15)
Layer 4: Bootstrap CLI                 claude-agents init 5 step (probe/match/confirm/adapter/hook)
Layer 5: Enforcement (admission)       PreToolUse hook, applies_when 재평가
```

## 첫 실행 (Step 0 = P0)

이 dev log + Migration 0002 본문 + Progress tracker 3개 파일 생성 후 commit.
**이유**: plan 파일(`/Users/ress/.claude/plans/plan-rippling-spindle.md`)은 plan mode 임시 파일이라 휘발 가능. 사용자가 명시적으로 "세션 꺼져도 되도록 어디 기록하고 시작"을 요청.

## 다음 액션 (P1 Schema 동결)

```bash
mkdir -p control-plane/schemas
# JSON Schema 3개 작성:
#   - skill-manifest.v1.json   (Anthropic SKILL.md 표준 + applies_when + portability + handoff + security)
#   - project-profile.v1.json  (probe 출력)
#   - agent-manifest.v1.json   (agents/<n>/AGENT.md frontmatter)
# ajv 또는 jsonschema로 lint
# source-command-log-summary/SKILL.md를 새 schema에 검증 (현재 minimal frontmatter라 부분 통과 예상, applies_when 추가해야)
```

P1 게이트: JSON Schema lint exit 0 + 1개 기존 SKILL.md validate 통과 (또는 minimal compliance 확인).

## 메모

- 외부 검색 결과는 0002 본문 §Sources에 18개 링크로 박아둠. 본 dev log엔 중복 안 함.
- Plan agent의 추가 발견(`.codex/agents/` 46개 사전 존재) 덕에 P4 작업 1일 spike만으로 변환 로직 reverse-engineering 가능 — 부담 ↓.
- 메모리(`MEMORY.md`)는 다음 commit 또는 P1 종료 시 v5.1로 갱신 (Migration 0002 추가 표시).
