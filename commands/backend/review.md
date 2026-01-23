# Backend Code Review

변경된 코드를 리뷰하고 개선점을 제안합니다.

## Instructions

1. 먼저 `git diff`로 변경된 파일을 확인합니다.
2. 변경된 각 파일을 읽고 분석합니다.
3. 아래 체크리스트에 따라 리뷰를 수행합니다.
4. 발견된 이슈를 심각도별로 분류하여 보고합니다.

## Review Checklist

### Security (Critical)
- [ ] SQL Injection 위험: native query에서 파라미터 바인딩 미사용
- [ ] XSS 취약점: 사용자 입력 미검증
- [ ] 인증/인가 누락: 엔드포인트 보안 미적용
- [ ] 민감 정보 노출: API 키, 비밀번호 하드코딩
- [ ] CSRF 보호 누락

### Performance (High)
- [ ] N+1 쿼리 문제: 연관 엔티티 조회 시 fetch join 미사용
- [ ] 불필요한 데이터 조회: SELECT * 또는 필요 이상의 필드 조회
- [ ] 페이징 누락: 대량 데이터 조회 시 페이징 미적용
- [ ] 캐싱 미적용: 반복 조회되는 데이터

### Error Handling (Medium)
- [ ] 예외 처리 누락: try-catch 없이 예외 발생 가능 코드
- [ ] 부적절한 예외 타입: 너무 일반적인 Exception 사용
- [ ] 로깅 부족: 에러 발생 시 컨텍스트 정보 미포함
- [ ] 에러 응답 불일치: API 에러 응답 형식 미통일

### Code Quality (Low)
- [ ] 네이밍 컨벤션 위반
- [ ] 중복 코드
- [ ] 너무 긴 메서드 (30줄 초과)
- [ ] 매직 넘버/문자열 사용
- [ ] 불필요한 주석

## Output Format

```markdown
## Code Review Summary

### Critical Issues (즉시 수정 필요)
- [파일:라인] 이슈 설명
  - 제안: 수정 방법

### High Priority (PR 머지 전 수정 권장)
- ...

### Medium Priority (개선 권장)
- ...

### Low Priority (향후 고려)
- ...

### Positive Feedback
- 잘된 점 언급
```

## Usage

```
/review                    # 모든 변경 파일 리뷰
/review src/main/java/...  # 특정 파일만 리뷰
```
