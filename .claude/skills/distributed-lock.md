# Distributed Lock Patterns

MSA/다중 서버 환경에서의 분산 락 패턴

## 언제 필요한가?

| 상황 | 분산 락 필요 |
|------|-------------|
| 단일 서버 | ❌ (로컬 Mutex/Lock) |
| 다중 서버 + DB만 | △ (DB 락으로 가능) |
| MSA + 서비스 간 조율 | ✅ |
| 스케줄러 중복 방지 | ✅ |
| 결제/재고 등 크리티컬 | ✅ |

---

## Redis 분산 락 (기본)

### Spring Boot + Redisson

**의존성**
```groovy
implementation 'org.redisson:redisson-spring-boot-starter:3.27.0'
```

**설정**
```yaml
spring:
  data:
    redis:
      host: localhost
      port: 6379
```

**구현**
```java
@Service
@RequiredArgsConstructor
public class StockService {
    private final RedissonClient redissonClient;
    private final ProductRepository productRepository;

    public void decreaseStock(Long productId, int quantity) {
        String lockKey = "lock:product:" + productId;
        RLock lock = redissonClient.getLock(lockKey);

        try {
            // 최대 5초 대기, 락 획득 후 3초 유지
            boolean acquired = lock.tryLock(5, 3, TimeUnit.SECONDS);
            if (!acquired) {
                throw new LockAcquisitionException("락 획득 실패");
            }

            // 크리티컬 섹션
            Product product = productRepository.findById(productId)
                .orElseThrow();
            product.decreaseStock(quantity);
            productRepository.save(product);

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new LockAcquisitionException("락 획득 중 인터럽트");
        } finally {
            // 항상 해제 (현재 스레드가 보유한 경우만)
            if (lock.isLocked() && lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }
}
```

### AOP로 깔끔하게

**어노테이션**
```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface DistributedLock {
    String key();                    // 락 키 (SpEL 지원)
    long waitTime() default 5000;    // 대기 시간 (ms)
    long leaseTime() default 3000;   // 락 유지 시간 (ms)
}
```

**Aspect**
```java
@Aspect
@Component
@RequiredArgsConstructor
public class DistributedLockAspect {
    private final RedissonClient redissonClient;

    @Around("@annotation(distributedLock)")
    public Object around(ProceedingJoinPoint pjp, DistributedLock distributedLock)
            throws Throwable {
        String key = parseKey(distributedLock.key(), pjp);
        RLock lock = redissonClient.getLock(key);

        try {
            boolean acquired = lock.tryLock(
                distributedLock.waitTime(),
                distributedLock.leaseTime(),
                TimeUnit.MILLISECONDS
            );

            if (!acquired) {
                throw new LockAcquisitionException("락 획득 실패: " + key);
            }

            return pjp.proceed();

        } finally {
            if (lock.isLocked() && lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }

    private String parseKey(String keyExpression, ProceedingJoinPoint pjp) {
        // SpEL 파싱 로직 (productId -> lock:product:123)
        // ...
    }
}
```

**사용**
```java
@Service
public class StockService {

    @DistributedLock(key = "'lock:product:' + #productId")
    @Transactional
    public void decreaseStock(Long productId, int quantity) {
        Product product = productRepository.findById(productId).orElseThrow();
        product.decreaseStock(quantity);
    }
}
```

---

## Go + Redis 분산 락

### go-redis/redis
```go
import (
    "context"
    "time"
    "github.com/redis/go-redis/v9"
    "github.com/google/uuid"
)

type DistributedLock struct {
    client   *redis.Client
    key      string
    value    string  // 고유 식별자 (UUID)
    duration time.Duration
}

func NewLock(client *redis.Client, key string, duration time.Duration) *DistributedLock {
    return &DistributedLock{
        client:   client,
        key:      "lock:" + key,
        value:    uuid.New().String(),
        duration: duration,
    }
}

func (l *DistributedLock) Acquire(ctx context.Context) (bool, error) {
    // SET key value NX PX duration
    result, err := l.client.SetNX(ctx, l.key, l.value, l.duration).Result()
    return result, err
}

func (l *DistributedLock) Release(ctx context.Context) error {
    // Lua 스크립트: 본인 락만 해제
    script := `
        if redis.call("GET", KEYS[1]) == ARGV[1] then
            return redis.call("DEL", KEYS[1])
        else
            return 0
        end
    `
    _, err := l.client.Eval(ctx, script, []string{l.key}, l.value).Result()
    return err
}

// 사용
func DecreaseStock(ctx context.Context, rdb *redis.Client, productID int64, qty int) error {
    lock := NewLock(rdb, fmt.Sprintf("product:%d", productID), 3*time.Second)

    acquired, err := lock.Acquire(ctx)
    if err != nil {
        return err
    }
    if !acquired {
        return errors.New("failed to acquire lock")
    }
    defer lock.Release(ctx)

    // 크리티컬 섹션
    return updateStock(productID, qty)
}
```

### Redsync (Redlock 알고리즘)
```go
import (
    "github.com/go-redsync/redsync/v4"
    "github.com/go-redsync/redsync/v4/redis/goredis/v9"
)

func NewRedsync(clients ...*redis.Client) *redsync.Redsync {
    pools := make([]redsync.Pool, len(clients))
    for i, client := range clients {
        pools[i] = goredis.NewPool(client)
    }
    return redsync.New(pools...)
}

func DecreaseStockWithRedsync(ctx context.Context, rs *redsync.Redsync, productID int64, qty int) error {
    mutex := rs.NewMutex(
        fmt.Sprintf("lock:product:%d", productID),
        redsync.WithExpiry(3*time.Second),
        redsync.WithTries(3),
        redsync.WithRetryDelay(100*time.Millisecond),
    )

    if err := mutex.LockContext(ctx); err != nil {
        return fmt.Errorf("락 획득 실패: %w", err)
    }
    defer mutex.UnlockContext(ctx)

    return updateStock(productID, qty)
}
```

---

## 스케줄러 중복 방지

### Spring + ShedLock

**의존성**
```groovy
implementation 'net.javacrumbs.shedlock:shedlock-spring:5.10.0'
implementation 'net.javacrumbs.shedlock:shedlock-provider-redis-spring:5.10.0'
```

**설정**
```java
@Configuration
@EnableSchedulerLock(defaultLockAtMostFor = "10m")
public class ShedLockConfig {

    @Bean
    public LockProvider lockProvider(RedisConnectionFactory connectionFactory) {
        return new RedisLockProvider(connectionFactory);
    }
}
```

**사용**
```java
@Component
public class ScheduledTasks {

    @Scheduled(cron = "0 0 * * * *")  // 매시 정각
    @SchedulerLock(
        name = "hourlyTask",
        lockAtLeastFor = "5m",   // 최소 5분 유지 (중복 실행 방지)
        lockAtMostFor = "10m"    // 최대 10분 (장애 시 자동 해제)
    )
    public void hourlyTask() {
        // 다중 인스턴스 중 하나만 실행
    }
}
```

---

## Fencing Token (안전한 락)

TTL 만료로 인한 문제 방지

```java
@Service
public class SafeStockService {
    private final RedissonClient redissonClient;

    public void safeUpdate(Long productId, int quantity) {
        String lockKey = "lock:product:" + productId;
        String tokenKey = "token:product:" + productId;

        RLock lock = redissonClient.getLock(lockKey);
        RAtomicLong tokenCounter = redissonClient.getAtomicLong(tokenKey);

        try {
            if (!lock.tryLock(5, 10, TimeUnit.SECONDS)) {
                throw new LockAcquisitionException("락 획득 실패");
            }

            // Fencing Token 발급
            long token = tokenCounter.incrementAndGet();

            // DB 업데이트 시 토큰 검증
            int updated = jdbcTemplate.update(
                "UPDATE product SET stock = stock - ?, last_token = ? " +
                "WHERE id = ? AND (last_token IS NULL OR last_token < ?)",
                quantity, token, productId, token
            );

            if (updated == 0) {
                throw new StaleTokenException("오래된 토큰");
            }

        } finally {
            if (lock.isLocked() && lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }
}
```

---

## 선택 가이드

```
분산 락 필요?
    │
    ├─ 스케줄러 중복 방지 ──────> ShedLock
    │
    ├─ 단순 크리티컬 섹션 ──────> Redis + Redisson (단일 노드)
    │
    ├─ 높은 가용성 필요 ────────> Redlock (다중 Redis 노드)
    │
    └─ 강력한 일관성 필요 ──────> ZooKeeper / etcd
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| TTL 없음 | 프로세스 죽으면 영구 락 | 항상 TTL 설정 |
| 고유 ID 없이 해제 | 다른 클라이언트 락 해제 | UUID로 본인 확인 |
| finally에서 해제 안함 | 락 누수 | try-finally 필수 |
| 락 범위 너무 큼 | 병목 | 최소 범위로 |
| TTL만 믿음 | GC pause로 만료 후 작업 | Fencing Token |
| 단일 Redis 장애 | 서비스 중단 | Redlock 또는 클러스터 |

---

## 체크리스트

- [ ] 락 키는 리소스별로 고유하게 (예: `lock:product:{id}`)
- [ ] TTL 적절히 설정 (작업 시간 + 여유)
- [ ] UUID로 락 소유자 식별
- [ ] try-finally로 반드시 해제
- [ ] 트랜잭션은 락 해제 전에 커밋
- [ ] 스케줄러는 ShedLock 사용
- [ ] 크리티컬한 경우 Fencing Token 검토
- [ ] 고가용성 필요시 Redlock/클러스터 검토
