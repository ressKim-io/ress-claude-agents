# Go Refactor

Go 코드 품질 개선을 위한 리팩토링을 제안합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Go 소스 파일 또는 패키지 |
| Output | 리팩토링 제안 및 수정된 코드 |
| Required Tools | go |
| Verification | `go test ./...` 통과, 기능 동일 |

## Analysis Areas

### 1. 코드 구조
- 함수 길이 (30줄 초과 시 분리 고려)
- 파라미터 수 (4개 초과 시 구조체 고려)
- 중첩 깊이 (3단계 초과 시 early return 적용)

### 2. Go Idioms
- error 처리 패턴
- defer 사용
- context 전파
- interface 활용

### 3. 성능
- 불필요한 메모리 할당
- slice/map 사전 할당
- strings.Builder 사용

### 4. 테스트 용이성
- 의존성 주입 패턴
- interface 분리
- mock 가능한 구조

## Output Format

```markdown
## Refactoring Suggestions

### High Priority
- [파일:라인] 제안 내용

### Code Examples
- Before: {원본 코드}
- After: {개선된 코드}
```

## Usage

```
/refactor user_service.go           # 파일 분석
/refactor ./internal/handler/       # 패키지 분석
/refactor --apply                   # 제안 적용
```

## Best Practices

### Early Return
```go
// Before
if data != nil {
    if data.Valid { /* logic */ }
}

// After
if data == nil { return nil }
if !data.Valid { return nil }
// logic
```

### Extract Function
```go
// Before: 50 lines handler

// After
input, err := parseInput(r)
result := processInput(input)
writeResponse(w, result)
```
