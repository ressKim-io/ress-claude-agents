---
paths: "**/*.go"
---

# Go 코드 패턴 규칙

Go Proverbs + Effective Go + Modern Go (1.21+) 핵심 규칙.

## 인터페이스

- PREFER 파라미터는 interface로 받고, 반환값은 concrete struct로 반환
- MUST 인터페이스 메서드는 1-3개로 제한 ("The bigger the interface, the weaker the abstraction")
- MUST 인터페이스는 구현 패키지가 아닌 소비자(consumer) 패키지에 정의
- PREFER zero value가 유용하도록 struct 설계 (`var s Server`가 동작해야 함)

## 에러 처리

- MUST 에러는 항상 처리 — `_ = err` 절대 금지
- MUST 에러 래핑: `fmt.Errorf("operation failed: %w", err)`
- MUST 에러 비교: `errors.Is()` / `errors.As()` 사용 (직접 `==` 비교 금지)
- NEVER 라이브러리 코드에서 `panic` 사용
- PREFER Sentinel error 선언: `var ErrNotFound = errors.New("not found")`

```go
// Bad
if err != nil { return err }  // 컨텍스트 없음

// Good
if err != nil { return fmt.Errorf("fetch user %d: %w", id, err) }
```

## 동시성

- PREFER 고루틴 간 데이터 전달 → Channel 사용
- PREFER 단순 상태 보호 → `sync.Mutex` 사용
- MUST `context.Context`는 항상 첫 번째 파라미터로 전달
- NEVER struct 필드에 `context.Context` 저장
- PREFER 여러 고루틴의 에러 수집 → `golang.org/x/sync/errgroup` 사용

```go
// Bad
type Server struct { ctx context.Context }

// Good
func (s *Server) Run(ctx context.Context) error { ... }
```

## 초기화

- PREFER 선택적 옵션이 3개 이상이면 Functional Options 패턴 사용
- PREFER 필수 파라미터만 적을 때는 `NewXxx()` 생성자 함수 사용

```go
// Functional Options
type Option func(*Server)
func WithTimeout(d time.Duration) Option { return func(s *Server) { s.timeout = d } }
func NewServer(addr string, opts ...Option) *Server { ... }
```

## Modern Go (1.21+)

- MUST 구조화 로깅은 `log/slog` 사용 — `fmt.Println`, `log.Printf` 금지
- PREFER Generics는 같은 로직을 타입만 다르게 쓸 때만 — interface로 충분하면 generic 사용하지 않음
- PREFER 10-20줄 수준의 유틸 함수는 외부 패키지 추가보다 복사(copy) 선호

```go
// Good
slog.Info("user created", "id", user.ID, "email", user.Email)
```

## 코드 스타일

- MUST Clear is better than clever — 영리한 코드보다 읽기 쉬운 코드
- PREFER Early return (guard clause) 으로 중첩 줄이기
- PREFER 좁은 스코프(함수 내부)에서는 짧은 변수명 (`err`, `ctx`, `req`, `resp`)
- PREFER 넓은 스코프(패키지 수준)에서는 설명적 변수명

```go
// Bad
func process(u *User) error {
    if u != nil {
        if u.Active {
            // 핵심 로직
        }
    }
    return nil
}

// Good
func process(u *User) error {
    if u == nil { return ErrNilUser }
    if !u.Active { return ErrInactiveUser }
    // 핵심 로직
    return nil
}
```

## 참조

상세 가이드: `/effective-go` 스킬 참조
