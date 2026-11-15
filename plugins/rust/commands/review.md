---
description: "Rust 코드를 리뷰하고 개선점을 제안합니다"
---

# Rust Code Review

변경된 Rust 코드를 리뷰합니다. 컴파일러·런타임 의미에 걸린 Rust 고유 위험을 먼저 보고, 언어 공통 항목(가독성·네이밍·중복)은 `dx:code-reviewer` agent 기준을 따릅니다.
상시 규칙은 [rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md), 심각도는 [code-review rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/code-review.md) 의 Blocker/Critical/Major/Minor 를 씁니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Git diff 또는 특정 파일·crate |
| Output | 이슈 목록 (파일:라인, 심각도, 현재/수정) |
| Required Tools | git, cargo, clippy |
| Verification | Blocker/Critical 이슈 해결, `cargo clippy --all-targets -- -D warnings` 와 `cargo test` 통과 |

## Checklist

### 에러·panic (`/rust:rust-error-handling`)
- [ ] 입력·외부 상태 실패에 `unwrap()`·`panic!` 없음. 불변식만 `expect("왜 실패할 수 없는지")`
- [ ] 변환은 `From`(`#[from]`) + `?`. 호출부 `map_err` 반복, `map_err(|_| …)` 로 원인 버리기 없음
- [ ] 엔진이 판정해 저장할 결과(구간 미통과·부정 의심·판정할 수 없는 입력 → `Rejected`)는 `Err` 가 아니라 `Ok(Verdict)`. 요청 형식 오류처럼 4xx 로 끝나는 거절은 `Err`
- [ ] 경계마다 분류 지점 하나 (`impl IntoResponse` 는 wildcard 없는 `match`), 500 body 에 내부 메시지 없음
- [ ] 원인은 `source()` 또는 Display 중 하나만 — `#[error("…: {0}")]` 와 `#[from]` 을 같이 쓰지 않음

### 구조·타입 (`/rust:rust-idioms`)
- [ ] 이름 붙일 단계는 `fn check_x(..) -> Result<_, E>` + `?` (Composed Method), 중첩은 `?`·`let-else`·let chains
- [ ] borrow 에러를 `clone()` 으로 덮지 않음, bool 인자 대신 enum, 불변식 있는 값은 newtype + fallible 생성자
- [ ] 구현이 하나뿐인 trait(interface + Impl) 없음 — 단 fake 로 shell 흐름을 테스트하는 좁은 경계 trait(DB·외부 API·시계)는 허용. 의존성은 concrete > generic > `dyn`
- [ ] 가시성 최소 (`pub(crate)`·`pub(super)`), `foo.rs` 와 `foo/mod.rs` 혼용 없음
- [ ] `.rs` 파일이 테스트 모듈을 빼고 400줄을 넘으면 분할 검토 (house rule)

### async·엔진 (`/rust:rust-async-tokio`, `/rust:rust-engine-architecture`)
- [ ] async 함수 안 blocking IO·무거운 CPU 없음 (`spawn_blocking` + CPU 전용 상한, 측정해서 CPU 가 처리량을 좌우하면 rayon)
- [ ] std `MutexGuard` 를 `.await` 너머 들고 있지 않음 (clippy `await_holding_lock`)
- [ ] `select!` branch future 가 취소 안전, spawn 한 task 의 실패(`JoinError`)를 버리지 않음
- [ ] core crate 에 tokio·sqlx·`Instant::now()` 가 없고 출력 경로에 `HashMap` 순회 순서가 없음

### unsafe·lint·테스트 (`/rust:rust-testing`)
- [ ] 모든 `unsafe` 블록 앞에 `// SAFETY:` 주석
- [ ] 새 예외는 `#[allow]` 가 아니라 `#[expect(lint, reason = "…")]`, 코드에 `#![deny(warnings)]` 없음
- [ ] 변경 로직에 `should_x_when_y` 테스트, SQL 은 실제 Postgres 로 검증

언어 공통 항목은 subagent_type: `dx:code-reviewer` 에 맡기고, 소유권·async·unsafe·core 순수성 변경이 많은 PR 은 subagent_type: `rust:rust-reviewer` 를 함께 호출합니다. 결과가 겹치면 Rust 고유 항목은 rust-reviewer 쪽을 우선합니다.

## Output Format

```
[Blocker] src/api/error.rs:58 - 500 응답 body 에 내부 에러 문자열 노출
  현재: (StatusCode::INTERNAL_SERVER_ERROR, self.to_string()).into_response()
  수정: tracing::error!(error = %error_chain(&self), "request failed");   // error_chain: /rust:rust-error-handling
        (StatusCode::INTERNAL_SERVER_ERROR, "internal error").into_response()

[Critical] src/ingest/parse.rs:42 - 외부 입력 실패에 unwrap (잘못된 값 하나로 worker 가 panic)
  현재: let distance: f64 = raw.parse().unwrap();
  수정: let distance: f64 = raw.parse()?;   // ParseError 에 #[from] ParseFloatError

[Blocker] src/worker/run.rs:88 - std MutexGuard 를 .await 너머 보유 (변경 라인의 await_holding_lock 이 -D warnings 를 깸, spawn 하면 Send 에러)
  현재: let mut seen = state.seen.lock().expect("…"); fetch(id).await; seen.insert(id);
  수정: fetch(id).await; state.seen.lock().expect("…").insert(id);
```

## Usage

```
/rust:review                    # 현재 변경사항 (git diff)
/rust:review src/worker/        # 특정 경로
/rust:review --staged           # staged 변경만
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `git diff` 결과 없음 | 변경이 이미 staged | `git diff --cached` 또는 `git status` 확인 |
| clippy 가 리뷰 전에 컴파일 에러로 멈춤 | 변경이 빌드되지 않음 | `cargo check --all-targets` 에러를 [Blocker] 로 먼저 보고 |
| `future cannot be sent between threads safely` | `.await` 너머 std `MutexGuard`·`Rc` 보유 | guard 를 `.await` 전에 drop (블록으로 감싸기). `.await` 너머 잠가야 하는 IO 자원만 tokio `Mutex` |
| `error[E0502]` (helper 추출 후) | `&mut self` helper 가 self 전체를 빌림 | 필요한 필드만 받는 fn — `/rust:rust-idioms` |
| clippy 경고가 너무 많아 diff 이슈가 묻힘 | 기존 코드의 경고 | 변경 라인의 경고만 이슈로(`-D warnings` 를 깨므로 [Blocker]), 나머지는 목록으로 |
| 리뷰 범위가 너무 큼 | PR 400줄 초과 | crate·기능 단위로 PR 분할 |

## Best Practices

1. `git diff --stat` 으로 범위를 보고 core crate 와 shell crate 변경을 나눠 읽는다
2. `cargo check --all-targets` → `cargo clippy --all-targets -- -D warnings` → `cargo test` 결과를 근거로 첨부한다. 못 돌렸으면 "실행 안 함" 으로 적는다
3. 이슈마다 근거 skill 을 붙이고, 결과는 텍스트로만 반환한다. PR 코멘트 게시는 사용자 승인 후에 한다
