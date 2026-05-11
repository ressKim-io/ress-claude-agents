---
description: "docs/dev-logs/*.md tier 자동 산출, 클러스터 발견, superseded 식별. dry-run 기본, 사용자 승인 후 적용."
---

# /consolidate-devlogs

dev-logs 자동 정리 패스. `/consolidate-memory`와 동형 패턴 — Sleep-time computation으로 Tier 정책 (`/.claude/rules/devlog-lifecycle.md`)을 dev-logs 152개에 적용한다.

**원칙**: 분석/제안만 자동, **실제 이동·통합은 사용자 명시 승인 후**.

## 입력 자산

| 자산 | 위치 | 역할 |
|------|------|------|
| dev-logs | `docs/dev-logs/*.md` | 분석 대상 |
| ADR | `docs/adr/*.md` | 인용 검사 (Tier 2 신호) |
| repo-cards | `docs/repo-cards/*.md` | 인용 검사 (Tier 2 신호) |
| memory | `~/.claude/projects/{slug}/memory/*.md` | 인용 검사 |

## 분류 알고리즘 (5 분류)

각 dev-log 파일을 라벨링 (devlog-lifecycle.md Tier 산출 우선순위 따름):

### 1. ACTIVE (Tier 1)
- frontmatter `status: open`
- 또는 `frontmatter status` 부재 + 본문에 미해결 TODO/open 표지
- 또는 active 메모리 (`memory/project_*` 진행 중) / repo-card hotspot에서 인용됨

### 2. REFERENCE (Tier 2)
- `status: resolved` + `importance: critical|major`
- 또는 `status: resolved` + ADR/repo-card/memory에서 인용 검출됨
- frontmatter 부재 시 본문 분량·incident 키워드 기반 보수적 추정

### 3. HISTORICAL (Tier 3, demote 후보)
- `status: resolved` + `importance: minor`
- + 60일+ 미참조 (ADR/카드/메모리에서 링크 없음)
- 권장 액션: `INDEX-by-topic.md`에서 메타만 노출, 본문 grep으로만 발견

### 4. SUPERSEDED (Tier 4, archive 후보)
- `status: superseded` + `replaced_by` 명시
- 또는 본문에 명시적 "이 결정은 dev-logs/... 로 대체됨" 표지
- 권장 액션: `/archive-devlog <slug>` 사용

### 5. CLUSTER (통합·승격 후보)
- 같은 주제 dev-log 3건+ 발견
- 권장 액션: `/promote-devlog` (ADR/skill로 semantic 정착) 또는 통합 dev-log 작성

## frontmatter 부재 처리

기존 dev-logs 대다수는 frontmatter 미보유. 다음 휴리스틱으로 추정:

| 추정 | 근거 |
|------|------|
| `status: open` | 본문에 "TODO", "다음 단계", "미해결", "open" 키워드 |
| `status: resolved` | 본문에 "해결", "완료", "fix", "resolved", postmortem 패턴 |
| `importance: critical` | 프로덕션 장애·비용·보안 키워드 |
| `importance: major` | ADR-NNNN 인용, 패턴/교훈 섹션 존재 |
| `importance: minor` | 단순 작업 기록, 짧은 분량 (< 50줄) |
| `category: troubleshoot` | "장애", "버그", "디버깅", "CrashLoop" 등 |
| `category: decision` | "선택", "vs", "결정", ADR 후보 |
| `category: migration` | "전환", "이관", "→", "마이그레이션" |
| `category: meta` | rules/skills/commands/agents 변경 |

추정 결과는 리포트에서 **"backfill 권장"** 으로 별도 표시.

## 클러스터 탐지

같은 주제 다중 파일 발견 알고리즘:
- 파일명 토큰 / frontmatter `tags` / 본문 첫 단락 키워드 유사도
- 임계: 3건+ 동일 주제 = 패턴 정착 후보

기존 식별된 클러스터 (2026-04-29 측정):
- redis(3), otel(3), sot(4), istio(2), ecr(2), db(2), dashboard(2), crashloop(2), ticketing(2), label(2)

## 실행 절차

1. **자산 인벤토리**:
   - `docs/dev-logs/*.md` 목록 수집 (sessions/ 제외)
   - 각 파일의 frontmatter 파싱 시도 + mtime 수집
   - ADR / repo-cards / memory 본문에서 dev-log 파일명 grep → 인용 그래프 구축

2. **각 파일을 5 분류로 라벨링**:
   - frontmatter 우선, 부재 시 휴리스틱
   - 인용 그래프 기반 "참조됨" 판정
   - 60일 cutoff: `today - 60d` 미만 mtime/date

3. **클러스터 탐지**:
   - 파일명 토큰 + tags + 키워드 → 동일 주제 그룹화
   - 3건+ 그룹만 리포트

4. **리포트 출력** (dry-run, 변경 없음):
   ```
   [dev-logs Consolidation Report · {today}]

   ## Summary
   - Total: {N} files (sessions/ 제외)
   - Active (Tier 1): {a}
   - Reference (Tier 2): {r}
   - Historical (Tier 3, demote 후보): {h}
   - Superseded (Tier 4, archive 후보): {s}
   - Cluster groups: {c}
   - frontmatter 부재: {nf} (backfill 권장)

   ## ACTIVE (Tier 1, 진행 중)
   - {file} — {status: open 근거}
     - 인용: {ADR/카드/메모리 링크}

   ## REFERENCE (Tier 2, 보존)
   - {file} — importance={importance}, 인용 {N}회

   ## HISTORICAL (Tier 3, demote 후보)
   - {file} ({Nd} ago) — minor, 미참조
     - 권장: tier=3 명시, INDEX-by-topic 메타만

   ## SUPERSEDED (Tier 4, archive 후보)
   - {file} → replaced_by: {target}
     - 권장: /archive-devlog {slug}

   ## CLUSTERS (통합·승격 후보)
   - 그룹: redis (3건)
     - 2026-MM-DD-redis-A.md
     - 2026-MM-DD-redis-B.md
     - 2026-MM-DD-redis-C.md
     - 권장: /promote-devlog → ADR-NNNN-redis-... 또는 통합 dev-log

   ## FRONTMATTER BACKFILL (휴리스틱 추정)
   - {file}: 추정 status={s}, importance={i}, category={c}
     - 권장: 수동 검토 후 frontmatter 추가

   ## RECOMMEND
   1. 우선 처리: {top 3 actions}
   2. 보류: {to be reviewed later}
   ```

5. **사용자 승인 대기**:
   - 리포트 표시 후 어느 항목을 적용할지 사용자에게 질문
   - 승인 받은 항목만 실제 변경 (Edit/Write)
   - frontmatter backfill, archive 이동 등은 한 번에 ≤ 5 파일

## 적용 시 변경 종류

승인 받은 경우에만 수행:

| Action | 영향 | 위임 커맨드 |
|--------|------|-------------|
| **frontmatter backfill** | 파일 상단에 frontmatter 추가/보강 | (직접 Edit) |
| **demote to Tier 3** | frontmatter `tier: 3` 추가 | (직접 Edit) |
| **archive (Tier 4)** | `_archive/` 이동, INDEX 정정 | `/archive-devlog` 권장 |
| **promote to ADR/skill** | ADR/skill 신규 생성, 원본에 `replaced_by` 추가 | `/promote-devlog` 권장 |
| **cluster merge** | 통합 dev-log 작성, 원본들 archive | 사용자 검토 필수 |

## 안전 장치

- 적용 전 항상 dry-run 리포트 표시
- 한 번에 처리할 항목 수 ≤ 5 (메모리 `feedback_smaller_commits`)
- 삭제는 절대 안 함, 항상 `_archive/` 이동
- frontmatter `status` 부재 파일은 자동 demote 안 함 (수동 확인 후 backfill)
- ADR/repo-card/memory에서 인용된 파일은 자동 archive 절대 안 함

## 인자

`$ARGUMENTS` 가 주어지면:
- `dry-run` (기본): 리포트만
- `--apply <category>`: 특정 분류 자동 적용 (사용자 사전 승인 시)
- `<keyword>`: 특정 키워드 관련 항목만 분석
- `--cluster-only`: 클러스터 탐지만 출력

## 출력 외 부수 효과

`docs/dev-logs/INDEX-active.md` 와 `INDEX-by-topic.md` (있다면) 자동 갱신 권장. 단, 사용자 승인 후 적용.

오늘 날짜: $CURRENT_DATE
