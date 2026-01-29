# Go Refactor

Go 코드 품질 개선을 위한 리팩토링을 제안합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Go 소스 파일 또는 패키지 |
| Output | 리팩토링 제안 및 수정된 코드 |
| Required Tools | go |
| Verification | `go test ./...` 통과, 기능 동일 |

## Checklist

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

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| 리팩토링 후 테스트 실패 | 동작 변경됨 | `git diff`로 변경 사항 확인, 원본 복구 후 단계적 적용 |
| `undefined` 에러 | 함수 이동 후 import 누락 | 모든 import 문 확인, `goimports` 실행 |
| 순환 import 발생 | 패키지 간 의존성 꼬임 | interface를 별도 패키지로 분리 |
| 메서드 추출 후 private 접근 에러 | 다른 패키지로 이동 | 필요한 필드/메서드를 public으로 변경하거나 같은 패키지 유지 |
| IDE에서 참조 못 찾음 | 함수명/시그니처 변경 | `go build ./...`로 컴파일 확인, IDE 캐시 리프레시 |
| 성능 저하 | 과도한 함수 호출 오버헤드 | 핫 패스에서는 inline 유지, 벤치마크로 확인 |

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
