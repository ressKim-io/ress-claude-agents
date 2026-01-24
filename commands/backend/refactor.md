# Code Refactoring Assistant

코드 품질 개선을 위한 리팩토링을 제안하고 수행합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 클래스 또는 파일 경로 |
| Output | 리팩토링 제안 및 수정된 코드 |
| Required Tools | - |
| Verification | 테스트 통과, 기능 동일 |

## Code Smells to Detect

### Method Level
- **Long Method**: 30줄 초과 → 메서드 추출
- **Long Parameter List**: 4개 초과 → 파라미터 객체
- **Duplicate Code**: → 메서드 추출

### Class Level
- **Large Class**: → 클래스 분리
- **Feature Envy**: → 메서드 이동
- **Primitive Obsession**: → 값 객체 도입

## Refactoring Patterns

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

## Safety Checks

Before:
- [ ] 기존 테스트 통과

After:
- [ ] 모든 테스트 통과
- [ ] 동작 변경 없음

## Usage

```
/refactor UserService    # 클래스 분석
/refactor src/main/...   # 파일 분석
/refactor --apply        # 리팩토링 적용
```
