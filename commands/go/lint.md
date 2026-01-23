# Go Lint

golangci-lint를 실행하고 발견된 이슈를 수정합니다.

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
- `ineffassign`: 비효율적 할당
- `staticcheck`: 정적 분석
- `unused`: 미사용 코드

### 권장 추가
- `gofmt`: 포맷팅
- `goimports`: import 정리
- `misspell`: 오타
- `unconvert`: 불필요한 타입 변환
- `unparam`: 미사용 파라미터
- `nakedret`: naked return 지양
- `prealloc`: slice 사전 할당

## Auto-fix

가능한 이슈는 자동 수정:
```bash
# goimports로 import 정리
goimports -w .

# gofmt로 포맷팅
gofmt -s -w .
```

## .golangci.yml 예시

```yaml
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - gofmt
    - goimports
    - misspell

linters-settings:
  errcheck:
    check-blank: true

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - errcheck
```

## Output
- 발견된 이슈 목록
- 자동 수정된 항목
- 수동 수정 필요 항목과 제안
