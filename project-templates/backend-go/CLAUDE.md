# Backend Go Project - Claude Settings

## Quick Reference
- Test: `go test -race -cover ./...`
- Lint: `golangci-lint run`
- Format: `goimports -w .`
- Build: `go build -o bin/api ./cmd/api`

## Project Structure
```
cmd/api/main.go          # Entry point
internal/handler/        # HTTP handlers
internal/service/        # Business logic
internal/repository/     # Data access
internal/domain/         # Domain models, errors
pkg/                     # Public libraries
```

## CRITICAL Rules

1. **Error Wrapping** - Verify: `grep -r "return err$" internal/`
   ```go
   // Always wrap with context
   return fmt.Errorf("failed to get user %d: %w", id, err)
   ```

2. **Table-Driven Tests** - Verify: `go test -cover ./...` (80%+)
   ```go
   tests := []struct{ name string; ... }{}
   for _, tt := range tests { t.Run(tt.name, ...) }
   ```

3. **Security Context** - Verify: `grep -r "fmt.Sprintf.*SELECT" internal/`
   - Use parameterized queries only
   - No hardcoded secrets

## Common Mistakes

| Mistake | Correct | Verify |
|---------|---------|--------|
| `return err` | `return fmt.Errorf("ctx: %w", err)` | `grep "return err$"` |
| `image: latest` | `image: v1.2.3` | Check Dockerfile |
| No test | Table-driven test | `go test -cover` |
| `_ = err` | Handle or log error | `grep "_ ="` |
| `map` 동시 접근 | `sync.Map` 또는 Mutex | `go test -race` |
| MSA에서 로컬 락 | 분산 락 (Redis) | Race condition |

## Skills Reference
- `/go-database` - DB 라이브러리 선택 (pgx, sqlc, sqlx) 및 커넥션 풀 설정
- `/go-errors` - Error handling patterns
- `/go-gin` - Gin framework patterns
- `/go-testing` - Testing patterns
- `/concurrency-go` - 동시성 패턴 (Mutex, Channel, Worker Pool)
- `/distributed-lock` - MSA 분산 락 (Redis)
- `/observability` - 로깅 + OpenTelemetry + 메트릭
- `/observability-otel` - OpenTelemetry SDK 및 Collector 설정
- `/monitoring-grafana` - Grafana 대시보드, 알림, RBAC
- `/monitoring-metrics` - Prometheus 스케일링, Thanos/VictoriaMetrics
- `/monitoring-logs` - Fluent Bit, Loki, 로그 필터링
- `/monitoring-troubleshoot` - 알림 대응, 트러블슈팅
- `/logging-compliance` - 결제/개인정보 법적 로그 (PCI-DSS, 전자금융거래법)
- `/logging-security` - 봇/매크로 탐지, 보안 감사 로그
- `/logging-loki` - Loki + LogQL 검색/분석 (개발팀/보안팀용)
- `/logging-elk` - ELK Stack 검색/분석 (Elasticsearch, Kibana)
- `/api-design` - REST API 설계, 에러 처리 (RFC 9457)
- `/docker` - Dockerfile 최적화, 멀티스테이지 빌드
- `/database` - 인덱스, N+1 해결, 쿼리 최적화
- `/database-migration` - Flyway, golang-migrate, 스키마 변경

## Commands
- `/review` - Code review
- `/test-gen` - Generate table-driven tests
- `/lint` - Run golangci-lint with fixes
- `/refactor` - Code quality improvements

---
*Applies with global CLAUDE.md settings*
