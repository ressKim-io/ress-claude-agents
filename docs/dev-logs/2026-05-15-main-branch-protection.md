---
date: 2026-05-15
category: meta
tier: 2
importance: major
status: resolved
tags: [ci, branch-protection, github-actions, drift, governance]
related:
  - dev-logs/2026-05-12-pr18-20-fact-check-and-dangling-ref-fixes.md
---

# main branch protection 활성화 — CI fail 후 머지 가능 구조 차단

## Context

PR #25 (frontmatter/effort sync) 머지 이후 main CI 4 연속 실패. 가장 최근 PR #27 (devlog-meta-refactor) 머지 직후 run `25921044619` 도 fail.

실패 step: `Validate inventory labels freshness` (`./scripts/generate-inventory-labels.sh validate`). 메시지: `FAIL  inventory-labels.yml is outdated`.

## Issue

표면 원인은 PR #25 가 frontmatter 변경 후 `inventory-labels.yml` 재생성 누락. 그러나 근본 원인은 다른 곳:

1. **main 에 branch protection rule 없음** — `gh api .../branches/main/protection` 응답 `Branch not protected (HTTP 404)`
2. PR #25/26/27 의 PR CI 도 fail (`Rules / Frontmatter / Adapter Drift` + `Inventory Freshness`) 이지만 머지 가능했음
3. 한 PR 의 누락이 다음 PR base 를 깨뜨리고, 다음 PR 도 fail 무시 머지 → 누적 drift

즉 inventory-labels drift 는 증상이고, **CI fail 을 무시한 채 머지 가능한 구조 자체** 가 근본 원인.

## Action

### 1차 — 증상 fix

- `./scripts/generate-inventory-labels.sh` 재실행 → drift 보정
  - `dx/token-efficiency` model_dependency `low → high`
  - `operations/cloud-cli-safety` 신규 항목 추가
  - timestamp 갱신
- commit `0249ad4 fix(ci): regenerate inventory-labels.yml drift` + main push
- 새 run `25921894146` 5/5 job 통과 확인

### 2차 — 근본 fix

`gh api PUT /repos/ressKim-io/ress-claude-agents/branches/main/protection`:

| 설정 | 값 | 의도 |
|---|---|---|
| `required_status_checks.contexts` | 5 job (Test / Docs / Inventory / Shellcheck / Drift) | CI fail 시 머지 차단 |
| `required_status_checks.strict` | `true` | PR branch base outdated → rebase 강제 |
| `enforce_admins` | `false` | 1인 운영 긴급 우회 허용 |
| `required_pull_request_reviews` | `null` | self-merge 가능 |
| `allow_force_pushes` | `false` (자동) | main 강제 push 차단 |
| `allow_deletions` | `false` (자동) | main 삭제 차단 |

## Result

- PR CI fail = 머지 버튼 비활성화 → PR #25-27 시나리오 재발 불가
- strict=true → PR branch 가 main rebase 후에만 머지 → 누적 drift 자동 차단
- 1인 self-merge 워크플로우 유지 (review 요구 없음)
- 긴급 시 admin 우회 가능 (enforce_admins=false)

## Trade-off / 한계

- branch protection 은 GitHub side 설정이라 레포 fork 시 자동 복제 안 됨 (다른 운영자 fork 시 동일 설정 수동 적용 필요)
- claude code 가 PR 만들 때 generator 실행 누락 자체는 막지 못함 — CI fail → 사용자가 fix → re-push 흐름. auto-fix commit back 은 채택 안 함 (옵션 A 선택, B 거절)

## Related Files / Links

- Failed run: https://github.com/ressKim-io/ress-claude-agents/actions/runs/25921044619
- Fix run: https://github.com/ressKim-io/ress-claude-agents/actions/runs/25921894146
- Fix commit: `0249ad4` (`fix(ci): regenerate inventory-labels.yml drift`)
- 직전 dev-log: `docs/dev-logs/2026-05-12-pr18-20-fact-check-and-dangling-ref-fixes.md`
