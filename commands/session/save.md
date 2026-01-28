# Session Context Save

현재 세션 컨텍스트를 강제 저장합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 현재 대화 컨텍스트 |
| Output | `.claude/session-context.md` 파일 |
| Required Tools | Write |
| Verification | 파일 존재 확인 |

## Checklist

### 저장 항목
- [ ] 현재 작업 목표
- [ ] 환경 설정 (MCP 서버, API 키 위치 등)
- [ ] 진행 상황 (완료/진행중/대기)
- [ ] 중요 결정사항
- [ ] 참고 URL/문서

### 실행 단계
1. `.claude/` 디렉토리 확인 (없으면 생성)
2. `session-context.md` 파일 생성/업데이트

### 파일 템플릿
```markdown
# Session Context
> Auto-generated: {timestamp}

## 현재 작업
-

## 환경 설정
-

## 진행 상황
- [ ]

## 중요 결정사항
-

## 참고
-
```

## Output Format

`.claude/session-context.md` 파일

## Usage

```
/session save
/session save "추가 메모"
```
