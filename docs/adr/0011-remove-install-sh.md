# ADR 0011 — install.sh 및 배포 표면 제거

- **Status**: Accepted
- **Date**: 2026-08-26
- **Driver**: 사용자 결정 — "install 시리즈 전부 없애는 방향으로 가자. 리뷰가 문제가 아니라 install 이게 필요가없어 안써"
- **Supersedes**: [ADR 0007](0007-install-sh-narrow-scope.md) (install.sh 자산 단위 옵션 — PR-8 미착수 상태로 종료)
- **Related**: [ADR 0010](0010-drop-codex-support.md) (같은 이유로 유지되지 않는 산출물을 제거), [PR #36 리뷰](../audit/2026-08-24-agent-harness-readiness.md)

## Context

`install.sh` (924줄)는 이 레포의 자산을 **다른 프로젝트에 설치**하는 수단이었다. `--global` / `--local` / `--modules` / `--with-skills` / `--with-mcp` / `--plugin` / `--workflow` 플래그를 지원했고, 그 설정 표면으로 `plugins/*.yml` 12개와 `.claude/workflows/*.yml` 11개가 있었다.

**사용자가 쓰지 않는다.** 그리고 유지 비용은 계속 지불되고 있었다 — 2026-08-26 PR #36 리뷰가 낸 15건 중 6건이 install 계열이었다.

| 리뷰 지적 | 내용 |
|---|---|
| 범위 게이트 누락 | `--workflow X` 가 `--with-skills` 없이 skill 71개를 설치 (`--plugin` 은 0). ADR 0007 의 narrow-scope 의도 위반 |
| 파서 4중복 | frontmatter category 파서가 4벌 복사돼 있었고 2벌에 early-exit 이 빠져 phantom 카테고리 발생 |
| CI 하드코딩 | 범위 회귀 테스트가 `plugins/backend-go.yml` 의 카테고리를 복사해 박아둠 |
| CI 로그 소실 | install 실패 시 `>/dev/null` 로 진단이 사라짐 |
| 성능 | `install_skills_by_category` 가 카테고리마다 272 파일 재파싱 |
| (신규 발견) | plugin 파서가 `individual:` 항목을 카테고리로 오인 → `compliance`/`ops` 의 개별 skill 6개가 설치되지 않고 "category not found" 경고만 냄. **도입 이후 아무도 몰랐다** |

마지막 항목이 결정적이다. 12개 plugin 중 2개가 선언한 skill 을 설치하지 못하는 상태가 방치돼 있었다 — **아무도 그 경로를 실행하지 않았다는 증거**다.

## Decision

**`install.sh` 와 그 설정 표면을 전부 제거한다.** 이 레포는 배포 수단을 두지 않고, **여기서 직접 작업할 때 로드되는 자산 모음**으로 재정의한다.

제거 대상:

| 묶음 | 내용 |
|---|---|
| 실행체 | `install.sh`, `tests/install.bats`, `mcp-configs/` |
| 설정 표면 | `plugins/*.yml` (12), `.claude/workflows/*.yml` (11) — install.sh 외 런타임 소비자가 **0** |
| CI | `test` job, `install-macos` job (둘 다 install.sh 검증 전용) |
| 검증 | `validate-agent-handoff.sh` 의 `check_workflows` / `check_skill_refs`, `validate-commands-drift.sh` 의 `check_flatten_ssot` |
| 일회성 | `scripts/migrate-skills-to-skillmd.sh` (Step 2 에서 역할 종료) |

다른 프로젝트에서 쓰려면 **필요한 파일을 직접 복사**한다. skill 은 `<skill-name>/SKILL.md` 레이아웃을 유지해야 로드된다.

## 대안 비교

| 안 | 판단 |
|---|---|
| **A. 전부 제거** | ✅ 채택. 유지 비용이 0이 되고, 사용자가 쓰지 않는다는 사실이 확정적이다 |
| B. 리뷰 지적 6건만 고치고 유지 | ❌ 고치는 순간에도 소비자는 없다. `individual:` 버그가 도입 이후 방치된 것이 그 증거 |
| C. `plugins`/`workflows` 는 문서로 남긴다 | ❌ 검증되지 않는 설정 파일만 남는다. 이번 세션에서 세 번(죽은 hook / `ask` 층 / `.codex` drift) 반복된 "있는데 작동하지 않으면서 작동하는 듯 보이는" 패턴을 또 만든다 |

## Consequences

**얻는 것**
- 924줄 스크립트 + 30개 설정 파일 + CI job 2개의 유지 비용 소멸
- CI 가 4 job (docs / inventory / lint / drift) 으로 단순해진다
- 파서 중복 압력이 사라진다 — `scripts/lib/skill-category.sh` 만 남고 소비자는 validator·generator 4개

**잃는 것 / 위험**
- **다른 프로젝트로의 자동 배포 경로가 없다.** 수동 복사가 유일한 방법이고, 복사본은 원본 변경을 따라가지 않는다. 이것이 실질적 손실인지는 사용자만 판단할 수 있고, 현재 판단은 "쓰지 않으므로 손실 아님" 이다
- `plugins/` 가 담고 있던 **역할별 자산 묶음 지식**이 사라진다 (예: backend-go = go + msa + architecture). 필요해지면 문서로 되살린다
- **branch protection 갱신이 필요하다** — `Test` 와 `install.sh smoke (macOS bash 3.2)` 가 main 의 required status check 로 등록돼 있다. job 을 지우면 해당 컨텍스트가 영원히 보고되지 않아 **PR 이 머지 불가 상태로 대기**한다. 이 ADR 적용과 **같은 시점에** 두 컨텍스트를 required 목록에서 제거해야 한다
- macOS bash 3.2 회귀를 잡던 유일한 job 이 사라진다. 남은 셸 스크립트(`scripts/*.sh`)는 `#!/usr/bin/env bash` 로 사용자 환경 bash 를 쓰므로 3.2 호환이 여전히 중요하다 — shellcheck 은 이를 검증하지 않는다. **검증 공백으로 기록한다**

## 남은 문제 (범위 밖)

- **루트 `commands/` 디렉터리** (52 파일) 는 install.sh 가 읽던 모듈 레이아웃 소스다. `.claude/commands/` 와 내용이 동일하며 install.sh 가 사라진 지금 별도 소비자는 `validate-commands-drift.sh` / `generate-docs.sh` / `generate-inventory-labels.sh` 뿐이다 — 즉 **자기 자신을 검증하기 위해서만 존재한다.** 통합 여부는 별도 판단
- `.claude/rules/multi-tool-adapter.md` 의 "자산 단위로 가져간다(picky 운영)" 원칙은 유효하다. 수단이 `install.sh --skill` 에서 `cp` 로 바뀌었을 뿐이다

## 검증

```bash
make all                      # validate + enforcement + links
./scripts/validate-agent-handoff.sh all
./scripts/validate-commands-drift.sh all
shellcheck scripts/*.sh scripts/lib/*.sh
```
