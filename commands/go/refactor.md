# Go Refactor

Go 코드 품질 개선을 위한 리팩토링을 제안합니다.

## Analysis Areas

### 1. 코드 구조
- 함수 길이 (30줄 초과 시 분리 고려)
- 파라미터 수 (4개 초과 시 구조체 고려)
- 중첩 깊이 (3단계 초과 시 early return 적용)
- 패키지 의존성 (순환 참조 확인)

### 2. Go Idioms
- error 처리 패턴
- defer 사용
- context 전파
- interface 활용

### 3. 성능
- 불필요한 메모리 할당
- slice/map 사전 할당
- string concatenation (strings.Builder 사용)
- sync.Pool 활용 가능 여부

### 4. 테스트 용이성
- 의존성 주입 패턴
- interface 분리
- mock 가능한 구조

## Common Refactoring Patterns

### Early Return
```go
// Before
func process(data *Data) error {
    if data != nil {
        if data.Valid {
            // main logic
        }
    }
    return nil
}

// After
func process(data *Data) error {
    if data == nil {
        return nil
    }
    if !data.Valid {
        return nil
    }
    // main logic
    return nil
}
```

### Extract Function
```go
// Before
func handleRequest(w http.ResponseWriter, r *http.Request) {
    // 50 lines of code...
}

// After
func handleRequest(w http.ResponseWriter, r *http.Request) {
    input, err := parseInput(r)
    if err != nil {
        handleError(w, err)
        return
    }
    result := processInput(input)
    writeResponse(w, result)
}
```

### Interface Segregation
```go
// Before
type UserService interface {
    Create(user *User) error
    Update(user *User) error
    Delete(id int64) error
    FindByID(id int64) (*User, error)
    FindAll() ([]*User, error)
}

// After - 필요한 메서드만 의존
type UserCreator interface {
    Create(user *User) error
}

type UserFinder interface {
    FindByID(id int64) (*User, error)
}
```

## Output
- 개선 가능 영역 목록
- 우선순위별 정렬 (High, Medium, Low)
- 리팩토링 전/후 코드 예시
- 예상 효과 설명
