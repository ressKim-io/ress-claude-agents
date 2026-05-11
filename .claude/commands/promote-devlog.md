---
description: "Tier 2 dev-log를 ADR/skill로 승격 (Episodic → Semantic). 패턴 정착 시 사용."
---

# /promote-devlog

dev-log (episodic memory)를 **ADR 또는 skill (semantic memory)** 로 승격한다. 학계 패턴 "Episodic → Semantic" 동형.

`/consolidate-devlogs`가 클러스터 (3건+)를 발견하면 이 커맨드로 정착시킨다.

## 입력

`$ARGUMENTS` — 승격 대상

옵션:
- 단일 dev-log slug: `2026-04-25-otel-spec-compliance-fixes`
- 클러스터 키워드: `otel` (3건+ 클러스터 자동 통합)

## 승격 경로 (3가지)

| 패턴 | 산출물 | 위치 |
|------|--------|------|
| **결정·트레이드오프 패턴** (decision 카테고리) | ADR | `docs/adr/NNNN-제목.md` |
| **반복 절차 패턴** (troubleshoot/migration 카테고리) | skill | `.claude/skills/{도메인}/{이름}.md` |
| **인프라 표준 패턴** | architecture 문서 | `docs/architecture/주제.md` |

## 실행 절차

### 1. 대상 식별

- 단일 slug → 해당 dev-log + frontmatter `related` 링크 수집
- 클러스터 키워드 → `/consolidate-devlogs` 결과의 같은 그룹 dev-logs 묶음

### 2. 승격 경로 추천

frontmatter `category` 와 본문 키워드로 자동 분기:
- `category: decision` → ADR 권장
- `category: troubleshoot` + 동일 패턴 3건+ → skill 권장
- `category: migration` + 정착된 절차 → skill 또는 architecture
- 본문에 "선택", "vs", "트레이드오프" → ADR

### 3. 산출물 초안 생성

#### ADR 산출물 양식

```yaml
---
date: YYYY-MM-DD
status: Proposed | Accepted
supersedes: []
related:
  - dev-logs/...md   # 원본 episodic
---

# ADR-NNNN: 제목

## Context
{원본 dev-logs에서 합성한 배경}

## Decision
{결정 내용}

## Consequences
- 긍정: ...
- 부정: ...

## Alternatives Considered
- A: ...
- B: ...

## References
- dev-logs/2026-MM-DD-...md (원본)
```

#### skill 산출물 양식

```markdown
---
description: "{한 줄 요약}"
---

# {도메인}/{이름}

## When to use
{언제 적용하는지}

## Steps
1. ...
2. ...

## Pitfalls
- {함정 사례 — 원본 dev-logs에서 추출}

## References
- dev-logs/2026-MM-DD-...md
```

### 4. 사용자 승인 대기

초안을 사용자에게 표시하고 다음 중 선택:
- **승인**: 산출물 생성 + 원본 dev-logs `replaced_by` 추가 + frontmatter `tier` 갱신
- **수정 요청**: 사용자 피드백 반영 후 재생성
- **취소**: 변경 없이 종료

### 5. 승인 시 적용

```
1. 산출물 파일 생성 (ADR 번호는 docs/adr/ 다음 번호 자동 할당)
2. 원본 dev-logs 각각에 frontmatter 추가:
   - replaced_by: adr/NNNN-...md  (또는 .claude/skills/...)
   - status: superseded (선택, 사용자 확인)
3. INDEX 갱신:
   - docs/adr/INDEX.md 또는 _CATALOG.md (있다면)
   - docs/dev-logs/INDEX-by-topic.md (있다면)
4. 관련 자산 forward link 추가:
   - 메모리 (관련 project_*) 본문 갱신 권장
   - repo-card hotspot 갱신 권장
```

### 6. 후속 권장

승격 후 자동 권장:
- 기존 `replaced_by` 처리된 dev-logs는 `/archive-devlog` 후보 (Tier 4)
- ADR 채택되면 `status: Accepted` 갱신
- skill 추가되면 관련 rules에서 cross-reference 권장

## 안전 장치

- 단일 dev-log 승격은 신중 — 패턴 정착이 아니라면 거절 권장
  - 해당 dev-log가 `importance: critical` 이고 단독 ADR 가치 명확할 때만 허용
- 클러스터 승격 시 원본 dev-logs는 **삭제하지 않음** — `replaced_by` 메타만 추가, 본문 보존
- ADR 번호 충돌 검사 (`docs/adr/` 최대 번호 +1)
- 사용자 승인 없이 ADR/skill 자동 생성 절대 안 함

## 인자

`$ARGUMENTS`:
- `<slug>`: 단일 dev-log
- `<keyword>`: 클러스터 자동 묶음
- `--dry-run` (기본): 초안만 출력
- `--apply`: 승인 가정 (사용자 확인 시 사용)
- `--target adr|skill|arch`: 승격 경로 강제 지정

## 사용 예시

```
/promote-devlog otel
→ otel 클러스터 (3건) 발견
→ skill 산출물 추천: .claude/skills/observability/otel-spec-compliance.md
→ 초안 표시
→ 사용자 승인 대기
```

```
/promote-devlog 2026-04-21-decision-cross-cloud-db-promote-automation
→ category: decision 감지
→ ADR 산출물 추천: docs/adr/0017-cross-cloud-db-promote-automation.md
→ 초안 표시
→ 사용자 승인 대기
```

## 학계 근거

- **Episodic → Semantic 변환**: 개별 사건 (dev-log) → 일반화된 지식 (ADR/skill)
- **Sleep-time consolidation**: `/consolidate-devlogs` (탐지) + `/promote-devlog` (정착) 2단계
- 출처: `docs/dev-logs/2026-04-29-devlog-tier-policy.md` 끝 섹션

오늘 날짜: $CURRENT_DATE
