# ADR 0012 — 영역별 native plugin 구조와 marketplace

- **Status**: Accepted
- **Date**: 2026-11-04
- **Driver**: 사용자 결정 — "한번에 주르륵 몰려 있어서 구분하고 사람들이 내꺼에서 뭘 들고가야되는지 판단하기 어려워"
- **Partially supersedes**: [ADR 0011](0011-remove-install-sh.md) 의 "배포 수단을 두지 않는다" 부분. `install.sh` 제거 자체는 유지한다.
- **Related**: [ADR 0008](0008-asset-tier-policy.md), [ADR 0009](0009-enforcement-layer-placement.md), [사양 검증 기록](../audit/2026-11-04-claude-spec-verification.md)

## Context

skill 272개가 `.claude/skills/` 에 평탄하게 있었다. 두 가지 문제가 있었다.

| 문제 | 측정값 |
|---|---|
| 무엇을 가져갈지 판단할 수 없다 | README 수치가 실제와 달랐고(46 agents / 254 skills / 삭제된 12 plugins), 영역 구분이 파일 구조에 없었다 |
| description 이 Claude 에게 도달하지 않는다 | 2026-11-04 세션 목록에서 272개 중 94개만 description 표시. 목록 예산(컨텍스트의 1%) 초과로 추정 ⚠️ |

ADR 0011 은 "사용자가 쓰지 않는다" 는 이유로 배포 수단을 없앴다. 그때의 판단 대상은 자체 설치 스크립트 924줄이었다. 이번 요구는 다른 사람이 일부만 가져가는 것이고, Claude Code 에는 이를 위한 기본 기능이 있다.

## Decision

1. 영역별 자산을 `plugins/<plugin>/{skills,agents,commands}` 로 옮기고 `.claude-plugin/marketplace.json` 으로 묶는다. 자체 스크립트는 두지 않는다.
2. 이 레포는 `dx` 만 켠다. Go·K8s 코드가 없는 메타 레포라 나머지를 켤 이유가 없고, 켜면 예산 문제가 그대로다.
3. rule 은 plugin 에 실을 수 없으므로 `.claude/rules/<그룹>/` 에 둔다.
4. `version` 을 쓰지 않는다 (아래).
5. 설치본은 plugin 별로 캐시되므로 plugin 경계를 넘는 상대 링크를 두지 않는다. 다른 plugin 의 skill 은 `/plugin:skill` 표기로, rule·docs 는 GitHub URL 로 가리킨다. 두 경우 모두 게이트가 검사한다.

## 대안 비교

| 안 | 영역 구분 | 일부만 설치 | 예산 문제 | 판단 |
|---|---|---|---|---|
| **A. plugin + marketplace** | ✅ | ✅ 공식 기능 | ✅ 켠 것만 로드 | ✅ 채택 |
| B. `.claude/skills/<영역>/<이름>/` | ✅ | ❌ | ❌ | ❌ 실측에서 로드되지 않았다 (아래). 문서에도 없는 형태이고 2026-08 에 260개가 이 계열 구조로 죽어 있었다 |
| C. 평탄 유지 + 카탈로그 문서 | △ 문서로만 | ❌ 수동 복사 | ❌ | ❌ 작업은 가장 작지만 두 문제가 그대로다 |
| D. `domains/<영역>/` + `.claude/skills` symlink | ✅ | ❌ | ❌ | ❌ 전부 로드되니 예산 문제가 남고, 설치 경로도 없다 |
| E. `install.sh` 부활 | ✅ | ✅ | △ | ❌ ADR 0011 의 실패 사유(924줄 유지, 아무도 실행 안 함)가 그대로다 |

## 실측 (Claude Code 2.1.318, 2026-11-04)

| 검증 | 방법 | 결과 |
|---|---|---|
| 중첩 skill 경로 | 임시 폴더, `initialize` 응답 | `flat-probe` 보임, `cat/nested-probe` 안 보임 |
| plugin 로드 | `--plugin-dir plugins/dx`, `initialize` 응답 | skill+command 50/50, agent 6/6 |
| 자체 활성화 `path: "."` | 레포 루트, `initialize` 응답 | 설정 있음 50·6 / 설정 제거한 사본 0·0 |
| 실제 호출 | `claude -p`, Haiku 5.5 | skill, agent(`dx:dev-logger`), command(`/dx:where`) 성공 |
| bare 이름 | `initialize` 응답 | `/log-trouble` 은 등록되지 않는다. `-p` 에서는 모델이 `dx:log-trouble` 로 찾아 실행했다 |
| 상시 토큰 비용 | `claude plugin details` | `dx` 약 4,266 토큰 (파일럿 시점. 전체 수치는 [Migration 0003](../migration/0003-plugin-restructure.md)) |
| GitHub 설치 | 격리한 설정 폴더, `claude plugin marketplace add <repo>#<브랜치>`, `claude plugin install go@ress` | 성공. 캐시에 그 plugin 폴더만 복사되고 skill·command 15개 로드, version 은 커밋 SHA |
| 폴더 복사 | `plugins/go/skills/go-testing` 을 `.claude/skills/` 로 | 접두사 없이 `go-testing` 으로 로드 |

`claude plugin details` 는 프로젝트 설정의 marketplace 를 읽지 않는 관리 명령이다. 자체 활성화 확인에는 쓸 수 없어 `initialize` 응답을 쓴다 (`scripts/verify-plugins.sh`).

## version 을 쓰지 않는 이유

| | `version` 지정 | **미지정 (채택)** |
|---|---|---|
| 판별 기준 | 문자열이 바뀌어야 업데이트 | 설치한 폴더의 커밋 SHA |
| 사용자 업데이트 | "keeps every user on the cached copy until its author changes the string" | 해당 plugin 이 바뀌면 감지 |
| 유지 비용 | 변경마다 올려야 하고, 잊으면 조용히 옛 버전에 머문다 | 없음 |
| `claude plugin validate --strict` | 통과 | 경고로 실패 |

이 레포는 릴리스 절차가 없고 내용 수정이 잦다. 올리는 것을 잊는 쪽이 더 나쁘다. `--strict` 대신 `version` 경고만 허용하고 나머지 경고는 실패로 처리한다.

## Consequences

**얻는 것**
- 방문자가 `plugins/` 폴더와 README 만 보고 고를 수 있고, 필요한 영역만 설치할 수 있다
- 켠 plugin 만 목록 예산을 쓴다
- 자체 스크립트 없이 업데이트 감지까지 얻는다

**잃는 것 / 위험**
- 호출명이 바뀐다: `/go-testing` → `/go:go-testing`, `/log-trouble` → `/dx:log-trouble`. 접두사 중복은 이번에 정리하지 않는다
- 같은 plugin 에서 command 와 skill 의 이름이 겹치면 skill 이 이겨 command 가 사라진다. `/terraform:security` 가 이 경우라 `/infra:terraform-security-check` 로 바꿨고, 게이트가 검사한다
- 설치본에는 rule 과 `permissions.deny` 가 없다. agent 의 Permission Boundary 는 설치본에서 안내문이다. plugin README 에 명시한다
- plugin agent 에서 `permissionMode`, `hooks`, `mcpServers`, `initialPrompt` 는 무시된다. 현재 agent 34개는 쓰지 않는다
- 이 레포의 `dx` 자체 활성화에는 제약이 있다: 신뢰한 폴더에서만 동작하고, 클라우드 세션은 레포의 marketplace 를 추가하지 않으며, 상대 경로는 main checkout 기준이라 worktree 수정분은 로드되지 않는다. 이 경우 `--plugin-dir plugins/dx` 를 쓴다
- 다른 plugin 을 가리키는 `/plugin:skill` 은 그 plugin 이 없으면 열리지 않는다. README 의 "함께 쓰면 좋은 plugin" 으로 안내한다
- 여러 plugin 을 켜면 다시 예산을 넘을 수 있다

**ADR 0011 의 교훈에 대한 대응**

외부 사용자는 현재 0명이다(star 0, fork 0). "아무도 실행하지 않는 경로는 썩는다" 는 교훈이 그대로 적용된다.

- `dx` 를 이 레포에서 직접 켜서 쓴다
- `scripts/test-gates.sh` 가 marketplace, plugin 폴더, `plugin.json`, `enabledPlugins` 의 불일치를 CI 에서 잡는다
- `scripts/verify-plugins.sh` 가 실제 로드를 확인한다 (로컬, 모델 호출 없음)

**재평가 시점**: 2027-05. 외부 설치 흔적이 없고 유지 비용이 생겼다면 marketplace 제거를 검토한다. plugin 폴더 구조는 영역 구분만으로도 가치가 있어 유지 대상이다.

## 검증

```bash
make all
make test-gates
make verify-plugins
make verify-enforcement   # settings.json 을 바꾼 커밋에서 1회
```

## Sources

- https://code.claude.com/docs/en/plugins/marketplace-reference (2026-11-04)
- https://code.claude.com/docs/en/plugins/manifest-reference (2026-11-04)
- https://code.claude.com/docs/en/plugins/loading (2026-11-04)
- https://code.claude.com/docs/en/plugins/org (2026-11-04)
- 분기 재검증: 2027-02
