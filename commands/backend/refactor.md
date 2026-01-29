# Code Refactoring Assistant

코드 품질 개선을 위한 리팩토링을 제안하고 수행합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 클래스 또는 파일 경로 |
| Output | 리팩토링 제안 및 수정된 코드 |
| Required Tools | - |
| Verification | 테스트 통과, 기능 동일 |

## Analysis Areas

### Method Level
- **Long Method**: 30줄 초과 -> 메서드 추출
- **Long Parameter List**: 4개 초과 -> 파라미터 객체
- **Duplicate Code**: -> 메서드 추출

### Class Level
- **Large Class**: -> 클래스 분리
- **Feature Envy**: -> 메서드 이동
- **Primitive Obsession**: -> 값 객체 도입

## Checklist

### Safety Checks
Before:
- [ ] 기존 테스트 통과

After:
- [ ] 모든 테스트 통과
- [ ] 동작 변경 없음

## Output Format

```markdown
## Refactoring Suggestions

### Code Smells Detected
- [파일:라인] 이슈 설명

### Suggested Changes
- Before: {원본 코드}
- After: {개선된 코드}
```

## Usage

```
/refactor UserService    # 클래스 분석
/refactor src/main/...   # 파일 분석
/refactor --apply        # 리팩토링 적용
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| 리팩토링 후 테스트 실패 | 동작 변경됨 | 작은 단위로 리팩토링, 각 단계마다 테스트 실행 |
| 순환 의존성 발생 | 클래스 분리 시 의존 방향 문제 | interface 도입으로 의존성 역전 |
| DI 컨테이너 에러 | Bean 정의 변경됨 | `@Component` 스캔 범위 및 Bean 이름 확인 |
| 트랜잭션 동작 변경 | 메서드 추출 시 `@Transactional` 전파 문제 | 같은 클래스 내 호출은 프록시 미작동, 별도 Bean으로 분리 |
| IDE 리팩토링 기능 오동작 | 리플렉션 사용 코드 | 수동으로 참조 확인 후 변경 |
| 성능 저하 | N+1 쿼리 발생 | 리팩토링 전후 쿼리 로그 비교 |

## Best Practices

### Extract Method
```java
// Before: 45줄 메서드
// After
validateOrder(order);
calculateTotal(order);
processPayment(order);
```

### Introduce Parameter Object
```java
// Before
searchUsers(name, email, age, city)
// After
searchUsers(UserSearchCriteria criteria)
```
