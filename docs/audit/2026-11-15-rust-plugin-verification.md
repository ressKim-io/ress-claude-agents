# Rust plugin 사실 검증 기록 (2026-11-15)

rust plugin(skill 10개, rule `rust.md`, command 4개, agent `rust-reviewer`)이 기대는 외부 사실을 1차 출처와 로컬 컴파일로 확인한 기록이다. 조사 보고서 두 건(언어 전반·엔진 3종. 로컬 자료라 커밋하지 않음)에서 ✅ 와 ❌→정정 항목만 자산에 옮겼다. 자산을 쓰면서 새로 필요해진 사실은 그 자리에서 원문을 받거나 scratch crate 로 실측했다. 자산마다 사실이 31~66건이라, 이 기록에는 판단을 좌우하는 행만 남기고 절마다 생략 건수를 적는다. skill 10개는 본문 끝 `Sources / Verified` 절에 자기 출처를 따로 적는다.

| 항목 | 값 |
|---|---|
| 검증일 | 2026-11-15 (조사 2026-11-14~15) |
| 검증 방법 | research subagent → 적대적 verify subagent(원문 재fetch) → 자산 작성 subagent(빠진 사실은 `curl -sL`·crates.io API·docs.rs·raw GitHub 소스로 live fetch) → 2-lens review loop(자산마다 2~4라운드, blocking 0 까지) → consistency critic. 코드 블록은 자산마다 scratch crate 에 그대로 옮겨 `cargo check --all-targets`, `cargo clippy --all-targets -- -D warnings`, `cargo test` 를 돌렸다 |
| toolchain | 로컬 rustc·cargo 1.96.0, clippy 0.1.96, cargo-nextest 0.9.143. 최신 stable 1.100.0(2026-11-12)은 설치하지 않았다. 1.97+ 동작은 원문으로만 확인했다 |
| 검증자 | subagent. 표의 검증자 칸에 단계를 적는다: `verify`(조사→적대적 검증), `writer`(자산 작성 중 live fetch·로컬 실측), `review`(리뷰 지적으로 고친 것) |
| 환경 제약 | 로컬 Postgres·docker daemon 이 없다. SQL·LISTEN/NOTIFY·`#[sqlx::test]`·testcontainers 는 실행하지 않았다 (§검증하지 못한 것) |
| 인용 규칙 | 따옴표 안은 원문 문자열이다. 패치 버전·배포일은 이 기록에만 쓰고 skill 본문은 caret `major.minor` 로 쓴다 |
| 다음 재검증 | 2027-02. axum 0.9·RTN·clippy.toml 위치·Google 가이드 적용 범위·yrs·resvg 는 그 전에라도 바뀔 수 있다 |

상태 표기: ✅ verified (원문 대조) / ✅ 로컬 실측 (rustc·clippy 1.96, scratch crate) / ⚠️ unverified (사유 1줄) / ❌→정정 (조사·초안 값이 틀려 정정값을 사실 칸에 적음) / house rule (외부 사실이 아니라 레포 결정).

컴파일 표기: tested(테스트 통과) · clippy-clean(`-D warnings` 통과, 실행 안 함) · compiled(check 만) · expected-fail(BAD 예시가 적힌 에러로 실패함을 확인) · not-compiled(코드가 아니거나 실행 불가, 사유 병기). scratch crate 에는 stub 타입 같은 스캐폴딩만 더했다.

---

## 0. 버전 기준

출처는 crates.io API(`https://crates.io/api/v1/crates/<name>`)의 `max_stable_version`·`created_at` 이고, Rust 는 [channel-rust-stable.toml](https://static.rust-lang.org/dist/channel-rust-stable.toml)이다. 2026-11-14~15 에 조회했다.

| crate·도구 | 버전 (배포일) | 비고 | 상태 |
|---|---|---|---|
| Rust stable / 로컬 | 1.100.0 (2026-11-12) / 1.96.0 (2026-05-25) | edition 2024 는 1.85+, let chains 는 1.88+ | ✅ |
| tokio / tokio-util | 1.54.1 (2026-10-21) / 0.7.20 (2026-10-09) | 1.54.0 은 yanked. LTS 1.51.x(~2027-03)·1.53.x(~2027-09) | ✅ |
| axum / tower / tower-http | 0.8.9 (2026-04-14) / 0.5.3 (2026-01-12) / 0.7.1 (2026-08-31) | axum 0.9 미출시. axum 0.8.9 + tower-http 0.7.1 은 scratch 에서 함께 컴파일 | ✅ |
| sqlx | 0.9.0 (2026-05-21) | MSRV 1.94 라 프로젝트 `rust-version` 하한이 된다 | ✅ |
| thiserror / anyhow / rayon | 2.0.21 (2026-09-23) / 1.0.104 (2026-07-18) / 1.12.0 (2026-04-14) | | ✅ |
| opentelemetry·-otlp / tracing-opentelemetry / tracing-subscriber | 0.33.1 (2026-10-09) / 0.34.0 (2026-09-23) / 0.3.23 (2026-03-13) | otlp 기본 feature 에 grpc-tonic 이 없다 | ✅ |
| metrics-exporter-prometheus / prometheus(tikv) | 0.18.3 (2026-04-30) / 0.14.0 (2025-03-27) | tikv 는 그 뒤 릴리스 없음 | ✅ |
| config / secrecy | 0.15.27 (2026-09-30) / 0.10.3 (2024-10-09) | | ✅ |
| proptest / insta / mockall | 1.12.0 (2026-10-10) / 1.49.0 (2026-10-03) / 0.15.0 (2026-06-28) | proptest MSRV 1.88 | ✅ |
| criterion / divan | 0.8.2 (2026-02-04) / 0.1.21 (2025-04-10) | divan 은 그 뒤 릴리스 없음 | ✅ |
| testcontainers / -modules | 0.28.0 (2026-08-06) / 0.15.0 (2026-02-21) | modules 0.15 는 testcontainers ^0.27 | ✅ |
| cargo-nextest / cargo-llvm-cov | 0.9.152 (2026-11-13) / 0.9.1 (2026-09-06) | 로컬 nextest 0.9.143, llvm-cov 미설치 | ✅ |
| geo / geo-types / rstar | 0.33.1 (2026-04-20) / 0.7.20 (2026-08-02) / 0.12.2 (2024-11-05) | geo 는 rstar ^0.12. rstar 0.13.1·0.14.0 은 2026-11-01 | ✅ |
| gpx / fitparser | 0.10.0 (2023-12-04) / 0.12.0 (2026-11-03) | | ✅ |
| resvg·usvg / tiny-skia / fontdb / png | 0.50.0 (2026-11-11) / 0.12.0 (2026-02-02) / 0.24.0 (2026-07-29) / 0.18.1 (2026-02-14) | resvg MSRV 1.85 | ✅ |
| cosmic-text / unicode-segmentation / unicode-normalization | 0.19.0 (2026-04-22) / 1.13.3 / 0.1.26 | unicode 두 crate 는 배포일을 기록하지 않았다 | ✅ |
| yrs / dashmap / tokio-tungstenite | 0.28.1 (2026-11-04) / 6.2.1 / 0.29.0 | yrs breaking 은 0.28.0. tungstenite 는 테스트 전용 | ✅ |
| automerge / loro / turmoil | 0.12.0 (2026-09-16) / 1.17.1 (2026-10-22) / 0.7.2 (2026-04-24) | 비교 대상이다. 채택은 프론트 생태계가 정한다 | ✅ |
| PostgreSQL | 18.7 (current) | 문서 링크는 `/docs/18/` 로 고정 | ✅ |

## 1. `rust/rust-idioms`

컴파일: tested 17 · clippy-clean 3 · expected-fail 9 (E0502·E0308·E0624·E0761, edition 2021 let chains, edition 2015 상속 누락, target 별 `#[expect]` 결과 차이, `lint_groups_priority`, Cargo.toml threshold) · not-compiled 1 (async 모양 인라인 조각, async 스캐폴딩 없음). 리뷰 blocking 2→1→0. 사실 51건 중 16건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| `too_many_lines` 는 pedantic(기본 allow), threshold 기본 100. 코드가 있는 줄만 세고 closure 는 부모 함수에 포함한다 | [too_many_lines.rs](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/functions/too_many_lines.rs) | 2026-11-15 | verify | ✅ verified |
| `cognitive_complexity` 는 1.91 에 restriction 으로 옮겨졌다: "left in restriction so as to not mislead users into using this lint as a measurement tool" | [cognitive_complexity.rs](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/cognitive_complexity.rs) | 2026-11-15 | verify | ✅ verified |
| `excessive_nesting` 은 threshold 기본 0(꺼짐)이고 impl·fn 본문도 1단계로 센다. threshold 4 에서 free fn 은 if 4단째, impl method 는 3단째에 경고 | [excessive_nesting.rs](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/excessive_nesting.rs) | 2026-11-15 | verify·writer | ✅ verified + 로컬 실측 |
| lint 레벨은 Cargo.toml `[lints]`·`[workspace.lints]`(1.74+)에, threshold 는 clippy.toml 에만 둔다. Cargo.toml 에 `{ level, threshold }` 를 쓰면 `unused manifest key` 경고만 나고, `[lints.clippy]` 안 하이픈 threshold 키는 manifest 파싱 에러 | [manifest #lints](https://doc.rust-lang.org/cargo/reference/manifest.html#the-lints-section) | 2026-11-15 | writer | ❌→정정 (실패 양상을 위치별로 나눔, 로컬 실측) |
| clippy.toml 은 `CLIPPY_CONF_DIR` → `CARGO_MANIFEST_DIR` → 현재 디렉토리에서 시작해 위로 올라가며 처음 찾은 파일 하나만 쓴다. 설정 파일은 "unstable and may be deprecated". 병합하지 않는 것은 문서에 없고 로컬 실측이다 | [configuration.md](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/book/src/configuration.md) | 2026-11-15 | verify·writer | ✅ verified (병합 없음은 로컬 실측) |
| `[workspace.package]` 의 edition·rust-version 은 멤버가 `edition.workspace = true` 처럼 opt-in 해야 상속된다. `[lints] workspace = true` 만 두면 edition 2015 로 빌드돼 let chains 가 에러. workspace 안 `cargo new` 는 세 줄을 다 넣는다 | [workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html) | 2026-11-15 | writer | ✅ 로컬 실측 (cargo 1.96) |
| `lint_groups_priority`(correctness, 1.78)는 그룹과 개별 lint 의 priority 가 같고 level 이 다를 때만 난다. 표 안 순서는 무시되고, virtual manifest 의 `[workspace.lints]` 에서도 에러가 난다 | [lint_groups_priority.rs](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/cargo/lint_groups_priority.rs) | 2026-11-15 | writer | ❌→정정 (V-20 문구 구체화, §13 행 참조) |
| let-else(else 블록은 diverge)와 labeled block `break 'a` 는 1.65. let chains 는 1.88 + edition 2024 전용이고 2021 에서는 "let chains are only allowed in Rust 2024 or later" | [Rust 1.88.0](https://blog.rust-lang.org/2025/06/26/Rust-1.88.0/), [Rust 1.65.0](https://blog.rust-lang.org/2022/11/03/Rust-1.65.0/) | 2026-11-15 | verify·writer | ✅ verified + 로컬 실측 |
| `#[expect]` 는 1.81 stable. 지켜지지 않으면 `unfulfilled_lint_expectations` 가 나고, build target 마다 lint 결과가 다르면 한쪽에서 unfulfilled 가 된다 | [Rust 1.81.0](https://blog.rust-lang.org/2024/09/05/Rust-1.81.0/) | 2026-11-15 | verify·writer | ✅ verified + 로컬 실측 |
| `allow-unwrap-in-tests`: 1.100 전 `is_in_test` 는 `#[test]`·`cfg(test)` 만 본다. 1.100 은 rustc 입력 경로가 `tests` 로 시작하면 통합 테스트로 본다(#16786). 1.96 은 `tests/common/mod.rs` helper 의 unwrap 에 경고 | [clippy_utils 1.100.0](https://raw.githubusercontent.com/rust-lang/rust-clippy/rust-1.100.0/clippy_utils/src/lib.rs), [#16786](https://github.com/rust-lang/rust-clippy/pull/16786) | 2026-11-15 | writer | ✅ verified (1.100 은 소스, 1.96 은 로컬 실측) |
| Book 7.5: `foo.rs` + `foo/` 가 관용이고 `mod.rs` 는 older style. 둘을 같이 두면 E0761. `tests/common/mod.rs` 는 예외다(Book 11.3) | [Book 7.5](https://doc.rust-lang.org/book/ch07-05-separating-modules-into-different-files.html) | 2026-11-15 | verify·writer | ✅ verified + 로컬 실측 |
| 필드를 빌린 채 `&mut self` helper 를 부르면 E0502. 필요한 필드만 받는 fn 이나 구조 분해로 푼다. view types 는 2026 project goal 실험(Status: Accepted)이라 지금은 쓸 수 없다 | [babysteps](https://smallcultfollowing.com/babysteps/blog/2018/11/01/after-nll-interprocedural-conflicts/), [view types](https://goals.rust-lang.org/2026/view-types-experiment.html) | 2026-11-15 | verify·writer | ✅ verified / view types 는 ❌→정정 (FN-14) |
| rust-analyzer 의 "Avoid creating single-use helper functions"(예외: `return`·`?` 를 쓸 때)는 그 프로젝트 내부 규칙이다. 함수 끝에 둔 nested helper fn 은 pedantic `items_after_statements` | [rust-analyzer style](https://raw.githubusercontent.com/rust-lang/rust-analyzer/master/docs/book/src/contributing/style.md) | 2026-11-15 | verify | ✅ verified |
| M-BALANCED-MODULES 원문은 traits·errors 만 든다: "Modules named traits and errors don't help anyone". `utils` 로 넓힌 것과 앱 경계 `error.rs` 예외는 skill 의 해석이다(library 장) | [MS libs/ux](https://microsoft.github.io/rust-guidelines/guidelines/libs/ux/index.html) | 2026-11-15 | writer | ❌→정정 (귀속을 traits·errors 로 한정) |
| 공식·대기업 가이드(Style Guide, MS, Google, kernel, rust-analyzer)에 함수·파일 길이 숫자가 없고 clippy 에 파일 길이 lint 가 없다. 기본 release profile(`overflow-checks = false`)은 정수 overflow 를 wrap 한다 | [Style Guide](https://doc.rust-lang.org/style-guide/index.html), [profiles #release](https://doc.rust-lang.org/cargo/reference/profiles.html#release) | 2026-11-15 | verify·writer | ❌→정정 (FN-09, "release 는 wrap" 을 기본 profile 로 한정) |
| threshold 100 명시, `excessive-nesting-threshold = 4` 시작값, 테스트 모듈 빼고 400줄 초과 시 분할 검토(awk 스크립트 로컬 테스트), `unwrap_used = warn` + `allow-unwrap-in-tests`, `cognitive_complexity` 미사용, correctness deny 유지, borrow 회피용 clone 금지 | [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) | 2026-11-15 | writer | house rule |

## 2. `rust/rust-error-handling`

컴파일: tested 9 (skill 밖 cross-check 1건 포함) · clippy-clean 3 (`nickname_conflict` 는 Postgres 에러가 있어야 `constraint()` 가 채워져 실행하지 않음, lint 설정 2) · compiled 1 (`Arc<AppError>` + `from_fn` 로그 미들웨어, axum 0.8.9) · expected-fail 3 (wildcard 없는 match E0004 flat·nested, `PermanentKind` Debug 누락 E0277, `unwrap_used`). 리뷰 blocking 3→1→3→0. 사실 52건 중 15건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| Spring `@ControllerAdvice` 는 AOP 가 아니다. DispatcherServlet 이 HandlerExceptionResolver 체인에 위임하고 ExceptionHandlerExceptionResolver 가 `@ExceptionHandler` 를 부른다 | [Spring exceptionhandlers](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-servlet/exceptionhandlers.html) | 2026-11-15 | writer | ✅ verified |
| thiserror 2: `#[from]` 은 `#[source]` 를 겸하고 같은 variant 에 다른 필드를 둘 수 없다(backtrace 제외). `#[error(transparent)]` 는 "그 외" variant 용 | [thiserror README](https://raw.githubusercontent.com/dtolnay/thiserror/master/README.md) | 2026-11-15 | verify | ✅ verified |
| std `Error`: 감싼 원인은 `source()` 와 Display 중 한쪽으로만 드러낸다("but not both"). MS 는 Display 에 cause 를 권해 충돌하고, 레포는 std 쪽을 고른다(D10) | [std Error](https://doc.rust-lang.org/std/error/trait.Error.html) | 2026-11-15 | verify | ✅ verified |
| M-APP-ERROR: 앱과 앱 전용 내부 crate 는 anyhow 허용, crate 2개 이상이 쓰면 library 로 본다. workspace 내부 crate 를 thiserror enum 으로 시작하는 것은 house rule | [MS apps](https://microsoft.github.io/rust-guidelines/guidelines/apps/index.html#M-APP-ERROR) | 2026-11-15 | verify | ❌→정정 (house rule 부분 분리) |
| sled: "Do not implement conversions from local concerns into global enums" | [sled errors](https://sled.rs/errors.html) | 2026-11-15 | verify | ✅ verified |
| axum error-handling 예제는 internal 분기만 고정 메시지로 숨기고 `JsonRejection` 은 status·문구를 그대로 보낸다. `AppJson` 은 `derive(FromRequest)` + macros feature | [axum 0.8.9 error-handling](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/examples/error-handling/src/main.rs) | 2026-11-15 | verify | ❌→정정 (JR-13: 고정 메시지는 internal 분기 한정) |
| `Arc<AppError>` response extension + `from_fn` 로그 구조는 #3527 에서 들어왔다(#3788 은 레이어 순서만 바꿨다). axum 0.8.9 로 컴파일된다 | [axum commits](https://api.github.com/repos/tokio-rs/axum/commits?path=examples/error-handling/src/main.rs) | 2026-11-15 | verify·writer | ❌→정정 (EH-19 귀속) |
| `tower::timeout::TimeoutLayer` 는 `Elapsed` 에러를 내서 `HandleErrorLayer` 가 필요하다. `tower_http` 판은 응답을 돌려주고 `TimeoutLayer::new` 는 deprecated(`with_status_code`) | [axum error_handling.md](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/axum/src/docs/error_handling.md), [tower-http 0.7.1](https://raw.githubusercontent.com/tower-rs/tower-http/tower-http-0.7.1/tower-http/src/timeout/service.rs) | 2026-11-15 | writer | ✅ verified |
| `sqlx::Error`·`ErrorKind` 는 `#[non_exhaustive]`, `code()` 는 `Option<Cow<str>>`. `Error::Database` 는 Display 에 `{0}` + `#[source]` 라 체인을 그대로 찍으면 중복된다. `constraint()` 는 "Currently only populated by the Postgres driver" | [sqlx 0.9.0 error.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/error.rs), [DatabaseError](https://docs.rs/sqlx-core/0.9.0/sqlx_core/error/trait.DatabaseError.html) | 2026-11-15 | writer | ✅ verified + 로컬 테스트 |
| rayon 클로저의 panic 은 등록한 handler 로 가고 "If no panic handler is set, the default is to abort the process". tokio oneshot 은 sender 가 보내지 않고 drop 되면 `RecvError` | [rayon ThreadPoolBuilder](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html), [rayon::spawn](https://docs.rs/rayon/latest/rayon/fn.spawn.html) | 2026-11-15 | review | ❌→정정 (Sources 비고의 과대 서술) |
| tokio task 의 panic 은 unwind 일 때만 `JoinError::is_panic` 으로 잡힌다. `panic = "abort"` 는 test 에서 무시된다. Cargo release 기본은 `panic = "unwind"` | [JoinHandle](https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html), [profiles](https://doc.rust-lang.org/cargo/reference/profiles.html) | 2026-11-15 | verify·writer | ❌→정정 |
| RFC 6455: control frame payload ≤125 bytes, close reason 은 "clients MUST NOT show it to end users", 1008 정책 위반, 1011 서버 오류. IANA 1013 = Try Again Later. axum 0.8.9 `Message::Close` 는 `Option<CloseFrame>` | [RFC 6455](https://www.rfc-editor.org/rfc/rfc6455.txt), [IANA registry](https://www.iana.org/assignments/websocket/websocket.xml) | 2026-11-15 | writer | ✅ verified |
| read-only peer 의 쓰기는 에러가 아니다. viewer 도 SyncStep2 로 답하므로 연결을 끊으면 매번 끊긴다. core `authorize` 가 버리고 센다 → 초안의 `SyncError::ReadOnly` 를 지웠다 | [y-protocols PROTOCOL.md](https://raw.githubusercontent.com/yjs/y-protocols/master/PROTOCOL.md) | 2026-11-15 | review | ❌→정정 (ReadOnly close 삭제) |
| M-PANIC-IS-STOP "Panics are not exceptions". MS 는 요청 단위 catch 를 허용하되 재시작을 유도하고, Google(적용 예정 단계)은 first-party `catch_unwind` 를 금지한다. Cloudflare 2025-11-18 장애는 FL2 Rust 프록시의 `unwrap()` panic 이다 | [MS correctness](https://microsoft.github.io/rust-guidelines/guidelines/correctness/index.html), [Cloudflare](https://blog.cloudflare.com/18-november-2025-outage/) | 2026-11-15 | verify | ✅ verified (출처 충돌 병기) |
| 로그 레벨(500=error, 예상된 400·409·503=debug), release `panic = "unwind"` 명시, `unwrap_used = warn` + `allow-unwrap-in-tests`, expect 는 이유와 함께 허용 | [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) | 2026-11-15 | writer | house rule |

## 3. `rust/rust-engine-architecture`

컴파일: tested 16 · expected-fail 5 (async fn trait + `dyn` E0038, HashMap 의 `disallowed_types`·`iter_over_hash_type`, `Instant::now` disallowed, 멤버 `[lints]` override 실패, RTN E0658) · not-compiled 2 (ASCII 결정 트리, 디렉터리 배치도). DB 접근은 stub 이고 `sqlx::Error` 타입까지만 실제다. 리뷰 blocking 2→1→0. 사실 43건 중 15건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| 패키지 하나에 lib 은 최대 1개이고 bin 은 `[dependencies]` 전체와 링크된다. target 별 의존성(cargo#1982)은 2015년부터 열려 있다 | [cargo#1982](https://github.com/rust-lang/cargo/issues/1982) | 2026-11-15 | verify | ✅ verified |
| virtual manifest 는 resolver 를 직접 적고 `"3"` 은 1.84+. `[workspace.lints]` 는 멤버마다 `[lints] workspace = true` 가 있어야 적용된다 | [workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html) | 2026-11-15 | verify | ✅ verified |
| 멤버에 `[lints] workspace = true` 와 다른 lint 를 같이 두면 cargo 1.96 이 "cannot override `workspace.lints` in `lints`" 로 실패한다. 그래서 workspace lint 는 shell 에도 걸리고 shell 은 `#[expect(.., reason)]` 로 연다. Cargo 문서에는 이 제한 문장이 없다 | [workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html) | 2026-11-15 | writer | ✅ 로컬 실측 (문서 미기재) |
| `cargo tree --target` 기본은 host 뿐이고 `-e normal` 은 dev-dep 를 뺀다. `--all-features` 가 없으면 shell 이 feature 로 켠 core 의 optional tokio 가 안 보인다. 결과를 파이프로 grep 에 넘기면 cargo tree 가 실패해도 통과한다 | [cargo-tree](https://doc.rust-lang.org/cargo/commands/cargo-tree.html) | 2026-11-15 | writer | ✅ verified + 로컬 실측 (파이프 형태는 ❌→정정) |
| geo 0.33.0 은 rand ^0.10 을 normal·non-optional 로 가진다. tree 전체에 `rand` 를 걸면 오탐한다 | [geo 0.33.0 deps](https://crates.io/api/v1/crates/geo/0.33.0/dependencies) | 2026-11-15 | writer | ✅ verified + 로컬 실측 |
| `disallowed_methods`·`disallowed_types` 는 clippy.toml 에 항목이 있을 때만 동작하고 항목 경로만 받는다(모듈 경로 `std::fs` 는 경고만 내고 막지 못함). 문서는 잘못된 경로가 에러라고 하지만 1.96 은 경고만 내고 `-D warnings` 에서도 exit 0 | [lint_configuration.md](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/book/src/lint_configuration.md) | 2026-11-15 | writer | ❌→정정 (AR-13 "에러" → 1.96 실측 경고) |
| HashMap 은 시드가 무작위라 순회 순서가 정해져 있지 않고 `iter_over_hash_type` 은 for 루프만 잡는다. `BTreeMap::extract_if` 는 1.91.0 안정화 | [HashMap](https://doc.rust-lang.org/std/collections/struct.HashMap.html), [extract_if](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html#method.extract_if) | 2026-11-15 | verify·writer | ✅ verified |
| f64 의 sin·cos·tan·atan2·hypot·exp·powf·powi·ln 등은 "Unspecified precision" 이고 `sqrt`·`mul_add` 는 결과가 보장된다 | [f64](https://doc.rust-lang.org/std/primitive.f64.html) | 2026-11-15 | verify·writer | ✅ verified |
| `Instant` 는 "opaque types that can only be compared to one another" 이고 숫자에서 만들 수 없다. 생성은 `now()` 또는 다른 Instant 에서 파생(`checked_add`) | [Instant](https://doc.rust-lang.org/std/time/struct.Instant.html) | 2026-11-15 | writer | ❌→정정 (AR-19 "생성자는 now() 뿐") |
| async fn 이 있는 trait 는 dyn compatible 이 아니다(E0038). bin crate 의 pub trait 에서도 `async_fn_in_trait` 경고가 난다. RTN 은 1.96 에서 E0658 이고 1.100.0 까지 RELEASES.md 에 안정화 기록이 없다 | [traits](https://doc.rust-lang.org/reference/items/traits.html), [rust#109417](https://github.com/rust-lang/rust/issues/109417) | 2026-11-15 | verify·writer | ✅ verified + 로컬 실측 |
| M-DI-HIERARCHY "prefer concrete types over generics, and generics over dyn Trait", 테스트 대체만 필요하면 enum(M-MOCKABLE-SYSCALLS). 레포 D1 은 enum 단계 대신 좁은 trait + generic 을 고른다(library 장 지침의 해석) | [MS libs/ux](https://microsoft.github.io/rust-guidelines/guidelines/libs/ux/index.html) | 2026-11-15 | writer | ✅ verified / D1 은 house rule |
| axum DI 예제는 "Using trait objects is recommended unless you really need generics" 라고 쓰고 예제 trait 는 sync 다 | [axum 0.8.9 DI](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/examples/dependency-injection/src/main.rs) | 2026-11-15 | verify | ✅ verified |
| quinn-proto 는 "fully deterministic"(poll_transmit·handle_timeout), rustls 는 "does not take care of network IO". rust-analyzer 는 core 가 외부와 통신하지 않는 것을 Architecture Invariant 로 적는다 | [Firezone sans-IO](https://www.firezone.dev/blog/sans-io), [rust-analyzer architecture](https://rust-analyzer.github.io/book/contributing/architecture.html) | 2026-11-15 | verify | ✅ verified |
| sqlx 0.9.0 `fetch_one` 은 `fetch_optional` 결과에 `ok_or(Error::RowNotFound)` 를 붙인 것이다. RowNotFound 는 `classify_sqlx` 에서 Transient 라, 지워진 activity 는 `fetch_optional` 의 None 으로 받아 `Rejected{ActivityMissing}` 으로 저장한다 | [sqlx 0.9.0 query_as.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/query_as.rs) | 2026-11-15 | review | ✅ verified + 로컬 테스트 |
| core `judge()` 는 `Judgement` 를 돌려주고 Err 는 shell 인프라 장애에만 쓴다. ENGINE_VERSION 을 올리는 규칙은 설계 제안이다. 파일 배치 이름은 예시다. uom 0.38.0 기본 feature 는 `[autoconvert, f32, f64, si, std]` | [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md), [uom features](https://docs.rs/crate/uom/0.38.0/features) | 2026-11-15 | writer | house rule / ⚠️ ENGINE_VERSION 규칙 (업계 출처 없음) / uom 은 ❌→정정 (AR-25) |

## 4. `rust/rust-async-tokio`

컴파일: tested 12 · compiled 1 (`[profile.release]`: manifest 파싱과 `cargo check --release` 만, LTO 링크 빌드 안 함) · expected-fail 1 (std `MutexGuard` 를 `.await` 너머 보유 → "future cannot be sent between threads safely") · not-compiled 1 (ASCII 결정 트리). 바이너리를 SIGTERM·SIGINT·hang·err·panic 다섯 경우로 실행했다. OTLP 수집기 전송은 하지 않았다. 리뷰 blocking 3→1→1→1. 마지막 라운드 지적은 자산 밖(rule 102행 정합, 이 기록의 AC-22)을 가리켰다. rule 은 이미 맞춰졌고 AC-22 는 아래 행에 반영했다. 사실 43건 중 15건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| spawn_blocking 은 시작 뒤 abort 할 수 없고 blocking 스레드 상한 기본값은 512. "When running many CPU-bound computations, a semaphore or some other synchronization primitive should be used to limit the number of computations executed in parallel. Specialized CPU-bound executors, such as rayon, may also be a good fit." | [spawn_blocking](https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html) | 2026-11-15 | verify·writer | ✅ verified |
| Alice Ryhl: blocking pool 은 스레드가 코어보다 훨씬 많아 비싼 CPU 계산에 "poorly suited" 하다. 다만 "if you only need a few CPU-bound computations, I wont blame you for running them on spawn_blocking"(원문 철자) | [ryhl.io](https://ryhl.io/blog/async-what-is-blocking/) | 2026-11-15 | verify·writer | ❌→정정 (AC-07) |
| permit 은 blocking 클로저 안으로 옮기고 job 세마포어와 CPU 세마포어를 나눈다. 하나를 공유하면 deadlock 이 난다. permit = 코어 수는 공식 수치가 아니라 시작값이다 | [Semaphore](https://docs.rs/tokio/latest/tokio/sync/struct.Semaphore.html) | 2026-11-15 | verify·writer | ✅ verified + 로컬 테스트 / 시작값은 house rule |
| rayon 기본 스레드 수는 `RAYON_NUM_THREADS` 또는 논리 CPU 수이고 전역 풀은 한 번만 초기화된다. panic handler 가 없으면 클로저 panic 에 프로세스가 abort 된다 | [ThreadPoolBuilder](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html) | 2026-11-15 | verify·writer | ✅ verified + 로컬 테스트 |
| `select!` 는 진 분기를 drop 한다. 문서의 cancel safety 목록: `read_exact` 등은 데이터 유실, `Mutex::lock` 등은 대기 순서 상실. 모든 분기가 꺼졌는데 else 가 없으면 panic | [select!](https://docs.rs/tokio/latest/tokio/macro.select.html) | 2026-11-15 | verify | ✅ verified |
| `JoinSet::join_next` 는 cancel safe 이고 JoinSet 을 drop 하면 남은 task 가 abort 된다. panic 의 JoinError Display 는 "task {id} panicked with message …" | [JoinSet](https://docs.rs/tokio/latest/tokio/task/struct.JoinSet.html), [JoinError](https://docs.rs/tokio/latest/tokio/task/struct.JoinError.html) | 2026-11-15 | writer | ✅ verified + 로컬 실행 |
| Runtime 의 Drop 은 spawn_blocking 작업을 "waits forever" 하고 `#[tokio::main]` 은 runtime 에 손이 닿지 않는다 → `Builder` + `shutdown_timeout`. 종료 시간 3.26s 대 0.79s 로 실측 | [Runtime](https://docs.rs/tokio/latest/tokio/runtime/struct.Runtime.html) | 2026-11-15 | writer | ✅ verified + 로컬 실측 |
| DropGuard 는 drop 될 때 항상 취소하고 `disarm(self)` 으로 해제한다. `TaskTracker::spawn` 은 `JoinHandle<F::Output>` 을 돌려주고 tracker 는 결과를 모으지 않는다(handle 을 버리면 Err·panic 도 사라짐). `wait()` 는 `close()` 뒤에만 끝난다 | [DropGuard](https://docs.rs/tokio-util/latest/tokio_util/sync/struct.DropGuard.html), [TaskTracker](https://docs.rs/tokio-util/latest/tokio_util/task/task_tracker/struct.TaskTracker.html) | 2026-11-15 | writer | ✅ verified + 로컬 테스트 |
| axum 0.8.9 `with_graceful_shutdown` 은 신호를 받으면 accept 를 멈추고 진행 중 요청을 기다린다. ops 서버가 worker 토큰을 공유하면 drain 중 /readyz·/healthz·/metrics 가 connection refused 이고, 토큰을 나누면 drain 중 503/200/200 이다 | [axum Serve](https://docs.rs/axum/0.8.9/axum/serve/struct.Serve.html) | 2026-11-15 | writer·review | ✅ verified + 로컬 실측 |
| K8s 는 preStop 뒤 TERM 을 보내고 grace 기본값은 30s, preStop 이 넘치면 2초를 한 번 더 준다. liveness 에 의존성을 넣으면 연쇄 장애가 난다. preStop sleep action 은 1.29 alpha → 1.34 stable | [pod-lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/), [PodLifecycleSleepAction](https://raw.githubusercontent.com/kubernetes/website/main/content/en/docs/reference/command-line-tools-reference/feature-gates/PodLifecycleSleepAction.md) | 2026-11-15 | verify·writer | ✅ verified |
| tokio Mutex 문서: "Contrary to popular belief, it is ok and often preferred to use the ordinary Mutex from the standard library in asynchronous code" | [tokio Mutex](https://docs.rs/tokio/latest/tokio/sync/struct.Mutex.html) | 2026-11-15 | verify | ✅ verified |
| opentelemetry 0.33 과 tracing-opentelemetry 0.34 는 함께 올린다. traces exporter 는 beta 라 minor 마다 breaking 이다. opentelemetry-otlp 0.33.1 기본 feature 에 grpc-tonic 이 없다 | [otlp CHANGELOG](https://raw.githubusercontent.com/open-telemetry/opentelemetry-rust/main/opentelemetry-otlp/CHANGELOG.md), [otlp 0.33.1](https://crates.io/api/v1/crates/opentelemetry-otlp/0.33.1) | 2026-11-15 | verify·writer | ✅ verified |
| tracing-subscriber 0.3.23 기본 feature 에 tracing-log 가 있고 JSON 출력에 trace_id 가 없다. AC-22 의 "`log` 레코드(sqlx 등)" 예시는 낡았다. sqlx 0.9 는 `tracing::event!(target: "sqlx::query")` 로 직접 낸다 | [EnvFilter](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/filter/struct.EnvFilter.html), [sqlx-core 0.9.0 logger.rs](https://docs.rs/crate/sqlx-core/0.9.0/source/src/logger.rs) | 2026-11-15 | writer·review | ❌→정정 (AC-22 기본 feature 와 sqlx 예시) |
| metrics-exporter-prometheus `install()` 은 모든 경로에 응답하고 `run_upkeep` 은 호출자 책임이다. tikv prometheus 는 0.14.0 뒤 릴리스가 없다. opentelemetry-prometheus README 는 새 프로젝트에 OTLP 를 권한다 | [PrometheusBuilder](https://docs.rs/metrics-exporter-prometheus/latest/metrics_exporter_prometheus/struct.PrometheusBuilder.html), [opentelemetry-prometheus README](https://github.com/open-telemetry/opentelemetry-rust/blob/main/opentelemetry-prometheus/README.md) | 2026-11-15 | verify·writer | ✅ verified |
| config `Environment` separator 에는 기본값이 없다(`unwrap_or("")`). writer 사실 목록의 "기본값 '.'" 은 JR-20 을 옮긴 것이라 틀렸다. skill 코드는 `separator("__")`·`prefix_separator("_")` 를 둘 다 명시해 본문은 영향이 없다 | [config 0.15.27 env.rs](https://raw.githubusercontent.com/rust-cli/config-rs/v0.15.27/src/env.rs) | 2026-11-15 | writer | ❌→정정 (§6 과 같은 정정) |

## 5. `rust/rust-testing`

컴파일: tested 11 · clippy-clean 2 (`#[sqlx::test]` 어댑터 테스트와 testcontainers 조각. 실행하면 DATABASE_URL·docker.sock 에서 실패) · compiled 3 (Cargo.toml 블록 2, 두 단계 migrations 경로) · expected-fail 9 (proptest-regressions 위치, 한 단계 migrations 경로, pub trait `async fn`, 없는 fixture, required-features, `--doc --lib` 혼용, testcontainers 0.28 + modules 0.15, criterion 옵션을 libtest harness 가 거부, 1.96 helper unwrap 경고) · not-compiled 2 (텍스트 결정 트리, nextest·llvm-cov 명령 — 도구 미설치). 리뷰 blocking 3→2→0. 사실 31건 중 13건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| 단위 테스트는 `#[cfg(test)] mod tests`, `tests/*.rs` 는 파일마다 별도 crate, 공용 helper 는 `tests/common/mod.rs`. `src/main.rs` 만 있는 crate 는 tests/ 에서 함수를 use 로 가져올 수 없다. doctest 는 library target 만 돈다 | [Book 11.3](https://doc.rust-lang.org/book/ch11-03-test-organization.html), [cargo test](https://doc.rust-lang.org/cargo/commands/cargo-test.html) | 2026-11-15 | verify·writer | ❌→정정 (ECO-25 문구) |
| Rust 에는 snake_case 외 테스트 이름 규칙이 없어 `should_x_when_y` 와 충돌하지 않는다 | [API naming](https://rust-lang.github.io/api-guidelines/naming.html) | 2026-11-15 | verify | ✅ verified |
| MS M-INTEGRATION-TESTS·M-MOCKABLE-SYSCALLS·M-TEST-UTIL 은 Libraries → Resilience 장이다. 앱·엔진에 적용하는 것은 해석이다 | [MS libs/resilience](https://microsoft.github.io/rust-guidelines/guidelines/libs/resilience/index.html) | 2026-11-15 | verify·review | ❌→정정 (장 귀속) |
| proptest 는 기본 256 case 이고 `PROPTEST_CASES` 를 읽는다. `f64::ANY` 는 inf·NaN 을 포함한다. `src/path.rs` 의 실패는 crate 루트 `proptest-regressions/path.txt` 에 저장되고 실패 뒤에만 생긴다(커밋 대상) | [failure-persistence](https://proptest-rs.github.io/proptest/proptest/failure-persistence.html) | 2026-11-15 | writer | ✅ verified + 로컬 실측 |
| insta 1.49 의 공식 기본 feature 는 colors 뿐이고 json·yaml 은 legacy 로 제한적으로 켜져 opt-in 하지 않으면 deprecation 경고가 난다. `INSTA_UPDATE=auto` 는 CI 에서 no, 그 밖에서 `.snap.new`. `assert_binary_snapshot!` 은 Experimental | [insta 1.49.0](https://docs.rs/insta/1.49.0/insta/) | 2026-11-15 | writer·review | ❌→정정 (legacy json·yaml 단서) |
| `#[sqlx::test]` 는 migrate feature + Pool 인자면 테스트마다 DB 를 만들고 superuser DATABASE_URL 이 필요하다. 실패한 테스트의 DB 는 남겼다가 다음 실행에 지운다 | [sqlx::test](https://docs.rs/sqlx/0.9.0/sqlx/attr.test.html) | 2026-11-15 | verify·writer | ✅ verified (DB 실행 안 함) |
| sqlx 0.9 migrations 경로: 인자가 없으면 `CARGO_MANIFEST_DIR/migrations` 가 디렉토리일 때만 쓰고 없으면 조용히 아무것도 적용하지 않는다. 절대 경로와 한 단계 상대 경로는 거부한다. 그래서 docs.rs 의 `"foo_migrations"` 예시는 0.9 에서 그대로 컴파일되지 않는다 | [sqlx-macros-core common.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-macros-core/src/common.rs) | 2026-11-15 | writer | ❌→정정 (docs.rs 예시) + 로컬 실측 |
| sqlx `MigrationSource` 는 파일 전체를 실행하고 `.up.sql`·`.down.sql` 접미사로만 나눈다. 한 파일에서 Up·Down 을 주석으로 나누면 Down 도 실행된다 | [source.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/migrate/source.rs) | 2026-11-15 | review | ✅ verified |
| testcontainers-modules 0.15.0 은 testcontainers ^0.27 에 의존해, 0.28 을 함께 넣으면 bollard-stubs 해석이 실패한다. Postgres 모듈 기본 tag 는 11-alpine | [modules 0.15.0 deps](https://crates.io/api/v1/crates/testcontainers-modules/0.15.0/dependencies) | 2026-11-15 | writer | ✅ verified + 로컬 실측 |
| mockall 0.15: 예상하지 않은 호출은 panic, `impl Future` 반환 메서드는 `Pin<Box<dyn Future>>` 기대값. 문서는 1.75 async trait 를 "Partial support" 로 적고 두 제약(`#[automock]` 을 먼저, 매크로는 정식 이름으로 import)을 둔다 | [mockall 0.15.0](https://docs.rs/mockall/0.15.0/mockall/) | 2026-11-15 | writer·review | ❌→정정 (지원 범위 서술) |
| paused time 은 runtime 이 idle 이면 I/O 대기 중에도 시계를 앞당긴다(accept 에 건 30초 timeout 이 실제 0.00초에 만료). `start_paused` 는 test-util feature 가 필요하다 | [tokio pause](https://docs.rs/tokio/1.54.1/tokio/time/fn.pause.html) | 2026-11-15 | writer | ✅ verified + 로컬 실측 |
| criterion FAQ: libtest 의 암묵 bench harness 는 criterion 옵션을 거부한다 → `[lib] bench = false`(bin 이 있으면 `[[bin]]` 도). nextest 는 doctest 를 돌리지 않고 doctest 커버리지는 nightly 전용이다 | [criterion FAQ](https://raw.githubusercontent.com/criterion-rs/criterion.rs/master/book/src/faq.md), [cargo-llvm-cov README](https://raw.githubusercontent.com/taiki-e/cargo-llvm-cov/main/README.md) | 2026-11-15 | writer | ❌→정정 (criterion 우회책) / llvm-cov ✅ |
| `should_x_when_y` + Given-When-Then, 커버리지 80%/95%, 단위 테스트는 같은 파일 끝 `#[cfg(test)] mod tests`(예외 없음) | [testing.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/testing.md) | 2026-11-15 | writer | house rule |

## 6. `rust/rust-from-spring`

컴파일: tested 6 · clippy-clean 4 (Bean·`@Transactional`·`create_user` 예시와 `query_scalar` 허용 probe. Postgres 가 필요해 실행 안 함) · expected-fail 1 (`format!` SQL → E0277 `SqlSafeStr`) · not-compiled 1 (Java 원본). 리뷰 blocking 2→0. 사실 56건 중 12건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| M-RUST-SHAPED: Java 등에서 옮길 때 "technical constructs must not be copied 1-on-1" | [MS ai](https://microsoft.github.io/rust-guidelines/guidelines/ai/index.html) | 2026-11-15 | verify | ✅ verified |
| `@ControllerAdvice` 는 "Specialization of @Component for classes that declare @ExceptionHandler, @InitBinder, or @ModelAttribute methods to be shared across multiple @Controller classes" | [ControllerAdvice](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/bind/annotation/ControllerAdvice.html) | 2026-11-15 | writer | ❌→정정 (보고서 §1.1 의 AOP 표현) |
| `MethodArgumentNotValidException` 은 `@Valid` 검증 실패이고 JSON 읽기 실패는 `HttpMessageNotReadableException` 이다 → 대응표 두 행 | [MethodArgumentNotValidException](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/bind/MethodArgumentNotValidException.html) | 2026-11-15 | writer | ❌→정정 (V-12 묶음 표기) |
| M-INIT-BUILDER: "Types that could support 4 or more arbitrary initialization permutations should provide builders". 선택 값 2개까지는 inherent method 로 만든다 | [MS libs/ux](https://microsoft.github.io/rust-guidelines/guidelines/libs/ux/index.html) | 2026-11-15 | writer | ❌→정정 (JR-18·D15 의 요약) |
| `Propagation.SUPPORTS` 는 "Support a current transaction, execute non-transactionally if none exists" → `&mut PgConnection` 을 받는 함수에 대응한다. PostgreSQL 은 BEGIN 이 없으면 문장마다 암묵 BEGIN·COMMIT 을 두른다 | [Propagation](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/annotation/Propagation.html), [PG tutorial](https://www.postgresql.org/docs/current/tutorial-transactions.html) | 2026-11-15 | writer | ❌→정정 (Propagation 대응) |
| sqlx 문서에서 선언적 트랜잭션 기능을 찾을 수 없다. `Transaction` 은 commit 없이 drop 하면 rollback 하고 `&mut tx` 는 `&mut PgConnection` 으로 coerce 된다 | [Transaction](https://docs.rs/sqlx/0.9.0/sqlx/struct.Transaction.html) | 2026-11-15 | verify | ✅ verified |
| sqlx 0.9 `query*()` 는 `impl SqlSafeStr` 를 받아 `format!` 으로 만든 String 을 E0277("dynamic SQL strings should be audited for possible injections")로 거부한다. `QueryBuilder::push_bind` 가 `$N` 으로 바인딩한다 | [SqlSafeStr](https://docs.rs/sqlx/0.9.0/sqlx/trait.SqlSafeStr.html), [QueryBuilder](https://docs.rs/sqlx/0.9.0/sqlx/struct.QueryBuilder.html) | 2026-11-15 | writer | ✅ verified + 로컬 expected-fail |
| axum 은 Extension 보다 State 를 권하고(type safe) State 는 요청마다 clone 되므로 Arc 로 감싼다. 0.8 경로 문법은 `/{id}` 이고 옛 `/:id` 는 panic | [axum 0.8.9](https://docs.rs/axum/0.8.9/axum/index.html), [axum CHANGELOG](https://raw.githubusercontent.com/tokio-rs/axum/main/axum/CHANGELOG.md) | 2026-11-15 | verify | ✅ verified |
| config 0.15.27 `Environment` separator 에는 기본값이 없다: `separator.as_deref().unwrap_or("")` 이고 비어 있으면 `.` 으로 바꾸지 않는다. prefix APP 의 `APP_DATABASE_URL` 은 평평한 키 `database_url` 이 된다. 중첩 키는 `separator("__")`, prefix 구분자도 따라가므로 `prefix_separator("_")` | [config env.rs](https://raw.githubusercontent.com/rust-cli/config-rs/v0.15.27/src/env.rs) | 2026-11-15 | writer | ❌→정정 (JR-20 "기본값 '.'") + 로컬 테스트 |
| bon `derive(Builder)` 는 typestate 라 필수 필드 누락이 컴파일 에러다. 모양이 M-INIT-BUILDER 와 달라 프로젝트가 하나를 고른다 | [bon](https://docs.rs/bon/latest/bon/) | 2026-11-15 | verify | ✅ verified |
| M-WEASEL-WORDS: Service·Manager·Factory 는 약한 타입명 접미사다. service 계층 자체는 금지하지 않는다 | [MS universal](https://microsoft.github.io/rust-guidelines/guidelines/universal/index.html) | 2026-11-15 | verify | ✅ verified |
| "Composed Method"·"SLAP" 은 레포 clean-code rule 의 이름으로만 인용한다. lint 수치(threshold 100·4, 20-50줄 PREFER)는 rust.md 의 house rule 이다 | [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) | 2026-11-15 | writer | house rule / ⚠️ 용어 원 출처 미검증 |

## 7. `rust/rust-pg-queue-worker`

컴파일: tested 4 · clippy-clean 9 (claim·finish·`judge_and_finish`·`apply_outcome`·`run_listener`·`run_worker`·`#[sqlx::test]`·scratch 조립·pool) · compiled 2 (sqlx feature 목록, `--features db-tests --test db --no-run`) · expected-fail 5 (u32 바인딩 E0277, `PermanentKind` Debug 누락 E0277, `query!(CONST)` "expected string literal", `()` 반환 컴포넌트를 `JoinSet<anyhow::Result<()>>` 에 spawn 하면 E0308, feature 없이 `--test db`) · not-compiled 7 (SQL 블록·조각 6개는 Postgres·docker 가 없어서, `query_file_as!` 1개는 DATABASE_URL·`.sqlx` 가 없어서). 리뷰 blocking 3→1→0. 사실 62건 중 16건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| SKIP LOCKED 는 바로 잠글 수 없는 행을 건너뛴다. OFFSET 으로 건너뛴 행도 잠긴다. READ COMMITTED 에서 ORDER BY + 잠금은 순서가 어긋날 수 있다 | [PG18 SELECT](https://www.postgresql.org/docs/18/sql-select.html) | 2026-11-15 | verify | ✅ verified |
| MATERIALIZED 는 WITH 쿼리를 따로 계산하게 강제한다. PG18 UPDATE 에는 LIMIT 이 없어 reaper 배치도 claim 과 같은 CTE 형태를 쓴다 | [PG18 WITH](https://www.postgresql.org/docs/18/queries-with.html), [PG18 UPDATE](https://www.postgresql.org/docs/18/sql-update.html) | 2026-11-15 | verify·writer | ✅ verified |
| NOTIFY 는 commit 때만 전달되고, 한 트랜잭션의 같은 채널·payload 는 하나로 합쳐지며, payload 는 8000 bytes 미만, 큐는 8GB 다. LISTEN 은 commit 시점부터 유효하고 연결이 끊긴 동안의 알림은 받지 못한다 | [NOTIFY](https://www.postgresql.org/docs/18/sql-notify.html), [LISTEN](https://www.postgresql.org/docs/18/sql-listen.html) | 2026-11-15 | verify | ✅ verified |
| NOTIFY 를 실행한 트랜잭션의 COMMIT 은 인스턴스 전역 lock 을 잡고 REL_19 async.c 에도 남아 있다. Recall.ai 갱신분의 "commit 282b1cde 가 병목을 제거했다" 는 부정확하다 | [REL_19 async.c](https://raw.githubusercontent.com/postgres/postgres/REL_19_STABLE/src/backend/commands/async.c) | 2026-11-15 | verify | ❌→정정 (PQ-07) |
| PgBouncer transaction pooling 은 LISTEN 은 안 되고 NOTIFY 는 된다. prepared statement 는 `max_prepared_statements` 를 0 이 아닌 값으로 둬야 한다 | [PgBouncer features](https://www.pgbouncer.org/features.html) | 2026-11-15 | verify | ✅ verified |
| sqlx 0.9.0 `PgListener`: `connect` 는 연결 1개짜리 pool(acquire 30s), `recv()` 는 `Ok(None)` 을 삼키고 `try_recv` 는 IO 에러 네 종류에서만 재연결한다. #4485·#4016 수정은 미릴리스 | [listener.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-postgres/src/listener.rs), [#4485](https://github.com/transact-rs/sqlx/pull/4485) | 2026-11-15 | verify·writer | ✅ verified |
| `query!` 는 문자열 리터럴(또는 `+` 연결)만 받아 const 식별자는 "expected string literal" 이다. `include_str!` 은 호출 파일 기준, `query_file!` 은 프로젝트 루트 기준 경로다 | [query!](https://docs.rs/sqlx/0.9.0/sqlx/macro.query.html), [include_str!](https://doc.rust-lang.org/std/macro.include_str.html) | 2026-11-15 | verify·writer | ❌→정정 (PQ-14) + 로컬 expected-fail |
| sqlx 매크로는 offline 이 꺼져 있고 DATABASE_URL 이 비어 있지 않으면 live DB 를, 아니면 `SQLX_OFFLINE_DIR` → crate `.sqlx` → workspace 루트 `.sqlx` 를 쓴다. CI 는 `cargo sqlx prepare --check` | [query/mod.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-macros-core/src/query/mod.rs), [sqlx-cli README](https://raw.githubusercontent.com/launchbadge/sqlx/main/sqlx-cli/README.md) | 2026-11-15 | writer | ✅ verified |
| 재시도할 SQLSTATE: 40001, 40P01, 55P03, 57014, 57P01, 08003, 08006, 53300, 25P03, 25P04. 부록은 재시도 여부를 말하지 않는다. class 22·23 → Permanent(Bug), 42 → Schema 는 이 skill 의 설계 선택이다 | [errcodes](https://www.postgresql.org/docs/18/errcodes-appendix.html) | 2026-11-15 | verify·review | ✅ verified / 분류는 house rule |
| `ON CONFLICT DO UPDATE` 는 원자적이고 unique index 를 추론하지 못하면 에러다. `DO UPDATE … WHERE` 는 "Only rows for which this expression returns true will be updated, although all rows will be locked" | [PG18 INSERT](https://www.postgresql.org/docs/18/sql-insert.html) | 2026-11-15 | verify·review | ✅ verified |
| `power(int,int)` 는 double precision 으로 해석되고 PG18 `dpow` 는 결과가 inf 면 overflow 에러를 낸다 → 지수 상한 `least(attempts, 10)` | [float.c](https://raw.githubusercontent.com/postgres/postgres/REL_18_STABLE/src/backend/utils/adt/float.c), [typeconv-func](https://www.postgresql.org/docs/18/typeconv-func.html) | 2026-11-15 | writer | ✅ verified (SQL 실행 안 함) |
| `transaction_timeout`(PG17+)은 세션을 끝내고 단일 문장에도 걸린다. `idle_in_transaction_session_timeout` 이 그 이하면 무시된다 | [runtime-config-client](https://www.postgresql.org/docs/18/runtime-config-client.html) | 2026-11-15 | verify | ✅ verified |
| PlanetScale 은 PG18 에서 다른 워크로드가 horizon 을 잡고 있으면 SKIP LOCKED 로도 MVCC 저하를 못 막는 것을 재현했다. River RescueStuckJobsAfter 1h, Solid Queue heartbeat 60s·5분 뒤 dead | [PlanetScale](https://planetscale.com/blog/keeping-a-postgres-queue-healthy), [River](https://riverqueue.com/docs/maintenance-services) | 2026-11-15 | verify | ✅ verified |
| metrics-exporter-prometheus 0.18.3 기본 http listener 는 `/health` 에 고정 "OK" 를 주고 나머지 모든 경로에 메트릭을 준다 | [http_listener.rs](https://docs.rs/crate/metrics-exporter-prometheus/0.18.3/source/src/exporter/http_listener.rs) | 2026-11-15 | writer | ❌→정정 (PQ-26 "모든 경로") |
| apalis-postgres·graphile_worker 는 sqlx ^0.9, pgmq 0.33.x 는 ^0.8(0.34 alpha 는 ^0.9), sqlxmq·underway 는 0.8. pgmq 는 확장 또는 SQL-only 로 설치하고 Rust 클라이언트가 설치할 수도 있다 | [apalis-postgres](https://crates.io/api/v1/crates/apalis-postgres), [pgmq README](https://github.com/pgmq/pgmq/blob/main/pgmq-extension/README.md) | 2026-11-15 | verify·writer | ✅ verified / pgmq 설치 형태는 ❌→정정 (PQ-25) |
| 컴포넌트는 `anyhow::Result<()>` 를 돌려 rust-async-tokio §4 의 `JoinSet` 에 들어간다. db 테스트는 `[[test]] required-features = ["db-tests"]`. backoff 2^n 초(상한 600), MAX_ERROR_CHARS 500, `max_connections`(concurrency+2) 는 예시 설계값이다 | [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) | 2026-11-15 | review | house rule |

## 8. `rust/rust-og-image-render`

컴파일: tested 16 (scratch 전용 검사·probe 6건 포함) · expected-fail 1 (`png = "0.17"` 직접 의존 → tiny-skia 의 png 0.18.1 과 두 벌 빌드돼 `?` 에서 E0277) · not-compiled 1 (ASCII 결정 트리). 렌더 시간·메모리·슬롯 수는 재지 않았다. 리뷰 blocking 3→1→1→0. 사실 54건 중 14건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| resvg/usvg 0.50.0: MSRV 1.85, `Options::max_depth`(기본 1024) 추가, Group·Node `bounding_box` 가 Option. clip path·mask·pattern·marker·feImage 순환 참조를 거부하고 순환 xlink:href 에서 멈추지 않는다 | [resvg CHANGELOG](https://raw.githubusercontent.com/linebender/resvg/main/CHANGELOG.md) | 2026-11-15 | verify·writer | ✅ verified |
| resvg 기본 feature 는 svgz·text·system-fonts·memmap-fonts·raster-images 다. 래스터 이미지와 CBDT·sbix 이모지는 `raster-images` 아래에 있다. `features=["text"]` 만이면 sbix 이모지가 칠한 픽셀 0, 켜면 3,341 | [resvg 0.50.0](https://crates.io/api/v1/crates/resvg/0.50.0), [image.rs](https://raw.githubusercontent.com/linebender/resvg/main/crates/resvg/src/image.rs) | 2026-11-15 | verify·writer | ✅ verified + 로컬 실측 |
| `Options::default()` 의 fontdb 는 비어 있고 font_family 는 Times New Roman 이다. system-fonts feature 만으로는 결과가 같고 `load_system_fonts()` 를 부를 때 dev 와 prod 가 갈린다 | [options.rs](https://raw.githubusercontent.com/linebender/resvg/main/crates/usvg/src/parser/options.rs) | 2026-11-15 | verify | ❌→정정 (R-04 보정) |
| `ImageHrefResolver` 기본 구현은 로컬 파일 접근을 허용한다(usvg 는 네트워크 요청을 하지 않는다). 기본 data resolver 는 SVG data URL 을 중첩 트리로 파싱하므로 PNG·JPEG 만 받는 resolver 로 막는다 | [ImageHrefResolver](https://docs.rs/usvg/0.50.0/usvg/struct.ImageHrefResolver.html) | 2026-11-15 | verify·writer | ✅ verified + 로컬 테스트 |
| fontdb 0.24.0 은 magic 이 TrueType·`OTTO`·`ttcf` 가 아니면 face 를 건너뛴다 → woff·woff2 는 읽지 않는다 | [fontdb ttf_parser](https://docs.rs/crate/fontdb/0.24.0/source/src/ttf_parser/mod.rs) | 2026-11-15 | writer | ❌→정정 |
| NotoSansCJKkr-Bold.otf(16,997,996 bytes, family "Noto Sans CJK KR")는 U+AC00–U+D7A3 cmap 누락이 0 이다 | [noto-cjk Korean](https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/Korean) | 2026-11-15 | writer | ✅ 로컬 실측 |
| `png::EncodingError` 는 re-export 되지 않아 png 0.18 을 직접 의존한다. 버전이 tiny-skia 0.12 의 png 와 다르면 두 벌 빌드돼 `encode_png()?` 가 E0277 | [pixmap.rs](https://raw.githubusercontent.com/linebender/tiny-skia/main/src/pixmap.rs) | 2026-11-15 | verify·writer | ✅ verified + 로컬 expected-fail |
| resvg 는 SVG2 `inline-size`·`white-space`·`text-overflow`·`line-height`·`text-align` 과 bidi 를 구현하지 않는다 → 줄바꿈은 직접 한다 | [unsupported.md](https://raw.githubusercontent.com/linebender/resvg/main/docs/unsupported.md) | 2026-11-15 | verify | ✅ verified |
| XML 1.0 Char 프로덕션 밖 문자(U+FFFE 등)가 들어가면 usvg 파싱이 실패하고, `char::is_control` 은 U+FFFE·U+FFFF 를 통과시킨다 | [XML 1.0](https://www.w3.org/TR/xml/) | 2026-11-15 | verify·writer | ✅ verified + 로컬 테스트 |
| UAX #14 는 한글 음절 사이를 기본 줄바꿈 후보로 본다(keep-all 은 Hangul 을 AL 로 tailoring). cosmic-text 0.19.0 `Wrap::Word` 는 기본 규칙이라 keep-all 이 없고, usvg 와 fontdb·harfrust·skrifa 버전이 달라 두 벌 링크된다 | [UAX #14](https://www.unicode.org/reports/tr14/), [cosmic-text deps](https://crates.io/api/v1/crates/cosmic-text/0.19.0/dependencies) | 2026-11-15 | verify | ✅ verified |
| Pretendard·Noto CJK 는 OFL 1.1 이다. 번들할 수 있고 생성물에는 의무가 없다. 사본마다 고지·LICENSE(조건 2), 수정판은 RFN 사용 불가(조건 3). Pretendard RFN 은 Pretendard·Source·Inter·M PLUS 1 | [Noto CJK LICENSE](https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE) | 2026-11-15 | verify·writer | ✅ verified |
| axum 은 서비스가 늘 ready 라고 가정해 backpressure middleware 를 피하라고 하고, tower 0.5.3 `ConcurrencyLimit` 은 `poll_ready` 에서 기다린다. timeout 으로 future 가 drop 되면 permit 은 풀리지만 spawn_blocking 렌더는 계속 돈다 | [axum middleware.md](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/axum/src/docs/middleware.md), [tower future.rs](https://raw.githubusercontent.com/tower-rs/tower/tower-0.5.3/tower/src/limit/concurrency/future.rs) | 2026-11-15 | verify·writer | ✅ verified + 로컬 테스트 |
| RFC 9110: If-None-Match 가 거짓이면 GET/HEAD 는 304, 그 밖의 메서드는 412 → 내부 POST 렌더 API 에 ETag/304 는 위반이다. Meta 는 1200x630 이상·1.91:1·8MB 이하·"Use a new URL for the new image" | [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.txt), [Meta](https://developers.facebook.com/docs/sharing/webmasters/images/) | 2026-11-15 | verify | ✅ verified |
| 카카오(포럼 운영진 답변, 공식 문서 아님): JPG/PNG 만, 800x400(2:1), smart crop, 80/443 포트, 썸네일 캐시는 이미지 URL 기준 | [Kakao devtalk](https://devtalk.kakao.com/t/scrap-url/116202) | 2026-11-15 | verify | ✅ verified (포럼 답변) |
| crates_io_og_image 0.3.1 게시판은 typst ^0.14.2 에 의존한다(0.15.1 은 미게시 main). OWASP Top 10:2025 에서 SSRF(CWE-918)는 A01 에 매핑되고 A10 은 "Mishandling of Exceptional Conditions" 다(레포 `/security:owasp-top10` 은 2021 판) | [crates_io_og_image deps](https://crates.io/api/v1/crates/crates_io_og_image/0.3.1/dependencies), [OWASP A01:2025](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/) | 2026-11-15 | verify·writer | ❌→정정 (R-14) / OWASP ✅ |

## 9. `rust/rust-crdt-sync`

컴파일: tested 15 (actor 테스트와 실제 upgrade 를 거치는 WS e2e 4건 포함. 클라이언트 tokio-tungstenite 는 scratch dev-dependency) · compiled 1 (crate 별 의존성 산문) · expected-fail 2 (`sync` feature 없는 `Awareness` 를 `tokio::spawn` → E0277, `Rc<Cell<u64>>` 클로저를 `with_clock` 에 → E0277) · not-compiled 1 (§6 SQL, Postgres·docker 없음). 리뷰 blocking 7→2→0. 사실 66건 중 16건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| yrs 는 Yjs 와 동작·binary protocol 호환이 목표다. breaking 은 0.28.0(Subscription 제거, key 를 받는 subscribe, Any::Int/Float → Number) | [yrs](https://crates.io/api/v1/crates/yrs), [y-crdt releases](https://github.com/y-crdt/y-crdt/releases) | 2026-11-15 | verify | ✅ verified |
| `Protocol` 의 handle 계열은 `&mut Awareness` 를 받고 `Result` 를 돌려준다(`start` 만 `&Awareness`). `handle()` 은 첫 에러에서 `?` 로 반환해 앞 reply 까지 버리고 role·peer 를 모른다 | [Protocol](https://docs.rs/yrs/0.28.1/yrs/sync/protocol/trait.Protocol.html), [protocol.rs](https://docs.rs/crate/yrs/0.28.1/source/src/sync/protocol.rs) | 2026-11-15 | verify·writer | ❌→정정 (AR-27) |
| `Awareness` 는 sync feature 없이는 Send/Sync 가 아니다. `Awareness::new` 는 SystemClock 을 쓰고, `Clock` blanket impl 이 `Fn() -> Timestamp + Send + Sync` 라 `with_clock` 으로 주입한다 | [Awareness](https://docs.rs/yrs/0.28.1/yrs/sync/awareness/struct.Awareness.html), [Clock](https://docs.rs/yrs/0.28.1/yrs/sync/time/trait.Clock.html) | 2026-11-15 | verify·writer | ✅ verified + 로컬 expected-fail |
| yrs Awareness 에는 만료 타이머가 없다(`iter`·`meta`·`remove_state` 로 직접). `AwarenessUpdate.clients` 는 std HashMap 이라 여러 항목 update 의 바이트 순서가 실행마다 다를 수 있다 | [awareness.rs v0.28.1](https://raw.githubusercontent.com/y-crdt/y-crdt/v0.28.1/yrs/src/sync/awareness.rs) | 2026-11-15 | verify·writer | ❌→정정 (CR-04 "만 있다") / 바이트 순서는 소스 판단 |
| awareness 규칙: clock 이 엄밀히 클 때만 적용, 30초 갱신이 없으면 제거(MUST), 적어도 15초마다 재전송(SHOULD), 신원은 상위 계층이 강제(MUST). 이 문구는 2026-05-05 커밋 73b2ff7 개정판에만 있고 v1.0.7 태그 문서에는 없다 | [PROTOCOL.md @73b2ff7](https://raw.githubusercontent.com/yjs/y-protocols/73b2ff75486c9879843718dc6c7fc52d63aea4fe/PROTOCOL.md) | 2026-11-15 | writer | ✅ verified (커밋 고정) |
| read-only 판정은 메시지 앞 2바이트(00 00 허용, 00 01·00 02 거부)로, frame 이 아니라 메시지마다 한다. viewer 도 SyncStep1 에 SyncStep2 로 답한다 | [PROTOCOL.md @73b2ff7](https://raw.githubusercontent.com/yjs/y-protocols/73b2ff75486c9879843718dc6c7fc52d63aea4fe/PROTOCOL.md) | 2026-11-15 | verify·writer | ✅ verified + 로컬 테스트 |
| 사양 개정판은 클라이언트가 SyncStep1 로 시작한다고 쓰지만(server SHOULD NOT initiate) yrs `DefaultProtocol::start` 와 @y/websocket-server 0.1.5 는 서버가 먼저 보낸다 | [@y/websocket-server utils.js](https://unpkg.com/@y/websocket-server@0.1.5/src/utils.js) | 2026-11-15 | verify·writer | ✅ verified (사양·구현 불일치 병기) |
| `transact` 는 read_blocking, `transact_mut` 은 write_blocking 이다. 같은 스레드에서 같은 Doc 에 중첩할 때 하나라도 쓰기면 self-deadlock 이고 읽기 안 읽기는 열린다. `get_or_insert_text` 는 안에서 `transact_mut` 를 연다 | [Transact](https://docs.rs/yrs/0.28.1/yrs/trait.Transact.html) | 2026-11-15 | verify·writer | ❌→정정 (CR-06) |
| `Options::offset_kind` 기본값은 Bytes 이고 직렬화는 Utf16 을 0 으로 쓴다("0 for compatibility with Yjs"). client_id 가 겹치면 문서 상태가 손상된다 | [doc.rs](https://docs.rs/crate/yrs/0.28.1/source/src/doc.rs), [Options](https://docs.rs/yrs/0.28.1/yrs/doc/struct.Options.html) | 2026-11-15 | verify·writer | ❌→정정 (CR-08) / JS 가 UTF-16 이라는 점은 ⚠️ 추론 |
| yrs-warp 0.9·yrs-axum 0.8·y-sweet-core 0.9 는 yrs ^0.24·^0.18·^0.19 에 묶여 있고 yrs-warp sink 루프는 Lagged 에서 끝난다 | [yrs-warp deps](https://crates.io/api/v1/crates/yrs-warp/0.9.0/dependencies) | 2026-11-15 | verify | ✅ verified |
| axum extractor 는 인자 순서대로 돈다. `Grant` 를 `WebSocketUpgrade` 앞에 두면 토큰 없는 요청이 401, 뒤집으면 400. 브라우저 `WebSocket` 생성자에는 헤더 인자가 없다 | [axum extractor order](https://docs.rs/axum/0.8.9/axum/extract/index.html#the-order-of-extractors), [MDN WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket/WebSocket) | 2026-11-15 | writer | ✅ verified + 로컬 테스트 |
| futures-util `split` 의 두 반쪽은 BiLock 으로 같은 stream 을 공유해 한쪽만 drop 해도 socket 이 닫히지 않는다. axum `WebSocket::recv`·`send` 는 상태를 self 가 들고 있어 한 `select!` 에서 써도 메시지를 잃지 않는다 | [split.rs](https://docs.rs/crate/futures-util/0.3.34/source/src/stream/stream/split.rs), [axum ws.rs](https://docs.rs/crate/axum/0.8.9/source/src/extract/ws.rs) | 2026-11-15 | writer | ✅ verified + 로컬 mutation |
| axum WS 기본값은 max_message 64MB, max_frame 16MB, max_write_buffer 무제한이다. RFC 6455 §10.2: 특정 사이트용 서버는 Origin 을 검증하고 403 으로 답해야 한다(SHOULD) | [WebSocketUpgrade](https://docs.rs/axum/0.8.9/axum/extract/ws/struct.WebSocketUpgrade.html), [RFC 6455](https://www.rfc-editor.org/rfc/rfc6455.txt) | 2026-11-15 | verify·writer | ✅ verified |
| Figma: "Figma isn't using true CRDTs though", 서버 권위·LWW·문서마다 worker 하나. Notion 은 LWW 에서 RGA + Peritext 로 옮겼고 라이브러리는 밝히지 않았다 | [Figma](https://www.figma.com/blog/how-figmas-multiplayer-technology-works/), [Notion](https://www.notion.com/blog/how-notion-handles-concurrent-editing-with-crdts) | 2026-11-15 | verify | ✅ verified |
| Automerge 3.0 은 메모리를 "over 10x" 줄였다(Rust native 수치는 없음). Loro 는 1.0 부터 데이터 형식이 안정이고 loro-websocket-server 는 개발·테스트용이다. crdt-benchmarks 는 JS/WASM 측정이라 Rust native 성능 근거가 아니다 | [Automerge 3](https://automerge.org/blog/automerge-3/), [Loro](https://www.loro.dev/llms-full.txt), [crdt-benchmarks](https://raw.githubusercontent.com/dmonad/crdt-benchmarks/main/README.md) | 2026-11-15 | verify | ❌→정정 (CR-17 "JS 측정" 표기 삭제) |
| npm y-websocket latest 3.1.0, y-protocols 1.0.7, yjs latest 13.6.33(14.0.0 은 beta). yrs `small-client` 는 v0.26 이하·yjs pre v14 호환용 32-bit ClientID 다 | [npm y-websocket](https://registry.npmjs.org/y-websocket), [yrs docs](https://docs.rs/yrs/0.28.1/yrs/index.html) | 2026-11-15 | verify·writer | ✅ verified / Yjs 13.x 에 필요한지는 ⚠️ |

## 10. `rust/rust-geo-track`

컴파일: tested 14 (`cargo test` 38/38, 전체 블록 `cargo fmt --check`·house lint 재확인 1건 포함) · compiled 1 (Cargo.toml 의존성: geo 0.33.1·rstar 0.12.2 한 벌, `cargo tree -d` 출력 없음) · expected-fail 6 (deprecated `haversine_distance` + `deprecated = "deny"`, `Haversine.distance(&line, &p)` E0308, private 생성자 E0603, 좌표계 혼용 E0308, `Kernel` 미import E0599, private 필드 struct literal E0451). 실제 GPS fixture 는 돌리지 않았다. 리뷰 blocking 4→2→0. 사실 45건 중 15건 수록.

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| geo 0.33.1 은 MSRV 1.88, rstar ^0.12, geographiclib-rs ^0.2.3. 미릴리스 CHANGES 는 rstar 0.14·MSRV 1.90·Simplify 연관 타입 변경을 예고한다 | [geo 0.33.1 deps](https://crates.io/api/v1/crates/geo/0.33.1/dependencies) | 2026-11-15 | verify | ✅ verified |
| geo 0.29 에서 `HaversineDistance`·`EuclideanDistance`·옛 `FrechetDistance`·`haversine_length`·`LineInterpolatePoint` 가 deprecated 됐다. `[lints.rust] deprecated = "deny"` 면 일반 build 도 에러, 없으면 `cargo clippy -- -D warnings` 에서만 에러 | [HaversineDistance](https://docs.rs/geo/0.33.1/geo/algorithm/haversine_distance/trait.HaversineDistance.html) | 2026-11-15 | verify·writer | ✅ verified + 로컬 실측 |
| `Haversine` 평균 반지름 6371.0088 km, `Geodesic` 은 Karney·f64 전용이고 둘 다 Point→Point 만 지원한다. `Euclidean` 은 비-Point 를 참조로 받는다. geo `Geodesic` 은 geographiclib-rs `Geodesic::wgs84` 위에 있어 둘을 비교하면 같은 구현 비교다 | [Euclidean](https://docs.rs/geo/0.33.1/geo/algorithm/line_measures/metric_spaces/struct.Euclidean.html), [geodesic.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/line_measures/metric_spaces/geodesic.rs) | 2026-11-15 | verify·writer | ❌→정정 (GEO-03) |
| 구면 모델 오차는 보통 0.3% 이하, 최대 0.55% 이고 haversine 은 짧은 거리에서 수치적으로 안정하다 | [movable-type](https://www.movable-type.co.uk/scripts/latlong.html) | 2026-11-15 | verify | ✅ verified |
| `LineLocatePoint` 는 평면 계산이고 전역 최근접 segment 를 고르며 동점이면 앞 segment, 비유한 입력이면 None. `CrossTrackDistance` 는 무한 대원까지라 끝점에서 clamp 하지 않고, 0.33 의 `haversine_closest_point` 에는 고위도 버그 #1325(main 에서만 수정)가 있다 | [line_locate_point.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/line_locate_point.rs), [cross_track_distance.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/cross_track_distance.rs) | 2026-11-15 | verify | ✅ verified |
| `line_intersection` 은 `SinglePoint{intersection,is_proper}` 또는 `Collinear`. `Kernel::orient2d` 는 연관 함수라 trait 를 import 하지 않으면 E0599. `RobustKernel` 은 NaN 을 Collinear 로 돌려준다 | [LineIntersection](https://docs.rs/geo/0.33.1/geo/algorithm/line_intersection/enum.LineIntersection.html), [robust.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/kernels/robust.rs) | 2026-11-15 | verify·writer | ✅ verified + 로컬 expected-fail |
| `Densify` 는 spacing ≤ 0·NaN 이면 assert panic, segment 수가 u64 를 넘으면 expect panic → `CorridorParams` 는 private 필드 + fallible `new()` | [densify.rs](https://raw.githubusercontent.com/georust/geo/geo-0.33.1/geo/src/algorithm/line_measures/densify.rs) | 2026-11-15 | verify·writer | ✅ verified + 로컬 테스트 |
| rstar 0.13.0 에 bulk_load 회귀가 있고 0.13.1 이 수정을 backport 했다. 배포된 0.14.0 에는 `bulk_load_parallel`·rayon feature 가 없다. geo-types 0.7.20 의 rstar feature 는 0_8~0_13 이라 geo 타입은 rstar 0.14 RTree 에 못 넣는다 | [rstar](https://crates.io/api/v1/crates/rstar), [geo-types 0.7.20](https://crates.io/api/v1/crates/geo-types/0.7.20) | 2026-11-15 | verify | ❌→정정 (GEO-12) |
| Strava 특허 US9116922B2 는 Active, 예상 만료 2031-03-31 이다. 청구 범위는 해석하지 않았다 | [Google Patents](https://patents.google.com/patent/US9116922B2/en) | 2026-11-15 | verify | ✅ verified / 범위는 ⚠️ 법무 검토 |
| Strava 는 segment 시작·끝에 가장 가까운 GPS 점으로 매칭하고 1초 기록을 권한다. GPS drift 나 중간 "Gap Threshold" 초과로 매칭이 실패할 수 있고, 그 기준이 시간인지 거리인지는 밝히지 않는다 | [Strava support](https://support.strava.com/en-us/articles/15401957-segment-matching-issues) | 2026-11-15 | verify·writer | ❌→정정 (Gap Threshold 서술 완화) |
| 스마트폰 GPS 정확도는 개방 하늘에서 약 4.9 m(gps.gov archive, 원 출처 ION.org). Newson & Krumm 은 차량 데이터에서 σ = 4.07 m | [gps.gov archive](https://archive.gps.gov/systems/gps/performance/accuracy/), [Newson & Krumm](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/12/map-matching-ACM-GIS-camera-ready.pdf) | 2026-11-15 | verify | ✅ verified |
| Android `isMock()` 은 API 31+, `isFromMockProvider` 는 deprecated, `getAccuracy` 는 68% 반경이다. iOS 는 `isSimulatedBySoftware`(15+)·`isProducedByAccessory` | [Android Location](https://developer.android.com/reference/android/location/Location) | 2026-11-15 | verify | ✅ verified |
| gpx 0.10.0 은 thiserror 1.x 에 의존해 thiserror 2 와 두 벌이 된다. fitparser 0.12.0 은 위경도를 SInt32 semicircle 로 돌려주고 degrees = semicircles × 180/2^31 | [gpx](https://crates.io/api/v1/crates/gpx), [fitparser decode.rs](https://docs.rs/crate/fitparser/0.12.0/source/src/profile/decode.rs) | 2026-11-15 | verify·writer | ✅ verified / Garmin 공식 문서는 ⚠️ |
| 12.32 m/s 는 Bolt 의 9.58 s 세계 기록 레이스(베를린 2009) 레이저 측정 최고 속도다(Štuhec 외 2023). 위도 37° 의 경도 1° 88,804 m·위도 1° 111,195 m(R = 6371.0088 km 구)는 scratch 계산값이다 | [Europe PMC](https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=PMCID:PMC10669785&format=json&resultType=core) | 2026-11-15 | verify·writer | ❌→정정 (GEO-26 출처 교체, 37° 수치는 현장 측정 아님) |
| 판정 경로는 lon/lat 거리에 Haversine, 투영 평면에 Euclidean 을 쓴다. 종목별 가속도 한계는 검증된 수치가 없어 fixture 로 정한다. `gps_slack_m` ≈ 2ε. 출력이 바뀌는 규칙 변경은 ENGINE_VERSION, 임계값은 Params 위치에 따라 정한다 | [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) | 2026-11-15 | writer·review | house rule / ⚠️ 설계 제안 (팀 합의) |

## 11. rule `rust.md`

컴파일: tested 2 (Composed Method BAD·GOOD, `cargo test` 4건 통과, house lint 로 clippy 통과). 나머지는 산문 bullet 이라 §1~§6 사실에 기댄다. 리뷰 blocking 3→1→0. 사실 62건 중 6건 수록(54건은 §1~§6 과 같은 사실, 나머지 2건은 house rule 목록과 중복).

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| `lint_groups_priority` 는 그룹과 개별 lint 의 level 이 다를 때만 난다: pedantic=warn + too_many_lines=warn 은 출력이 없고, pedantic=warn + missing_errors_doc=allow 는 에러 | [lint_groups_priority.rs](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/cargo/lint_groups_priority.rs) | 2026-11-15 | writer | ✅ verified + 로컬 실측 |
| clippy CHANGELOG "## Rust 1.100": "`allow-unwrap-in-tests` now also applies to integration tests"(#16786). 구현은 입력 경로가 "tests" 로 시작하는지만 보는데, workspace root 에서 `cargo check -v` 를 돌리면 member 입력 경로가 `app/tests/it.rs` 로 넘어간다 | [clippy CHANGELOG](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/CHANGELOG.md) | 2026-11-15 | writer | ✅ verified / member 적용은 ⚠️ 미측정 |
| M-FROM-ERROR: 소유한 에러는 `impl From` + `?` 로 바꾸고, 호출부마다 `map_err` 를 반복하는 것은 Bad | [MS M-FROM-ERROR](https://microsoft.github.io/rust-guidelines/guidelines/libs/ux/index.html#M-FROM-ERROR) | 2026-11-15 | verify | ✅ verified |
| GOOD 예시의 `repo.insert` 에러는 `#[from]` 을 거쳐 `SignupError::Db`(Display "database error" → 500)가 된다. 동시 가입 경합에서 진 요청은 409 가 아니라 500 이고, 이 분류는 rust-error-handling 의 `nickname_conflict` 가 맡는다 | 로컬 scratch 테스트 | 2026-11-15 | writer | ✅ 로컬 실측 |
| TaskTracker 는 끝난 task 를 바로 지우고 return value 를 보관하지 않는다("Comparison to JoinSet"). spawn 이 준 JoinHandle 로는 결과를 확인할 수 있다 | [TaskTracker](https://docs.rs/tokio-util/latest/tokio_util/task/task_tracker/struct.TaskTracker.html) | 2026-11-15 | writer | ❌→정정 (AC-10 "결과를 버린다") |
| CPU 오프로드는 "CPU 전용 Semaphore 를 건 spawn_blocking 으로 시작하고 측정 후 rayon" 순서다. tokio 문서는 둘 다 제시하므로 이 순서는 형제 skill 에 맞춘 설계 선택이다. 그 밖에 함수 20-50줄 PREFER, threshold 100·4, 400줄 분할 검토, DI ladder, core/shell workspace, release `panic = "unwind"` | [spawn_blocking](https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html), [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) | 2026-11-15 | writer·review | house rule |

## 12. commands `/rust:review`·`/rust:lint`·`/rust:refactor`·`/rust:test-gen`

컴파일: tested 8 · clippy-clean 1 · expected-fail 7 (Troubleshooting 재현 묶음 — `unused manifest key`·`lint_groups_priority`·unknown lint·`--fix` dirty tree 등, VCS 없음, 자체 clippy.toml 을 둔 member 가 루트 threshold 를 잃음, `undocumented_unsafe_blocks`, `await_holding_lock` 이 `-D warnings` 를 깸, future not Send·E0502·E0624·E0761·edition 2021 let chains, binary-only crate E0432/E0433) · not-compiled 3 (`cargo sqlx prepare` — sqlx-cli·Postgres 없음, refactor 텍스트 결정 트리, `cargo insta review` — 미설치). 리뷰 blocking 3→0. 사실 55건 중 7건 수록(나머지는 §1~§6 과 같은 사실).

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| `cargo clippy --fix` 는 `--no-deps`·`--all-targets` 를 함축한다. dirty tree(untracked 포함)면 "has uncommitted changes … pass --allow-dirty", VCS 밖이면 "no VCS found for this package … pass --allow-no-vcs". fmt 를 먼저 돌리면 그 변경 때문에 `--fix` 가 거부된다 | 로컬 `cargo clippy --help` + probe | 2026-11-15 | writer | ✅ 로컬 실측 (clippy 0.1.96) |
| `--fix` 는 제안을 한 번만 적용해서 고친 뒤 새 경고가 남을 수 있다(needless_return 을 고치자 let_and_return 이 남음) | 로컬 probe | 2026-11-15 | writer | ✅ 로컬 실측 |
| `inline_modules` 는 1.97+ restriction 이고 1.96 에서는 "warning[E0602]: unknown lint" 다 | [module_style.rs](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/module_style.rs) | 2026-11-15 | verify·writer | ✅ verified (1.97 동작은 미측정) |
| rustfmt `imports_granularity`·`group_imports` 는 unstable 이라 stable 에서 경고가 난다 | [Configurations.md](https://raw.githubusercontent.com/rust-lang/rustfmt/main/Configurations.md) | 2026-11-15 | verify | ✅ verified |
| tracing-subscriber 0.3.23 JSON formatter 는 `Visit::record_error` 를 덮어쓰지 않아 최상위 Display 만 기록한다 → 원인 체인은 `error_chain` 문자열로 남긴다 | 로컬 registry 소스(tracing-subscriber 0.3.23 json.rs, tracing-core 0.1.36 field.rs) | 2026-11-15 | writer | ✅ 소스 판독 + 로컬 테스트 |
| `clippy::await_holding_lock` 은 suspicious(기본 warn)라 `-D warnings` 에서 빌드를 깬다 → `/rust:review` 예시는 [Blocker] | [await_holding_invalid.rs](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/await_holding_invalid.rs) | 2026-11-15 | writer | ✅ verified + 로컬 실측 |
| 심각도는 code-review rule(Blocker = 빌드 깨짐)을 따른다. 구현 하나뿐인 trait 금지에는 fake 가 필요한 좁은 경계(DB·외부 API·시계) 예외가 있다. `/rust:lint` 는 `--fix` 일 때만 파일을 고치고 커밋·stash·`--allow-dirty` 는 승인 없이 하지 않는다 | [code-review.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/code-review.md) | 2026-11-15 | writer | house rule |

## 13. agent `rust:rust-reviewer`

컴파일: tested 15 (Grep 정규식 probe 3건, `tests/common.rs` 의 "running 0 tests" 포함) · compiled 1 (code-reviewer `### Rust` 블록 전체) · expected-fail 7 (bin 전용 crate E0432, `Rc`·`Arc<RefCell>`·`RefMut`·std `MutexGuard` 를 `.await` 너머 보유 → not Send 4건, `await_holding_lock`, E0038) · not-compiled 5 (cargo 명령 블록, Glob 패턴 — 이 세션에 Glob 도구 없음, 출력 템플릿, 예시 출력, Automated Checks 명령). agent 를 end-to-end 로 돌리지는 않았다. 리뷰 blocking 3→0. 사실 59건 중 7건 수록(나머지는 §1~§10 과 같은 사실).

| 사실 | URL | 검증일 | 검증자 | 상태 |
|---|---|---|---|---|
| `RefCell<T>` 는 T: Send 면 Send 이고 Sync 는 아니다. RefCell 을 소유만 하는 future 는 spawn 할 수 있고, `Arc<RefCell<_>>`·`Rc`·`RefMut` guard 를 `.await` 너머 들고 가면 spawn 이 실패한다 | [RefCell](https://doc.rust-lang.org/std/cell/struct.RefCell.html) | 2026-11-15 | writer | ❌→정정 + 로컬 실측 |
| `lint_groups_priority` 는 rustc 작업 디렉토리의 Cargo.toml 하나를 읽어 루트 `[workspace.lints]` 는 잡고 멤버가 따로 둔 `[lints]` 는 검사하지 않는다(1.96) | [lint_groups_priority.rs](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/clippy_lints/src/cargo/lint_groups_priority.rs) | 2026-11-15 | writer | ❌→정정 (V-20 문구 구체화) + 로컬 실측 |
| `#[sqlx::test]` 는 성공한 테스트의 DB 만 지우고 실패한 테스트의 DB 는 남긴다. DATABASE_URL 은 Postgres·MySQL 에만 필요하다 | [sqlx::test](https://docs.rs/sqlx/0.9.0/sqlx/attr.test.html) | 2026-11-15 | writer | ❌→정정 ("만들고 지운다") |
| `--locked` 는 Cargo.lock 이 없거나 바뀌어야 할 때 에러를 낼 뿐 네트워크는 막지 않는다(`--offline`, 둘 다는 `--frozen`). build.rs·proc-macro 는 컴파일 중 실행되므로 신뢰할 수 없는 코드에서 cargo 를 돌리지 않는다 | [cargo-check](https://doc.rust-lang.org/cargo/commands/cargo-check.html), [procedural-macros](https://doc.rust-lang.org/reference/procedural-macros.html) | 2026-11-15 | writer | ✅ verified |
| `catch_unwind` 는 일반 try/catch 용도가 아니고 abort 하는 panic 은 잡지 못한다. tower-http `CatchPanicLayer` 기본은 500 이고 안에서 catch_unwind 를 쓴다 | [catch_unwind](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html), [catch_panic.rs](https://raw.githubusercontent.com/tower-rs/tower-http/tower-http-0.7.1/tower-http/src/catch_panic.rs) | 2026-11-15 | writer | ✅ verified (`panic = "abort"` 에서 무력하다는 것은 추론) |
| Cargo.toml 에 edition 이 없으면 2015 로 본다. edition 2024 에서 `std::env::set_var`·`remove_var` 는 unsafe 다 | [manifest](https://doc.rust-lang.org/cargo/reference/manifest.html), [edition guide](https://doc.rust-lang.org/edition-guide/rust-2024/newly-unsafe-functions.html) | 2026-11-15 | writer | ✅ verified |
| plugin agent 는 permissionMode·hooks·mcpServers·initialPrompt 를 무시한다. plugin skill 을 `skills:` frontmatter 에 적는 이름 형식은 문서에 없어 쓰지 않았다 | [plugin components](https://code.claude.com/docs/en/plugins/components), [sub-agents](https://code.claude.com/docs/en/sub-agents) | 2026-11-15 | writer | ✅ verified / 이름 형식 ⚠️ 문서에 없음 |

## 검증하지 못한 것

| 항목 | 상태 | 이유 | 다음 행동 |
|---|---|---|---|
| SQL 전부(pg-queue-worker 의 DDL·claim·finish·upsert·reaper·heartbeat, Go enqueue, crdt-sync 의 소유 획득·fence CTE)와 LISTEN/NOTIFY 런타임 | ⚠️ 실행 안 함 | 로컬 Postgres·docker daemon 없음 | Postgres 18 에서 `DATABASE_URL=… cargo test --features db-tests --test db` |
| `#[sqlx::test]`·testcontainers 테스트, from-spring DB 예시(`build_app`·`register`·`create_user`), error-handling `nickname_conflict` 의 `constraint()` 매칭 | ⚠️ 컴파일·clippy 만 | 같음. 실행하면 DATABASE_URL·docker.sock 에서 실패 | 같음 |
| `query_file_as!`·`query!` 와 `"col!"` override, `cargo sqlx prepare --check` | ⚠️ 컴파일 안 함 | DATABASE_URL·`.sqlx` 없음, sqlx-cli 미설치 | DB 연결 뒤 `cargo sqlx prepare --workspace` |
| 1.97+ 동작: `inline_modules`, `collapsible_match` guard 제안 축소(1.97), Cargo 1.99 하이픈 lint 이름 경고, `allow-unwrap-in-tests` 통합 테스트 확장(1.100), 잘못된 disallowed 경로·멤버 lint override·RTN 의 1.97~1.100 동작 | ⚠️ 미측정 | 로컬 toolchain 1.96, 1.100 미설치. rust-idioms 본문은 항목마다 버전과 "미측정" 을 붙였다 | toolchain 1.100 으로 scratch crate 재실행 |
| 1.100 `allow-unwrap-in-tests` 가 workspace member `crates/<x>/tests/` helper 에도 적용되는가 | ⚠️ | 구현은 입력 경로 접두어만 보고 member 경로는 `app/tests/…` 로 넘어간다(소스 추론) | 1.100 에서 member 하나로 측정. 그 전까지 helper 는 expect |
| `excessive-nesting-threshold = 4` 의 적정성 | ⚠️ house rule 시작값 | 공식 권장치 없음, 엔진 코드 없음 | 첫 엔진 코드에서 경고 수를 세고 조정(D5) |
| libm 아키텍처 간 bit-exact (AR-18) | ⚠️ | 문서에 보장 없음 | x86_64·aarch64 golden 비교 |
| ENGINE_VERSION 을 올리는 규칙과 Params 위치에 따른 결과 키 (A4) | ⚠️ 설계 제안 | 업계 출처 없음 | 팀 합의 + version_lock 테스트 |
| `IN (SELECT … LIMIT … FOR UPDATE SKIP LOCKED)` 가 LIMIT 보다 많이 잠근다는 주장 | ⚠️ | 공식 문서에서 찾지 못함 | MATERIALIZED CTE 로 회피, 주장은 인용하지 않음 |
| PgListener `recv`·`try_recv` 의 cancel safety | ⚠️ | 문서·소스에 언급 없음 | 전용 task + mpsc(1) 구조로 이 성질에 기대지 않음 |
| FIT semicircle 변환식의 Garmin 1차 문서, Strava 특허 청구 범위, Gap Threshold 기준(시간·거리) | ⚠️ | developer.garmin.com 이 JS 렌더링, 청구항 해석은 법무 영역, Strava 문서에 기준 없음 | 브라우저로 FIT SDK 확인 / 법무 검토 / `max_gap_ms` 는 skill 자체 선택으로 표기 |
| 실제 GPS fixture, 종목별 `max_accel_mps2`·`gps_slack_m` 값 | ⚠️ | fixture 없음 | 종목별 실기록 fixture 확보 후 조정 |
| X(Twitter) summary_large_image, Slack·LinkedIn 크롤러 WebP, 카카오 smart crop 알고리즘·안전 여백 | ⚠️ | x.com 문서 402/404, 실제 공유 테스트 안 함, 카카오는 포럼 답변뿐 | 실제 공유로 확인 |
| Pretendard 의 현대 한글 11,172 음절 커버리지, resvg 0.50 COLR 벡터 이모지, 실제 `.woff2` 파일 거부 | ⚠️ | Noto CJK KR Bold 만 cmap 검사, sbix 만 실측, woff2 는 magic 4바이트로만 시험 | skrifa cmap 검사, 이모지·woff2 fixture |
| 렌더 시간·메모리, Semaphore 슬롯 수, timeout 3s, 실제 폰트에서 `wrap_keep_all` 측정 호출 수 | ⚠️ | 부하 테스트 안 함 | 부하 테스트로 정한다 |
| takumi 의 keep-all 지원과 `default-features = false` 일 때 feature 이름 | ⚠️ | 문서에서 찾지 못함 | docs.rs features 페이지 |
| yrs `small-client` 가 Yjs 13.x 에 필요한가, JS offset 이 UTF-16 인가, Automerge 3.0 개선의 Rust native 적용, samod 성숙도 | ⚠️ | 상호운용 테스트 전, JS 쪽은 추론, 측정 자료 없음, README 와 블로그 상충 | Yjs 13.6.x·y-prosemirror 교차 테스트, 채택 시 criterion 측정 |
| crdt-sync writer task 구조(group commit), `SEND_TIMEOUT` 경로, turmoil 단절 시뮬레이션, 예시값(64·10초·5초·8 MiB) | ⚠️ | 산문뿐이거나 테스트하지 않음 | 실제 문서 크기·편집 빈도로 측정 |
| OTLP exporter 의 collector 전송, release profile LTO 링크 빌드 | ⚠️ | collector·docker 없음, `cargo check --release` 까지만 | 로컬 collector, CI 의 `cargo build --release` |
| cargo-nextest·cargo-llvm-cov 체인, `cargo insta review`, mockall_double | ⚠️ 실행 안 함 | 도구 미설치(플래그는 README·usage 대조), mockall_double 최신 릴리스 2023-12 | CI 에서 실행, 임시 crate |
| rust-reviewer agent end-to-end, Glob 패턴 매칭, plugin agent 의 `Skill` 도구로 `/rust:*` 로드 | ⚠️ | 실제 workspace 에서 돌리지 않음, 이 세션에 Glob 도구 없음 | 실제 Rust 레포에서 agent 실행 |
| "Composed Method"·"SLAP" 원 출처, Bulletproof Rust Web 저자 동일인 여부, Google 가이드 적용 범위 | ⚠️ | 레포 용어로만 인용, 커밋 author 만 확인, "intend to start applying" 단계 | 인용 범위 유지, 분기 재검증 |
| Microsoft Libraries 장 지침(M-DI-HIERARCHY·M-INIT-BUILDER·M-MOCKABLE-SYSCALLS·M-BALANCED-MODULES 등)의 앱 적용 | ⚠️ 해석 | 원문이 library 장이다 | 자산 본문에 해석이라고 적었다. 앱 장에 같은 지침이 생기면 갱신 |
| 바뀔 예정인 것: axum 0.9, RTN·dyn async fn 안정화, clippy.toml 위치("may be deprecated") | ⚠️ | 미출시·예고 단계 | 2027-02 재검증 |

조사 보고서의 미검증 항목 가운데 자산 작성 중 해소된 것:

- tower-http 0.7 + axum 0.8.9 조합: rust-async-tokio·rust-og-image-render scratch 에서 tower-http 0.7.1 과 axum 0.8.9 로 함께 컴파일됐다(Cargo.lock 확인).
- axum main 예제의 에러 로깅 미들웨어(`Arc<AppError>` + `from_fn`): axum 0.8.9 로 컴파일됐다. 실행은 하지 않았다.
- `async_fn_in_trait` 가 bin crate 안 trait 에서 안 나는지: bin crate 의 pub trait 에서도 경고가 난다(로컬 실측, §3).
- sqlx 0.9 feature 이름(runtime-tokio·postgres·macros·migrate·tls-rustls)과 testcontainers 조합: docs.rs features 와 scratch 로 확인했다(§5, §7).
- 번들 한글 폰트 커버리지는 Noto Sans CJK KR Bold 에 한해 누락 0, 위도 37° 수치는 투영 함수 계산으로 대체, dashmap·unicode-segmentation·unicode-normalization 버전은 docs.rs 로 확인했다.

## 인용 금지·충돌 목록

- **출처 간 충돌**(자산에 "충돌" 로 적었다): DI 기본(MS concrete vs axum 예제 dyn → D1), Display 와 `source()`(std vs MS → D10), `catch_unwind`(MS 요청 단위 허용 vs Google 금지), fallible 생성자 이름(MS `TryFrom`·Google `try_new`·Comprehensive Rust `new -> Result`), Builder(bon typestate vs M-INIT-BUILDER), Service 타입명(D3), error 모듈 배치(D11, smithy-rs 는 error submodule), single-use helper(rust-analyzer vs Book 12.3 → D12), y-protocols 개정판의 client-first handshake vs yrs·@y/websocket-server 의 server-first.
- **CPU 오프로드 기본 순서**: tokio 문서는 semaphore 와 rayon 을 둘 다 제시한다. 레포는 "CPU 전용 Semaphore 를 건 spawn_blocking 으로 시작하고 측정 후 rayon" 을 고른다. Alice Ryhl 의 "poorly suited" 는 비싼 CPU 계산을 두고 한 말이고 소수 계산은 허용한다.
- ❌ **정정값만 쓴다**: JR-20 config separator 기본값 '.'(기본값 없음) / AC-22 "`log` 레코드(sqlx 등)"(sqlx 0.9 는 tracing 으로 직접) / AR-13 잘못된 disallowed 경로는 에러(1.96 은 경고) / AC-07 spawn_blocking 을 CPU 에 그대로 / GEO-12 rstar 0.14 의 `bulk_load_parallel`(배포판에 없음) / R-14 crates_io_og_image 의 typst 0.15.1(^0.14.2) / AR-27 yrs `Protocol` 의 `&Awareness`(`&mut`·`Result`) / 내부 POST 렌더 API 의 ETag/304 / cosmic-text `Wrap::Word` 를 keep-all 로 / resvg `features=["text"]` 만으로 컬러 이모지 / PQ-07 Recall.ai 갱신분의 "병목 제거".
- **인용 금지**: axum `anyhow-error-response` 예제 body(내부 메시지 노출) / tower-http `CatchPanicLayer::custom` 예제(panic 상세 노출) / Comprehensive Rust thiserror 예제의 `{0}` + `#[from]` / launchbadge realworld 의 `Extension`·axum 0.3 API / Zero To Production 의 thiserror 1.x·validator 0.18 코드 / actix 문서의 "WARN 로그" 서술 / MS 템플릿의 `correctness = warn` / 옛 용어 "object safe" / `M-ABSTRACTIONS-DONT-NEST` ID / docs.rs 의 `#[sqlx::test(migrations = "foo_migrations")]` 예시(0.9 에서 컴파일 안 됨) / DBOS "60K writes/s"(수치 미대조).
- **수치의 주체**: Automerge "over 10x" 는 개발 주체 블로그 수치이고 Rust native 수치가 아니다. 카카오 OG 규격은 포럼 운영진 답변이다. Strava 매칭·차량 탐지는 Strava 자체 글, Cloudflare 장애는 Cloudflare 사후 보고다. Firezone·Polar Signals 는 대기업 근거로 쓰지 않는다.
