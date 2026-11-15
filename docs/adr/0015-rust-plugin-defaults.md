# ADR 0015 — Rust plugin 기본값: 엔진 중심 범위, `rust-reviewer`, house rule 숫자, core/shell workspace

- **Status**: Accepted
- **Date**: 2026-11-15 (사용자가 같은 날 계획을 승인)
- **Driver**: 사용자의 Rust 작업은 Go API 뒤에서 도는 엔진 3개다. 설계는 정했고 코드는 아직 없다
- **Verification**: [Rust plugin 검증 기록](../audit/2026-11-15-rust-plugin-verification.md) — 이 ADR 과 Rust 자산이 인용하는 외부 사실의 출처·검증일·상태
- **Related**: [ADR 0008](0008-asset-tier-policy.md) (티어 판정, agent 분할 축), [ADR 0012](0012-native-plugin-structure.md) (plugin 구조), [ADR 0013](0013-ops-perspective-placement.md) (skill 총수 목표와의 긴장)

## Context

사용자는 Java/Spring·Go 백엔드 개발자이고 Rust 는 많이 써 보지 않았다. 역할은 이렇게 나뉜다.

| 구성 | 맡는 것 | Rust 쪽 경계 |
|---|---|---|
| Go | 요청·응답 API | — |
| track-engine | GPS 기록의 코스 구간 통과 판정, 부정 기록 필터 | Postgres 테이블 큐 워커. HTTP 는 `/metrics`·`/healthz` 만 |
| og-render | Open Graph 미리보기 이미지 (한글) | Go 가 내부 동기 HTTP 로 호출 |
| CRDT sync | 공동 편집 동기화 (Notion·Figma 류) | WebSocket |

FFI·WASM 은 지금 쓰지 않는다. 사용자가 Rust 에도 가져가려는 습관은 계층 분리, Composed Method, `@ControllerAdvice` 식 에러 집중, 사람과 AI 가 읽기 쉬운 짧은 파일이다.

결정에 걸린 사실 (✅ 2026-11-15, 출처는 검증 기록):

| 사실 | 결정에 주는 영향 |
|---|---|
| 공식·대기업 가이드(Rust Style Guide, Microsoft, Google, Linux kernel, rust-analyzer)에 함수·파일 길이 숫자 한도가 없다. 함수 길이의 숫자는 clippy `too_many_lines` 기본 threshold 100 하나다 | 숫자는 레포 house rule 로만 정할 수 있다 |
| clippy stable lint 전체에 파일·모듈 길이 lint 가 없다 | 파일 길이는 lint 로 강제할 수 없다 |
| `cognitive_complexity` 는 1.91(2025-10-30)에 restriction 으로 옮겨졌다. 문서가 이 lint 를 측정 도구로 쓰지 말라고 적는다 | 레포 공통 Code Style 의 "Cognitive Complexity ≤ 15" 를 Rust 에서 잴 수단이 없다 |
| `too_many_lines` 는 pedantic 이라 기본으로 꺼져 있고, 코드가 있는 줄만 센다. `excessive_nesting` 은 threshold 기본값 0 이라 값을 줘야 동작하고, `impl`·함수 본문 블록도 1단계로 센다 | lint 를 켜고 값을 명시해야 신호가 나온다 |
| 패키지 하나의 bin 은 `[dependencies]` 전체와 링크된다. target 별 의존성 요청(cargo#1982)은 2015-09-10 부터 열려 있다 | lib+bin 한 패키지로는 core 에 tokio·sqlx 가 들어오는 것을 막지 못한다 |
| Clippy 는 처음 찾은 clippy.toml 하나를 쓰고, 설정 파일은 "unstable and may be deprecated" 상태다 | 순수성 강제를 clippy 하나에 맡길 수 없다 |
| release 프로필의 기본 `panic` 은 `unwind` 다. 이때 task 의 panic 은 `JoinError` 로 잡히지만, `abort` 로 바꾸면 task 하나의 panic 이 프로세스 전체를 끝낸다 | 기본값을 바꾸지 않는다는 결정만 남는다 |

agent 선례도 있다. 2026-08-24 audit Step 3 에서 `go-expert`·`java-expert`(각 605줄)를 skill 로 강등했다. 조사 프로토콜도 출력 계약도 없는 레퍼런스 문서였기 때문이다 ([audit §3.1](../audit/2026-08-24-agent-harness-readiness.md#31-판정-기준)). 이 선례에 따라 조사 단계 설계안은 Rust 에도 agent 를 두지 말자고 권했다.

## Decision

1. **범위는 엔진 중심으로 잡는다.** skill 은 언어 공통 6개(`rust-idioms`, `rust-error-handling`, `rust-engine-architecture`, `rust-async-tokio`, `rust-testing`, `rust-from-spring`)와 엔진 도메인 4개(`rust-pg-queue-worker`, `rust-og-image-render`, `rust-crdt-sync`, `rust-geo-track`)를 둔다. 여기에 rule 1개, command 4개(`/rust:review`·`lint`·`refactor`·`test-gen`), agent 1개를 더한다. 처음 제안한 웹 CRUD 묶음(`rust-axum-service`, `rust-database`)은 만들지 않는다. axum 은 og-render 의 HTTP adapter 와 에러 경계(`impl IntoResponse`)에서만, sqlx 는 큐 워커에서만 다룬다. skill 은 결정 트리로 쓰고, 이 프로젝트에서 아직 정하지 않은 값은 박아 두지 않는다.
2. **`rust-reviewer` agent 를 추가한다.** ADR 0008 §3 의 관점별 축을 쓴다. 선례는 `k8s-reviewer` 와 `k8s-security-reviewer` 다. `dx:code-reviewer` 는 언어 공통의 가독성·명명·중복·테스트를 보고, `rust-reviewer` 는 컴파일러·런타임 의미에 걸린 8개 관점만 본다. 8개 관점은 소유권·clone, 에러 경계·도메인 결과, panic 경로, async, core 순수성·결정성, unsafe, lint 설정, Rust rule 준수다.
3. **숫자는 house rule 로 명시한다.** 공식·대기업 숫자 한도가 없다는 점을 [Rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 본문에 함께 적는다.

   | 항목 | 값 | 강제 수단 |
   |---|---|---|
   | 함수 길이 | `too_many_lines = "warn"` + clippy.toml `too-many-lines-threshold = 100` 명시. 20-50줄은 PREFER | clippy |
   | 중첩 | `excessive-nesting-threshold = 4` 로 시작한다. method 안 `if` 3단부터 경고 | clippy, 실측 후 조정 |
   | 파일 길이 | `.rs` 파일이 테스트 모듈을 빼고 400줄을 넘으면 분할 검토 | 리뷰 (lint 없음) |
   | unwrap | `unwrap_used = "warn"` + `allow-unwrap-in-tests = true`. 불변식은 `expect("왜 실패할 수 없는지")` 로 허용 | clippy |
   | 복잡도 | `cognitive_complexity` 는 쓰지 않는다 | — |

   숫자가 아닌 house rule 두 가지도 같이 정한다. release 프로필은 `panic = "unwind"` 를 유지하고, 의존성 타입은 concrete > generic > `dyn` 순으로 고른다.
4. **엔진은 처음부터 workspace 로 시작한다.** IO 없는 `<name>-core` lib crate 와 얇은 `<name>-worker`·`<name>-server` bin crate 로 나누고, virtual manifest 에 `resolver = "3"` 과 `[workspace.lints]` 를 둔다. 순수성은 두 겹으로 막는다. 첫째, CI 에서 `cargo tree -p <name>-core -e normal --target all --all-features` 결과에 tokio·sqlx·reqwest 가 있으면 실패시킨다. 둘째, core 의 clippy.toml 에 `disallowed-methods`(`Instant::now`, `SystemTime::now`)와 `disallowed-types`(`HashMap`, `HashSet`)를 둔다. sans-IO 상태기계는 상태가 있는 프로토콜(CRDT sync)에만 쓰고, track-engine core 는 상태 없는 판정 함수로 둔다.

## 대안 비교

### 1. 범위

| 안 | 강점 | 약점 | 판단 |
|---|---|---|---|
| a. 웹 CRUD 묶음 (조사 단계 첫 제안) | Spring 웹 구조와 1:1 로 대응한다. 일반 Rust 웹 사용자도 다시 쓸 수 있다 | 사용자의 Rust 코드에는 CRUD API 가 없다(Go 가 맡는다). 큐 lease·fencing, SVG 외부 리소스 차단, CRDT 메시지별 권한 같은 엔진 함정이 빠진다 | ❌ |
| **b. 엔진 중심** | 실제 작업과 맞는다. 언어 공통 skill 6개는 웹 서비스에도 그대로 쓴다 | skill 이 10개로 는다. 도메인 skill 4개는 다른 사용자가 다시 쓸 일이 적다 | ✅ |
| c. 웹 + 엔진 모두 | 범위가 가장 넓다 | 쓰지 않는 자산을 유지하게 된다. ADR 0011 의 교훈 "아무도 실행하지 않는 경로는 썩는다" 에 걸린다 | ❌ |

### 2. agent

| 안 | 강점 | 약점 | 판단 |
|---|---|---|---|
| a. agent 없음 (조사 설계안의 권고) | 비용이 0 이고 go·java 강등 선례와 맞는다. 초심자는 skill 을 읽으며 "왜" 를 배운다 | Rust 고유 위험을 `dx:code-reviewer` 가 skill 참조로만 본다. cargo 출력을 해석하는 다단계 조사가 메인 컨텍스트에서 돈다 | ❌ |
| b. `dx:code-reviewer` 에 Rust 블록 추가 | agent 수가 그대로고 리뷰도 한 번이다 | 언어 공통 reviewer 에 언어별 판정 기준이 쌓인다. Rust 를 쓰지 않는 `dx` 설치자에게도 실린다 | ❌ |
| **c. `rust-reviewer` (관점 축)** | 사용자가 골랐다. `.await` 너머의 lock, `select!` 취소 안전성, 세마포어 deadlock, borrow 회피용 `clone()`, core 순수성처럼 Java 감각으로 보이지 않는 위험을 전담한다. `cargo check`·`clippy`·`test` 를 돌리고 원인을 판정하는 다단계 조사라 ADR 0008 §1 의 "따로 조사해야 하나?" 에 해당한다. `## Review Process`(조사 프로토콜)와 `## Output Format`(출력 계약)을 둘 다 가지므로 audit §3.1 기준으로 정당한 agent 다 | 아래 Consequences | ✅ |

go·java 선례가 이번에 적용되지 않는 이유가 있다. 그때 강등한 이유는 레퍼런스 문서를 agent 티어에 둔 것이었다. 언어별 agent 라서 강등한 것이 아니다. `rust-reviewer` 는 출력 계약이 있는 reviewer 이고, ADR 0008 §3 이 요구하는 역할 경계·Permission Boundary·Escalation·Pair Patterns 를 모두 갖췄다.

### 3. house rule 숫자

| 안 | 강점 | 약점 | 판단 |
|---|---|---|---|
| a. clippy 기본값만 쓴다 | 설정이 필요 없다 | `too_many_lines` 는 꺼져 있고 `excessive_nesting` 은 0 이라 동작하지 않는다. 길이·중첩 신호가 없다 | ❌ |
| b. 공통 rule 숫자를 그대로 쓴다 (threshold 50, nesting 3) | clean-code 의 20-50줄과 숫자가 같다 | 50 은 PREFER 이지 금지선이 아니다. nesting 3 이면 method 안 `if` 2단부터 경고해, 실측 없이 정하면 경고 피로가 생긴다 | ❌ |
| c. Microsoft M-STATIC-VERIFICATION 템플릿을 통째로 가져온다 | 대기업 근거가 있다 | 여전히 길이 숫자가 없다. correctness 를 deny 에서 warn 으로 낮춘다 | ❌ |
| **d. house rule 명시 + 실측 후 조정** | 100 은 clean-code 의 "100줄 초과 금지" 와 짝이 맞고, config-contract-audit 의 "기본값도 명시" 를 따른다 | 실측 전에는 근거 없는 숫자다. 1.97+ lint 는 로컬 toolchain(1.96)에서 측정하지 못했다 | ✅ |

### 4. 엔진 crate 구조

| 안 | 강점 | 약점 | 판단 |
|---|---|---|---|
| a. 한 패키지 lib+bin (Book 12장 "Separating Concerns in Binary Projects") | 가장 단순하고, Book 이 권하는 첫 단계다 | bin 의 의존성이 lib 에도 열린다. core 에 tokio·sqlx 가 들어와도 막을 수 없다 (cargo#1982) | ❌ |
| b. 단일 crate + 모듈 규율 | 파일 수가 가장 적다 | 강제 수단이 없어 리뷰가 유일한 방어선이다 | ❌ |
| **c. core + shell workspace + 순수성 CI** | 경계를 Cargo 가 강제한다. core 는 test double 없이 입력 → 출력으로 테스트한다. 결정성(엔진 버전별 결과 키)을 지키기 쉽다 | 아래 Consequences | ✅ |
| d. 모든 엔진을 sans-IO 상태기계로 (quinn-proto, Firezone 방식) | 결정성과 시뮬레이션 테스트가 가장 강하다 | 인지 부하가 크고, 로직이 driver 로 새기 쉽다 (Polar Signals). 상태 없는 판정에는 과하다 | ❌ (상태 있는 프로토콜에만 쓴다) |

## Consequences

**얻는 것**
- 사용자가 실제로 만들 엔진 3개의 함정이 결정 트리와 Verification Criteria 로 남는다. 언어 공통 skill 은 다른 Rust 프로젝트에도 그대로 쓴다
- Rust 리뷰가 cargo 출력을 근거로 붙이고, finding 마다 근거 skill 을 가리킨다
- 숫자마다 "공식 근거 없음, house rule" 표시가 붙어서 나중에 조정해도 근거를 잃지 않는다
- core 에 IO crate 가 들어오면 CI 가 실패한다

**잃는 것 / 위험**
- skill 이 10개 는다 (`scripts/lib/layout.sh` 하한 272 → 282). ADR 0008 의 "skill 총수 ≤ 160" 과 반대 방향이다. 다만 이 레포는 `rust` 를 켜지 않으므로 레포 세션의 목록 예산은 그대로다. 설치자에게만 description 10개가 실린다
- agent 하한이 34 → 35 가 되고 `.claude/agent-handoff.yml` 에 등록해야 한다. plugin 설치본에서 Permission Boundary 는 안내문일 뿐이다 (ADR 0012)
- `cargo check`·`clippy`·`test` 는 읽기 전용이 아니다. `build.rs`·proc-macro·테스트 코드를 실행한다. 그래서 신뢰할 수 없는 코드는 cargo 를 돌리지 않고 정독만 하도록 agent 본문에 적었다
- 초심자가 agent 결과에 기대고 skill 을 읽지 않을 수 있다. finding 마다 근거 skill 이름을 붙여 줄인다
- house rule 숫자는 실제 Rust 코드로 측정하지 않았다. `allow-unwrap-in-tests` 가 workspace member 의 `tests/` 에도 적용되는지는 ⚠️ 로컬이 1.96 이라 측정하지 못했다
- workspace 에는 Cargo.toml 이 더 많다. crate 별 clippy.toml 을 두면 루트 threshold 를 그 파일에 복제해야 한다. 두 겹으로도 std IO(`std::fs`·`std::net`)와 금지 목록에 없는 sync IO crate 는 못 잡는다. 그 몫은 리뷰가 맡는다

**중립**
- 레포 공통 rule 의 "Cognitive Complexity ≤ 15" 는 원칙으로 남긴다. Rust 에서는 측정 수단만 `too_many_lines`·`excessive_nesting`·리뷰로 바꾼다

## 검증

**재조정 시점과 방법**
- **house rule 숫자**: 첫 엔진 crate 에 코드가 생기면 lint 별 `cargo clippy` 경고 수와 400줄 초과 파일을 dev-log 에 적는다. `excessive_nesting` 경고 중 리뷰에서 "읽기 어렵지 않음" 으로 판정한 것이 절반을 넘으면 threshold 를 올린다. 경고는 0건인데 리뷰에서 중첩 지적이 나오면 내린다. 값을 바꾸면 이 ADR 의 표와 Rust rule 을 같은 PR 에서 고친다
- **toolchain**: 로컬을 1.100 으로 올린 뒤 1.97+ lint 와 `allow-unwrap-in-tests` 적용 범위를 다시 잰다
- **`rust-reviewer` 재평가**: Rust 리뷰를 5회 돌린 뒤 판단한다. 리뷰마다 `dx:code-reviewer` 와 함께 돌려, `rust-reviewer` 만 잡은 Critical 이상 finding 수를 리뷰 출력이나 `/devlog:log-feedback` 에 남긴다. 5회 동안 0건이면 `/rust:review` command 와 skill 로 강등한다 (2026-08-24 Step 3 방식). 2027-05 까지 Rust 리뷰가 한 번도 없어도 같은 판단을 한다
- **엔진 구조**: core 마다 순수성 CI 를 도입할 때 한 번, core 에 tokio 를 임시로 넣어 CI 가 실패하는지 확인한다

**자산 검증 (로컬, 모델 호출 없음)**

```bash
./scripts/verify-plugins.sh rust
./scripts/validate-catalog.sh
python3 scripts/generate-plugin-readmes.py validate
```

코드 예시의 컴파일 결과와 DB 가 있어야 해서 돌리지 못한 블록은 검증 기록에 적는다.

## Sources

- 외부 사실: [Rust plugin 검증 기록](../audit/2026-11-15-rust-plugin-verification.md) (검증일 2026-11-15)
- 직접 근거 URL (2026-11-15): https://rust-lang.github.io/rust-clippy/stable/index.html · https://raw.githubusercontent.com/rust-lang/rust-clippy/master/book/src/configuration.md · https://github.com/rust-lang/cargo/issues/1982 · https://doc.rust-lang.org/cargo/reference/profiles.html
- 레포 사실: [ADR 0008](0008-asset-tier-policy.md) §1·§3, [2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) §3.1·Step 3, `scripts/lib/layout.sh`, 2026-11-15 확인
- 분기 재검증: 2027-02 (clippy.toml 위치, RTN·dyn async fn 안정화, Google Rust Style Guide 적용 범위)
