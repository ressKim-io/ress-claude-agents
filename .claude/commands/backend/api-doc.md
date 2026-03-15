# API Documentation Generator

OpenAPI/Swagger 어노테이션을 추가하거나 검증합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Controller 클래스 |
| Output | OpenAPI 어노테이션이 추가된 코드 |
| Required Tools | - |
| Verification | Swagger UI에서 API 문서 확인 |

## Checklist

### Required Annotations
- [ ] 모든 Controller에 @Tag
- [ ] 모든 엔드포인트에 @Operation
- [ ] 모든 DTO에 @Schema
- [ ] example 값 설정

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

## Output Format

OpenAPI 어노테이션이 추가된 코드

## Usage

```
/api-doc                 # 모든 Controller
/api-doc UserController  # 특정 Controller
/api-doc --fix           # 자동 추가
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| Swagger UI에 API 미표시 | `@Tag` 또는 `@Operation` 누락 | Controller에 어노테이션 추가 확인 |
| example 값 표시 안됨 | `@Schema(example = ...)` 누락 | DTO 필드에 example 추가 |
| 500 응답코드만 표시 | `@ApiResponses` 미설정 | 모든 가능한 응답 코드 명시 |
| springdoc 의존성 에러 | 버전 호환성 문제 | Spring Boot 버전에 맞는 springdoc 버전 사용 |
| 인증 헤더 미표시 | Security Scheme 미설정 | `@SecurityScheme` 설정 추가 |
| Swagger JSON 생성 안됨 | 패키지 스캔 범위 문제 | `springdoc.packagesToScan` 설정 확인 |
