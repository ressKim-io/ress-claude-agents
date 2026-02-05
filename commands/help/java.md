# Java Commands Help

Java/Spring 개발을 위한 명령어 모음입니다.

## Available Commands

| Command | Description |
|---------|-------------|
| `/java review` | Java/Spring 코드 리뷰 (Virtual Threads, DI, Security) |
| `/java test-gen` | JUnit 5 + Testcontainers 테스트 생성 |
| `/java lint` | 정적 분석 (SonarQube, Qodana, SpotBugs) |
| `/java refactor` | 리팩토링 패턴 적용 (Modern Java, Virtual Threads) |
| `/java performance` | 성능 최적화 (Native Image, CDS, GC) |

## Quick Examples

```bash
# 코드 리뷰
/java review                    # 변경사항 전체 리뷰
/java review --staged           # staged 변경만 리뷰

# 테스트 생성
/java test-gen UserService      # 클래스 테스트 생성
/java test-gen --type=integration  # 통합 테스트 생성

# 정적 분석
/java lint                      # 전체 프로젝트 분석
/java lint --security           # 보안 이슈만 검사

# 리팩토링
/java refactor --virtual-threads  # Virtual Threads 마이그레이션
/java refactor --modern           # Modern Java 패턴 적용

# 성능 최적화
/java performance --startup     # 시작 시간 최적화
/java performance --profile     # 프로파일링 가이드
```

## 2026 Best Practices Included

- **Java 21+ Virtual Threads**: I/O-bound 작업 성능 개선
- **GraalVM Native Image**: 초단위 시작, 적은 메모리
- **Spring Boot 3.3 CDS**: JVM 시작 가속
- **Testcontainers**: 실제 DB로 통합 테스트
- **Qodana**: Spring 특화 정적 분석
- **Pattern Matching**: Java 21+ 문법 활용

## Related Skills

- `/spring-testing` - Spring 테스트 상세
- `/spring-security` - Spring Security 패턴
- `/spring-data` - JPA/QueryDSL 최적화
- `/concurrency-spring` - 동시성 패턴
