# Test Code Generator

지정된 클래스/메서드에 대한 테스트 코드를 자동 생성합니다.

## Instructions

1. 대상 클래스/파일을 분석합니다.
2. 클래스 타입(Controller, Service, Repository)을 식별합니다.
3. 각 public 메서드에 대해 테스트 케이스를 생성합니다.
4. Given-When-Then 패턴으로 테스트를 작성합니다.

## Test Templates

### Controller Test (@WebMvcTest)
```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    void should_returnUser_when_validIdProvided() throws Exception {
        // Given
        Long userId = 1L;
        UserResponse response = new UserResponse(userId, "test");
        when(userService.findById(userId)).thenReturn(response);

        // When & Then
        mockMvc.perform(get("/api/users/{id}", userId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(userId))
            .andExpect(jsonPath("$.name").value("test"));
    }
}
```

### Service Test (Unit)
```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserServiceImpl userService;

    @Test
    void should_returnUser_when_userExists() {
        // Given
        Long userId = 1L;
        User user = new User(userId, "test");
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));

        // When
        UserResponse result = userService.findById(userId);

        // Then
        assertThat(result.getId()).isEqualTo(userId);
        verify(userRepository).findById(userId);
    }

    @Test
    void should_throwException_when_userNotFound() {
        // Given
        Long userId = 1L;
        when(userRepository.findById(userId)).thenReturn(Optional.empty());

        // When & Then
        assertThrows(UserNotFoundException.class, () -> userService.findById(userId));
    }
}
```

### Repository Test (@DataJpaTest)
```java
@DataJpaTest
class UserRepositoryTest {

    @Autowired
    private UserRepository userRepository;

    @Test
    void should_findUser_when_emailExists() {
        // Given
        User user = new User("test@example.com", "test");
        userRepository.save(user);

        // When
        Optional<User> result = userRepository.findByEmail("test@example.com");

        // Then
        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("test");
    }
}
```

## Test Cases to Generate

각 메서드에 대해 다음 케이스 고려:
- Happy path (정상 케이스)
- Edge cases (경계값)
- Error cases (예외 상황)
- Null/empty input handling

## Output

생성된 테스트 파일을 `src/test/java/` 하위 적절한 위치에 작성합니다.

## Usage

```
/test-gen UserService           # 특정 클래스 테스트 생성
/test-gen src/main/java/...     # 파일 경로로 지정
/test-gen                       # 변경된 파일들의 테스트 생성
```
