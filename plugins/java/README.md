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
| `/java:bean-postprocessor-ordering` | Spring BeanPostProcessor 순서 함정 — 빈 초기화 순서, 다른 BPP 의 래핑 타이밍, 메트릭·계측·AOP 의 silent 누락 |
| `/java:concurrency-spring` | Spring 동시성 제어 — Optimistic Locking(@Version), Pessimistic Locking, Deadlock 방지, 락 선택 기준 |
| `/java:effective-java` | Effective Java 설계 결정 — 객체 생성 패턴, Modern Java(17·21) 기능, 제네릭·enum, Stream vs for loop, 예외 처리 |
| `/java:jvm-performance` | JVM·Spring 성능 튜닝 — Virtual Threads vs WebFlux, HikariCP, 다단계 캐싱, Resilience4j Circuit Breaker, JVM 옵션 |
| `/java:refactoring-spring` | Spring Boot 리팩토링 — Extract Method, God Class 분해, 계층 분리, N+1 쿼리 개선, DI 개선, 테스트 용이성 향상 |
| `/java:spring-ai` | Spring AI 통합 — ChatClient, Advisors API, Structured Output, Function·Tool Calling, MCP, RAG, 비용 최적화 |
| `/java:spring-cache` | Spring Cache 와 Redis — @Cacheable·@CacheEvict 등 캐시 어노테이션, 캐싱 전략, RedisTemplate 직접 사용 |
| `/java:spring-data` | Spring Data JPA 와 QueryDSL — Repository, 동적 쿼리, JPA+QueryDSL 조합, 흔한 실수 |
| `/java:spring-jooq` | Spring Boot + jOOQ — 타입 세이프 SQL 빌더, 코드 생성(Flyway·Testcontainers), MULTISET, Window Function·CTE, Keyset … |
| `/java:spring-oauth2` | Spring JWT 와 OAuth2 — JWT 발급·검증, JWT Filter, Auth Controller, Resource Server 설정, Token TTL |
| `/java:spring-patterns` | Spring Boot 핵심 설계 규칙 — 계층 구조, @Transactional 규칙, DTO vs Entity 분리, 예외 처리, 의존성 주입, API 설계 |
| `/java:spring-security` | Spring Security 기본 설정 — SecurityFilterChain, Method Security(@PreAuthorize), CORS, 설정 우선순위, Authorization … |
| `/java:spring-security-review` | Spring/Java 보안 리뷰 — SQL Injection, Spring Security 오설정, Mass Assignment, 역직렬화 공격, IDOR, 로깅 정보 노출, 암호·비밀번호 처리, … |
| `/java:spring-testcontainers` | Spring 통합 테스트 — Testcontainers 공유 컨테이너, PostgreSQL·MongoDB, @DataJpaTest, REST Assured, @Sql 데이터, 컨테이너 재사용 |
| `/java:spring-testing` | Spring 단위·슬라이스 테스트 — JUnit 5, Mockito, @WebMvcTest, @DataJpaTest, 테스트 픽스처, 네이밍 규칙, 테스트 피라미드 |

## Commands (5)

| 이름 | 설명 |
|---|---|
| `/java:lint` | SonarQube/Qodana 정적 분석을 수행합니다 |
| `/java:performance` | Native Image, CDS, GC 튜닝 등 성능 최적화를 제안합니다 |
| `/java:refactor` | Modern Java 패턴 및 Virtual Threads 리팩토링을 제안합니다 |
| `/java:review` | Java/Spring 코드를 리뷰합니다 (Virtual Threads, DI, Security) |
| `/java:test-gen` | JUnit 5 + Testcontainers 테스트를 생성합니다 |
