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
- `/go-errors` - Error handling patterns
- `/go-gin` - Gin framework patterns
- `/go-testing` - Testing patterns
- `/concurrency-go` - 동시성 패턴 (Mutex, Channel, Worker Pool)
- `/distributed-lock` - MSA 분산 락 (Redis)

## Commands
- `/review` - Code review
- `/test-gen` - Generate table-driven tests
- `/lint` - Run golangci-lint with fixes
- `/refactor` - Code quality improvements

---
*Applies with global CLAUDE.md settings*
