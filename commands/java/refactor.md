# Java/Spring Refactoring

Java/Spring 코드 리팩토링 패턴을 적용합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 리팩토링 대상 코드 |
| Output | 리팩토링된 코드 + 설명 |
| Required Tools | java, gradle/maven |
| Verification | 기존 테스트 통과 |

## Refactoring Decision Tree

```
리팩토링 유형 선택:
├─ 성능 개선 필요
│   ├─ I/O-bound → Virtual Threads 적용
│   ├─ DB 쿼리 최적화 → N+1 해결, 인덱스
│   └─ 시작 시간 → GraalVM Native / CDS
├─ 코드 품질 개선
│   ├─ 중복 제거 → Extract Method/Class
│   ├─ 복잡도 감소 → Strategy/State 패턴
│   └─ 테스트 용이성 → DI 개선
└─ 모던 Java 마이그레이션
    ├─ Java 17+ → Record, Sealed, Pattern Matching
    └─ Java 21+ → Virtual Threads, Sequenced Collections
```

## Virtual Threads Migration (Java 21+)

### Before: Thread Pool 기반

```java
@Configuration
public class AsyncConfig {
    @Bean
    public Executor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(10);
        executor.setMaxPoolSize(50);
        executor.setQueueCapacity(100);
        return executor;
    }
}

@Service
public class OrderService {
    @Async("taskExecutor")
    public CompletableFuture<OrderResult> processOrder(Order order) {
        // blocking I/O operations
    }
}
```

### After: Virtual Threads

```yaml
# application.yml
spring:
  threads:
    virtual:
      enabled: true
```

```java
@Service
public class OrderService {
    @Async  // 기본으로 Virtual Thread 사용
    public CompletableFuture<OrderResult> processOrder(Order order) {
        // 동일한 blocking 코드, 하지만 Virtual Thread에서 실행
    }
}

// 명시적 Virtual Thread 사용
public class PaymentService {
    private final ExecutorService executor =
        Executors.newVirtualThreadPerTaskExecutor();

    public List<PaymentResult> processPayments(List<Payment> payments) {
        return payments.stream()
            .map(p -> executor.submit(() -> processPayment(p)))
            .map(this::getFuture)
            .toList();
    }
}
```

### Pinning 이슈 해결

```java
// Before: synchronized로 인한 Pinning
public class Counter {
    private int count = 0;

    public synchronized void increment() {  // Pinning 발생!
        count++;
    }
}

// After: ReentrantLock 사용
public class Counter {
    private int count = 0;
    private final ReentrantLock lock = new ReentrantLock();

    public void increment() {
        lock.lock();
        try {
            count++;
        } finally {
            lock.unlock();
        }
    }
}
```

## Modern Java Patterns

### Record 활용

```java
// Before: POJO with Lombok
@Data
@AllArgsConstructor
public class UserDto {
    private Long id;
    private String email;
    private String name;
}

// After: Record (불변, 간결)
public record UserDto(Long id, String email, String name) {
    // Compact constructor로 검증
    public UserDto {
        Objects.requireNonNull(email, "email is required");
    }
}
```

### Pattern Matching (Java 21+)

```java
// Before: instanceof + cast
public String describe(Object obj) {
    if (obj instanceof String) {
        String s = (String) obj;
        return "String: " + s.length();
    } else if (obj instanceof Integer) {
        Integer i = (Integer) obj;
        return "Integer: " + i;
    }
    return "Unknown";
}

// After: Pattern Matching
public String describe(Object obj) {
    return switch (obj) {
        case String s -> "String: " + s.length();
        case Integer i -> "Integer: " + i;
        case null -> "Null";
        default -> "Unknown";
    };
}
```

## N+1 Query 해결

### Before: N+1 문제

```java
@Entity
public class Order {
    @OneToMany(mappedBy = "order")
    private List<OrderItem> items;  // Lazy Loading → N+1
}

// 사용 시 N+1 발생
List<Order> orders = orderRepository.findAll();
orders.forEach(o -> o.getItems().size());  // N번 추가 쿼리
```

### After: Fetch Join / EntityGraph

```java
// 방법 1: JPQL Fetch Join
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.status = :status")
List<Order> findByStatusWithItems(@Param("status") OrderStatus status);

// 방법 2: EntityGraph
@EntityGraph(attributePaths = {"items", "customer"})
List<Order> findByStatus(OrderStatus status);

// 방법 3: Batch Size (글로벌 설정)
// application.yml
spring:
  jpa:
    properties:
      hibernate:
        default_batch_fetch_size: 100
```

## Constructor Injection 리팩토링

### Before: Field Injection

```java
@Service
public class UserService {
    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private EmailService emailService;
}
```

### After: Constructor Injection with Lombok

```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;
}
```

## Checklist

### Virtual Threads
- [ ] `spring.threads.virtual.enabled=true` 설정
- [ ] synchronized → ReentrantLock 교체
- [ ] ThreadLocal 사용 검토 (Scoped Values)
- [ ] Connection Pool 크기 조정 (Virtual Thread는 많은 동시 연결 가능)

### Modern Java
- [ ] DTO → Record 변환 검토
- [ ] instanceof → Pattern Matching
- [ ] Optional 적극 활용
- [ ] var 적절히 사용

### Performance
- [ ] N+1 쿼리 제거
- [ ] 불필요한 Eager Loading 제거
- [ ] 적절한 인덱스 추가
- [ ] 캐시 적용 검토

## Usage

```
/java refactor --virtual-threads    # Virtual Threads 마이그레이션
/java refactor --modern             # Modern Java 패턴 적용
/java refactor --n-plus-one         # N+1 쿼리 해결
/java refactor --di                 # Constructor Injection 변환
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| Virtual Thread 성능 저하 | synchronized Pinning | `-Djdk.tracePinnedThreads=short`로 확인 |
| Record JSON 직렬화 실패 | Jackson 버전 | Jackson 2.12+ 사용 |
| EntityGraph 무시됨 | JPQL 우선 | @Query와 함께 사용 시 FETCH JOIN 직접 작성 |
| @RequiredArgsConstructor 미동작 | Lombok 설정 | annotationProcessor 의존성 확인 |

## References

- [Virtual Threads Migration](https://www.baeldung.com/spring-6-virtual-threads)
- [Record Patterns](https://openjdk.org/jeps/440)
- [N+1 Query Solutions](https://www.baeldung.com/hibernate-common-performance-problems)
