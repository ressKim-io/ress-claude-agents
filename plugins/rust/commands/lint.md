---
description: "cargo fmt·clippy 로 이슈를 찾고 요청하면 수정합니다"
---

# Rust Lint

`cargo fmt --check` 와 `cargo clippy` 로 경고를 보고합니다. `--fix` 로 부르면 작업 트리가 깨끗할 때만 기계적으로 고칠 수 있는 것을 고치고 다시 검사합니다.
lint 레벨·threshold 의 근거와 전체 템플릿은 `/rust:rust-idioms` (Lint 로 강제) 에 있습니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Cargo 패키지 또는 workspace 루트 |
| Output | 잔여 경고 목록 (`--fix` 면 수정된 파일 포함) |
| Required Tools | cargo, rustfmt, clippy (rustup component) |
| Verification | `cargo fmt --all --check` 와 `cargo clippy --all-targets -- -D warnings` 통과. feature 끼리 배타적이지 않으면 `--all-features` 로도 |

## Checklist

### 실행 순서
- [ ] 기본은 보고만 — `cargo fmt --all --check`, `cargo clippy --all-targets -- -D warnings`. `-p <pkg>` 를 받으면 fmt 는 `--all` 대신 `-p <pkg>`, clippy 와 `--fix` 에는 `-p <pkg>` 를 붙인다
- [ ] `--fix` 일 때만 수정. 먼저 `git status` — untracked 를 포함해 dirty 면 멈추고 사용자에게 알린다 (커밋·stash 는 사용자가, `--allow-dirty` 는 사용자가 승인할 때만)
- [ ] `cargo clippy --fix` (`--no-deps`·`--all-targets` 를 함축) → `cargo fmt --all` (자동 수정 결과도 포맷)
- [ ] 다시 `cargo clippy --all-targets -- -D warnings` (수정이 새 경고를 남길 수 있다) → `cargo test` 로 동작 확인

### 설정 확인 (값은 house rule)
- [ ] 레벨은 Cargo.toml `[lints]`·`[workspace.lints]`, threshold 는 clippy.toml 에만
- [ ] `too_many_lines = "warn"` + `too-many-lines-threshold = 100` 명시 (20-50줄 PREFER 는 리뷰 기준)
- [ ] `excessive-nesting-threshold = 4` 로 시작해 실제 경고 수를 보고 조정
- [ ] `unwrap_used = "warn"` + `allow-unwrap-in-tests = true`, 불변식은 `expect("…")`
- [ ] 그룹은 `{ level = "warn", priority = -1 }`, `unsafe` 가 있으면 `undocumented_unsafe_blocks = "warn"`
- [ ] `cognitive_complexity` 는 켜지 않는다 (clippy 문서가 측정값으로 쓰지 말라고 한다)

### 수동 처리
- [ ] 경고를 `#[allow]` 로 덮지 않는다 — 고치거나 `#[expect(lint, reason = "…")]`
- [ ] 코드에 `#![deny(warnings)]` 를 넣지 않는다 — CI 의 `-D warnings` 로 막는다
- [ ] `too_many_lines`·`excessive_nesting` 경고는 `/rust:refactor` 로 넘긴다

## Output Format

```markdown
## Lint Report

### Fixed Issues (`--fix` 일 때만)
- [clippy::needless_return] src/track/gate.rs:42 - `--fix` 로 수정
- [rustfmt] src/track/gate.rs - 포맷 적용

### Remaining Issues
- [clippy::too_many_lines] src/worker/run.rs:88 - 132/100줄, 단계 추출 필요
- [clippy::unwrap_used] src/render/font.rs:17 - 불변식이면 expect("…"), 아니면 ? 로 전파
```

## Usage

```
/rust:lint                      # workspace 전체, 보고만
/rust:lint -p engine-core       # 특정 패키지
/rust:lint --fix                # 작업 트리가 깨끗할 때 자동 수정 후 재검사
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `excessive_nesting` 경고가 하나도 없음 | threshold 기본값 0 = 꺼짐 | clippy.toml 에 `excessive-nesting-threshold` |
| ``unused manifest key: `lints.clippy.too_many_lines.threshold` `` | threshold 를 Cargo.toml 에 씀 | clippy.toml 로 옮긴다 |
| ``lint group `pedantic` has the same priority (0) as a lint`` | 그룹과 개별 lint 의 priority 가 같음 | `pedantic = { level = "warn", priority = -1 }` |
| ``unknown lint: `clippy::inline_modules` `` | 1.97+ lint 인데 toolchain 이 낮음 | toolchain 을 올리거나 그 줄을 뺀다 |
| core 처럼 자기 clippy.toml(`disallowed-methods` 등)을 둔 member 에서 threshold 가 안 먹음 | 가장 가까운 clippy.toml 하나만 쓰이고 root 와 병합되지 않는다 | 그 member 의 clippy.toml 에 threshold 복제 |
| `cargo clippy --fix` 가 `uncommitted changes` 로 멈춤 | 작업 트리가 dirty | 사용자에게 알리고 커밋·stash 여부를 묻는다. diff 가 섞여도 된다고 승인하면 `--allow-dirty` |
| `cargo clippy --fix` 가 `no VCS found for this package` 로 멈춤 | git 저장소가 아님 | 사용자에게 알린다. 승인할 때만 `--allow-no-vcs` |
| ``Warning: can't set `imports_granularity = Crate` `` | rustfmt.toml 의 unstable 옵션 | stable 옵션만 쓰거나 nightly rustfmt |
| `query!` 매크로가 CI 에서만 실패 | `.sqlx` 오프라인 데이터가 없거나 stale | `cargo sqlx prepare --workspace` 로 `.sqlx` 를 갱신하고 커밋은 사용자에게 요청, CI 는 `--check` |

Cargo 1.99+ 는 `[lints]` 의 hyphen lint 이름에 경고합니다. Cargo.toml 은 `too_many_lines`, clippy.toml 키는 `too-many-lines-threshold` 입니다.

## Best Practices

```toml
# Cargo.toml (단일 crate). workspace 면 [workspace.lints.clippy] 에 쓰고 member 는 [lints] workspace = true
[package]
# 예: let chains(edition 2024) 하한. 의존성 MSRV 가 더 높으면 그 값 (sqlx 0.9 는 1.94)
rust-version = "1.88"            # clippy msrv 기본값이 이 값을 따른다

[lints.clippy]
too_many_lines = "warn"          # pedantic(allow) 이라 직접 켠다
unwrap_used    = "warn"
```

```toml
# clippy.toml — 값은 house rule
too-many-lines-threshold    = 100   # 기본값과 같지만 명시한다
excessive-nesting-threshold = 4     # 시작값. 실제 코드의 경고 수를 잰 뒤 조정
allow-unwrap-in-tests       = true
```
