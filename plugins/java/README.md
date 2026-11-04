<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# java

Java·Spring — Effective Java, Spring Data·Security·Cache, jOOQ, JVM 성능, 테스트

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install java@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/java/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`security`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/security/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`lang/java.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/java.md)
- [`lang/spring.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/spring.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (15)

| 이름 | 설명 |
|---|---|
| `/java:bean-postprocessor-ordering` | BeanPostProcessor 등록 순서/초기화 시점/프록시 래핑 타이밍 오류로 인한 런타임 누락 패턴 방지. static @Bean + ObjectProvider + Before/After … |
| `/java:concurrency-spring` | Spring Concurrency Patterns — MSA/대규모 트래픽 환경에서의 동시성 문제 해결 패턴 |
| `/java:effective-java` | Effective Java — 패턴 결정 가이드 — Effective Java + Modern Java (17+, 21+) 기반 설계 결정 가이드 |
| `/java:jvm-performance` | JVM/Spring 성능 튜닝 — Virtual Threads vs WebFlux 선택 기준, HikariCP 커넥션 풀(Virtual Threads 병용 주의), 다단계 캐싱, … |
| `/java:refactoring-spring` | Spring Refactoring Patterns — Spring Boot 코드 리팩토링 패턴 및 best practices |
| `/java:spring-ai` | Spring AI Patterns — Spring AI 1.1 기반 LLM 통합, ChatClient, Advisors API, Structured Output, Function Calling, … |
| `/java:spring-cache` | Spring Cache Patterns — Redis를 활용한 Spring Boot 캐싱 전략 |
| `/java:spring-data` | Spring Data Access Patterns — Spring Data JPA + QueryDSL 데이터 액세스 패턴 |
| `/java:spring-jooq` | Spring Boot + jOOQ Patterns — jOOQ (Java Object Oriented Querying) — 타입 세이프 SQL 빌더 + 코드 생성. JPA 대신 SQL 중심 개발 |
| `/java:spring-oauth2` | Spring OAuth2 & JWT Patterns — JWT 토큰 발급/검증 및 OAuth2 Resource Server 설정 |
| `/java:spring-patterns` | Spring Boot Core Patterns — Spring Boot 프로젝트에서 반복되는 설계 결정 가이드. '이 상황에서는 이렇게 한다' |
| `/java:spring-security` | Spring Security Patterns — Spring Security 기본 설정 및 Method Security 패턴 |
| `/java:spring-security-review` | Spring/Java 보안 리뷰 — SQL Injection, Spring Security 오설정, Mass Assignment, 역직렬화 공격, IDOR, 로깅 정보 노출, 암호·비밀번호 처리, … |
| `/java:spring-testcontainers` | Spring Testcontainers Patterns — Testcontainers, REST Assured를 활용한 통합 테스트 패턴 |
| `/java:spring-testing` | Spring Testing Patterns — JUnit 5, Mockito를 활용한 테스트 패턴 |

## Commands (5)

| 이름 | 설명 |
|---|---|
| `/java:lint` | SonarQube/Qodana 정적 분석을 수행합니다 |
| `/java:performance` | Native Image, CDS, GC 튜닝 등 성능 최적화를 제안합니다 |
| `/java:refactor` | Modern Java 패턴 및 Virtual Threads 리팩토링을 제안합니다 |
| `/java:review` | Java/Spring 코드를 리뷰합니다 (Virtual Threads, DI, Security) |
| `/java:test-gen` | JUnit 5 + Testcontainers 테스트를 생성합니다 |
