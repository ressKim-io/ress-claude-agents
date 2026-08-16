---
description: "Tier 4 dev-log를 _archive/ 로 이동, replaced_by 링크 보존. superseded 처리."
---

# /archive-devlog

`status: superseded` dev-log를 `docs/dev-logs/_archive/` 로 이동한다. forward link (`replaced_by`)는 새 자료에 보존, INDEX는 정리.

학계 패턴 "Cold Storage" + "Searchable metadata 유지" 동형. **삭제하지 않음**.

## 입력

`$ARGUMENTS` — archive 대상

옵션:
- 단일 dev-log slug: `2026-03-15-old-decision`
- `--all-superseded`: frontmatter `status: superseded` 모든 파일 일괄 (사용자 승인 필수)
- `--dry-run`: 미리보기

## 사전 조건 (MANDATORY)

archive 전 반드시 확인:

1. **`status: superseded`**: frontmatter에 명시 필요. 없으면 거절.
2. **`replaced_by` 명시**: 대체 자료 경로 필수. 없으면 거절.
3. **대체 자료 존재**: `replaced_by` 경로 파일이 실제 존재하는지 검증.
4. **기존 forward link**: 다른 dev-log/ADR/memory에서 이 파일을 인용하는지 검사.
   - 인용 발견 시 → 사용자에게 보고, 강제 archive 시 인용 측 갱신 권장

조건 미충족 시: archive 거절 + 정정 가이드 출력.

## 실행 절차

### 1. 대상 검증

```
대상: docs/dev-logs/2026-MM-DD-{slug}.md
- frontmatter status: {status}
- frontmatter replaced_by: {path}
- 인용 검사:
  - docs/adr/ → {N건}
  - docs/repo-cards/ → {N건}
  - memory/ → {N건}
  - dev-logs/ → {N건}
```

### 2. 사용자 승인 대기

```
[archive 미리보기]

이동 계획:
- FROM: docs/dev-logs/2026-MM-DD-{slug}.md
- TO:   docs/dev-logs/_archive/2026-MM-DD-{slug}.md

영향:
- replaced_by: {대체 경로} (forward link 보존)
- 인용 자료 {N개} 갱신 권장:
  - docs/repo-cards/X.md (line N)
  - memory/Y.md (line M)

INDEX 영향:
- docs/dev-logs/INDEX-active.md → 라인 제거 (있다면)
- docs/dev-logs/INDEX-by-topic.md → 메타만 유지 (있다면)

진행하시겠습니까? [y/n/edit-replaced-by]
```

### 3. 승인 시 적용

```
1. _archive/ 디렉토리 없으면 생성:
   mkdir -p docs/dev-logs/_archive/

2. 파일 이동:
   git mv docs/dev-logs/2026-MM-DD-{slug}.md \
          docs/dev-logs/_archive/2026-MM-DD-{slug}.md

3. 인용 자료 갱신 (선택, 사용자 추가 승인):
   - 인용 측에서 경로를 _archive/ 로 변경 또는 replaced_by 경로로 redirect

4. INDEX 갱신:
   - INDEX-active.md 에서 제거
   - INDEX-by-topic.md 에 archived 표기 (메타 유지)

5. 변경 요약 출력:
   - 이동된 파일
   - 갱신된 인용
   - 갱신 권장 (사용자가 수동 처리할 항목)
```

## 적용 시 변경 종류

| Action | 영향 | 자동/수동 |
|--------|------|----------|
| 파일 이동 | `_archive/` 로 git mv | 자동 (승인 후) |
| INDEX 정리 | 활성 인덱스에서 제거 | 자동 (승인 후) |
| 인용 갱신 | 인용 측 파일 수정 | **수동 권장** (사용자 승인 후 한 건씩) |

## 안전 장치

- 사용자 승인 없이 절대 archive 안 함
- `git mv` 사용 — 히스토리 보존
- `replaced_by` 미기입 파일은 archive 거절 (대체 추적 불가)
- 한 번에 처리할 항목 수 ≤ 5 (메모리 `feedback_smaller_commits`)
- `--all-superseded` 옵션도 5건 단위로 batch + 각 batch 사용자 승인

## 인자

`$ARGUMENTS`:
- `<slug>`: 단일 dev-log
- `--dry-run` (기본 미리보기): 변경 없이 영향 보고
- `--apply`: 승인 가정 (사용자 확인 시 사용)
- `--all-superseded`: 일괄 (5건 단위 batch + 각각 승인)
- `--keep-citations`: 인용 측 갱신 스킵 (수동 처리 의도)

## 사용 예시

### 단일 archive

```
/archive-devlog 2026-03-15-old-decision
→
[archive 미리보기]
이동: docs/dev-logs/2026-03-15-old-decision.md → _archive/
replaced_by: adr/0015-jwt-issuer-sot.md (존재 확인)
인용: 1건 (memory/project_jwt.md line 42)

진행? [y/n]
y
→ git mv 완료
→ memory/project_jwt.md 갱신 권장 (수동)
```

### 일괄 archive (Phase 1.6 R5)

```
/archive-devlog --all-superseded
→
superseded 5건 발견:
  1. 2026-03-15-A.md → adr/0015 (인용 1건)
  2. 2026-03-22-B.md → dev-logs/2026-04-01-B-rev2 (인용 0건)
  ...

batch 1 (3건) 승인하시겠습니까? [y/n]
```

## 학계 근거

- **Cold Storage**: 메타데이터 유지 + 본문 archive 분리
- **Searchable metadata**: `_archive/` 도 grep 검색 가능
- **Forward link 보존**: episodic → semantic 추적 그래프 유지
- 출처: `docs/dev-logs/2026-04-29-devlog-tier-policy.md` 끝 섹션

## 복구 (실수 시)

archive는 `git mv` 이므로 복구 가능:
```bash
git mv docs/dev-logs/_archive/{slug}.md docs/dev-logs/{slug}.md
# frontmatter status 정정 (resolved 또는 open)
# replaced_by 제거 (또는 수정)
```

오늘 날짜: $CURRENT_DATE
