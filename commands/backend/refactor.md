# Code Refactoring Assistant

코드 품질 개선을 위한 리팩토링을 제안하고 수행합니다.

## Instructions

1. 대상 코드를 분석합니다.
2. 코드 스멜과 개선 가능한 부분을 식별합니다.
3. 리팩토링 제안을 우선순위별로 정리합니다.
4. 사용자 승인 후 리팩토링을 수행합니다.

## Code Smells to Detect

### Method Level
- **Long Method**: 30줄 초과 메서드 → 메서드 추출
- **Long Parameter List**: 파라미터 4개 초과 → 파라미터 객체 도입
- **Duplicate Code**: 중복 코드 → 메서드 추출 또는 상속/합성
- **Complex Conditionals**: 복잡한 if/switch → 전략 패턴, 다형성

### Class Level
- **Large Class**: 너무 많은 책임 → 클래스 분리
- **Feature Envy**: 다른 클래스 데이터에 과도한 의존 → 메서드 이동
- **Data Class**: getter/setter만 있는 클래스 → 행위 추가 고려
- **Primitive Obsession**: 원시 타입 남용 → 값 객체 도입

### Architecture Level
- **Circular Dependency**: 순환 의존성 → 의존성 역전
- **God Class**: 모든 것을 아는 클래스 → 책임 분리
- **Lazy Class**: 하는 일이 없는 클래스 → 인라인 또는 제거

## Refactoring Patterns

### Extract Method
```java
// Before
public void processOrder(Order order) {
    // validate
    if (order.getItems().isEmpty()) throw new Exception();
    if (order.getCustomer() == null) throw new Exception();
    
    // calculate
    double total = 0;
    for (Item item : order.getItems()) {
        total += item.getPrice() * item.getQuantity();
    }
    // ... more code
}

// After
public void processOrder(Order order) {
    validateOrder(order);
    double total = calculateTotal(order);
    // ...
}

private void validateOrder(Order order) { ... }
private double calculateTotal(Order order) { ... }
```

### Introduce Parameter Object
```java
// Before
public List<User> searchUsers(String name, String email, int age, String city) { ... }

// After
public List<User> searchUsers(UserSearchCriteria criteria) { ... }
```

### Replace Conditional with Polymorphism
```java
// Before
public double calculateFee(String userType) {
    switch (userType) {
        case "BASIC": return 10.0;
        case "PREMIUM": return 5.0;
        case "VIP": return 0.0;
    }
}

// After
public interface FeePolicy {
    double calculateFee();
}
// BasicFeePolicy, PremiumFeePolicy, VipFeePolicy 구현
```

## Output Format

```markdown
## Refactoring Suggestions

### High Priority
1. **[파일:라인] Long Method**
   - 현재: 45줄 메서드
   - 제안: 3개 메서드로 분리
   - 이유: 가독성, 테스트 용이성

### Medium Priority
...

### 리팩토링 수행 여부
이 리팩토링을 수행할까요? (y/n)
```

## Safety Checks

리팩토링 전 확인:
- [ ] 기존 테스트가 모두 통과하는가?
- [ ] 변경 범위가 명확한가?
- [ ] 롤백 가능한가?

리팩토링 후 확인:
- [ ] 모든 테스트 통과
- [ ] 동작 변경 없음 확인
- [ ] 코드 커버리지 유지

## Usage

```
/refactor UserService           # 특정 클래스 분석
/refactor src/main/java/...     # 특정 파일 분석
/refactor --apply               # 제안된 리팩토링 적용
```
