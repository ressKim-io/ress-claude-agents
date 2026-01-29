# Test Code Generator

지정된 클래스/메서드에 대한 테스트 코드를 자동 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 클래스 또는 파일 경로 |
| Output | `*Test.java` 테스트 파일 |
| Required Tools | - |
| Verification | `./gradlew test` 또는 `mvn test` 통과 |

## Checklist

### Test Cases
- [ ] Happy path (정상)
- [ ] Edge cases (경계값)
- [ ] Error cases (예외)
- [ ] Null/empty handling

### Test Templates

#### Controller (@WebMvcTest)
```java
@WebMvcTest(UserController.class)
class UserControllerTest {
    @Autowired MockMvc mockMvc;
    @MockBean UserService userService;

    @Test
    void should_returnUser_when_validId() { }
}
```

#### Service (Unit)
```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    @Mock UserRepository userRepository;
    @InjectMocks UserServiceImpl userService;

    @Test
    void should_returnUser_when_exists() { }
}
```

#### Repository (@DataJpaTest)
```java
@DataJpaTest
class UserRepositoryTest {
    @Autowired UserRepository userRepository;

    @Test
    void should_findUser_when_emailExists() { }
}
```

## Output Format

생성된 테스트 파일 `*Test.java`

## Usage

```
/test-gen UserService       # 특정 클래스
/test-gen src/main/java/... # 파일 경로
/test-gen                   # 변경된 파일
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `@WebMvcTest` 빈 주입 실패 | 필요한 Bean 미등록 | `@MockBean`으로 의존성 모킹 추가 |
| `@DataJpaTest` 트랜잭션 롤백 안됨 | 테스트 설정 문제 | `@Transactional` 명시 또는 `@Rollback(true)` 추가 |
| MockMvc 응답 인코딩 깨짐 | charset 설정 누락 | `MockMvc` 생성 시 `characterEncoding("UTF-8")` 설정 |
| `@InjectMocks` null 반환 | `@ExtendWith(MockitoExtension.class)` 누락 | 클래스에 어노테이션 추가 |
| H2 DB 호환성 에러 | 프로덕션 DB와 문법 차이 | TestContainers 사용 또는 H2 Mode 설정 |
| 비동기 테스트 불안정 | 타이밍 이슈 | `Awaitility` 라이브러리 사용 또는 `CompletableFuture.get()` |
