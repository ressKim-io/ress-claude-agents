# Backend Java/Kotlin Project - Claude Settings

## Quick Reference
- Test: `./gradlew test` or `mvn test`
- Build: `./gradlew build` or `mvn package`
- Lint: `./gradlew checkstyleMain` or `mvn checkstyle:check`

## Project Structure
```
src/main/java/com/example/
├── controller/      # REST endpoints
├── service/         # Business logic
├── repository/      # Data access
├── domain/          # Entities, DTOs
└── config/          # Configuration
```

## CRITICAL Rules

1. **Test Coverage** - Verify: `./gradlew jacocoTestReport` (80%+)
   ```java
   @Test
   void should_returnUser_when_validIdProvided() {
       // Given-When-Then pattern
   }
   ```

2. **API Documentation** - Verify: Check Swagger UI
   ```java
   @Operation(summary = "Get user", description = "...")
   @GetMapping("/{id}")
   public UserResponse getUser(@PathVariable Long id) { }
   ```

3. **No N+1 Queries** - Verify: Enable SQL logging
   ```java
   @EntityGraph(attributePaths = {"orders"})
   Optional<User> findById(Long id);
   ```

## Common Mistakes

| Mistake | Correct | Verify |
|---------|---------|--------|
| N+1 queries | fetch join/@EntityGraph | SQL log |
| No validation | @Valid + DTO constraints | Controller tests |
| Hardcoded secrets | @Value + env vars | `grep "password"` |
| No transaction | @Transactional | Service layer |
| JWT secret hardcoded | Environment variable | `grep -r "secret"` |
| No cache for reads | @Cacheable on hot paths | Response time |
| 동시 수정 무시 | @Version + @Retryable | Lost Update 방지 |
| MSA에서 로컬 락 | 분산 락 (Redis) | Race condition |

## Technology Stack

| 분야 | 기본 | 고급 |
|------|------|------|
| Data Access | Spring Data JPA | + QueryDSL |
| Caching | Spring Cache | + Redis |
| Security | Spring Security | + OAuth2, JWT |
| Testing | JUnit, Mockito | + Testcontainers |

## Skills (상세 패턴)
- `/spring-data` - JPA, QueryDSL 패턴 및 조합
- `/spring-cache` - Redis 캐싱 전략
- `/spring-security` - Security, OAuth2, JWT 인증
- `/spring-testing` - JUnit, Mockito, Testcontainers
- `/concurrency-spring` - 동시성 문제 해결 (락킹, 데드락 방지)
- `/distributed-lock` - MSA 분산 락 (Redis, Redisson)
- `/observability` - 로깅 + OpenTelemetry + 메트릭

## Commands
- `/backend review` - Code review
- `/backend test-gen` - Generate tests
- `/backend api-doc` - Add OpenAPI annotations
- `/backend refactor` - Code quality improvements

---
*Applies with global CLAUDE.md settings*
