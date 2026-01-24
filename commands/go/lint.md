# Go Lint

golangci-lint를 실행하고 발견된 이슈를 수정합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Go 프로젝트 디렉토리 |
| Output | 수정된 파일, 잔여 이슈 목록 |
| Required Tools | golangci-lint, goimports |
| Verification | `golangci-lint run ./...` 통과 |

## Steps

1. golangci-lint 실행
```bash
golangci-lint run ./...
```

2. 발견된 이슈 분석 및 수정

## Common Linters

### 기본 활성화
- `errcheck`: 에러 체크 누락
- `gosimple`: 코드 단순화 제안
- `govet`: 의심스러운 구문
- `staticcheck`: 정적 분석
- `unused`: 미사용 코드

### 권장 추가
- `goimports`: import 정리
- `misspell`: 오타
- `unconvert`: 불필요한 타입 변환

## Auto-fix

가능한 이슈는 자동 수정:
```bash
goimports -w .
gofmt -s -w .
```

## .golangci.yml 예시

```yaml
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - staticcheck
    - goimports
    - misspell

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - errcheck
```

## Usage
```
/lint                    # 전체 프로젝트
/lint ./internal/...     # 특정 패키지
/lint --fix              # 자동 수정 적용
```
