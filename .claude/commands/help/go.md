# Go Commands

Go 백엔드 개발을 위한 명령어입니다.

## 명령어

| 명령어 | 설명 |
|--------|------|
| `/go review` | Go 코드 리뷰 |
| `/go test-gen` | Table-driven 테스트 생성 |
| `/go lint` | golangci-lint 실행 및 수정 |
| `/go refactor` | 리팩토링 제안 |

## 관련 Skills

| Skill | 내용 |
|-------|------|
| `/go-errors` | 에러 처리 패턴 |
| `/go-gin` | Gin 프레임워크 |
| `/go-testing` | 테스트 패턴 |
| `/concurrency-go` | 동시성 패턴 |

## Quick Reference

```bash
# 테스트
go test ./...
go test -v -cover ./...

# 린트
golangci-lint run

# 빌드
go build -v ./cmd/...
```
