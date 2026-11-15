---
description: "Rust 단위·통합 테스트 코드를 생성합니다"
---

# Rust Test Generator

Rust 함수·모듈의 테스트를 생성합니다. 배치·도구 선택의 근거는 `/rust:rust-testing`, 이름·Given-When-Then·커버리지 기준은 레포 [testing rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/testing.md) 을 따릅니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Rust 소스 파일 또는 함수명 |
| Output | 같은 파일의 `#[cfg(test)] mod tests` 또는 `tests/<대상>.rs` |
| Required Tools | cargo (선택: cargo-nextest, cargo-insta) |
| Verification | `cargo test` 통과. nextest 를 쓰면 `cargo nextest run` + `cargo test --doc` |

## Checklist

### 배치
- [ ] 비공개 함수·순수 계산 → 같은 파일 `#[cfg(test)] mod tests` (`use super::*;`)
- [ ] 공개 API 만 쓰는 시나리오 → `tests/*.rs`, 공용 helper 는 `tests/common/mod.rs`
- [ ] SQL·제약·`ON CONFLICT` → 실제 Postgres (`#[sqlx::test]` 또는 testcontainers), mock 금지
- [ ] async fn → `#[tokio::test]` (tokio `macros`·`rt`), 타이머는 sleep 대신 `start_paused = true` (`test-util`)

### 케이스
- [ ] happy / error / edge (경계값, 빈 입력, NaN·inf) — 에러 경로 목록은 `/dx:negative-path-coverage`
- [ ] 이름은 `should_x_when_y`, 본문은 `// Given` `// When` `// Then` (When 은 한 번), 기대값은 손으로 계산한 값

### 도구 선택
- [ ] 어떤 입력이든 성립하는 성질 → proptest. 범위를 정한 strategy 가 기본, `f64::ANY` 는 NaN·inf 를 섞으므로 비유한값 처리 성질을 볼 때만
- [ ] 큰 구조체·JSON 결과 → `insta::assert_json_snapshot!(summary, { ".distance_m" => insta::rounded_redaction(2) })`
- [ ] 결과만 돌려주는 의존성 → hand-written fake, 호출 횟수가 계약이면 mockall `#[automock]`

### Test Template — 대상 `Distance::parse(raw: &str) -> Result<Distance, DistanceError>`
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn should_reject_when_distance_is_negative() {
        // Given
        let raw = "-1.5";
        // When
        let result = Distance::parse(raw);
        // Then
        assert!(matches!(result, Err(DistanceError::Negative)));
    }

    proptest! {
        #[test]
        fn should_keep_value_when_parsing_its_own_text(meters in 0.0..1_000_000.0_f64) {
            // Given
            let raw = meters.to_string();
            // When
            let distance = Distance::parse(&raw)?;
            // Then
            prop_assert_eq!(distance.meters(), meters);
        }
    }
}
```

## Output Format

생성된 테스트 위치(파일·모듈)와 실행 결과 한 줄 — `cargo test: N passed` 또는 "실행 안 함".

## Usage

```
/rust:test-gen src/track/distance.rs            # 파일 전체
/rust:test-gen src/track/distance.rs parse      # 특정 함수
/rust:test-gen --integration                    # tests/ 통합 테스트로 생성
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `tests/` 에서 `<crate>::…` 경로가 `error[E0432]`·`error[E0433]` 로 실패 | `main.rs` 만 있는 binary crate | 로직을 `lib.rs` 로 옮긴다 |
| `Running tests/common.rs` 와 `running 0 tests` 가 출력됨 | `tests/common.rs` 도 테스트 crate 로 잡힘 | `tests/common/mod.rs` 로 옮긴다 |
| insta 테스트가 첫 실행에서 실패하고 `.snap.new` 가 생김 | 저장된 스냅샷이 없음 | `cargo insta review` 로 승인, CI 는 `INSTA_UPDATE=no` |
| `#[sqlx::test]` 가 DB 생성 단계에서 실패 | `DATABASE_URL` 없음 또는 superuser 아님 | superuser 권한 `DATABASE_URL` 설정 |

## Best Practices

대상의 시그니처·에러 타입·`pub` 여부로 배치를 정하고, happy / error / edge 케이스 표를 먼저 쓴 뒤 테스트로 옮깁니다. proptest 본문의 `?` 는 에러 타입이 `std::error::Error` 를 구현해야 쓸 수 있고, insta 는 `assert_json_snapshot!` 에 `json`, `rounded_redaction` 에 `redactions` feature 가 필요합니다.

```toml
[dev-dependencies]
proptest = "1.12"
insta = { version = "1.49", features = ["json", "redactions"] }
```
