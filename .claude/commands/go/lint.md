# Go Lint

golangci-lint를 실행하고 발견된 이슈를 수정합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Go 프로젝트 디렉토리 |
| Output | 수정된 파일, 잔여 이슈 목록 |
| Required Tools | golangci-lint, goimports |
| Verification | `golangci-lint run ./...` 통과 |

## Checklist

### 기본 활성화 Linters
- [ ] `errcheck`: 에러 체크 누락
- [ ] `gosimple`: 코드 단순화 제안
- [ ] `govet`: 의심스러운 구문
- [ ] `staticcheck`: 정적 분석
- [ ] `unused`: 미사용 코드

### 권장 추가 Linters
- [ ] `goimports`: import 정리
- [ ] `misspell`: 오타
- [ ] `unconvert`: 불필요한 타입 변환

### Auto-fix
가능한 이슈는 자동 수정:
```bash
goimports -w .
gofmt -s -w .
```

## Output Format

```markdown
## Lint Report

### Fixed Issues
- [errcheck] file.go:42 - 에러 체크 추가

### Remaining Issues
- [staticcheck] file.go:58 - 수동 검토 필요
```

## Usage

```
/lint                    # 전체 프로젝트
/lint ./internal/...     # 특정 패키지
/lint --fix              # 자동 수정 적용
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `command not found: golangci-lint` | golangci-lint 미설치 | `brew install golangci-lint` 또는 `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` |
| `typecheck` 에러 발생 | Go 모듈 의존성 문제 | `go mod tidy && go mod download` 실행 |
| `.golangci.yml` 인식 안됨 | 설정 파일 위치 오류 | 프로젝트 루트에 파일 배치 확인 |
| `out of memory` 에러 | 대규모 프로젝트 분석 시 메모리 부족 | `--concurrency 1` 옵션으로 병렬 처리 제한 |
| 특정 linter 동작 안함 | 해당 linter 미활성화 | `.golangci.yml`의 `linters.enable` 확인 |
| `GOPATH` 관련 에러 | 모듈 모드 미사용 | `GO111MODULE=on` 환경변수 설정 |

## Best Practices

### .golangci.yml 예시

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
