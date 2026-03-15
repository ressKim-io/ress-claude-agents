# Java/Spring Test Generation

Java/Spring 코드에 대한 테스트를 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 테스트할 클래스/메서드 |
| Output | JUnit 5 테스트 코드 |
| Required Tools | java, gradle/maven, testcontainers |
| Verification | 테스트 통과 및 커버리지 80%+ |

## Test Types Decision Tree

```
테스트 대상 선택:
├─ 순수 비즈니스 로직 (외부 의존성 없음)
│   └─ Unit Test (@ExtendWith(MockitoExtension.class))
├─ Spring 빈 간 상호작용
│   └─ Slice Test (@WebMvcTest, @DataJpaTest)
├─ 실제 DB/외부 서비스 필요
│   └─ Integration Test (@SpringBootTest + Testcontainers)
└─ E2E 시나리오
    └─ Full Test (@SpringBootTest(webEnvironment=RANDOM_PORT))
```

## Unit Test Template

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    @Test
    @DisplayName("사용자 생성 - 정상 케이스")
    void createUser_Success() {
        // given
        var request = new CreateUserRequest("john@example.com", "John");
        given(userRepository.existsByEmail(anyString())).willReturn(false);
        given(userRepository.save(any(User.class)))
            .willReturn(new User(1L, "john@example.com", "John"));

        // when
        var result = userService.createUser(request);

        // then
        assertThat(result.id()).isNotNull();
        assertThat(result.email()).isEqualTo("john@example.com");
        then(userRepository).should().save(any(User.class));
    }

    @Test
    @DisplayName("사용자 생성 - 이메일 중복 시 예외")
    void createUser_DuplicateEmail_ThrowsException() {
        // given
        var request = new CreateUserRequest("existing@example.com", "John");
        given(userRepository.existsByEmail("existing@example.com")).willReturn(true);

        // when & then
        assertThatThrownBy(() -> userService.createUser(request))
            .isInstanceOf(DuplicateEmailException.class)
            .hasMessageContaining("existing@example.com");
    }
}
```

## Integration Test with Testcontainers

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class UserIntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("사용자 생성 API - 정상 케이스")
    void createUser_API_Success() {
        // given
        var request = Map.of("email", "test@example.com", "name", "Test");

        // when
        var response = restTemplate.postForEntity("/api/users", request, UserResponse.class);

        // then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().email()).isEqualTo("test@example.com");

        // DB 확인
        assertThat(userRepository.findByEmail("test@example.com")).isPresent();
    }
}
```

## Slice Test Templates

### @WebMvcTest (Controller)

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @Test
    void getUser_Success() throws Exception {
        given(userService.findById(1L))
            .willReturn(new UserResponse(1L, "john@example.com", "John"));

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value("john@example.com"));
    }
}
```

### @DataJpaTest (Repository)

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class UserRepositoryTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private UserRepository userRepository;

    @Test
    void findByEmail_Exists_ReturnsUser() {
        // given
        userRepository.save(new User(null, "test@example.com", "Test"));

        // when
        var result = userRepository.findByEmail("test@example.com");

        // then
        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("Test");
    }
}
```

## Checklist

### Test Quality
- [ ] Given-When-Then 구조 준수
- [ ] 테스트당 하나의 검증 포인트
- [ ] @DisplayName으로 한글 설명
- [ ] 테스트 격리 (상태 공유 없음)

### Mocking
- [ ] @Mock vs @MockitoBean 적절히 선택
- [ ] BDDMockito (given/then) 사용
- [ ] 불필요한 stubbing 없음 (lenient 지양)

### Testcontainers
- [ ] static container로 재사용 (속도 개선)
- [ ] @ServiceConnection 사용 (Spring Boot 3.1+)
- [ ] 적절한 이미지 버전 지정

### Assertions
- [ ] AssertJ 사용 (가독성)
- [ ] 예외 테스트는 assertThatThrownBy 사용
- [ ] Collection 검증 시 contains/hasSize 활용

## Output Format

```
✅ Generated: UserServiceTest.java
   - Unit Tests: 5 (Given-When-Then)
   - Integration Tests: 2 (Testcontainers)
   - Coverage Target: 80%+

📁 Output Location:
   src/test/java/com/example/.../UserServiceTest.java
```

## Usage

```
/java test-gen UserService            # 클래스 전체 테스트 생성
/java test-gen UserService.createUser # 특정 메서드 테스트 생성
/java test-gen --type=integration     # 통합 테스트 생성
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| Testcontainers 시작 느림 | 매 테스트마다 컨테이너 생성 | static container + @BeforeAll |
| @MockitoBean NPE | Spring Context 미로드 | @ExtendWith(MockitoExtension.class) 확인 |
| @ServiceConnection 미동작 | Spring Boot 버전 | 3.1+ 필요, 이전 버전은 @DynamicPropertySource |
| 테스트 간 데이터 충돌 | 트랜잭션 미롤백 | @BeforeEach에서 deleteAll() 또는 @Transactional |
| MockMvc 한글 깨짐 | 인코딩 설정 누락 | `.characterEncoding("UTF-8")` 추가 |

## References

- [Testcontainers Spring Boot](https://testcontainers.com/guides/testing-spring-boot-rest-api-using-testcontainers/)
- [Spring Boot Testing Guide](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.testing)
