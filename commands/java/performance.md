# Java/Spring Performance Optimization

Java/Spring 애플리케이션 성능을 최적화합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 성능 이슈 또는 최적화 대상 |
| Output | 최적화 방안 및 적용 코드 |
| Required Tools | java, gradle/maven, jfr, async-profiler |
| Verification | 벤치마크 개선 확인 |

## Performance Decision Tree

```
성능 최적화 영역:
├─ 시작 시간 (Startup Time)
│   ├─ GraalVM Native Image → 초단위 시작
│   ├─ Spring AOT → 빌드 타임 최적화
│   └─ CDS (Class Data Sharing) → JVM 시작 가속
├─ 처리량 (Throughput)
│   ├─ Virtual Threads → I/O-bound 작업
│   ├─ WebFlux → CPU-bound + 고동시성
│   └─ Connection Pool 튜닝 → DB 병목
├─ 메모리 (Memory)
│   ├─ GC 튜닝 → G1GC / ZGC
│   ├─ Heap 분석 → 메모리 누수 탐지
│   └─ Off-heap → 대용량 캐시
└─ 응답 시간 (Latency)
    ├─ 쿼리 최적화 → N+1, 인덱스
    ├─ 캐싱 → Redis, Caffeine
    └─ 비동기 처리 → @Async, CompletableFuture
```

## Startup Time Optimization

### GraalVM Native Image

```groovy
// build.gradle
plugins {
    id 'org.graalvm.buildtools.native' version '0.10.1'
}

graalvmNative {
    binaries {
        main {
            imageName = 'my-app'
            buildArgs.add('--enable-preview')
            buildArgs.add('-O3')  // 최적화 레벨
        }
    }
}
```

```bash
# 빌드 및 실행
./gradlew nativeCompile
./build/native/nativeCompile/my-app

# 시작 시간: JVM ~3초 → Native ~0.1초
```

### Spring AOT (Ahead-of-Time)

```groovy
// build.gradle
plugins {
    id 'org.springframework.boot' version '3.3.0'
}

springBoot {
    buildInfo()
}

// AOT 처리 활성화 (Native 빌드 시 자동)
```

### CDS (Class Data Sharing)

```yaml
# application.yml (Spring Boot 3.3+)
spring:
  cds:
    enabled: true
```

```bash
# 수동 CDS 설정
# 1. 클래스 리스트 생성
java -XX:DumpLoadedClassList=classes.lst -jar app.jar --exit

# 2. 공유 아카이브 생성
java -Xshare:dump -XX:SharedClassListFile=classes.lst \
     -XX:SharedArchiveFile=app.jsa -jar app.jar

# 3. 공유 아카이브로 실행
java -Xshare:on -XX:SharedArchiveFile=app.jsa -jar app.jar
```

## Virtual Threads for High Throughput

### 설정

```yaml
# application.yml
spring:
  threads:
    virtual:
      enabled: true

# Tomcat도 Virtual Thread 사용
server:
  tomcat:
    threads:
      max: 200  # Virtual Thread 시 큰 의미 없음
```

### Connection Pool 조정

```yaml
# HikariCP with Virtual Threads
spring:
  datasource:
    hikari:
      maximum-pool-size: 50  # Virtual Thread는 더 많은 연결 필요할 수 있음
      minimum-idle: 10
      connection-timeout: 30000

# 또는 Semaphore로 동시 DB 연결 제한
```

```java
@Service
public class DatabaseService {
    private final Semaphore dbSemaphore = new Semaphore(50);

    public Result query(String sql) {
        dbSemaphore.acquire();
        try {
            return jdbcTemplate.query(sql, ...);
        } finally {
            dbSemaphore.release();
        }
    }
}
```

## GC Tuning

### G1GC (기본, 균형잡힌 성능)

```bash
java -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     -XX:G1HeapRegionSize=16m \
     -Xmx4g -Xms4g \
     -jar app.jar
```

### ZGC (초저지연, Java 21+)

```bash
java -XX:+UseZGC \
     -XX:+ZGenerational \  # Java 21+ Generational ZGC
     -Xmx8g -Xms8g \
     -jar app.jar

# ZGC 특징: 1ms 미만 GC pause, 대용량 힙 지원
```

## Caching Strategies

### Caffeine (로컬 캐시)

```java
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CacheManager cacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager();
        manager.setCaffeine(Caffeine.newBuilder()
            .maximumSize(10_000)
            .expireAfterWrite(Duration.ofMinutes(10))
            .recordStats());
        return manager;
    }
}

@Service
public class ProductService {

    @Cacheable(value = "products", key = "#id")
    public Product findById(Long id) {
        return productRepository.findById(id).orElseThrow();
    }

    @CacheEvict(value = "products", key = "#product.id")
    public Product update(Product product) {
        return productRepository.save(product);
    }
}
```

### Redis (분산 캐시)

```yaml
spring:
  data:
    redis:
      host: localhost
      port: 6379
  cache:
    type: redis
    redis:
      time-to-live: 600000  # 10분
```

## Query Optimization

### 쿼리 분석

```yaml
# application.yml
spring:
  jpa:
    show-sql: true
    properties:
      hibernate:
        format_sql: true
        generate_statistics: true

logging:
  level:
    org.hibernate.stat: DEBUG
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql: TRACE
```

### 인덱스 최적화

```java
@Entity
@Table(indexes = {
    @Index(name = "idx_user_email", columnList = "email"),
    @Index(name = "idx_order_user_status", columnList = "user_id, status")
})
public class Order {
    // ...
}
```

## Profiling Tools

### JDK Flight Recorder (JFR)

```bash
# 프로파일링 시작
java -XX:+FlightRecorder \
     -XX:StartFlightRecording=duration=60s,filename=recording.jfr \
     -jar app.jar

# 또는 런타임에 시작
jcmd <pid> JFR.start duration=60s filename=recording.jfr

# JDK Mission Control로 분석
jmc recording.jfr
```

### Async Profiler

```bash
# CPU 프로파일링
./profiler.sh -d 30 -f cpu.html <pid>

# 메모리 할당 프로파일링
./profiler.sh -d 30 -e alloc -f alloc.html <pid>

# Wall-clock 프로파일링 (I/O 대기 포함)
./profiler.sh -d 30 -e wall -f wall.html <pid>
```

## Checklist

### Startup
- [ ] GraalVM Native 또는 CDS 적용
- [ ] 불필요한 auto-configuration 제외
- [ ] Lazy initialization 검토

### Throughput
- [ ] Virtual Threads 적용 (I/O-bound)
- [ ] Connection Pool 최적화
- [ ] 비동기 처리 적용

### Memory
- [ ] GC 알고리즘 선택 (G1GC/ZGC)
- [ ] 힙 크기 적절히 설정
- [ ] 메모리 누수 확인

### Latency
- [ ] N+1 쿼리 제거
- [ ] 적절한 캐싱 적용
- [ ] 인덱스 최적화

## Output Format

```
⚡ Performance Analysis: OrderService
   - Bottleneck: N+1 Query (findAllOrders)
   - Impact: 150ms → 12ms (92% improvement)
   - Applied: EntityGraph + Batch Fetch Size
```

## Usage

```
/java performance --startup      # 시작 시간 최적화
/java performance --throughput   # 처리량 최적화
/java performance --memory       # 메모리 최적화
/java performance --profile      # 프로파일링 가이드
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| Native Image 빌드 실패 | Reflection 사용 | reflect-config.json 추가 |
| ZGC OOM | 힙 크기 부족 | -Xmx 증가, 메모리 누수 확인 |
| 캐시 미스 많음 | TTL 너무 짧음 | 적절한 만료 시간 설정 |
| Virtual Thread 느림 | synchronized Pinning | ReentrantLock 사용 |
| Connection Pool 고갈 | 연결 미반환 | try-with-resources 확인 |

## Benchmarks Reference

| 최적화 | Before | After | 개선 |
|--------|--------|-------|------|
| CDS 적용 | 3.2s | 2.1s | 34% |
| Native Image | 3.2s | 0.08s | 97% |
| Virtual Threads | 500 RPS | 2000 RPS | 4x |
| N+1 해결 | 150ms | 12ms | 92% |
| Redis 캐시 | 50ms | 2ms | 96% |

## References

- [GraalVM Native Image](https://www.graalvm.org/latest/reference-manual/native-image/)
- [Spring Boot CDS](https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html#deployment.efficient)
- [Virtual Threads Performance](https://www.javacodegeeks.com/2025/04/spring-boot-performance-with-java-virtual-threads.html)
