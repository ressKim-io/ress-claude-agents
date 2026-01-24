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

## Quick Reference

```bash
# Gradle
./gradlew test
./gradlew build

# Maven
mvn test
mvn package
```
