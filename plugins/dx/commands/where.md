---
description: "키워드로 INDEX.md + repo-cards + MEMORY + dev-logs 횡단 검색. '어디에 있지?' 질문에 1분 안에 답."
---

# /where

키워드 기반 인덱스 횡단 검색. 프로젝트 자산 전체(INDEX.md, repo-cards, MEMORY, dev-logs) 에서 가장 관련 높은 위치를 즉시 알려준다.

> 전제: 프로젝트에 `INDEX.md` + `docs/repo-cards/` + `docs/dev-logs/` + memory 시스템이 부트스트랩되어 있어야 한다 (`templates/INDEX.md.template`, `templates/repo-card.md.template` 사용).

## 입력

`$ARGUMENTS` — 검색 키워드 또는 자연어 질의 (한글/영문 혼용 OK)

예시:
- `/where session 만료`
- `/where pgbouncer`
- `/where ESO External Secrets`
- `/where 결제 흐름`

## 검색 대상 (우선순위순)

| 우선순위 | 자산 | 위치 |
|---------|------|------|
| 1 | INDEX.md | `/INDEX.md` (루트) |
| 2 | repo-cards | `docs/repo-cards/*.md` (frontmatter + 본문) |
| 3 | MEMORY.md 인덱스 | 사용자 메모리 인덱스 |
| 4 | memory 본문 | `~/.claude/projects/{slug}/memory/*.md` |
| 5 | dev-logs | `docs/dev-logs/*.md` (최근 6개월) |
| 6 | ADR | `docs/adr/*.md` |
| 7 | architecture | `docs/architecture/*.md` |

## 매칭 전략

1. **정확 매칭**: 파일명 / frontmatter `tags` / 헤딩 정확 일치
2. **본문 매칭**: 키워드를 포함한 단락
3. **유사어 확장**: 동의어/약어/한영 변환 (예: "외부 시크릿" → "External Secrets" → "ESO")

## 출력 형식

```
[/where {query} · {today}]

## 가장 관련 높은 결과

### 🎯 PRIMARY (직접적 SoT)
- {경로} — {1줄 요약}
  - 핵심 섹션: {section name}
  - 발췌: "{관련 발췌}"

### 📋 RELATED (참고용)
- {경로} — {1줄 요약}
- {경로} — {1줄 요약}

### 🕐 TIMELINE (관련 dev-logs, 최근→과거)
- 2026-04-25: {dev-log 제목}
- 2026-04-19: {dev-log 제목}

### 💭 MEMORY (관련 사용자 메모리)
- [{name}](memory file) — {desc}

## 발견 못한 경우 권장
- 관련 자산 부재 시: "/log-{type} 으로 새 항목 작성 권장"
- 인덱스 갱신 권장: 본문에 있으나 INDEX/MEMORY 미참조 시
```

## 실행 절차

1. **인덱스 우선 조회**: INDEX.md → repo-cards → MEMORY.md
2. **본문 grep**: ripgrep / grep으로 모든 대상 디렉토리 검색
3. **점수 매기기**:
   - 인덱스 매칭 = 10점
   - 파일명 매칭 = 8점
   - 헤딩 매칭 = 5점
   - tags 매칭 = 5점
   - 본문 매칭 = 1점/회
4. **상위 5건 출력**:
   - 1위 = PRIMARY
   - 2~5위 = RELATED
5. **timeline 추출**: dev-logs 중 키워드 매칭된 것 시간순 정렬
6. **인덱스 stale 의심 표시**: 본문에는 풍부하지만 인덱스에 미참조면 경고

## 빠른 단축

`/where` 단독 실행 시 (인자 없음): "현재 작업 컨텍스트" 기준으로 추론
- 가장 최근 dev-log + 메모리 진행 중 항목 + 24h 내 git 변경 파일

## 사용 예시

```
/where 세션 dropout
→
[/where 세션 dropout · 2026-04-29]

## 가장 관련 높은 결과

### 🎯 PRIMARY
- ~/.claude/.../memory/trouble_session_dropout_2026_04_19.md — P0: 클라 1h vs 서버 30m TTL 미스매치
  - 발췌: "auto-reissue 경로 제한, K8s values + FE 수정 필요"

### 📋 RELATED
- docs/repo-cards/frontend.md — Hotspot 섹션에서 언급
- docs/repo-cards/backend.md — auth 영역

### 🕐 TIMELINE
- 2026-04-19: trouble session dropout root cause audit

### 💭 MEMORY
- trouble_session_dropout_2026_04_19 — 미해결 P0
```

오늘 날짜: $CURRENT_DATE
