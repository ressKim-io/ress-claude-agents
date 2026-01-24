# Spring Cache Patterns

Redis를 활용한 Spring Boot 캐싱 전략

## 설정

### 의존성
```groovy
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-data-redis'
    implementation 'org.springframework.boot:spring-boot-starter-cache'
}
```

### application.yml
```yaml
spring:
  cache:
    type: redis
  data:
    redis:
      host: localhost
      port: 6379
      password: ${REDIS_PASSWORD:}
      timeout: 2000ms
      lettuce:
        pool:
          max-active: 8
          max-idle: 8
          min-idle: 2

  # 캐시별 TTL 설정
  cache:
    redis:
      time-to-live: 600000  # 10분 (기본값)
      cache-null-values: false
```

### Redis 설정 클래스
```java
@Configuration
@EnableCaching
public class RedisConfig {

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory factory) {
        RedisCacheConfiguration defaultConfig = RedisCacheConfiguration
            .defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10))
            .serializeKeysWith(SerializationPair.fromSerializer(new StringRedisSerializer()))
            .serializeValuesWith(SerializationPair.fromSerializer(new GenericJackson2JsonRedisSerializer()));

        // 캐시별 개별 설정
        Map<String, RedisCacheConfiguration> cacheConfigs = Map.of(
            "users", defaultConfig.entryTtl(Duration.ofHours(1)),
            "products", defaultConfig.entryTtl(Duration.ofMinutes(30)),
            "sessions", defaultConfig.entryTtl(Duration.ofHours(24))
        );

        return RedisCacheManager.builder(factory)
            .cacheDefaults(defaultConfig)
            .withInitialCacheConfigurations(cacheConfigs)
            .build();
    }
}
```

---

## 캐시 어노테이션

### @Cacheable - 조회 캐싱
```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;

    // 기본 사용법
    @Cacheable(value = "users", key = "#id")
    public User getUser(Long id) {
        return userRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("User not found"));
    }

    // 조건부 캐싱
    @Cacheable(value = "users", key = "#id", condition = "#id > 0")
    public User getUserConditional(Long id) {
        return userRepository.findById(id).orElse(null);
    }

    // null 결과 캐싱 방지
    @Cacheable(value = "users", key = "#email", unless = "#result == null")
    public User getUserByEmail(String email) {
        return userRepository.findByEmail(email).orElse(null);
    }

    // 복합 키
    @Cacheable(value = "userSearch", key = "#condition.hashCode()")
    public List<User> searchUsers(UserSearchCondition condition) {
        return userRepository.search(condition);
    }
}
```

### @CachePut - 캐시 업데이트
```java
// 저장/수정 시 캐시도 업데이트
@CachePut(value = "users", key = "#result.id")
@Transactional
public User updateUser(Long id, UpdateUserRequest request) {
    User user = userRepository.findById(id)
        .orElseThrow(() -> new NotFoundException("User not found"));
    user.update(request);
    return userRepository.save(user);
}
```

### @CacheEvict - 캐시 삭제
```java
// 단일 항목 삭제
@CacheEvict(value = "users", key = "#id")
@Transactional
public void deleteUser(Long id) {
    userRepository.deleteById(id);
}

// 전체 캐시 삭제
@CacheEvict(value = "users", allEntries = true)
@Transactional
public void deleteAllUsers() {
    userRepository.deleteAll();
}

// 여러 캐시 삭제
@Caching(evict = {
    @CacheEvict(value = "users", key = "#id"),
    @CacheEvict(value = "userSearch", allEntries = true)
})
@Transactional
public void deleteUserWithRelated(Long id) {
    userRepository.deleteById(id);
}
```

---

## 캐싱 전략

### Cache-Aside (Lazy Loading)
```java
// 가장 일반적인 패턴 - @Cacheable이 이 패턴
@Cacheable(value = "products", key = "#id")
public Product getProduct(Long id) {
    // 캐시 미스 시에만 DB 조회
    return productRepository.findById(id).orElseThrow();
}
```

### Write-Through
```java
// 쓰기 시 캐시도 함께 업데이트
@CachePut(value = "products", key = "#result.id")
@Transactional
public Product saveProduct(Product product) {
    return productRepository.save(product);
}
```

### Write-Behind (Async)
```java
// 비동기로 캐시 먼저, DB는 나중에
@Service
@RequiredArgsConstructor
public class AsyncCacheService {
    private final RedisTemplate<String, Object> redisTemplate;
    private final ProductRepository productRepository;

    public void saveProductAsync(Product product) {
        // 1. 캐시에 즉시 저장
        redisTemplate.opsForValue().set("product:" + product.getId(), product);

        // 2. DB는 비동기로 저장
        CompletableFuture.runAsync(() -> productRepository.save(product));
    }
}
```

---

## Redis 직접 사용

### RedisTemplate
```java
@Service
@RequiredArgsConstructor
public class RedisService {
    private final RedisTemplate<String, Object> redisTemplate;

    // String 타입
    public void setValue(String key, Object value, Duration ttl) {
        redisTemplate.opsForValue().set(key, value, ttl);
    }

    public Object getValue(String key) {
        return redisTemplate.opsForValue().get(key);
    }

    // Hash 타입 (객체 필드별 저장)
    public void setHash(String key, String field, Object value) {
        redisTemplate.opsForHash().put(key, field, value);
    }

    public Map<Object, Object> getHash(String key) {
        return redisTemplate.opsForHash().entries(key);
    }

    // List 타입 (최근 조회 기록 등)
    public void addToList(String key, Object value) {
        redisTemplate.opsForList().rightPush(key, value);
        redisTemplate.opsForList().trim(key, -100, -1);  // 최근 100개만 유지
    }

    // Set 타입 (좋아요 목록 등)
    public void addToSet(String key, Object value) {
        redisTemplate.opsForSet().add(key, value);
    }

    public boolean isMember(String key, Object value) {
        return Boolean.TRUE.equals(redisTemplate.opsForSet().isMember(key, value));
    }

    // Sorted Set (랭킹)
    public void addToRanking(String key, Object value, double score) {
        redisTemplate.opsForZSet().add(key, value, score);
    }

    public Set<Object> getTopRanking(String key, int count) {
        return redisTemplate.opsForZSet().reverseRange(key, 0, count - 1);
    }
}
```

---

## 분산 락

```java
@Service
@RequiredArgsConstructor
public class DistributedLockService {
    private final RedisTemplate<String, String> redisTemplate;

    public boolean acquireLock(String lockKey, String value, Duration timeout) {
        return Boolean.TRUE.equals(
            redisTemplate.opsForValue()
                .setIfAbsent(lockKey, value, timeout)
        );
    }

    public void releaseLock(String lockKey, String value) {
        String script = """
            if redis.call('get', KEYS[1]) == ARGV[1] then
                return redis.call('del', KEYS[1])
            else
                return 0
            end
            """;
        redisTemplate.execute(
            new DefaultRedisScript<>(script, Long.class),
            List.of(lockKey),
            value
        );
    }
}

// 사용 예시
@Transactional
public void processOrderWithLock(Long orderId) {
    String lockKey = "order:lock:" + orderId;
    String lockValue = UUID.randomUUID().toString();

    if (!lockService.acquireLock(lockKey, lockValue, Duration.ofSeconds(30))) {
        throw new ConflictException("Order is being processed");
    }

    try {
        // 비즈니스 로직
        processOrder(orderId);
    } finally {
        lockService.releaseLock(lockKey, lockValue);
    }
}
```

---

## MongoDB + Redis 조합

```java
@Service
@RequiredArgsConstructor
public class ProductService {
    private final ProductMongoRepository productRepository;  // MongoDB

    @Cacheable(value = "products", key = "#id")
    public Product getProduct(String id) {
        return productRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("Product not found"));
    }

    @CachePut(value = "products", key = "#result.id")
    public Product saveProduct(Product product) {
        return productRepository.save(product);
    }

    @CacheEvict(value = "products", key = "#id")
    public void deleteProduct(String id) {
        productRepository.deleteById(id);
    }
}
```

---

## Common Mistakes

| 실수 | 올바른 방법 |
|------|------------|
| TTL 없이 캐싱 | 항상 적절한 TTL 설정 |
| 대용량 객체 캐싱 | 필요한 필드만 DTO로 캐싱 |
| Serializable 누락 | Entity에 Serializable 구현 |
| 캐시 키 충돌 | 명확한 네이밍 규칙 (prefix:entity:id) |
| 캐시-DB 불일치 | @CachePut/@CacheEvict로 동기화 |

---

## 캐싱 대상 선정

```
자주 조회? ─────────────────────> 캐싱 후보
     │
     ├─ 자주 변경? ──────────────> 짧은 TTL 또는 캐싱 제외
     │
     ├─ 데이터 크기? ─────────────> 작으면 캐싱, 크면 분할
     │
     └─ 일관성 중요? ─────────────> Write-Through 패턴
```
