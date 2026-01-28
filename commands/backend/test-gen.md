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
