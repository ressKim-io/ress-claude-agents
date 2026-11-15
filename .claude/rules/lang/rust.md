---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/clippy.toml"
  - "**/.clippy.toml"
---

# Rust 코드 패턴 규칙

Rust Book·API Guidelines·Clippy·Tokio 문서와 Microsoft·Google Rust 가이드 기준 핵심 규칙. Java/Spring 에서 왔다면 `rust-from-spring`(대응표) → `/rust:rust-idioms`(함수·모듈 나누기) → `/rust:rust-engine-architecture`(엔진 구조) 순으로 본다.
공식·대기업 가이드에는 함수·파일 길이 숫자가 없다 (함수 길이의 유일한 숫자는 clippy `too_many_lines` 기본 threshold 100). 나머지 숫자는 레포 **house rule** 이다.

## 에러 처리

- MUST 실패할 수 있는 함수는 `Result` 를 반환하고 `?` 로 전파 — 입력·외부 상태 실패에 `panic!`·`unwrap()` NEVER
- PREFER 같은 하위 에러 변환은 `From`(thiserror `#[from]`)으로 한 번 정의해 `?` 로 쓰고, 같은 `map_err` 를 호출부마다 반복하지 않는다 — `map_err` 는 외부 에러 일부만 도메인 에러로 바꾸거나 분류·문맥을 더할 때만. NEVER 모든 에러를 `#[from]` 으로 받는 전역 enum 하나, `map_err(|_| ..)` 로 원인 버리기
- PREFER 호출자가 분기할 에러는 경계마다 thiserror enum 하나, 분기하지 않는 앱 최상단(main·초기화)은 anyhow
- MUST 결과로 저장·반환할 도메인 판정(구간 미통과·부정 의심·판정할 수 없는 입력 → `Rejected`)은 `Err` 가 아니라 `Ok(Verdict)` 같은 값 — `Err` 로 올리면 worker 가 재시도하다 정상 판정을 dead 로 보낸다. `Err` 는 처리를 끝내지 못한 경우(인프라 오류)와 동기 API 가 요청을 거절해 4xx 로 끝나는 경우(형식 오류·닉네임 중복)에만
- MUST 에러 분류는 경계마다 한 곳 (`@ControllerAdvice` 대응) — HTTP 는 `impl IntoResponse for AppError` 의 wildcard 없는 `match`, worker 는 재시도·dead 를 정하는 함수 하나, WebSocket 은 close frame 변환 하나
- NEVER 500 응답 body 에 내부 에러 문자열 — 고정 메시지를 보내고 원인은 서버 로그로
- MUST 감싼 원인은 `source()` 와 Display 중 한쪽으로만 — `#[error("database error")] Db(#[from] sqlx::Error)` 처럼 Display 에 `{0}` 를 넣지 않는다
- MUST 로그는 에러를 처리하는 곳에서 한 번 — `?` 로 넘기기만 하는 함수는 로그하지 않는다
- NEVER `Result<_, String>`·`Result<_, ()>` — 호출자가 분기할 수 없고 `Error` trait 도 없다
- PREFER 깨지면 버그인 불변식은 `expect("왜 실패할 수 없는지")` — panic 은 버그 전용이다. 복구할 실패는 `Result` 로 돌려주고 `catch_unwind` 로 예외 흉내 NEVER
- MUST release profile 은 `panic = "unwind"` 유지 (house rule: `abort` 면 task 하나의 panic 이 프로세스 전체를 끝낸다)

## 메서드 구조 (Composed Method)

비즈니스 로직은 같은 추상화 수준의 함수 호출로 구성한다 (SLAP 원칙).

- 조건문/로직 블록이 3줄 이상이면 MUST 의도를 드러내는 함수로 추출 — 실패할 수 있으면 `fn check_x(..) -> Result<(), E>` 로 만들어 `?` 로 잇는다
- 1-2줄 로직은 함수 추출 대신 MUST 목적을 설명하는 WHY 주석 사용 (한 번만 쓰는 값 계산은 block expression `let x = { .. };`)
- 한 함수는 PREFER 20-50줄 이내로 유지 — 측정은 Cognitive Complexity 대신 clippy `too_many_lines`·`excessive_nesting` (clippy 의 `cognitive_complexity` 는 1.91 에 restriction 으로 옮겨졌고, 문서가 측정 도구로 쓰지 말라고 한다)

```rust
// ❌ BAD: 형식 검사·중복 조회·저장이 한 함수에 섞이고, 호출부마다 map_err 를 반복한다
pub async fn create_user(repo: &UserRepo, req: SignupRequest) -> Result<UserId, SignupError> {
    let email = req.email.trim().to_lowercase();
    if !email.contains('@') || email.len() > 254 {
        return Err(SignupError::InvalidEmail(EmailError));
    }
    let taken = repo.nickname_exists(&req.nickname).await.map_err(SignupError::Db)?;
    if taken {
        return Err(SignupError::DuplicateNickname);
    }
    repo.insert(&email, &req.nickname).await.map_err(SignupError::Db)
}

// ✅ GOOD: 단계마다 이름을 붙이고 `?` 로 잇는다. 형식 검증은 경계의 newtype 이 맡는다
pub async fn create_user(repo: &UserRepo, req: SignupRequest) -> Result<UserId, SignupError> {
    let email = Email::parse(&req.email)?;
    check_duplicate_nickname(repo, &req.nickname).await?;
    Ok(repo.insert(&email, &req.nickname).await?)
}

async fn check_duplicate_nickname(repo: &UserRepo, nickname: &str) -> Result<(), SignupError> {
    // 사전 검사는 친절한 에러용 — 동시 가입 경합은 DB unique 제약이 막고, 그 위반을 DuplicateNickname 으로 바꾸는 분류는 /rust:rust-error-handling
    if repo.nickname_exists(nickname).await? {
        return Err(SignupError::DuplicateNickname);
    }
    Ok(())
}
```

## 함수 분해와 중첩

- PREFER `self` 상태가 필요 없는 단계는 `impl` 밖 모듈 private free fn
- MUST 필드를 빌린 채 `&mut self` helper 를 불러 E0502 가 나면 필요한 필드만 인자로 받는 fn 으로 뽑는다
- NEVER borrow 에러를 `clone()` 으로 덮기 — `&T` 로 빌리기 → move → `Arc::clone` 순으로 검토
- MUST 중첩은 `?`·`let-else`·let chains(Rust 1.88+, edition 2024)·match guard 로 평탄화해 happy path 를 최외곽에 둔다
- PREFER 짧은 변환은 iterator combinator, 조건 분기·상태 변경이 섞이면 `for` 나 `match`

## 타입과 검증 (Parse, don't validate)

- MUST 불변식이 있는 값은 newtype + fallible 생성자(`Email::parse`, `TryFrom`, `FromStr`) — 불변식 newtype 에 infallible `From` NEVER
- MUST 검증은 경계(handler 또는 유스케이스 진입 함수)에서 요청 DTO(serde)를 도메인 타입으로 바꿀 때 한 번 — 그 안쪽 helper·core 는 검증된 타입만 받는다
- PREFER bool 인자 대신 2-variant enum 또는 이름이 다른 두 함수 (`create_user(req, true, false)` 금지)
- PREFER 단위가 섞일 수 있는 수(미터·초·도)는 맨 `f64` 대신 타입으로 구분 (newtype 또는 `uom`)

## 추상화와 의존성

- NEVER 구현이 하나뿐인 trait (`UserService` + `UserServiceImpl` 직역) — trait 는 바꿔 끼우거나 test double 이 필요한 경계(DB·외부 API·시계)에만, 좁게
- PREFER 의존성 타입은 concrete > generic > `dyn` 순 (house rule) — `async fn` 이 있는 trait 는 dyn compatible 이 아니므로 `dyn` 이 꼭 필요할 때만 async-trait
- MUST DI 컨테이너 대신 `main` 에서 직접 조립해 넘긴다 (axum 은 `State<T>`) — 공유 서비스는 `Clone`(안쪽에 `Arc`)
- NEVER `Deref` 로 상속 흉내, `Arc<Mutex<_>>` 를 공개 API 에 노출
- MUST 계산 엔진은 처음부터 workspace 로 IO 없는 `<name>-core` lib crate + 얇은 shell bin crate (house rule) — core 에 tokio·sqlx·reqwest 의존 NEVER, CI 에서 `cargo tree` 로 검사
- MUST core 는 시계와 `HashMap` 순회 순서에 기대지 않는다 — 시간은 인자로 받고 출력 경로는 `BTreeMap` 이나 정렬. clippy.toml `disallowed-methods`·`disallowed-types` 로 강제하고, crate 별 clippy.toml 을 두면 루트 threshold 를 그 파일에 복제한다 (Clippy 는 처음 찾은 clippy.toml 하나만 쓴다. 병합하지 않는다는 점은 문서에 없고 1.96 실측)

## 모듈과 파일

- MUST 하위 모듈은 `foo.rs` + `foo/bar.rs` — `foo/mod.rs` 는 옛 방식이라 섞지 않는다 (예외: `tests/common/mod.rs`)
- PREFER 최상위는 기능 단위 모듈(`user`, `course`), 기능 안에서 handler·service·repo 파일로 계층 분리 — `controllers/`·`services/`·`utils` 같은 기술 분류 지양
- PREFER 파일명은 그 파일의 주 타입 이름, 하위 모듈을 둔 상위 모듈은 선언·re-export 만
- MUST 가시성은 최소로 — 기본 private, crate 안 공유는 `pub(crate)`, 부모만 쓰면 `pub(super)` (impl 을 하위 파일로 나누면 부모가 부르는 method 는 `pub(super)` 필요)
- MUST `main.rs` 는 조립만, 로직은 `lib.rs` 쪽 — `main.rs` 만 있는 binary 는 `tests/` 통합 테스트에서 함수를 가져올 수 없다
- MUST `.rs` 파일이 테스트 모듈을 빼고 400줄을 넘으면 분할 검토 (house rule — 공식 기준도 clippy lint 도 없다)

## async 기본

- NEVER async 함수 안에서 blocking 호출(`std::fs`, `std::thread::sleep`, 동기 DB·HTTP client)이나 긴 CPU 계산
- MUST CPU 계산(판정·렌더)은 runtime 밖으로 — `spawn_blocking` + CPU 전용 Semaphore 로 시작하고 permit 을 클로저 안으로 옮긴다. 측정해서 CPU 가 처리량을 좌우하면 rayon (`rayon::spawn` 은 `panic_handler` 가 없으면 panic 이 프로세스를 abort). blocking IO 는 `spawn_blocking`
- MUST CPU Semaphore 는 job 동시성 Semaphore 와 분리 — 하나를 같이 쓰면 job 이 permit 을 쥔 채 서로 기다려 deadlock
- NEVER std `MutexGuard` 를 `.await` 너머로 들고 가기 — 일반 데이터는 std `Mutex` 로 짧게 잠그고, `.await` 를 넘겨 잡아야 하는 IO 자원만 `tokio::sync::Mutex`
- MUST `select!` branch 의 future 가 cancel safe 인지 확인 — 문서에 없으면 cancel safe 로 가정하지 않는다
- MUST spawn 한 task 의 실패(에러·panic)가 드러나게 한다 — `JoinHandle`·`JoinSet` 으로 결과를 확인한다. `TaskTracker` 는 결과를 보관하지 않으므로(`spawn` 이 준 `JoinHandle` 을 버리면 결과도 사라진다) task 안에서 `Err` 를 처리한다. 프로세스를 멈춰야 하는 실패만 루트 `CancellationToken` 의 `drop_guard` 로 전파하고 성공 경로에서는 `guard.disarm()` — disarm 하지 않으면 정상 종료에도 루트가 취소된다
- PREFER 채널은 bounded `mpsc` (backpressure), 종료는 `CancellationToken` + SIGTERM 처리

## 네이밍

- NEVER getter 에 `get_` 접두사 — `email()`, `email_mut()`, `set_email()` (예외는 API Guidelines C-GETTER 가 허용하는 `Cell::get` 처럼 얻을 대상이 하나뿐인 `get`, 검사 생략판 `get_unchecked`)
- PREFER 타입명에 `Service`·`Manager`·`Factory` 대신 역할이 드러나는 이름 (service 계층 자체는 괜찮다), Factory 는 Builder 또는 `impl Fn() -> T`
- MUST 에러 Display 메시지는 소문자로 시작하고 마침표 없이 (`"nickname already taken"`)

## Lint 설정

- MUST lint 레벨은 Cargo.toml `[lints]` (workspace 면 `[workspace.lints]` + 멤버 `[lints] workspace = true`), threshold 는 clippy.toml 에만 — Cargo.toml 에 넣으면 무시(`unused manifest key`)되거나 파싱 에러. 이름은 Cargo.toml 밑줄(`too_many_lines`), clippy.toml 하이픈(`too-many-lines-threshold`)
- MUST 그룹을 켤 때는 `{ level = "warn", priority = -1 }` — 같은 priority 로 레벨이 다른 개별 lint(예: `missing_errors_doc = "allow"`)와 함께 쓰면 `lint_groups_priority` 에러
- MUST `too_many_lines = "warn"` + `too-many-lines-threshold = 100` 명시 (house rule: 켜고 기본값 100 을 명시. pedantic 이라 기본 꺼져 있고, 빈 줄·주석 줄은 세지 않는다)
- MUST `excessive-nesting-threshold = 4` 로 시작해 실제 코드의 경고 수를 잰 뒤 조정 (house rule. 기본값 0 이면 동작 안 함. `impl`·함수 본문도 1단계로 세서 4 면 method 안 `if` 3단부터 경고)
- MUST `unwrap_used = "warn"` + `allow-unwrap-in-tests = true` (house rule) — 불변식은 `expect("…")` 로 허용. 1.96 은 이 설정을 `#[test]`·`#[cfg(test)]` 에만 적용해 `tests/common` helper 를 경고한다. 1.100 CHANGELOG 는 integration test 로 넓혔다고 적지만 workspace member(`crates/<x>/tests/`)에도 적용되는지는 ⚠️ 로컬이 1.96 이라 미측정 — helper 는 버전과 상관없이 `expect("…")` (세부 `/rust:rust-idioms`)
- MUST correctness 그룹은 기본값 deny 유지, restriction 그룹 통째로 켜기 NEVER — 필요한 lint 만 골라 켠다
- MUST 국소 예외는 `#[expect(clippy::lint_name, reason = "…")]` — 더 이상 lint 가 안 나면 경고가 떠서 `#[allow]` 처럼 남지 않는다
- NEVER 코드에 `#![deny(warnings)]` — CI 에서 `cargo clippy --all-targets -- -D warnings`
- MUST `rust-version` 명시 (clippy `msrv` 기본값이 이 값을 따른다)
- MUST `unsafe` 블록마다 바로 위에 SAFETY 주석 — `undocumented_unsafe_blocks = "warn"`

## 테스트 위치

- MUST 단위 테스트는 같은 파일 끝 `#[cfg(test)] mod tests`, 공개 API·HTTP 경계는 `tests/` 통합 테스트, 공용 helper 는 `tests/common/mod.rs`
- MUST 테스트 이름은 `should_x_when_y`, 본문은 Given / When / Then 주석으로 나눈다
- MUST DB 를 쓰는 통합 테스트는 실제 Postgres (`#[sqlx::test]` 또는 testcontainers) — mock 으로 대체 NEVER
- MUST nextest 를 쓰면 doctest 는 `cargo test --doc` 로 따로 돌린다 (nextest 는 doctest 를 돌리지 않는다)
- PREFER IO 없는 core 는 test double 없이 입력 → 출력으로 테스트

---

## 참조

- `rust-from-spring` — Spring 개념 → Rust 대응표 (Java/Spring 출신의 시작점)
- `/rust:rust-idioms` — Composed Method·중첩·모듈 분할·lint 템플릿
- `/rust:rust-error-handling` — thiserror·anyhow, 경계별 에러 분류, panic 정책
- `/rust:rust-engine-architecture` — core/shell workspace, 결정성, 의존성 주입
- `/rust:rust-async-tokio` — CPU 오프로드, 채널·actor, graceful shutdown, 관측
- `/rust:rust-testing` — 테스트 배치, proptest·insta, 실제 DB 테스트
- `/rust:rust-pg-queue-worker` — Postgres 테이블 큐 워커
- `rust-og-image-render` — OG 미리보기 이미지 렌더링
- `/rust:rust-crdt-sync` — CRDT 협업 편집 동기화
- `rust-geo-track` — GPS 트랙 구간 판정·부정 기록 필터
- 언어 공통 원칙: `/dx:clean-code`
