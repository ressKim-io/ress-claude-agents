# Backend Java/Kotlin Project - Claude Settings

Spring Boot 기반 백엔드 프로젝트를 위한 Claude Code 설정입니다.

## Project Structure

Layered Architecture 기반:
```
src/main/java/com/example/
├── controller/          # REST API 엔드포인트
├── service/             # 비즈니스 로직
├── repository/          # 데이터 접근 계층
├── domain/              # 엔티티, VO, DTO
├── config/              # 설정 클래스
└── exception/           # 예외 처리
```

## Code Style

### Naming
- 클래스: PascalCase (UserService, OrderController)
- 메서드/변수: camelCase (findById, userName)
- 상수: UPPER_SNAKE_CASE (MAX_RETRY_COUNT)
- 패키지: lowercase (com.example.user)

### Spring Conventions
- Controller: `@RestController` + `@RequestMapping`
- Service: `@Service` + 인터페이스 분리 권장
- Repository: Spring Data JPA 사용 시 `JpaRepository` 상속
- DTO 변환은 Service 계층에서 처리

### Kotlin Specific
- data class 활용 (DTO, VO)
- null safety 적극 활용 (`?`, `!!` 최소화)
- extension function 적절히 사용

## Git Workflow

### Commit Convention
```
<type>(<scope>): <subject>

<body>
```

**Types:**
- feat: 새 기능
- fix: 버그 수정
- refactor: 리팩토링
- test: 테스트 추가/수정
- docs: 문서
- chore: 빌드, 설정 변경

**커밋 단위:** 하나의 논리적 변경 = 하나의 커밋
- 기능 추가 시: Controller + Service + Repository + Test 를 하나의 커밋으로
- 버그 수정 시: 수정 코드 + 관련 테스트를 하나의 커밋으로

### Pull Request
- **IMPORTANT:** PR 크기는 400줄 이하 유지
- 큰 기능은 여러 PR로 분리
- PR 제목: `[타입] 간단한 설명`
- PR 본문: 변경 사항, 테스트 방법, 스크린샷(UI 변경 시)

## Testing

### Coverage
- **IMPORTANT:** 테스트 커버리지 80% 이상 유지
- 새 기능 추가 시 반드시 테스트 코드 포함

### Test Types
```
src/test/java/
├── unit/                # 단위 테스트 (@WebMvcTest, @DataJpaTest)
├── integration/         # 통합 테스트 (@SpringBootTest)
└── e2e/                 # E2E 테스트 (필요시)
```

### Naming Convention
- 테스트 클래스: `{ClassName}Test`
- 테스트 메서드: `should_{expectedBehavior}_when_{condition}`
  - 예: `should_returnUser_when_validIdProvided`

### Test Structure (Given-When-Then)
```java
@Test
void should_returnUser_when_validIdProvided() {
    // Given
    Long userId = 1L;
    User expected = new User(userId, "test");
    when(userRepository.findById(userId)).thenReturn(Optional.of(expected));

    // When
    User result = userService.findById(userId);

    // Then
    assertThat(result).isEqualTo(expected);
}
```

## API Documentation

### OpenAPI/Swagger
- springdoc-openapi 사용
- 모든 API 엔드포인트에 `@Operation` 어노테이션 필수
- Request/Response DTO에 `@Schema` 설명 추가

```java
@Operation(summary = "사용자 조회", description = "ID로 사용자 정보를 조회합니다")
@ApiResponses({
    @ApiResponse(responseCode = "200", description = "성공"),
    @ApiResponse(responseCode = "404", description = "사용자 없음")
})
@GetMapping("/{id}")
public UserResponse getUser(@PathVariable Long id) { ... }
```

## Code Review Focus

코드 리뷰 시 다음 항목을 중점 확인:

### Security (OWASP Top 10)
- SQL Injection: JPA 사용, native query 시 파라미터 바인딩 필수
- XSS: 입력값 검증, 출력 인코딩
- 인증/인가: Spring Security 적절한 설정
- 민감 정보: 하드코딩 금지, 환경변수 사용

### Performance
- N+1 문제: fetch join, @EntityGraph 활용
- 불필요한 쿼리: 필요한 필드만 조회 (Projection)
- 페이징: 대량 데이터 조회 시 페이징 필수
- 캐싱: 반복 조회 데이터는 캐싱 고려

### Error Handling
- 적절한 예외 클래스 사용 (커스텀 예외 정의)
- @ControllerAdvice로 전역 예외 처리
- 에러 응답 형식 통일
- 로깅: 에러 시 충분한 컨텍스트 로깅

## Commands

다음 명령어 사용 가능:
- `/review` - 변경된 코드 리뷰
- `/test-gen` - 테스트 코드 자동 생성
- `/api-doc` - API 문서 어노테이션 추가/검증
- `/refactor` - 코드 품질 개선 제안

---

*global CLAUDE.md 설정도 함께 적용됩니다*
