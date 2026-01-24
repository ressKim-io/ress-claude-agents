# Go Test Generator

Go 코드에 대한 테이블 기반 테스트 코드를 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Go 소스 파일 또는 함수명 |
| Output | `{filename}_test.go` 테스트 파일 |
| Required Tools | go, mockgen (선택) |
| Verification | `go test -v ./...` 통과 |

## Steps

1. 대상 파일/함수 확인
2. 함수 시그니처 분석
3. Table-driven test 구조로 테스트 생성

## Test Template

```go
func Test{TypeName}_{MethodName}(t *testing.T) {
    tests := []struct {
        name    string
        // input fields
        want    // expected output type
        wantErr error
    }{
        {
            name: "success case",
            // ...
        },
        {
            name: "error case",
            // ...
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange (Given)
            // Act (When)
            // Assert (Then)
        })
    }
}
```

## Test Cases to Cover

- Happy path (정상 케이스)
- Error cases (에러 케이스)
- Edge cases (경계값)
- Nil/empty inputs
- Validation failures

## Mock Generation

필요시 gomock으로 mock 생성:
```bash
mockgen -source={source_file} -destination=mocks/mock_{name}.go
```

## Usage
```
/test-gen user_service.go           # 파일 전체
/test-gen user_service.go GetByID   # 특정 함수
/test-gen --mock                    # mock 파일도 생성
```
