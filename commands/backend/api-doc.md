# API Documentation Generator

OpenAPI/Swagger 어노테이션을 추가하거나 검증합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Controller 클래스 |
| Output | OpenAPI 어노테이션이 추가된 코드 |
| Required Tools | - |
| Verification | Swagger UI에서 API 문서 확인 |

## Required Annotations

### Controller Level
```java
@Tag(name = "User", description = "사용자 관리 API")
@RestController
```

### Method Level
```java
@Operation(summary = "사용자 조회")
@ApiResponses({
    @ApiResponse(responseCode = "200", description = "성공"),
    @ApiResponse(responseCode = "404", description = "Not Found")
})
@GetMapping("/{id}")
public UserResponse getUser(@PathVariable Long id) { }
```

### DTO Level
```java
@Schema(description = "사용자 응답")
public class UserResponse {
    @Schema(description = "사용자 ID", example = "1")
    private Long id;
}
```

## Validation Checklist

- [ ] 모든 Controller에 @Tag
- [ ] 모든 엔드포인트에 @Operation
- [ ] 모든 DTO에 @Schema
- [ ] example 값 설정

## Usage

```
/api-doc                 # 모든 Controller
/api-doc UserController  # 특정 Controller
/api-doc --fix           # 자동 추가
```
