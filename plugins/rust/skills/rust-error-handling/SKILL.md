---
name: rust-error-handling
description: "Rust 에러 설계 — thiserror·anyhow 선택, From 과 ? 로 변환 모으기, 판정 결과(Ok)와 Err 구분, HTTP·큐 워커·WebSocket 경계마다 분류 지점 하나, 500 정보 노출 방지, panic·unwrap 정책. Use when Rust 서비스·엔진의 에러 타입을 설계하거나 @ControllerAdvice 같은 중앙 에러 처리를 만들 때."
---

# Rust Error Handling — 경계마다 분류 지점 하나

Spring 은 던져진 예외를 DispatcherServlet 의 `HandlerExceptionResolver` 체인(`ExceptionHandlerExceptionResolver`)이 받아 `@ControllerAdvice` 의 `@ExceptionHandler` 를 부르지만, Rust 는 **타입 변환**으로 에러를 모은다. 하위 에러는 `From` 으로 한 번만 정의해 `?` 로 올리고, 경계(HTTP·큐 워커·WebSocket)마다 함수 하나에서만 분류한다. 업무상 정상 결과(구간 미통과, 부정 의심, 엔진 입력 거부)는 `Err` 가 아니라 `Ok` 값이다.

## Quick Reference (결정 트리)

```
이 실패는 무엇인가?
├── 일어날 수 없어야 함 (불변식 위반·버그) ───────────> panic: expect("왜 불가능한지")
├── 업무상 정상 결과 — 저장할 판정
│   (미통과·부정·엔진 입력 거부) ──────────────────────> Ok(Verdict) — Err 아님
├── 호출자가 분기해야 함 (HTTP 요청 형식·닉네임 중복) ─> 기능별 thiserror enum 의 variant
└── 호출자가 분기 안 함 (예상 밖 IO·설정) ────────────> 원인 보존해 위로 (#[from], anyhow)

어떤 crate?
├── 다른 crate 가 match 하는 에러 ───────────────────> thiserror enum
│   (workspace core 포함 — house rule, MS 는 struct 권고. 아래 app vs library)
├── 바이너리 조립부 (main·설정 로딩) — 원인 체인만 필요 ─> anyhow + .context()
└── 앱 경계 (handler 가 돌려주는 에러) ───────────────> thiserror AppError 하나

경계에 도착 → 경계마다 분류 지점 하나
├── HTTP (axum) ──> impl IntoResponse for AppError (wildcard 없는 match, 500 body 고정)
├── 큐 워커 ──────> classify_sqlx·classify_compute(→ classify_join)
│                   (+ fencing 0 rows = LeaseLost) → JobFailure → next_step → apply_outcome
└── WebSocket ────> SyncError::close_frame() (read-only 쓰기는 끊지 않고 버림)
```

## 실패 세 갈래 — 결과 값, Err, panic

Wlaschin 의 Domain / Infrastructure / Panic 분류를 빌려, 판정 엔진에서는 업무 결과 → `Ok(값)`, 처리 실패 → `Err(E)`, 버그 → `panic` 으로 나눈다. 이 대응은 이 skill 의 해석이다. Wlaschin 은 domain 오류를 `Result` 의 오류 쪽에 두고, infra 오류는 도메인으로 모델링하거나 panic 처럼 다루라고 한다. 판정 엔진의 미통과·부정 의심은 저장할 결과라 `Ok` 이고, Rust 에는 예외가 없으므로 infra 오류는 `Err` 로 둔다. 구간 미통과를 `Err` 로 표현하면 `?` 로 전파되어 재시도 대상이 되고, attempts 상한에 걸려 정상 판정이 dead-letter 에 쌓인다.

```rust
#[derive(Debug, Clone, PartialEq)]
pub enum Verdict {
    Passed { efforts: Vec<SegmentEffort> },
    NotPassed { reason: MissReason },
    Flagged { flags: Vec<FraudFlag> },
    Rejected { reason: InputRejection }, // 포인트 부족·좌표 범위 밖 → 결과 저장 후 done (dead 아님)
}
#[derive(Debug, Clone, PartialEq)]
#[must_use = "판정을 저장하지 않으면 job 이 끝나지 않는다"]
pub struct Judgement {
    pub engine_version: u32,
    pub verdict: Verdict,
}
pub fn judge(raw: &RawActivity, course: &Course) -> Judgement { /* … */ }
```

- `#[must_use]` 는 **버려지는 식의 타입**에 붙어 있어야 경고가 난다. `Verdict` 에만 붙이면 `judge(..);` 로 결과를 버려도 조용하다(로컬 rustc 1.96 확인). `Judgement` 나 `fn judge` 에 붙인다. 판정 core 의 `judge` 는 `Err` 를 돌려주지 않는다(시그니처가 `-> Judgement`). 엔진이 받을 수 없는 입력은 `Rejected` 로 저장하고, 불변식 위반은 `expect` 로 panic 한다. worker 가 그 panic 을 `JoinError::is_panic()` 으로 받아 `Permanent(Bug)` 로 분류한다. rayon 경로는 `panic_handler` 를 설정했을 때만 `ComputeError::Panicked` 로 받고, 설정하지 않으면 프로세스가 abort 된다([rust-async-tokio](../rust-async-tokio/SKILL.md)). `Err` 는 shell 에서 처리를 끝내지 못한 경우(잘못된 요청·인프라 장애)에만 쓴다. `Verdict` 의 정본 정의와 core/shell 구조는 [rust-engine-architecture](../rust-engine-architecture/SKILL.md).

## thiserror 2 — 경계마다 enum 하나, 변환은 From 한 번

```rust
#[derive(Debug, thiserror::Error)]
pub enum SignupError {
    #[error("nickname already taken")]
    DuplicateNickname,
    #[error("invalid email")]
    InvalidEmail(#[from] EmailError),
    #[error("database error")] // ✅ 원인은 source() 로만 잇는다
    Db(#[from] sqlx::Error),
}
pub async fn create_user(pool: &PgPool, req: CreateUserRequest) -> Result<i64, SignupError> {
    let email = Email::parse(&req.email)?; // EmailError → SignupError::InvalidEmail (From)
    insert_user(pool, &email, &req.nickname).await
}
```

| 규칙 | 근거 |
|---|---|
| `#[from]` 은 `#[source]` 를 겸하고, 같은 variant 에 다른 필드를 둘 수 없다(backtrace 제외) | thiserror README |
| 원인은 `source()` 와 Display **중 하나로만** 노출: `#[error("database error")]` ✅ / `#[error("database error: {0}")]` + `#[from]` ❌ | std `Error` 문서·AWS smithy-rs. 체인을 출력하면 같은 문장이 두 번 나온다. MS 는 Display 에 cause 를 넣으라고 해 충돌하며, 이 레포는 std 쪽을 따른다 |
| Display 는 소문자로 시작, 끝에 마침표 없음 | API Guidelines C-GOOD-ERR |
| `Result<T, String>`·`()` 에러 금지 | `String` 은 `Error` 미구현, 호출자가 분기할 수 없다 |
| 호출부마다 `map_err` 반복 금지 — `map_err` 는 외부 에러 일부를 도메인 에러로 바꾸거나 문맥을 더할 때만 | MS M-FROM-ERROR: 반복 `map_err` 는 happy path 를 가린다 |
| 모든 에러를 `#[from]` 으로 받는 전역 enum 하나 금지 | sled "Do not implement conversions from local concerns into global enums", Palmieri 'Ball Of Mud' |
| thiserror 1.x 블로그 예제를 그대로 옮기지 않는다 | 2.0 breaking: `{r#type}`→`{type}`, `{0}` 과 추가 positional 인자 혼용 금지 등 |

`map_err` 가 맞는 자리 — 외부 에러 중 일부만 도메인 에러로 바꿀 때. `insert_user` 는 `sqlx::query_scalar(..).fetch_one(pool).await.map_err(nickname_conflict)` 로 끝난다:

```rust
fn nickname_conflict(e: sqlx::Error) -> SignupError {
    match e {
        sqlx::Error::Database(ref db) if db.constraint() == Some("users_nickname_key") => {
            SignupError::DuplicateNickname
        }
        other => SignupError::Db(other),
    }
}
```

`constraint()` 는 현재 Postgres 드라이버에서만 채워진다. 서비스의 사전 중복 검사는 빠른 응답용이고 이 변환이 최종 방어선이다.

**app vs library.** Microsoft M-APP-ERROR 는 앱과 앱 전용 내부 crate 에 anyhow 를 허용하되 "앱 수준 에러 타입을 여러 개 섞지 말라" 고 한다. 둘 이상의 crate 가 쓰는 crate 는 library 로 보고 상황별 struct(M-ERRORS-CANONICAL-STRUCTS)를 권한다. 엄밀히는 `<name>-core` 를 shell 외의 crate(ingest·bench bin 등)도 쓰면 여기에 해당하지만, **house rule** 로 workspace 내부 crate 는 thiserror enum 으로 시작하고 외부에 공개할 때 다시 판단한다(출처끼리 갈리는 지점). "그 외" 를 담는 variant 는 `#[error(transparent)] Unexpected(#[from] anyhow::Error)` 로 둔다(Palmieri). variant 가 커지면 clippy `result_large_err`(기본 128 bytes)가 경고하므로 `Box` 로 감싼다.

## HTTP 경계 — `@ControllerAdvice` 대응 (axum 0.8)

axum 은 handler 가 돌려준 `Err` 도 `IntoResponse` 로 응답을 만든다(`Result<T, E>` 는 T·E 가 모두 `IntoResponse` 이면 응답). 그래서 앱 경계에 `AppError` 하나를 두고 `impl IntoResponse` 한 곳에서 status·body·로그를 정한다.

```rust
// src/error.rs — 앱에 하나
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error(transparent)]
    Signup(#[from] SignupError),
    #[error(transparent)]
    BadJson(#[from] JsonRejection),
    #[error("server busy, retry later")]
    Busy,
}
#[derive(Serialize)]
struct ErrorBody {
    code: &'static str,
    message: String,
}
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code) = self.status_and_code();
        let message = if status == StatusCode::INTERNAL_SERVER_ERROR {
            tracing::error!(error = %error_chain(&self), "request failed"); // 원인은 서버 로그로만
            "internal server error".to_owned()                              // body 는 고정 문구
        } else {
            tracing::debug!(error = %self, %status, "request rejected");
            self.to_string()
        };
        (status, Json(ErrorBody { code, message })).into_response()
    }
}
impl AppError {
    fn status_and_code(&self) -> (StatusCode, &'static str) {
        match self {
            Self::Signup(SignupError::DuplicateNickname) => (StatusCode::CONFLICT, "duplicate_nickname"),
            Self::Signup(SignupError::InvalidEmail(_)) => (StatusCode::UNPROCESSABLE_ENTITY, "invalid_email"),
            Self::Signup(SignupError::Db(_)) => (StatusCode::INTERNAL_SERVER_ERROR, "internal"),
            Self::BadJson(rejection) => (rejection.status(), "invalid_body"),
            Self::Busy => (StatusCode::SERVICE_UNAVAILABLE, "busy"),
        }
    }
}
pub async fn create_user(
    State(app): State<AppState>,
    AppJson(req): AppJson<CreateUserRequest>,
) -> Result<(StatusCode, Json<UserCreated>), AppError> {
    let id = signup::create_user(&app.pool, req).await?; // SignupError → AppError (From)
    Ok((StatusCode::CREATED, Json(UserCreated { id })))
}
```

- **exhaustive match**: 같은 crate 안에서는 `#[non_exhaustive]` 가 match 에 영향을 주지 않는다. wildcard 없는 match 를 두면 variant 추가가 E0004 로 드러난다. 중첩 패턴도 검사되어 `SignupError` 에 variant 를 더하면 `status_and_code` 에서 E0004 가 난다(로컬 확인). 다른 crate 가 match 하는 workspace 내부 enum 에 `#[non_exhaustive]` 를 붙이면 그 crate 는 wildcard 를 강요받아 이 검사를 잃으므로 붙이지 않는다.
- **500 은 고정 문구**: axum `error-handling` 예제의 내부 분기처럼 상세를 숨긴다. `anyhow-error-response` 예제는 body 에 내부 에러 메시지를 넣으므로 따라 하지 않는다. **4xx·로그 레벨**: 입력 오류(`JsonRejection`)는 status 와 문구를 그대로 돌려줘도 된다. 도메인 에러 Display 에는 사용자 데이터·SQL 을 넣지 않는다. 500 은 `error`, 예상된 거절(400·409·503 load shedding)은 `debug` 로 남긴다(이 레포 제안 — 외부 권고 아님). og-render 의 `OgError`(400/503/500)도 같은 구조다. **응답 형식**: RFC 9457 crate(`problem_details`, `http-api-problem`)는 다운로드 수로 볼 때 아직 정착 전이라 serde struct 로 직접 정한다. 형식 결정은 `/architecture:api-design`.

### extractor rejection — `@ExceptionHandler(HttpMessageNotReadableException)` 자리

JSON 파싱 실패는 handler 에 들어오기 전에 axum 기본 rejection 응답으로 나가 형식이 달라진다. 커스텀 extractor 로 `AppError` 에 모은다(axum `macros` feature 필요). 아래 415 는 Spring 의 `HttpMediaTypeNotSupportedException` 에 해당한다. `@Valid` 실패(`MethodArgumentNotValidException`)는 newtype 검증(`Email::parse` → `InvalidEmail` → 422)이 맡는다 → [rust-idioms](../rust-idioms/SKILL.md).

```rust
#[derive(FromRequest)]
#[from_request(via(axum::Json), rejection(AppError))]
pub struct AppJson<T>(pub T);
```

- 깨진 JSON 은 400, `content-type` 누락은 415 가 `AppError` body 로 나간다(로컬 테스트). `WithRejection`·수동 `FromRequest` 방식 비교는 axum `customize-extractor-error` 예제에 있다.
- 실패하는 tower middleware 는 `HandleErrorLayer` 로 응답으로 바꾼다. `tower::timeout::TimeoutLayer` 는 `Elapsed` 에러를 돌려주므로 필요하다. 이름이 같은 `tower_http::timeout::TimeoutLayer::with_status_code(..)` 는 에러 대신 응답을 돌려주므로 필요 없다(tower-http 의 `TimeoutLayer::new` 는 deprecated). 경계 enum 이 필요 없는 작은 handler 는 axum 내장 `axum::response::Result`·`ErrorResponse` 로 충분하다. 로그를 `into_response` 밖으로 빼려면 axum main 브랜치 예제처럼 `Arc<AppError>` 를 response extension 에 넣고 `middleware::from_fn` 이 읽는다(axum 0.8 에서 컴파일 확인).

## 큐 워커 경계 — 분류 한 곳 (track-engine)

worker 의 결과는 HTTP status 가 아니라 **큐 상태 전이**다. 재시도할 오류와 하면 안 되는 오류를 한 enum 에 `#[from]` 으로 모으면 구분할 수 없으므로 분류를 명시한다. `classify_*` 가 에러를 `JobFailure` 로 바꾸고, `next_step` 이 전이를 정하고, `apply_outcome` 하나가 그 전이를 SQL 로 실행한다.

| 상황 | 표현 | 전이 |
|---|---|---|
| 판정 완료 (미통과·부정 의심·입력 거부 포함) | `Ok(Judgement)` | 결과 upsert → done |
| 스키마 drift (컬럼 decode 실패) | `Permanent(Schema)` | dead + 알람. **입력 거부로 위장 금지** |
| 다시 해도 같은 결과 (제약 위반, core panic = `JoinError::is_panic()`, rayon 경로는 `ComputeError::Panicked` — `panic_handler` 필수, 없으면 abort. rayon 쪽 설정은 [rust-async-tokio](../rust-async-tokio/SKILL.md)) | `Permanent(Bug)` | dead + 알람 |
| 경합·timeout·연결 끊김 | `Transient` | pending, backoff 후 재시도 |
| 처음 보는 오류 | `Transient` (기본값을 명시) | attempts 상한이 무한 재시도를 막는다 |
| lease 상실 (fencing UPDATE 0 rows) | `LeaseLost` | 아무것도 쓰지 않는다 |

어떤 sqlx 에러·SQLSTATE 가 어느 행인지(`classify_sqlx` 와 코드 목록), `ComputeError` 정의와 그것을 나누는 `classify_compute` 는 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) §4 한 곳에만 둔다. 이 skill 은 그 함수가 쓰는 타입과 DB 와 무관한 분류만 정의한다.

```rust
pub type BoxError = Box<dyn std::error::Error + Send + Sync>;
#[derive(Debug)]
pub enum JobFailure {
    Transient(BoxError),
    Permanent { kind: PermanentKind, source: BoxError },
    LeaseLost, // classify 가 아니라 finish 의 fencing UPDATE 가 0 rows 일 때 만든다
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PermanentKind { Schema, Bug }
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Next { Retry, Dead, Skip }

pub fn classify_join(e: tokio::task::JoinError) -> JobFailure {
    if e.is_panic() {
        JobFailure::Permanent { kind: PermanentKind::Bug, source: e.into() }
    } else {
        JobFailure::Transient(e.into()) // abort·runtime 종료로 취소된 것(작업 자체의 실패 아님)이라 다시 시도해도 된다
    }
}
pub fn next_step(failure: &JobFailure, attempts: i32, max_attempts: i32) -> Next {
    match failure {
        JobFailure::LeaseLost => Next::Skip,
        JobFailure::Permanent { .. } => Next::Dead,
        JobFailure::Transient(_) if attempts >= max_attempts => Next::Dead,
        JobFailure::Transient(_) => Next::Retry,
    }
}
```

- `next_step` 은 IO 가 없어서 표의 행마다 단위 테스트로 고정할 수 있다. 이를 SQL 로 실행하는 `apply_outcome`, backoff, dead, lease fencing 은 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md).

## WebSocket 경계 — close_frame 한 곳 (sync engine)

```rust
#[derive(Debug, thiserror::Error)]
pub enum SyncError {
    #[error(transparent)]
    Room(#[from] RoomError), // core 는 close code 를 모른다. 고르는 곳은 여기 하나
    #[error("peer too slow")]
    SlowConsumer,
}
impl SyncError {
    /// axum `Message::Close(Option<CloseFrame>)` 에 그대로 넣는다.
    pub fn close_frame(&self) -> Option<CloseFrame> {
        let (code, reason) = match self {
            Self::Room(RoomError::Client(_)) => (close_code::POLICY, "invalid message"),
            Self::Room(RoomError::Internal(_)) => (close_code::ERROR, "internal error"),
            Self::SlowConsumer => (close_code::AGAIN, "too slow, reconnect"),
        };
        Some(CloseFrame { code, reason: reason.into() })
    }
}
```

- read-only peer 의 쓰기는 에러가 아니라서 variant 가 없다. core 의 `authorize` 가 끊지 않고 버리고 센다(viewer 도 SyncStep1 에 SyncStep2 로 답하므로, 끊으면 접속마다 끊긴다) → [rust-crdt-sync](../rust-crdt-sync/SKILL.md) §2·§4. yrs `sync::Error` 는 이 enum 이 직접 받지 않는다. core 의 `RoomError` 가 수동 `From` 으로 wildcard 없이 `Client`(깨진 bytes·구조가 틀린 update·모르는 태그·거부된 Auth)와 `Internal` 로 먼저 나누고, 이 enum 은 `#[from]` 으로 감싸 close code 만 고른다. `RoomError` 정의와 `From` 구현은 [rust-crdt-sync](../rust-crdt-sync/SKILL.md). close reason 도 500 body 처럼 다룬다. RFC 6455 는 reason 이 사람이 읽을 문장이라고 보장하지 않으며, 클라이언트가 이를 사용자에게 보여주면 안 된다(MUST NOT)고 규정한다. 원인은 서버 로그로만 남긴다. Close 는 control frame 이라 payload 가 125 bytes 이하이므로, 2 bytes 코드를 빼면 reason 은 123 bytes 까지다. 1008(`POLICY`)은 더 맞는 코드가 없거나 정책 세부를 숨길 때 쓰는 범용 코드, 1011(`ERROR`)은 서버 내부 오류, 1013(`AGAIN`, Try Again Later)은 IANA 레지스트리 코드다. 클라이언트의 재연결 정책과 맞춰 고른다. 문서 actor 를 내릴지 판단하는 메서드(예: `fn is_fatal_for_doc(&self) -> bool`, 이 skill 의 제안이며 라이브러리 API 아님)도 같은 `impl` 에 둔다. 메시지마다 권한을 검사하는 이유와 actor 구조는 [rust-crdt-sync](../rust-crdt-sync/SKILL.md).

## panic·unwrap 정책

panic 은 예외가 아니다(MS M-PANIC-IS-STOP). 사용자 입력·외부 상태의 실패는 `Result` 로, panic 은 버그 신호로만 쓴다. Cloudflare 2025-11-18 장애에서는 내부에서 만든 feature 파일이 한도(200개)를 넘자 Rust 프록시의 `unwrap()` 이 panic 했고 그 결과 5xx 가 났다. 내부 설정도 외부 입력처럼 검증한다.

```rust
// ❌ BAD: 외부 입력에 unwrap — 설정 값 하나로 프로세스가 죽는다
let port: u16 = raw.parse().unwrap();
// ✅ GOOD: 외부 입력은 Result + 문맥 (anyhow::Context)
let port: u16 = raw.parse().context("APP_PORT must be a u16")?;
// ✅ GOOD: 불변식은 expect 에 "왜 불가능한지"
let started_at = self.points.first().expect("ValidatedTrack holds at least two points").timestamp;
```

**House rule** (공식 수치·권고가 아니라 이 레포의 기본값):

```toml
# Cargo.toml (workspace 면 [workspace.lints.clippy])
[lints.clippy]
unwrap_used = "warn" # restriction 그룹 — 그룹째 켜지 않고 이 lint 만
[profile.release]
panic = "unwind"     # Cargo 기본값이지만 명시해 abort 로 바뀌는 것을 막는다
```

```toml
# clippy.toml — threshold·설정 값은 여기만
# (Cargo.toml [lints.clippy] 에 쓰면 파싱 에러, [package] 에 쓰면 unused manifest key 경고만 나고 적용되지 않는다)
allow-unwrap-in-tests = true
```

- `expect_used` 는 켜지 않는다. `expect("이유")` 는 불변식을 표기하는 용도로 허용한다(Firecracker, 적용 예정 단계인 Google 가이드의 "Prefer expect over unwrap"). Microsoft 의 lint 템플릿에는 `unwrap_used` 가 없다는 점도 알고 쓴다. 테스트 helper(`tests/common` 등)는 `unwrap` 대신 `expect("왜 실패할 수 없는지")` 를 쓴다. `allow-unwrap-in-tests` 의 적용 범위(clippy 버전·workspace 배치)는 [rust-idioms](../rust-idioms/SKILL.md) §Lint 로 강제.
- `panic = "abort"` 의 함정: 테스트는 이 설정과 무관하게 unwind 로 돌기 때문에 CI 에서 드러나지 않는다. unwind 일 때만 tokio 가 task panic 을 `JoinError` 로 돌려주고, worker 가 `is_panic()` 을 `Permanent(Bug)` 로 분류할 수 있다(위 표). abort 면 그 전에 프로세스가 끝난다. rayon 전역 풀에 `panic_handler` 가 없을 때도 같다. 반면 `TaskTracker` 는 task 결과(에러·panic)를 버린다. 최상위 컴포넌트의 실패 전파는 [rust-async-tokio](../rust-async-tokio/SKILL.md). tower-http `CatchPanicLayer` 는 최후 수단이다. 문서 스스로 panic 을 에러 처리에 쓰지 말라고 하고, `panic = "abort"` 면 잡지 못한다. `custom` 핸들러로 panic 메시지를 body 에 넣지 않는다. `catch_unwind` 로 예외를 흉내 내지도 않는다. Google 가이드(적용 예정 단계)는 first-party `catch_unwind` 를 금지하고(panic=unwind 진입점의 방어만 예외), MS M-PANIC-CONTINUATION 은 요청 단위로 잡더라도 재시작을 유도하라고 해 갈린다. 어느 쪽이든 panic 을 잡고 계속 서비스하라는 뜻은 아니다.

## 로그 — 처리하는 곳에서 한 번

- 에러는 **처리하는 곳**에서만 로그한다. `?` 로 넘기기만 하는 함수는 로그하지 않는다(Palmieri). 처리 지점은 HTTP 는 `into_response`, worker 는 `apply_outcome` 을 부르는 job 처리 함수([rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) 의 `process`), WS 는 close frame 을 보내는 곳이다. Display 에 원인을 넣지 않았으므로 로그에는 체인을 이어서 찍는다. anyhow 는 `{:#}` 가 `: ` 로 체인을 잇는다. thiserror 타입은 `source()` 를 따라간다:

```rust
pub fn error_chain(e: &dyn std::error::Error) -> String {
    let mut out = e.to_string();
    let mut cause = e.source();
    while let Some(c) = cause {
        out.push_str(": ");
        out.push_str(&c.to_string());
        cause = c.source();
    }
    out
}
```

- `sqlx::Error::Database` 는 Display 에 `{0}` 을 넣으면서 `#[source]` 로도 원인을 내보내므로, 이 체인에서 DB 메시지가 두 번 찍힌다(sqlx 0.9 소스·로컬 테스트 확인). 외부 crate 까지 원칙을 강제할 수는 없으니 이 동작을 알고 쓴다. `#[tracing::instrument(err)]` 는 기본으로 모든 인자를 span 필드에 기록하므로 `skip_all` 을 붙인다. 또 처리 지점에만 단다. 중간 함수마다 달면 같은 에러가 여러 번 찍힌다. PII·토큰·SQL 바인딩 값은 로그에 넣지 않는다(레포 security rule, MS M-LOG-STRUCTURED 의 Redact Sensitive Data).

## Anti-Patterns

| 실수 | 문제 | 해결 |
|---|---|---|
| 구간 미통과·부정 의심을 `Err` 로 | `?` 로 전파 → 재시도 → 정상 판정이 dead 에 쌓임 | `Ok(Verdict)` |
| 워커 에러 전부를 `#[from]` 으로 enum 하나에 | classify 가 재시도할 것과 아닌 것을 구분 못함 | 경계마다 enum, 분류는 `classify` 에서 명시 |
| 500 body 에 `format!("{e}")` | 내부 정보 노출 | 고정 문구, 원인은 로그 |
| `into_response` match 에 `_ =>` | variant 를 추가해도 매핑 누락을 컴파일러가 못 잡음 | wildcard 없는 match |
| `map_err(\|_\| AppError::Internal)` | 원인 소실 | `From`/`#[from]`. lint 로 막으려면 restriction `map_err_ignore` 를 켠다(MS 템플릿도 켬) |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[기능 검증]** — 경계마다 분류 지점이 하나다. 예: `rg -n 'impl IntoResponse for' src/` 가 앱 에러 타입 하나만 가리키고, `rg -n 'INTERNAL_SERVER_ERROR' src/` 결과가 `error.rs` 안에만 있다. worker 상태 전이는 `next_step` 이 정하고 `apply_outcome` 한 곳에서만 실행한다
2. **[기능 검증]** — 매핑을 테스트로 고정하고 `cargo test` 가 통과한다. 예: variant 별 status(`should_return_409_when_nickname_duplicated`), 500 body 에 원인 문자열이 없음, `classify_join`·`next_step` 의 표 행마다 1개(SQLSTATE 행은 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) 의 `classify_sqlx` 테스트), `Rejected` 판정이 dead 가 아니라 done 으로 감
3. **[안전성]** — `unwrap_used = "warn"` + `allow-unwrap-in-tests = true` 에서 `cargo clippy --all-targets -- -D warnings` 가 통과하고, `rg -n 'panic\s*=\s*"abort"' --glob 'Cargo.toml'` 결과가 0건이다
4. **[안전성]** — 경계 match(`status_and_code`, `close_frame`)에 wildcard 가 없다. `#[non_exhaustive]` 외부 타입(`sqlx::Error`)에 쓴 wildcard 에는 기본값의 의도를 적은 주석이 있다
5. **[일관성]** — [Rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) §에러 처리와 맞고, 에러 경로 테스트를 `/dx:negative-path-coverage` 체크리스트로 점검했다

## 참조 스킬

- [rust-idioms](../rust-idioms/SKILL.md) — `fn -> Result` + `?` 로 쓰는 Composed Method, newtype 검증(`Email::parse`) · [rust-engine-architecture](../rust-engine-architecture/SKILL.md) — core/shell 분리, `Verdict` 가 core 에 있는 이유 · [rust-async-tokio](../rust-async-tokio/SKILL.md) — `JoinSet`·`TaskTracker` 실패 전파, graceful shutdown · [rust-testing](../rust-testing/SKILL.md) — 테스트 배치·이름·실제 DB 테스트
- [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) — `classify_sqlx`·SQLSTATE 표, `apply_outcome` SQL, backoff, dead, lease fencing · [rust-crdt-sync](../rust-crdt-sync/SKILL.md) — WebSocket 메시지별 권한, 문서 actor, `RoomError`(yrs 에러 분류) · [rust-og-image-render](../rust-og-image-render/SKILL.md) — `OgError` 400/503/500 적용 · [rust-from-spring](../rust-from-spring/SKILL.md) — `@ControllerAdvice` 밖의 Spring 대응표
- `/java:spring-patterns` — Spring `@RestControllerAdvice` 쪽 비교 · `/architecture:api-design` — 에러 응답 body 형식(RFC 9457) · `/dx:negative-path-coverage` — 에러 경로 테스트 목록

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. 기준은 Rust stable 1.100.0(2026-11-12)이고 로컬 실측은 rustc·clippy 1.96.0 이다. 다음 재검증은 2027-02.

- [thiserror README](https://raw.githubusercontent.com/dtolnay/thiserror/master/README.md) · [2.0.0 release](https://api.github.com/repos/dtolnay/thiserror/releases/tags/2.0.0) — 검증일 2026-11-15 · ✅ verified (2.0.21, 2026-09-23) · subagent
- [anyhow README](https://raw.githubusercontent.com/dtolnay/anyhow/master/README.md) · [lib.rs Display 형식](https://raw.githubusercontent.com/dtolnay/anyhow/master/src/lib.rs) — 검증일 2026-11-15 · ✅ verified (1.0.104, 2026-07-18. `{:#}` 는 로컬 테스트) · subagent
- [std Error trait](https://doc.rust-lang.org/std/error/trait.Error.html) · [smithy-rs RFC-0022](https://smithy-lang.github.io/smithy-rs/design/rfcs/rfc0022_error_context_and_compatibility.html) · [Rust Book 9.2](https://doc.rust-lang.org/book/ch09-02-recoverable-errors-with-result.html) · [9.3](https://doc.rust-lang.org/book/ch09-03-to-panic-or-not-to-panic.html) · [C-GOOD-ERR](https://rust-lang.github.io/api-guidelines/interoperability.html#c-good-err) · [sled — errors](https://sled.rs/errors.html) · [Wlaschin](https://fsharpforfunandprofit.com/posts/against-railway-oriented-programming/) · [Palmieri](https://www.lpalmieri.com/posts/error-handling-rust/) · [tracing instrument](https://docs.rs/tracing/latest/tracing/attr.instrument.html) · [Reference must_use](https://doc.rust-lang.org/reference/attributes/diagnostics.html) · [non_exhaustive](https://doc.rust-lang.org/reference/attributes/type_system.html) — 검증일 2026-11-15 · ✅ verified (Palmieri 글은 2021 actix-web 4 beta 기준. must_use 위치·E0004 는 로컬 rustc 1.96 실측) · subagent
- [MS M-FROM-ERROR·M-ERRORS-CANONICAL-STRUCTS](https://microsoft.github.io/rust-guidelines/guidelines/libs/ux/index.html) · [M-APP-ERROR](https://microsoft.github.io/rust-guidelines/guidelines/apps/index.html#M-APP-ERROR) · [M-PANIC-IS-STOP·M-PANIC-CONTINUATION](https://microsoft.github.io/rust-guidelines/guidelines/correctness/index.html) · [M-LOG-STRUCTURED·lint 템플릿](https://microsoft.github.io/rust-guidelines/guidelines/universal/index.html) — 검증일 2026-11-15 · ✅ verified (Version 2026.6) · subagent
- [axum error_handling](https://docs.rs/axum/0.8.9/axum/error_handling/index.html) · [IntoResponse for Result](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/axum-core/src/response/into_response.rs) · [error-handling 예제 (0.8.9 태그)](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/examples/error-handling/src/main.rs) · [커밋 이력](https://api.github.com/repos/tokio-rs/axum/commits?path=examples/error-handling/src/main.rs) · [anyhow-error-response 예제 (0.8.9 태그)](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/examples/anyhow-error-response/src/main.rs) · [customize-extractor-error](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/examples/customize-extractor-error/README.md) · [HandleErrorLayer 문서](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/axum/src/docs/error_handling.md) · [response 모듈](https://docs.rs/axum/0.8.9/axum/response/index.html) · [tower-http TimeoutLayer](https://raw.githubusercontent.com/tower-rs/tower-http/tower-http-0.7.1/tower-http/src/timeout/service.rs) — 검증일 2026-11-15 · ✅ verified (axum 0.8.9, 2026-04-14. 미들웨어 로그 구조는 #3527, 0.8.9 로컬 컴파일. anyhow 예제는 body 에 내부 메시지를 넣는 반면교사. `AppJson` 400·415 는 로컬 테스트. tower `timeout` 의 `Elapsed` 에러 + `HandleErrorLayer` 는 0.8.9 HandleErrorLayer 문서 예시) · subagent
- [Spring @ControllerAdvice](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-advice.html) · [Spring Exceptions (HandlerExceptionResolver)](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-servlet/exceptionhandlers.html) · [HttpMessageNotReadableException](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/http/converter/HttpMessageNotReadableException.html) · [HttpMediaTypeNotSupportedException](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/HttpMediaTypeNotSupportedException.html) · [MethodArgumentNotValidException](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/bind/MethodArgumentNotValidException.html) — 검증일 2026-11-15 · ✅ verified (`ExceptionHandlerExceptionResolver` 가 advice bean 을 찾아 적용. 읽기 실패·미지원 content type·`@Valid` 실패는 각각 다른 예외) · subagent
- [problem_details (crates.io)](https://crates.io/api/v1/crates/problem_details) — 검증일 2026-11-15 · ✅ verified / ⚠️ "정착 전" 은 다운로드 수 기반 판단 · subagent
- [sqlx-core 0.9.0 error.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/error.rs) · [DatabaseError](https://docs.rs/sqlx-core/0.9.0/sqlx_core/error/trait.DatabaseError.html) · [tokio JoinHandle](https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html) · [JoinError](https://docs.rs/tokio/latest/tokio/task/struct.JoinError.html) · [task 모듈 Cancellation](https://docs.rs/tokio/latest/tokio/task/index.html) · [TaskTracker](https://docs.rs/tokio-util/latest/tokio_util/task/task_tracker/struct.TaskTracker.html) · [tokio oneshot](https://docs.rs/tokio/latest/tokio/sync/oneshot/index.html) · [rayon spawn](https://docs.rs/rayon/latest/rayon/fn.spawn.html) · [rayon ThreadPoolBuilder](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html) — 검증일 2026-11-15 · ✅ verified (sqlx 0.9.0, 2026-05-21. Database 의 Display+source 중복은 로컬 소스·테스트. tokio 1.54.1, rayon 1.12.0. 취소는 abort 와 runtime 종료, `spawn_blocking` 은 시작 전이 아니면 abort 되지 않음. `is_panic`·abort 분류는 로컬 테스트. rayon 클로저 panic 은 등록한 `panic_handler` 가 있으면 그쪽으로 가고 없으면 기본값은 process abort. oneshot sender 가 보내지 않고 drop 되면 receiver 는 `RecvError`) · subagent
- [RFC 6455 §5.5, §7.4.1](https://www.rfc-editor.org/rfc/rfc6455.txt) · [IANA close code registry](https://www.iana.org/assignments/websocket/websocket.xml) · [y-protocols PROTOCOL.md](https://raw.githubusercontent.com/yjs/y-protocols/master/PROTOCOL.md) · [axum ws close_code](https://docs.rs/axum/0.8.9/axum/extract/ws/close_code/index.html) · [yrs sync::Error](https://docs.rs/yrs/0.28.1/yrs/sync/protocol/enum.Error.html) — 검증일 2026-11-15 · ✅ verified (y-protocols 는 read-only 회신 처리. yrs 0.28.1 로컬 소스. `RoomError` 경유 close code 는 로컬 테스트) · subagent
- [clippy lints](https://rust-lang.github.io/rust-clippy/stable/index.html) · [configuration](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/book/src/configuration.md) · [Cargo profiles](https://doc.rust-lang.org/cargo/reference/profiles.html) · [std catch_unwind](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html) · [tower-http catch_panic (0.7.1 태그)](https://raw.githubusercontent.com/tower-rs/tower-http/tower-http-0.7.1/tower-http/src/catch_panic.rs) · [Google Rust Style Guide](https://google.github.io/styleguide/rustguide.html) · [Firecracker CONTRIBUTING](https://raw.githubusercontent.com/firecracker-microvm/firecracker/main/CONTRIBUTING.md) · [Cloudflare 2025-11-18](https://blog.cloudflare.com/18-november-2025-outage/) — 검증일 2026-11-15 · ✅ verified (`unwrap_used`·`map_err_ignore` 그룹, 설정 키를 Cargo.toml 에 쓸 때의 에러/경고는 로컬 clippy 1.96 실측. `allow-unwrap-in-tests` 적용 범위의 출처는 rust-idioms 에 있다. release 기본 `panic = 'unwind'` 는 Cargo 문서. abort 에서 CatchPanicLayer 무력은 문서에서 추론. Google 가이드는 "intend to start applying" 단계) · subagent
