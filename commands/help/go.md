# Go Commands

Go 백엔드 개발을 위한 명령어입니다.

## 명령어

### `/go review`
Go 코드 리뷰를 수행합니다.

```
/go review              # 변경된 파일 리뷰
/go review main.go      # 특정 파일 리뷰
/go review ./pkg/...    # 패키지 리뷰
```

**검사 항목:**
- 에러 처리 패턴
- 고루틴/채널 사용
- 인터페이스 설계
- 테스트 가능성

---

### `/go test-gen`
테스트 코드를 생성합니다.

```
/go test-gen UserService        # 특정 구조체
/go test-gen ./internal/...     # 패키지
/go test-gen                    # 변경된 파일
```

**생성 패턴:**
- Table-driven tests
- Mock 인터페이스
- 서브테스트 구조

---

### `/go lint`
golangci-lint를 실행하고 문제를 수정합니다.

```
/go lint                # 전체 린트
/go lint --fix          # 자동 수정
/go lint ./pkg/...      # 특정 패키지
```

---

### `/go refactor`
리팩토링을 제안합니다.

```
/go refactor UserService    # 구조체 분석
/go refactor main.go        # 파일 분석
/go refactor --apply        # 리팩토링 적용
```

**검사 항목:**
- 함수 길이 (30줄 초과)
- 파라미터 수 (4개 초과)
- 중복 코드
- God struct

---

## Skills (상세 지식)

| 명령어 | 내용 |
|--------|------|
| `/go-errors` | 에러 처리 패턴 (wrapping, sentinel, custom) |
| `/go-gin` | Gin 프레임워크 (핸들러, 미들웨어, 라우팅) |
| `/go-testing` | 테스트 패턴 (table-driven, mock, testify) |

---

## Quick Reference

```bash
# 테스트
go test ./...
go test -v -cover ./...

# 린트
golangci-lint run

# 빌드
go build -v ./cmd/...
```
