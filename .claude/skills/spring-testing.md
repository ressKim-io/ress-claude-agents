# Spring Testing Patterns

JUnit 5, Mockito, Testcontainers를 활용한 테스트 패턴

## 의존성

```groovy
dependencies {
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation 'org.testcontainers:junit-jupiter'
    testImplementation 'org.testcontainers:postgresql'
    testImplementation 'org.testcontainers:mongodb'
    testImplementation 'io.rest-assured:rest-assured'
}
```

---

## 테스트 피라미드

```
        /\
       /  \      E2E Tests (적게)
      /----\
     /      \    Integration Tests (적당히)
    /--------\
   /          \  Unit Tests (많이)
  --------------
```

---

## Unit Tests

### Service 테스트 (Mockito)
```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private UserServiceImpl userService;

    @Test
    @DisplayName("사용자 생성 성공")
    void createUser_Success() {
        // Given
        CreateUserRequest request = new CreateUserRequest("test@example.com", "password");
        User savedUser = User.builder()
            .id(1L)
            .email(request.getEmail())
            .password("encodedPassword")
            .build();

        when(userRepository.existsByEmail(request.getEmail())).thenReturn(false);
        when(passwordEncoder.encode(request.getPassword())).thenReturn("encodedPassword");
        when(userRepository.save(any(User.class))).thenReturn(savedUser);

        // When
        UserResponse response = userService.createUser(request);

        // Then
        assertThat(response.getId()).isEqualTo(1L);
        assertThat(response.getEmail()).isEqualTo("test@example.com");

        verify(userRepository).existsByEmail(request.getEmail());
        verify(userRepository).save(any(User.class));
    }

    @Test
    @DisplayName("중복 이메일로 사용자 생성 시 예외")
    void createUser_DuplicateEmail_ThrowsException() {
        // Given
        CreateUserRequest request = new CreateUserRequest("existing@example.com", "password");
        when(userRepository.existsByEmail(request.getEmail())).thenReturn(true);

        // When & Then
        assertThatThrownBy(() -> userService.createUser(request))
            .isInstanceOf(DuplicateException.class)
            .hasMessage("Email already exists");

        verify(userRepository, never()).save(any());
    }
}
```

### Parameterized Tests
```java
@ParameterizedTest
@CsvSource({
    "test@example.com, true",
    "invalid-email, false",
    "'', false",
    "test@, false"
})
@DisplayName("이메일 유효성 검증")
void validateEmail(String email, boolean expected) {
    assertThat(EmailValidator.isValid(email)).isEqualTo(expected);
}

@ParameterizedTest
@MethodSource("provideUserCreationData")
void createUser_MultipleScenarios(CreateUserRequest request, Class<? extends Exception> expectedException) {
    if (expectedException == null) {
        assertThatNoException().isThrownBy(() -> userService.createUser(request));
    } else {
        assertThatThrownBy(() -> userService.createUser(request))
            .isInstanceOf(expectedException);
    }
}

private static Stream<Arguments> provideUserCreationData() {
    return Stream.of(
        Arguments.of(new CreateUserRequest("valid@example.com", "password123"), null),
        Arguments.of(new CreateUserRequest("", "password123"), ValidationException.class),
        Arguments.of(new CreateUserRequest("valid@example.com", ""), ValidationException.class)
    );
}
```

---

## Integration Tests

### @WebMvcTest (Controller)
```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    @DisplayName("GET /api/users/{id} - 사용자 조회 성공")
    void getUser_Success() throws Exception {
        // Given
        UserResponse response = new UserResponse(1L, "test@example.com", "Test User");
        when(userService.getUser(1L)).thenReturn(response);

        // When & Then
        mockMvc.perform(get("/api/users/{id}", 1L)
                .contentType(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("test@example.com"));
    }

    @Test
    @DisplayName("POST /api/users - 사용자 생성 성공")
    void createUser_Success() throws Exception {
        // Given
        CreateUserRequest request = new CreateUserRequest("new@example.com", "password123");
        UserResponse response = new UserResponse(1L, "new@example.com", "New User");
        when(userService.createUser(any())).thenReturn(response);

        // When & Then
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1));
    }

    @Test
    @DisplayName("POST /api/users - 유효성 검증 실패")
    void createUser_ValidationFailed() throws Exception {
        // Given
        CreateUserRequest request = new CreateUserRequest("invalid-email", "");

        // When & Then
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors").isArray());
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
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    @DisplayName("이메일로 사용자 조회")
    void findByEmail_Success() {
        // Given
        User user = User.builder()
            .email("test@example.com")
            .password("password")
            .name("Test User")
            .build();
        entityManager.persistAndFlush(user);

        // When
        Optional<User> found = userRepository.findByEmail("test@example.com");

        // Then
        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Test User");
    }
}
```

---

## Testcontainers

### 공유 컨테이너 설정
```java
@SpringBootTest
@Testcontainers
public abstract class IntegrationTestBase {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
        .withDatabaseName("testdb")
        .withReuse(true);  // 컨테이너 재사용

    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7")
        .withExposedPorts(6379)
        .withReuse(true);

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", () -> redis.getMappedPort(6379));
    }
}

// 사용
class UserIntegrationTest extends IntegrationTestBase {
    @Test
    void integrationTest() {
        // 테스트 로직
    }
}
```

### MongoDB + Testcontainers
```java
@DataMongoTest
@Testcontainers
class ProductRepositoryTest {

    @Container
    static MongoDBContainer mongo = new MongoDBContainer("mongo:6");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.mongodb.uri", mongo::getReplicaSetUrl);
    }

    @Autowired
    private ProductRepository productRepository;

    @Test
    void findByCategory() {
        // Given
        Product product = new Product("Test Product", "Electronics", 100.0);
        productRepository.save(product);

        // When
        List<Product> found = productRepository.findByCategory("Electronics");

        // Then
        assertThat(found).hasSize(1);
    }
}
```

---

## REST Assured (API 테스트)

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class UserApiTest extends IntegrationTestBase {

    @LocalServerPort
    private int port;

    @BeforeEach
    void setup() {
        RestAssured.port = port;
        RestAssured.basePath = "/api";
    }

    @Test
    @DisplayName("사용자 생성 및 조회 통합 테스트")
    void createAndGetUser() {
        // Create
        CreateUserRequest createRequest = new CreateUserRequest("api@example.com", "password123");

        UserResponse created = given()
            .contentType(ContentType.JSON)
            .body(createRequest)
        .when()
            .post("/users")
        .then()
            .statusCode(201)
            .extract()
            .as(UserResponse.class);

        assertThat(created.getId()).isNotNull();

        // Get
        given()
        .when()
            .get("/users/{id}", created.getId())
        .then()
            .statusCode(200)
            .body("email", equalTo("api@example.com"));
    }

    @Test
    @DisplayName("인증이 필요한 API 테스트")
    void authenticatedEndpoint() {
        String token = obtainAccessToken("user@example.com", "password");

        given()
            .header("Authorization", "Bearer " + token)
        .when()
            .get("/users/me")
        .then()
            .statusCode(200)
            .body("email", equalTo("user@example.com"));
    }
}
```

---

## 테스트 유틸리티

### 테스트 픽스처
```java
public class UserFixture {

    public static User createUser() {
        return User.builder()
            .email("test@example.com")
            .password("password")
            .name("Test User")
            .status(UserStatus.ACTIVE)
            .build();
    }

    public static User createUser(String email) {
        return User.builder()
            .email(email)
            .password("password")
            .name("Test User")
            .status(UserStatus.ACTIVE)
            .build();
    }

    public static CreateUserRequest createRequest() {
        return new CreateUserRequest("new@example.com", "password123");
    }
}

// 사용
@Test
void test() {
    User user = UserFixture.createUser("custom@example.com");
}
```

### @Sql로 테스트 데이터
```java
@Test
@Sql("/sql/users.sql")
@Sql(value = "/sql/cleanup.sql", executionPhase = Sql.ExecutionPhase.AFTER_TEST_METHOD)
void testWithPreparedData() {
    // users.sql이 먼저 실행됨
    List<User> users = userRepository.findAll();
    assertThat(users).hasSize(5);
}
```

---

## Common Mistakes

| 실수 | 올바른 방법 |
|------|------------|
| @SpringBootTest 남용 | 필요한 슬라이스만 (@WebMvcTest, @DataJpaTest) |
| 테스트 간 상태 공유 | @BeforeEach로 초기화 |
| 실제 외부 서비스 호출 | Mock 또는 Testcontainers |
| 느린 테스트 | 유닛 테스트 비중 높이기 |
| 테스트 순서 의존 | 독립적인 테스트 작성 |

---

## 테스트 네이밍 규칙

```java
// Given-When-Then 또는 Should 패턴
@Test
void should_ReturnUser_When_ValidIdProvided() { }

@Test
void createUser_WithDuplicateEmail_ThrowsException() { }

// @DisplayName으로 한글 설명 추가
@Test
@DisplayName("유효한 ID로 사용자 조회 시 사용자 반환")
void getUser_ValidId_ReturnsUser() { }
```

---

## 테스트 체크리스트

- [ ] 유닛 테스트: 핵심 비즈니스 로직
- [ ] 통합 테스트: Repository, 외부 연동
- [ ] API 테스트: 주요 엔드포인트
- [ ] 경계값, 예외 케이스 포함
- [ ] 테스트 격리 (독립 실행 가능)
- [ ] CI에서 자동 실행
