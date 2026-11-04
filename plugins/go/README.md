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
| `/go:concurrency-go` | Go Concurrency Patterns — MSA/대규모 트래픽 환경에서의 Go 동시성 문제 해결 패턴 |
| `/go:effective-go` | Effective Go — 패턴 결정 가이드 — Rob Pike의 Go Proverbs + Modern Go (1.21+) 기반 실전 결정 가이드 |
| `/go:go-ai` | Go AI Integration Patterns — Go 백엔드에서 LLM 통합, 프레임워크 선택 (Genkit/LangChainGo/Eino), Tool Calling, RAG, MCP 서버 구현 |
| `/go:go-database` | Go Database Access Patterns — Go DB 라이브러리 선택 가이드 및 production-ready 패턴. ORM 없이 SQL 중심 개발 |
| `/go:go-gin` | Gin Framework Patterns — Gin 웹 프레임워크 패턴 및 best practices |
| `/go:go-microservice` | Go 마이크로서비스 가이드 — Go 기반 MSA 프로젝트 구조, 레이어드/헥사고날 아키텍처, 미들웨어 체인, DI 패턴, 운영 패턴 |
| `/go:go-performance` | Go 고성능 패턴 — sync.Pool 오브젝트 풀링, zero-allocation 기법, GC 튜닝(GOGC/GOMEMLIMIT), DB·HTTP 커넥션 관리, Graceful Shutdown, … |
| `/go:go-security` | Go 보안 리뷰 — 입력 검증·SQL/Command injection, 시크릿·인증 처리, 동시성 안전성, crypto/TLS 설정, 에러 정보 노출, path traversal, … |
| `/go:go-testing` | Go Testing Patterns — Go 테스트 패턴 및 best practices |
| `/go:refactoring-go` | Go Refactoring Patterns — Go 코드 리팩토링 패턴 및 best practices |
| `/go:viper-config-binding` | Go Viper의 설정 바인딩 함정과 정답 패턴. SetDefault + AutomaticEnv + Unmarshal 조합의 silent skip 동작과 mapstructure tag 매핑. 신규 … |

## Commands (4)

| 이름 | 설명 |
|---|---|
| `/go:lint` | golangci-lint를 실행하고 이슈를 수정합니다 |
| `/go:refactor` | Go 코드 리팩토링을 제안합니다 |
| `/go:review` | Go 코드를 리뷰하고 개선점을 제안합니다 |
| `/go:test-gen` | Table-driven 테스트 코드를 생성합니다 |
