# Backend Code Review

변경된 코드를 리뷰하고 개선점을 제안합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Git diff 또는 특정 파일 |
| Output | 이슈 목록 (심각도별 분류) |
| Required Tools | git |
| Verification | 모든 Critical 이슈 해결 |

## Review Checklist

### Security (Critical)
- [ ] SQL Injection: native query 파라미터 바인딩
- [ ] XSS: 사용자 입력 검증
- [ ] 인증/인가 누락
- [ ] 민감 정보 하드코딩

### Performance (High)
- [ ] N+1 쿼리: fetch join 사용
- [ ] 불필요한 데이터 조회
- [ ] 페이징 누락
- [ ] 캐싱 미적용

### Error Handling (Medium)
- [ ] 예외 처리 누락
- [ ] 부적절한 예외 타입
- [ ] 로깅 부족
- [ ] 에러 응답 불일치

### Code Quality (Low)
- [ ] 네이밍 컨벤션
- [ ] 중복 코드
- [ ] 긴 메서드 (30줄 초과)

## Output Format

```markdown
## Code Review Summary

### Critical Issues
- [파일:라인] 이슈 설명
  제안: 수정 방법
```

## Usage

```
/review                # 모든 변경 리뷰
/review src/main/...   # 특정 파일
```
