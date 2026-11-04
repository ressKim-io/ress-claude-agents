# Migration 0003 — 평탄 구조에서 영역별 plugin 으로

- **기간**: 2026-11-04
- **결정**: [ADR 0012](../adr/0012-native-plugin-structure.md)
- **사양 근거**: [2026-11-04 사양 검증](../audit/2026-11-04-claude-spec-verification.md)
- **과정의 문제와 재발 방지**: [dev-log](../dev-logs/2026-11-04-plugin-restructure.md)

## 무엇이 바뀌었나

skill, agent, command 가 `.claude/` 에서 `plugins/<plugin>/` 으로 옮겨 갔다. 이 레포는 `dx` 만 켜고, 다른 프로젝트는 필요한 plugin 만 설치하거나 폴더를 복사한다.

| 지표 | Before | After |
|---|---|---|
| skill 위치 | `.claude/skills/` 에 평탄하게 272개 | 17개 plugin 에 269개 (redirect 스텁 3개 제거) |
| 이 레포에서 로드되는 skill+command | 전체 | `dx` 의 50개 |
| 템플릿 description (`Use when working with ...`) | 224개 | 0개 (게이트가 강제) |
| `Use when` 없는 description | 28개 | 0개 (게이트가 강제) |
| skill `effort` | 240개 (`xhigh` 217, `low` 21, `max` 2) | 0개 (게이트가 강제) |
| 공식 필드가 아닌 frontmatter | `category` 269개, `deprecated` 240개 | 0개 (게이트가 강제) |
| agent `effort` 의 `xhigh`·`max` | 28개 | 0개 (`high`) |
| README 수치 | 46 agents / 254 skills / 12 plugins (전부 틀림) | 수치 없음, plugin 표로 대체 |
| 게이트 음성 테스트 | 0건 | `scripts/test-gates.sh` |
| skill 자동 호출률 (아래) | 40건 중 29건 | 40건 중 36건 |

## description 재작성 효과

`go`, `k8s` plugin 을 각각 켜고 프롬프트 10개씩을 두 번 돌렸다. 재작성 직전 커밋과 직후 커밋을 비교했다.

| | Before 1회차 | Before 2회차 | After 1회차 | After 2회차 |
|---|---|---|---|---|
| `go` 호출 | 7/10 | 6/10 | 9/10 | 9/10 |
| `k8s` 호출 | 8/10 | 8/10 | 9/10 | 9/10 |
| 기대한 skill 호출 (합계) | 14/20 | 13/20 | 17/20 | 17/20 |

- 새로 호출된 프롬프트: `go-testing`, `effective-go`, `k8s-scheduling`. `go-database` 는 두 회차 모두 호출되도록 안정됐다.
- 양쪽 다 호출되지 않은 프롬프트: `refactoring-go`, `netpol-defense-depth`.
- `k8s-gpu-scheduling` 을 기대한 프롬프트는 양쪽 모두 `k8s-gpu` 를 불렀다. 프롬프트에 MIG·time-slicing 을 적었으니 `k8s-gpu` 가 맞다. 기대값을 잘못 적은 것이라 호출률에는 세고, 기대한 skill 호출에는 세지 않았다.

**한계**: 표본이 작다(프롬프트 20개). Sonnet 5.5, `--tools Skill`, 첫 턴만 봤고, 빈 폴더에서 plugin 하나만 켰다. 프롬프트는 작성자가 직접 썼다. 여러 plugin 을 켰을 때의 경쟁은 측정하지 않았다. 측정 비용은 약 $1.1 이다.

## 비용: 길이는 오히려 늘었다

재작성의 목표 중 하나는 짧은 description 이었지만 합계는 늘었다. 템플릿 문구가 짧았기 때문이다. 호출률을 얻는 대가이고, 켠 plugin 만 비용을 낸다.

| | 재작성 전 | 재작성 후 |
|---|---|---|
| description 합계 (269개) | 36,710자 | 38,977자 (+6%) |
| 17개 plugin 을 모두 켰을 때 상시 토큰 | 약 33,741 | 약 39,346 (+17%) |

plugin 별 상시 토큰 (`claude plugin details`, 2026-11-04, 추정치):

| Plugin | 토큰 | Plugin | 토큰 |
|---|---|---|---|
| `dx` | 4,950 | `sre` | 2,728 |
| `observability` | 4,202 | `saas` | 2,401 |
| `infra` | 3,328 | `service-mesh` | 2,077 |
| `architecture` | 3,183 | `java` | 2,034 |
| `k8s` | 2,634 | `cicd` | 1,922 |
| `ai` | 1,816 | `security` | 1,784 |
| `platform` | 1,660 | `messaging` | 1,481 |
| `go` | 1,447 | `frontend` | 1,002 |
| `python` | 697 | | |

이 수치는 README 에 넣지 않았다. 내용을 고칠 때마다 달라지는데 검사할 방법이 없어서다. 사용자는 `claude plugin details` 로 확인한다.

## 호출명 변경

| Before | After | 비고 |
|---|---|---|
| `/go-testing` | `/go:go-testing` | 모든 skill 이 `/<plugin>:<skill>`. 복사해서 쓰면 접두사가 없다 |
| `/go:review`, `/java:*`, `/k8s:*` | 그대로 | |
| `/dx:pr-create` 등 | 그대로 | |
| `/terraform:validate`, `plan-review`, `module-gen` | `/infra:terraform-validate` 등 | |
| `/terraform:security` | `/infra:terraform-security-check` | skill `terraform-security` 에 가려져 이름을 달리했다 |
| `/backend:review` 등 | `/dx:backend-review` 등 | |
| `/session:save`, `/session:end` | `/dx:session-save`, `/dx:session-end` | |
| `/review-pr:k8s` 등 | `/dx:review-pr-k8s` 등 | |
| `/log-trouble`, `/where` 등 | `/dx:log-trouble`, `/dx:where` 등 | bare 이름은 등록되지 않는다 |
| `/help:*` | 삭제 | plugin README 로 대체 |
| `go-errors`, `istio-kiali`, `mlops-llmops` | 삭제 | `/go:effective-go`, `/service-mesh:istio-observability`, `/ai:llmops` |

agent 는 `subagent_type` 에 `<plugin>:<agent>` 로 쓴다. `/dx:review-pr-terraform` 은 `infra` 와 `sre` 의 agent 를 부르므로 두 plugin 도 있어야 한다.

## 검증

| 확인 | 결과 |
|---|---|
| 이동 대조 | 이전 대상 302개: 이동 291, 삭제 11, 누락 0. rename 커밋은 전부 R100 |
| 17개 plugin 로드 (`make verify-plugins`) | 파일 수와 로드 수 일치. 모델 호출 없음 |
| GitHub 설치 | 격리한 설정 폴더에서 `marketplace add <repo>#<브랜치>` → `install go@ress` → skill·command 15개 로드, 캐시본으로 skill 호출 성공 |
| 폴더 복사 | `go-testing` 이 접두사 없이 로드 |
| `dx` 자체 활성화 | 설정 있음 50·6 / 설정 제거한 사본 0·0 |
| 코드 구간 링크 | 원본과 대조해 달라진 곳 0건 |

**실행하지 못한 것**

- ⚠️ main 기준의 `/plugin marketplace add ressKim-io/ress-claude-agents`. 머지 전이라 브랜치 지정으로 대신했다. 머지 후 한 번 확인한다.
- ⚠️ `/doctor`, `/skill-doctor` 전후 비교. 대화형 명령이라 사용자가 실행해야 한다. 이번 작업의 출발점인 "272개 중 94개만 description 표시" 가 해소됐는지는 이 비교로만 확정된다.
- ⚠️ 일반 문장의 언급 치환 약 1,000건은 게이트만 통과했고 전수 검토하지 않았다.

## 롤백

PR 체인을 merge commit 으로 머지하므로 `git revert -m 1 <merge>` 로 되돌린다. squash 하면 `SKILL.md` 수백 개가 잘못 짝지어질 수 있어 쓰지 않는다.
