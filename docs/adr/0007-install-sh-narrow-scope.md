# ADR 0007 — install.sh 축소: `--plugin` / `--workflow` deprecation + 자산 단위 정밀 옵션

- **Status**: Accepted
- **Date**: 2026-05-20 (실제 커밋 `dbf5e73` 2026-05-26)
- **Driver**: install.sh 광범위 묶음 불만 ("안 쓰는 것까지 다 깔린다") + 자산 picky 운영 욕구
- **Depends on**: ADR 0006 (Kiro 어댑터 — 본 결정과 같은 picky 정신)
- **Related**: PR-8 (`install.sh` 수정 + `docs/guides/cherry-pick-assets.md`)
- **관련 plan**: `/Users/ress/.claude/plans/install-sh-staged-blossom.md` ⚠️ 다른 머신 경로 — 현재 접근 불가. 본 ADR 본문이 유일한 SOT
- **진행**: PR-1(본 ADR) 완료. **PR-8 미착수** — 백로그 추적은 [2026-08-15 audit §8 B2](../audit/2026-08-15-asset-tier-rebalance.md#84-b-트랙-정의)

> **2026-08-16 일정 정정**: 최초 절대 날짜(warn 2026-05-20 / error 06-20 / remove 07-20)는 deprecation 을 *구현하는* PR-8 이 없는 상태에서 흘러 **3단계 전부 시작된 적 없이 만료**했다. 아래 일정을 **PR-8 머지일 기준 상대 표기**로 교체한다. 결정 내용(Option 2 축소)은 불변.

## Context

`install.sh` (860 줄) 는 현재 다음 옵션만 제공한다:

```bash
./install.sh                       # 전체 설치
./install.sh --plugin go-stack     # plugins/go-stack.yml 의 묶음
./install.sh --workflow msa        # .claude/workflows/msa-migration.yml 의 시나리오
./install.sh --list-plugins        # 묶음 목록
```

문제 — **모든 설치 단위가 묶음**이다:

| 묶음 | 포함 자산 수 (예시) | 사용자 불만 |
|---|---|---|
| `--plugin go-stack` | go-* skill 10+ + database-expert agent + ... | "Go 만 쓰는데 database-expert 까지 설치됨" |
| `--workflow msa-migration` | msa-* skill 5 + monitoring + tracing + ... | "MSA 마이그레이션은 아닌데 일부만 필요" |
| `(no flag)` 전체 | skill 274 + agent 50 + rule 25 | "설치 시간 + 디스크 + 자산 노이즈" |

ressKim 본인의 정확한 표현: **"install 자체를 좀 폐기할까도 고민중이라. 이거 너무 범위가 넓어서 쓰지않는것까지 다 들어갈꺼같아."**

이 불만의 본질은 **묶음 단위만 있고 자산 단위 cherry-pick 이 없다**는 것. install.sh 자체의 자산 copy 기능은 가치 있음 — 동기화 / 다른 레포 import / CI 배포에 쓰임. 묶음 옵션이 문제.

또한 ADR 0006 의 Kiro 합류 결정과 결이 같다 — Kiro 도 자산을 골라 가져가는 picky 운영. install.sh 도 같은 정신으로 정밀 옵션이 필요.

## Decision

### 선택한 옵션: **Option 2 — 축소** (광범위 묶음 deprecation + 자산 단위 정밀 옵션 추가)

`install.sh` 의 자산 copy 기능은 유지하되:

1. **신규 옵션 추가**:
   ```bash
   ./install.sh --skill <category>/<name>   # 예: --skill go/concurrency
   ./install.sh --agent <name>              # 예: --agent code-reviewer
   ./install.sh --rule <name>               # 예: --rule security
   ```
   복수 지정 가능: `--skill go/concurrency --skill k8s/deployment-strategies`

2. **기존 광범위 옵션 deprecation 3 단계** (기준일 D0 = **PR-8 머지일**):
   | 단계 | 기간 | 동작 |
   |---|---|---|
   | warn | D0 ~ D+30 | `--plugin` / `--workflow` 사용 시 stderr 경고 + 작동 |
   | error | D+30 ~ D+60 | stderr 에러 + exit 1 (작동 안 함). `--force-legacy-bundle` 플래그로 임시 우회 |
   | remove | D+60 ~ | 옵션 자체 제거. plugins/ 디렉토리는 reference 용으로 유지 |

3. **Migration path 표** — `docs/guides/cherry-pick-assets.md` 에 plugin/workflow → 자산 픽업 매핑 표 포함.

## Considered Options

### Option 1 — install.sh 완전 폐기

- **장점**: 가장 단순. 자산 cherry-pick 만 별도 도구로
- **단점**:
  - blast radius 큼. CI / 기존 사용자 / 다른 레포 import 영향
  - 자산 copy 기능은 가치 있음 (동기화 / 배포 용도)
  - 사용자 불만의 본질은 묶음이지 install.sh 자체가 아님
- **비용**: install.sh 삭제 + 모든 의존성 마이그레이션
- **위험**: 높음

### Option 2 — 축소 (채택)

- **장점**:
  - 사용자 불만 핵심 (묶음 광범위함) 정확히 해결
  - 자산 copy 가치 유지
  - ADR 0006 의 Kiro picky 운영과 정신 일관
  - 단계적 deprecation 으로 기존 사용자 호환성 보장
- **단점**:
  - install.sh 수정 (현재 860 줄, +옵션 처리 +deprecation 로직 약 +50-80 줄)
  - 3 단계 deprecation 동안 양쪽 옵션 코드 공존
- **비용**: PR-8 (install.sh 수정 + 가이드)
- **위험**: 중간 — 단계적 deprecation 으로 완화

### Option 3 — 별도 ADR/plan 으로 분리 (본 plan 에서 제외)

- **장점**: 본 plan 의 사이즈 축소, Kiro 어댑터에 집중
- **단점**:
  - Kiro 합류 결정과 자산 picky 정신이 같은 트랙 — 분리 시 의사결정 지연
  - 두 결정이 같은 PR-8 에 자연 결합 (install.sh 의 `--skill` 옵션이 Kiro 자산 port 의 도구로도 쓰임)
- **비용**: 본 plan 사이즈 축소 / 별도 plan 추후 작성 부담
- **위험**: 낮음 — 단순 시점 이동

### Option 4 — install.sh 그대로 + 정밀 옵션 병행

- **장점**: 호환성 100%
- **단점**: 사용자 불만 (광범위 묶음) 해결 안 됨. "광범위 옵션 그대로 두면 사용자가 또 그거 쓸 거고, 결국 picky 운영 정착 안 됨"
- **비용**: PR-8 의 deprecation 로직만 빼고 옵션 추가만
- **위험**: 사용자 불만 미해결

## Consequences

### 긍정 (Pros)

- 사용자 불만 (광범위 묶음) 직접 해결
- ADR 0006 Kiro picky 운영과 SOT 정신 일관
- `--skill` 옵션이 Kiro 자산 port 의 첫 단계로도 활용 가능 (PR-6 의 multi-tool-asset-port skill 의 1 단계)
- 묶음 사용자 → 자산 단위 사용자로 자연 마이그레이션

### 부정 (Cons / Trade-offs)

- `--plugin` / `--workflow` 의존 CI 파이프라인 영향 (외부 레포 import). 3 단계 deprecation 으로 완화하지만 통보 의무
- `plugins/*.yml` (13 파일) / `.claude/workflows/*.yml` (11 파일) 의 정의 자체는 유지 가치가 있음 (reference / 자산 묶음 의도 표현) — deprecation 은 install.sh 의 묶음 옵션만, YAML 파일 자체는 보존
- install.sh 코드 복잡도 일시 증가 (양쪽 옵션 공존 2 개월)

### 중립 (Neutral)

- 자산 copy 기능 자체는 변경 없음
- `--list-plugins` / `--list-workflows` 는 reference 용도로 유지 (자산 묶음 의도 보기)
- `docs/guides/cherry-pick-assets.md` 신규

## Implementation Notes

### PR-8 작업 단위

- `install.sh` 수정
  - `--skill <cat>/<name>` 파서 + 처리 로직
  - `--agent <name>` 파서 + 처리 로직
  - `--rule <name>` 파서 + 처리 로직
  - `--plugin` / `--workflow` 사용 시 deprecation 경고 (단계별 분기)
  - `--force-legacy-bundle` 임시 우회 플래그 (Phase 2 error 단계 한정)
- `docs/guides/cherry-pick-assets.md` 신규
  - 사용 시나리오 (Go 만 / K8s 만 / MSA 일부만 / Kiro 자산 port)
  - `--skill` 옵션 사용 예
  - plugin/workflow → cherry-pick 매핑 표 (13 plugin + 11 workflow 분해)
- `.github/` CI workflow 점검 — `--plugin` / `--workflow` 사용 부분 확인 후 마이그레이션

### Deprecation 일정 (상대 표기 — D0 = PR-8 머지일)

| 단계 | 시작 | 동작 |
|---|---|---|
| Warn | D0 | stderr 경고 출력, 작동 |
| Error | D+30 | exit 1, `--force-legacy-bundle` 로 우회 가능 |
| Remove | D+60 | 옵션 자체 제거. plugins/*.yml YAML 은 보존 |

> 절대 날짜를 쓰지 않는 이유 — 최초 버전은 warn 을 ADR 작성일(2026-05-20)에 앵커했으나 구현 주체인 PR-8 이 착수되지 않아 3단계가 전부 사문화됐다. 선행 산출물 머지일 기준 상대 표기는 세션이 끊겨도 유효하다. 동일 사고가 ADR 0005("1주 baseline")에서도 발생했다.

PR-8 머지 시 이 표의 D0 을 실제 날짜로 치환한 1줄을 본 ADR 에 append 한다.

### Migration path 표 (예시 — `docs/guides/cherry-pick-assets.md` 에 포함)

| Before (광범위) | After (정밀) |
|---|---|
| `./install.sh --plugin go-stack` | `./install.sh --skill go/concurrency --skill go/error-handling --agent go-expert --rule go` |
| `./install.sh --workflow msa-migration` | `./install.sh --skill msa/saga-pattern --skill msa/outbox-pattern --agent saga-agent` |
| `./install.sh` (전체) | (사용자가 필요한 자산만 명시) |

### 롤백 계획

- Phase 1 (warn) 단계에서 사용자 항의 시 Phase 2 (error) 진입 보류, warn 영구 유지 옵션
- Phase 2 (error) 단계에서 외부 CI 영향 발견 시 `--force-legacy-bundle` 기간 연장
- Phase 3 (remove) 단계 전까지 plugin/workflow YAML 보존 → 필요 시 부활 가능

## Validation / Success Criteria

- [ ] PR-8 머지 + `./install.sh --help` 에 신규 옵션 노출 확인
- [ ] `./install.sh --skill dx/multi-tool-asset-port` 동작 검증 (단일 자산만 설치)
- [ ] `./install.sh --plugin go-stack` 실행 시 stderr deprecation 경고 출력 확인
- [ ] `tests/install.bats` L409·460·505·511 의 `--plugin` / `--workflow` 단언 갱신 (PR-8 동시 수정 대상)
- [ ] D+30 (Error 단계) 직전 외부 CI 사용처 점검 보고
- [ ] D+90 회고 — 사용자 불만 해소 / picky 운영 정착 / 자산 단위 사용 빈도

## Sources

- 사용자 불만 인용: 본 ADR Context "install 자체를 좀 폐기할까도 고민중이라. 이거 너무 범위가 넓어서 쓰지않는것까지 다 들어갈꺼같아."
- `/Users/ress/.claude/plans/install-sh-staged-blossom.md` — 본 ADR 의 plan 원본 + 의사결정 #2 채택 근거

## References

- ADR 0006 — Kiro 어댑터 (자산 picky 운영의 다른 측면)
- `install.sh` L309-312 — 기존 `--plugin` / `--workflow` 옵션 위치
- `plugins/*.yml` (13 개) — 묶음 정의 (옵션 deprecation 후에도 reference 유지)
- `.claude/workflows/*.yml` (11 개) — 시나리오 정의 (동일)
