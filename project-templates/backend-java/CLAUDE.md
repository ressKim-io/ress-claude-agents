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

## Commands
- `/review` - Code review
- `/test-gen` - Generate tests
- `/api-doc` - Add OpenAPI annotations
- `/refactor` - Code quality improvements

---
*Applies with global CLAUDE.md settings*
