---
description: "MEMORY.md + memory/*.md 정리. stale/duplicate/orphan/repo-card 이관 후보 분류. dry-run 기본, 사용자 승인 후 적용."
---

# /consolidate-memory

자동 메모리 정리 패스. Anthropic 의 "Dream Memory Consolidation" 패턴을 프로젝트 메모리 자산에 적용한다.

**원칙**: 분석/제안만 자동, **실제 삭제·이동은 사용자 명시 승인 후**.

## 입력 자산

| 자산 | 위치 | 역할 |
|------|------|------|
| MEMORY.md | `~/.claude/projects/{project-slug}/memory/MEMORY.md` | 메모리 인덱스 |
| 메모리 파일 | `~/.claude/projects/{project-slug}/memory/*.md` | 개별 항목 |
| repo-cards | `docs/repo-cards/*.md` | 통합 후보 대상 |

`{project-slug}`: 현재 프로젝트의 `~/.claude/projects/` 하위 디렉토리. 자동 탐지.

## 분류 알고리즘

각 메모리 파일을 6 분류로 라벨링:

### 1. STALE (오래된 항목)
- type=project + 마지막 수정 60일+ 경과
- 단, 같은 주제의 후속 메모리 / dev-log 존재 시 → **수정**(merge 권장) 또는 **archive**(보존)
- type=feedback/user/reference 는 시간 기준 면제 (영구 보존성)
- type=trouble 은 incident 종결 여부 확인 후

### 2. DUPLICATE (중복 의심)
- 파일명 / frontmatter 키워드 / 본문 첫 단락 유사도 분석
- 동일 주제 다중 파일 발견 시 → **merge 후보**

### 3. MIGRATION CANDIDATE (repo-cards 이관 가능)
- type=project이고 단일 레포 한정 정보 (예: `project_server_todo`)
- 해당 레포 카드의 hotspot/recent_incidents/관련 문서 섹션으로 통합 가능

### 4. ORPHAN (MEMORY.md 인덱스 미참조)
- 파일은 존재하지만 MEMORY.md에 링크 없음
- 옵션: 인덱스에 추가 또는 삭제

### 5. INDEX-ONLY (역방향 ORPHAN)
- MEMORY.md에 링크 있으나 실제 파일 없음 (broken link)
- 인덱스 정정 필요

### 6. HEALTHY (조치 불필요)
- 위 5개 분류 어디에도 해당 없음

## 실행 절차

1. **자산 인벤토리**:
   - 메모리 디렉토리 절대경로 확인 (자동 탐지)
   - `ls -la` 로 모든 파일 + mtime 수집
   - MEMORY.md 파싱해 `[name](file.md) — desc` 패턴으로 인덱스 추출
   - `docs/repo-cards/*.md` 목록 수집

2. **각 메모리 파일을 6 분류로 라벨링**:
   - frontmatter `type` / mtime / MEMORY.md 참조 여부 / 동일 주제 후속 파일 여부
   - 단일 레포 한정 여부 (frontmatter 또는 본문 키워드 기반)

3. **리포트 출력** (dry-run, 변경 없음):
   ```
   [Memory Consolidation Report · {today}]

   ## Summary
   - Total: {N} files
   - Healthy: {h}
   - Stale: {s}
   - Duplicate: {d}
   - Migration candidate: {m}
   - Orphan: {o}
   - Index-only (broken): {b}

   ## STALE (60d+ 미갱신, 정리 후보)
   - {file} (mtime, {Nd} ago) — 후속 파일: {related} → 권장: {merge/archive/keep}

   ## DUPLICATE (중복 의심)
   - 그룹 1:
     - {fileA} (주제: ...)
     - {fileB} (주제: ...)
     - 권장: merge into {fileA} (더 최근 갱신)

   ## MIGRATION CANDIDATE (repo-cards 통합 가능)
   - {file} → docs/repo-cards/{repo}.md
     - 통합 위치: hotspot / recent_incidents / 관련 문서

   ## ORPHAN (인덱스 미참조)
   - {file} → 권장: MEMORY.md 추가 또는 삭제

   ## INDEX-ONLY (broken link)
   - MEMORY.md 라인 N: [{name}]({file}) — 파일 없음

   ## RECOMMEND
   1. 우선 처리: {top 3 actions}
   2. 보류: {to be reviewed later}
   ```

4. **사용자 승인 대기**:
   - 리포트 표시 후 어느 항목을 적용할지 사용자에게 질문
   - 승인 받은 항목만 실제 변경 (Edit/Write/Delete)
   - 변경 후 변경 요약 출력

## 적용 시 변경 종류

승인 받은 경우에만 수행:

| Action | 영향 |
|--------|------|
| **archive** | `memory/_archive/{file}` 로 이동, MEMORY.md 라인 제거 |
| **merge** | A의 본문을 B에 통합, A는 archive, MEMORY.md 라인 정정 |
| **migrate to repo-card** | repo-card에 본문 통합, 메모리 archive, MEMORY.md 라인 제거 |
| **add to index** | MEMORY.md에 링크 라인 추가 (적절한 섹션) |
| **fix broken link** | MEMORY.md 라인 정정 또는 제거 |

## 안전 장치

- 적용 전 항상 dry-run 리포트 표시
- 한 번에 처리할 항목 수 ≤ 5 (변경 폭주 방지, 메모리 `feedback_smaller_commits`)
- 삭제는 절대 안 함, 항상 `_archive/` 이동
- frontmatter `type` 모르는 파일은 분류 제외 (기본 keep)
- type=feedback/user 는 자동 처리 절대 안 함 (수동 조정 영역)

## 인자

`$ARGUMENTS` 가 주어지면:
- `dry-run` (기본): 리포트만
- `--apply <category>`: 특정 분류 자동 적용 (사용자 사전 승인 시)
- `<keyword>`: 특정 키워드 관련 항목만 분석

오늘 날짜: $CURRENT_DATE
