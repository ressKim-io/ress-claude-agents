# Spec-Driven Development

명세 기반 개발 방법론 가이드 — PRD, SDD, Design Doc, Shape Up, RFC/ADR 비교 및 실전 활용

## Quick Reference (결정 트리)

```
어떤 계획 방법론이 필요한가?
    │
    ├─ 제품 요구사항 정의 ──────────> PRD (Product Requirements Document)
    │       │
    │       └─ PM/PO가 비즈니스 요구사항과 사용자 스토리 정리
    │
    ├─ 기술 설계 + 구현 계획 ──────> SDD (Spec-Driven Development)
    │       │
    │       └─ Specify → Plan → Tasks → Implement 4단계
    │
    ├─ 아키텍처 결정 기록 ─────────> RFC / ADR
    │       │
    │       └─ 상세: dx/rfc-adr.md 참고
    │
    ├─ 시스템 설계 합의 ───────────> Design Doc (Google Style)
    │       │
    │       └─ 대안 비교, Cross-cutting concerns, 리뷰 기반 합의
    │
    ├─ 시간 제한 기반 기능 개발 ───> Shape Up (Basecamp)
    │       │
    │       └─ 6주 사이클: Shaping → Betting → Building → Cool-down
    │
    └─ 테스트로 요구사항 명세 ─────> TDD / BDD
            │
            └─ 상세: rules/testing.md 참고
```

---

## 방법론 비교표

| 항목 | PRD | SDD | RFC/ADR | Design Doc | Shape Up |
|------|-----|-----|---------|------------|----------|
| **목적** | 제품 요구사항 정의 | 명세 기반 구현 계획 | 기술 결정 기록/합의 | 시스템 설계 합의 | 시간 제한 기능 개발 |
| **작성자** | PM / PO | 테크리드 / 개발자 | 설계 리더 | 엔지니어 | 시니어 / PM |
| **분량** | 3~10페이지 | 2~5페이지 | 1~15페이지 | 5~15페이지 | 1~5페이지 (Pitch) |
| **적합한 상황** | 신규 제품/기능 기획 | 중규모 기능 구현 | 아키텍처 변경 결정 | 복잡한 시스템 설계 | 제한된 일정 내 배포 |
| **산출물** | 요구사항 문서 | Spec + Task 목록 | ADR 기록 | 설계 문서 | Pitch + Hill Chart |
| **리뷰 방식** | 이해관계자 승인 | 개발팀 내 합의 | 비동기 리뷰 + 미팅 | 비동기 리뷰 | Betting Table |
| **변경 관리** | 버전 관리 | Phase Gate 검증 | Supersede (새 ADR) | 문서 업데이트 | Scope Hammering |

### 조합 패턴

```
신규 제품 개발:     PRD → Design Doc → SDD → TDD
기존 서비스 개선:   SDD만으로 충분
아키텍처 변경:      RFC → ADR → Design Doc → SDD
스타트업 빠른 배포: Shape Up 또는 SDD (경량)
```

---

## Spec-Driven Development (SDD)

GitHub Spec Kit에서 영감을 받은 4단계 명세 기반 개발 프로세스.
코드 작성 전에 "무엇을, 왜, 어떻게" 구현할지 명확히 정의한다.

### 전체 흐름

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Specify  │───>│   Plan   │───>│  Tasks   │───>│Implement │
│ (무엇/왜)│    │ (어떻게)  │    │ (분해)   │    │ (구현)    │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │               │               │               │
     ▼               ▼               ▼               ▼
  문제 정의      기술 설계       작업 분해       점진적 구현
  성공 기준      의존성 분석     우선순위 결정    Phase Gate 검증
```

### Phase 1: Specify — 문제와 목표 정의

```markdown
# Spec: {기능명}

## Problem
해결하려는 문제를 구체적으로 기술한다.
- 현재 상태: ...
- 문제점: ...
- 영향 범위: ...

## Solution
제안하는 해결 방향을 기술한다.
- 접근 방식: ...
- 핵심 아이디어: ...

## Non-Goals
이 스펙에서 다루지 않는 것을 명시한다.
- ...

## Open Questions
아직 결정되지 않은 사항을 나열한다.
- [ ] Q1: ...
- [ ] Q2: ...

## Success Criteria
완료 기준을 측정 가능하게 정의한다.
- [ ] 기능적: ...
- [ ] 성능: 응답시간 < 200ms (P95)
- [ ] 품질: 테스트 커버리지 > 80%
```

**Phase Gate 1**: Open Questions가 모두 해결되었는가? Success Criteria가 측정 가능한가?

### Phase 2: Plan — 기술 설계

```markdown
## Technical Approach

### 아키텍처 변경
- 변경할 컴포넌트: ...
- 신규 컴포넌트: ...
- 삭제할 컴포넌트: ...

### API 설계 (해당 시)
- 엔드포인트: ...
- 요청/응답 스키마: ...

### 데이터 모델 (해당 시)
- 테이블/컬렉션 변경: ...
- 마이그레이션 전략: ...

### 의존성 분석
- 내부 의존성: 영향받는 모듈/서비스
- 외부 의존성: 신규 라이브러리, 외부 API
- Breaking Changes: 하위 호환성 영향
```

**Phase Gate 2**: 기술적으로 구현 가능한가? 의존성이 모두 파악되었는가?

### Phase 3: Tasks — 작업 분해

```markdown
## Task Breakdown

### Phase A: 기반 작업 (P0 - 필수)
- [ ] Task 1: ... [S]
- [ ] Task 2: ... [M]

### Phase B: 핵심 구현 (P0 - 필수)
- [ ] Task 3: ... [M]
- [ ] Task 4: ... [L]

### Phase C: 마무리 (P1 - 권장)
- [ ] Task 5: ... [S]
- [ ] Task 6: ... [S]

## 사이즈 기준
- [S] Small: 2시간 이내, 단일 파일/모듈
- [M] Medium: 반나절, 2~3개 파일
- [L] Large: 하루, 여러 모듈 — L 초과 시 분할 필수

## 의존 관계
Task 3 → Task 1, 2 완료 후 시작
Task 5 → Task 4 완료 후 시작
```

**Phase Gate 3**: 모든 태스크가 L 이하인가? 의존 관계가 명확한가?

### Phase 4: Implement — 점진적 구현

```markdown
## 구현 진행

### Phase A 완료 체크
- [ ] Task 1, 2 구현 완료
- [ ] 단위 테스트 통과
- [ ] 코드 리뷰 완료

### Phase B 완료 체크
- [ ] Task 3, 4 구현 완료
- [ ] 통합 테스트 통과
- [ ] Success Criteria 중간 검증

### Phase C 완료 체크
- [ ] Task 5, 6 구현 완료
- [ ] 전체 테스트 통과
- [ ] Success Criteria 최종 검증
- [ ] 문서 업데이트
```

**Phase Gate 4**: Success Criteria를 모두 충족하는가?

---

## PRD (Product Requirements Document)

### 템플릿

```markdown
# PRD: {제품/기능명}

| 항목 | 내용 |
|------|------|
| 작성자 | @pm |
| 상태 | Draft / In Review / Approved |
| 대상 버전 | v2.1 |
| 작성일 | YYYY-MM-DD |

## Background
프로젝트 배경과 비즈니스 맥락을 기술한다.
- 비즈니스 목표: ...
- 대상 사용자: ...
- 현재 상태와 한계: ...

## User Stories

### Persona: {사용자 유형}
- US-1: {역할}로서 {행위}를 하여 {가치}를 얻고 싶다
- US-2: ...

### Persona: {사용자 유형 2}
- US-3: ...

## Functional Requirements

| ID | 요구사항 | 우선순위 | 관련 US |
|----|----------|---------|---------|
| FR-1 | ... | Must | US-1 |
| FR-2 | ... | Should | US-2 |
| FR-3 | ... | Could | US-3 |

### 우선순위 기준 (MoSCoW)
- **Must**: 없으면 출시 불가
- **Should**: 출시 가능하지만 중요
- **Could**: 있으면 좋음
- **Won't**: 이번에는 하지 않음

## Non-Functional Requirements

| ID | 항목 | 기준 |
|----|------|------|
| NFR-1 | 성능 | 응답시간 P95 < 200ms |
| NFR-2 | 가용성 | 99.9% uptime |
| NFR-3 | 보안 | OWASP Top 10 대응 |
| NFR-4 | 확장성 | 동시 사용자 10,000명 |

## Success Metrics

| 지표 | 현재 | 목표 | 측정 방법 |
|------|------|------|----------|
| 전환율 | 3% | 5% | GA 퍼널 분석 |
| 이탈률 | 40% | 25% | 세션 분석 |

## Out of Scope
- 이번 버전에서 다루지 않는 항목
```

---

## Design Doc (Google Style)

### 템플릿

```markdown
# Design Doc: {제목}

| 항목 | 내용 |
|------|------|
| 작성자 | @engineer |
| 상태 | Draft / Reviewing / Approved / Obsolete |
| 리뷰어 | @reviewer1, @reviewer2 |
| 최종 수정 | YYYY-MM-DD |

## Context
현재 시스템 상태와 이 설계가 필요한 배경.

## Goals
- 이 설계로 달성하려는 것

## Non-Goals
- 이 설계에서 의도적으로 제외하는 것

## Design

### Overview
제안하는 설계 개요. 다이어그램 포함 권장.

### Detailed Design
구체적 구현 설계:
- 시스템 아키텍처
- API 인터페이스
- 데이터 모델
- 주요 알고리즘/로직

### Error Handling
장애 시나리오와 대응 방안.

## Alternatives Considered

### Alternative A: {이름}
- 장점: ...
- 단점: ...
- 미채택 이유: ...

### Alternative B: {이름}
- 장점: ...
- 단점: ...
- 미채택 이유: ...

## Cross-cutting Concerns
- **보안**: ...
- **성능**: ...
- **모니터링**: ...
- **비용**: ...
- **접근성**: ...

## Implementation Plan
| Phase | 내용 | 기간 |
|-------|------|------|
| 1 | ... | 1주 |
| 2 | ... | 2주 |
```

---

## Shape Up (Basecamp)

### 6주 사이클 개요

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌──────────┐
│  Shaping    │──>│  Betting    │──>│  Building   │──>│ Cool-down│
│  (비정형)   │   │  Table      │   │  (6주)      │   │  (2주)   │
└─────────────┘   └─────────────┘   └─────────────┘   └──────────┘
      │                 │                 │                 │
      ▼                 ▼                 ▼                 ▼
  문제 정의        우선순위 결정      자율 구현         기술 부채
  솔루션 스케치    Pitch 선택        Scope 조정        탐색/실험
  Appetite 설정    팀 배정           Hill Chart 추적   다음 사이클 준비
```

### Shaping (사전 정의)

시니어가 솔루션의 윤곽을 잡되, 구체적 구현은 팀에 맡긴다.

| 요소 | 설명 |
|------|------|
| **Problem** | 해결할 문제를 구체적으로 정의 |
| **Appetite** | 투자할 시간 — Small Batch (2주) 또는 Big Batch (6주) |
| **Solution** | 방향만 제시, 와이어프레임 수준 (Fat Marker Sketch) |
| **Rabbit Holes** | 피해야 할 복잡도 함정 |
| **No-Gos** | 명시적으로 하지 않을 것 |

### Betting Table

- 6주 동안 진행할 Pitch를 선택
- 선택되지 않은 Pitch는 자동 폐기 (백로그 없음)
- 판단 기준: 가치, 시급성, Appetite 적절성

### Building

- 팀이 자율적으로 Scope를 조정하며 구현
- **Scope Hammering**: 시간 내 완료를 위해 범위를 적극 축소
- **Hill Chart**: 진행 상황을 "올라가는 중 (불확실)" / "내려가는 중 (확실)" 으로 추적

```
Hill Chart:
        /\
       /  \
      /    \
 ────/──────\────
 불확실     확실
 (탐색)     (실행)
```

### Cool-down (2주)

- 기술 부채 해소, 버그 수정
- 자유 탐색, 프로토타이핑
- 다음 사이클 Shaping 시작

---

## Phase Gate 체크리스트

모든 방법론에 공통 적용할 수 있는 단계별 검증 항목.

### Gate 1: 문제 정의 완료

```markdown
- [ ] 문제가 구체적이고 측정 가능하게 정의됨
- [ ] 대상 사용자/이해관계자가 명확함
- [ ] 해결하지 않을 때의 영향(비용)이 기술됨
- [ ] Non-Goals가 명시됨
```

### Gate 2: 설계 완료

```markdown
- [ ] 기술적 접근 방식이 결정됨
- [ ] 최소 2개 대안이 검토됨
- [ ] 의존성과 영향 범위가 파악됨
- [ ] 보안, 성능, 비용 관점이 검토됨
- [ ] Open Questions가 모두 해결됨
```

### Gate 3: 구현 준비 완료

```markdown
- [ ] 태스크가 실행 가능한 단위로 분해됨
- [ ] 각 태스크 사이즈가 하루 이내
- [ ] 의존 관계와 실행 순서가 정의됨
- [ ] 테스트 전략이 수립됨
- [ ] 롤백 계획이 있음 (해당 시)
```

### Gate 4: 구현 완료

```markdown
- [ ] 모든 Success Criteria 충족
- [ ] 테스트 통과 (단위 + 통합)
- [ ] 코드 리뷰 완료
- [ ] 문서 업데이트 완료
- [ ] 배포 준비 상태 확인
```

---

## 방법론 선택 가이드

| 상황 | 권장 방법론 | 이유 |
|------|------------|------|
| 신규 제품 기획 단계 | PRD | 비즈니스 요구사항 체계화 |
| 중규모 기능 개발 (1~4주) | SDD | 명세부터 구현까지 일관된 프로세스 |
| 대규모 시스템 설계 | Design Doc + RFC | 합의 + 결정 기록 |
| 빠른 반복 개발 | Shape Up | 시간 제한 + Scope 조정 |
| 기술 스택 변경 | RFC → ADR | 결정 근거 보존 |
| 요구사항이 불명확 | Shape Up Shaping | 탐색 후 Appetite 설정 |
| 버그 수정/소규모 개선 | 불필요 | 이슈 트래커 + PR로 충분 |

---

## Anti-Patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| Spec 없이 바로 코딩 | 요구사항 누락, 재작업 발생 | 최소한 SDD Phase 1 작성 |
| 과도한 문서화 | 문서 작성이 목적화, 속도 저하 | Appetite에 맞는 방법론 선택 |
| Phase Gate 무시 | 불완전한 상태로 다음 단계 진입 | 체크리스트 기반 검증 |
| 한 문서에 모든 것 | PRD + 설계 + 태스크 혼재 | 목적별 문서 분리 |
| 문서 작성 후 방치 | 구현과 문서 괴리 | 구현 완료 시 문서 최종 업데이트 |
| Success Criteria 없음 | "완료" 기준 모호 | 측정 가능한 기준 필수 정의 |

---

## Sources

- GitHub Spec Kit: Specify → Plan → Tasks → Implement workflow
- Google "Design Docs at Google" (Industrial Empathy)
- Basecamp "Shape Up" (Ryan Singer)
- MoSCoW Prioritization (DSDM)

**관련 skill**: `dx/rfc-adr.md` (RFC/ADR 상세), `rules/testing.md` (TDD/BDD 상세)
