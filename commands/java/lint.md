# Java/Spring Static Analysis

Java/Spring 프로젝트의 정적 분석을 수행합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 프로젝트 또는 특정 파일 |
| Output | 정적 분석 결과 리포트 |
| Required Tools | java, gradle/maven, sonarqube/qodana |
| Verification | Critical/Blocker 이슈 0개 |

## Tool Selection

```
정적 분석 도구 선택:
├─ IDE 통합 필요 + Spring 특화
│   └─ JetBrains Qodana (Spring 설정 검사 포함)
├─ CI/CD 통합 + 대시보드 필요
│   └─ SonarQube/SonarCloud
├─ 빠른 로컬 분석
│   └─ SpotBugs + PMD + Checkstyle
└─ 보안 중심
    └─ Snyk + OWASP Dependency-Check
```

## SonarQube Integration

### Gradle 설정

```groovy
plugins {
    id 'org.sonarqube' version '5.0.0.4638'
}

sonar {
    properties {
        property 'sonar.projectKey', 'my-project'
        property 'sonar.host.url', 'https://sonarqube.company.com'
        property 'sonar.coverage.jacoco.xmlReportPaths',
                 'build/reports/jacoco/test/jacocoTestReport.xml'
        property 'sonar.java.source', '21'
    }
}
```

### CI 파이프라인

```yaml
# GitHub Actions
- name: SonarQube Scan
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  run: ./gradlew sonar
```

## Qodana (JetBrains)

### 로컬 실행

```bash
# Docker로 실행
docker run --rm -v $(pwd):/data/project \
  -v $(pwd)/qodana:/data/results \
  jetbrains/qodana-jvm:latest

# CLI로 실행
qodana scan --ide QDKOT  # Kotlin 포함
```

### CI 통합

```yaml
# GitHub Actions
- name: Qodana Scan
  uses: JetBrains/qodana-action@v2024.3
  with:
    args: --baseline,qodana.sarif.json
```

### Spring 특화 검사

Qodana가 감지하는 Spring 이슈:
- Deprecated 설정 키 사용
- 잘못된 property 값
- Bean 순환 의존성
- 누락된 @Transactional

## SpotBugs + PMD 조합

### Gradle 설정

```groovy
plugins {
    id 'com.github.spotbugs' version '6.0.7'
    id 'pmd'
}

spotbugs {
    toolVersion = '4.8.3'
    effort = 'max'
    reportLevel = 'medium'
}

pmd {
    toolVersion = '7.0.0'
    ruleSetFiles = files('config/pmd/ruleset.xml')
    ruleSets = []
}
```

## Checklist

### Code Quality
- [ ] Cognitive Complexity 15 이하
- [ ] 메서드 라인 수 50 이하
- [ ] 중복 코드 없음 (DRY)
- [ ] 사용되지 않는 코드 없음

### Bug Prevention
- [ ] Null 체크 적절히 수행
- [ ] Resource leak 없음 (try-with-resources)
- [ ] 잠재적 NPE 없음
- [ ] equals/hashCode 일관성

### Security (OWASP)
- [ ] SQL Injection 취약점 없음
- [ ] XSS 취약점 없음
- [ ] 하드코딩된 credential 없음
- [ ] 안전하지 않은 랜덤 사용 없음

### Spring Specific
- [ ] @Autowired field injection 없음
- [ ] @Transactional 적절한 사용
- [ ] Property 설정 오류 없음
- [ ] Bean 순환 의존성 없음

### Dependency Security
- [ ] 알려진 취약점 있는 의존성 없음 (CVE)
- [ ] outdated 의존성 업데이트
- [ ] 라이선스 호환성 확인

## Output Format

```
=== Static Analysis Report ===

[BLOCKER] SecurityHotspot - SQL Injection 가능성
  UserRepository.java:45
  String query = "SELECT * FROM users WHERE name = '" + name + "'";
  Fix: JPA Named Parameter 또는 Criteria API 사용

[CRITICAL] Bug - Potential NPE
  OrderService.java:78
  order.getCustomer().getAddress().getCity()
  Fix: Optional 또는 null 체크 추가

[MAJOR] Code Smell - Field Injection
  PaymentService.java:12
  @Autowired private PaymentGateway gateway;
  Fix: Constructor Injection 사용

[MINOR] Code Smell - Magic Number
  PricingService.java:34
  return price * 1.1;
  Fix: 상수로 추출 (TAX_RATE = 0.1)

Summary: 1 Blocker, 1 Critical, 5 Major, 12 Minor
```

## Usage

```
/java lint                    # 전체 프로젝트 분석
/java lint src/main/java/     # 특정 디렉토리 분석
/java lint --security         # 보안 이슈만 검사
/java lint --sonar            # SonarQube 규칙으로 검사
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| SonarQube 연결 실패 | 토큰/URL 오류 | SONAR_TOKEN 환경변수 확인 |
| 커버리지 0% 표시 | JaCoCo 리포트 경로 | `sonar.coverage.jacoco.xmlReportPaths` 확인 |
| SpotBugs OOM | 힙 부족 | `-Xmx2g` JVM 옵션 추가 |
| False Positive 과다 | 규칙 설정 | `.spotbugs-exclude.xml`로 제외 |
| Qodana 느림 | 전체 스캔 | baseline 설정으로 변경분만 검사 |

## Quality Gate Example

```yaml
# SonarQube Quality Gate
conditions:
  - metric: new_reliability_rating
    op: GT
    error: 1       # A rating 필수
  - metric: new_security_rating
    op: GT
    error: 1       # A rating 필수
  - metric: new_coverage
    op: LT
    error: 80      # 80% 이상
  - metric: new_duplicated_lines_density
    op: GT
    error: 3       # 3% 이하
```

## References

- [SonarQube Java Rules](https://rules.sonarsource.com/java/)
- [Qodana Spring Analysis](https://blog.jetbrains.com/qodana/2024/06/static-code-analysis-for-spring-run-analysis-fix-critical-errors-hit-the-beach/)
- [SpotBugs Docs](https://spotbugs.readthedocs.io/)
