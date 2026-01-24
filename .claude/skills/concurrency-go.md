# Go Concurrency Patterns

MSA/대규모 트래픽 환경에서의 Go 동시성 문제 해결 패턴

## Race Condition 감지

### Race Detector 사용
```bash
# 테스트 시 레이스 감지
go test -race ./...

# 빌드 시 레이스 감지
go build -race -o myapp

# 실행 시 레이스 감지
go run -race main.go
```

### 감지 예시
```go
// BAD: 레이스 컨디션 발생
var counter int

func increment() {
    counter++  // 동시 접근 시 데이터 레이스
}

func main() {
    for i := 0; i < 1000; i++ {
        go increment()
    }
}
// go run -race 실행 시: WARNING: DATA RACE
```

---

## Mutex (상호 배제)

### sync.Mutex
```go
type SafeCounter struct {
    mu    sync.Mutex
    count int
}

func (c *SafeCounter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

func (c *SafeCounter) Value() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.count
}
```

### sync.RWMutex (읽기 많은 경우)
```go
type SafeCache struct {
    mu    sync.RWMutex
    items map[string]interface{}
}

func (c *SafeCache) Get(key string) (interface{}, bool) {
    c.mu.RLock()  // 읽기 락 (동시 읽기 허용)
    defer c.mu.RUnlock()
    val, ok := c.items[key]
    return val, ok
}

func (c *SafeCache) Set(key string, value interface{}) {
    c.mu.Lock()  // 쓰기 락 (배타적)
    defer c.mu.Unlock()
    c.items[key] = value
}
```

---

## Channels (Go 철학)

> "Don't communicate by sharing memory; share memory by communicating."

### 기본 패턴
```go
func worker(jobs <-chan int, results chan<- int) {
    for job := range jobs {
        results <- job * 2
    }
}

func main() {
    jobs := make(chan int, 100)
    results := make(chan int, 100)

    // 워커 3개 시작
    for w := 1; w <= 3; w++ {
        go worker(jobs, results)
    }

    // 작업 전송
    for j := 1; j <= 9; j++ {
        jobs <- j
    }
    close(jobs)

    // 결과 수집
    for r := 1; r <= 9; r++ {
        <-results
    }
}
```

### Select로 타임아웃
```go
func fetchWithTimeout(ctx context.Context, url string) ([]byte, error) {
    resultCh := make(chan []byte, 1)
    errCh := make(chan error, 1)

    go func() {
        data, err := fetch(url)
        if err != nil {
            errCh <- err
            return
        }
        resultCh <- data
    }()

    select {
    case data := <-resultCh:
        return data, nil
    case err := <-errCh:
        return nil, err
    case <-ctx.Done():
        return nil, ctx.Err()
    case <-time.After(5 * time.Second):
        return nil, errors.New("timeout")
    }
}
```

---

## Worker Pool

동시 고루틴 수 제한으로 리소스 관리

```go
type WorkerPool struct {
    workers   int
    jobs      chan Job
    results   chan Result
    wg        sync.WaitGroup
}

func NewWorkerPool(workers int) *WorkerPool {
    return &WorkerPool{
        workers: workers,
        jobs:    make(chan Job, workers*2),
        results: make(chan Result, workers*2),
    }
}

func (p *WorkerPool) Start(ctx context.Context) {
    for i := 0; i < p.workers; i++ {
        p.wg.Add(1)
        go func(workerID int) {
            defer p.wg.Done()
            for {
                select {
                case job, ok := <-p.jobs:
                    if !ok {
                        return
                    }
                    result := process(job)
                    p.results <- result
                case <-ctx.Done():
                    return
                }
            }
        }(i)
    }
}

func (p *WorkerPool) Submit(job Job) {
    p.jobs <- job
}

func (p *WorkerPool) Close() {
    close(p.jobs)
    p.wg.Wait()
    close(p.results)
}
```

---

## Database 동시성

### GORM Optimistic Locking
```go
type Product struct {
    ID      uint   `gorm:"primaryKey"`
    Name    string
    Stock   int
    Version int `gorm:"default:1"`  // 버전 필드
}

func (p *Product) BeforeUpdate(tx *gorm.DB) error {
    tx.Statement.Where("version = ?", p.Version)
    p.Version++
    return nil
}

// 사용
func DecreaseStock(db *gorm.DB, productID uint, quantity int) error {
    return db.Transaction(func(tx *gorm.DB) error {
        var product Product
        if err := tx.First(&product, productID).Error; err != nil {
            return err
        }

        if product.Stock < quantity {
            return errors.New("insufficient stock")
        }

        product.Stock -= quantity

        result := tx.Save(&product)
        if result.RowsAffected == 0 {
            return errors.New("concurrent modification detected")
        }
        return result.Error
    })
}
```

### Pessimistic Locking (FOR UPDATE)
```go
func DecreaseStockWithLock(db *gorm.DB, productID uint, quantity int) error {
    return db.Transaction(func(tx *gorm.DB) error {
        var product Product

        // SELECT ... FOR UPDATE
        if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
            First(&product, productID).Error; err != nil {
            return err
        }

        if product.Stock < quantity {
            return errors.New("insufficient stock")
        }

        product.Stock -= quantity
        return tx.Save(&product).Error
    })
}
```

---

## sync.Once (초기화)

```go
var (
    instance *Database
    once     sync.Once
)

func GetDatabase() *Database {
    once.Do(func() {
        instance = &Database{
            // 초기화 (한 번만 실행)
        }
    })
    return instance
}
```

---

## Context 취소

```go
func processWithCancel(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            // 정리 작업
            return ctx.Err()
        default:
            // 작업 수행
            if err := doWork(); err != nil {
                return err
            }
        }
    }
}

// 사용
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()

if err := processWithCancel(ctx); err != nil {
    log.Printf("처리 실패: %v", err)
}
```

---

## sync.Map (동시성 안전 맵)

```go
var cache sync.Map

// 저장
cache.Store("key", "value")

// 로드
if val, ok := cache.Load("key"); ok {
    fmt.Println(val)
}

// 없으면 저장
actual, loaded := cache.LoadOrStore("key", "default")

// 삭제
cache.Delete("key")

// 순회
cache.Range(func(key, value interface{}) bool {
    fmt.Printf("%v: %v\n", key, value)
    return true  // false 반환 시 중단
})
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| `map` 동시 접근 | panic: concurrent map writes | `sync.Map` 또는 `Mutex` |
| `defer unlock` 누락 | 데드락 | 항상 `defer mu.Unlock()` |
| 무한 고루틴 생성 | 메모리 폭발 | Worker Pool 사용 |
| 채널 close 안함 | 고루틴 누수 | `defer close(ch)` |
| 버퍼 없는 채널 블로킹 | 데드락 | 버퍼 크기 설정 또는 select |
| Context 무시 | 타임아웃/취소 안됨 | Context 전파 |

---

## 선택 가이드

```
공유 상태 있음?
    │
    ├─ 없음 ──────────────> Channels (Go Way)
    │
    └─ 있음
         │
         ├─ 읽기 많음 ──────> sync.RWMutex
         │
         ├─ 쓰기 많음 ──────> sync.Mutex
         │
         └─ 맵 캐시 ────────> sync.Map
```

```
DB 동시성?
    │
    ├─ 충돌 드묾 ──────────> Optimistic (Version)
    │
    ├─ 충돌 잦음 ──────────> Pessimistic (FOR UPDATE)
    │
    └─ MSA/다중 서버 ──────> Distributed Lock (/distributed-lock)
```

---

## 체크리스트

- [ ] `go test -race` CI에 추가
- [ ] 공유 상태에 Mutex 또는 Channel 사용
- [ ] 고루틴 수 제한 (Worker Pool)
- [ ] Context로 타임아웃/취소 처리
- [ ] `defer` 로 락 해제, 채널 close
- [ ] DB 동시성은 트랜잭션 + 락 사용
- [ ] MSA 환경이면 분산 락 검토 (/distributed-lock)
