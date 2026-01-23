# Go Code Review

변경된 Go 코드를 리뷰합니다.

## Steps

1. `git diff` 또는 `git diff --cached`로 변경 사항 확인
2. 다음 항목 검토:

### Code Style
- [ ] gofmt/goimports 적용 여부
- [ ] 네이밍 컨벤션 준수 (CamelCase, camelCase)
- [ ] 패키지 import 순서 (stdlib, external, internal)
- [ ] 적절한 주석 (exported 함수에 GoDoc)

### Error Handling
- [ ] 에러 래핑 (`fmt.Errorf("...: %w", err)`)
- [ ] 에러 무시 없음 (`_ = err` 지양)
- [ ] 적절한 에러 체크 (`errors.Is`, `errors.As`)

### Testing
- [ ] 변경된 코드에 대한 테스트 존재
- [ ] Table-driven test 패턴 사용
- [ ] 테스트 커버리지 80% 이상

### Security
- [ ] SQL Injection 방지 (parameterized query)
- [ ] 민감 정보 하드코딩 없음
- [ ] Input validation 적용

### Performance
- [ ] 불필요한 메모리 할당 없음
- [ ] goroutine leak 가능성 없음
- [ ] context 적절히 전파

## Output
- 이슈 발견 시 파일:라인 형식으로 지적
- 개선 제안 코드 예시 제공
- 심각도 표시 (Critical, Warning, Info)
