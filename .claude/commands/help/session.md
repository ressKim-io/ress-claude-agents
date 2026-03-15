# Session Commands

세션 컨텍스트 관리 명령어입니다.

## 명령어

| 명령어 | 설명 |
|--------|------|
| `/session save` | 현재 세션 컨텍스트 저장 |
| `/session end` | 세션 종료 및 파일 정리 |

## 자동 관리

- **자동 생성**: TodoWrite 3개 이상, MCP 설정 언급, 복잡한 작업 시작 시
- **자동 삭제**: 모든 태스크 완료, 명시적 종료 시
- **파일 위치**: `.claude/session-context.md`

## Quick Reference

```bash
/session save           # 강제 저장
/session save "메모"    # 메모와 함께 저장
/session end            # 세션 종료
/session end --keep     # 파일 유지 (백업용)
```
