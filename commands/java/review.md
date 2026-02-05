# Java/Spring Code Review

변경된 Java/Spring 코드를 리뷰합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Git diff 또는 특정 파일 |
| Output | 이슈 목록 (파일:라인, 심각도, 제안) |
| Required Tools | git, java, gradle/maven |
| Verification | 모든 Critical/High 이슈 해결 |

## Checklist

### Code Style
- [ ] Google Java Style 또는 프로젝트 컨벤션 준수
- [ ] import 순서 (java.*, javax.*, org.*, com.*, 프로젝트)
- [ ] Lombok 적절히 사용 (@Data 남용 지양)

### Spring Best Practices
- [ ] Constructor Injection 사용 (Field Injection 지양)
- [ ] Controller는 라우팅만, Service에 비즈니스 로직
- [ ] @Transactional 적절한 범위 (읽기 전용 readOnly=true)
- [ ] ResponseEntity 일관된 응답 형식

### Virtual Threads (Java 21+)
- [ ] I/O-bound 작업에 Virtual Threads 적용 검토
- [ ] synchronized 블록 대신 ReentrantLock 사용
- [ ] ThreadLocal 사용 시 ScopedValue 검토
- [ ] Pinning 이슈 확인 (native 메서드, synchronized)

### Error Handling
- [ ] 커스텀 예외 적절히 정의
- [ ] @ExceptionHandler/@ControllerAdvice 사용
- [ ] 예외 메시지에 민감 정보 노출 없음
- [ ] 적절한 HTTP 상태 코드 반환

### Testing
- [ ] 단위 테스트: @ExtendWith(MockitoExtension.class)
- [ ] 통합 테스트: @SpringBootTest + Testcontainers
- [ ] 테스트 커버리지 80% 이상
- [ ] 테스트 격리 (상태 공유 없음)

### Security
- [ ] SQL Injection 방지 (JPA parameterized query)
- [ ] @Valid/@Validated 입력 검증
- [ ] 민감 정보 하드코딩 없음
- [ ] 인증/인가 적절히 적용

### Performance
- [ ] N+1 쿼리 문제 없음 (fetch join, @EntityGraph)
- [ ] 불필요한 eager loading 없음
- [ ] 적절한 캐싱 적용 (@Cacheable)
- [ ] Connection Pool 크기 적정 (Virtual Threads 시 주의)

## Output Format

```
[Critical] UserService.java:42 - Field Injection 사용
  현재: @Autowired private UserRepository userRepository;
  수정: private final UserRepository userRepository;
        public UserService(UserRepository userRepository) { ... }

[Warning] OrderController.java:58 - N+1 쿼리 가능성
  현재: orders.stream().map(o -> o.getItems()).collect(...)
  수정: @EntityGraph(attributePaths = "items") 사용하거나 fetch join

[Info] PaymentService.java:23 - Virtual Threads 적용 검토
  현재: @Async("taskExecutor") 사용
  수정: spring.threads.virtual.enabled=true 설정 후 기본 @Async 사용
```

## Usage

```
/java review                  # 현재 변경사항 리뷰
/java review src/main/java/   # 특정 디렉토리 리뷰
/java review --staged         # staged 변경만 리뷰
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| Virtual Threads 적용 후 성능 저하 | synchronized로 인한 Pinning | ReentrantLock으로 교체, `-Djdk.tracePinnedThreads=short` |
| Connection Pool 고갈 | Virtual Threads + 작은 Pool | HikariCP max 크기 증가, semaphore로 제한 |
| 테스트 느림 | @SpringBootTest 남용 | 단위 테스트는 MockitoExtension 사용 |
| @Transactional 미동작 | self-invocation | 별도 서비스로 분리 또는 TransactionTemplate |
| N+1 감지 어려움 | 쿼리 로깅 미설정 | `spring.jpa.show-sql=true`, p6spy 사용 |

## Best Practices

1. `git diff` 또는 `git diff --cached`로 변경 사항 확인
2. 심각도별로 이슈 분류하여 리포트
3. Virtual Threads 관련 이슈 우선 확인 (Java 21+)

## References

- [Spring Boot Virtual Threads](https://www.baeldung.com/spring-6-virtual-threads)
- [Constructor Injection Best Practices](https://docs.spring.io/spring-framework/reference/core/beans/dependencies/factory-collaborators.html)
