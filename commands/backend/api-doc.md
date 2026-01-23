# API Documentation Generator

OpenAPI/Swagger 어노테이션을 추가하거나 검증합니다.

## Instructions

1. Controller 클래스를 분석합니다.
2. 각 API 엔드포인트의 문서화 상태를 확인합니다.
3. 누락된 어노테이션을 추가합니다.
4. DTO 클래스에 @Schema 어노테이션을 추가합니다.

## Required Annotations

### Controller Level
```java
@Tag(name = "User", description = "사용자 관리 API")
@RestController
@RequestMapping("/api/users")
public class UserController { ... }
```

### Method Level
```java
@Operation(
    summary = "사용자 조회",
    description = "ID로 사용자 정보를 조회합니다"
)
@ApiResponses({
    @ApiResponse(
        responseCode = "200",
        description = "성공",
        content = @Content(schema = @Schema(implementation = UserResponse.class))
    ),
    @ApiResponse(
        responseCode = "404",
        description = "사용자를 찾을 수 없음",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    )
})
@GetMapping("/{id}")
public UserResponse getUser(
    @Parameter(description = "사용자 ID", required = true, example = "1")
    @PathVariable Long id
) { ... }
```

### DTO Level
```java
@Schema(description = "사용자 응답")
public class UserResponse {

    @Schema(description = "사용자 ID", example = "1")
    private Long id;

    @Schema(description = "사용자 이름", example = "홍길동")
    private String name;

    @Schema(description = "이메일", example = "user@example.com")
    private String email;
}
```

### Request Body
```java
@Schema(description = "사용자 생성 요청")
public class CreateUserRequest {

    @Schema(description = "사용자 이름", required = true, example = "홍길동")
    @NotBlank
    private String name;

    @Schema(description = "이메일", required = true, example = "user@example.com")
    @Email
    private String email;
}
```

## Validation Checklist

- [ ] 모든 Controller에 @Tag 존재
- [ ] 모든 엔드포인트에 @Operation 존재
- [ ] 모든 엔드포인트에 @ApiResponses 존재 (최소 성공/에러 케이스)
- [ ] 모든 @PathVariable, @RequestParam에 @Parameter 존재
- [ ] 모든 Request/Response DTO에 @Schema 존재
- [ ] example 값이 적절히 설정됨

## Output Format

```markdown
## API Documentation Report

### Missing Annotations
- [Controller] UserController: @Tag 누락
- [Method] getUser: @ApiResponse(404) 누락
- [DTO] UserResponse.email: @Schema 누락

### Added Annotations
- 수정된 파일 목록 및 변경 사항

### Swagger UI URL
- http://localhost:8080/swagger-ui.html
```

## Usage

```
/api-doc                        # 모든 Controller 검증
/api-doc UserController         # 특정 Controller만
/api-doc --fix                  # 누락된 어노테이션 자동 추가
```
