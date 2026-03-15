# Go Code Review

변경된 Go 코드를 리뷰합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Git diff 또는 특정 파일 |
| Output | 이슈 목록 (파일:라인, 심각도, 제안) |
| Required Tools | git, go |
| Verification | 모든 Critical/High 이슈 해결 |

## Checklist

### Code Style
- [ ] gofmt/goimports 적용 여부
- [ ] 네이밍 컨벤션 준수 (CamelCase, camelCase)
- [ ] 패키지 import 순서 (stdlib, external, internal)

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

## Output Format

```
[Critical] file.go:42 - 에러 무시됨
  현재: _ = db.Close()
  수정: if err := db.Close(); err != nil { log.Error(err) }

[Warning] file.go:58 - 에러 컨텍스트 없음
  현재: return err
  수정: return fmt.Errorf("failed to create user: %w", err)
```

## Usage

```
/review                    # 현재 변경사항 리뷰
/review file.go            # 특정 파일 리뷰
/review --staged           # staged 변경만 리뷰
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `git diff` 결과 없음 | 변경사항 미커밋 또는 이미 staged | `git diff --cached` 또는 `git status` 확인 |
| 테스트 커버리지 측정 실패 | 테스트 파일 없음 | `_test.go` 파일 존재 확인 |
| `go vet` 오탐 | 특정 패턴 오인식 | `//nolint:vet` 주석으로 무시 (사유 명시) |
| 리뷰 범위가 너무 큼 | PR 크기 과다 | PR 분할, 기능 단위로 나누어 리뷰 |
| 에러 컨텍스트 추가 어려움 | 기존 코드 스타일 불일치 | 프로젝트 에러 처리 패턴 먼저 정립 |
| context 전파 누락 감지 어려움 | 긴 콜체인 | 최상위부터 context 파라미터 일관성 확인 |

## Best Practices

1. `git diff` 또는 `git diff --cached`로 변경 사항 확인
2. 심각도별로 이슈 분류하여 리포트
