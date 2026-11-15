---
name: rust-from-spring
description: "Java·Spring 개념의 Rust 대응표 — Bean·@Autowired, @Transactional, @Valid, @ControllerAdvice, Optional, 상속·interface, getter·Builder 매핑과 버려야 할 Java 습관. Use when Java/Spring 경험으로 Rust 코드를 짜거나 익숙한 Spring 개념의 Rust 대응을 찾을 때."
---

# Rust from Spring — Java·Spring 개념 대응표

Spring 개념이 Rust 에서 무엇이 되는지 한 줄로 찾고, 자세한 설명은 링크된 skill 에서 본다.
원칙은 하나다. **도메인 흐름(무엇을 나누나)은 그대로 두고, 기술 구성(어떻게 나누나)은 Rust 식으로 다시 쓴다.** Microsoft M-RUST-SHAPED 의 "technical constructs must not be copied 1-on-1" 이 이 선을 긋는다.

## Quick Reference (결정 트리)

```
이 Java 습관을 Rust 로 가져가도 되나?
├─ 도메인 흐름·단계 이름 (createUser = checkEmail + checkDuplicateNickname + save)
│     └─ 그대로 ─────────────────> 단계 이름 유지, fn -> Result + ? 로 연결
├─ 기술 구성 (interface+Impl, DI 컨테이너, 예외, 상속, 어노테이션, Lombok)
│     └─ 다시 쓴다 ──────────────> 아래 대응표에서 Rust 형태를 찾는다
└─ 무엇을 만드나?
      ├─ 요청/응답 웹 API ────────> handler → service → repo, 기능별 모듈
      └─ 계산 엔진 (판정·렌더·동기화) ─> IO 없는 core crate + 얇은 shell crate

Spring 이 대신 해주던 일은 이제 누가 하나?
├─ Bean 생성·주입 ──────> main 에서 직접 조립 (컨테이너 없음)
├─ @Transactional ──────> 호출자가 pool.begin() … commit() 을 쓴다
├─ @Valid ──────────────> use case 입구에서 newtype 으로 한 번 파싱 (Email::parse 또는 NewUser::try_from)
├─ @ControllerAdvice ───> 경계마다 분류 지점 하나 (IntoResponse / apply_outcome / close_frame)
└─ 예외 전파 ───────────> Result + ?   (panic 은 버그 전용)
```

계산 엔진 가지의 구조는 [rust-engine-architecture](../rust-engine-architecture/SKILL.md), 엔진별로는 [rust-geo-track](../rust-geo-track/SKILL.md)(판정)·[rust-og-image-render](../rust-og-image-render/SKILL.md)(렌더)·[rust-crdt-sync](../rust-crdt-sync/SKILL.md)(동기화)·[rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md)(큐 처리)에서 본다.

## 네 가지 습관 판정

| Java 습관 | 판정 | Rust 에서의 모양 | 상세 |
|---|---|---|---|
| Controller-Service-Repository | 고쳐서 쓴다 | 웹: 얇은 handler → service → repo 를 기능별 모듈로 묶는다. 엔진: inbound adapter / IO 없는 core / outbound adapter | [rust-engine-architecture](../rust-engine-architecture/SKILL.md) |
| Composed Method | 그대로 쓴다 | 단계를 `fn check_x(..) -> Result<(), E>` 로 뽑아 `?` 로 잇는다. 형식 검사는 newtype 생성자로 옮겨 서비스가 짧아진다 | [rust-idioms](../rust-idioms/SKILL.md) |
| `@ControllerAdvice` 로 에러 모으기 | 고쳐서 쓴다 | 던져진 예외를 프레임워크가 찾아 처리하는 방식이 아니라 **타입 변환**이다. `impl IntoResponse for AppError` 한 곳(wildcard 없는 `match`) + `From` + `?` | [rust-error-handling](../rust-error-handling/SKILL.md) |
| 파일이 길어지면 쪼개기 | 그대로 쓴다 | `foo.rs` + `foo/bar.rs`. 공식 숫자 기준이 없어 줄 수는 house rule 로 정한다 | [rust-idioms](../rust-idioms/SKILL.md) |

## 대응표 — 구조·DI

| Spring / Java | Rust | 상세 |
|---|---|---|
| `@Component`·`@Service` Bean, 컴포넌트 스캔 | 컨테이너가 없다. `main` 에서 생성자 함수로 만들어 넘긴다 | [rust-engine-architecture](../rust-engine-architecture/SKILL.md) |
| `@Autowired` 생성자 주입 | 생성자 인자. axum 은 `#[derive(Clone)] AppState` + `State<T>` extractor (`Extension` 보다 타입 안전). 무거운 서비스는 내부 `Arc` 로 Clone 을 싸게 | [rust-engine-architecture](../rust-engine-architecture/SKILL.md) |
| `UserService` + `UserServiceImpl` | concrete 타입부터 쓴다. 구현을 바꿔 끼우거나 shell 흐름을 fake 로 테스트해야 하는 경계(DB·외부 API·시계)에만 좁은 trait 를 두고 generic 으로 받는다 (`-> impl Future + Send`). enum (`Native`/`Mocked`)은 trait 를 만들 이유가 없는 시스템 호출만. `dyn` 은 generic 이 중첩되거나 런타임에 고를 때. 순서는 concrete > generic > `dyn` | [rust-engine-architecture](../rust-engine-architecture/SKILL.md) |
| `@Qualifier` 로 구현 고르기 | 닫힌 집합이면 enum, 컴파일 타임에 정해지면 generic, 런타임 선택만 `dyn`. async fn in trait 는 `dyn` 으로 못 쓴다 | [rust-engine-architecture](../rust-engine-architecture/SKILL.md) |
| `@RestController` | 얇은 axum handler — 추출, use case fn 호출, 응답만. DTO→도메인 파싱은 use case fn 첫 줄에서 한 번. 경로는 `/{id}` (axum 0.8 에서 `/:id` 는 panic) | [rust-engine-architecture](../rust-engine-architecture/SKILL.md) |
| `@Service` 비즈니스 로직 | 웹: service 모듈의 fn. 엔진: IO 없는 core crate (시간도 인자로 받는다) | [rust-engine-architecture](../rust-engine-architecture/SKILL.md) |
| 도메인 계산 `@Service` (GPS 기록의 구간 통과 판정·부정 기록 거르기) | track 판정 core 의 순수 함수. 위경도 거리는 geo 의 metric space API, 교차·최근접은 미터 평면으로 투영해 계산. 판정 결과는 `Err` 가 아닌 `Judgement` 값 | [rust-geo-track](../rust-geo-track/SKILL.md) |
| 이미지 생성 서비스 (OG 미리보기 이미지) | SVG 문자열을 만들어 resvg 로 PNG 를 굽는다. 한글 폰트는 번들하고, 렌더 슬롯이 없으면 기다리지 않고 503 | [rust-og-image-render](../rust-og-image-render/SKILL.md) |
| `JpaRepository` | sqlx 로 SQL 을 직접 쓴다. `query!`·`query_file_as!` 는 빌드할 때 DB 또는 `.sqlx` 로 검증된다. 값은 `bind` 로 넘긴다 | [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) |
| JPA Criteria·`Specification` (동적 조건) | sqlx `QueryBuilder` + `push_bind` 로 값 바인딩을 유지한다. `format!` 으로 만든 SQL 문자열은 sqlx 0.9 의 `SqlSafeStr` 이 컴파일 에러로 거부한다 | [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) |
| layer 별 패키지 (`controller/`, `service/`) | 기능 모듈 (`user.rs` + `user/{handler,service,repo}.rs`) | [rust-idioms](../rust-idioms/SKILL.md) |
| package-private / `protected` | 같은 기능 모듈의 형제 파일까지는 `pub(super)`, crate 전체는 `pub(crate)` / 해당 없음 (상속이 없다) | [rust-idioms](../rust-idioms/SKILL.md) |

## 대응표 — 에러·검증

| Spring / Java | Rust | 상세 |
|---|---|---|
| `@ControllerAdvice` + `@ExceptionHandler` | HTTP 는 §네 가지 습관 판정. HTTP 밖도 경계마다 분류 지점이 하나다: worker `apply_outcome`, WebSocket `close_frame` | [rust-error-handling](../rust-error-handling/SKILL.md) |
| checked exception (`throws`) | `Result<T, E>`. 실패 가능성이 시그니처에 드러난다 | [rust-error-handling](../rust-error-handling/SKILL.md) |
| `RuntimeException`, `throw` | 호출자가 분기할 실패는 thiserror enum variant. 버그·불변식 위반만 `panic`/`expect` | [rust-error-handling](../rust-error-handling/SKILL.md) |
| "구간 미통과" 같은 판정을 예외로 | 저장할 결과는 `Ok(Verdict::…)` 도메인 값. `Err` 는 인프라 장애·불변식 위반에만 | [rust-error-handling](../rust-error-handling/SKILL.md) |
| `HttpMessageNotReadableException` 핸들러 (JSON 읽기 실패) | JSON 역직렬화 실패(`JsonRejection`)를 커스텀 extractor(`AppJson`)로 `AppError` 에 모아 같은 응답 형식으로 낸다 | [rust-error-handling](../rust-error-handling/SKILL.md) |
| `MethodArgumentNotValidException` 핸들러 (`@Valid` 실패) | 검증 실패는 newtype 생성자(`Email::parse`)의 `Err` 가 `From` 으로 `AppError` variant 가 되어 `IntoResponse` 한 곳에서 4xx 로 나간다 | [rust-error-handling](../rust-error-handling/SKILL.md) |
| `@Valid` + validator Bean | 진실의 원천은 newtype 의 fallible 생성자 (Parse, don't validate). 필드 하나는 `Email::parse(&str)`, DTO 전체를 도메인 값으로 바꿀 때만 `NewUser::try_from(req)`. DTO derive 검증(validator·garde)은 보조 | [rust-idioms](../rust-idioms/SKILL.md) |
| `Optional<T>`, `null` | `Option<T>`. null 이 없다 | §Optional → Option |

## 대응표 — 데이터·트랜잭션·작업

| Spring / Java | Rust | 상세 |
|---|---|---|
| `@Transactional` | `pool.begin()` → 하위 fn 에 `&mut PgConnection` 전달 → `commit()`. commit 없이 drop 되면 rollback | §@Transactional |
| outbox (`@TransactionalEventListener` 대체) | 업무 행과 job 행을 한 트랜잭션에 쓴다. 같은 job 이 다시 처리될 수 있어 결과는 멱등 upsert | [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) |
| `@KafkaListener` 같은 consumer | 브로커를 유지하면 그 브로커의 Rust client. 큐가 Postgres 테이블이면 `FOR UPDATE SKIP LOCKED` claim + LISTEN/NOTIFY 로 깨우기 + polling | [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) |
| Flyway / Liquibase | SQL 파일 + `sqlx::migrate!` (`macros`·`migrate` feature, 바이너리에 포함). 여러 서비스가 한 DB 를 쓰면 스키마를 소유하는 서비스를 하나로 정한다 (결정 사항) | [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) |
| `@Scheduled(fixedRate)` | `tokio::time::interval`. 놓친 tick 기본 동작은 `Burst` 라 필요하면 `Delay`/`Skip` | [rust-async-tokio](../rust-async-tokio/SKILL.md) |

## 대응표 — 객체·Lombok

| Spring / Java | Rust | 상세 |
|---|---|---|
| `extends`, `abstract BaseService` | 상속이 없다. composition, trait default method, enum. `Deref` 로 상속 흉내 금지 | §Anti-Patterns |
| Java enum + `switch`, `instanceof` 분기 | 데이터를 담는 `enum` + `match`. 모든 경우를 다루지 않으면 컴파일되지 않는다 | [rust-idioms](../rust-idioms/SKILL.md) |
| `getEmail()` / `setEmail()` | `email()` (`get_` 접두사 안 씀), 불변식이 있는 타입은 필드 private. setter 는 필요할 때만 `set_email()` | [rust-idioms](../rust-idioms/SKILL.md) |
| Lombok `@Data`·`@EqualsAndHashCode`·`@ToString` | `#[derive(Debug, Clone, PartialEq, Eq, Hash)]`. 사용자에게 보일 문자열은 `Display` 를 직접 구현 (derive 불가) | — |
| Lombok `@Builder` | `pub` 필드 값 묶음은 struct literal + `..Default::default()`, 필수 값은 `new(..)`. 필드를 숨긴 타입은 선택 값이 3개 이상이면 builder (Microsoft M-INIT-BUILDER, library 장 기준. 2개까지는 `with_a` 같은 inherent 메서드). bon 은 필수 필드 누락을 컴파일 에러로 | §Builder |

## 대응표 — 동시성·운영·테스트

| Spring / Java | Rust | 상세 |
|---|---|---|
| `@Async`, `CompletableFuture` | `tokio::spawn` (IO 대기). 여러 결과를 모을 때 `JoinSet` | [rust-async-tokio](../rust-async-tokio/SKILL.md) |
| `ExecutorService` 로 CPU 작업 | `spawn_blocking` + CPU 전용 Semaphore 로 시작하고 permit 을 클로저 안으로 옮긴다. 측정해서 CPU 가 처리량을 좌우하면 rayon (`panic_handler` 필수) | [rust-async-tokio](../rust-async-tokio/SKILL.md) |
| `synchronized`, `ConcurrentHashMap` | 짧은 구간은 std `Mutex`. `.await` 너머로 잡아야 하는 IO 자원만 tokio `Mutex`. 상태가 크면 actor (task + bounded mpsc) | [rust-async-tokio](../rust-async-tokio/SKILL.md) |
| `application.yml` + `@Value`, profile | config crate 레이어 (default → `RUN_MODE` → local → env). env 구분자 기본값이 없어 `APP_DATABASE_URL` 은 평평한 키 `database_url` 이 된다. 중첩 키 `database.url` 을 덮으려면 `.separator("__")` 를 명시한다 (prefix 구분자도 `__` 로 따라가므로 `APP_` 를 유지하려면 `.prefix_separator("_")` 도). 비밀값은 secrecy | [rust-async-tokio](../rust-async-tokio/SKILL.md) |
| SLF4J + MDC | `tracing` span 필드. `#[instrument]` 는 기본으로 모든 인자를 기록하므로 `skip_all` 부터 | [rust-async-tokio](../rust-async-tokio/SKILL.md) |
| Actuator health / prometheus | `/healthz` (liveness 와 readiness 의미를 나눈다), `/metrics` (exporter 는 Go 쪽 수집 방식에 맞춘다) | [rust-async-tokio](../rust-async-tokio/SKILL.md) |
| Spring WebSocket | axum WebSocket. 협업 문서처럼 상태를 가진 세션이면 문서마다 actor 하나 | [rust-crdt-sync](../rust-crdt-sync/SKILL.md) |
| JUnit `@Test`, Mockito | 같은 파일 `#[cfg(test)] mod tests`, 통합은 `tests/`. mock 보다 손으로 만든 fake 먼저, trait 경계에만 mockall | [rust-testing](../rust-testing/SKILL.md) |
| `@DataJpaTest` + Testcontainers | `#[sqlx::test]` (`migrate` feature 를 켜고 `Pool` 인자를 받으면 테스트마다 새 DB, superuser `DATABASE_URL` 필요) 또는 testcontainers | [rust-testing](../rust-testing/SKILL.md) |
| Checkstyle·SonarQube | clippy + `[lints]` + clippy.toml. Cognitive Complexity 는 clippy 로 재지 않는다 (문서가 측정값을 믿지 말라고 함) | [rust-idioms](../rust-idioms/SKILL.md) |

## Bean·@Autowired → main 에서 조립

DI 컨테이너가 하던 일을 `main` (또는 그 옆 조립 함수)이 코드로 한다. 의존성 그래프가 한 화면에 보인다.

```rust
#[derive(Clone)]
pub struct Users {
    pool: PgPool, // Clone 은 참조 카운트 handle 복사라 싸다
}

#[derive(Clone)]
pub struct AppState {
    pub users: Users, // Bean 하나 = 필드 하나
}

pub async fn build_app(database_url: &str) -> Result<Router, sqlx::Error> {
    let pool = PgPool::connect(database_url).await?;
    let state = AppState { users: Users::new(pool) };
    Ok(Router::new()
        .route("/users/{id}/nickname", get(fetch_nickname))
        .with_state(state))
}

async fn fetch_nickname(State(app): State<AppState>, Path(id): Path<i64>) -> Result<String, AppError> {
    app.users.nickname(id).await?.ok_or(AppError::NotFound)
}
```

`Users` 이름에 `Service`·`Impl` 을 붙이지 않는다. service 계층은 그대로 두되 타입 이름은 역할로 짓는다. `AppError` → HTTP 응답 변환은 [rust-error-handling](../rust-error-handling/SKILL.md) 이 다룬다.

## Optional → Option

| Java `Optional` | Rust `Option` |
|---|---|
| `Optional.ofNullable(x)` | 값 자체를 `Option<T>` 로 둔다 (null 이 없다) |
| `.map(f)` / `.flatMap(f)` / `.filter(p)` | `.map(f)` / `.and_then(f)` / `.filter(p)` |
| `.orElse(v)` / `.orElseGet(f)` | `.unwrap_or(v)` (인자를 미리 계산) / `.unwrap_or_else(f)`, `.unwrap_or_default()` |
| `.orElseThrow(() -> e)` | `.ok_or(e)?`. 에러 생성에 비용이 들 때만 `.ok_or_else(\|\| e)?` (clippy `unnecessary_lazy_evaluations`) |
| `isPresent() && p(v)` / `isEmpty() \|\| p(v)` | `.is_some_and(p)` (1.70+) / `.is_none_or(p)` (1.82+) |
| `.ifPresent(f)` | `if let Some(v) = opt { … }` |
| `.get()` | 쓰지 않는다. 불변식이면 `expect("왜 None 일 수 없는지")`, 아니면 `?` |

```rust
// Java: users.findById(id).map(User::getEmail).orElseThrow(() -> new UserNotFound(id))
pub fn email_of(users: &BTreeMap<UserId, User>, id: UserId) -> Result<&Email, LookupError> {
    users.get(&id).map(User::email).ok_or(LookupError::NotFound(id))
}
```

## @Transactional → 명시적 트랜잭션

sqlx 문서에서 선언형 트랜잭션 기능은 찾을 수 없다. 경계를 여는 함수 한 곳이 `begin`·`commit` 을 쓰고, 하위 함수는 트랜잭션인지 모른 채 연결만 받는다.

```rust
// @Transactional 메서드에 해당한다. ? 로 빠져나가면 tx 가 drop 되어 rollback 된다
pub async fn register(pool: &PgPool, email: &str, nickname: &str) -> Result<i64, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let user_id = insert_user(&mut tx, email).await?;
    insert_profile(&mut tx, user_id, nickname).await?;
    tx.commit().await?;
    Ok(user_id)
}

// 스스로 트랜잭션을 열지 않는다. Spring SUPPORTS 에 해당한다 — tx 를 받으면 참여, 그냥 연결이면 문장마다 autocommit
async fn insert_user(conn: &mut PgConnection, email: &str) -> Result<i64, sqlx::Error> {
    sqlx::query_scalar("INSERT INTO users (email) VALUES ($1) RETURNING id")
        .bind(email)
        .fetch_one(conn)
        .await
}
```

- `&mut tx` 는 `Transaction` 의 `DerefMut` 로 `&mut PgConnection` 이 되어 하위 함수에 그대로 넘어간다. 쿼리에 직접 줄 때는 `&mut *tx`.
- 범위가 코드에 보이므로 Spring 프록시의 self-invocation 함정(같은 객체 안 호출엔 트랜잭션이 안 걸림)이 없다.
- 하위 함수를 tx 없이 부르면 PostgreSQL 은 문장마다 암묵적 BEGIN·COMMIT 을 씌운다. 여러 문장이 함께 성공·실패해야 하면 경계 함수가 `begin` 한다.

## Builder → struct literal + Default

```rust
use std::time::Duration;

#[derive(Debug, Clone, PartialEq)]
pub struct HttpClientConfig {
    pub timeout: Duration,
    pub max_retries: u32,
    pub user_agent: String,
}

impl Default for HttpClientConfig {
    fn default() -> Self {
        Self { timeout: Duration::from_secs(10), max_retries: 3, user_agent: "app".to_owned() }
    }
}

pub fn retrying_client() -> HttpClientConfig {
    // Lombok: HttpClientConfig.builder().maxRetries(5).build()
    HttpClientConfig { max_retries: 5, ..HttpClientConfig::default() }
}
```

- 설정·DTO 처럼 불변식 없는 값 묶음은 `pub` 필드가 관용이다 (C-STRUCT-PRIVATE: "compound, passive data structures"). 불변식이 있는 도메인 타입은 필드를 숨기고 생성자를 둔다.
- 검증할 필드가 있으면 builder 를 쓰고 `.build()` 가 `Result` 를 돌려준다 (M-BUILD-RESULT). builder 형태는 출처끼리 달라(bon typestate vs Microsoft M-INIT-BUILDER 의 `Foo::builder(필수값)`) 프로젝트에서 하나로 정한다.

## 포팅 절차 — createUser 를 옮기는 순서

1. **도메인 흐름을 그대로 적는다.** 메서드 이름이 곧 단계 이름이다.
2. **예외를 `Result` 로 바꾼다.** 호출자가 분기할 실패만 enum variant 로, 하위 에러는 `#[from]` 으로 한 번.
3. **interface 를 지운다.** concrete 타입으로 시작한다. 구현을 바꿔 끼우거나 fake 로 테스트할 경계(DB·외부 API·시계)에만 좁은 trait 를 두고 generic 으로 받는다. trait 를 만들 이유가 없는 시스템 호출은 enum (`Native`/`Mocked`).
4. **검증을 newtype 으로 옮긴다.** 필드는 `Email::parse(&str)`, DTO 전체를 묶으면 `NewUser::try_from(req)`. 파싱은 use case 입구 fn(`create_user`) 첫 줄에서 한 번 하고, 그 아래 단계 fn·repo 는 검증된 타입만 받는다.
5. **lint 로 고정한다.** Cargo.toml `[lints]` 에 `too_many_lines`·`unwrap_used` = `warn`, clippy.toml 에 `too-many-lines-threshold = 100`·`excessive-nesting-threshold = 4`·`allow-unwrap-in-tests = true` (house rule, [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md)).

```java
// Java (Spring)
public User createUser(CreateUserRequest req) {
    checkEmail(req.getEmail());
    checkDuplicateNickname(req.getNickname());
    return userRepository.save(req.toEntity());
}
```

```rust
#[derive(Debug, thiserror::Error)]
pub enum SignupError {
    #[error("invalid email")]
    InvalidEmail,
    #[error("nickname already taken")]
    DuplicateNickname,
    #[error("database error")]
    Db(#[from] sqlx::Error), // 원인은 source() 로만 — Display 에 {0} 을 넣지 않는다
}

pub struct Email(String);

impl Email {
    pub fn parse(raw: &str) -> Result<Self, SignupError> {
        // 형식은 최소한만 본다. 실제 소유 확인은 인증 메일이 맡는다
        match raw.split_once('@') {
            Some((local, domain)) if !local.is_empty() && domain.contains('.') => Ok(Self(raw.to_owned())),
            _ => Err(SignupError::InvalidEmail),
        }
    }
}

pub async fn create_user(users: &Users, req: CreateUserRequest) -> Result<UserId, SignupError> {
    let email = Email::parse(&req.email)?; // checkEmail → use case 입구에서 한 번 파싱, 아래로는 Email 만 넘긴다
    check_duplicate_nickname(users, &req.nickname).await?;
    users.insert(&email, &req.nickname).await // 동시 가입은 DB unique 제약이 최종 방어선
}

async fn check_duplicate_nickname(users: &Users, nickname: &str) -> Result<(), SignupError> {
    if users.nickname_exists(nickname).await? {
        return Err(SignupError::DuplicateNickname);
    }
    Ok(())
}
```

여기서는 짧게 `Email` 의 에러를 `SignupError` 로 두었다. `Email` 을 여러 use case 가 쓰면 `EmailError` 를 따로 두고 `InvalidEmail(#[from] EmailError)` 로 잇는다 ([rust-error-handling](../rust-error-handling/SKILL.md)).

## 용어 정리

| 용어 | 한 줄 정의 |
|---|---|
| Composed Method / SLAP | 한 함수를 같은 추상화 수준의 이름 있는 단계 호출로만 구성한다. 레포 `/dx:clean-code` 가 쓰는 이름이다 |
| Guard Clause | 예외 조건을 먼저 반환해 happy path 를 바깥에 둔다. Rust 에선 `?`, `let-else`, let chains |
| Separation of Concerns | 서로 다른 이유로 바뀌는 코드를 다른 함수·모듈·계층으로 나눈다 |
| Layered Architecture | presentation → service → persistence 처럼 위에서 아래로만 의존한다. Controller-Service-Repository 가 대표 |
| Hexagonal (Ports & Adapters) | 도메인을 가운데 두고 DB·HTTP 를 port(trait)·adapter(구현)로 바깥에 붙인다. 의존이 도메인을 향한다 |
| Functional Core, Imperative Shell / sans-IO | 계산은 IO 없는 core 에, IO 는 core 가 만든 값을 처리하는 얇은 shell 에 둔다. 시간도 인자로 받는다 |
| Centralized error handling | 에러 → 응답 변환을 한 지점에 모은다. Spring `@ControllerAdvice`, axum `impl IntoResponse for AppError` |
| High Cohesion / Low Coupling | 모듈 안은 같은 목적으로 묶고 모듈 사이 의존은 줄인다. "파일을 어디서 쪼갤까" 의 기준 |
| Maintainability / Evolvability | 읽고 고치기 쉬운 정도 / 요구가 바뀔 때 구조를 깨지 않고 확장할 수 있는 정도 |
| Parse, don't validate | 검증 결과를 bool 로 버리지 않고 더 정밀한 타입으로 바꿔, 이후 코드가 다시 검사하지 않게 한다 |
| Newtype | 기존 타입을 감싼 단일 필드 struct (`struct Email(String)`). 의미와 불변식을 타입에 담는다 |
| Type-state | 상태를 타입으로 표현해 잘못된 전이를 컴파일 타임에 막는다 (Book 18.3 `DraftPost` → `Post`) |

## Anti-Patterns — 버릴 Java 습관

| Java 습관 | 왜 안 되나 | 대신 |
|---|---|---|
| 클래스마다 interface (`XxxService` + `XxxServiceImpl`) | Microsoft 가 C# interface 를 trait + `dyn` 으로 직역한 예를 비관용으로 지목. Google "Don't use traits merely to organize code" | concrete 먼저. 바꿔 끼우거나 fake 가 필요한 경계에만 좁은 trait + generic |
| 상속·`BaseService`·`Deref` 로 상속 흉내 | 상속이 없고 `Deref` 는 subtyping 을 만들지 못한다 | composition, trait default method, enum |
| `panic!` 을 throw 로, `catch_unwind` 를 catch 로 | "Panics are not exceptions". `panic = "abort"` 면 잡히지도 않는다 | 입력·외부 상태 실패는 `Result`, panic 은 버그 전용 |
| `new RuntimeException("msg")` 식 문자열 에러 | `String` 은 `Error` trait 를 구현하지 않고 분기할 수 없다 | 기능별 thiserror enum, 앱 경계는 `AppError` 하나 |
| 호출부마다 try-catch-rethrow (`map_err` 반복) | happy path 가 흐려진다 | `impl From` 한 번 + `?` |
| `getXxx()`, `XxxFactory`, `XxxManager` | C-GETTER: `get_` 접두사 미사용. M-WEASEL-WORDS: Service·Manager·Factory 는 의미 없는 단어 | `email()`, Builder 또는 `impl Fn() -> T`, 역할 이름 |
| boolean flag 인자 (`createUser(req, true, false)`) | 호출부에서 의도가 안 보인다 | 2-variant enum, 이름 있는 함수 두 개, options struct |
| Stream 처럼 조건·상태 변경을 한 chain 에 | Google·rust-analyzer 모두 긴 combinator chain 을 피하라고 한다 | 짧으면 combinator, 섞이면 `for`/`match` |
| 곳곳에 `Arc<Mutex<..>>`, god service | 공유 가변 상태가 퍼진다 | 작은 struct, 짧은 구간 std `Mutex`, 나머지는 message passing |
| borrow checker 를 피하려고 `clone()` | 학습·프로토타입에서만 허용되는 안티패턴 | `&T` 로 빌리기 → move → `Arc::clone` |
| SonarQube Cognitive Complexity ≤ 15 를 clippy 로 강제 | `cognitive_complexity` 는 restriction 으로 내려갔고 문서가 측정 도구로 쓰지 말라고 한다 | `too_many_lines` + `excessive_nesting` (threshold 필수) + 리뷰 |
| Checkstyle 처럼 코드에 `#![deny(warnings)]` | 컴파일러가 바뀌면 빌드가 깨진다 | CI 에서 `-D warnings`, 예외는 `#[expect(lint, reason = "…")]` |
| `utils`·`errors`·`traits` 같은 기술 분류 모듈 | 무엇이 들어 있는지 이름이 말해주지 않는다 | `user`, `track` 같은 도메인 모듈. 앱 경계 `AppError` 하나를 담는 `error.rs` 는 예외 |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[기능 검증]** — 옮긴 코드가 `cargo test` 와 `cargo clippy --all-targets -- -D warnings` 를 통과한다
   예: [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 lint 설정(`too_many_lines`, `unwrap_used`, clippy.toml threshold)을 켠 상태에서 통과
2. **[습관 제거]** — 아래 검색으로 나온 후보를 확인해 실제 위반이 0건이거나, 남은 건마다 이유가 주석으로 있다
   예: `rg -n 'struct \w+Impl\b'` · `rg -n 'fn get_\w+\(&self'` · `rg -n 'Result<.*,\s*String>'` · `rg -n 'Result<.*,\s*\(\)>'` · `rg -n 'catch_unwind'` · `rg -n '#!\[deny\(warnings\)\]'`
3. **[대응 정확성]** — 대응표의 각 행은 한 줄 요약일 뿐이다. 최종 형태는 링크된 skill 의 결정 트리로 정했다
   예: `@Autowired` 를 옮길 때 [rust-engine-architecture](../rust-engine-architecture/SKILL.md) 의 concrete > generic > `dyn` 순서를 따랐다
4. **[일관성]** — [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 에러·추상화·네이밍 규칙과 `/dx:clean-code` 의 Composed Method 원칙을 지킨다. 서비스 함수가 50줄을 넘으면 단계 추출을 검토한다 (house rule: 20-50줄 PREFER, clippy `too_many_lines` threshold 100 — 공식 숫자 기준 아님)

## 참조 스킬

- [rust-idioms](../rust-idioms/SKILL.md) — Composed Method·중첩 줄이기·newtype·모듈 분할·lint 템플릿
- [rust-error-handling](../rust-error-handling/SKILL.md) — `@ControllerAdvice` 대응, thiserror·anyhow, panic 정책
- [rust-engine-architecture](../rust-engine-architecture/SKILL.md) — core/shell workspace, DI 사다리, 계층 → adapter 매핑
- [rust-async-tokio](../rust-async-tokio/SKILL.md) — `@Async`·스레드 풀·lock·종료·관측성·설정
- [rust-testing](../rust-testing/SKILL.md) — JUnit·Mockito·Testcontainers 대응
- [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) — 트랜잭션·outbox·테이블 큐
- [rust-crdt-sync](../rust-crdt-sync/SKILL.md) — WebSocket 협업 편집 엔진
- [rust-geo-track](../rust-geo-track/SKILL.md) — GPS 구간 통과 판정·부정 기록 탐지 core
- [rust-og-image-render](../rust-og-image-render/SKILL.md) — OG 미리보기 이미지 렌더 서버
- `/java:spring-patterns` — 대응 전 Spring 쪽 계층·트랜잭션·예외 규칙
- `/dx:clean-code` — Composed Method·SLAP·Guard Clause 원칙 (언어 공통)
- `/architecture:hexagonal-clean-architecture` — Ports & Adapters 개념

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. 따옴표 안은 원문 문자열이다. 다음 재검증은 2027-02.

**원칙·가이드라인**
- Microsoft Pragmatic Rust Guidelines — [AI (M-RUST-SHAPED)](https://microsoft.github.io/rust-guidelines/guidelines/ai/index.html) · [Universal (M-WEASEL-WORDS)](https://microsoft.github.io/rust-guidelines/guidelines/universal/index.html) · [Correctness (M-PANIC-IS-STOP)](https://microsoft.github.io/rust-guidelines/guidelines/correctness/index.html) — 검증일 2026-11-15 · ✅ verified · subagent
- Microsoft — [Libraries UX (M-DI-HIERARCHY, M-INIT-BUILDER, M-SERVICES-CLONE)](https://microsoft.github.io/rust-guidelines/guidelines/libs/ux/index.html) · [Resilience (M-BUILD-RESULT, M-STRONG-TYPES-GUARD, M-MOCKABLE-SYSCALLS)](https://microsoft.github.io/rust-guidelines/guidelines/libs/resilience/index.html) — 검증일 2026-11-15 · ✅ verified (library 장이라 앱 적용은 해석. M-INIT-BUILDER: "4 or more arbitrary initialization permutations" 면 builder, "up to 2 optional initialization parameters" 는 inherent 메서드. M-DI-HIERARCHY: 테스트용 대체만이면 enum — 레포 결정(D1)은 그 자리에 좁은 trait + generic 을 고름) · subagent
- [Google Rust Style Guide](https://google.github.io/styleguide/rustguide.html) · [rust-analyzer style](https://raw.githubusercontent.com/rust-lang/rust-analyzer/master/docs/book/src/contributing/style.md) (프로젝트 내부 스타일, "don't bend the code to fit into some combinator") · [Rust API Guidelines — Naming (C-GETTER)](https://rust-lang.github.io/api-guidelines/naming.html) · [Future proofing (C-STRUCT-PRIVATE)](https://rust-lang.github.io/api-guidelines/future-proofing.html#c-struct-private) — 검증일 2026-11-15 · ✅ verified (Google 적용 범위는 "intend to start applying" 단계로 정정) · subagent
- [Comprehensive Rust — From OOP to Rust](https://google.github.io/comprehensive-rust/idiomatic/from-oop-to-rust/problem-solving.html) · [Parse, don't validate (Alexis King)](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) · [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) · [Firezone — sans-IO](https://www.firezone.dev/blog/sans-io) (스타트업 사례) · [Hexagonal Architecture (Cockburn)](https://alistair.cockburn.us/hexagonal-architecture/) · [sled — errors](https://sled.rs/errors.html) — 검증일 2026-11-15 · ✅ verified · subagent
- [Deref polymorphism 안티패턴](https://rust-unofficial.github.io/patterns/anti_patterns/deref.html) · [Clone to satisfy the borrow checker](https://rust-unofficial.github.io/patterns/anti_patterns/borrow_clone.html) · [deny(warnings) 안티패턴](https://rust-unofficial.github.io/patterns/anti_patterns/deny-warnings.html) · [corrode — Java to Rust](https://corrode.dev/learn/migration-guides/java-to-rust/) · [Spring — @Transactional self-invocation](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html) · [Spring — propagation](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/tx-propagation.html) · [Spring Data JPA — Specifications](https://docs.spring.io/spring-data/jpa/reference/jpa/specifications.html) ("JPA’s Criteria API lets you build queries programmatically") — 검증일 2026-11-15 · ✅ verified · subagent
- Spring javadoc — [MethodArgumentNotValidException](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/bind/MethodArgumentNotValidException.html) ("validation on an argument annotated with @Valid fails") · [HttpMessageNotReadableException](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/http/converter/HttpMessageNotReadableException.html) · [@ControllerAdvice](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/bind/annotation/ControllerAdvice.html) ("Specialization of @Component") · [Propagation](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/annotation/Propagation.html) (SUPPORTS: "execute non-transactionally if none exists") — 검증일 2026-11-15 · ✅ verified · subagent
- [PostgreSQL — Transactions](https://www.postgresql.org/docs/current/tutorial-transactions.html) ("each individual statement has an implicit BEGIN and (if successful) COMMIT") — 검증일 2026-11-15 · ✅ verified · subagent
- 용어 "Composed Method"·"SLAP" — ⚠️ 원 출처 미검증 (레포 clean-code 가 쓰는 이름으로만 인용)

**언어·표준 라이브러리**
- [Book 18 — OOP](https://doc.rust-lang.org/book/ch18-01-what-is-oo.html) · [18.3 type-state](https://doc.rust-lang.org/book/ch18-03-oo-design-patterns.html) · [6.2 — Matches Are Exhaustive](https://doc.rust-lang.org/book/ch06-02-match.html) · [Appendix C — Derivable Traits](https://doc.rust-lang.org/book/appendix-03-derivable-traits.html) · [std Option](https://doc.rust-lang.org/std/option/enum.Option.html) · [std Default](https://doc.rust-lang.org/std/default/trait.Default.html) · [std Display](https://doc.rust-lang.org/std/fmt/trait.Display.html) · [Reference — Visibility](https://doc.rust-lang.org/reference/visibility-and-privacy.html) — 검증일 2026-11-15 · ✅ verified · subagent
- 코드 블록 컴파일 — 검증일 2026-11-15 · ✅ 로컬 실측 (rustc 1.96, `cargo check`·`cargo clippy --all-targets -D warnings`·`cargo test`, 검증 기록 참조) · subagent — DB 를 쓰는 블록(Bean·@Transactional·포팅 `create_user`)은 컴파일·clippy 만, 실행 안 함 (Postgres 없음). drop 시 rollback 은 sqlx `Transaction` 문서 근거. `cargo test` 는 순수 로직 블록(Optional·Builder·`Email`)만. `QueryBuilder`·`SqlSafeStr` 문장은 별도 probe 로 확인 (`push_bind` 가 `$1`… placeholder 를 만드는 SQL 문자열 테스트, `format!` String 은 E0277)

**크레이트·런타임**
- [axum 0.8.9 — State](https://docs.rs/axum/0.8.9/axum/index.html) · [axum CHANGELOG (`/{id}` 경로)](https://raw.githubusercontent.com/tokio-rs/axum/main/axum/CHANGELOG.md) · [error-handling 예제](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/examples/error-handling/src/main.rs) — 검증일 2026-11-15 · ✅ verified · subagent
- [sqlx 0.9.0 Transaction](https://docs.rs/sqlx/0.9.0/sqlx/struct.Transaction.html) · [Pool](https://docs.rs/sqlx/0.9.0/sqlx/struct.Pool.html) · [crates.io features](https://crates.io/api/v1/crates/sqlx/0.9.0) · [sqlx::test 속성](https://docs.rs/sqlx/0.9.0/sqlx/attr.test.html) · [CHANGELOG (SqlSafeStr)](https://raw.githubusercontent.com/launchbadge/sqlx/main/CHANGELOG.md) · [SqlSafeStr](https://docs.rs/sqlx/0.9.0/sqlx/trait.SqlSafeStr.html) · [QueryBuilder](https://docs.rs/sqlx/0.9.0/sqlx/struct.QueryBuilder.html) (`push_bind`, 로컬 probe 로 SQL 문자열 확인) · [migrate!](https://docs.rs/sqlx/0.9.0/sqlx/macro.migrate.html) ("Available on crate features macros and migrate only") — 검증일 2026-11-15 · ✅ verified · subagent
- [bon](https://docs.rs/bon/latest/bon/) · [config Environment](https://docs.rs/config/latest/config/struct.Environment.html) · [mockall 0.15.0](https://docs.rs/mockall/0.15.0/mockall/) — 검증일 2026-11-15 · ✅ verified · subagent
- [geo 0.33.1 Distance](https://docs.rs/geo/0.33.1/geo/algorithm/line_measures/trait.Distance.html) · [usvg 0.50.0 Options](https://docs.rs/usvg/0.50.0/usvg/struct.Options.html) — 검증일 2026-11-15 · ✅ verified (도메인 계산·이미지 생성 두 행은 [rust-geo-track](../rust-geo-track/SKILL.md)·[rust-og-image-render](../rust-og-image-render/SKILL.md) 의 검증 항목을 한 줄로 줄인 것. 503 동작은 그 skill 의 로컬 테스트) · subagent
- [config 0.15.27 src/env.rs](https://raw.githubusercontent.com/rust-cli/config-rs/v0.15.27/src/env.rs) (`separator.as_deref().unwrap_or("")`, 비어 있으면 키를 `.` 으로 바꾸지 않는다) — 검증일 2026-11-15 · ✅ verified (❌ 정정: 조사 단계의 "separator 기본값 `.`" 은 틀렸다) + 로컬 테스트 · subagent
- [tokio Mutex](https://docs.rs/tokio/latest/tokio/sync/struct.Mutex.html) · [MissedTickBehavior](https://docs.rs/tokio/1.54.1/tokio/time/enum.MissedTickBehavior.html) · [tracing instrument](https://docs.rs/tracing/latest/tracing/attr.instrument.html) · [Alice Ryhl — What is blocking](https://ryhl.io/blog/async-what-is-blocking/) — 검증일 2026-11-15 · ✅ verified (❌ 정정값 적용: CPU 계산에 spawn_blocking 은 "poorly suited") · subagent
- [clippy cognitive_complexity](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/cognitive_complexity.rs) · [clippy unnecessary_lazy_evaluations](https://rust-lang.github.io/rust-clippy/stable/index.html#unnecessary_lazy_evaluations) (기본 warn 은 로컬 clippy 실측) · [Transactional outbox](https://microservices.io/patterns/data/transactional-outbox.html) · [K8s probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/) — 검증일 2026-11-15 · ✅ verified · subagent
