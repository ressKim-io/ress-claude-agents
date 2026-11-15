---
description: "Rust 코드 리팩토링을 제안합니다"
---

# Rust Refactor

동작을 바꾸지 않고 Rust 코드를 짧은 단계로 나누는 리팩토링을 제안합니다. 나누는 수단의 근거는 `/rust:rust-idioms`, 에러 타입 설계는 `/rust:rust-error-handling` 에 있습니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Rust 소스 파일 또는 모듈 |
| Output | 리팩토링 제안 및 수정된 코드 |
| Required Tools | cargo, clippy |
| Verification | 리팩토링 전후 모두 `cargo test` 와 `cargo clippy --all-targets -- -D warnings` 통과 |

## Checklist

### 1. 자주 쓰는 분리 수단 — 전체 결정 트리는 `/rust:rust-idioms`
```
├── 실패할 수 있고 이름 붙일 단계 ──────> fn check_x(..) -> Result<_, E>, 호출부는 ?
├── self 상태가 필요 없다 ─────────────> impl 밖 module-private free fn
├── 필드를 빌린 채 &mut self helper ──> 필요한 필드만 받는 fn (E0502 회피)
└── Err/None 이면 위로, 아니면 꺼내기 ──> ? / let-else / let chains (edition 2024)
```

### 2. 크기·타입·테스트 용이성
- 함수는 20-50줄 PREFER, clippy `too_many_lines` 100 (코드 줄만 센다)·`excessive_nesting` 4 (house rule)
- `.rs` 파일이 테스트 모듈을 빼고 400줄을 넘으면 `foo.rs` + `foo/` 로 책임별 분할 검토 (house rule)
- 호출부 `map_err` 반복 → `impl From`(`#[from]`) 한 번 + `?`
- 같은 원시값 검증 반복 → newtype + `TryFrom`/`FromStr` (경계에서 한 번)
- IO 와 계산이 섞임 → 계산을 IO 없는 함수로, 시간은 `now` 인자로 (`/rust:rust-engine-architecture`)

## Output Format

```markdown
- [High] src/session/start.rs:30 - start_session if 중첩 2단 → let-else + check_not_in_future 추출
  Before: {원본 코드}
  After: {개선된 코드}
- 검증: cargo test·clippy 전/후 통과 | 실행 안 함
```

## Usage

```
/rust:refactor src/session/start.rs     # 파일 분석
/rust:refactor src/worker/              # 모듈 분석
/rust:refactor --apply                  # 제안 적용
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| ``error[E0502]: cannot borrow `*self` as mutable …`` | `&mut self` helper 가 self 전체를 빌림 | 필요한 필드만 받는 fn, 또는 계산과 대입 분리 |
| ``error[E0624]: method `…` is private`` | impl 을 하위 파일로 옮겼는데 부모 모듈이 호출 | 그 method 를 `pub(super) fn` 으로 |
| ``error[E0761]: file for module `…` found at both …`` | `foo.rs` 와 `foo/mod.rs` 가 같이 있음 | 한쪽만 남긴다 (`foo.rs` + `foo/` 권장) |
| `let chains are only allowed in Rust 2024 or later` | edition 2021 crate | edition 2024 로 올리거나 let-else·중첩 if |

## Best Practices

```rust
// ❌ BAD: 조건이 중첩되고 단계에 이름이 없다 — clippy(threshold 4)도 경고하지 않는다
pub fn start_session(req: &StartRequest, now: UnixSeconds) -> Result<Session, SessionError> {
    if let Some(course_id) = req.course_id {
        if req.started_at <= now {
            Ok(Session::new(course_id, req.started_at))
        } else {
            Err(SessionError::FutureStart)
        }
    } else {
        Err(SessionError::MissingCourse)
    }
}

// ✅ GOOD: guard 는 let-else, 이름 붙일 단계는 Result 를 돌려주는 fn + ?
pub fn start_session(req: &StartRequest, now: UnixSeconds) -> Result<Session, SessionError> {
    let Some(course_id) = req.course_id else {
        return Err(SessionError::MissingCourse);
    };
    check_not_in_future(req.started_at, now)?;
    Ok(Session::new(course_id, req.started_at))
}

fn check_not_in_future(started_at: UnixSeconds, now: UnixSeconds) -> Result<(), SessionError> {
    if started_at > now {
        return Err(SessionError::FutureStart);
    }
    Ok(())
}
```
