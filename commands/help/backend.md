# Backend Commands

Java/Kotlin 백엔드 개발을 위한 명령어입니다.

## 명령어

### `/backend review`
코드 리뷰를 수행합니다.

```
/backend review                    # 변경된 파일
/backend review UserController     # 특정 클래스
/backend review src/main/java/...  # 경로
```

**검사 항목:**
- 레이어 분리 (Controller/Service/Repository)
- 예외 처리
- 트랜잭션 관리
- 보안 취약점

---

### `/backend test-gen`
테스트 코드를 생성합니다.

```
/backend test-gen UserService    # 특정 클래스
/backend test-gen                # 변경된 파일
```

**생성 패턴:**
- `@WebMvcTest` (Controller)
- `@ExtendWith(MockitoExtension.class)` (Service)
- `@DataJpaTest` (Repository)

---

### `/backend api-doc`
OpenAPI/Swagger 문서를 생성합니다.

```
/backend api-doc                 # 모든 Controller
/backend api-doc UserController  # 특정 Controller
/backend api-doc --fix           # 어노테이션 자동 추가
```

**추가 어노테이션:**
- `@Tag` (Controller)
- `@Operation` (Method)
- `@Schema` (DTO)

---

### `/backend refactor`
리팩토링을 제안합니다.

```
/backend refactor UserService    # 클래스 분석
/backend refactor --apply        # 리팩토링 적용
```

**검사 항목:**
- Long Method (30줄 초과)
- Long Parameter List (4개 초과)
- Large Class
- Feature Envy

---

## Skills (상세 패턴)

기술별 상세 패턴이 필요할 때 사용:

| 명령어 | 내용 |
|--------|------|
| `/spring-data` | JPA, QueryDSL 패턴 및 조합 |
| `/spring-cache` | Redis 캐싱 전략 |
| `/spring-security` | Security, OAuth2, JWT 인증 |
| `/spring-testing` | JUnit, Mockito, Testcontainers |
| `/concurrency-spring` | 동시성 문제 해결 (락킹, 데드락 방지) |
| `/distributed-lock` | MSA 분산 락 (Redis, Redisson) |
| `/observability` | 로깅 + OpenTelemetry + 메트릭 |
| `/api-design` | REST API 설계, 에러 처리 (RFC 9457) |
| `/docker` | Dockerfile 최적화, 멀티스테이지 빌드 |
| `/database` | 인덱스, 쿼리 최적화, 마이그레이션 |

### 기술 선택 가이드

```
CRUD 위주? ──────────────> Spring Data JPA
     │
     ├─ 동적 쿼리? ──────> + QueryDSL (/spring-data)
     │
     ├─ 읽기 성능? ───────> + Redis (/spring-cache)
     │
     ├─ 인증 필요? ───────> + JWT (/spring-security)
     │
     └─ 동시 수정? ───────> + @Version (/concurrency-spring)
           │
           └─ MSA? ──────> + 분산 락 (/distributed-lock)
```

---

## Quick Reference

```bash
# Gradle
./gradlew test
./gradlew build

# Maven
mvn test
mvn package
```
