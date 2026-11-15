---
name: rust-engine-architecture
description: "Rust 계산 엔진 구조 — IO 없는 core·얇은 shell crate(Functional Core·sans-IO), 경계 CI 검사, concrete·generic·dyn 의존성 선택, 결정성·ENGINE_VERSION 관리. Use when Rust 계산 엔진의 workspace·core/shell crate 경계를 정하거나 엔진의 Controller-Service-Repository 를 adapter·core 로 나눌 때."
---

# Rust Engine Architecture — IO 없는 core, 얇은 shell

계산 엔진(판정·렌더·동기화)은 Controller-Service-Repository 를 그대로 옮기지 않는다. **IO 없는 core 라이브러리 crate + IO 를 맡는 얇은 shell 바이너리 crate** 로 나누고 경계를 Cargo 와 CI 로 강제한다. 이 구조의 이름은 Functional Core, Imperative Shell(Gary Bernhardt) 이고, 프로토콜 쪽에서는 sans-IO 라고 부른다(quinn-proto "fully deterministic", rustls "does not take care of network IO"). 도메인 흐름은 Java 때와 같게 두고 기술 구성만 바꾼다 (Microsoft M-RUST-SHAPED: "technical constructs must not be copied 1-on-1").

## Quick Reference (결정 트리)

```
crate 를 어떻게 나누나?
├─ IO 없는 계산이 핵심 (판정·렌더·CRDT) ──────> workspace: <name>-core(lib) + <name>-worker|server(bin)
├─ 입력 파싱(GPX·FIT 등)이 크고 따로 테스트 ───> + <name>-ingest(lib)
└─ CRUD 위주, 계산 로직이 거의 없다 ───────────> 단일 crate + 기능별 모듈 (workspace 는 과설계)

core 의 모양은? (DB·시계 값은 shell 이 먼저 읽어 인자로 넘긴다)
├─ 입력 한 번 → 결과 한 번 (판정·렌더) ────────> 상태 없는 함수  judge(input, params) -> Judgement
└─ 메시지·타이머가 계속 온다 (동기화) ──────────> sans-IO 상태기계  handle_*(.., now) / poll_timeout()

shell 안에서 의존성을 어떻게 받나?
├─ 구현이 하나 ──────────────────────────────> concrete struct (기본)
├─ 닫힌 집합 중 하나를 설정으로 고른다 ──────────> enum
├─ shell 흐름 전체를 fake store 로 테스트한다 ──> generic + 좁은 trait (-> impl Future + Send). 레포 결정
└─ generic 이 중첩돼 번진다·런타임에 고른다 ────> dyn 을 wrapper struct 뒤에 (async 메서드면 async-trait)

실패를 어떻게 표현하나?
├─ 미통과·부정 의심·입력 거부 ─────────────────> Judgement 의 variant (Err 아님) — 저장할 결과
├─ core 불변식 위반 ───────────────────────────> expect → panic → CpuGate 가 JoinError 로 받아 Permanent(Bug)
└─ 인프라 장애(DB·gate 닫힘) ──────────────────> shell 의 Err → classify_* 한 곳

ENGINE_VERSION 을 올리나? (⚠️ 설계 제안 — 팀 합의)
├─ golden diff 가 생긴다 (판정 로직·Params·계산 crate·툴체인) ─> +1
└─ 리팩터링·로그·성능만 (golden diff 없음) ──────────────> 유지
```

## Workspace — 처음부터 core 와 shell 을 나눈다

**왜 첫 커밋부터인가.** 패키지 하나에는 lib 이 최대 1개이고 bin 은 `[dependencies]` 전체와 링크된다. target 별 의존성 기능(cargo#1982)은 2015년부터 열려 있다. lib 과 bin 을 한 패키지에 두면 core 코드가 tokio·sqlx 를 import 해도 Cargo 가 막지 못한다.

```
<engine>/
  Cargo.toml · clippy.toml · rust-toolchain.toml   # virtual manifest, threshold, 툴체인 고정
  crates/
    <name>-core/      # lib. 계산만. tokio·sqlx·reqwest·axum·시계 없음
      clippy.toml     # 금지 목록 + 루트 threshold 복제
      src/lib.rs      # pub fn judge(..) / pub const ENGINE_VERSION
      tests/          # golden fixture
    <name>-ingest/    # (선택) 입력 파싱
    <name>-worker/    # bin. 큐 워커 (HTTP·WS 엔진이면 <name>-server). main.rs 는 조립만
```

```toml
# <engine>/Cargo.toml
[workspace]
members  = ["crates/*"]
resolver = "3"                 # virtual manifest 는 edition 으로 추론하지 못한다 → 명시 (1.84+)
[workspace.package]
edition      = "2024"
rust-version = "1.94"          # 예: sqlx 0.9 를 쓰면 그 MSRV. 엔진마다 실제 의존성에 맞춘다
[workspace.lints.clippy]
# 공통 lint(too_many_lines·unwrap_used 등)는 rust-idioms 템플릿 그대로 두고, 엔진은 이 줄을 더한다
# 멤버가 [lints] workspace = true 에 lint 를 더할 수 없어 shell 에도 걸린다.
# 출력 순서와 무관한 shell 순회는 #[expect(clippy::iter_over_hash_type, reason = "…")]
iter_over_hash_type = "warn"   # restriction. for 루프만 잡는다
[profile.release]
panic = "unwind"               # 기본값이지만 명시. abort 면 task 하나의 panic 이 프로세스 전체를 죽인다
```

```toml
# crates/track-core/Cargo.toml
[package]
name         = "track-core"
version      = "0.0.0"          # 내부 crate. 배포 버전과 ENGINE_VERSION 을 섞지 않는다
publish      = false
edition.workspace      = true
rust-version.workspace = true
[dependencies]
thiserror = "2.0"
serde     = { version = "1.0", features = ["derive"] }
[lints]
workspace = true
```

- 멤버마다 `[lints] workspace = true` 가 있어야 `[workspace.lints]` 가 적용된다 (1.74+). lint 전체 목록은 [rust-idioms](../rust-idioms/SKILL.md). 폴더명 = crate 명, `crates/` 아래 평평하게, 내부 crate 는 `version = "0.0.0"` (matklad 권고). `main.rs` 는 config → pool → loops → signal 조립만 한다. Book 12.3 "Separating Concerns in Binary Projects" 도 main 은 직접 테스트할 수 없으니 로직을 lib 으로 옮기라고 한다.
- **안 나누는 경우:** 계산 로직이 없는 CRUD 서비스. 커뮤니티 자료도 CRUD endpoint 5개짜리 앱에 workspace crate 3개·trait 기반 repository·generic service·CQRS·event bus 를 한꺼번에 얹는 것을 과설계로 꼽는다.

## 경계 강제 — 두 겹

**1겹: CI 의 `cargo tree` 검사.** core 의 의존성 그래프에 IO crate 가 들어오면 실패시킨다.

```bash
set -euo pipefail
for core in track-core track-ingest; do
  deps=$(cargo tree -p "$core" -e normal --target all --all-features --prefix none)
  if grep -qE '^(tokio|sqlx|reqwest|axum|hyper) ' <<<"$deps"; then
    echo "::error::$core 에 IO crate 가 들어왔다"; exit 1
  fi
done
```

- `--target all`: 기본값은 host target 뿐이라 플랫폼별 의존성을 놓친다. `-e normal`: dev-dependency(proptest·insta)는 허용. `--all-features`: core 에 `tokio = { optional = true }` 를 두고 shell 이 feature 로 켜면, 이 옵션 없이는 검사가 통과한다 (로컬 실측: 없을 때 exit 0, 있을 때 exit 1). `cargo tree | grep -q` 로 바로 잇지 않는다. crate 이름 오타 등으로 `cargo tree` 자체가 실패해도 pipe 형태는 `if` 가 거짓이 되어 **검사가 조용히 통과**한다. 변수에 담으면 `set -e` 로 스크립트가 실패한다 (로컬 실측: pipe 형태 통과, 변수 형태 exit 101).

**2겹: core 전용 clippy.toml.** 시계와 순서 없는 컬렉션을 막는다. Clippy book 이 설정 파일을 "unstable and may be deprecated" 라고 적으므로 보조 수단으로 둔다.

```toml
# crates/track-core/clippy.toml — 가장 가까운 clippy.toml 하나만 읽힌다 → 루트 threshold 를 복제한다
# threshold 는 house rule(Rust rule)이지 공식 권장치가 아니다. nesting 4 는 시작값, 실제 코드로 잰 뒤 조정
too-many-lines-threshold    = 100
excessive-nesting-threshold = 4
allow-unwrap-in-tests       = true
disallowed-methods = [
  { path = "std::time::Instant::now",    reason = "core 는 시계를 읽지 않는다. now 를 인자로 받는다" },
  { path = "std::time::SystemTime::now", reason = "core 는 시계를 읽지 않는다. now 를 인자로 받는다" },
]
disallowed-types = [
  { path = "std::collections::HashMap", reason = "순회 순서가 실행마다 다르다. BTreeMap 을 쓴다" },
  { path = "std::collections::HashSet", reason = "순회 순서가 실행마다 다르다. BTreeSet 을 쓴다" },
]
```

- **병합되지 않는다.** 루트에만 `allow-unwrap-in-tests` 를 두면 core 테스트의 `unwrap()` 이 경고된다 (로컬 실측). 그래서 threshold 를 복제한다. **경로 오타는 조용히 지나갈 수 있다.** 문서는 없는 경로면 에러라고 적지만, 로컬 clippy(1.96)는 `std::…` 오타를 경고로만 냈고(`-D warnings` 로도 exit 0) 의존성에 없는 crate 경로(`rand::thread_rng`)는 아무 진단 없이 무시했다. 금지 항목마다 BAD 예시로 실제로 걸리는지 확인한다. 내부 조회용 HashSet 도 먼저 `BTreeSet`·정렬로 해결한다. 측정으로 병목이 확인된 경우에만 함수 단위로 예외를 두고 reason 에 근거를 적는다. 파일 상단의 `use std::collections::HashSet;` 도 경고되므로 전체 경로로 쓴다.

```rust
#[expect(clippy::disallowed_types, reason = "프로파일에서 BTreeSet 이 병목. 조회 전용이라 순회 결과가 출력에 나가지 않는다")]
pub fn count_duplicate_timestamps(ts: &[i64]) -> usize {
    let mut seen = std::collections::HashSet::new();
    ts.iter().filter(|t| !seen.insert(**t)).count()
}
```

**두 겹이 못 잡는 것.** std 의 IO(`std::fs`·`std::net`·`std::env`)는 별도 crate 가 아니라 `cargo tree` 에 나오지 않고, 정규식에 없는 sync IO crate(`ureq`·`postgres`)도 통과한다. clippy 목록은 모듈 단위로 막지 못해 항목마다 적어야 한다 (로컬 실측 clippy 1.96: `std::fs::File`·`std::net::TcpStream` 은 `disallowed-types`, `std::fs::read_to_string`·`std::env::var` 는 `disallowed-methods` 에서 경고가 났다. `std::fs` 를 넣으면 "expected a type, found a module" 경고만 나고, 적지 않은 `std::fs::write` 는 그대로 지나갔다). 두 겹은 실수를 줄이는 장치이고, 빠진 곳은 리뷰가 막는다.

## core 의 모양 — 상태 없는 함수 vs sans-IO 상태기계

### 상태 없는 판정 함수 (track-engine, og-render)

공개 진입점은 Composed Method 다. 같은 추상화 수준의 단계만 부르고, 단계마다 private 모듈 파일을 둔다 (`input.rs`, `anti_cheat/`, `frame.rs`, `segment/`).

```rust
pub fn judge(raw: &RawActivity, course: &Course, p: &Params) -> Judgement {
    let track = match validate_input(raw, p) {
        Ok(t) => t,
        Err(reason) => return Judgement::rejected(reason), // 저장할 판정 결과다. 재시도할 Err 가 아니다
    };
    let findings = anti_cheat::run_all(&track, p); // 원본 기준. smoothing 이 순간이동 증거를 지우기 전에
    if findings.iter().any(Finding::is_blocking) {
        return Judgement::flagged(findings);
    }
    let frame = LocalFrame::around(course.anchor());
    let path = frame.project_track(&clean_points(&track, p));
    let passes = segment::match_all(&path, &frame.project_course(course), p);
    Judgement::from_passes(passes, findings)
}
```

```rust
#[derive(Debug, Clone, PartialEq)]
pub enum Verdict {                                 // #[non_exhaustive] 를 붙이지 않는다 (worker 의 match 가 누락을 잡게)
    Passed { efforts: Vec<SegmentEffort> },
    NotPassed { reason: MissReason },
    Flagged { flags: Vec<FraudFlag> },             // 정렬해서 넣는다 (결정성)
    Rejected { reason: InputRejection },
}
#[derive(Debug, Clone, PartialEq)]
#[must_use = "판정 결과를 저장하지 않고 버리고 있다"] // 타입에 붙이면 Judgement 를 돌려주는 모든 함수에 적용된다
pub struct Judgement { pub engine_version: u32, pub verdict: Verdict }
```

- `#[must_use]` 는 함수에도 붙일 수 있지만, **타입**에 붙이면 그 타입 값을 버리는 모든 호출에 적용된다. 그래서 `judge()` 에 또 붙이지 않는다 (fn 에 메시지 없는 `#[must_use]` 를 더 붙이면 clippy `double_must_use`). `#[non_exhaustive]` 는 정의한 crate 밖의 match 에 wildcard 를 강제한다. workspace 내부 enum 에 붙이면 worker 가 새 variant 누락을 컴파일 에러로 잡지 못한다.
- 인자가 늘면 `Params` 구조체로 묶는다 (`too_many_arguments` 기본 7). 에러 enum 설계는 rust-error-handling, og-render 의 `render(spec, assets)` 도 같은 모양이다 (rust-og-image-render). shell 이 `spawn_blocking` 으로 돌린 계산은 시작된 뒤에는 abort 할 수 없다. 입력 크기 상한(포인트 수 등)은 core 의 `validate_input` 이 `Rejected` 로 처리한다.

### sans-IO 상태기계 (CRDT sync engine)

연결·타이머가 계속 오는 엔진은 상태기계에 bytes 와 시각을 넣고 출력을 받는다. 출력을 반환값으로 주는 방식(Polar Signals)과 `poll_transmit()` 으로 꺼내 가게 하는 방식(Firezone·quinn-proto)이 있다.

```rust
use std::collections::BTreeMap;

const IDLE_MS: u64 = 30_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct PeerId(pub u64);

#[derive(Debug, PartialEq)]
pub enum Outbound { Broadcast(Vec<u8>), PeerLeft(PeerId) }

#[derive(Default)]
pub struct Room { last_seen: BTreeMap<PeerId, u64> }

impl Room {
    pub fn handle_client(&mut self, peer: PeerId, msg: &[u8], now_ms: u64) -> Vec<Outbound> {
        self.last_seen.insert(peer, now_ms);
        vec![Outbound::Broadcast(msg.to_vec())]
    }

    pub fn handle_timeout(&mut self, now_ms: u64) -> Vec<Outbound> {
        self.last_seen
            .extract_if(.., |_, seen| now_ms.saturating_sub(*seen) >= IDLE_MS)
            .map(|(peer, _)| Outbound::PeerLeft(peer))
            .collect()
    }

    pub fn poll_timeout(&self) -> Option<u64> {
        self.last_seen.values().min().map(|seen| seen.saturating_add(IDLE_MS))
    }
}
```

- `BTreeMap::extract_if` (1.91+) 는 조건에 맞는 항목을 key 순서로 꺼내며 지운다. 그래서 `PeerLeft` 순서도 실행마다 같다. 테스트는 `room.handle_timeout(30_000)` 처럼 시각을 값으로 넘긴다. sleep 도 tokio runtime 도 필요 없다. `std::time::Instant` 는 숫자로 만들 수 없는 opaque 값(`now()` 에서 출발한다)이라 fixture 로 저장할 core 경계에서는 `u64` ms 나 newtype 을 쓴다. shell 은 `poll_timeout()` 시각에 `handle_timeout(now)` 을, 메시지가 오면 `handle_client(.., now)` 를 부르고 받은 `Outbound` 를 보낸다. 루프와 `select!` 는 [rust-async-tokio](../rust-async-tokio/SKILL.md), yrs 를 감싼 실제 Room 은 rust-crdt-sync.
- **모든 엔진에 쓰지 않는다.** Polar Signals 는 이 방식의 단점으로 인지 부하와 driver 로 새는 로직을 꼽는다. 상태 없는 track-engine 은 `judge()` 하나로 충분하다.

## Spring 계층 → 엔진 매핑

| Spring | 엔진에서 | track-engine | og-render | sync engine |
|---|---|---|---|---|
| Controller | inbound adapter (shell) | claim 루프, LISTEN 태스크, `/metrics`·`/healthz` | axum handler: body limit, timeout, 과부하 503 | WS upgrade 전 토큰 검증, 연결별 bounded 송신 큐 |
| Service | core (IO 없음) | `judge(raw, course, params)` | `render(spec, assets)` | `Room` 상태기계 |
| Repository | outbound adapter (shell) | claim·finish·결과 upsert + SQL 파일 | 거의 없음. 번들 폰트를 시작 시 1회 로드 | update log·snapshot·epoch fencing |
| `@ControllerAdvice` | 분류 지점 한 곳 | `apply_outcome` | `impl IntoResponse for OgError` | `SyncError::close_frame()` |
| DI 컨테이너 | `main` 에서 직접 조립 | config → pool → listener → loops | `#[derive(Clone)] AppState` + `State<T>` | 같음 |
| 패키지(`controller`·`service`·`repository`) | 기능별 파일 (예시) | track-worker `main.rs`(조립)·`runner.rs`(loop·fill·`process_job`)·`claim.rs`·`store.rs`(입력 load·fencing finish)·`outcome.rs`(`classify_*`·`apply_outcome`)·`listener.rs`·`reaper.rs`·`ops.rs`(`/healthz`·`/metrics`). core 는 위 §상태 없는 판정 함수 | og-server `render.rs` + `render/{handler,limits}.rs`·`error.rs`(`OgError`). og-core 는 rust-og-image-render §1 | sync-core `room.rs`·`authorize.rs`·`error.rs`(`RoomError`). sync-server `connect.rs`(토큰·upgrade)·`peer.rs`(연결 task)·`actor.rs`·`registry.rs`·`journal.rs`·`error.rs`(`SyncError`) |

rust-analyzer 아키텍처 문서도 core 가 외부와 통신하지 않는다는 점을 "Architecture Invariant" 로 적는다. shell 의 작업 하나는 "값을 읽는다 → 순수 계산 → 결과를 쓴다" 순서다. 실패는 `classify_*` 가 `JobFailure` 로 바꾼다. `classify_*` 는 원인을 감싸기만 하는 변환이 아니라 재시도·dead 를 가르는 분류다. rule 이 `map_err` 를 허용하는 자리가 바로 이것이다. 계산은 `CpuGate::run` 으로 보낸다. `CpuGate` 는 [rust-async-tokio](../rust-async-tokio/SKILL.md), `JobFailure`·`classify_join` 은 rust-error-handling, `ComputeError`·`classify_sqlx`·`classify_compute` 와 lease 를 확인하는 finish(`judge_and_finish`, lease 를 잃으면 `JobFailure::LeaseLost`)는 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) 에 있다. 아래 `save_result` 는 그 finish 를 줄여 쓴 것이다. `load_inputs` 는 `fetch_optional` 로 읽어 `Option` 을 돌려준다. Go 가 activity 를 지운 경우는 장애가 아니라 core 의 `Rejected` 판정으로 저장한다. `fetch_one` 을 쓰면 `RowNotFound` 가 `classify_sqlx` 에서 Transient 가 되어 재시도를 다 쓴 뒤 dead 로 간다 (rust-pg-queue-worker §4). core 진입점의 정식 모양은 `judge(raw, course, params)` 이고, 다른 skill 의 `judge(..)` 호출은 이것을 줄여 쓴 것이다.

```rust
pub(crate) async fn process_job(
    store: &ActivityStore, cpu: &CpuGate, job: ClaimedJob, params: Arc<Params>,
) -> Result<(), JobFailure> {
    let judgement = match store.load_inputs(job.activity_id).await.map_err(classify_sqlx)? {
        Some((raw, course)) => cpu
            .run(move || judge(&raw, &course, &params))
            .await
            .map_err(classify_compute)?, // core 의 panic 도 여기로 온다 → Permanent(Bug)
        None => Judgement::rejected(InputRejection::ActivityMissing), // Go 가 지운 activity. 장애가 아니라 판정
    };
    store.save_result(job.activity_id, &judgement).await.map_err(classify_sqlx)
}
```

API 성격의 shell(og-server, sync-server)이 커지면 최상위 폴더를 계층별(`controllers/`)이 아니라 **기능별**(`render.rs` + `render/{handler,limits}.rs`)로 묶는다. Microsoft M-BALANCED-MODULES 도 `traits`·`errors` 같은 기술 분류 모듈을 피하라고 한다 (library 지침을 앱에 적용한 해석. 경계 에러 하나를 담는 `error.rs` 는 [rust-idioms](../rust-idioms/SKILL.md) 가 둔 예외). 엔진별 배치 예시는 위 표의 마지막 행이고, 어느 파일이든 테스트 모듈을 빼고 400줄을 넘으면 분할을 검토한다 ([Rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 house rule).

## 의존성 선택 — concrete > generic > dyn

Microsoft M-DI-HIERARCHY: "When asking for async dependencies, prefer concrete types over generics, and generics over dyn Trait". 의존성을 받는 trait 는 **shell 안**에 둔다. core 는 IO 를 부르지 않으므로 port 가 필요 없다.

| 단계 | 언제 | 모양 | 주의 |
|---|---|---|---|
| concrete | 기본. 구현이 하나 | `#[derive(Clone)] struct ActivityStore { pool }` + inherent `async fn` | — |
| enum | 닫힌 집합 중 하나를 설정으로 고른다. 또는 IO 타입이 자기 안에 mock variant 를 둔다 | `enum Exporter { Prometheus(..), Otlp(..) }`, 비공개 `enum Core { Native, Mocked(..) }` 의 `Mocked` 는 `test-util` feature 뒤 (M-MOCKABLE-SYSCALLS) | variant 를 늘리면 match 가 알려준다 |
| generic | shell 흐름 전체를 fake store 로 돌려 테스트한다, 구현 2개 이상 | 좁은 trait + `-> impl Future<Output = T> + Send` | `Send` 를 trait 정의에 적는다 |
| dyn | generic 이 중첩돼 타입 인자가 번진다. 열린 집합(플러그인)을 런타임에 고른다 | `struct DynStore(Arc<dyn Store>)` 같은 wrapper. async 면 `#[async_trait]` (`Pin<Box<dyn Future + Send>>`) | async fn in trait 는 dyn compatible 이 아니다 |

**출처와 다른 두 곳.** Microsoft 사다리는 테스트용 대체만 필요하면 generic 보다 enum(M-MOCKABLE-SYSCALLS)을 먼저 둔다. 이 레포는 "기본 concrete, mock 경계만 generic" 으로 정했다 — 위 generic 행은 enum 단계 대신 고른 레포 결정이다. dyn 은 Microsoft 가 "Once generics become a nesting problem" 일 때 고려하고, 그때도 "visible wrapping should be avoided, and custom wrappers should be preferred" 라고 한다. 그래서 `Arc<dyn>` 을 그대로 드러내지 않고 wrapper struct 뒤에 둔다. '열린 집합을 런타임에 고른다'는 이 skill 이 더한 기준이다.

```rust
// ❌ BAD: Spring 의 Repository interface + Impl 을 그대로 옮김. 구현은 하나뿐인데 trait + dyn
pub(crate) trait ActivityRepository {
    async fn load(&self, id: ActivityId) -> Result<RawActivity, StoreError>;
}
pub(crate) struct Runner { repo: Arc<dyn ActivityRepository> } // error[E0038]: dyn compatible 이 아니다
// ✅ 2단계: shell 흐름을 DB 없이 테스트해야 할 때만, shell 안에 좁은 trait 하나
pub(crate) trait JobStore {
    fn load_inputs(&self, id: ActivityId)
        -> impl Future<Output = Result<Option<(RawActivity, Course)>, StoreError>> + Send;
    fn save_result(&self, id: ActivityId, j: &Judgement)
        -> impl Future<Output = Result<(), StoreError>> + Send;
}
```

- stable 에서는 trait 에 그냥 `async fn` 을 쓰면 반환 future 에 `Send` 를 요구할 수 없다 (return type notation `S: Trait<method(..): Send>` 은 로컬 1.96 에서 E0658 experimental, 최신 stable(1.100) 릴리스 노트까지 안정화 기록 없음). 로컬 실측(rustc 1.96)에서 generic 코드의 `tokio::spawn` 이 "future cannot be sent between threads safely" 로 실패했고, bin crate 의 `pub trait` 에서도 `async_fn_in_trait` 경고가 났다. 위처럼 쓰거나 `#[trait_variant::make(Send)]` 로 trait 를 Send bound 판으로 다시 쓴다. 구현(`impl JobStore for ActivityStore`)과 fake 는 `async fn` 으로 써도 된다. fake 는 `Mutex<Vec<..>>` 에 저장 결과를 모으는 struct 하나면 된다 ([rust-testing](../rust-testing/SKILL.md)). port 의 `StoreError` 는 `#[error("database error")] Db(#[from] sqlx::Error)` 처럼 원인을 담는 enum 으로 둔다. 분류는 그 안의 `sqlx::Error` 를 꺼내 `classify_sqlx` 에 넘긴다 (`StoreError::Db(e) => classify_sqlx(e)`). 원인을 버리는 `From` 은 SQLSTATE 분류를 깨뜨린다. [rust-testing](../rust-testing/SKILL.md) 의 fake·mock 이 쓰는 `StoreError::Db` 와 같은 모양이다.
- axum 의 dependency-injection 예제는 "Using trait objects is recommended unless you really need generics" 라고 쓰지만 예제 trait 가 **sync** 다. async repository 에 옮기면 위 E0038 이 난다. Google 가이드: "Don't use traits merely to organize code". `XxxService` + `XxxServiceImpl` 쌍을 만들지 않는다.

## 결정성 — 같은 입력이면 같은 출력

| 비결정 원인 | 대책 | 강제 |
|---|---|---|
| HashMap 순회 순서 (무작위 시드) | 출력 경로는 `BTreeMap`·`BTreeSet` 또는 정렬 | `disallowed-types`, `iter_over_hash_type`(for 루프만. iterator 체인은 못 잡는다) |
| 시계 | `now` 를 인자로 받는다 | `disallowed-methods` |
| 난수 | core 의 직접 의존성에 두지 않는다. 시뮬레이션은 시드 고정 RNG 하나 | 리뷰. geo 0.33 이 `rand` 를 normal 의존성으로 가져와 `cargo tree` 금지 목록에는 넣지 않는다 |
| f64 초월함수 | 결과를 정수 단위로 양자화, 판정 경계에 tolerance band | golden 테스트 |
| 툴체인·계산 crate 버전 | `rust-toolchain.toml` 고정, 올리는 PR 에서 golden diff 확인 | CI |

```rust
// ❌ BAD: HashMap 순회 순서가 출력 순서가 된다 → 실행마다 golden 이 깨진다
let mut by_segment: HashMap<SegmentId, Vec<i64>> = HashMap::new();
// ✅ GOOD: 출력으로 나가는 집계는 순서가 정해진 컬렉션
let mut by_segment: BTreeMap<SegmentId, Vec<i64>> = BTreeMap::new();
impl Peer {
    // ❌ BAD: core 가 시계를 읽는다 → 테스트가 시간을 제어하지 못한다 (clippy: disallowed_methods)
    pub fn is_idle(&self) -> bool { Instant::now().duration_since(self.last_seen) >= IDLE }
    // ✅ GOOD: 시간은 값으로 받는다
    pub fn is_idle_at(&self, now_ms: u64) -> bool { now_ms.saturating_sub(self.last_seen_ms) >= IDLE_MS }
}
```

**부동소수점.** std 문서는 f64 의 sin·cos·sin_cos·tan·atan2·hypot·exp·powf·powi·ln·asin·acos·atan·cbrt·to_radians·to_degrees 를 "Unspecified precision" 으로 적는다 (플랫폼·버전·호출마다 다를 수 있다). sqrt 와 mul_add 는 결과가 보장된다. 양자화해도 반올림 경계 근처 값은 마지막 ulp 차이로 정수 결과가 뒤집힐 수 있다. **먼저 정할 것 — 재현성 수준.** 아키텍처가 달라도 비트 단위로 같아야 하나, 같은 verdict 면 충분한가. 비트 단위라면 libm 이나 고정소수점을 검토하는데, libm 의 아키텍처 간 결정성은 문서에 없다 (⚠️ x86_64·aarch64 golden 비교로 확인). verdict 수준이면 tolerance band + 툴체인 고정으로 충분하다.

## ENGINE_VERSION 과 결과 키

```rust
/// 판정 출력이 달라지는 변경마다 올린다. 패키지 버전(CARGO_PKG_VERSION)과 따로 관리한다
pub const ENGINE_VERSION: u32 = 3;
```

- `CARGO_PKG_VERSION` 에 묶으면 출력과 무관한 변경에도 재판정이 쏟아지고, 반대로 geo·libm·툴체인을 올려 출력이 바뀐 경우는 놓친다. 결과는 `(activity_id, engine_version)` 으로 upsert 한다. 이전 버전 결과가 남아 비교와 롤백이 된다. SQL 은 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md). golden snapshot 본문에 `engine_version` 을 넣어 버전과 출력이 함께 리뷰되게 한다 ([rust-testing](../rust-testing/SKILL.md)).
- 올리는 규칙은 업계 표준 출처가 없는 **설계 제안**이다 (⚠️ 팀 합의 필요): golden diff 가 생기면 올리고, 없으면 유지한다. 올린 뒤 기존 결과를 다시 판정할지(backfill)는 운영 결정이다.

**먼저 정할 것 — 판정 임계값(Params)의 위치.**

| Params 위치 | 결과를 재현하는 키 | 장점 | 단점 |
|---|---|---|---|
| core 코드 상수 | `engine_version` 하나 | 단순. golden 이 Params 까지 고정 | 임계값을 바꾸려면 배포 |
| DB·설정 | `engine_version` + `params_hash` | 배포 없이 조정 | 해시 정의(고정 순서 직렬화)를 테스트로 고정하고 결과에 함께 저장 |

## 단위 타입 — 직접 만든 newtype vs uom

단위 몇 개(`Meters`, `Seconds`, `EpochMs`, `Lat`)와 연산 몇 개면 newtype 을 직접 만들고 필요한 `impl Div<Seconds> for Meters` 만 구현한다. 차원 연산이 많을 때만 uom 을 쓴다. uom 은 기본 feature 에 `autoconvert`·`f32`·`f64`·`si`·`std` 가 켜져 있어 줄이려면 `default-features = false` 로 시작한다. `Lat::new(v) -> Result<Self, InputRejection>` 처럼 경계에서 한 번 검사하는 newtype 기본은 [rust-idioms](../rust-idioms/SKILL.md).

## Anti-Patterns

| 실수 | 문제 | 해결 |
|---|---|---|
| lib + bin 을 한 패키지에 | core 가 tokio·sqlx 를 import 해도 Cargo 가 못 막는다 | workspace 로 나누고 `cargo tree` CI |
| core 에 async Repository trait 주입 | core 가 async 와 DB 타입에 묶인다 | shell 이 값을 먼저 읽어 넘긴다 |
| 미통과·부정 의심을 `Err` 로 | `?` 로 전파돼 재시도되고 정상 결과가 dead-letter 에 쌓인다 | `Ok(Judgement)` 의 `Rejected`·`Flagged`·`NotPassed` |
| 구현 하나에 trait + `Arc<dyn>` | async fn 이면 E0038. 아니어도 간접 호출만 는다 | concrete 부터, 필요할 때 generic |
| 출력에 HashMap 순회 순서 | golden 이 실행마다 깨진다 | BTreeMap 또는 정렬 |
| `ENGINE_VERSION = CARGO_PKG_VERSION` | 무관한 변경에 재판정, 계산 crate 업그레이드는 놓침 | 명시 상수 + golden |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[경계 검증]** — core 마다 위 `cargo tree` 스크립트가 exit 0 이고, core 에 tokio 를 임시로 넣으면 exit 1 이 된다. `[dependencies]` 에 바로 넣은 경우와 `optional = true` 로 넣고 shell 이 feature 로 켠 경우를 둘 다 확인한다 (도입 시 한 번). `cargo test -p <name>-core` 가 tokio runtime·DB·sleep 없이 통과한다
2. **[lint 검증]** — rust-idioms lint 템플릿 + `iter_over_hash_type` 으로 `cargo clippy --workspace --all-targets -- -D warnings` 통과. 금지 항목(`Instant::now`, `SystemTime::now`, `HashMap`, `HashSet`)마다 BAD 예시를 한 번 넣어 경고가 실제로 나는지 확인했다
3. **[결정성]** — 같은 입력으로 `judge()` 를 두 번 부른 결과가 같다는 테스트가 있고 golden snapshot 에 `engine_version` 이 들어 있다. 툴체인·계산 crate 를 올리는 PR 은 golden diff 로 `ENGINE_VERSION` 을 판단했다
4. **[설계 결정 기록]** — 재현성 수준과 Params 위치를 ADR 에 남겼다. 정하지 않았으면 엔진 코드에 단정하지 않는다
5. **[일관성]** — [Rust rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 house rule(`too-many-lines-threshold = 100` 명시, `excessive-nesting-threshold = 4`, `unwrap_used = "warn"` + `allow-unwrap-in-tests`, `cognitive_complexity` 미사용, concrete > generic > dyn, release `panic = "unwind"`)과 workspace Cargo.toml·crate 별 clippy.toml 이 일치한다

## 참조 스킬

- [rust-idioms](../rust-idioms/SKILL.md) — Composed Method, lint 템플릿 전체, newtype 기본, 모듈·파일 분할 · rust-error-handling — 경계별 에러 enum, 분류 지점 한 곳, panic 정책 · [rust-async-tokio](../rust-async-tokio/SKILL.md) — CPU 오프로드(rayon vs spawn_blocking + Semaphore), 종료, 관측성
- [rust-testing](../rust-testing/SKILL.md) — golden fixture, insta, fake vs mockall · rust-from-spring — Spring 개념 → Rust 대응표
- [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) · rust-og-image-render · rust-crdt-sync · rust-geo-track — 엔진별 shell·core 세부 · `/architecture:hexagonal-clean-architecture` — Ports & Adapters 일반론 · `/dx:clean-code` — Composed Method·SLAP 원칙

## Sources / Verified

출처·인용·상태의 전문과 로컬 실측(scratch workspace) 기록은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. 다음 재검증은 2027-02.

- [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) · [Cockburn — Hexagonal](https://alistair.cockburn.us/hexagonal-architecture/) · [rust-analyzer architecture](https://rust-analyzer.github.io/book/contributing/architecture.html) · [quinn-proto](https://docs.rs/quinn-proto/latest/quinn_proto/) · [rustls](https://docs.rs/rustls/latest/rustls/) · [Firezone — sans-IO](https://www.firezone.dev/blog/sans-io) · [Polar Signals — DST](https://blog.polarsignals.com/blog/posts/2025/07/08/dst-rust) · [Book 7.1](https://doc.rust-lang.org/book/ch07-01-packages-and-crates.html) · [Book 12.3](https://doc.rust-lang.org/book/ch12-03-improving-error-handling-and-modularity.html) · [Cargo targets](https://doc.rust-lang.org/cargo/reference/cargo-targets.html) · [cargo#1982](https://github.com/rust-lang/cargo/issues/1982) — 검증일 2026-11-15 · ✅ verified (Firezone·Polar Signals 는 스타트업 사례, Book 12.3 절 제목 정정 반영) · subagent
- [Microsoft guidelines — AI (M-RUST-SHAPED)](https://microsoft.github.io/rust-guidelines/guidelines/ai/index.html) · [Libraries/UX (M-DI-HIERARCHY, M-BALANCED-MODULES)](https://microsoft.github.io/rust-guidelines/guidelines/libs/ux/index.html) · [Resilience (M-MOCKABLE-SYSCALLS)](https://microsoft.github.io/rust-guidelines/guidelines/libs/resilience/index.html) — 검증일 2026-11-15 · ✅ verified (library 장을 앱에 적용한 것은 해석. 사다리의 enum·dyn 단계 문구는 Claude 가 원문 재확인) · subagent, Claude
- [Bulletproof Rust Web — anti-patterns](https://gruberb.github.io/bulletproof-rust-web/anti-patterns.html) — 검증일 2026-11-15 · ⚠️ 커뮤니티 1인 자료, 저자 동일인 여부 미확인 · subagent
- [Cargo workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html) · [resolver](https://doc.rust-lang.org/cargo/reference/resolver.html) · [profiles](https://doc.rust-lang.org/cargo/reference/profiles.html) · [matklad — Large Rust Workspaces](https://matklad.github.io/2021/08/22/large-rust-workspaces.html) — 검증일 2026-11-15 · ✅ verified (release 기본 `panic = 'unwind'` 은 profiles 문서) + 로컬 실측(cargo 1.96: 멤버 `[lints]` 에 `workspace = true` 와 lint 를 함께 두면 "cannot override `workspace.lints` in `lints`" 로 실패. 문서에는 이 제한 문장이 없다. shell 의 `#[expect(clippy::iter_over_hash_type, reason)]` 은 fn·statement 둘 다 통과) · subagent, Claude
- [cargo tree](https://doc.rust-lang.org/cargo/commands/cargo-tree.html) — 검증일 2026-11-15 · ✅ verified + 로컬 실측(통과·tokio 주입 시 실패·dev-dependency 통과, `--all-features` 없으면 feature 로 켠 optional tokio 를 놓침, 오타 시 pipe 형태 조용히 통과) · subagent, Claude
- [crates.io — geo 0.33.0 dependencies](https://crates.io/api/v1/crates/geo/0.33.0/dependencies) · [sqlx v0.9.0 query_as.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/query_as.rs) — 검증일 2026-11-15 · ✅ verified (`rand ^0.10.0` normal·non-optional. geo 를 넣은 core 에서 `rand` 정규식은 exit 1 로 오탐함을 로컬 실측. `fetch_one` 은 `fetch_optional` 결과에 `ok_or(Error::RowNotFound)` 를 붙인 것이고 로컬 registry 소스와 대조했다. `RowNotFound` → Transient 는 scratch 테스트) · Claude
- [Clippy lint configuration](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/book/src/lint_configuration.md) · [Clippy configuration](https://raw.githubusercontent.com/rust-lang/rust-clippy/master/book/src/configuration.md) · [Clippy lint list](https://clippy.rust-lang.org/master/index.html) — 검증일 2026-11-15 · ✅ verified + 로컬 실측(가장 가까운 파일만 읽고 병합 없음, `disallowed_*`·`iter_over_hash_type` 발화, `std::fs::File`·`std::env::var` 등 항목 경로는 발화하고 모듈 경로 `std::fs` 는 "expected a type/function, found a module" 경고만) / ⚠️ lint configuration 의 "없는 경로면 에러" 서술과 로컬 clippy 1.96 동작(경고만, `-D warnings` 로도 exit 0, 의존성에 없는 crate 경로는 무시)이 다름. 1.97+ 동작은 미측정 · subagent, Claude
- [Reference — diagnostics (`must_use`)](https://doc.rust-lang.org/reference/attributes/diagnostics.html) · [type system (`non_exhaustive`)](https://doc.rust-lang.org/reference/attributes/type_system.html) · [traits (dyn compatibility)](https://doc.rust-lang.org/reference/items/traits.html) — 검증일 2026-11-15 · ✅ verified (`must_use` 는 struct·enum·union·함수·trait 에 붙는다) + 로컬 실측(`double_must_use`, E0038, Send 누락) · subagent, Claude
- [std BTreeMap::extract_if](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html#method.extract_if) · [Rust RELEASES.md](https://raw.githubusercontent.com/rust-lang/rust/master/RELEASES.md) · [rust#109417 (return type notation)](https://github.com/rust-lang/rust/issues/109417) — 검증일 2026-11-15 · ✅ verified (`extract_if` 는 1.91.0 안정화, RTN 은 1.100.0 노트까지 안정화 기록 없음) + 로컬 실측(RTN E0658) · Claude
- [axum dependency-injection 예제 (axum-v0.8.9 태그)](https://raw.githubusercontent.com/tokio-rs/axum/axum-v0.8.9/examples/dependency-injection/src/main.rs) · [Google Rust Style Guide](https://raw.githubusercontent.com/google/styleguide/gh-pages/rustguide.md) · [async-trait](https://docs.rs/async-trait/latest/async_trait/) · [trait-variant](https://docs.rs/trait-variant/0.1.3/trait_variant/attr.make.html) · [tokio spawn_blocking](https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html) · [std HashMap](https://doc.rust-lang.org/std/collections/struct.HashMap.html) · [std f64](https://doc.rust-lang.org/std/primitive.f64.html) · [std Instant](https://doc.rust-lang.org/std/time/struct.Instant.html) · [uom features](https://docs.rs/crate/uom/0.38.0/features) — 검증일 2026-11-15 · ✅ verified (uom 기본 feature 는 정정값 반영) · subagent
- [libm](https://docs.rs/libm/latest/libm/) — 검증일 2026-11-15 · ⚠️ 아키텍처 간 bit-exact 결정성은 문서에 없음. 대상 아키텍처별 golden 비교로 확인 · subagent
