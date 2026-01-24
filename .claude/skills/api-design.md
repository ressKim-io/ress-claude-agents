# REST API Design Patterns

REST API 설계 원칙, 에러 처리, 페이지네이션, 버저닝 패턴

## URL 설계 원칙

### 기본 규칙

| 규칙 | Good | Bad |
|------|------|-----|
| 명사 사용 (동사 X) | `/orders` | `/createOrder` |
| 복수형 사용 | `/users/123` | `/user/123` |
| 소문자 + 케밥케이스 | `/order-items` | `/orderItems` |
| 마지막 슬래시 제거 | `/users` | `/users/` |
| 계층 관계 표현 | `/users/123/orders` | `/orders?userId=123` |

### URL 구조

```
https://api.example.com/v1/users/123/orders?status=pending&sort=-created_at&page=2&limit=20
         └─ 도메인 ──────┘ └─ 버전 ─┘ └─ 리소스 경로 ─┘ └─────── 쿼리 파라미터 ────────┘
```

### HTTP 메서드 매핑

| 메서드 | 용도 | URL 예시 | 멱등성 |
|--------|------|----------|--------|
| GET | 조회 | `/users/123` | ✅ |
| POST | 생성 | `/users` | ❌ |
| PUT | 전체 수정 | `/users/123` | ✅ |
| PATCH | 부분 수정 | `/users/123` | ✅ |
| DELETE | 삭제 | `/users/123` | ✅ |

### 비-CRUD 액션 처리

```
# Bad: 동사 사용
POST /orders/123/cancel

# Good: 명사화 (리소스로 표현)
POST /orders/123/cancellation

# Good: 상태 변경으로 표현
PATCH /orders/123
{ "status": "cancelled" }
```

---

## 에러 응답 (RFC 9457)

### Problem Details 형식

RFC 9457 (RFC 7807 후속) 표준 에러 응답:

```json
{
  "type": "https://api.example.com/errors/insufficient-funds",
  "title": "Insufficient Funds",
  "status": 400,
  "detail": "Your account balance is $30, but the transaction requires $50.",
  "instance": "/accounts/12345/transactions/67890",
  "balance": 30,
  "required": 50
}
```

### 필드 설명

| 필드 | 필수 | 설명 |
|------|------|------|
| `type` | ❌ | 에러 유형 URI (문서 링크) |
| `title` | ❌ | 에러 유형 요약 (변하지 않음) |
| `status` | ❌ | HTTP 상태 코드 |
| `detail` | ❌ | 구체적 에러 설명 (클라이언트 도움용) |
| `instance` | ❌ | 에러 발생 리소스 URI |
| (확장) | ❌ | 추가 컨텍스트 필드 |

### HTTP 상태 코드

```
2xx: 성공
├── 200 OK              - 조회/수정 성공
├── 201 Created         - 생성 성공 (Location 헤더 포함)
└── 204 No Content      - 삭제 성공

4xx: 클라이언트 에러
├── 400 Bad Request     - 잘못된 요청 (검증 실패)
├── 401 Unauthorized    - 인증 필요
├── 403 Forbidden       - 권한 없음
├── 404 Not Found       - 리소스 없음
├── 409 Conflict        - 충돌 (중복 등)
├── 422 Unprocessable   - 검증 실패 (의미적)
└── 429 Too Many Requests - 요청 제한 초과

5xx: 서버 에러
├── 500 Internal Error  - 서버 에러
├── 502 Bad Gateway     - 업스트림 에러
├── 503 Unavailable     - 서비스 불가
└── 504 Gateway Timeout - 업스트림 타임아웃
```

### Spring Boot 구현

```java
// Spring Boot 3+ 기본 지원
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND,
            ex.getMessage()
        );
        problem.setType(URI.create("https://api.example.com/errors/not-found"));
        problem.setTitle("Resource Not Found");
        problem.setProperty("resourceId", ex.getResourceId());
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setTitle("Validation Failed");

        List<Map<String, String>> errors = ex.getBindingResult()
            .getFieldErrors()
            .stream()
            .map(error -> Map.of(
                "field", error.getField(),
                "message", error.getDefaultMessage()
            ))
            .toList();

        problem.setProperty("errors", errors);
        return problem;
    }
}
```

### Go 구현

```go
type ProblemDetail struct {
    Type     string         `json:"type,omitempty"`
    Title    string         `json:"title"`
    Status   int            `json:"status"`
    Detail   string         `json:"detail,omitempty"`
    Instance string         `json:"instance,omitempty"`
    Extra    map[string]any `json:"extra,omitempty"`
}

func NewProblemDetail(status int, title, detail string) *ProblemDetail {
    return &ProblemDetail{
        Status: status,
        Title:  title,
        Detail: detail,
    }
}

func (p *ProblemDetail) WithType(t string) *ProblemDetail {
    p.Type = t
    return p
}

// Gin 에러 핸들러
func ErrorHandler() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()

        if len(c.Errors) > 0 {
            err := c.Errors.Last().Err

            var problem *ProblemDetail
            switch e := err.(type) {
            case *NotFoundError:
                problem = NewProblemDetail(404, "Not Found", e.Error())
            case *ValidationError:
                problem = NewProblemDetail(400, "Validation Failed", e.Error()).
                    WithType("https://api.example.com/errors/validation")
            default:
                problem = NewProblemDetail(500, "Internal Error", "Something went wrong")
            }

            c.JSON(problem.Status, problem)
        }
    }
}
```

---

## 페이지네이션

### Offset 기반

```
GET /users?page=3&limit=20
GET /users?offset=40&limit=20
```

**응답:**
```json
{
  "data": [...],
  "pagination": {
    "page": 3,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  },
  "links": {
    "self": "/users?page=3&limit=20",
    "first": "/users?page=1&limit=20",
    "prev": "/users?page=2&limit=20",
    "next": "/users?page=4&limit=20",
    "last": "/users?page=8&limit=20"
  }
}
```

**장점:** 특정 페이지 이동 가능
**단점:** 데이터 변경 시 중복/누락 가능

### Cursor 기반 (권장)

```
GET /users?cursor=eyJpZCI6MTIzfQ&limit=20
```

**응답:**
```json
{
  "data": [...],
  "pagination": {
    "limit": 20,
    "hasNext": true,
    "nextCursor": "eyJpZCI6MTQzfQ"
  }
}
```

**장점:** 대용량 데이터에 효율적, 실시간 데이터에 안정적
**단점:** 특정 페이지 이동 불가

### 기본값 및 제한

```java
@GetMapping("/users")
public Page<User> getUsers(
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "20") int limit
) {
    // 최대 100개로 제한 (DoS 방지)
    int safeLimit = Math.min(limit, 100);
    return userService.findAll(PageRequest.of(page, safeLimit));
}
```

---

## 필터링 & 정렬

### 필터링

```
# 단순 필터
GET /users?status=active&role=admin

# 비교 연산자
GET /products?price[gte]=100&price[lte]=500

# 검색
GET /users?search=john

# 복합 필터
GET /orders?status=pending,processing&created_at[gte]=2025-01-01
```

### 정렬

```
# 단일 정렬 (- 는 DESC)
GET /users?sort=-created_at

# 다중 정렬
GET /users?sort=-created_at,name

# 명시적 방향
GET /users?sort=created_at:desc,name:asc
```

### 필드 선택

```
# 필요한 필드만
GET /users?fields=id,name,email

# 관계 포함
GET /users?include=orders,profile
```

---

## 버저닝

### URL Path (권장)

```
GET /v1/users
GET /v2/users
```

**장점:** 명확함, 캐시 친화적
**단점:** 중복 코드 가능성

### Header 기반

```
GET /users
Accept: application/vnd.api+json; version=2
```

**장점:** URL 깔끔
**단점:** 테스트 어려움

### 버전 업그레이드 정책

```
Breaking Change가 필요한 경우:
├── 필드 삭제
├── 필드 타입 변경
├── 필수 파라미터 추가
└── 인증 방식 변경

Breaking Change가 아닌 경우:
├── 필드 추가
├── 선택적 파라미터 추가
└── 에러 메시지 개선
```

---

## 응답 구조

### 단일 리소스

```json
{
  "id": 123,
  "name": "John Doe",
  "email": "john@example.com",
  "createdAt": "2025-01-24T10:30:00Z",
  "links": {
    "self": "/users/123",
    "orders": "/users/123/orders"
  }
}
```

### 컬렉션

```json
{
  "data": [
    { "id": 1, "name": "..." },
    { "id": 2, "name": "..." }
  ],
  "meta": {
    "total": 150,
    "page": 1,
    "limit": 20
  },
  "links": {
    "self": "/users?page=1",
    "next": "/users?page=2"
  }
}
```

### 날짜/시간

```
# ISO 8601 + UTC
"createdAt": "2025-01-24T10:30:00Z"

# 타임존 포함
"scheduledAt": "2025-01-24T10:30:00+09:00"
```

---

## 보안

### 헤더

```
# 필수
Content-Type: application/json
Authorization: Bearer <token>

# 보안 관련
X-Request-ID: uuid        # 요청 추적
X-RateLimit-Limit: 100    # 요청 제한
X-RateLimit-Remaining: 95 # 남은 요청
```

### Rate Limiting

```json
// 429 Too Many Requests
{
  "type": "https://api.example.com/errors/rate-limit",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "detail": "You have exceeded the rate limit of 100 requests per minute.",
  "retryAfter": 30
}
```

### 민감 정보

```
❌ 노출하면 안 됨:
- 내부 에러 스택트레이스
- DB 쿼리
- 서버 경로
- 다른 사용자 정보

✅ 프로덕션 에러 응답:
{
  "status": 500,
  "title": "Internal Server Error",
  "detail": "An unexpected error occurred. Please try again later.",
  "instance": "/orders/123",
  "traceId": "abc123"  // 로그 추적용
}
```

---

## Anti-Patterns

| 실수 | 올바른 방법 |
|------|------------|
| `GET /getUsers` | `GET /users` |
| `POST /users/123/delete` | `DELETE /users/123` |
| 에러에 200 반환 | 적절한 4xx/5xx 코드 |
| 에러 형식 불일치 | RFC 9457 표준 사용 |
| SELECT * 응답 | 필요한 필드만 |
| 버전 없이 배포 | `/v1/` 시작부터 사용 |

---

## 체크리스트

### URL 설계
- [ ] 명사, 복수형, 소문자, 케밥케이스
- [ ] 계층 관계 올바르게 표현
- [ ] 버전 포함 (`/v1/`)

### 에러 처리
- [ ] RFC 9457 형식 사용
- [ ] 적절한 HTTP 상태 코드
- [ ] 클라이언트에 도움되는 `detail`
- [ ] 프로덕션에서 내부 정보 숨김

### 페이지네이션
- [ ] 기본값 설정 (limit=20)
- [ ] 최대값 제한 (max=100)
- [ ] 네비게이션 링크 제공

### 보안
- [ ] Rate Limiting 적용
- [ ] 인증/인가 확인
- [ ] 입력 검증
