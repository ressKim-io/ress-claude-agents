# Go Database Access Patterns

Go DB 라이브러리 선택 가이드 및 production-ready 패턴. ORM 없이 SQL 중심 개발.

## Quick Reference (결정 트리)

```
라이브러리 선택
    ├─ PostgreSQL 전용 (권장) ────> pgx native + sqlc (golden path)
    ├─ PostgreSQL + 가벼운 래퍼 ──> pgx native 단독
    ├─ Multi-DB (MySQL+PG) ──────> sqlx 또는 bun
    ├─ 복잡한 도메인/관계 ────────> ent (그래프 기반 코드 생성)
    └─ 기존 lib/pq 코드 ─────────> pgx/stdlib 로 드롭인 교체

드라이버 상태 (2025-2026)
    ├─ lib/pq ───────> 유지보수 모드 (deprecated)
    ├─ sqlx ─────────> 유지보수 모드 (jmoiron 거의 업데이트 안 함)
    ├─ pgx v5 ───────> 활발 개발, PostgreSQL 표준 드라이버
    ├─ sqlc ─────────> 활발 개발, SQL-first 코드 생성
    └─ ent ──────────> 활발 개발 (Atlas 팀)
```

---

## Connection Pool 설정 (공통, 가장 중요)

```go
// database/sql 기반 (sqlx, bun, ent 공통)
db.SetMaxOpenConns(25)                 // 필수! 기본값 0(무제한)이면 DB 터짐
db.SetMaxIdleConns(25)                 // MaxOpenConns 와 동일하게
db.SetConnMaxLifetime(5 * time.Minute) // LB/DNS 변경 대응
db.SetConnMaxIdleTime(1 * time.Minute) // 트래픽 감소 시 풀 축소
```

```go
// pgxpool (pgx native) - 권장
config, _ := pgxpool.ParseConfig(databaseURL)
config.MaxConns = int32(max(4, runtime.NumCPU()))
config.MinConns = 2
config.MaxConnLifetime = 30 * time.Minute
config.MaxConnIdleTime = 5 * time.Minute
config.HealthCheckPeriod = 30 * time.Second
pool, _ := pgxpool.NewWithConfig(ctx, config)
```

| 설정 | 소규모 | 중규모 | 고트래픽 |
|------|--------|--------|----------|
| MaxOpenConns | 10 | 25 | 50-100 |
| MaxIdleConns | 10 | 25 | 25-50 |
| ConnMaxLifetime | 5m | 5m | 30m |
| ConnMaxIdleTime | 1m | 1m | 5m |

> **공식**: `(DB max_connections / 앱 인스턴스 수) * 0.8`

---

## 1. pgx (PostgreSQL 표준 드라이버)

`github.com/jackc/pgx/v5` + `github.com/jackc/pgx/v5/pgxpool`

database/sql 대비 **50-100% 빠름**. COPY, Batch, LISTEN/NOTIFY 등 PostgreSQL 전용 기능 지원.

### 연결

```go
func NewPool(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
    config, err := pgxpool.ParseConfig(databaseURL)
    if err != nil {
        return nil, fmt.Errorf("parse config: %w", err)
    }
    config.MaxConns = int32(max(4, runtime.NumCPU()))
    config.MinConns = 2
    config.MaxConnLifetime = 30 * time.Minute
    config.MaxConnIdleTime = 5 * time.Minute

    pool, err := pgxpool.NewWithConfig(ctx, config)
    if err != nil {
        return nil, fmt.Errorf("create pool: %w", err)
    }
    if err := pool.Ping(ctx); err != nil {
        pool.Close()
        return nil, fmt.Errorf("ping: %w", err)
    }
    return pool, nil
}
```

### CRUD

```go
// CREATE - NamedArgs 사용
err := pool.QueryRow(ctx,
    `INSERT INTO users (name, email) VALUES (@name, @email) RETURNING id, created_at`,
    pgx.NamedArgs{"name": u.Name, "email": u.Email},
).Scan(&u.ID, &u.CreatedAt)

// READ (단건)
var u User
err := pool.QueryRow(ctx,
    "SELECT id, name, email FROM users WHERE id = $1", id,
).Scan(&u.ID, &u.Name, &u.Email)
if errors.Is(err, pgx.ErrNoRows) {
    return nil, ErrUserNotFound
}

// READ (목록) - CollectRows (pgx v5)
rows, _ := pool.Query(ctx,
    "SELECT id, name, email FROM users ORDER BY id LIMIT $1 OFFSET $2", limit, offset)
users, err := pgx.CollectRows(rows, pgx.RowToStructByName[User])

// UPDATE
tag, _ := pool.Exec(ctx, "UPDATE users SET name=$1 WHERE id=$2", name, id)
if tag.RowsAffected() == 0 { return ErrUserNotFound }

// DELETE
tag, _ := pool.Exec(ctx, "DELETE FROM users WHERE id = $1", id)
```

### Batch (네트워크 라운드트립 최소화)

```go
batch := &pgx.Batch{}
for _, u := range users {
    batch.Queue("INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id",
        u.Name, u.Email)
}
br := pool.SendBatch(ctx, batch)
defer br.Close()
for range users {
    var id int64
    br.QueryRow().Scan(&id)
}
```

### COPY Protocol (대량 삽입, INSERT 대비 10-70x 빠름)

```go
copyCount, err := pool.CopyFrom(ctx,
    pgx.Identifier{"users"},
    []string{"name", "email"},
    pgx.CopyFromSlice(len(users), func(i int) ([]any, error) {
        return []any{users[i].Name, users[i].Email}, nil
    }),
)
```

### Transaction - BeginTxFunc (권장)

```go
err := pgx.BeginTxFunc(ctx, pool, pgx.TxOptions{
    IsoLevel: pgx.Serializable,
}, func(tx pgx.Tx) error {
    var balance float64
    err := tx.QueryRow(ctx,
        "SELECT balance FROM accounts WHERE id=$1 FOR UPDATE", fromID,
    ).Scan(&balance)
    if err != nil { return fmt.Errorf("check balance: %w", err) }
    if balance < amount { return ErrInsufficientFunds }

    _, err = tx.Exec(ctx, "UPDATE accounts SET balance=balance-$1 WHERE id=$2", amount, fromID)
    if err != nil { return fmt.Errorf("debit: %w", err) }
    _, err = tx.Exec(ctx, "UPDATE accounts SET balance=balance+$1 WHERE id=$2", amount, toID)
    if err != nil { return fmt.Errorf("credit: %w", err) }
    return nil
})
// 성공 시 자동 Commit, 에러 시 자동 Rollback
```

---

## 2. sqlc (SQL-first 코드 생성)

`go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest`

SQL 작성 -> 타입 세이프 Go 코드 자동 생성. pgx와 조합이 **golden path**.

### sqlc.yaml

```yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "db/query/"
    schema: "db/schema/"
    gen:
      go:
        package: "db"
        out: "internal/db"
        sql_package: "pgx/v5"        # pgx native 사용
        emit_json_tags: true
        emit_interface: true          # Querier 인터페이스 (mock 용)
        emit_empty_slices: true       # nil 대신 [] 반환
        query_parameter_limit: 1      # 파라미터 2개 이상이면 struct 생성
```

### SQL 쿼리 작성 (db/query/users.sql)

```sql
-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: ListUsers :many
SELECT * FROM users ORDER BY id LIMIT $1 OFFSET $2;

-- name: CreateUser :one
INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *;

-- name: UpdateUser :exec
UPDATE users SET name = $1, email = $2 WHERE id = $3;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;

-- name: BulkCreateUsers :batchone
INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *;
```

| 어노테이션 | 반환 타입 | 용도 |
|-----------|----------|------|
| `:one` | `(T, error)` | 단건 조회 |
| `:many` | `([]T, error)` | 목록 조회 |
| `:exec` | `error` | INSERT/UPDATE/DELETE |
| `:execrows` | `(int64, error)` | 영향받은 행 수 |
| `:batchone` | Batch 메서드 | 대량 단건 |
| `:batchexec` | Batch 메서드 | 대량 실행 |

### 사용 (자동 생성된 코드)

```go
pool, _ := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
queries := db.New(pool)

// CREATE
user, err := queries.CreateUser(ctx, db.CreateUserParams{
    Name: "Alice", Email: "alice@example.com",
})

// READ
u, err := queries.GetUser(ctx, userID)

// Transaction - WithTx
tx, _ := pool.Begin(ctx)
defer tx.Rollback(ctx)
qtx := queries.WithTx(tx)
user, _ := qtx.CreateUser(ctx, params)
_ = tx.Commit(ctx)
```

---

## 3. sqlx (database/sql 확장)

`github.com/jmoiron/sqlx` -- Multi-DB 지원. 구조체 스캔, Named 쿼리.

> **주의**: 유지보수 모드. 새 PostgreSQL 프로젝트는 pgx 권장.

```go
// 연결
db, _ := sqlx.Connect("postgres", dsn)
db.SetMaxOpenConns(25)

// 모델 - db 태그 사용
type User struct {
    ID    int64  `db:"id"`
    Name  string `db:"name"`
    Email string `db:"email"`
}

// 단건 조회 - Get
var u User
err := db.GetContext(ctx, &u, "SELECT * FROM users WHERE id = $1", id)

// 목록 조회 - Select
var users []User
err := db.SelectContext(ctx, &users, "SELECT * FROM users ORDER BY id LIMIT $1", limit)

// Named 쿼리
result, err := db.NamedExecContext(ctx,
    "UPDATE users SET name=:name, email=:email WHERE id=:id", &user)

// Transaction 헬퍼
func WithTx(ctx context.Context, db *sqlx.DB, fn func(tx *sqlx.Tx) error) error {
    tx, err := db.BeginTxx(ctx, nil)
    if err != nil { return err }
    defer func() {
        if p := recover(); p != nil { tx.Rollback(); panic(p) }
    }()
    if err := fn(tx); err != nil {
        tx.Rollback()
        return err
    }
    return tx.Commit()
}
```

---

## Error Handling (pgx)

```go
import "github.com/jackc/pgx/v5/pgconn"

func handleDBError(err error) error {
    if errors.Is(err, pgx.ErrNoRows) { return ErrNotFound }
    if errors.Is(err, context.DeadlineExceeded) { return ErrTimeout }

    var pgErr *pgconn.PgError
    if errors.As(err, &pgErr) {
        switch pgErr.Code {
        case "23505": return fmt.Errorf("%w: %s", ErrDuplicate, pgErr.ConstraintName)
        case "23503": return fmt.Errorf("%w: %s", ErrForeignKey, pgErr.ConstraintName)
        case "40001": return ErrSerializationFailure // 재시도 가능
        }
    }
    return fmt.Errorf("database: %w", err)
}
```

---

## Testing

### testcontainers-go (통합 테스트, 권장)

```go
func testDB(t *testing.T) *pgxpool.Pool {
    t.Helper()
    ctx := context.Background()
    pg, err := postgres.Run(ctx, "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"), postgres.WithPassword("test"),
        postgres.WithInitScripts("testdata/schema.sql"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("ready to accept connections").
                WithOccurrence(2).WithStartupTimeout(30*time.Second)),
    )
    if err != nil { t.Fatal(err) }
    t.Cleanup(func() { pg.Terminate(ctx) })

    connStr, _ := pg.ConnectionString(ctx, "sslmode=disable")
    pool, _ := pgxpool.New(ctx, connStr)
    t.Cleanup(pool.Close)
    return pool
}
```

### pgxmock (유닛 테스트)

```go
import pgxmock "github.com/pashagolub/pgxmock/v4"

func TestGetUser(t *testing.T) {
    mock, _ := pgxmock.NewPool()
    defer mock.Close()
    mock.ExpectQuery("SELECT .+ FROM users WHERE id").
        WithArgs(int64(1)).
        WillReturnRows(pgxmock.NewRows([]string{"id","name","email"}).
            AddRow(int64(1), "Alice", "alice@test.com"))
    user, err := GetUser(context.Background(), mock, 1)
    // assert...
}
```

### sqlc + Querier 인터페이스 Mock

`emit_interface: true` 설정 시 `Querier` 인터페이스 자동 생성 -> 표준 Go mock 사용 가능.

---

## Graceful Shutdown

```go
// 순서: HTTP 서버 먼저 종료 -> DB 풀 닫기
quit := make(chan os.Signal, 1)
signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
<-quit

shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
defer cancel()
server.Shutdown(shutdownCtx) // 1. 진행 중 요청 대기
pool.Close()                 // 2. DB 연결 종료
```

---

## Performance 비교

```
SELECT 1 row (상대 속도, 낮을수록 빠름)
pgx native     ████████             1.0x (기준)
pgx/stdlib     █████████████        1.2x
sqlx (lib/pq)  ███████████████      1.4x
bun            ██████████████       1.3x
ent            █████████████████    1.6x
GORM           ████████████████████ 2.0x

Bulk INSERT (pgx COPY vs 개별 INSERT)
pgx CopyFrom   ████                 1.0x (10-70x 빠름)
pgx Batch      ████████             2.0x
sqlx batch     ████████████████     5.0x
```

---

## Anti-patterns

| Mistake | Correct | Why |
|---------|---------|-----|
| MaxOpenConns 미설정 (기본 0) | 반드시 `SetMaxOpenConns(25)` | DB 연결 폭발 |
| `rows` 닫기 누락 | `defer rows.Close()` | 커넥션 리크 |
| `rows.Err()` 체크 안 함 | 루프 후 `rows.Err()` 확인 | 네트워크 에러 감지 |
| Context 없는 쿼리 | `QueryRowContext(ctx, ...)` | 타임아웃 없으면 영원히 블록 |
| tx 후 Rollback defer 누락 | `defer tx.Rollback()` | 트랜잭션 리크 |
| `sql.NullString` 남용 | pgx에서는 `*string` 사용 | 코드 간결화 |
| `db.Prepare()` 고동시성 | pgx 자동 statement cache 사용 | N*M statement 핸들 방지 |
| lib/pq 신규 사용 | pgx 또는 pgx/stdlib | lib/pq는 deprecated |

## References

- [jackc/pgx](https://github.com/jackc/pgx) -- PostgreSQL driver
- [sqlc.dev](https://sqlc.dev/) -- SQL-first code generation
- [jmoiron/sqlx](https://github.com/jmoiron/sqlx) -- database/sql extensions
- [entgo.io](https://entgo.io/) -- Entity framework
- [uptrace/bun](https://github.com/uptrace/bun) -- SQL-first ORM
- [testcontainers-go](https://golang.testcontainers.org/) -- Integration testing
- [go-database-sql.org](http://go-database-sql.org/) -- database/sql tutorial
