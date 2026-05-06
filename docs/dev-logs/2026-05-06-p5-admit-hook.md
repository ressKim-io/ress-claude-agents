---
date: 2026-05-06
type: meta
phase: 0002-P5
related:
  - ../migration/0002-standardization-and-control-plane.md
  - ../migration/0002-progress.md
  - 2026-05-06-p4-adapter-implementation.md
---

# 0002 P5 — Enforcement Hook (PreToolUse admit)

P4 종결(`736f0dd`→`c7931ec`, CI run 25419755062 success) 직후 동일 흐름에서 P5 진입. P4보다 단순(hook 1개 + 6 fixture + init wiring) — Step A spike는 narrative로 흡수, B/C/D 3 commit으로 압축.

## 진입 시점 상태

- P4 종료: control-plane adapter 4 subcommand + 5 검증 게이트(adapter parity, multi-AI sim 포함) ✓
- LockFile.hook = `{installed: false, status: "p5-stub"}` (init.ts L46-47)
- plan §205-225 명세: PreToolUse 형식 + admit 동작 3 규칙 + warn→deny 단계 전환 (P0 Q5)

## Step A — admit.ts (구현 + 테스트)

### 매칭 시맨틱: match.ts와 다름

처음엔 `control-plane/src/match.ts`의 `applies_when` 평가 로직을 재사용할 수 있을지 검토. 결론: **재사용 불가**. score 시맨틱(전체 file enumerate → 점수 합산)과 admit 시맨틱(단일 path boolean) 시맨틱 자체가 다름. admit은 단일 path 1개에 대한 글롭/regex 매칭이 핵심이고 score는 점수 가중치를 위한 frequency 계산.

→ admit 전용 매처를 inline 작성. control-plane runtime deps(zod·kleur·fast-glob·yaml = 4/5) 정책상 picomatch/minimatch 같은 글롭 라이브러리 추가는 회피. 50줄 미만 `globToRegex(glob)` 직접 구현:

```ts
// `**/`        → (?:.*/)?
// `**`         → .*
// `*`          → [^/]*
// `?`          → [^/]
// `.{}()[]+^$|\\` → \<char>
```

실제 PoC 10개 manifest의 모든 패턴(`**/Chart.yaml`, `**/values*.yaml`, `**/templates/*.tpl`, `**/*.go` 등)은 위 subset에 안전히 들어간다. 미래 패턴이 더 복잡해지면 picomatch 도입 재고.

### 규칙 3 + Fallback 3

```
1. tool ∈ {Edit, Write, NotebookEdit} 아님 → ALLOW (admission 범위 외)
2. skill 미지정 → ALLOW (skill-aware admission은 P6+)
3. path 미지정 → ALLOW (validation skip)
4. skill의 security.sandbox === "read-only" → DENY
5. applies_when 미지정 → ALLOW (manifest이 admission 의견 표명 안 함)
6. exclude_when.files_present 매치 → DENY
7. files_present 글롭 매치 → ALLOW
8. files_contain 글롭+regex 매치 → ALLOW
9. 위 모두 불일치 → DENY ("does not match")
```

Fallback 3개(2/3/5)가 ALLOW인 이유: P5는 초기 warning 모드라 데이터 수집 단계. false negative(admit 차단)는 사용자 마찰을 만들고 baseline 노이즈 증가. P6 pilot에서 deny 전환 시 fallback 정책 재검토.

### Mode 처리

| Mode | allow=true | allow=false |
|---|---|---|
| `warn` | exit 0 | exit 0 + stderr WARN message |
| `deny` | exit 0 | exit 2 + stderr DENY message |

P5 init wiring은 디폴트 `warn`. plan §224 + P0 결정 Q5 정합.

### 6 vitest fixture (검증 게이트)

plan §52 검증 게이트 "위배 3건 정확히 deny, 정상 3건 allow" 충족:

**DENY 3건**:
1. `applies_when.files_present` 미스 (helm-edit이 `src/main.go` Edit 시도)
2. `security.sandbox: read-only` 가드 (review-only가 `docs/notes.md` Write 시도)
3. `files_contain` glob은 매치하나 regex 미스 (deploy-strict가 `^kind: ImpossibleKind` 요구하는데 실제 파일은 `Deployment`)

**ALLOW 3건**:
1. `applies_when.files_present` 매치 (helm-edit이 `charts/myapp/Chart.yaml` Edit)
2. read-only tool (review-only skill인데 `Read` tool 호출 — admission 범위 외)
3. skill 미지정 (CLAUDE_ACTIVE_SKILL 빈 값)

추가 3 unit: `globToRegex` 매처 자체 검증 (`**/Chart.yaml` nested path / `**/*.go` 배제 / regex special char escape).

vitest 96→**105**.

## Step B — install-hook.ts + init.ts step 5 wiring

### `installHook` 책임

- 입력: `{root, mode, dryRun?}`
- 출력: `{installed, alreadyPresent, settingsPath, mode}`
- 동작:
  1. `<root>/.claude/settings.local.json` 읽기 (없으면 빈 객체)
  2. `hooks.PreToolUse[]`에 `HOOK_MARKER='@ress/claude-agents admit'` substring 검색 → 이미 존재면 idempotent skip
  3. 없으면 새 entry append:
     ```json
     {
       "matcher": "Edit|Write|NotebookEdit",
       "hooks": [{
         "type": "command",
         "command": "npx @ress/claude-agents admit --tool=\"$CLAUDE_TOOL\" --path=\"$CLAUDE_TOOL_INPUT_path\" --skill=\"$CLAUDE_ACTIVE_SKILL\" --mode=warn"
       }]
     }
     ```
  4. JSON.stringify(2 indent) + trailing newline로 write

### `settings.json` vs `settings.local.json` 결정

git-tracked `settings.json`(팀 공유) 대신 `settings.local.json`(개인 환경) 사용. 이유:
- hook command path가 사용자 환경 의존(`npx`, PATH)이라 공유 안전성 낮음
- baseline 데이터 수집 단계라 사용자별 옵트인이 자연스러움
- P6 deny 전환 + adoption 안정화 후 `settings.json`(공유)로 승격 가능

### LockFile.hook schema 확장

```ts
hook: {
  installed: boolean;
  status: "p5-active" | "p5-skipped" | "p5-already-present";
  mode?: HookMode;
  settings_path?: string;  // root 기준 상대 경로
}
```

`p5-stub` 사라짐. `p5-skipped` = `.claude/` 부재로 hook install 안 됨. `p5-already-present` = idempotent re-run.

### init.ts step 5 분기

`detected.includes("claude")` 조건. claude 도구 감지된 경우만 hook install. codex/cursor는 admit hook 없음 (P5 범위 외).

### init.test.ts 갱신 + 신규 3 테스트

기존 `lock carries P4/P5 stub markers` 테스트:
- `p4-stub` → `p4-skipped` (P4-D에서 변경됨)
- `p5-stub` → `p5-skipped` (P5에서 변경)
- `installed: false` 검증 추가

신규 3 테스트:
1. `installs warn-mode admit hook into .claude/settings.local.json`: settings.local.json 생성 + command 문자열 검증
2. `is idempotent: re-running init does not duplicate hook entry`: 두 번째 init이 `p5-already-present` + PreToolUse 길이 1 유지
3. `merges into existing settings.local.json without losing other keys`: 기존 `permissions.allow` 보존 + hooks 추가

vitest 105→**108**.

## Step C — docs

본 dev-log + progress.md 갱신:

- P5 row: in_progress → completed
- P6 row: pending → next (warn baseline 1주 후 deny 전환 결정 명시)
- Decision Log P5 4건 추가: 매처 결정 / fallback 정책 / settings.local.json + HOOK_MARKER / hookMode warn 디폴트
- Verification 체크리스트: Hook 동작 (deny 3 + allow 3) ✓

## 최종 검증

| 항목 | 결과 |
|---|---|
| `npm run typecheck` | 0 |
| `npm test` | **108/108** (96→108, +12) |
| `npm run build` | ESM 44.71KB, DTS 17.59KB |
| 5 lint | all green |
| adapter parity (local) | 0 create / 0 update / 66 unchanged → CI drift step 통과 보장 |

## 결정 4건 (Decision Log P5)

progress.md L92-95에 1줄씩 박았다.

1. admit 전용 매처 (match.ts 재사용 불가, inline glob→regex 50줄)
2. fallback 3건 ALLOW (warning 단계 데이터 수집 우선)
3. `settings.local.json` + HOOK_MARKER substring detection (개인 환경 격리 + idempotent)
4. hookMode 디폴트 warn, deny 전환은 P6 baseline 후 ADR

## P5 verification gate 종결

- [x] Hook 동작 (deny 3건, allow 3건) — `tests/admit.test.ts` 통과

P5 완전 종결. P6 진입 시점:
- kubernetes 카테고리 10개 skill 전체 변환 (assets/skills/kubernetes/{전체}/SKILL.md)
- pilot 1주 baseline 수집 (activation rate, matching accuracy, false positive/negative)
- baseline 결과 → deny 전환 ADR

## P5 commit 분할

3 commit:
1. `feat(control-plane): add admit subcommand for PreToolUse admission`
   - control-plane/src/admit.ts
   - control-plane/src/index.ts (admit routing)
   - control-plane/tests/admit.test.ts
2. `feat(control-plane): wire init step 5 with installHook idempotent merge`
   - control-plane/src/install-hook.ts
   - control-plane/src/init.ts
   - control-plane/tests/init.test.ts
3. `docs(migration): track 0002 P5 progress + dev-log`
   - docs/migration/0002-progress.md
   - docs/dev-logs/2026-05-06-p5-admit-hook.md

## 비용

총 작업: ~1.5시간 (P4의 절반 — hook 1개라 단순). admit.ts 169줄 + install-hook.ts 95줄 + 9 admit tests + 3 init tests + dev-log 1건. 단계 압축이 P4 정신 그대로.
