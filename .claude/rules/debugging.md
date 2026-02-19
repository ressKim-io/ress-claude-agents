# Debugging Rules

디버깅 및 문제 해결 시 반드시 따라야 할 프로토콜.
원인 파악 없이 코드를 수정하는 행위는 절대 허용되지 않는다.

---

## 디버깅 프로토콜 (MANDATORY)

### 1. REPRODUCE — 문제 재현

- 에러 메시지와 stack trace를 정확히 읽는다.
- 재현 조건을 파악한다: 어떤 입력, 어떤 상태에서 발생하는가?
- 재현이 불가능하면 원인 파악 단계로 넘어가지 않는다.
- 재현 케이스를 최소화한다 (minimal reproducible example).

### 2. DIAGNOSE — 원인 파악

- 에러 발생 지점과 호출 경로의 관련 코드를 읽는다.
- 필요 시 로그를 추가하여 런타임 상태를 확인한다.
- 가설을 수립하고 검증하는 사이클을 반복한다.
  - 가설 → 확인 → 기각 또는 수용 → 다음 가설
- 하나의 가설을 검증하기 전에 코드를 수정하지 않는다.

### 3. ROOT CAUSE — 근본 원인 확인

- 증상(symptom)이 아닌 원인(cause)을 찾는다.
- "왜 이 코드가 이렇게 동작하는가?"를 반복해서 질문한다.
- 근본 원인이 확인되기 전까지 수정 단계로 넘어가지 않는다.

### 4. FIX — 수정 및 검증

- 근본 원인에 대한 수정만 적용한다.
- 테스트를 실행하여 수정이 문제를 해결했는지 확인한다.
- 수정으로 인한 regression이 없는지 점검한다.
- 동일한 버그가 재발하지 않도록 회귀 테스트를 추가한다.

---

## 금지 사항

**원인 확인 전 추측으로 코드 수정 금지**
"아마 이 부분이 문제일 것이다"는 근거가 아니다.
로그, 스택트레이스, 코드 분석으로 원인을 확인한 후 수정하라.

**에러 suppress/무시하는 코드 금지**
```java
// 금지: 에러를 삼키는 코드
try { ... } catch (Exception e) { /* ignored */ }

// 허용: 에러를 로깅하고 적절히 처리
try { ... } catch (Exception e) {
    log.error("context={}, error={}", ctx, e.getMessage(), e);
    throw new DomainException("원인 설명", e);
}
```

**임시 수정(workaround) 금지**
"일단 이렇게 하면 될 수도 있다"는 근본 원인을 숨길 뿐이다.
임시 수정이 불가피할 경우 TODO와 원인 분석 결과를 반드시 주석으로 남긴다.

**여러 문제를 동시에 수정하지 않음**
하나의 버그를 수정하고, 테스트로 검증한 후 다음 버그로 넘어간다.

---

## 에러 유형별 분석 패턴

```
NullPointer / nil dereference
  - null이 최초로 주입된 지점을 역추적한다.
  - Optional/포인터 반환 메서드의 결과를 확인하지 않고 사용한 곳을 찾는다.

Timeout
  - 어떤 호출이 느린지 확인한다 (DB 쿼리, 외부 API, 잠금 경합).
  - timeout 설정값과 실제 응답 시간을 비교한다.
  - slow query log, trace를 활용한다.

Race Condition
  - 공유 상태에 대한 동시 접근 패턴을 확인한다.
  - lock 범위와 atomic 연산 여부를 검토한다.
  - 재현이 어려우면 race detector(go -race, ThreadSanitizer)를 활용한다.

OOM (Out of Memory)
  - 메모리 사용량을 프로파일링한다 (heap dump, pprof).
  - 컬렉션/스트림의 크기를 제한 없이 누적하는 코드를 찾는다.
  - 메모리 누수(leak) 여부를 확인한다.
```

---

## 로깅 원칙

에러 발생 시 원본 에러와 컨텍스트를 함께 로깅하라:

```java
// 원본 에러(cause)를 반드시 포함
log.error("주문 처리 실패: orderId={}, userId={}", orderId, userId, e);
```

구조화된 로깅을 사용하라 (key=value 또는 JSON):
```
// 권장: key=value 구조
level=error msg="payment failed" orderId=123 amount=5000 err="timeout"
```

적절한 로그 레벨을 사용하라:
```
ERROR  시스템이 복구 불가능한 상태, 즉각 대응 필요
WARN   잠재적 문제, 모니터링 필요
INFO   주요 비즈니스 이벤트 (요청 시작/완료, 상태 전이)
DEBUG  개발/진단용 상세 정보, 프로덕션에서는 비활성화
```

민감 정보(비밀번호, 토큰, 개인정보)는 로그에 절대 포함하지 않는다.
