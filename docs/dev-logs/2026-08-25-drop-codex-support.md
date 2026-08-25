---
date: 2026-08-25
category: decision
tier: 2
importance: major
status: resolved
tags: [codex, adapter, multi-tool, control-plane, drift]
related:
  - adr/0010-drop-codex-support.md
  - dev-logs/2026-08-25-step6-enforcement-layer.md
  - architecture/multi-tool-mapping.md
---

# Codex 전용 view 제거

## 왜

Step 6 작업 중 adapter 를 재실행했더니 `.codex/agents/` 33파일에 ~1,500줄 drift 가 나왔다. 확인 결과 **`.codex/` 는 2026-05-18 이후 재생성된 적이 없었다** — Step 3(agent 49→34 강등·삭제)과 Step 4(전 agent 에 Permission Boundary / Escalation / Verification Criteria 신설)가 통째로 빠져 있었고, 이미 삭제된 agent 의 `.toml` 이 남아 있었다.

사용자 판단: **"지금 저거까지 관리가 안 돼."** → 재생성이 아니라 제거.

## 무엇이 게이트를 통과시켰나

`multi-tool-adapter.md` 는 "원본 변경 후 **같은 PR에서** 변환 재실행, CI drift job 이 게이트" 를 MUST 로 규정한다. 규정은 있었고 job 도 있었다. **발화 조건이 없었을 뿐이다** — `ci.yml` 트리거가 `push: branches: [main]` + `pull_request` 인데 `docs/harness-readiness-audit` 브랜치에 PR 이 없어서 Step 1~6 내내 CI 가 한 번도 돌지 않았다.

같은 세션에서 진단한 F11(죽은 hook)과 형태가 같다. **있는데 작동하지 않으면서 있는 것처럼 보이는 통제.** 이번엔 통제 자체가 아니라 통제의 트리거가 비어 있었다.

## 규칙 보강

`multi-tool-adapter.md` 에 §"도구를 뺄 때도 ADR 을 쓴다" 를 추가했다. 기존 규칙은 도구 **추가** 시의 ROI 판단만 규정했다. 추가만 판단하고 제거를 방치하면 유지되지 않는 산출물이 SSOT 인 척 남는다.

> **도구별 view 의 유지 근거는 재생성 실적이다.** 분기 review 에서 "이 도구의 산출물이 최근 원본 변경을 따라갔는가" 를 함께 본다.

## 판단 기록

- **Codex 를 버린 게 아니다.** Codex 는 `AGENTS.md` 를 자동 인식하므로 추가 설정 없이 계속 쓸 수 있다. 없어진 것은 `.toml` view 뿐이고, 이는 ADR 0006 이 Kiro 를 adapter 에서 제외한 것과 같은 판단이다.
- **제거 근거는 취향이 아니라 실적이다.** 도입(2026-05) 이후 `.codex/` 를 소비한 기록이 dev-log·retrospective 어디에도 없고, 3개월 drift 를 아무도 눈치채지 못했다 — 아무도 읽지 않았다는 증거다.
- **`.cursor/` 는 유지.** 지목되지 않았고, `.mdc` 15개로 작으며 이번 adapter 재실행에서 **drift 0** 이었다. 같은 문제를 겪고 있지 않다.
- **결정성 테스트는 삭제하지 않고 cursor 로 이전했다.** 10회 실행 byte-equal 은 도구와 무관한 속성이라 codex 와 함께 버릴 이유가 없다.

## 손대지 않은 것 (의도적)

| 대상 | 이유 |
|---|---|
| `schemas/*.json` · `skill-manifest.ts` 의 `codex-incompat` enum | enum 값 제거는 published manifest 전부에 MAJOR bump 를 강제한다. orphan 주석만 (`security.sandbox` 와 동일 처리) |
| `assets/skills/**` 15개의 `portability.tested_on: [..., codex]` | 과거에 실제로 검증한 이력. 지우면 검증 이력 조작이다 |
| `docs/dev-logs/` · `retrospective/` · `migration/0002` Decision Log | 이력 기록. 현재 상태 문서만 갱신했다 |

## 검증

```
control-plane   typecheck 통과 / vitest 94 passed (97 → 94, codex 테스트 3건 제거)
adapter         --tool=cursor 정상, cursor parity drift 0
                --tool=codex 는 "must be one of: claude, cursor" 로 거부
validators      7종 전부 PASS · shellcheck PASS · inventory 최신
```

`bats tests/install.bats` 는 **실행 안 함** — 로컬에 bats 미설치.

## 남은 문제

**CI 가 feature 브랜치에서 돌지 않는다.** 이번 drift 가 3개월간 발견되지 않은 직접 원인이고, 트리거 확대는 러너 비용과 얽혀 있어 별도 판단이 필요하다. ADR 0010 §남은 문제에 기록.
