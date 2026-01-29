# Go Test Generator

Go 코드에 대한 테이블 기반 테스트 코드를 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Go 소스 파일 또는 함수명 |
| Output | `{filename}_test.go` 테스트 파일 |
| Required Tools | go, mockgen (선택) |
| Verification | `go test -v ./...` 통과 |

## Checklist

### Test Cases to Cover
- [ ] Happy path (정상 케이스)
- [ ] Error cases (에러 케이스)
- [ ] Edge cases (경계값)
- [ ] Nil/empty inputs
- [ ] Validation failures

### Test Template
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

### Mock Generation
필요시 gomock으로 mock 생성:
```bash
mockgen -source={source_file} -destination=mocks/mock_{name}.go
```

## Output Format

생성된 테스트 파일 `{filename}_test.go`

## Usage

```
/test-gen user_service.go           # 파일 전체
/test-gen user_service.go GetByID   # 특정 함수
/test-gen --mock                    # mock 파일도 생성
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `undefined` 에러 in test | 테스트 파일 패키지명 불일치 | 테스트 파일 패키지를 `{pkg}_test`로 통일 |
| mock 생성 실패 | interface 정의 없음 | 먼저 interface 정의 후 mockgen 실행 |
| `go test` timeout | 테스트가 외부 리소스 대기 | mock 사용 또는 `-timeout` 플래그 조정 |
| 테스트 간 간섭 발생 | 전역 상태 공유 | 각 테스트에서 독립적 상태 초기화 |
| 커버리지 0% | 빌드 태그 불일치 | `//go:build` 태그 확인 |
| parallel 테스트 실패 | 공유 리소스 경쟁 | `t.Parallel()` 제거 또는 리소스 격리 |

## Best Practices

1. 대상 파일/함수 확인
2. 함수 시그니처 분석
3. Table-driven test 구조로 테스트 생성
