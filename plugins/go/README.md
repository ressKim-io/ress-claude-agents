<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# go

Go — 동시성, DB 접근, Gin, 마이크로서비스, 성능, 보안, 테스트, 리팩터링

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install go@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/go/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`security`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/security/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`lang/go.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/go.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (11)

| 이름 | 설명 |
|---|---|
| `/go:concurrency-go` | Go 동시성 패턴 — race detector, Mutex·RWMutex, channel 설계, DB 동시성, goroutine 누수 방지 |
| `/go:effective-go` | Go 관용 패턴 결정 기준 — 인터페이스 설계, 에러 처리(wrapping), Functional Options, 동시성 기본기, Modern Go 문법 |
| `/go:go-ai` | Go 백엔드 AI 통합 — Genkit·LangChainGo·Eino 비교, Tool Calling, RAG(PgVector), mcp-go 로 MCP 서버 구현 |
| `/go:go-database` | Go DB 접근 — pgx, sqlc, sqlx 선택, Connection Pool 설정, pgx 에러 처리, 테스트, Graceful Shutdown |
| `/go:go-gin` | Gin 웹 프레임워크 — Handler 구조, Router 설정, Middleware, Request Binding, Response 패턴 |
| `/go:go-microservice` | Go MSA 서비스 구조 — Standard Layout, 레이어드·헥사고날 아키텍처, 미들웨어 체인, DI, Viper 설정, Health Check |
| `/go:go-performance` | Go 고성능 패턴 — sync.Pool 오브젝트 풀링, zero-allocation 기법, GC 튜닝(GOGC/GOMEMLIMIT), DB·HTTP 커넥션 관리, Graceful Shutdown, … |
| `/go:go-security` | Go 보안 리뷰 — 입력 검증·SQL/Command injection, 시크릿·인증 처리, 동시성 안전성, crypto/TLS 설정, 에러 정보 노출, path traversal, … |
| `/go:go-testing` | Go 테스트 — table-driven test, 네이밍 규칙, go test 명령, mock 생성, HTTP handler 테스트, 테스트 파일 구조 |
| `/go:refactoring-go` | Go 리팩토링 — Early Return, 함수·인터페이스 추출, 의존성 주입, 에러 처리 개선, goroutine·channel 정리 |
| `/go:viper-config-binding` | Viper 설정 바인딩 함정 — AutomaticEnv 는 SetDefault 한 key만 인식, env 이름 매핑, nested struct·slice·map 바인딩 |

## Commands (4)

| 이름 | 설명 |
|---|---|
| `/go:lint` | golangci-lint를 실행하고 이슈를 수정합니다 |
| `/go:refactor` | Go 코드 리팩토링을 제안합니다 |
| `/go:review` | Go 코드를 리뷰하고 개선점을 제안합니다 |
| `/go:test-gen` | Table-driven 테스트 코드를 생성합니다 |
