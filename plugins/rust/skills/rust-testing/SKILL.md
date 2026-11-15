---
name: rust-testing
description: "Rust 테스트 — #[cfg(test)] 단위와 tests/ 통합 테스트 배치, proptest 속성 테스트, insta·golden fixture, #[sqlx::test] 실제 DB, fake·mockall 선택, criterion·divan 벤치, nextest·doctest. Use when Rust 코드에 테스트를 추가하거나 계산 결과의 회귀를 고정할 때."
---

# Rust Testing — 배치·속성 테스트·스냅샷·실제 DB·벤치

IO 없는 core 는 값만 넣어 테스트하고, shell 은 실제 Postgres 와 좁은 fake 로 테스트한다. 계산 결과의 회귀는 proptest(성질)와 insta(값) 두 겹으로 고정한다. 예시의 `engine_core` 는 IO 없는 core lib crate, `engine_worker` 는 shell crate(`lib.rs` + 조립만 하는 `main.rs`)다. 구조는 [rust-engine-architecture](../rust-engine-architecture/SKILL.md) 의 `<name>-core`·`<name>-worker` 를 따른다. 이름 규칙·Given-When-Then·커버리지 기준은 레포 [testing rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/testing.md) 을 따르고, 여기서는 그것을 Rust 로 구현하는 방법만 다룬다.

## Quick Reference (결정 트리)

```
무엇을 검증하나?
├─ core 의 순수 계산 (IO 없음) ─────> 같은 파일 #[cfg(test)] mod tests, 값만 넣고 비교
├─ 어떤 입력이든 성립해야 하는 성질 ─> proptest (범위를 정한 strategy)
├─ 큰 구조체·JSON 결과의 회귀 ──────> insta snapshot + float redaction
├─ 실제 입력 파일 → 결과 고정 ──────> tests/fixtures + insta::glob! (golden)
├─ 공개 API 만 쓰는 시나리오 ───────> tests/*.rs (파일마다 별도 crate)
├─ HTTP handler·라우팅 ────────────> Router::oneshot (서버를 띄우지 않음)
├─ SQL·제약·트랜잭션 ──────────────> 실제 Postgres — #[sqlx::test] 또는 testcontainers
├─ 성능 회귀 ──────────────────────> criterion (benches/, harness = false)
└─ 네트워크 단절·재연결 ───────────> turmoil (참조 스킬의 rust-crdt-sync)
바깥 경계를 대신할 것이 필요한가?
├─ core 함수 ───────────────> 필요 없음. 시간·설정은 인자로 받는다
├─ 결과만 돌려주면 된다 ─────> 좁은 trait + hand-written fake (기본)
├─ 호출 횟수·인자가 계약이다 ─> mockall #[automock]
└─ trait 를 만들 이유가 없다 ─> 비공개 enum (Native / Mocked)
```

## 배치 — 단위·통합·doctest

| 종류 | 위치 | 보이는 범위 | 명령 |
|---|---|---|---|
| 단위 | 같은 파일 `#[cfg(test)] mod tests` | 비공개 항목까지 (자식 모듈) | `cargo test --lib` |
| 통합 | `tests/*.rs` — 파일마다 별도 crate | `pub` API 만 | `cargo test --test <파일명>` |
| 통합 공용 helper | `tests/common/mod.rs` (Book 권장. `tests/common.rs` 는 그것도 테스트 crate 가 되어 출력에 나온다) | — | 각 파일에서 `mod common;` |
| doctest | `///` 안의 코드 블록 | `pub` API, **library target 만** | `cargo test --doc` |
| 벤치 | `benches/*.rs` | `pub` API | `cargo bench` |

- `main.rs` 만 있는 binary crate 의 함수는 `tests/` 에서 `use` 할 수 없다. shell crate 도 로직을 `lib.rs` 에 두고 `main.rs` 는 조립만 한다. 공개 API 만 쓰는 테스트는 `tests/` 로 보낸다 (Microsoft M-INTEGRATION-TESTS — library 장의 지침이라 앱 crate 에 적용하는 것은 해석이다). src 파일이 테스트로 길어지지 않는다. 파일 길이 house rule(테스트 모듈 빼고 400줄)은 [rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 기준이다. Java 처럼 테스트하려고 `private` 을 package-private(`@VisibleForTesting`)으로 넓힐 필요가 없다 — 단위 테스트가 자식 모듈이라 비공개 항목을 본다.

## 이름과 구조 — should_x_when_y + Given-When-Then

Rust 에 테스트 이름 규칙은 따로 없다. snake_case 만 지키면 되므로 레포 규칙 `should_행위_when_조건` 을 그대로 쓴다. `// When` 이 두 번 나오면 테스트를 나눈다.

```rust
// 대상: pub fn average_speed(distance_m: f64, elapsed_s: f64) -> Result<MetersPerSecond, SpeedError>
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn should_double_speed_when_elapsed_is_halved() -> Result<(), SpeedError> {
        // Given
        let base = average_speed(1_000.0, 500.0)?;
        // When
        let faster = average_speed(1_000.0, 250.0)?;
        // Then — 2.0·4.0 처럼 f64 로 정확히 표현되는 값만 골랐다. 그 외에는 상대 오차로 비교
        assert_eq!(faster.get(), base.get() * 2.0);
        Ok(())
    }
}
```

- 준비 단계가 `Result` 를 돌려주면 테스트가 `Result<(), E>` 를 반환하게 하고 `?` 를 쓴다. 이 형태에는 `#[should_panic]` 을 붙일 수 없다. Err 자체는 `?` 대신 `assert_eq!(r, Err(SpeedError::InvalidElapsed))`·`matches!` 로 검증한다. unwrap 은 rule 의 lint 설정(house rule: `unwrap_used = "warn"` + clippy.toml `allow-unwrap-in-tests = true`)을 따른다. `tests/` helper(`tests/common/mod.rs` 포함)의 처리는 clippy 1.96 실측과 1.100 CHANGELOG 가 다르다 — [rust-idioms](../rust-idioms/SKILL.md). helper 는 버전과 상관없이 `expect("왜 실패할 수 없는지")` 로 쓴다.

```rust
// ❌ BAD: 구현과 같은 식으로 기대값을 만든다 — 식이 틀려도 통과한다
assert_eq!(average_speed(d, t), Ok(MetersPerSecond(d / t)));
// ✅ GOOD: 손으로 계산한 값
assert_eq!(average_speed(1_000.0, 250.0), Ok(MetersPerSecond(4.0)));
```

## 속성 테스트 — proptest

예시 몇 개 대신 "어떤 입력이든 성립해야 하는 성질" 을 적는다. 엔진에서는 "점을 중복해도 판정이 같다", "역방향 트랙은 방향 구간을 통과하지 못한다", "update 를 어떤 순서로 적용해도 수렴한다" 같은 것이다. 도메인별 성질은 각 도메인 skill 에 있다.

```rust
// src/path.rs 끝 #[cfg(test)] mod tests { … } 안
use super::*;
use proptest::prelude::*;
fn point() -> impl Strategy<Value = Point> {
    (-50_000.0..50_000.0_f64, -50_000.0..50_000.0_f64).prop_map(|(x, y)| Point { x, y })
}
proptest! {
    #[test]
    fn should_keep_length_when_a_point_is_duplicated(
        points in prop::collection::vec(point(), 1..200),
        at in any::<prop::sample::Index>(),
    ) {
        // Given
        let i = at.index(points.len());
        let mut duplicated = points.clone();
        duplicated.insert(i, points[i]);
        // When
        let length = path_length(&duplicated);
        // Then — 합산 순서가 바뀌면 마지막 비트가 달라지므로 상대 오차로 비교
        let expected = path_length(&points);
        prop_assert!((length - expected).abs() <= 1e-9 * expected.max(1.0));
    }
}
```

- 기본 256 case. 야간 CI 처럼 오래 돌릴 곳에서는 `PROPTEST_CASES=10000` 으로 늘린다. 본문에서 `?` 를 쓸 수 있다 (`std::error::Error` 구현 타입이 `TestCaseError` 로 변환된다). 실패하면 축소(shrink)한 입력의 seed 가 소스 경로 이름으로 저장된다. 실측: `src/path.rs` 의 실패 → crate 루트 `proptest-regressions/path.txt`. **커밋한다** — 다른 사람과 CI 가 같은 case 를 먼저 재생한다.

## 스냅샷과 golden fixture — insta

구조체 전체를 기대값으로 고정할 때 쓴다. 필드를 하나씩 `assert_eq!` 하면 새 필드가 생겨도 테스트가 모른다. golden 은 실제 입력 파일마다 스냅샷을 하나씩 만든다. fixture 를 추가하면 테스트가 늘어난다. 스냅샷 파일 이름에 fixture 이름이 붙는다 (실측: `golden__should_match_golden_when_replaying_fixtures@out_and_back.json.snap`). 단위 테스트에서는 같은 `assert_json_snapshot!` 을 `glob!` 없이 쓴다.

```rust
// tests/golden.rs (core crate) — common::load_points 는 tests/common/mod.rs 에서 fixture JSON 을 읽는다
mod common;
use engine_core::summarize;
#[test]
fn should_match_golden_when_replaying_fixtures() {
    insta::glob!("fixtures/*.json", |path| {
        // Given
        let points = common::load_points(path);
        // When
        let summary = summarize(&points);
        // Then
        insta::assert_json_snapshot!(summary, {
            ".distance_m" => insta::rounded_redaction(2),
            ".max_step_m" => insta::rounded_redaction(2),
        });
    });
}
```

| 상황 | 동작 (로컬 실측) | 할 일 |
|---|---|---|
| 첫 실행·값 변경 | 기본 `INSTA_UPDATE=auto` → `.snap.new` 를 쓰고 **테스트 실패**. CI 를 감지하면 `auto` 는 `no` (파일을 쓰지 않음) | diff 를 보고 받아들일지 정한다. CI 에는 `INSTA_UPDATE=no` 를 명시 |
| 받아들이기 | `cargo insta review` (cargo-insta 설치 시) 또는 `INSTA_UPDATE=always cargo test` → `.snap` 기록, 통과 | 스냅샷 diff 를 PR 리뷰에 올린다 |
| `always` 직후 | 이전 `.snap.new` 가 남아 있다가 다음 통과 실행에서 지워졌다 | `INSTA_UPDATE=no cargo test` 를 한 번 더 돌리고 커밋 |

- 공식 기본 feature 는 `colors` 뿐이다 (`json`·`yaml` 은 legacy 로 제한적으로 켜져 있고, 명시하지 않으면 deprecation 경고가 난다). `json`·`redactions`·`glob` 을 명시한다. 출력에 `HashMap` 순회 순서가 들어가면 실행마다 스냅샷이 바뀐다. 결과 타입은 `BTreeMap`/`Vec` 으로 둔다. `Settings::set_sort_maps(true)` 는 기본 false 이고 `assert_debug_snapshot!` 에는 적용되지 않는다. 스냅샷 본문에 `engine_version` 필드를 넣는다 (예시의 `Summary` 가 그렇다). 버전과 출력이 같은 diff 에서 리뷰된다. toolchain·의존성 업그레이드 PR 에서는 스냅샷 diff 가 곧 동작 변경 목록이다. 판정 결과가 바뀌면 결과 키의 엔진 버전을 올릴지 정한다 — [rust-engine-architecture](../rust-engine-architecture/SKILL.md). 도메인 fixture 의 내용(GPS 이상치, 한글·이모지 문자열, 이미지 픽셀 허용오차)은 각 도메인 skill 이 정한다. 이미지 바이트 비교용 `assert_binary_snapshot!` 은 insta 문서상 Experimental 이다.

## 실제 DB — #[sqlx::test] 와 testcontainers

SQL·제약·`ON CONFLICT` 는 mock 으로 검증할 수 없다. 레포 testing rule 대로 실제 Postgres 를 쓴다. 단, 테스트 안에 SQL 을 복사해 두면 production 쿼리가 틀려도 통과한다. Given·When 은 production adapter 를 부르고, SQL 은 Then 의 확인에만 쓴다.

| | `#[sqlx::test]` | testcontainers |
|---|---|---|
| 필요한 것 | 떠 있는 Postgres + **superuser** `DATABASE_URL` | Docker |
| 격리 | 테스트마다 새 DB, crate 루트 `migrations/` 자동 적용 | 컨테이너마다 새 서버 |
| 쓸 때 | 기본. CI 의 Postgres service 와 짝 | superuser 를 줄 수 없거나 Postgres major·extension 을 고정할 때 |

```rust
// tests/db.rs (shell crate) — INSERT … ON CONFLICT 는 PgResultStore(outbound adapter) 안에 있다
use engine_core::{ENGINE_VERSION, Summary, summarize};
use engine_worker::{PgResultStore, ResultKey, ResultStore, StoreError};
use sqlx::PgPool;
#[sqlx::test]
async fn should_keep_one_row_when_same_key_is_upserted_twice(pool: PgPool) -> Result<(), StoreError> {
    // Given
    let store = PgResultStore::new(pool.clone());
    let key = ResultKey { subject_id: 42, engine_version: ENGINE_VERSION };
    let summary = |distance_m| Summary { distance_m, ..summarize(&[]) };
    store.upsert(key, &summary(100.0)).await?;
    // When
    store.upsert(key, &summary(120.0)).await?;
    // Then — SQL 은 결과 확인에만 쓴다
    let (rows, distance): (i64, f64) =
        sqlx::query_as("SELECT count(*), max(distance_m) FROM results WHERE subject_id = 42").fetch_one(&pool).await?;
    assert_eq!((rows, distance), (1, 120.0));
    Ok(())
}
```

- `migrate` feature 를 켜고 DB 인자(`Pool`·`PoolConnection`·`PoolOptions`+`ConnectOptions`)를 받으면 테스트마다 새 DB 를 만든다. 반환형은 `()` 또는 `Result<_, _>` 다. 실패한 테스트의 DB 는 디버깅용으로 남고 다음 실행 때 지워진다. 이 정리 판단에서는 panic 을 `#[should_panic]` 이어도 실패로 보고 DB 를 남긴다. `#[tokio::test]` 의 인자(`flavor`, `start_paused` 등)는 받지 않는다. 준비 데이터는 `fixtures("users")` 로 SQL 파일을 적용한다. 경로는 테스트 파일 기준이라 `tests/db.rs` 면 `tests/fixtures/users.sql` 이다 (실측: 파일이 없으면 이 경로로 컴파일 오류). golden fixture 와 같은 `tests/fixtures/` 관례다. 인자가 없으면 crate 루트(CARGO_MANIFEST_DIR)의 `migrations/` 를 적용한다 (예시가 그렇다. 실측: 디렉토리가 없으면 오류 없이 마이그레이션 없이 돈다). `migrations = "<path>"` 의 기준도 crate 루트다 — 테스트 파일 기준인 `fixtures` 와 다르다. `./migrations`·`../x/migrations` 는 되지만 디렉토리 이름 하나(`"migrations"`)만 쓰면 "paths relative to the current file's directory are not currently supported" 로 컴파일 실패한다 (sqlx 0.9 실측, sqlx-macros-core `common.rs`). docs.rs 의 `"foo_migrations"` 예시도 0.9 에서 그대로는 컴파일되지 않는다. Go 쪽 마이그레이션을 그대로 가리키려면 파일이 sqlx 형식(`<VERSION>_<DESC>.sql` 또는 `.up.sql`/`.down.sql`)이어야 한다. sqlx 는 파일 이름에서 버전·방향을 읽고 파일 전체를 실행하므로, Up·Down 을 한 파일 안 주석으로 나눈 형식은 Down 까지 돈다. 그런 형식이면 `#[sqlx::test(migrations = false)]` 로 끄고 스키마를 직접 만들거나, Go 도구로 마이그레이션한 DB(testcontainers 등)에 붙는다. 스키마 소유 결정은 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) 에서 본다.
- `DATABASE_URL` 이 없으면 `DATABASE_URL must be set` 으로 panic 한다 (실측). 그래서 `tests/db.rs` 를 `[[test]] required-features = ["db-tests"]` 로 묶는다 (아래 shell `Cargo.toml`). feature 가 꺼져 있으면 cargo 가 그 target 만 건너뛰어 DB 없는 로컬의 `cargo test` 도 golden·HTTP·doctest 는 돈다. CI 는 `--all-features` 로 돌린다. clippy 도 feature 를 켜야 `db.rs` 를 검사한다 (실측: 끄면 `--all-targets` 에서도 빠진다). 큐 claim·lease·SKIP LOCKED 동시성 테스트는 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) 에 있다. testcontainers 는 아래처럼 컨테이너를 띄워 그 주소로 pool 을 만드는 부분만 다르다 (계정·DB 이름 `postgres` 는 모듈 기본값). testcontainers-modules 0.15 는 testcontainers `^0.27` 에 의존하므로 re-export(`testcontainers_modules::testcontainers`)를 쓴다. testcontainers 0.28 을 따로 넣으면 의존성 해석에서 실패한다 (실측: `bollard-stubs` 충돌). 개념 비교는 `/java:spring-testcontainers`.

```rust
use testcontainers_modules::{postgres::Postgres, testcontainers::{ImageExt, runners::AsyncRunner}};
let container = Postgres::default().with_tag("18-alpine").start().await?; // 생략하면 모듈 기본 11-alpine — 운영 DB 와 같은 major 로 고정
let (host, port) = (container.get_host().await?, container.get_host_port_ipv4(5432).await?);
let pool = PgPool::connect(&format!("postgres://postgres:postgres@{host}:{port}/postgres")).await?;
sqlx::migrate!("./migrations").run(&pool).await?;
```

## Test double — fake 가 기본, mockall 은 호출 검증

core 는 IO 가 없으므로 double 이 필요 없다. 시간은 `now` 인자로, 설정은 `Params` 값으로 받는다 (Functional Core / Imperative Shell). double 은 shell 의 바깥 경계에만 두고, 경계 trait 는 메서드 1~3개로 좁게 만든다. 의존성 형태(concrete > generic > dyn)는 [rust-engine-architecture](../rust-engine-architecture/SKILL.md) 를 따른다. fake 는 결과와 저장된 상태를 보며 대부분 이것으로 충분하다 (레포 rule 의 "단순 데이터 반환이면 Stub"). trait 는 `tests/db.rs` 가 production adapter(`PgResultStore`)를 부를 수 있게 `pub` 이다. `pub trait` 에 그냥 `async fn` 을 쓰면 `async_fn_in_trait` 경고가 나서 (실측) `-> impl Future + Send` 로 적는다. 구현과 fake 는 `async fn` 으로 쓴다.

```rust
#[cfg_attr(test, mockall::automock)]
pub trait ResultStore {
    fn upsert(&self, key: ResultKey, summary: &Summary)
        -> impl Future<Output = Result<(), StoreError>> + Send; // Send 는 trait 에 적는다
}
// #[cfg(test)] mod tests 안 — fake 는 production 빌드에 들어가지 않는다
#[derive(Default)]
struct InMemoryStore {
    saved: std::sync::Mutex<Vec<ResultKey>>, // await 를 가로질러 잡지 않으므로 std Mutex
}
impl ResultStore for InMemoryStore {
    async fn upsert(&self, key: ResultKey, _summary: &Summary) -> Result<(), StoreError> {
        self.saved.lock().expect("poisoned only if another holder panicked").push(key);
        Ok(())
    }
}
```

mockall 은 호출 횟수·인자가 계약일 때만 쓴다 (Mockito `verify(times(1))` 에 해당). 대상 `record(&store, ..)` 는 요약을 계산해 `upsert` 를 한 번 부른다. `line()` 은 점 두 개짜리 테스트 입력을 만드는 helper 다.

```rust
use std::future::ready; // tests 모듈 안
#[tokio::test]
async fn should_call_upsert_once_when_store_fails() {
    // Given
    let mut store = MockResultStore::new();
    store
        .expect_upsert()
        .withf(|key, _| key.engine_version == ENGINE_VERSION)
        .times(1) // 재시도는 큐가 맡는다 — 여기서 다시 부르면 실패
        .returning(|_, _| Box::pin(ready(Err(StoreError::Db(sqlx::Error::PoolTimedOut)))));
    // When
    let result = record(&store, 42, &line()).await;
    // Then
    assert!(matches!(result, Err(StoreError::Db(sqlx::Error::PoolTimedOut))));
}
```

- `#[automock]` 은 trait 와 impl 블록이 하나인 struct 를 mock 한다 (나머지는 `mock!`). 이름은 `Mock` + 원래 이름이고, 기대와 다른 호출은 panic 한다. `impl Future` 를 돌려주는 메서드는 expectation 이 `Pin<Box<dyn Future>>` 라 `Box::pin(..)` 으로 돌려준다. native `async fn` in trait(Rust 1.75 부터 언어 차원에서 부분 지원)·`#[async_trait]`·`#[trait_variant::make]` 와 호환된다. 문서가 적는 제약은 두 가지다: `#[automock]` 을 그 매크로보다 **위에** 두고, 매크로는 원래 이름으로 import 한다. mockall 은 `[dev-dependencies]` 에 두고 `cfg_attr(test, ..)` 로 붙인다. release 빌드에 mock 이 들어가지 않는다 (실측: 같은 crate 단위 테스트에서 동작). struct 를 통째로 바꾸는 mockall_double 은 측정하지 않았다 ⚠️ — 좁은 trait 를 만든다. trait 를 만들 이유가 없는 시스템 호출은 비공개 enum(`Native`/`Mocked`)으로 감싼다 (M-MOCKABLE-SYSCALLS). 다른 crate 테스트에 fake·builder 를 내줄 때는 `test-util` feature 하나 뒤에 둔다 (M-TEST-UTIL. 둘 다 Microsoft library 장 지침이라 앱 적용은 해석).
- shell 의 tokio 타이머(lease·backoff)는 실제로 기다리지 않는다. `#[tokio::test(start_paused = true)]`(tokio `test-util` feature)로 시간을 멈추면 runtime 이 할 일이 없을 때 시간이 자동으로 앞당겨진다. 실제 IO(DB·소켓)를 기다리는 테스트와 섞지 않는다. IO 를 기다리는 동안에도 시간이 앞당겨져 timeout 이 바로 터진다 (실측: 30초 timeout 이 0.00s 에 만료).

## HTTP 경계 — Router::oneshot

`Router` 는 tower `Service` 라 서버 없이 요청 하나를 보낼 수 있다. dev-dependency 에 `tower`(`util` feature)가 필요하고, body 는 `http_body_util::BodyExt::collect` 로 읽는다. 에러 응답 매핑(`IntoResponse`) 테스트도 같은 방식이고, 매핑 규칙은 rust-error-handling 에 있다.

```rust
// tests/http.rs (shell crate) — engine_worker 의 lib.rs 가 Router 를 조립한다
use axum::{body::Body, http::{Request, StatusCode}};
use http_body_util::BodyExt; // collect
use tower::ServiceExt; // Router::oneshot
#[tokio::test]
async fn should_return_ok_when_healthz_is_called() {
    // Given
    let request = Request::get("/healthz").body(Body::empty()).expect("static request is valid");
    // When
    let response = engine_worker::app().oneshot(request).await.expect("Router error type is Infallible");
    // Then — into_body() 가 response 를 소비하므로 status 를 먼저 본다
    assert_eq!(response.status(), StatusCode::OK);
    let body = response.into_body().collect().await.expect("in-memory body").to_bytes();
    assert_eq!(&body[..], b"ok");
}
```

## 벤치와 Cargo.toml — criterion

criterion 을 기본으로 쓴다 (0.8 계열, 저장소는 criterion-rs 로 이전). divan 은 검증일 기준 1년 넘게 새 릴리스가 없어 이미 쓰는 프로젝트만 유지한다.

```rust
use std::hint::black_box;
use criterion::{BenchmarkId, Criterion, criterion_group, criterion_main};
use engine_core::{Point, path_length};
fn bench_path_length(c: &mut Criterion) {
    let mut group = c.benchmark_group("path_length");
    for n in [1_000_u32, 10_000, 100_000] {
        let points: Vec<Point> = (0..n).map(|i| Point { x: f64::from(i), y: 0.0 }).collect();
        group.bench_with_input(BenchmarkId::from_parameter(n), &points, |b, pts| {
            b.iter(|| path_length(black_box(pts)));
        });
    }
    group.finish();
}
criterion_group!(benches, bench_path_length);
criterion_main!(benches);
```

```toml
# crates/engine-core/Cargo.toml — IO 없는 core: 테스트 의존성도 계산 검증 도구만
[lib]
bench = false # cargo bench -- <criterion 옵션> 이 lib 의 libtest 하네스로 가지 않게
[[bench]]
name = "path_length"
harness = false
[dev-dependencies]
proptest = "1.12"
insta = { version = "1.49", features = ["json", "redactions", "glob"] }
criterion = "0.8"
```

```toml
# crates/engine-worker/Cargo.toml (테스트 관련 부분만 — axum·tokio 런타임·engine-core 등 production 의존성은 생략)
[features]
db-tests = [] # 실제 Postgres 가 있어야 도는 target 을 켠다
[[test]]
name = "db"
required-features = ["db-tests"]
[dependencies]
sqlx = { version = "0.9", features = ["runtime-tokio", "postgres", "macros", "migrate"] }
[dev-dependencies]
mockall = "0.15"
tokio = { version = "1.54", features = ["macros", "rt", "test-util"] }
tower = { version = "0.5", features = ["util"] }
http-body-util = "0.1"
testcontainers-modules = { version = "0.15", features = ["postgres"] }
```

- `[lib] bench = false` 가 없으면 `cargo bench -- --warm-up-time 0.1` 이 lib 하네스에서 `Unrecognized option` 으로 멈춘다 (실측, criterion FAQ). workspace 루트에서 옵션을 넘기면 shell crate 의 lib·bin 하네스도 같은 이유로 멈춘다 (실측: core 벤치가 돈 뒤 exit 101). `cargo bench -p engine-core --bench path_length -- --warm-up-time 0.1` 처럼 대상을 지정하거나, 그 crate 의 `[lib]`·`[[bin]]` 에도 `bench = false` 를 둔다 (criterion FAQ). `black_box` 는 `std::hint` 것을 쓴다. 입력 크기를 행렬로 두면 복잡도 회귀가 보인다. CI 는 `cargo bench --no-run` 으로 컴파일만 확인하고, 수치 비교는 같은 머신에서 한다.

## 실행·커버리지

```bash
cargo nextest run --workspace --all-features      # 테스트마다 별도 프로세스. DB 없는 로컬은 --all-features 를 빼 db target 을 건너뛴다
cargo test --doc --workspace                      # nextest 는 doctest 를 돌리지 않는다
INSTA_UPDATE=no PROPTEST_CASES=10000 cargo nextest run --workspace --all-features   # 야간 CI
# 커버리지 — doctest 커버리지는 nightly 전용이라 네 단계 모두 같은 nightly toolchain 에서. --no-report 는 이전 산출물을 지우지 않아 clean 부터
cargo llvm-cov clean --workspace && cargo llvm-cov --no-report nextest --workspace --all-features \
  && cargo llvm-cov --no-report --doc --workspace && cargo llvm-cov report --doctests --lcov --output-path lcov.info
```

- 커버리지 기준(전체 80%, 핵심 로직 95%)과 happy·edge·error 세 경로는 레포 testing rule 이 정한다. 에러 경로 목록은 `/dx:negative-path-coverage`. `cargo test --doc` 은 `--lib`·`--test` 와 섞을 수 없다 (실측: "can't mix --doc with other target selecting options"). `--all-targets` 도 doctest 를 포함하지 않는다. nextest 가 없으면 `cargo test` 하나가 셋 다 돈다. doctest 는 공개 API 사용 예이자 테스트다. `?` 를 쓰려면 마지막에 숨김 줄 `# Ok::<(), E>(())` 를 둔다.

````rust
/// ```
/// let speed = engine_core::average_speed(1_000.0, 250.0)?;
/// assert_eq!(speed.get(), 4.0);
/// # Ok::<(), engine_core::SpeedError>(())
/// ```
````

## Anti-Patterns

| 실수 | 문제 | 해결 |
|---|---|---|
| 구현과 같은 식으로 기대값 계산 | 식이 틀려도 통과 (동어반복) | 손으로 계산한 값·경계값·독립 oracle |
| proptest 에 `f64::ANY` | NaN·inf 실패만 찾는다 | 도메인 범위 strategy, NaN 은 별도 단위 테스트 |
| CI 에서 `INSTA_UPDATE=always` | 회귀가 스냅샷 갱신으로 묻힘 | CI 는 `no`, 갱신은 로컬에서 리뷰 후 |
| 테스트끼리 DB 하나 공유·순서 의존 | 병렬 실행에서 간헐 실패 | `#[sqlx::test]` 테스트별 DB |
| core 까지 mock, 모든 의존성에 trait + mockall | 테스트가 구현을 따라 깨짐, Java 식 interface 남발 | core 는 값으로, shell 경계는 fake 기본, mockall 은 호출 계약만 |
| `tokio::time::sleep` 으로 실제 대기 | 느리고 간헐 실패 (rule 의 sleep 금지) | `start_paused = true` 또는 채널·이벤트로 대기 |
| `cargo nextest run` 만 실행 | doctest 누락 | `cargo test --doc` 을 함께 |
| 실패 테스트에 `#[ignore]` | 실패를 숨김 (rule 의 `@Disabled` 금지와 같음) | 고치거나 이슈에 원인을 적는다 |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:
1. **[기능 검증]** — `cargo nextest run --workspace --all-features`(또는 `cargo test --workspace --all-features`)와 `cargo test --doc --workspace` 가 통과한다. DB 테스트는 실제 Postgres(superuser `DATABASE_URL` 또는 Docker)에서 돌았고, production adapter 를 거쳤다 (테스트 안에 SQL 복사본 없음)
2. **[회귀 고정]** — 계산 결과마다 proptest 성질 1개 이상과 snapshot 또는 golden 1개 이상이 있다. `INSTA_UPDATE=no cargo test` 가 통과하고 `find . -name '*.snap.new' -o -name '*.pending-snap'` 결과가 비어 있다. 실패로 `proptest-regressions/` 가 생겼다면 커밋돼 있다 (`.gitignore` 에 없다)
3. **[lint]** — `cargo clippy --workspace --all-targets --all-features -- -D warnings` 가 테스트·벤치·`required-features` target 까지 포함해 통과하고 `cargo bench --no-run` 이 컴파일된다. 테스트용 의존성을 옮긴 뒤에도 core 가 [rust-engine-architecture](../rust-engine-architecture/SKILL.md) 의 `cargo tree` 순수성 검사를 통과한다 (axum·sqlx·tokio 는 shell 에만)
4. **[일관성]** — 테스트 이름이 `should_x_when_y` 이고 Given/When/Then 주석이 있다 (`grep -rnE --include='*.rs' --exclude-dir=target -A2 '#\[(tokio::|sqlx::)?test' . | grep -E 'fn [a-z_0-9]+\(' | grep -v 'fn should_'` 결과 없음 — `proptest!` 안의 `#[test]` 도 잡힌다). 배치·unwrap 정책은 [rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md), 커버리지는 [testing rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/testing.md) 과 맞는다

## 참조 스킬

- [rust-engine-architecture](../rust-engine-architecture/SKILL.md) (core/shell 분리, 시간 주입, 결정성(BTreeMap), 엔진 버전 — golden 이 안정적인 전제) · [rust-idioms](../rust-idioms/SKILL.md) (`[lints]`·clippy.toml 템플릿, `allow-unwrap-in-tests`) · rust-error-handling (에러 분류·`IntoResponse` 매핑 — 에러 경로 테스트의 기대값) · rust-from-spring (JUnit·Mockito·`@SpringBootTest` 대응표) · 도메인별 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) (claim·lease·reaper 를 실제 Postgres 로 테스트) · rust-geo-track (GPS fixture, 게이트 통과 proptest 성질) · rust-og-image-render (이미지 golden 과 픽셀 허용오차, 한글 fixture) · [rust-crdt-sync](../rust-crdt-sync/SKILL.md) (수렴성 proptest, turmoil 단절·재연결 시뮬레이션) · `/dx:negative-path-coverage` (timeout·부분 실패 같은 에러 경로 체크리스트) · `/java:spring-testcontainers` (Testcontainers 개념, Java)

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. 코드 블록은 core·shell 두 crate 로 나눈 scratch workspace 에서 rustc 1.96 으로 `cargo check`·`cargo clippy -D warnings` 를 통과했고, 순수 로직·snapshot·mock·HTTP 테스트는 실행까지 했다. DB·Docker 가 필요한 테스트는 컴파일만 확인했다. 다음 재검증은 2027-02. 아래 출처는 모두 검증일 2026-11-15, 검증자 subagent 다.

- [Rust Book 11.1](https://doc.rust-lang.org/book/ch11-01-writing-tests.html) · [Rust Book 11.3](https://doc.rust-lang.org/book/ch11-03-test-organization.html) · [cargo test](https://doc.rust-lang.org/cargo/commands/cargo-test.html) · [Cargo targets](https://doc.rust-lang.org/cargo/reference/cargo-targets.html) · [rustdoc doctests](https://doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html) — ✅ verified (+ `--doc` 혼용 오류 로컬 실측); [API Guidelines — Naming](https://rust-lang.github.io/api-guidelines/naming.html) · [Microsoft Pragmatic Rust Guidelines — Resilience](https://microsoft.github.io/rust-guidelines/guidelines/libs/resilience/index.html) · [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) — ✅ verified (테스트 이름 규칙 부재, M-INTEGRATION-TESTS·M-MOCKABLE-SYSCALLS·M-TEST-UTIL. Microsoft 지침은 library 장이라 앱 crate 적용은 해석); [Clippy unwrap_used](https://rust-lang.github.io/rust-clippy/stable/index.html#unwrap_used) · [Clippy CHANGELOG](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/CHANGELOG.md) — ✅ verified / ⚠️ 1.100 의 integration test 적용은 로컬 1.96 에서 측정 불가; [proptest Config](https://docs.rs/proptest/1.12.0/proptest/test_runner/struct.Config.html) · [Failure persistence](https://proptest-rs.github.io/proptest/proptest/failure-persistence.html) · [insta](https://docs.rs/insta/1.49.0/insta/) · [Redactions](https://insta.rs/docs/redactions/) · [Advanced](https://insta.rs/docs/advanced/) — ✅ verified (+ regressions 경로, `.snap.new` 생성·삭제 로컬 실측); [sqlx::test](https://docs.rs/sqlx/0.9.0/sqlx/attr.test.html) · [MigrationSource](https://docs.rs/sqlx/0.9.0/sqlx/migrate/trait.MigrationSource.html) · [sqlx-macros-core 0.9.0 common.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-macros-core/src/common.rs) · [sqlx-core 0.9.0 migrate/source.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/migrate/source.rs) · [migration_type.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/migrate/migration_type.rs) — ✅ verified (+ 한 단계 상대 경로 컴파일 오류·인자 없는 `migrations/` 추론·`DATABASE_URL` panic·`fixtures` 경로·`required-features` 로 db target 제외 로컬 실측, `.up.sql`/`.down.sql`·파일 전체 실행은 sqlx-core 소스 확인)
- [testcontainers-modules Postgres](https://docs.rs/testcontainers-modules/0.15.0/testcontainers_modules/postgres/struct.Postgres.html) (기본 tag `11-alpine` 은 0.15.0 소스) · [의존성](https://crates.io/api/v1/crates/testcontainers-modules/0.15.0/dependencies) · [postgres 18-alpine](https://hub.docker.com/v2/repositories/library/postgres/tags/18-alpine) — ✅ verified (컴파일·의존성 해석만, Docker 가 없어 실행 안 함); [mockall](https://docs.rs/mockall/0.15.0/mockall/) · [tokio::test start_paused](https://docs.rs/tokio/1.54.1/tokio/attr.test.html) · [tokio::time::pause](https://docs.rs/tokio/1.54.1/tokio/time/fn.pause.html) · [axum testing example](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/examples/testing/src/main.rs) — ✅ verified (+ `pub trait` 의 `async_fn_in_trait` 경고·paused time 에서 IO 대기 중 timeout 만료 로컬 실측) / ⚠️ mockall_double 은 실측 안 함; [criterion CHANGELOG](https://raw.githubusercontent.com/criterion-rs/criterion.rs/master/CHANGELOG.md) · [criterion FAQ](https://raw.githubusercontent.com/criterion-rs/criterion.rs/master/book/src/faq.md) · [divan](https://crates.io/api/v1/crates/divan) · [nextest — test coverage](https://nexte.st/docs/integrations/test-coverage/) · [process-per-test](https://nexte.st/docs/design/why-process-per-test/) · [cargo-llvm-cov README](https://raw.githubusercontent.com/taiki-e/cargo-llvm-cov/main/README.md) — ✅ verified (+ `Unrecognized option` 의 core 단독·workspace 전체 실행 로컬 실측) / ⚠️ llvm-cov 는 로컬 미설치로 실행 안 함; crates.io 최신 버전 (검증일 2026-11-15): proptest 1.12.0 (2026-10-10), insta 1.49.0 (2026-10-03), mockall 0.15.0 (2026-06-28), criterion 0.8.2 (2026-02-04), divan 0.1.21 (2025-04-10), sqlx 0.9.0 (2026-05-21), testcontainers 0.28.0 (2026-08-06), testcontainers-modules 0.15.0 (2026-02-21), tokio 1.54.1 (2026-10-21), cargo-nextest 0.9.152 (2026-11-13), cargo-llvm-cov 0.9.1 (2026-09-06) — ✅ verified · subagent
