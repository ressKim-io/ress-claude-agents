---
description: "Phase 기반 작업(SDD 게이트 강제) 시작. 11항목 체크리스트 출력 + Gate 1-5 흐름 안내."
---

# /phase-start

대규모 작업(6개 이상 파일 변경 / API 3개 이상 / 시스템 마이그레이션)을 시작할 때 `.claude/rules/phase-workflow.md`의 Gate 1-5를 강제하는 진입점.

`/phase-start`로 시작하지 않은 작업은 `.claude/rules/workflow.md`의 일반 작업 순서(EXPLORE → PLAN → IMPLEMENT → VERIFY → COMMIT)를 따른다.

## 입력

`$ARGUMENTS` — phase 이름 또는 번호

옵션:
- 단일 이름: `auth-refactor`
- 번호 + 슬러그: `phase-3-multitenancy`
- 생략: 현재 작업 컨텍스트에서 추론 (사용자 확인 필요)

## 적용 대상 (rules/phase-workflow.md §"적용 대상")

다음 중 하나 이상에 해당하면 `/phase-start` 사용:

- 새 서비스/모듈 구현 (6개 이상 파일 변경 예상)
- 기존 서비스 대규모 변경 (API 추가/변경 3개 이상)
- 시스템 마이그레이션 (언어 전환, 아키텍처 변경)

소규모 작업(버그 수정, 문서 수정, 설정 변경)은 사용하지 않는다.

## 실행 절차

### 1. Phase 컨텍스트 확정

`$ARGUMENTS`로 phase 이름/번호를 받아 다음을 확정:
- SDD 파일 경로: `docs/sdd-<phase-slug>.md` (path-scoped rule trigger와 일치)
- Phase 시작 일자: 오늘 날짜 ($CURRENT_DATE)
- 영향 범위 추정: 사용자에게 "변경 예상 파일 수", "API 변경 개수", "마이그레이션 여부" 확인

### 2. SDD 작성 안내 (Gate 1)

```
SDD 파일을 다음 위치에 작성하십시오:
  docs/sdd-<phase-slug>.md

템플릿: .claude/templates/sdd.md.template

SDD 필수 섹션:
  - Background (왜 이 작업이 필요한가)
  - Requirements (수락 기준)
  - Design (API / 데이터 모델)
  - Implementation Steps (Step별 의존성 명시)
  - Test Strategy (단위 + 통합)
  - Phase Gates (어느 Gate가 끝났는지 추적)
  - Risks (예상되는 함정)
```

SDD 작성 완료 전 구현 코드 작성 금지.

### 3. 체크리스트 출력

```
Phase: <phase-slug>
시작일: $CURRENT_DATE

[ ] Gate 1: SDD 작성 완료 (docs/sdd-<phase-slug>.md)
[ ] Gate 2: SDD 리뷰 완료 (code-reviewer 에이전트 + 피드백 반영)
[ ] Gate 3: SDD 기반 코드 구현 (Step별 순차)
[ ] Gate 3: 코드/보안 리뷰 실행 + 피드백 반영
[ ] Gate 4: 테스트 코드 작성 + 전체 통과 (단위 + 통합)
[ ] Gate 5: PR 생성
[ ] Gate 5: /review-pr 멀티 관점 리뷰
[ ] Gate 5: Gemini 리뷰 확인 + 갭 기록 (docs/review-gaps.md)
[ ] Gate 5: 피드백 반영 → push → merge
[ ] main pull
[ ] 트러블슈팅 로그 (/log-trouble) — 문제 발생 시
```

체크리스트는 SDD `## Phase Gates` 섹션에 복사하여 진행 상태를 추적한다.

### 4. Gate 위반 검출

Phase 진행 중 다음을 감지하면 작업을 중단하고 안내한다:

| 감지 상황 | 위반 Gate | 안내 |
|---------|----------|------|
| SDD 없이 구현 코드 작성 시도 | Gate 1 | "SDD를 먼저 작성하십시오" |
| SDD 리뷰 없이 구현 시작 | Gate 2 | "code-reviewer 에이전트로 SDD 리뷰 후 진행" |
| 코드 리뷰 없이 PR 생성 시도 | Gate 3 | "기술 스택 리뷰 커맨드 실행 (/go:review, /java:review 등)" |
| 테스트 미통과 상태 PR | Gate 4 | "테스트 실패 — PR 차단" |
| /review-pr 미실행 머지 시도 | Gate 5 | "/review-pr 실행 후 머지" |

### 5. 후속 권장

- Phase 종료 시 회고: `docs/retrospective/$CURRENT_DATE-<phase-slug>.md` 작성 권장
- Tier 2+ dev-log 누적 시 `/promote-devlog`로 ADR/skill 정착
- Phase 간 SDD가 dependency를 가지면 SDD frontmatter `depends_on:`로 명시

## 사용 예시

```
/phase-start auth-refactor
→ Phase: auth-refactor
→ 시작일: 2026-05-12
→ SDD 작성 안내: docs/sdd-auth-refactor.md
→ 11항목 체크리스트 출력
→ Gate 1 대기
```

```
/phase-start phase-3-multitenancy
→ Phase: phase-3-multitenancy
→ 시작일: 2026-05-12
→ SDD 작성 안내: docs/sdd-phase-3-multitenancy.md
→ 11항목 체크리스트 출력
→ Gate 1 대기
```

## 안전 장치

- `/phase-start`를 호출하지 않은 채 SDD 파일만 생성하면 path-scoped rule이 자동 로딩되지만 Gate 추적은 수동
- Phase 종료(merge) 후에도 SDD는 보존 (히스토리)
- 동시에 여러 Phase 진행 불가 — 1 Phase 1 PR 원칙

## 관련 파일

- Phase Gate 규칙: `.claude/rules/phase-workflow.md`
- SDD 템플릿: `.claude/templates/sdd.md.template`
- 일반 작업 순서: `.claude/rules/workflow.md`
- PR 리뷰: `/review-pr`

오늘 날짜: $CURRENT_DATE
