---
name: rust-async-tokio
description: "Tokio 비동기 운영 패턴 — CPU 작업 rayon·spawn_blocking 분리, actor·bounded channel, select! 취소 안전성, CancellationToken 종료 처리, Mutex 선택, tracing·OpenTelemetry·metrics·healthz. Use when Rust 서비스의 동시성·종료 처리를 설계하거나 async 코드가 멈추거나 Send 에러가 날 때."
---

# Rust Async with Tokio — 동시성·종료·관측성 운영 패턴

엔진의 shell(큐 워커·내부 HTTP 서버·WebSocket 서버)이 Tokio 위에서 돌 때의 공통 규칙이다. 큐 SQL·렌더·CRDT 세부는 각 skill 이 맡는다. Java 로 치면 `ExecutorService`·`BlockingQueue`·`CompletableFuture`·Actuator 가 하던 일이다. 코드 블록은 길이 때문에 한 줄로 모은 곳이 있으니 복사하면 `cargo fmt` 를 돌린다.

## Quick Reference (결정 트리)

```
이 작업은 어디서 돌릴까?
├── 소켓·DB 를 기다린다 (.await) ────────> 그냥 async (같은 task 또는 tokio::spawn)
├── 블로킹 IO · sync 라이브러리 ─────────> spawn_blocking + IO 전용 Semaphore (permit 은 클로저 안)
├── CPU 계산 (판정·렌더) ────────────────> spawn_blocking + CPU 전용 Semaphore (CpuGate, permit = 코어 수 시작값, 측정 후 조정)
├── CPU 가 처리량을 좌우한다 (측정 후) ───> rayon::spawn + oneshot (panic_handler 필수)
└── 블로킹(동기)으로 계속 도는 루프 ─────> 전용 std::thread

여러 task 가 같은 상태를 쓴다?
├── 잠금 구간에 .await 가 없다 ──────────> std::sync::Mutex
├── .await 너머로 쥐어야 하는 IO 자원 ───> tokio::sync::Mutex
└── 한 소유자가 순서대로 처리하면 된다 ──> actor (bounded mpsc + oneshot 응답)

spawn 한 task 를 어떻게 모을까?
├── 고정 컴포넌트 (워커 루프·ops 서버) ──> JoinSet — main 이 결과·panic 을 받는다 (drop 하면 abort)
├── 동시 수를 세서 빈 슬롯을 채우는 job ─> 루프가 쥔 JoinSet — join_next 를 select! 분기로 받는다
└── 결과가 필요 없는 요청 task ──────────> TaskTracker — Err 는 task 안에서 처리, 치명 실패만 drop_guard (성공 시 disarm)
```

- 루프 안 `select!` 에서 매번 새로 만드는 future, 진 쪽의 부분 진행을 잃으면 안 되는 future 는 cancel safe 여야 한다 (§3). 한 번만 도는 `select!`(종료 신호 대기)는 진 쪽을 버려도 되는지만 확인한다. 슬롯을 채우는 job 루프는 [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) §6 이다. 종료 예산은 `preStop + drain + ops 종료 + telemetry flush < terminationGracePeriodSeconds` (§4).

## 1. CPU 작업 분리 — spawn_blocking 과 rayon

async task 안에서 오래 계산하면 같은 worker thread 의 다른 task 가 모두 멈춘다. 계산은 runtime 밖으로 보낸다.

| 수단 | 맞는 일 | 주의 |
|---|---|---|
| `spawn_blocking` | blocking IO, sync 라이브러리, 상한을 건 CPU 계산 (판정·렌더) | 스레드 상한 기본 512. **abort 할 수 없고** runtime drop 이 무기한 기다린다 → Semaphore 상한, `Runtime::shutdown_timeout` (§4). Alice Ryhl: 비싼 CPU 계산에는 "poorly suited" |
| `rayon::spawn` + `oneshot` | 측정해 보니 CPU 가 처리량을 좌우할 때 | 기본 스레드 수는 `RAYON_NUM_THREADS` 또는 논리 CPU 수. 전역 풀은 한 번만 초기화. `panic_handler` 가 없으면 클로저 panic 이 **프로세스를 abort** |

**permit 은 blocking 클로저 안으로 옮기고, job 세마포어와 CPU 세마포어는 따로 둔다.** 하나를 같이 쓰면 job N개가 permit N개를 모두 쥔 채 CPU permit 을 기다리며 영원히 멈춘다.

```rust
// ❌ BAD: 호출자가 취소되면 permit 은 반환되지만 blocking 작업은 계속 돈다 → 상한이 깨진다
let _permit = Arc::clone(&self.permits).acquire_owned().await?;
Ok(tokio::task::spawn_blocking(f).await?)
// ✅ GOOD: CpuGate { permits: Arc<Semaphore> } — permit 이 클로저와 함께 움직인다
pub async fn run<T, F>(&self, f: F) -> Result<T, ComputeError>
where
    F: FnOnce() -> T + Send + 'static,
    T: Send + 'static,
{
    let permit = Arc::clone(&self.permits).acquire_owned().await?;
    let task = tokio::task::spawn_blocking(move || {
        let _permit = permit; // 계산이 실제로 끝날 때 반환된다
        f()
    });
    Ok(task.await?)
}
pub async fn handle_job(jobs: Arc<Semaphore>, cpu: CpuGate, job: Job) -> Result<Verdict, ComputeError> {
    let _job_permit = jobs.acquire_owned().await?; // job 동시성(DB 연결·lease 수). 실제 워커는 claim 전에 얻는다
    let track = load_track(&job).await; // IO 를 기다리는 동안 CPU permit 을 쥐지 않는다
    cpu.run(move || judge(&track)).await // CPU 동시성 상한(코어 수에서 시작해 측정 후 조정)
}
```

- **왜 `CpuGate` 인가** — 동시 계산 수를 묶으라는 것이 tokio 문서의 권고다: "a semaphore or some other synchronization primitive should be used to limit the number of computations executed in parallel" (rayon 도 맞을 수 있다고 한다). Alice Ryhl 은 blocking 풀이 비싼 CPU 계산에 "poorly suited" 한 이유로 스레드가 코어 수보다 훨씬 많다는 점을 들면서도("CPU-bound computations run most efficiently if the number of threads is equal to the number of CPU cores"), 계산이 몇 개뿐이면("if you only need a few CPU-bound computations") `spawn_blocking` 도 탓하지 않는다고 한다. 코어 수로 묶으면 과다 구독을 줄이지만 tokio worker 도 같은 코어를 쓰므로 없애지는 못한다. permit = 코어 수는 이 skill 의 시작값이고 공식 수치가 아니다. 측정해서 조정한다. **rayon 으로 옮길 때** — 측정해서 CPU 가 처리량을 좌우하면 옮긴다. 결과는 `oneshot` 으로 돌려받는다. 클로저가 panic 하면 `tx` 가 drop 되어 `rx` 가 에러를 받는다. 전역 풀은 main 에서 한 번 `ThreadPoolBuilder::new().num_threads(n).panic_handler(|_| tracing::error!(..)).build_global()?` 로 만든다. `ComputeError` 는 `AcquireError`·`JoinError` 를 `#[from]` 으로 받는 enum 이다 ([rust-error-handling](../rust-error-handling/SKILL.md)).

```rust
pub async fn on_rayon<T, F>(f: F) -> Result<T, ComputeError>
where
    F: FnOnce() -> T + Send + 'static,
    T: Send + 'static,
{
    let (tx, rx) = oneshot::channel();
    rayon::spawn(move || {
        let _ = tx.send(f()); // 호출자가 취소됐으면 받을 쪽이 없다
    });
    rx.await.map_err(|_| ComputeError::Panicked)
}
```

- 컨테이너에서는 스레드 수를 CPU limit 에 맞춰 명시한다 (`TOKIO_WORKER_THREADS`, `RAYON_NUM_THREADS`). `available_parallelism` 은 cgroup 정보를 읽지 못하면 실제보다 크게 셀 수 있다. job permit 은 claim(lease 획득) 전에 얻어, 처리하지 못할 lease 를 쥔 채 기다리지 않는다. DB 트랜잭션(`FOR UPDATE`)을 연 채로 계산하지 않는다 ([rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md)). 요청을 거절할 수 있는 서버는 `try_acquire_owned` 실패를 503 으로 돌려준다 (rust-og-image-render).

## 2. Actor 와 채널 — 공유 상태 대신 소유자 하나

Alice Ryhl 의 "Actors with Tokio" 패턴이다. 상태를 가진 task 하나와, 그 task 에 메시지를 보내는 `Clone` 가능한 handle 로 나눈다. 싱글톤 `@Service` 가 `synchronized` 로 지키던 상태를 "한 task 만 만진다" 로 바꾼다.

```rust
enum Command {
    Get { key: String, reply: oneshot::Sender<Option<u64>> },
    Put { key: String, value: u64 },
}
struct Store {
    commands: mpsc::Receiver<Command>,
    entries: HashMap<String, u64>, // 이 task 만 만지므로 잠금이 필요 없다
}
impl Store {
    async fn run(mut self) {
        while let Some(command) = self.commands.recv().await {
            self.handle(command);
        } // 모든 StoreHandle 이 drop 되면 None → actor 종료
    }
    fn handle(&mut self, command: Command) {
        match command {
            Command::Get { key, reply } => {
                let _ = reply.send(self.entries.get(&key).copied()); // 호출자가 취소됐으면 버린다
            }
            Command::Put { key, value } => {
                self.entries.insert(key, value);
            }
        }
    }
}
#[derive(Clone)]
pub struct StoreHandle {
    commands: mpsc::Sender<Command>,
}
impl StoreHandle {
    pub fn spawn(capacity: usize) -> Self {
        let (commands, rx) = mpsc::channel(capacity); // 가득 차면 send 가 기다린다 = backpressure
        tokio::spawn(Store { commands: rx, entries: HashMap::new() }.run()); // handle 은 버린다 — actor 가 멈추면 호출자가 StoreStopped 로 안다
        Self { commands }
    }
    pub async fn get(&self, key: &str) -> Result<Option<u64>, StoreStopped> {
        let (reply, response) = oneshot::channel();
        let command = Command::Get { key: key.to_owned(), reply };
        // SendError·RecvError 는 "actor 가 없다" 외의 원인 정보를 담고 있지 않다
        self.commands.send(command).await.map_err(|_| StoreStopped)?;
        response.await.map_err(|_| StoreStopped)
    }
}
```

| 채널 | 동작 | 함정 |
|---|---|---|
| `mpsc` (bounded) | 가득 차면 `send().await` 가 기다린다 → backpressure | actor 끼리 bounded 채널로 순환(A→B→A)하면 deadlock. 되돌리는 쪽은 `oneshot`·`try_send` |
| `oneshot` | 요청 1번에 응답 1번 | 받는 쪽이 사라졌으면 `send` 가 Err — 무시해도 된다 |
| `watch` | 마지막 값만 보관 | 중간 값은 건너뛴다 |
| `broadcast` | 모든 receiver 에 복제 | 느린 receiver 는 `Lagged(n)` 뒤 계속 받는다. receiver 0개면 `send` 가 Err 다. 이후 send 까지 실패한다는 뜻은 아니다(새로 `subscribe` 가능). 버려도 되는 값이면 무시한다. Lagged 면 `resubscribe()` 먼저, 그다음 snapshot ([rust-crdt-sync](../rust-crdt-sync/SKILL.md)) |

## 3. select! 와 취소 안전성

`tokio::select!` 는 한 분기가 끝나면 **나머지 future 를 drop(취소)한다**. 루프에서 매번 새로 만드는 future 가 중간까지 일했다면 그 일은 사라진다. 한 번만 도는 `select!`(§4 의 종료 신호 대기)는 진 쪽을 버려도 되면 문제없다.

| 루프 안에 넣어도 된다 (문서상 cancel safe) | 넣으면 안 된다 |
|---|---|
| `mpsc`·`broadcast` `recv`, `watch::Receiver::changed`, `TcpListener::accept`, `Signal::recv`, `AsyncReadExt::read`, `StreamExt::next`, `Interval::tick`, `JoinSet::join_next`, `CancellationToken::cancelled` | 데이터 유실: `read_exact`, `read_to_end`, `read_to_string`, `write_all` · 대기 순서를 잃음: `Mutex::lock`, `RwLock::read`·`write`, `Semaphore::acquire`, `Notify::notified` |

```rust
// ❌ BAD: command 가 먼저 오면 읽던 read_frame 이 취소된다. 이미 읽은 바이트는 사라지고 스트림이 어긋난다
loop {
    tokio::select! {
        frame = read_frame(&mut socket) => handle_frame(frame?),
        command = commands.recv() => match command { Some(c) => apply(c), None => return Ok(()) },
    }
}
// ✅ GOOD: 프레임 읽기는 전용 task 가 끝까지 하고, select! 에는 cancel safe 한 recv 만 둔다
pub async fn serve<R>(socket: R, mut commands: mpsc::Receiver<Command>, token: CancellationToken) -> io::Result<()>
where
    R: AsyncRead + Unpin + Send + 'static,
{
    let (frame_tx, mut frames) = mpsc::channel(32);
    let mut reader = JoinSet::new(); // serve 가 끝나 drop 되면 reader task 도 abort 된다
    reader.spawn(read_frames(socket, frame_tx)); // 프레임 경계의 EOF 는 Ok, 깨진 프레임은 Err
    loop {
        tokio::select! {
            biased; // 종료 신호를 먼저 본다. 순서가 고정되므로 frames 가 쉬지 않으면 commands 가 밀린다
            () = token.cancelled() => return Ok(()),
            frame = frames.recv() => match frame { Some(f) => handle_frame(f), None => break }, // reader 가 끝났다
            command = commands.recv() => match command { Some(c) => apply(c), None => return Ok(()) },
        }
    }
    match reader.join_next().await {
        Some(exit) => exit?, // reader 의 io 에러·panic(JoinError → io::Error)을 호출자에게 돌려준다
        None => Ok(()),
    }
}
```

- `Some(x) = rx.recv()` 처럼 패턴을 쓰면 안 맞는 분기는 꺼진다. 모든 분기가 꺼질 수 있는데 `else` 가 없으면 **panic** 이다. 위처럼 `match` 로 `None` 을 처리하거나, 꺼지지 않는 분기를 함께 둔다(§4 main 의 종료 신호 분기). 주기 polling 은 `interval` + `set_missed_tick_behavior(MissedTickBehavior::Delay)`. 기본값 Burst 는 긴 처리 뒤 밀린 tick 을 몰아서 낸다. sqlx `PgListener::recv`·`try_recv` 는 문서에 cancel safety 가 없다. 전용 task 로 감싼다 ([rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md)).

## 4. 종료 처리 — CancellationToken + JoinSet

K8s 는 `preStop` 을 먼저 실행하고 그다음 SIGTERM 을 보낸다. `preStop` 도 grace(기본 30초) 안에서 돌고, grace 가 끝나면 SIGKILL 이다. `ctrl_c()` 는 Unix 에서 SIGINT 만 받는다. SIGTERM·SIGINT 둘 다 `signal()` 로 시작할 때 설치해 설치 실패를 바로 드러낸다. ops 서버(`/healthz`·`/metrics`, 요청을 받는 서버는 `/readyz` 도)는 워커와 다른 토큰을 받아 워커 drain 이 끝난 뒤 닫는다. 같은 토큰이면 drain 구간에 `/healthz` 가 connection refused 가 되고 메트릭이 사라진다. `/readyz` 와 `start_draining` 은 Service 트래픽을 받는 HTTP·WS 서버(og-render, sync)용이다. 트래픽이 없는 큐 워커는 `/healthz`·`/metrics` 만 두고 그 줄을 빼며, ops 토큰은 그래도 분리한다 ([rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) §9). 컴포넌트는 모두 `anyhow::Result<()>` 를 반환한다.

```rust
#[tokio::main] // 종료 때 spawn_blocking 계산이 drain 예산을 넘길 수 있으면 아래 bullet 의 Builder + shutdown_timeout 형태로
async fn main() -> anyhow::Result<()> {
    let provider = telemetry::init_telemetry("engine-shell")?;
    let metrics = metrics_setup::install_metrics()?;
    let (sigterm, sigint) = (signal(SignalKind::terminate())?, signal(SignalKind::interrupt())?); // 설치 실패는 시작 단계에서 드러낸다
    let (work_token, ops_token, health) = (CancellationToken::new(), CancellationToken::new(), Health::default());
    let mut workers = JoinSet::new(); // 고정 컴포넌트 — 결과와 panic 을 main 이 받는다
    workers.spawn(worker_loop(health.clone(), work_token.clone()));
    let mut ops = JoinSet::new(); // drain 중에도 /healthz·/metrics(서버는 /readyz 도)가 응답하도록 토큰을 따로 둔다
    ops.spawn(serve_ops(ops_router(health.clone(), metrics.clone()), ops_token.clone()));
    ops.spawn(upkeep_metrics(metrics, ops_token.clone())); // §6
    let mut healthy = tokio::select! {
        () = shutdown_signal(sigterm, sigint) => { tracing::info!("shutdown signal received"); true }
        Some(exit) = workers.join_next() => { log_exit(exit); false } // 먼저 끝난 컴포넌트는 이상이다
        Some(exit) = ops.join_next() => { log_exit(exit); false }
    };
    health.start_draining(); // 요청을 받는 서버만: 이제부터 /readyz 는 503, ops 서버는 아직 열려 있다
    work_token.cancel();
    healthy &= drain(&mut workers, DRAIN_BUDGET).await;
    ops_token.cancel(); // 워커가 끝난 뒤 닫는다 — drain 구간의 메트릭도 scrape 된다
    healthy &= drain(&mut ops, OPS_CLOSE_BUDGET).await;
    provider.shutdown()?; // 남은 span 을 보낸다
    anyhow::ensure!(healthy, "a component failed"); // exit code 1 로 실패를 드러낸다
    Ok(())
}
async fn drain(set: &mut JoinSet<anyhow::Result<()>>, budget: Duration) -> bool {
    let all_ok = async { let mut ok = true; while let Some(exit) = set.join_next().await { ok &= log_exit(exit) } ok };
    match tokio::time::timeout(budget, all_ok).await {
        Ok(all_ok) => all_ok,
        Err(_) => { tracing::error!("drain budget exceeded"); false } // 남은 task 는 main 이 끝나며 JoinSet drop 으로 abort
    }
}
fn log_exit(exit: Result<anyhow::Result<()>, JoinError>) -> bool {
    match exit {
        Ok(Ok(())) => true,
        Ok(Err(e)) => { tracing::error!("component failed: {e:#}"); false }
        Err(e) => { tracing::error!(panic = e.is_panic(), "component aborted: {e}"); false } // panic 메시지도 tracing 로그로
    }
}
async fn shutdown_signal(mut sigterm: Signal, mut sigint: Signal) {
    tokio::select! {
        _ = sigterm.recv() => {} // K8s 가 보내는 SIGTERM
        _ = sigint.recv() => {} // 로컬 Ctrl+C
    }
}
async fn serve_ops(app: Router, token: CancellationToken) -> anyhow::Result<()> {
    let listener = tokio::net::TcpListener::bind(OPS_ADDR).await?;
    Ok(axum::serve(listener, app).with_graceful_shutdown(token.cancelled_owned()).await?) // 'static future 필요
}
```

- 결과가 필요 없고 수가 정해지지 않은 요청 task 는 `TaskTracker`(tokio-util `rt` feature)로 모으고, 종료 때 `close()` 다음 `wait()` 한다. close 하지 않으면 wait 가 끝나지 않는다. TaskTracker 는 결과를 모아 주지 않으므로(`spawn` 이 돌려준 `JoinHandle` 을 버리면 Err·panic 도 사라진다) `Err` 는 task 안에서 처리한다(요청은 500). 동시 수를 세어 빈 슬롯만큼 claim 하는 job 은 TaskTracker 가 아니라 루프가 쥔 `JoinSet` 에 담고 `join_next` 를 `select!` 분기로 받는다. drain 함수 안에서 기다리면 그동안 슬롯을 못 채우고 heartbeat 가 멈춘다 ([rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) §6). 프로세스를 멈춰야 하는 실패만 루트 토큰을 취소한다. 그럴 때는 `root.clone().drop_guard()` 를 task 안으로 옮기고, 정상 경로와 처리한 실패 경로에서 `guard.disarm()` 한다. **`DropGuard` 는 drop 될 때 무조건 cancel 하므로, disarm 하지 않으면 요청이 성공할 때마다 서비스 전체가 종료된다.** panic 이면 tokio 가 poll 의 panic 을 잡는 과정에서 task future 를 drop 하므로 guard 도 drop 되어 루트가 취소된다(`panic = "unwind"` 전제, §7). child 토큰을 취소해도 부모는 취소되지 않는다.
- `with_graceful_shutdown` 은 진행 중 요청을 끝까지 기다린다. 멈춘 요청이 종료를 막지 않게 `TimeoutLayer::with_status_code(..)` 를 건다 (`new` 는 deprecated). `spawn_blocking` 계산은 abort 되지 않는다. `#[tokio::main]` 은 runtime 을 감추므로 main 이 반환해도 runtime drop 이 남은 계산을 **무기한** 기다린다. 예산을 강제하려면 `Builder::new_multi_thread().enable_all().build()?` 로 runtime 을 직접 만들고 `rt.block_on(run())` 뒤에 `rt.shutdown_timeout(..)` 을 부른다. 예: grace 30초 = preStop 5초 + drain 20초 + ops 종료 2초 + flush 여유. preStop 이 넘치면 2초를 한 번 더 줄 뿐이다. shell 이 없는 distroless 이미지는 `lifecycle.preStop.sleep`(K8s 1.34 GA)을 쓴다.

## 5. Mutex 선택과 Send 에러

`tokio::spawn` 은 `Send + 'static` future 만 받는다. `.await` 너머로 들고 가는 값 하나라도 `Send` 가 아니면 컴파일이 실패한다.

| 상황 | 선택 |
|---|---|
| 잠금 구간이 짧고 그 안에 `.await` 가 없다 | `std::sync::Mutex` — tokio 문서: 일반 데이터에는 "ok and often preferred". 튜토리얼: "A common error is to unconditionally use tokio::sync::Mutex" |
| DB 연결 같은 IO 자원을 `.await` 너머로 쥐어야 한다 | `tokio::sync::Mutex` 또는 actor (§2) |

```rust
// ❌ BAD: guard 를 쥔 채 .await → tokio::spawn 에서 "future cannot be sent between threads safely"
let mut s = stats.lock().expect("no code panics while holding the stats lock");
s.processed += 1;
sink.flush(s.processed).await;
// ✅ GOOD: 블록이 끝날 때 guard 가 drop 된다. .await 에는 값만 들고 간다
let processed = {
    let mut s = stats.lock().expect("no code panics while holding the stats lock");
    s.processed += 1;
    s.processed
};
sink.flush(processed).await;
```

- 공개 trait 의 `async fn` 은 future 의 `Send` 를 보장하지 않는다 → `-> impl Future<Output = T> + Send`. dyn 이 필요할 때는 [rust-engine-architecture](../rust-engine-architecture/SKILL.md). yrs `Awareness` 는 기본 설정에서 `Send` 가 아니다 → [rust-crdt-sync](../rust-crdt-sync/SKILL.md).

## 6. 관측성 — tracing, OpenTelemetry, metrics, health

```rust
// tracing-subscriber: features = ["env-filter", "json"]
// opentelemetry-otlp: default-features = false, features = ["grpc-tonic", "trace"] (기본 transport 는 http-proto + reqwest-blocking-client)
pub fn init_telemetry(service: &'static str) -> anyhow::Result<SdkTracerProvider> {
    let exporter = SpanExporter::builder().with_tonic().build()?; // Tokio 런타임 안에서 호출
    let provider = SdkTracerProvider::builder()
        .with_batch_exporter(exporter)
        .with_resource(Resource::builder().with_service_name(service).build())
        .build();
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")); // RUST_LOG
    tracing_subscriber::registry()
        .with(filter)
        .with(fmt::layer().json())
        .with(tracing_opentelemetry::layer().with_tracer(provider.tracer(service)))
        .try_init()?;
    Ok(provider) // main 이 종료 때 provider.shutdown() 으로 남은 span 을 보낸다
}
```

- 버전은 짝으로 올린다: `opentelemetry`·`opentelemetry_sdk`·`opentelemetry-otlp` 0.33 ↔ `tracing-opentelemetry` 0.34. 어긋나면 span 이 이어지지 않는다. OTel Rust 는 minor 마다 breaking 이 있고 traces exporter 는 아직 beta 다. tracing-subscriber 기본 feature 에 `tracing-log` 가 있어 `log` crate 로 기록하는 의존성의 레코드도 들어온다. 필터에 그 target 도 넣는다. sqlx 0.9 의 쿼리 로그는 처음부터 tracing 이벤트(target `sqlx::query`)다. 기본 JSON 출력에는 trace_id 가 없다. 필요하면 `json-subscriber` 의 `layer().with_opentelemetry_ids(true)` (feature `tracing-opentelemetry-0-34`). ID 는 `openTelemetry` 키 아래 나온다. job span 은 job 행의 traceparent 를 `TraceContextPropagator` 로 복원해 `add_link` 하거나, span 에 처음 들어가기 **전에** `set_parent` 한다. semconv: HTTP server span 이름은 `{method} {http.route}`, 4xx 는 status 를 비우고(MUST) 5xx 는 Error(SHOULD). DB span 은 `db.system.name = "postgresql"`·`db.operation.name`·`db.collection.name`. 둘 다 stable 이다. messaging 은 Development 단계이고 스펙 최신판과 Rust crate 의 schema 버전이 달라 이름이 어긋나므로 stable 속성 위주로 쓴다.

**메트릭 경로는 Go 쪽을 따른다.** Prometheus scrape 면 `metrics` + `metrics-exporter-prometheus`(`default-features = false`) 또는 `prometheus-client`, OTLP push 면 opentelemetry metrics. `prometheus`(tikv) crate 는 새 릴리스가 오래 없다(Sources 참조). `opentelemetry-prometheus` README 는 신규 프로젝트에 `opentelemetry-otlp` 를 권한다.

```rust
pub fn install_metrics() -> Result<PrometheusHandle, BuildError> {
    PrometheusBuilder::new()
        .with_recommended_naming(true) // counter 에 _total, 단위 접미사
        .set_buckets(&[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0])? // 없으면 summary 로 나간다
        .install_recorder()
}
```

- `run_upkeep()` 은 호출자 책임이다. §4 의 `upkeep_metrics` 컴포넌트가 `while token.run_until_cancelled(tick.tick()).await.is_some() { handle.run_upkeep() }` 루프를 돈다. 빼먹으면 메모리가 는다. 기본 feature 의 `install()` 은 별도 포트에서 **모든 경로**에 응답하므로, feature 를 끄고 axum `/metrics` 에서 `handle.render()` 를 돌려준다. §4 의 `Health` 는 시작 시각과 `Arc<AtomicU64>`(마지막 heartbeat, 시작 후 ms)·`Arc<AtomicBool>`(draining)을 든 `Clone` 타입이다. 워커 루프가 매 바퀴 `beat()`, 종료가 시작되면 `start_draining()` 을 부른다. `/healthz` 는 마지막 heartbeat 가 N초 이내인지, `/readyz` 는 `!draining` 인지만 본다.

| probe | 실패하면 | 무엇을 보나 |
|---|---|---|
| liveness (`/healthz`) | 컨테이너 재시작 | 자기 자신만 — 워커 루프 heartbeat. DB ping 을 넣으면 DB 순단에 모든 pod 가 재시작된다 |
| readiness (`/readyz`, 요청을 받는 서버만) | EndpointSlice 에서 제외 | 종료가 시작되면 가장 먼저 false. ops 서버는 drain 이 끝날 때까지 응답한다(§4). HTTP 서버는 의존성 상태도 |

## 7. 빌드 프로필·버전·설정

```toml
[profile.release]
lto = "thin"               # 측정 후 "fat" 검토
codegen-units = 1
panic = "unwind"           # task panic 을 JoinError 로 격리한다. abort 면 프로세스가 죽는다
debug = "line-tables-only" # (선택) backtrace 줄 번호
```

- `panic = "abort"` 는 테스트에서 무시된다. CI 는 통과하고 운영에서만 죽는다 ([rust-error-handling](../rust-error-handling/SKILL.md)). `tokio = { version = "1.54", features = [...] }` 처럼 caret 으로 둔다. `=1.54.0` 은 yanked 다. LTS(`~1.53`)에 맞춰 툴체인을 낮추는 전략은 sqlx 0.9 (Rust 1.94+) 와 함께면 의미가 없다. 아래 설정에서 `separator("_")` 면 `DATABASE_URL` 이 `database.url` 로 쪼개진다. 기본값을 명시하는 원칙은 `/architecture:config-explicit-defaults`.

```rust
// secrecy = { version = "0.10", features = ["serde"] } — SecretString 을 Deserialize 하려면 필요
#[derive(Debug, serde::Deserialize)]
pub struct Settings {
    pub database_url: SecretString, // Debug 출력은 [REDACTED]. 쓰는 곳에서만 expose_secret()
    pub job_concurrency: usize,
}
pub fn load() -> Result<Settings, config::ConfigError> {
    let env = config::Environment::with_prefix("TRACK")
        .prefix_separator("_") // 없으면 separator 를 따라가 TRACK__DATABASE_URL 을 찾는다
        .separator("__"); // TRACK_DB__POOL_SIZE → db.pool_size
    config::Config::builder().add_source(env).build()?.try_deserialize()
}
```

## Anti-Patterns

| 실수 | 문제 | 해결 |
|---|---|---|
| 상한 없는 `spawn_blocking`, permit 을 async 쪽에, job·CPU 가 같은 세마포어 | 스레드가 512개까지 는다 / 취소 시 상한이 깨진다 / 서로 기다리며 멈춘다 | permit 을 클로저 안으로, 세마포어 두 개 |
| `rayon::spawn` 에 `panic_handler` 없음 | 계산 하나의 panic 이 프로세스를 abort | `panic_handler` + oneshot |
| 루프 안 `select!` 에 `read_exact`·`Mutex::lock` 을 직접 | 데이터 유실·대기 순서 잃음 | 전용 task + mpsc (§3) |
| `TaskTracker` 만 쓰고 실패를 안 봄, 실패 뒤 exit 0 | "살아 있지만 일하지 않는" 프로세스, 실패가 정상 종료처럼 보인다 | 고정 컴포넌트는 `JoinSet` + exit 1, 슬롯 job 은 루프의 `JoinSet`, 요청 task 는 task 안에서 `Err` 처리 |
| `drop_guard` 를 task 에 옮기고 `disarm` 안 함, 요청·job 의 일반 `Err` 로 루트 취소 | 성공한 요청·실패한 job 하나마다 서비스 전체가 종료된다 | 정상·처리한 경로에서 `guard.disarm()`, 일반 `Err` 는 retry/dead·500 |
| `close()` 없이 `tracker.wait()` / `ctrl_c()` 만 기다림 | 영원히 대기 / SIGTERM 을 못 받고 SIGKILL | `close()` 먼저 / SIGTERM 도 select |
| ops 서버를 워커와 같은 토큰으로 닫음 | drain 동안 `/healthz`·`/metrics`(서버는 `/readyz` 도)가 connection refused | ops 토큰을 따로 두고 워커 drain 뒤 cancel (§4) |
| 무조건 `tokio::sync::Mutex`, std guard 를 `.await` 너머로 | 불필요한 비용 / `Send` 에러 | §5 표 |
| liveness 에 DB ping | DB 순단에 전 pod 재시작 (cascading failure) | heartbeat 만 |
| `panic = "abort"` | task panic 이 프로세스 종료, 테스트에선 안 보인다 | `panic = "unwind"` |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[기능 검증]** — `cargo clippy --all-targets -- -D warnings` 와 `cargo test` 가 통과한다. 바이너리에 `kill -TERM <pid>` 를 보내면 `DRAIN_BUDGET` 안에 exit 0 으로 끝나고 "shutdown signal received" 가 찍힌다(종료 때 `spawn_blocking` 계산이 남을 수 있으면 `shutdown_timeout` 형태의 main 이어야 한다). drain 중에도 `/healthz`·`/metrics` 는 200 이고, 요청을 받는 HTTP·WS 서버라면 `/readyz` 는 503 이다. 컴포넌트 하나가 Err·panic 으로 끝나거나 drain 예산을 넘기면 error 로그(panic 메시지 포함)와 exit code 1 로 끝난다
2. **[성능 / 안전성]** — `grep -rn "spawn_blocking" src/` 의 모든 호출이 상한 Semaphore(CPU 는 `CpuGate`, blocking IO 는 별도 gate)를 거치고 permit 이 클로저 안에 있다. 루프 안 `select!` 분기는 §3 표의 cancel safe 목록만 쓴다. `cargo tree -d -e normal | grep -E '^(opentelemetry|opentelemetry_sdk|opentelemetry-otlp|tracing-opentelemetry) v'` 가 비어 있다. release 프로필에 `panic = "unwind"` 가 있고 `preStop + DRAIN_BUDGET + OPS_CLOSE_BUDGET + flush < terminationGracePeriodSeconds` 를 manifest 값으로 확인한다
3. **[회귀 테스트]** — 세마포어를 공유하면 `tokio::time::timeout` 이 만료되고 분리하면 끝나는지, rayon 클로저 panic 이 `Err` 로 오는지, 호출이 취소돼도 CPU permit 이 계산 종료까지 유지되는지, `log_exit` 가 Err·panic 을, `drain` 이 예산 초과를 실패로 판정하는지, TaskTracker task 가 Ok 로 끝나면 루트 토큰을 취소하지 않고 치명 Err·panic 이면 `drop_guard` 로 취소하는지 테스트로 고정한다 ([rust-testing](../rust-testing/SKILL.md))
4. **[일관성]** — [rust.md rule](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 async·`unwrap_used` 규칙, [rust-error-handling](../rust-error-handling/SKILL.md) 의 panic 정책(`panic = "unwind"`, `JoinError::is_panic`)과 어긋나지 않는다

## 참조 스킬

- [rust-pg-queue-worker](../rust-pg-queue-worker/SKILL.md) — 큐 루프, PgListener 전용 task, lease 반납 drain, heartbeat `/healthz` · rust-og-image-render — `try_acquire` → 503, 렌더 CPU 격리, 요청 timeout · [rust-crdt-sync](../rust-crdt-sync/SKILL.md) — 문서별 actor, 느린 클라이언트 backpressure, `Awareness` 의 Send
- [rust-error-handling](../rust-error-handling/SKILL.md) — `JoinError::is_panic`, panic 정책, 에러 enum 설계 · [rust-engine-architecture](../rust-engine-architecture/SKILL.md) — core crate 에 tokio 를 두지 않는 이유, async trait 의 Send·dyn 제약 · [rust-testing](../rust-testing/SKILL.md) — 동시성 테스트 배치와 이름
- `/go:concurrency-go` — Go 의 goroutine·channel·Mutex 판단과 비교할 때 · `/observability:observability-otel` — Collector·샘플링 (계측 이후 단계)

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. 코드는 scratch crate 에서 `cargo clippy --all-targets -- -D warnings`·`cargo test` 로 확인했다(rustc 1.96). 다음 재검증은 2027-02.

- [tokio spawn_blocking](https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html) · [tokio Semaphore](https://docs.rs/tokio/latest/tokio/sync/struct.Semaphore.html) · [std available_parallelism](https://doc.rust-lang.org/std/thread/fn.available_parallelism.html) · [Alice Ryhl — Async: What is blocking?](https://ryhl.io/blog/async-what-is-blocking/) · [rayon ThreadPoolBuilder](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html) · [rayon::spawn](https://docs.rs/rayon/latest/rayon/fn.spawn.html) — 검증일 2026-11-15 · ✅ verified (Ryhl 은 기록의 ❌ 정정값 적용. tokio 의 "a semaphore … should be used" 는 crate 소스, Ryhl 의 "poorly suited" 이유·"number of threads is equal to the number of CPU cores"·"if you only need a few CPU-bound computations" 는 원문 재확인. permit 위치·세마포어 분리·rayon panic → `Err` 는 로컬 테스트, `panic_handler` 미설정 시 abort 는 crate 소스. permit = 코어 수는 이 skill 의 시작값) · subagent
- [Alice Ryhl — Actors with Tokio](https://ryhl.io/blog/actors-with-tokio/) · [tokio broadcast](https://docs.rs/tokio/latest/tokio/sync/broadcast/index.html) · [broadcast Sender](https://docs.rs/tokio/latest/tokio/sync/broadcast/struct.Sender.html) · [tokio Mutex](https://docs.rs/tokio/latest/tokio/sync/struct.Mutex.html) · [tokio tutorial — Shared state](https://tokio.rs/tokio/tutorial/shared-state) · [Rust Reference — traits](https://doc.rust-lang.org/reference/items/traits.html) · [rustc lint async_fn_in_trait](https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html) · [tokio select!](https://docs.rs/tokio/latest/tokio/macro.select.html) · [Interval](https://docs.rs/tokio/latest/tokio/time/struct.Interval.html) · [MissedTickBehavior](https://docs.rs/tokio/latest/tokio/time/enum.MissedTickBehavior.html) · [JoinSet](https://docs.rs/tokio/latest/tokio/task/struct.JoinSet.html) — 검증일 2026-11-15 · ✅ verified (actor 동작은 로컬 테스트, `Send` 에러 문구는 로컬 컴파일 실패로 확인. cancel safety 목록·`else` 없는 panic·기본 Burst 는 crate 소스 재확인, BAD 의 스트림 어긋남은 로컬 테스트) · subagent
- [CancellationToken](https://docs.rs/tokio-util/latest/tokio_util/sync/struct.CancellationToken.html) · [DropGuard](https://docs.rs/tokio-util/latest/tokio_util/sync/struct.DropGuard.html) · [TaskTracker](https://docs.rs/tokio-util/latest/tokio_util/task/task_tracker/struct.TaskTracker.html) · [tokio JoinError](https://docs.rs/tokio/latest/tokio/task/struct.JoinError.html) · [tokio Runtime](https://docs.rs/tokio/latest/tokio/runtime/struct.Runtime.html) · [tokio graceful shutdown](https://tokio.rs/tokio/topics/shutdown) · [tokio ctrl_c](https://docs.rs/tokio/latest/tokio/signal/fn.ctrl_c.html) · [tokio unix Signal](https://docs.rs/tokio/latest/tokio/signal/unix/struct.Signal.html) · [axum Serve 0.8.9](https://docs.rs/axum/0.8.9/axum/serve/struct.Serve.html) · [tower-http CHANGELOG](https://raw.githubusercontent.com/tower-rs/tower-http/main/tower-http/CHANGELOG.md) · [Kubernetes Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/) · [Kubernetes probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/) · [Container lifecycle hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/) · [PodLifecycleSleepAction feature gate](https://raw.githubusercontent.com/kubernetes/website/main/content/en/docs/reference/command-line-tools-reference/feature-gates/PodLifecycleSleepAction.md) · [Cargo profiles](https://doc.rust-lang.org/cargo/reference/profiles.html) · [tokio 릴리스](https://crates.io/api/v1/crates/tokio) · [tokio README — LTS](https://raw.githubusercontent.com/tokio-rs/tokio/master/README.md) · [config Environment](https://docs.rs/config/latest/config/struct.Environment.html) · [secrecy](https://docs.rs/secrecy/latest/secrecy/) — 검증일 2026-11-15 · ✅ verified (로컬 실행: SIGTERM·SIGINT → exit 0, 컴포넌트 Err·panic → exit 1 과 panic 메시지가 담긴 error 로그, drain 예산 초과 → exit 1, drain 중 `/readyz` 503·`/healthz`·`/metrics` 200, `#[tokio::main]` 은 3초 blocking 을 다 기다리고 `shutdown_timeout(500ms)` 는 0.8초에 끝남. `drop_guard` + `disarm`(Ok 는 루트를 취소하지 않고 치명 Err·panic 은 취소, disarm 이 없으면 성공해도 취소)은 로컬 테스트, `DropGuard` 의 drop 시 무조건 cancel 은 crate 소스. Unix `ctrl_c` = SIGINT, `'static` bound, `with_status_code`, `From<JoinError> for io::Error`, Runtime Drop 의 "waits forever" 는 crate 소스. preStop `sleep` 의 1.34 stable 은 feature gate 문서. `prefix_separator` 동작과 `[REDACTED]` 출력은 로컬 테스트) · subagent
- [tracing-subscriber EnvFilter](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/filter/struct.EnvFilter.html) · [json-subscriber fmt::Layer](https://docs.rs/json-subscriber/latest/json_subscriber/fmt/struct.Layer.html) · [JsonLayer](https://docs.rs/json-subscriber/latest/json_subscriber/struct.JsonLayer.html) · [OTel semconv HTTP spans](https://opentelemetry.io/docs/specs/semconv/http/http-spans/) · [DB spans](https://opentelemetry.io/docs/specs/semconv/database/database-spans/) · [messaging spans](https://opentelemetry.io/docs/specs/semconv/messaging/messaging-spans/) · [sqlx-core 0.9.0 logger](https://docs.rs/crate/sqlx-core/0.9.0/source/src/logger.rs) · [opentelemetry-otlp CHANGELOG](https://raw.githubusercontent.com/open-telemetry/opentelemetry-rust/main/opentelemetry-otlp/CHANGELOG.md) · [opentelemetry-otlp features](https://docs.rs/crate/opentelemetry-otlp/latest/features) · [OpenTelemetrySpanExt](https://docs.rs/tracing-opentelemetry/latest/tracing_opentelemetry/trait.OpenTelemetrySpanExt.html) · [metrics-exporter-prometheus PrometheusBuilder](https://docs.rs/metrics-exporter-prometheus/latest/metrics_exporter_prometheus/struct.PrometheusBuilder.html) · [prometheus-client](https://github.com/prometheus/client_rust) · [tikv prometheus 릴리스](https://crates.io/api/v1/crates/prometheus) · [opentelemetry-prometheus README](https://github.com/open-telemetry/opentelemetry-rust/blob/main/opentelemetry-prometheus/README.md) — 검증일 2026-11-15 · ✅ verified (tracing-subscriber 기본 feature 는 기록의 ❌ 정정값 적용. 본문의 `layer().with_opentelemetry_ids(true)` 는 fmt::Layer 문서, `openTelemetry` 키는 JsonLayer 문서. sqlx 쿼리 로그의 `tracing::event!(target: "sqlx::query")` 는 crate 소스. opentelemetry-otlp 기본 feature 목록과 그중 transport `http-proto`·`reqwest-blocking-client` 는 crates.io API 로 재확인, feature 조합은 로컬 컴파일·테스트. `_total`·histogram bucket 은 로컬 테스트. tikv `prometheus` 최신은 0.14.0, 2025-03-27. OTLP 권고는 README "For new projects, consider using the opentelemetry-otlp crate instead") / ⚠️ collector 로 실제 전송은 미실측 (로컬에 docker 없음) · subagent
