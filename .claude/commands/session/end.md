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

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| session-context.md 찾을 수 없음 | 파일 미생성 또는 삭제됨 | `/session save`로 먼저 생성 |
| 삭제 권한 에러 | 파일 권한 문제 | `chmod 644 .claude/session-context.md` |
| 완료 리포트 누락 | 파일 내용 비어있음 | 세션 중 `/session save`로 주기적 저장 |
| .claude 디렉토리 없음 | 디렉토리 미생성 | `mkdir -p .claude` 실행 |
| 작업 요약 부정확 | 컨텍스트 정보 부족 | 세션 중 주요 작업마다 save 실행 |
| Todo 정리 실패 | TodoWrite 권한 문제 | 수동으로 todo 목록 확인 및 정리 |
