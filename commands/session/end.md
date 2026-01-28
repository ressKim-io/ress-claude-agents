# Session Context End

세션을 종료하고 컨텍스트 파일을 정리합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 종료 요청 |
| Output | 세션 정리 완료 |
| Required Tools | Bash, Read |
| Verification | session-context.md 삭제됨 |

## Checklist

### 실행 단계
1. `.claude/session-context.md` 존재 확인
2. 내용 요약 출력 (작업 완료 리포트)
3. 파일 삭제
4. TodoWrite 태스크 정리 (있는 경우)

### 완료 리포트 형식
```
## 세션 완료 리포트

### 작업 요약
- [완료된 작업 목록]

### 변경된 파일
- [파일 목록]

### 다음 작업 (있는 경우)
- [후속 작업]
```

## Output Format

세션 완료 리포트

## Usage

```
/session end
/session end --keep    # 파일 유지 (백업용)
```
