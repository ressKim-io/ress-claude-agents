# ADR 0010 — Codex 전용 view 지원 중단

- **Status**: Accepted
- **Date**: 2026-08-25
- **Driver**: 사용자 결정 — "codex 쪽 자체를 전부 다 없애줘. 지금 저거까지 관리가 안 돼." + [2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) Step 6 진행 중 발견한 `.codex/` 산출물 drift
- **Depends on**: 없음
- **Related**: [ADR 0006](0006-kiro-adapter-strategy.md) (Kiro 를 adapter 에서 제외한 같은 계열 판단), [`multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md)

## Context

`control-plane/src/adapter.ts` 는 `claude` / `codex` / `cursor` 3개 도구의 view 를 생성해 왔다. Codex view 는 `.codex/agents/*.toml` + `.codex/skills/<cat>/*.toml` + `.codex/AGENTS.md` symlink 로, 총 64파일 / 848K 였다.

2026-08-25 Step 6 작업 중 adapter 를 재실행했더니 **`.codex/agents/` 33개 파일에 ~1,500줄의 drift** 가 나왔다. 원인을 확인한 결과:

| 사실 | 값 |
|---|---|
| `.codex/agents/` 마지막 재생성 | **2026-05-18** |
| `.claude/agents/` 마지막 변경 | 2026-08-25 |
| 반영되지 않은 변경 | Step 3 (agent 49→34 강등·삭제) + Step 4 (`Permission Boundary` / `Escalation` / `Verification Criteria` 전 agent 신설) |

즉 `.codex/` 는 **3개월간 원본과 다른 내용을 담은 채 커밋돼 있었다.** 이미 삭제된 agent 의 `.toml` 이 남아 있고, 살아 있는 agent 의 `.toml` 에는 Step 4 가 추가한 경계 규약이 통째로 빠져 있었다.

[`multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md) 는 "원본 자산 변경 후 **같은 PR에서** 변환을 재실행한다. CI drift job 이 게이트하므로 누락 시 fail" 을 MUST 로 규정한다. 이 규정이 지켜지지 않았고 **게이트도 발화하지 않았다** — CI 는 `push: branches: [main]` 과 `pull_request` 에서만 돌고, Step 1~6 이 진행된 `docs/harness-readiness-audit` 브랜치에는 PR 이 없었다.

## Decision

**Codex 전용 view 를 제거한다.** `.codex/` 디렉터리와 `adapter.ts` 의 codex 경로를 모두 삭제하고, 지원 도구를 `claude` / `cursor` 2개로 줄인다.

**Codex 자체를 버리는 것이 아니다.** Codex 는 [Linux Foundation AGENTS.md 표준](https://agents.md/)을 자동 인식하므로 루트 `AGENTS.md` 만으로 계속 동작한다. 없어지는 것은 **`.toml` 변환 view 뿐**이며, 이는 ADR 0006 이 Kiro 를 adapter 에서 제외한 것과 같은 판단이다 — 표준을 인식하는 도구에 별도 변환을 유지할 ROI 가 없다.

## 대안 비교

| 안 | 내용 | 판단 |
|---|---|---|
| **A. 제거** | `.codex/` + adapter codex 경로 삭제 | ✅ 채택. 유지 비용이 0이 되고, 3개월 방치가 증명한 대로 그 비용은 실제로 지불되지 않고 있었다 |
| B. 재생성 후 유지 | adapter 재실행해 33파일 갱신, CI 트리거를 고쳐 재발 방지 | ❌ drift 는 즉시 해소되나 **원인이 남는다** — 원본이 바뀔 때마다 사람이 변환을 기억해야 하고, 사용자가 "관리가 안 된다" 고 명시했다 |
| C. 동결 | `.codex/` 를 그대로 두고 "더 이상 갱신하지 않음" 표기 | ❌ 최악. 틀린 내용이 SSOT 인 척 남는다. Step 6 의 F11(죽은 hook)과 같은 형태 — 있는데 작동하지 않으면서 있는 것처럼 보인다 |

B 를 택하지 않은 근거를 하나 더 적는다: Codex view 의 실사용 근거가 없다. 도입(2026-05) 이후 `.codex/` 를 소비한 기록이 dev-log·retrospective 어디에도 없고, 3개월 drift 를 아무도 눈치채지 못했다는 사실 자체가 **아무도 읽지 않았다는 증거**다.

## Consequences

**얻는 것**
- 원본 자산을 고칠 때 재실행할 변환이 `cursor` 하나로 줄어든다
- 커밋에서 64파일 / 848K 가 사라지고, agent 본문을 고칠 때마다 발생하던 `.toml` 대량 diff 가 없어진다
- CI adapter parity job 이 `.cursor/` 만 보므로 실패 시 원인 추적이 단순해진다

**잃는 것 / 위험**
- Codex 에서 이 레포의 **agent / skill 을 도구 네이티브 형식으로 쓸 수 없다.** `AGENTS.md` 의 보편 룰만 적용된다. 필요해지면 adapter 확장이 아니라 **먼저 실사용 근거를 확인**한 뒤 ADR 로 되살린다
- `schemas/skill-manifest.v1.json` 과 `control-plane/src/schema/skill-manifest.ts` 의 `portability.compat` enum `codex-incompat` 이 의미를 잃는다. **제거하지 않는다** — enum 값 삭제는 published manifest 전부에 MAJOR bump 를 강제한다. orphan 주석만 달고 신규 자산에는 쓰지 않는다
- `assets/skills/**` 15개의 `portability.tested_on: [..., codex]` 는 **그대로 둔다.** 과거에 실제로 검증한 이력이고, 지우면 검증 이력 조작이 된다

**규칙 보강** — [`multi-tool-adapter.md`](../../.claude/rules/multi-tool-adapter.md) 에 §"도구를 뺄 때도 ADR 을 쓴다" 를 추가했다. 기존 규칙은 도구 **추가** 시의 ROI 판단만 규정했다. 추가만 판단하고 제거를 방치하면 유지되지 않는 산출물이 SSOT 인 척 남는다 — 이번이 그 사례다. **도구별 view 의 유지 근거는 재생성 실적**이며, 분기 review 항목에 넣었다.

## 남은 문제 (본 ADR 범위 밖)

**CI 가 feature 브랜치에서 돌지 않는다.** `ci.yml` 트리거가 `push: [main]` + `pull_request` 뿐이라, PR 을 열기 전까지 drift job 을 포함한 모든 게이트가 침묵한다. 이번 drift 가 3개월간 발견되지 않은 직접 원인이다. 트리거 확대 여부는 러너 비용 문제와 얽혀 있어 별도 판단이 필요하다 — [2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) §Step 7+ 에 기록.

## 검증

```bash
cd control-plane && npm run typecheck && npm test
node control-plane/dist/cli.js adapter --tool=cursor --root=. --assets=./assets
git diff --quiet -- .cursor/ && echo "cursor parity OK"
grep -rn "codex" control-plane/src control-plane/tests   # schema orphan 주석만 남아야 한다
```
