---
description: "개념/주제로 dev-logs + ADR + memory + repo-cards를 timeline 순으로 묶어 반환. 컨텍스트 복원용."
---

# /related

특정 개념/주제와 관련된 자료를 **시간순 timeline 형태**로 모아 반환한다.

`/where` 가 "어디에?" 라면, `/related` 는 "어떻게 흘러왔지?" 답.

## 입력

`$ARGUMENTS` — 개념/주제 (예: "JWT migration", "GCP destroy", "PgBouncer 도입", "Java→Go")

## 출력 형식

```
[/related {topic} · {today}]

## Topic: {topic}

## TIMELINE (오래된 → 최신)

### 2026-MM-DD · {제목}
- type: dev-log | adr | memory | repo-card
- 경로: {path}
- 요약: {1~2줄}

### 2026-MM-DD · ...

## CURRENT STATE (지금 시점 정리)
- {topic}의 현재 상태를 모든 자료를 종합해 1~3 문단으로 요약
- 미해결 항목 / 진행 중 항목 / 완료 항목 명시

## NEXT (다음 가능 액션)
- 발견된 TODO / 미해결 / open 항목
- 유관 영역에서 시작 가능한 작업

## STALE WARNING
- timeline 마지막 항목이 60일 이상 전이면 "오래됨" 표시
- 진행 중 항목인데 갱신 없으면 "확인 필요" 표시
```

## 검색 대상

`/where` 와 동일하지만 **포함도** 우선 (정확도보다):
- dev-logs `docs/dev-logs/*.md` — 가장 중요
- ADR `docs/adr/*.md`
- memory `~/.claude/projects/{slug}/memory/*.md`
- repo-cards `docs/repo-cards/*.md`
- migration `docs/migration/*.md`

## 실행 절차

1. **topic 확장**: 동의어/관련어로 검색 범위 확장
   예: "JWT migration" → ["JWT", "RS256", "키 통일", "JWKS", "issuer"]

2. **각 자산에서 매칭 항목 수집**:
   - 파일명 / frontmatter / 본문 키워드
   - 매칭 강도 점수화 (5점 이상만 포함)

3. **시간순 정렬**:
   - dev-log: 파일명 날짜
   - ADR: frontmatter date 또는 파일명 번호 순
   - memory: file mtime
   - repo-card: frontmatter `last_updated_summary`

4. **CURRENT STATE 합성**:
   - 가장 최근 항목들을 LLM이 종합 요약
   - 진행 중 / 완료 / 미해결 분류

5. **STALE 체크**:
   - 마지막 항목 mtime / date 와 today 비교
   - 60일+ 경과 시 경고

## 사용 예시

```
/related JWT migration
→
[/related JWT migration · 2026-04-29]

## TIMELINE

### 2026-04-15 · ADR-0015 JWT issuer SoT
- type: adr
- 경로: docs/adr/0015-jwt-issuer-sot.md

### 2026-04-17 · JWT RS256 전환 + AWS↔GCP 키 통일
- type: memory
- 경로: ~/.claude/.../memory/project_jwt_rs256_migration.md
- 요약: AWS SSM=SoT, GCP .tfvars 주입, cross-cloud 세션 호환

### 2026-04-XX · JWKS 자동화 TODO
- type: memory
- 경로: ~/.claude/.../memory/project_jwks_automation_todo.md
- 요약: inline jwks 하드코딩 자동화 필요, ArgoCD lookup 불가

## CURRENT STATE
JWT는 RS256으로 전환 완료, AWS SSM이 단일 SoT로 통일됨 (2026-04-17).
ADR-0015 (Proposed Rev 2)에서 Option E (GitHub Actions PR 자동화) 채택.
다만 JWKS 배포 자동화는 미완 — inline jwks 하드코딩 상태.

## NEXT
- ADR-0010 Rev 2 결론(Option E) 구현
- inline jwks 자동화 PR 작성

## STALE WARNING
- (없음, 12일 전 갱신)
```

## 인자 없을 때

`$ARGUMENTS` 비어 있으면: 현재 진행 중 작업의 topic을 자동 추론
- 최근 git 변경 파일 / 대화 컨텍스트 / 최근 dev-log

오늘 날짜: $CURRENT_DATE
