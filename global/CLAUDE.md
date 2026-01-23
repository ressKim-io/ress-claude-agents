# Global Claude Code Settings

이 설정은 모든 프로젝트에 공통으로 적용됩니다.

## Language

- 기본 응답 언어: 한국어
- 코드 주석: 영어 (국제 협업 기준)
- 커밋 메시지: 영어

## Code Style

### General
- 명확하고 읽기 쉬운 코드 우선
- 과도한 추상화 지양
- 필요한 경우에만 주석 작성

### Naming
- 변수/함수: 의미를 명확히 전달
- 약어 최소화 (일반적으로 통용되는 것 제외)

## Git Conventions

### Commit Message Format
```
<type>(<scope>): <subject>

<body>
```

Types: feat, fix, docs, style, refactor, test, chore

### Branch Naming
- feature/: 새 기능
- fix/: 버그 수정
- refactor/: 리팩토링
- docs/: 문서 작업

## Security

- 민감 정보(API 키, 비밀번호 등)는 절대 코드에 하드코딩 금지
- 환경변수 또는 시크릿 매니저 사용
- .env 파일은 .gitignore에 포함

## Documentation

- 새로운 기능/API는 사용법 문서화
- 복잡한 비즈니스 로직은 주석으로 의도 설명
- README는 프로젝트 시작에 필요한 정보 포함

---

*프로젝트별 상세 규칙은 각 프로젝트 루트의 CLAUDE.md에서 정의*
