# Session Context Management

긴 작업 시 auto compact로 인한 컨텍스트 손실을 방지합니다.

## 문제 상황

Claude Code에서 긴 작업 수행 시:
1. 컨텍스트가 가득 차면 auto compact 발생
2. 초기 설정, 테스트 환경 정보 등이 손실
3. 반복적으로 같은 정보를 다시 설명해야 함

## 해결 방법

### 자동 관리 (권장)

다음 상황에서 `.claude/session-context.md` 자동 생성:
- TodoWrite로 3개 이상 태스크 생성 시
- MCP 서버나 테스트 환경 설정 언급 시
- 멀티스텝 복잡한 작업 시작 시
- "이거 기억해", "설정 저장해" 등 요청 시

자동 삭제:
- 모든 태스크 완료 시
- "작업 끝", "완료" 명시적 종료 시

### 수동 명령어

| 명령어 | 설명 |
|--------|------|
| `/session save` | 현재 컨텍스트 강제 저장 |
| `/session save "메모"` | 추가 메모와 함께 저장 |
| `/session end` | 세션 종료 및 파일 정리 |
| `/session end --keep` | 파일 유지 (백업용) |

## 저장되는 내용

```markdown
# Session Context
> Auto-generated: 2024-01-15 14:30

## 현재 작업
- 보드 생성 기능 개발

## 환경 설정
- Chrome MCP로 테스트 중
- API: https://api.example.com

## 진행 상황
- [x] API 설계
- [ ] 프론트엔드 구현
- [ ] 테스트

## 중요 결정사항
- 인증: OAuth2 사용
- DB: PostgreSQL
```

## 사용 예시

```
# 긴 작업 시작
"Chrome MCP로 보드 생성 기능 테스트할거야"
→ Claude가 자동으로 session-context.md 생성

# 중간에 중요한 결정
"인증은 OAuth2로 하자"
→ 결정사항 자동 업데이트

# auto compact 발생해도
→ session-context.md 읽고 컨텍스트 복구

# 작업 완료
"다 끝났어"
→ 파일 자동 삭제
```
