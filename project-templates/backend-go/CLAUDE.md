# Backend Go Project - Claude Settings

Go 백엔드 프로젝트를 위한 Claude Code 설정입니다.

## Project Structure

golang-standards/project-layout 기반:
```
project/
├── cmd/                         # 메인 애플리케이션
│   └── api/
│       └── main.go
├── internal/                    # 비공개 애플리케이션 코드
│   ├── handler/                 # HTTP 핸들러
│   ├── service/                 # 비즈니스 로직
│   ├── repository/              # 데이터 접근 계층
│   ├── domain/                  # 도메인 모델
│   └── config/                  # 설정
├── pkg/                         # 공개 라이브러리 코드
├── api/                         # API 스펙 (OpenAPI, protobuf)
├── configs/                     # 설정 파일
├── scripts/                     # 빌드, 설치 스크립트
├── test/                        # 추가 테스트 데이터
├── go.mod
├── go.sum
└── Makefile
```

### 디렉토리 규칙
- `internal/`: 외부 패키지에서 import 불가, 내부 코드만
- `pkg/`: 외부에서 사용 가능한 라이브러리 코드
- `cmd/`: 각 실행 파일별 디렉토리 (예: `cmd/api/`, `cmd/worker/`)

## Code Style

### Naming Convention
```go
// 패키지: 소문자, 단수형, 짧게
package user      // Good
package userUtils // Bad

// 함수/메서드: CamelCase (exported), camelCase (unexported)
func GetUser() {}     // exported
func validateInput() {} // unexported

// 변수: camelCase, 의미있는 이름
var userCount int     // Good
var uc int            // Bad (too short)
var user_count int    // Bad (snake_case)

// 상수: CamelCase 또는 ALL_CAPS (C 스타일 상수만)
const MaxRetries = 3
const defaultTimeout = 30 * time.Second

// 인터페이스: -er 접미사 권장
type Reader interface {}
type UserService interface {}  // 서비스 인터페이스는 예외

// Receiver: 짧은 이름 (1-2자)
func (u *User) GetName() string {}  // Good
func (user *User) GetName() string {} // Acceptable but verbose
```

### 패키지 구성
```go
// 패키지 import 순서: stdlib, external, internal
import (
    "context"
    "fmt"
    "net/http"

    "github.com/gin-gonic/gin"
    "go.uber.org/zap"

    "myproject/internal/domain"
    "myproject/internal/service"
)
```

### 코드 포맷팅
- `gofmt` 또는 `goimports` 필수 사용
- 라인 길이: 권장 100자, 최대 120자
- 주석: 영문으로 작성, 완전한 문장으로

## Error Handling

**IMPORTANT:** Wrapped errors 패턴 사용

### 에러 래핑
```go
// Good - 컨텍스트 추가하여 래핑
if err != nil {
    return fmt.Errorf("failed to get user %d: %w", userID, err)
}

// Bad - 컨텍스트 없이 반환
if err != nil {
    return err
}
```

### 에러 체크
```go
// errors.Is: 특정 에러 값 체크
if errors.Is(err, sql.ErrNoRows) {
    return nil, ErrUserNotFound
}

// errors.As: 에러 타입 체크
var validationErr *ValidationError
if errors.As(err, &validationErr) {
    return nil, validationErr
}
```

### 센티넬 에러
```go
// internal/domain/errors.go
var (
    ErrUserNotFound    = errors.New("user not found")
    ErrInvalidInput    = errors.New("invalid input")
    ErrUnauthorized    = errors.New("unauthorized")
)
```

### 커스텀 에러 타입 (필요시)
```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation error: %s - %s", e.Field, e.Message)
}
```

## Web Framework (Gin)

### 핸들러 구조
```go
// internal/handler/user_handler.go
type UserHandler struct {
    userService service.UserService
    logger      *zap.Logger
}

func NewUserHandler(us service.UserService, logger *zap.Logger) *UserHandler {
    return &UserHandler{
        userService: us,
        logger:      logger,
    }
}

func (h *UserHandler) GetUser(c *gin.Context) {
    id, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
        return
    }

    user, err := h.userService.GetByID(c.Request.Context(), id)
    if err != nil {
        if errors.Is(err, domain.ErrUserNotFound) {
            c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
            return
        }
        h.logger.Error("failed to get user", zap.Error(err))
        c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
        return
    }

    c.JSON(http.StatusOK, user)
}
```

### 라우터 설정
```go
// internal/handler/router.go
func SetupRouter(h *UserHandler) *gin.Engine {
    r := gin.New()
    r.Use(gin.Recovery())
    r.Use(ginzap.Ginzap(logger, time.RFC3339, true))

    api := r.Group("/api/v1")
    {
        users := api.Group("/users")
        {
            users.GET("/:id", h.GetUser)
            users.POST("", h.CreateUser)
        }
    }

    return r
}
```

### 미들웨어
```go
func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
            return
        }
        // validate token...
        c.Next()
    }
}
```

## Testing

**IMPORTANT:** 테스트 커버리지 80% 이상 유지

### 테스트 파일 구조
```
internal/
├── service/
│   ├── user_service.go
│   └── user_service_test.go    # 같은 디렉토리
└── handler/
    ├── user_handler.go
    └── user_handler_test.go
```

### Table-Driven Tests (필수)
```go
func TestUserService_GetByID(t *testing.T) {
    tests := []struct {
        name    string
        userID  int64
        mockFn  func(*mocks.MockUserRepository)
        want    *domain.User
        wantErr error
    }{
        {
            name:   "success",
            userID: 1,
            mockFn: func(m *mocks.MockUserRepository) {
                m.EXPECT().FindByID(gomock.Any(), int64(1)).
                    Return(&domain.User{ID: 1, Name: "test"}, nil)
            },
            want:    &domain.User{ID: 1, Name: "test"},
            wantErr: nil,
        },
        {
            name:   "not found",
            userID: 999,
            mockFn: func(m *mocks.MockUserRepository) {
                m.EXPECT().FindByID(gomock.Any(), int64(999)).
                    Return(nil, domain.ErrUserNotFound)
            },
            want:    nil,
            wantErr: domain.ErrUserNotFound,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()

            mockRepo := mocks.NewMockUserRepository(ctrl)
            tt.mockFn(mockRepo)

            svc := service.NewUserService(mockRepo)
            got, err := svc.GetByID(context.Background(), tt.userID)

            if !errors.Is(err, tt.wantErr) {
                t.Errorf("GetByID() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("GetByID() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

### 테스트 네이밍
```go
// 패턴: Test{Type}_{Method}[_{Scenario}]
func TestUserService_GetByID(t *testing.T) {}
func TestUserService_GetByID_NotFound(t *testing.T) {}
func TestUserHandler_GetUser_InvalidID(t *testing.T) {}
```

### 테스트 실행
```bash
# 전체 테스트
go test ./...

# 커버리지 포함
go test -cover ./...

# 커버리지 리포트
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# 특정 패키지
go test ./internal/service/...

# 특정 테스트
go test -run TestUserService_GetByID ./...
```

### Mock 생성
```bash
# gomock 사용
mockgen -source=internal/repository/user_repository.go \
    -destination=internal/mocks/mock_user_repository.go
```

## Dependency Injection

### Wire 또는 수동 DI
```go
// cmd/api/main.go
func main() {
    // Config
    cfg := config.Load()

    // Logger
    logger, _ := zap.NewProduction()

    // Database
    db, _ := sql.Open("postgres", cfg.DatabaseURL)

    // Repositories
    userRepo := repository.NewUserRepository(db)

    // Services
    userService := service.NewUserService(userRepo)

    // Handlers
    userHandler := handler.NewUserHandler(userService, logger)

    // Router
    r := handler.SetupRouter(userHandler)
    r.Run(":8080")
}
```

## Git Workflow

### Commit Convention
```
<type>(<scope>): <subject>

<body>
```

**Types:**
- feat: 새 기능
- fix: 버그 수정
- refactor: 리팩토링
- test: 테스트 추가/수정
- docs: 문서
- chore: 빌드, 설정 변경

### 커밋 단위
- 하나의 논리적 변경 = 하나의 커밋
- 기능 추가: handler + service + repository + test

### Pull Request
- **IMPORTANT:** PR 크기는 400줄 이하 유지
- 테스트 포함 필수
- go test, go vet, golangci-lint 통과

## Linting & Formatting

### 필수 도구
```bash
# 설치
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# 실행
goimports -w .
golangci-lint run
```

### Makefile 예시
```makefile
.PHONY: fmt lint test build

fmt:
	goimports -w .
	gofmt -s -w .

lint:
	golangci-lint run

test:
	go test -race -cover ./...

build:
	go build -o bin/api ./cmd/api

all: fmt lint test build
```

## Security

### 민감 정보
```go
// Bad - 하드코딩 금지
const apiKey = "sk-xxx"

// Good - 환경변수 사용
apiKey := os.Getenv("API_KEY")
```

### SQL Injection 방지
```go
// Bad
query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", id)

// Good - parameterized query
query := "SELECT * FROM users WHERE id = $1"
row := db.QueryRow(query, id)
```

### Input Validation
```go
// binding 태그 사용
type CreateUserRequest struct {
    Name  string `json:"name" binding:"required,min=1,max=100"`
    Email string `json:"email" binding:"required,email"`
    Age   int    `json:"age" binding:"gte=0,lte=150"`
}
```

## Commands

다음 명령어 사용 가능:
- `/review` - 변경된 코드 리뷰
- `/test-gen` - 테이블 기반 테스트 코드 생성
- `/lint` - golangci-lint 실행 및 수정
- `/refactor` - 코드 품질 개선 제안

---

*global CLAUDE.md 설정도 함께 적용됩니다*
