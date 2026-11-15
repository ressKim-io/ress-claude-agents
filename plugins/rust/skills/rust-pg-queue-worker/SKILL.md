---
name: rust-pg-queue-worker
description: "Postgres 테이블 큐 워커 (Rust·sqlx) — FOR UPDATE SKIP LOCKED claim, LISTEN/NOTIFY 와 polling fallback, lease·fencing·reaper, attempts 초과 dead, 멱등 upsert, 재시도 분류. Use when Rust 로 Postgres 기반 작업 큐 워커를 만들거나 작업이 멈추거나 중복 처리될 때."
---

# Rust Postgres 테이블 큐 워커 — claim·lease·fencing·깨우기

Go 가 업무 행과 job 행을 한 트랜잭션에 쓰고(outbox), Rust worker 가 `FOR UPDATE SKIP LOCKED` 로 가져가 처리한 뒤 결과를 멱등 upsert 하는 구조다.
코드는 sqlx 0.9 기준이다. `track_jobs` 같은 이름과 숫자는 예시다. 먼저 정할 것: 처리 시간 p99(lease 길이·heartbeat 필요 여부), PgBouncer·RDS Proxy 유무(listener 경로), migration 소유자, `max_attempts`·backoff 값, done·dead 보존 기간. 코드 블록은 길이 때문에 한 줄로 모은 곳이 있으니 복사하면 `cargo fmt` 를 돌린다.

## Quick Reference (결정 트리)

```
큐가 필요하다
  ├─ fan-out(여러 consumer 그룹)·이벤트 replay 가 필요하다 ──> 메시지 브로커 (이 skill 범위 밖)
  ├─ producer·consumer 가 모두 한 라이브러리 생태계다 ───────> §Build vs Buy
  └─ Go 가 업무 행과 같은 트랜잭션에 job 을 넣는다 ──────────> 직접 만든 jobs 테이블 (이 skill)
job 하나의 생애
  claim: 단일 UPDATE (SKIP LOCKED, attempts+1, lease_token 발급) → 바로 commit, 행 잠금 없이 처리(judge 는 CpuGate)
  finish: 한 트랜잭션에서 fencing UPDATE(lease_token 일치. 0 rows = LeaseLost → tx drop 으로 rollback) → 결과 upsert → commit
  실패: classify_sqlx·classify_compute → apply_outcome 한 곳에서 pending(backoff) 또는 dead
  worker 가 죽음: lease_until 이 지나면 reaper 가 backoff 를 두고 pending 또는 dead 로 되돌린다
깨우기 (worker loop 하나가 job 완료·wake·tick 중 먼저 온 것마다 빈 슬롯을 채운다)
  LISTEN 전용 task ──try_send──> mpsc(1) ──> worker loop <── interval polling (끊긴 동안의 알림 유실 보완)
```

## 1. 테이블 — 상태는 job 행에, 결과는 별도 테이블에

```sql
CREATE TABLE track_jobs (
    id           bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  activity_id bigint NOT NULL,
    status       text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'done', 'dead')),
    run_at       timestamptz NOT NULL DEFAULT now(),  attempts integer NOT NULL DEFAULT 0,  max_attempts integer NOT NULL,
    lease_token  uuid,  lease_until timestamptz,  last_error text
);
CREATE INDEX track_jobs_ready  ON track_jobs (run_at, id) WHERE status = 'pending';
CREATE INDEX track_jobs_leased ON track_jobs (lease_until) WHERE status = 'running';
CREATE UNIQUE INDEX track_jobs_one_open ON track_jobs (activity_id) WHERE status IN ('pending', 'running');
CREATE TABLE track_results (activity_id bigint NOT NULL, engine_version bigint NOT NULL, verdict text NOT NULL,
    reason text, judged_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (activity_id, engine_version));
```

| 설계 | 이유 |
|---|---|
| `attempts` 는 **claim 할 때** +1 | 처리 중 OOM·panic 으로 죽는 poison job 도 횟수가 쌓여 dead 로 간다. 실패할 때 올리면 같은 job 이 끝없이 돈다 |
| `lease_token`(claim 마다 새 uuid) + `lease_until` | fencing 과 reaper 의 기준이다. 고정 `worker_id` 로는 같은 worker 의 이전 claim 과 구분할 수 없다 |
| `track_jobs_one_open` partial unique | 같은 activity 의 열린 job 이 둘이 되지 않는다. Go 의 `ON CONFLICT ... WHERE` 가 이 인덱스를 추론한다. **enqueue 뒤 입력이 바뀌지 않는다는 전제다**: running 중 재enqueue 는 조용히 버려진다. 입력이 바뀔 수 있으면(수정·재업로드) 인덱스와 Go 의 `WHERE` 를 `status = 'pending'` 으로 좁히고, 두 job 이 함께 running 일 수 있으니 job 에 입력 revision 을 실어 결과 upsert 를 `DO UPDATE ... WHERE track_results.revision <= EXCLUDED.revision` 으로 막는다(늦게 끝난 옛 입력의 판정이 덮어쓰지 않는다) |
| 결과 PK `(activity_id, engine_version)` | 같은 job 이 두 번 처리돼도 결과는 한 행이다. 버전별 결과가 남아 비교와 롤백이 된다. Params 를 DB·설정에 둔다면 `params_hash` 를 PK·`ON CONFLICT` 대상에 함께 넣는다 ([rust-engine-architecture](../rust-engine-architecture/SKILL.md)). 빠뜨리면 다른 임계값으로 낸 판정이 같은 행을 덮어쓴다 |
| job 에는 엔진 버전이 없다 | worker 의 `ENGINE_VERSION` 상수가 결과 키다. 버전별 backfill 을 job 단위로 나눠야 하면 job 에 넣고 claim 에서 자기 버전만 고른다(rolling 배포 중에도 안 섞인다) |

## 2. Claim — 잠금은 claim 하는 동안만

```sql
-- queries/claim.sql
WITH picked AS MATERIALIZED (
    SELECT id FROM track_jobs WHERE status = 'pending' AND run_at <= now()
    ORDER BY run_at, id LIMIT $1
    FOR UPDATE SKIP LOCKED
)
UPDATE track_jobs AS j
SET status = 'running', attempts = j.attempts + 1,
    lease_token = gen_random_uuid(), lease_until = now() + make_interval(secs => $2)
FROM picked WHERE j.id = picked.id
RETURNING j.id, j.activity_id, j.attempts, j.max_attempts, j.lease_token
```

```rust
#[derive(Debug, sqlx::FromRow)]
pub struct ClaimedJob { pub id: i64, pub activity_id: i64, pub attempts: i32, pub max_attempts: i32, pub lease_token: Uuid }
const CLAIM_SQL: &str = include_str!("../../queries/claim.sql"); // include_str! 는 이 .rs 파일 기준, query_file_as! 는 crate 루트 기준 경로다
pub async fn claim(pool: &PgPool, batch: i64, lease: Duration) -> Result<Vec<ClaimedJob>, sqlx::Error> {
    sqlx::query_as::<_, ClaimedJob>(CLAIM_SQL)
        .bind(batch).bind(lease.as_secs_f64()) // make_interval 의 secs 는 double precision
        .fetch_all(pool).await
}
```

- **처리하는 동안 `FOR UPDATE` 를 쥐지 않는다.** 연결을 점유하고 VACUUM horizon 을 막는다. 그래서 claim 은 단일 statement 로 끝나는 즉시 commit 되고, 소유는 lease 로 표시한다. 자기 잠금을 줄여도 **같은 DB 의 다른 워크로드가 연 긴 트랜잭션**이 horizon 을 붙잡으면 큐 테이블에 dead tuple 이 쌓이고 lock 시간이 는다. SKIP LOCKED 로는 해결되지 않는다(PlanetScale 이 PG18 에서 재현). 다른 role 에도 `idle_in_transaction_session_timeout`·`transaction_timeout` 을 걸고, `pg_stat_user_tables` 의 jobs 테이블 `n_dead_tup` 에 알람을 건다. `transaction_timeout`(PG17+) 은 트랜잭션이 아니라 **세션을 끊고** 단일 statement 에도 적용된다. 이 값이 `idle_in_transaction_session_timeout` 이하이면 후자는 무시된다. worker role 에 걸 때는 가장 오래 걸리는 실제 쿼리(reaper, 큐 길이 COUNT)를 기준으로 정한다. `ORDER BY` 는 대략적인 순서다. READ COMMITTED 에서 잠금과 함께 쓰면 순서가 어긋날 수 있고, REPEATABLE READ 이상에서는 40001 이 난다. `OFFSET` 으로 건너뛴 행도 잠기므로 쓰지 않는다. `MATERIALIZED` 는 CTE 를 한 번만 계산하게 강제한다 (`IN (SELECT ... LIMIT ...)` 형태가 LIMIT 보다 많이 잠글 수 있다는 주장은 ⚠️ 공식 문서로 확인하지 못해 CTE 로 피해 가기만 한다). 운영 빌드에서 컬럼·타입을 빌드 때 검사하는 `query_file_as!` 형태는 §8.

## 3. Finish — fencing 먼저, 결과 upsert, 한 트랜잭션

```rust
#[derive(Debug, PartialEq, Eq)]
pub enum Fenced { Applied, LeaseLost }
// ❌ BAD: id 만 보면 lease 를 잃은 zombie worker 도 done 으로 바꾸고 새 주인의 결과를 덮어쓴다
const DONE_SQL: &str = "UPDATE track_jobs SET status = 'done' WHERE id = $1";
// ✅ GOOD: 지금 lease 주인일 때만 바뀐다. 0 rows = LeaseLost
const FENCE_DONE_SQL: &str = "UPDATE track_jobs SET status = 'done', lease_token = NULL, lease_until = NULL,
    last_error = NULL WHERE id = $1 AND lease_token = $2 AND status = 'running'";
const UPSERT_RESULT_SQL: &str = "INSERT INTO track_results (activity_id, engine_version, verdict, reason)
    VALUES ($1, $2, $3, $4) ON CONFLICT (activity_id, engine_version)
    DO UPDATE SET verdict = EXCLUDED.verdict, reason = EXCLUDED.reason, judged_at = now()";
pub async fn finish(pool: &PgPool, job: &ClaimedJob, row: &ResultRow<'_>) -> Result<Fenced, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let fenced = sqlx::query(FENCE_DONE_SQL).bind(job.id).bind(job.lease_token).execute(&mut *tx).await?;
    if fenced.rows_affected() == 0 { return Ok(Fenced::LeaseLost) } // tx 를 commit 하지 않고 drop → rollback
    sqlx::query(UPSERT_RESULT_SQL)
        .bind(job.activity_id).bind(i64::from(ENGINE_VERSION)) // sqlx 는 u32 를 Postgres 에 bind 하지 못한다 (E0277)
        .bind(row.verdict).bind(row.reason)
        .execute(&mut *tx).await?;
    tx.commit().await?;
    Ok(Fenced::Applied)
}
```

- **잠금 순서는 job → result 로 고정한다.** fencing 을 먼저 하면 lease 를 잃은 것을 일찍 알고, reaper·`apply_outcome`·lease 반납은 job 행만 바꾸므로 순서가 어긋나지 않는다. PG 문서도 deadlock 을 막으려면 모든 쪽이 같은 순서로 잠그라고 한다. **fencing 이 있어도 upsert 는 멱등이어야 한다.** fencing 은 한 job 의 결과를 한 번만 쓰게 할 뿐이다. 같은 activity 가 done 뒤 다시 enqueue 되거나 backfill 로 다시 판정되면 같은 키에 또 쓴다. `ON CONFLICT` 는 맞는 unique index 를 추론하지 못하면 에러가 나고, 여기서는 PK 가 그 역할을 한다. sqlx #4484 수정(#4485)이 릴리스되기 전에는 PgBouncer transaction 모드에서 이미 commit 된 쿼리가 Protocol 에러로 보일 수 있어, fencing 없는 쓰기를 그대로 재시도하면 두 번 쓴다.

## 4. 실패 — 분류는 한 함수, 상태 전이는 apply_outcome 한 곳

구간 미통과·부정 의심·입력 거부는 오류가 아니라 `Ok(Judgement)` 다. finish 로 done 이 되고 dead 로 가지 않는다 (rust-error-handling). Go 가 activity 를 지운 경우도 같다. `load_input` 은 `fetch_optional` 로 읽어 `Option` 을 돌려주고 core 가 '입력 없음' 을 판정한다. `fetch_one` 이 내는 `RowNotFound` 는 아래 `_ => None` 으로 Transient 가 되어, 재시도를 다 쓴 뒤 인프라 장애처럼 dead 로 간다. 오류만 아래 표로 나눈다.

| 오류 | 언제 나나 | 분류 → 전이 |
|---|---|---|
| `ColumnDecode`·`ColumnNotFound`·`TypeNotFound`·`Decode`, SQLSTATE `42xxx` | 배포 중 스키마 drift. `FromRow`·`try_get` 경로에서 타입 drift 는 `ColumnDecode`, 컬럼 이름 drift 는 `ColumnNotFound` 로 온다(`Decode` 는 row 밖의 값 decode). 테이블·컬럼 drift 는 `42703` undefined_column·`42P01` undefined_table | Permanent(Schema) → dead + 알람. 입력 거부로 위장하지 않는다 |
| SQLSTATE `22xxx`·`23xxx` | data exception(`22P02` 등)·제약 위반. 같은 입력이면 다시 해도 같다. class 단위로 묶는 것은(`42xxx` 포함) 이 skill 의 설계 선택이다. PG 문서는 class·code 만 정의하고 재시도 여부는 말하지 않는다 | Permanent(Bug) → dead + 알람 |
| `JoinError::is_panic()`·`ComputeError::Panicked` | core 불변식 위반 (`spawn_blocking`·rayon 경로) | Permanent(Bug) → dead + 알람 |
| `40001` serialization_failure · `40P01` deadlock_detected · `55P03` lock_not_available · `57014` query_canceled · `57P01` admin_shutdown · `08003`·`08006` 연결 끊김 · `53300` too_many_connections · `25P03`·`25P04` idle/transaction timeout · `PoolTimedOut` · 처음 보는 오류(`sqlx::Error` 는 `#[non_exhaustive]`) | 경합, timeout, failover, 연결 문제 | Transient(처음 보는 오류도 **명시**) → pending, `run_at = now() + backoff`. claim 때 올린 attempts 가 상한 |
| fencing 0 rows | lease 만료 뒤 다른 worker 가 가져감 | LeaseLost → 아무것도 쓰지 않는다 |

```rust
pub fn classify_sqlx(e: sqlx::Error) -> JobFailure {
    let permanent = match &e {
        sqlx::Error::Decode(_) | sqlx::Error::ColumnDecode { .. } | sqlx::Error::ColumnNotFound(_)
        | sqlx::Error::TypeNotFound { .. } => Some(PermanentKind::Schema),
        sqlx::Error::Database(db) => db.code().as_deref().and_then(permanent_by_sqlstate),
        _ => None, // 연결 끊김, PoolTimedOut, 처음 보는 오류: 재시도. 상한은 claim 때 올린 attempts
    };
    match permanent {
        Some(kind) => JobFailure::Permanent { kind, source: e.into() },
        None => JobFailure::Transient(e.into()),
    }
}
fn permanent_by_sqlstate(code: &str) -> Option<PermanentKind> {
    match code.get(..2)? {
        "22" | "23" => Some(PermanentKind::Bug), // data exception·제약 위반: 같은 입력이면 다시 해도 같다
        "42" => Some(PermanentKind::Schema), // 문법·권한 오류도 이 class 다. 재시도로 낫지 않는다
        _ => None, // 재시도 SQLSTATE 는 Transient 와 동작이 같아 따로 나누지 않는다
    }
}
#[derive(Debug, thiserror::Error)]
pub enum ComputeError {
    #[error("cpu gate closed")] GateClosed(#[from] AcquireError),
    #[error("compute task failed")] Join(#[from] JoinError),
    #[error("compute task panicked")] Panicked, // rayon: 클로저 panic 으로 oneshot sender 가 drop 됐다
}
fn classify_compute(e: ComputeError) -> JobFailure {
    match e {
        ComputeError::Join(join) => classify_join(join),
        ComputeError::Panicked => JobFailure::Permanent { kind: PermanentKind::Bug, source: e.into() },
        ComputeError::GateClosed(_) => JobFailure::Transient(e.into()), // 종료 중 gate 를 닫았다. 계산은 안 돌았다
    }
}
async fn judge_and_finish(pool: &PgPool, cpu: &CpuGate, job: &ClaimedJob) -> Result<(), JobFailure> {
    let input = load_input(pool, job.activity_id).await.map_err(classify_sqlx)?;
    let judgement = cpu.run(move || judge(&input)).await.map_err(classify_compute)?;
    match finish(pool, job, &judgement.as_row()).await.map_err(classify_sqlx)? {
        Fenced::Applied => Ok(()),
        Fenced::LeaseLost => Err(JobFailure::LeaseLost),
    }
}
impl JobFailure {
    const MAX_ERROR_CHARS: usize = 500;
    pub fn summary(&self) -> String {
        let text = match self {
            Self::Transient(e) => format!("transient: {e}"),
            Self::Permanent { kind, source } => format!("permanent {kind:?}: {source}"),
            Self::LeaseLost => "lease lost".to_owned(),
        };
        text.chars().take(Self::MAX_ERROR_CHARS).collect() // 바이트 위치로 자르면 한글 중간에서 panic
    }
}
const RECORD_FAILURE_SQL: &str = "UPDATE track_jobs SET status = $3, run_at = now() + make_interval(secs => $4),
    lease_token = NULL, lease_until = NULL, last_error = $5 WHERE id = $1 AND lease_token = $2 AND status = 'running'";
pub async fn apply_outcome(pool: &PgPool, job: &ClaimedJob, failure: &JobFailure) -> Result<(), sqlx::Error> {
    let (status, delay) = match next_step(failure, job.attempts, job.max_attempts) {
        Next::Skip => return Ok(()), // lease 를 잃었다. 지금 주인이 기록한다
        Next::Retry => ("pending", backoff(job.attempts)),
        Next::Dead => ("dead", Duration::ZERO),
    };
    sqlx::query(RECORD_FAILURE_SQL)
        .bind(job.id).bind(job.lease_token).bind(status)
        .bind(delay.as_secs_f64()).bind(failure.summary())
        .execute(pool).await?;
    Ok(())
}
```

- **타입 출처**: `JobFailure`·`PermanentKind`·`Next`·`next_step`·`classify_join` 은 rust-error-handling, `CpuGate` 는 [rust-async-tokio](../rust-async-tokio/SKILL.md) 의 것이다. `summary()` 의 `{kind:?}` 와 테스트의 `assert_eq!` 는 rust-error-handling 정의의 `Debug`·`PartialEq`·`Eq` derive 에 기대므로 그 derive 를 지우지 않는다. 위 `ComputeError` 는 `CpuGate::run`·`on_rayon` 이 돌려주는 타입이고, rust-async-tokio 가 말하는 "`AcquireError`·`JoinError` 를 `#[from]` 으로 받는 enum" 에 variant 이름을 붙인 것이다. `ResultRow` 는 core 의 `Judgement` 를 컬럼 값(`verdict: &str`, `reason: Option<&str>`)으로 옮긴 shell 쪽 타입이다.
- `next_step`·`backoff`·`permanent_by_sqlstate`·`classify_compute` 는 IO 가 없으니 표의 행마다 단위 테스트로 고정한다. `backoff` 는 `min(2^attempts 초, 10분)` 같은 순수 함수다(값은 예시). 지수는 상한을 둬 shift overflow 를 막는다. `apply_outcome` 자체가 실패하면(DB 장애) 로그만 남긴다. lease 가 만료되면 reaper 가 되돌리므로 안에서 재시도 루프를 돌지 않는다. dead 전이에는 메트릭과 알람을 건다. `summary()` 는 길이만 묶는다. SQLSTATE `22xxx` 메시지는 입력값을 되풀이한다(`22P02` 는 `invalid input syntax for type integer: "<값>"`). PII 가 걸리면 `last_error` 에는 분류와 SQLSTATE 만 남긴다.
- `judge` 는 CPU 작업이라 `CpuGate`(permit 수는 코어 수에서 시작해 측정 후 조정, permit 은 클로저 안)로 보낸다. job 동시성(worker 의 `concurrency` = JoinSet 슬롯)과 CPU 동시성을 따로 묶는 것은 [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 MUST 다. 측정해서 CPU 가 처리량을 좌우하면 rayon 경로로 옮기고, 그쪽 panic 은 `ComputeError::Panicked` 로 와서 같은 Permanent(Bug) 가 된다.

## 5. Lease 연장과 reaper

```sql
-- reaper: worker 가 죽어 lease 가 만료된 job 을 되돌린다. run_at 을 미뤄 poison job 이 replica 를 돌며 바로 다시 죽이지 않게 한다
UPDATE track_jobs
SET status = CASE WHEN attempts >= max_attempts THEN 'dead' ELSE 'pending' END,
    run_at = now() + make_interval(secs => least(power(2, least(attempts, 10)), 600)),
    lease_token = NULL, lease_until = NULL, last_error = 'lease expired'
WHERE status = 'running' AND lease_until < now();
-- 반납: 종료 예산을 넘겼을 때 (§9). claim 은 상한을 보지 않으므로 같은 CASE 로 max+1 번째 실행을 막는다
UPDATE track_jobs SET status = CASE WHEN attempts >= max_attempts THEN 'dead' ELSE 'pending' END,
    lease_token = NULL, lease_until = NULL
WHERE lease_token = ANY($1) AND status = 'running';
```

- **lease 길이**는 `CpuGate` 대기까지 포함한 claim→finish p99 보다 넉넉하게 잡는다. 더 길어질 수 있으면 heartbeat(`SET lease_until = now() + ... WHERE id = $1 AND lease_token = $2 AND status = 'running'`)로 연장하고, 0 rows 가 나오면 lease 를 잃은 것이니 그 job 을 멈춘다. heartbeat 를 쓰면 §6 `process` 의 `timeout(lease, ..)` 대신 job 마다 child token 을 넘겨 이때 취소한다. 참고값: Solid Queue 는 polling 0.1초·heartbeat 60초·5분 무응답이면 죽은 것으로 보고, River 는 1시간이 지난 job 을 stuck 으로 보고 되살린다. **상한은 pending 으로 되돌리는 쪽**(reaper·반납·`apply_outcome`)이 확인한다. reaper 지연의 상한은 §4 `backoff` 와 같은 600초다. 정수 인자 `power` 는 함수 타입 결정 규칙에 따라 double precision 이 되고, `least` 도 공통 타입인 double precision 으로 풀려 `make_interval(secs => ...)` 에 그대로 들어간다. 지수까지 묶어야 `max_attempts` 를 크게 잡아도 `power` 가 float overflow 오류로 reaper 를 멈추지 않는다.
- **reaper 는 replica 마다 돌려도 된다.** worker loop 와 같은 모양의 interval 루프다. READ COMMITTED 에서 같은 행을 기다린 두 번째 UPDATE 는 WHERE 를 다시 평가하므로 이미 되돌린 행을 또 바꾸지 않는다. `UPDATE` 에는 `LIMIT` 절이 없으니, 밀린 행이 많으면 §2 와 같은 이유로 `WITH picked AS MATERIALIZED (SELECT id ... LIMIT n FOR UPDATE SKIP LOCKED) UPDATE ... FROM picked` 형태로 n 개씩 나눠 `transaction_timeout`(§2) 안에 끝낸다. **보존**: done·dead 행을 지우지 않으면 테이블과 인덱스가 계속 커진다. 보존 기간을 정해 배치로 지우고 인덱스를 주기적으로 재구축한다. River 와 Solid Queue 도 완료 job 을 주기적으로 정리한다.

## 6. 깨우기 — LISTEN 전용 task + mpsc(1) + polling

- **LISTEN 은 commit 시점부터 유효하고, 연결이 끊긴 동안의 알림은 돌려받지 못한다.** → 순서는 LISTEN → 한 번 claim → 대기이고 polling fallback 이 필수다. **sqlx `recv()` 는 재연결을 뜻하는 `Ok(None)` 을 안에서 삼킨다.** 검증일 기준 최신 릴리스의 `try_recv` 가 재연결하는 ErrorKind 는 ConnectionAborted·UnexpectedEof·TimedOut·BrokenPipe 넷뿐이고 ConnectionReset 등은 Err 다(#4014. 수정 PR #4016 은 머지됐지만 미릴리스이고 backoff 는 빠졌다). → `try_recv()` 를 쓰고 `Ok(None)` 에도 깨운다. Err 면 listener 를 새로 만들고 지연은 앱이 둔다. `?` 로 main 까지 올리면 프로세스가 죽는다. **`PgListener::connect` 는 연결 1개짜리 전용 pool 을 만들고, 내부 acquire timeout 이 30초라 연결 실패가 늦게 드러난다.** → `connect_with(&pool)` 은 worker pool 연결 1개를 계속 점유하므로 전용 연결을 쓴다. 연결·LISTEN 도 종료 토큰으로 감싸 이 30초가 종료 예산을 먹지 않게 한다. **`recv`·`try_recv` 의 cancel safety 는 문서에 없다.** → worker 의 `select!` 에 넣지 않고 전용 task 에만 둔다. 취소되면 listener 째로 버리므로 `try_recv` 를 중간에 끊어도 잃을 것이 없다.

```rust
pub async fn run_listener(direct_url: String, wake: mpsc::Sender<()>, token: CancellationToken) -> anyhow::Result<()> {
    while !token.is_cancelled() {
        if let Err(e) = listen_until_error(&direct_url, &wake, &token).await {
            warn!(error = %e, "LISTEN lost; polling covers the gap");
            token.run_until_cancelled(tokio::time::sleep(RELISTEN_DELAY)).await; // hot loop 방지
        }
    }
    Ok(()) // 연결 오류는 여기서 삼키고 polling 이 메운다. 끝나는 길은 종료 토큰뿐이다
}
async fn listen_until_error(url: &str, wake: &mpsc::Sender<()>, token: &CancellationToken) -> Result<(), sqlx::Error> {
    let subscribe = async {
        let mut listener = PgListener::connect(url).await?;
        listener.listen(CHANNEL).await.map(|()| listener)
    };
    let Some(subscribed) = token.run_until_cancelled(subscribe).await else { return Ok(()) }; // DB 가 안 닿아도 종료를 막지 않는다
    let mut listener = subscribed?;
    let _ = wake.try_send(()); // LISTEN 이 유효해진 뒤 한 번 훑어 그 전에 들어온 job 을 줍는다
    while let Some(received) = token.run_until_cancelled(listener.try_recv()).await {
        received?; // Ok(None) = 재연결됨. 끊긴 동안의 알림은 사라졌으니 그래도 깨운다
        let _ = wake.try_send(()); // 칸이 1개라 신호가 이미 있으면 합쳐진다
    }
    Ok(())
}
pub async fn run_worker(w: Worker, mut wake: mpsc::Receiver<()>) -> anyhow::Result<()> {
    let mut poll = tokio::time::interval(w.poll_every);
    poll.set_missed_tick_behavior(MissedTickBehavior::Delay); // 기본 Burst 는 밀린 tick 을 몰아 쏜다
    let mut running = JoinSet::new();
    loop {
        tokio::select! {
            biased;
            () = w.token.cancelled() => break,
            Some(done) = running.join_next() => log_task_end(done), // 비어 있으면 None 이라 이번 호출에서만 꺼진다
            Some(()) = wake.recv() => {} // sender 가 사라지면 이 분기만 꺼지고 polling 으로 계속 돈다
            _ = poll.tick() => {}
        }
        w.heartbeat.send_replace(Instant::now()); // 긴 job 이 슬롯을 다 채워도 tick 마다 갱신된다
        fill(&w, &mut running).await;
    }
    while let Some(done) = running.join_next().await { log_task_end(done) } // 새 claim 없이 처리 중인 job 만 끝낸다
    Ok(())
}
async fn fill(w: &Worker, running: &mut JoinSet<()>) {
    let free = w.concurrency.saturating_sub(running.len());
    if free == 0 || w.token.is_cancelled() { return }
    match claim(&w.pool, i64::try_from(free).unwrap_or(1), w.lease).await {
        Ok(jobs) => for job in jobs { running.spawn(process(w.pool.clone(), w.cpu.clone(), w.lease, job)); },
        Err(e) => warn!(error = %e, "claim failed; next wake or tick retries"),
    }
}
fn log_task_end(done: Result<(), JoinError>) { if let Err(e) = done { error!(error = %e, "job task died; the reaper recovers its lease") } }
async fn process(pool: PgPool, cpu: CpuGate, lease: Duration, job: ClaimedJob) {
    let bounded = tokio::time::timeout(lease, judge_and_finish(&pool, &cpu, &job)).await; // lease 가 끝난 job 은 reaper 가 넘긴다. 멈춘 job 이 슬롯을 계속 쥐지 않게 끊는다
    let Err(failure) = bounded.unwrap_or_else(|elapsed| Err(JobFailure::Transient(elapsed.into()))) else { return };
    match &failure {
        JobFailure::LeaseLost => debug!(job_id = job.id, "lease lost; the current owner records the outcome"),
        _ => warn!(job_id = job.id, failure = %failure.summary(), "job failed"),
    }
    if let Err(e) = apply_outcome(&pool, &job, &failure).await { // LeaseLost 는 Skip 이라 아무것도 쓰지 않는다
        warn!(job_id = job.id, error = %e, "outcome not recorded; the reaper retries after the lease");
    }
}
```

- `Worker` 는 pool·`CpuGate`·종료 토큰·`concurrency`·lease·poll 주기·`heartbeat: watch::Sender<Instant>` 를 묶은 shell 쪽 구조체다. JoinSet 을 loop 한 곳이 쥐므로 job 이 도는 동안에도 wake·tick·heartbeat 가 보인다. drain 함수 안에서 `join_next().await` 로 기다리면 그동안 NOTIFY 가 와도 빈 슬롯을 못 채우고, 부하가 이어지면 그 함수가 끝나지 않아 heartbeat 가 멈춘다. 빈 자리만큼만 claim 한다. batch 를 한꺼번에 가져와 하나씩 처리하면 뒤쪽 job 의 lease 가 기다리는 동안 소진된다. 새 claim 은 job 완료·wake·tick 때 일어나고, 종료 토큰이 켜지면 멈춘다. `select!` 의 네 분기(`cancelled`, `JoinSet::join_next`, mpsc `recv`, `tick`)는 모두 문서상 cancel safe 이고, 패턴이 맞지 않는 분기는 그 `select!` 호출 동안만 꺼진다. `process` 의 `timeout(lease, ..)` 은 `statement_timeout` 없는 쿼리처럼 멈춘 job 이 reaper 가 넘긴 뒤에도 슬롯을 쥐는 것을 막는다. heartbeat 는 loop 가 돌기만 하면 갱신되므로 이 누수를 `/healthz` 가 잡지 못한다. 시간이 다 되면 Transient 로 `apply_outcome` 에 넘기고, 그사이 reaper 가 되돌렸으면 fencing 이 0 rows 로 막는다. `CpuGate` 안 계산은 멈추지 않으므로 그 permit 은 계산이 끝날 때 돌아온다.

## 7. Go 쪽 enqueue 계약과 스키마 소유

```sql
BEGIN;
INSERT INTO activities (...) VALUES (...) RETURNING id;
INSERT INTO track_jobs (activity_id, max_attempts) VALUES ($1, $2)
    ON CONFLICT (activity_id) WHERE status IN ('pending', 'running') DO NOTHING;
SELECT pg_notify('track_jobs', '');
COMMIT;
```

- transactional outbox 다. NOTIFY 는 commit 될 때만 전달되므로 rollback 된 enqueue 는 깨우지 않는다. 소비 쪽은 같은 job 을 두 번 받을 수 있다고 보고 멱등으로 만든다. payload 는 비운다. 같은 트랜잭션·같은 채널·같은 payload 의 NOTIFY 는 1건으로 합쳐진다. payload 는 8000 bytes 미만이어야 하고 알림 큐(8GB)가 가득 차면 commit 이 실패하므로 데이터를 싣지 않는다. 채널명은 소문자 snake_case 로 둔다. sqlx 는 채널명을 따옴표로 감싸 대소문자를 구분하고, 따옴표 없는 `NOTIFY` 는 소문자로 접힌다. NOTIFY 가 든 트랜잭션의 COMMIT 은 인스턴스 전역 lock 을 잡고, 이 lock 은 PG19 소스에도 남아 있다. 처리량이 커지면 업무 트랜잭션에서 `pg_notify` 를 빼고 commit 뒤에 debounce 한 NOTIFY 를 따로 보낸다. 빠진 알림은 polling 이 메운다. PgBouncer transaction pooling 에서는 LISTEN 을 쓸 수 없다(NOTIFY 는 된다). listener 는 direct URL 로 붙는다.
- migration 소유자는 한 곳이다(Go 레포 또는 별도 migration 레포). Rust CI 는 그 migration 을 적용한 DB 로 `cargo sqlx prepare --check` 를 돌려 drift 를 잡는다.

## 8. sqlx 0.9 사용 규칙

- `sqlx = { version = "0.9", default-features = false, features = ["runtime-tokio", "postgres", "macros", "migrate", "uuid"] }`. TLS 가 필요하면 `tls-rustls` 또는 `tls-native-tls` 를 더한다. 예전의 runtime·TLS 결합 feature 는 0.9 에서 없어졌다. MSRV 는 1.94 다.
- **매크로는 SQL 파일로 쓴다.** `query!`·`query_as!` 는 문자열 리터럴(또는 리터럴의 `+` 연결)만 받아서 `sqlx::query!(CLAIM_SQL)` 은 `expected string literal` 로 컴파일되지 않는다. `sqlx::query_file_as!(ClaimedJob, "queries/claim.sql", batch, secs)` 를 쓰고, 경로는 crate 루트 기준이다. RETURNING 컬럼은 `j.id AS "id!"` 처럼 nullability 를 고정한다. **런타임 `query`·`query_as` 의 제약**: `FromRow` 는 필드 이름으로 컬럼을 찾으므로 `"id!"` alias 가 붙은 파일을 읽으면 `ColumnNotFound` 가 난다. SQL 파일 하나는 한 방식으로만 쓴다. `format!` 으로 만든 SQL 은 `SqlSafeStr` 이 거부하니, 동적 SQL 이 꼭 필요할 때만 `AssertSqlSafe` 로 감싼다. **오프라인 빌드**: 매크로는 빌드할 때 `DATABASE_URL` 이나 `.sqlx` 가 필요하다. `.sqlx` 는 `SQLX_OFFLINE_DIR` → crate 디렉터리 → workspace 루트 순으로 찾는다. `cargo sqlx prepare --workspace` 결과를 커밋하고 CI 는 실제 DB 로 `--check` 한다. `DATABASE_URL` 이 `.sqlx` 보다 우선하므로 오프라인을 강제하려면 `SQLX_OFFLINE=true`. 0.9 부터 `cargo install --locked sqlx-cli` 는 동작하지 않는다.

## 9. Pool, 종료, 운영 endpoint

- **pool**: worker pool 은 `max_connections(concurrency + 2)` 에 `acquire_timeout` 을 기본 30초보다 짧게 둔다. listener 는 별도 연결 1개이므로 서버 연결 총량은 대략 replica × (concurrency + 3). PgBouncer transaction 모드 뒤라면 `max_prepared_statements` 를 0 이 아닌 값으로 둔다.
- **종료**: SIGTERM(`SignalKind::terminate()`)과 `ctrl_c` 를 함께 기다린다 → `token.cancel()` → worker loop 가 새 claim 을 멈추고 처리 중인 job 만 기다린다. main 은 `run_worker`·`run_listener`·reaper 를 고정 컴포넌트 `JoinSet<anyhow::Result<()>>` 에 띄우고(그래서 reaper 도 `anyhow::Result<()>` 를 돌려준다), 취소 뒤 `timeout(budget, ...)` 안에서 그 JoinSet 이 빌 때까지 `join_next` 한다 ([rust-async-tokio](../rust-async-tokio/SKILL.md) §4). 예산은 preStop + drain + ops(`/healthz`·`/metrics`) 종료 + telemetry flush < `terminationGracePeriodSeconds`(기본 30초, preStop 포함)다. `spawn_blocking` 은 abort 되지 않으므로 예산에 넣는다. **예산을 넘긴 job**: 그대로 끝내도 reaper 가 lease 만료 뒤 되돌린다. 더 빨리 돌려주려면 worker 가 in-flight `lease_token` 집합(`Mutex<BTreeSet<Uuid>>`, `fill` 에서 넣고 `process` 끝에서 뺀다)을 들고, main 이 timeout 뒤 그 목록을 §5 반납 SQL 에 넘긴다. 반납 때 attempts 를 되돌릴지는 정해야 한다. 안 되돌리면 배포가 잦을 때 정상 job 도 dead 에 가까워지고, 되돌리면 종료를 일으키는 job 이 상한을 피한다.
- **`/healthz`**: worker loop 가 매 반복(tick 포함)마다 갱신하는 heartbeat 가 N초 이내인지만 본다. DB ping 을 넣으면 DB 가 잠깐 끊겨도 모든 pod 가 재시작된다. `metrics-exporter-prometheus` 기본 feature 의 http listener 를 켜면 이 `/healthz` 를 그 포트에 둘 수 없고, 그 listener 의 내장 `/health` 는 항상 OK 라 liveness 신호가 아니다. **`/metrics`**: exporter 설정(`default-features = false`, `run_upkeep()` 주기 호출)은 [rust-async-tokio](../rust-async-tokio/SKILL.md) 를 따른다. 큐 길이 gauge 의 COUNT 는 replica 마다 하지 않고 한 곳에서만 한다. claim 실패 counter 에 알람을 건다. migration 뒤 `claim.sql` 이 `42703` 으로 깨지면 worker 는 일하지 않는데 heartbeat 는 계속 갱신되어 `/healthz` 는 초록이다.

## 10. 테스트 — claim·lease 는 실제 Postgres 로

```rust
#[sqlx::test(migrations = "./migrations")]
async fn should_not_hand_out_same_job_twice_when_claims_race(pool: PgPool) -> sqlx::Result<()> {
    // Given
    seed_pending(&pool, 10).await?;
    // When
    let (a, b) = tokio::join!(claim(&pool, 10, LEASE), claim(&pool, 10, LEASE));
    // Then
    let (a, b) = (a?, b?);
    let ids: BTreeSet<i64> = a.iter().chain(&b).map(|j| j.id).collect();
    assert_eq!((ids.len(), a.len() + b.len()), (10, 10)); // 겹치지 않고 빠짐없이
    Ok(())
}
```

- `#[sqlx::test]` 는 `migrate` feature 와 `PgPool` 인자가 있으면 테스트마다 새 DB 를 만든다. superuser `DATABASE_URL` 이 필요하고, 없으면 `DATABASE_URL must be set` 으로 panic 한다. 같은 방식으로 "reaper 뒤 finish 는 `Fenced::LeaseLost`", "attempts 가 max 에 닿은 만료 job 은 dead", "반납된 job 이 max+1 번째로 claim 되지 않는다" 를 고정한다. DB 없이 도는 것(`next_step`, `backoff`, `permanent_by_sqlstate`, `classify_compute`)은 단위 테스트로 둔다. 테스트 배치와 testcontainers 는 [rust-testing](../rust-testing/SKILL.md).

## Build vs Buy

- **apalis + apalis-postgres** (sqlx 0.9): 자체 `apalis` 스키마와 migration 24개(검증일 기준)라 Go 가 enqueue 하면 그 스키마·인코딩에 묶인다. **graphile_worker** (Rust, sqlx 0.9) 는 Node graphile-worker 와 "mostly compatible" 이라 Node producer 가 이미 있을 때 맞다. **pgmq**: SQL 함수로 된 큐 API(`pgmq.send()`, visibility timeout). extension 으로도, SQL 만으로도 설치할 수 있고 Rust client 가 직접 설치할 수도 있어 managed DB 에서도 쓸 수 있다. 0.33 계열은 sqlx 0.8, 0.34 alpha 가 0.9. Go 는 pgmq 의 스키마·함수로 enqueue 하게 된다. **sqlxmq, underway** (sqlx 0.8): sqlx 0.9 프로젝트에 섞으면 sqlx 가 두 벌 들어오고 `PgPool` 타입이 맞지 않는다.

## Anti-Patterns

| 실수 | 문제 | 해결 |
|---|---|---|
| `FOR UPDATE` 트랜잭션을 연 채 처리 | 연결 점유, VACUUM horizon 고정, dead tuple 누적 | claim 은 단일 UPDATE 로 끝내고 lease 로 소유를 표시 |
| 실패할 때 attempts +1 | OOM 으로 죽는 job 이 끝없이 반복 | claim 할 때 +1 |
| `WHERE id = $1` 만으로 done·결과 기록 | lease 를 잃은 zombie 가 덮어쓴다 | `AND lease_token = $2` fencing, 0 rows = LeaseLost (§3) |
| `ColumnDecode`·`ColumnNotFound`·`42703` 을 입력 거부(InvalidTrack)나 Transient 로 분류 | 스키마 drift 때 모든 job 이 '잘못된 입력' 으로 dead 거나, 재시도를 다 쓰고 알람 없이 dead | Permanent(Schema) + 알람. 입력 거부는 `Ok(Judgement)` |
| NOTIFY 만으로 깨우기, drain 함수 안에서 job 완료만 기다리기 | 재연결 중 알림 유실, 슬롯이 비어도 안 채워지고 heartbeat 가 멈춘다 | polling fallback, LISTEN 직후 claim, JoinSet 완료를 `select!` 분기로 |

## Verification Criteria

이 skill 을 적용한 결과가 다음 조건을 만족해야 한다:

1. **[기능 검증]** — 실제 Postgres(`#[sqlx::test]` 또는 testcontainers)에서 다음이 통과한다: 동시 claim 두 개가 겹치지 않는다, reaper 뒤 finish 가 `LeaseLost` 를 돌려주고 결과를 쓰지 않는다, attempts 가 `max_attempts` 에 닿은 job 이 dead 가 된다, 같은 activity 가 done 뒤 다시 enqueue·처리돼도 `(activity_id, engine_version)` 결과 행은 1개다 (예: `DATABASE_URL=... cargo test --features db-tests --test db`. 배치는 [rust-testing](../rust-testing/SKILL.md) §실제 DB)
2. **[오류 경로]** — `next_step`·`backoff`·SQLSTATE·sqlx 오류 분류(`23505`·`22P02` → Bug, `42703`·`ColumnNotFound` → Schema, 재시도 목록 → Transient)·`classify_compute` 를 표의 행마다 단위 테스트로 고정하고, 처음 보는 오류가 Transient 로 간다는 테스트가 있다 (예: `cargo test --lib`)
3. **[sqlx 정합]** — CI 에서 `cargo sqlx prepare --check` 가 통과하고 `.sqlx` 가 커밋되어 있다. `query!` 계열에 const 를 넘긴 곳이 없다
4. **[운영]** — listener 세션을 `SELECT pg_terminate_backend(pid)` 로 끊어도 polling 주기 안에 job 이 처리된다. lease 보다 긴 job 이 모든 슬롯을 채운 동안에도 `/healthz` heartbeat 가 poll 주기마다 갱신된다. SIGTERM 뒤 예산 안에 프로세스가 끝난다. 예산 안에 끝난 job 은 done·pending·dead 중 하나로 기록되고, 예산을 넘긴 job 은 반납을 구현했다면 바로 pending·dead, 아니면 lease 만료 뒤 reaper 가 되돌린다
5. **[일관성]** — [rust.md](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md) 의 lint 설정으로 `cargo clippy --all-targets -- -D warnings` 가 통과한다. `grep -rn "spawn_blocking" src/` 가 `CpuGate` 안에만 나온다. `status` 를 바꾸는 SQL 은 claim·finish·`apply_outcome`·reaper·반납 다섯 곳뿐이다

## 참조 스킬

- rust-error-handling (`JobFailure`·`next_step`·panic 정책. 이 skill 은 그 분류를 SQL 로 실행한다) · [rust-engine-architecture](../rust-engine-architecture/SKILL.md) (core/shell 분리, `ENGINE_VERSION`·`params_hash` 와 결과 키) · [rust-async-tokio](../rust-async-tokio/SKILL.md) (`CpuGate`, `select!` 취소 안전성, 고정 컴포넌트 종료와 예산, 메트릭 exporter 설정) · [rust-testing](../rust-testing/SKILL.md) (`#[sqlx::test]`·testcontainers 배치, Given-When-Then 이름 규칙) · `/dx:negative-path-coverage` (timeout·재시도·부분 실패 테스트 체크리스트)

## Sources / Verified

출처·인용·상태의 전문은 [2026-11-15 Rust plugin 검증 기록](https://github.com/ressKim-io/ress-claude-agents/blob/main/docs/audit/2026-11-15-rust-plugin-verification.md) 에 있다. Rust 코드 블록은 scratch crate 에서 `cargo check`·`clippy -D warnings` 를 통과했고 분류 함수는 단위 테스트로 돌렸다. SQL 과 DB 테스트는 Postgres 가 없어 실행하지 않았다. 다음 재검증은 2027-02.
- PostgreSQL 18 [SELECT locking](https://www.postgresql.org/docs/18/sql-select.html) · [UPDATE](https://www.postgresql.org/docs/18/sql-update.html) · [WITH](https://www.postgresql.org/docs/18/queries-with.html) · [isolation](https://www.postgresql.org/docs/18/transaction-iso.html) · [explicit locking](https://www.postgresql.org/docs/18/explicit-locking.html) · [INSERT](https://www.postgresql.org/docs/18/sql-insert.html) · [error codes](https://www.postgresql.org/docs/18/errcodes-appendix.html) · [client config](https://www.postgresql.org/docs/18/runtime-config-client.html) · [make_interval](https://www.postgresql.org/docs/18/functions-datetime.html) · [power](https://www.postgresql.org/docs/18/functions-math.html) · [function type resolution](https://www.postgresql.org/docs/18/typeconv-func.html) · [pg_type.dat](https://raw.githubusercontent.com/postgres/postgres/REL_18_STABLE/src/include/catalog/pg_type.dat) · [pg_cast.dat](https://raw.githubusercontent.com/postgres/postgres/REL_18_STABLE/src/include/catalog/pg_cast.dat) · [LEAST](https://www.postgresql.org/docs/18/functions-conditional.html) · [UNION·CASE type resolution](https://www.postgresql.org/docs/18/typeconv-union-case.html) · [float.c dpow overflow](https://raw.githubusercontent.com/postgres/postgres/REL_18_STABLE/src/backend/utils/adt/float.c) · [gen_random_uuid](https://www.postgresql.org/docs/18/functions-uuid.html) · [pg_terminate_backend](https://www.postgresql.org/docs/18/functions-admin.html) · [n_dead_tup](https://www.postgresql.org/docs/18/monitoring-stats.html) · [numutils.c 22P02 메시지](https://raw.githubusercontent.com/postgres/postgres/REL_18_STABLE/src/backend/utils/adt/numutils.c) — 검증일 2026-11-15 · ✅ verified (`power(int, int)`·`least(float8, int)` 가 double precision 으로 풀리는 것은 float8 의 `typispreferred` 와 implicit cast, `power` 결과가 inf 면 overflow 오류인 것은 `dpow` 소스로 확인. `ON CONFLICT DO UPDATE ... WHERE` 는 조건이 참인 행만 갱신한다. SQL 은 실행하지 않음. ⚠️ `IN`-subquery 가 LIMIT 보다 많이 잠글 수 있다는 주장은 WITH·SELECT 문서에서 찾지 못해 본문은 CTE 로 피해 가기만 한다) · subagent; PostgreSQL [NOTIFY](https://www.postgresql.org/docs/18/sql-notify.html) · [LISTEN](https://www.postgresql.org/docs/18/sql-listen.html) · [async.c REL_19_STABLE](https://raw.githubusercontent.com/postgres/postgres/REL_19_STABLE/src/backend/commands/async.c) · [Recall.ai](https://recall.ai/blog/postgres-listen-notify-does-not-scale) · [DBOS](https://dbos.dev/blog/postgres-listen-notify-scalability) · [PgBouncer features](https://www.pgbouncer.org/features.html) · [sqlx #4484](https://github.com/transact-rs/sqlx/issues/4484) · [PR #4485](https://github.com/transact-rs/sqlx/pull/4485) · [#4014](https://github.com/transact-rs/sqlx/issues/4014) · [PR #4016](https://github.com/transact-rs/sqlx/pull/4016) — 검증일 2026-11-15 · ✅ verified (PR #4485 는 머지됐고 crates.io 최신은 0.9.0 이라 미릴리스. Recall.ai 갱신분의 "해결됨" 문구는 소스로 반박되어 인용하지 않음. DBOS 처리량 수치는 미대조라 인용하지 않음) · subagent; sqlx v0.9.0 소스 [listener.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-postgres/src/listener.rs) · [error.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/error.rs) · [row.rs try_get](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/row.rs) · [pool options.rs](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/pool/options.rs) · [FromRow derive](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-macros-core/src/derives/row.rs) · [macro data source](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-macros-core/src/query/mod.rs) · [query_as.rs fetch_one](https://raw.githubusercontent.com/launchbadge/sqlx/v0.9.0/sqlx-core/src/query_as.rs) · docs [query!](https://docs.rs/sqlx/0.9.0/sqlx/macro.query.html) · [query_file!](https://docs.rs/sqlx/0.9.0/sqlx/macro.query_file.html) · [query_file_as!](https://docs.rs/sqlx/0.9.0/sqlx/macro.query_file_as.html) · [std include_str!](https://doc.rust-lang.org/std/macro.include_str.html) · [Transaction](https://docs.rs/sqlx/0.9.0/sqlx/struct.Transaction.html) · [sqlx::test](https://docs.rs/sqlx/0.9.0/sqlx/attr.test.html) · [features](https://docs.rs/crate/sqlx/0.9.0/features) · [CHANGELOG](https://raw.githubusercontent.com/launchbadge/sqlx/main/CHANGELOG.md) · [sqlx-cli README](https://raw.githubusercontent.com/launchbadge/sqlx/main/sqlx-cli/README.md) · [crates.io](https://crates.io/api/v1/crates/sqlx) — 검증일 2026-11-15 · ✅ verified (소스는 로컬 registry 와 재대조. `try_get` 은 `ColumnNotFound`·`ColumnDecode` 를, `Value::try_decode` 는 `Decode` 를 돌려준다. `query_file!` 경로는 crate 루트, `include_str!` 는 호출한 파일 기준. `.sqlx` 탐색 순서(`SQLX_OFFLINE_DIR` → manifest dir → workspace 루트)와 `fetch_one` 의 `RowNotFound` 도 소스로 확인. const SQL 거부, `u32` bind 의 E0277, `DATABASE_URL must be set` 은 로컬 재현) · subagent; tokio [select!](https://docs.rs/tokio/1.54.1/tokio/macro.select.html) · [JoinSet](https://docs.rs/tokio/1.54.1/tokio/task/struct.JoinSet.html) · [watch::Sender](https://docs.rs/tokio/1.54.1/tokio/sync/watch/struct.Sender.html) · [timeout](https://docs.rs/tokio/1.54.1/tokio/time/fn.timeout.html) · [MissedTickBehavior](https://docs.rs/tokio/1.54.1/tokio/time/enum.MissedTickBehavior.html) · [CancellationToken](https://docs.rs/tokio-util/0.7.20/tokio_util/sync/struct.CancellationToken.html) · [graceful shutdown](https://tokio.rs/tokio/topics/shutdown) · Kubernetes [pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/) · [probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/) · [PrometheusBuilder](https://docs.rs/metrics-exporter-prometheus/0.18.3/metrics_exporter_prometheus/struct.PrometheusBuilder.html) · [http_listener.rs](https://docs.rs/crate/metrics-exporter-prometheus/0.18.3/source/src/exporter/http_listener.rs) · [PlanetScale — queue health](https://planetscale.com/blog/keeping-a-postgres-queue-healthy) · [Solid Queue](https://raw.githubusercontent.com/rails/solid_queue/main/README.md) · [River maintenance](https://riverqueue.com/docs/maintenance-services) · [outbox](https://microservices.io/patterns/data/transactional-outbox.html) · [AWS outbox](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) · [brandur](https://brandur.org/job-drain) — 검증일 2026-11-15 · ✅ verified (`join_next` cancel safe, `send_replace` 는 receiver 가 없어도 동작, `timeout` 이 다 되면 안쪽 future 를 취소, `/health` 고정 응답은 로컬 registry 소스: tokio 1.54.1, metrics-exporter-prometheus 0.18.3) · subagent; [apalis-postgres](https://crates.io/api/v1/crates/apalis-postgres) · [apalis migrations](https://github.com/apalis-dev/apalis-postgres/tree/main/migrations) · [graphile_worker](https://crates.io/api/v1/crates/graphile_worker) · [pgmq](https://crates.io/api/v1/crates/pgmq) · [pgmq 설치 방식](https://github.com/pgmq/pgmq/blob/main/pgmq-extension/README.md) · [sqlxmq](https://crates.io/api/v1/crates/sqlxmq) · [underway](https://crates.io/api/v1/crates/underway) — 검증일 2026-11-15 · ✅ verified (pgmq SQL-only 설치와 Rust client 설치는 README 와 crate readme 0.33.7) · subagent
