---
date: 2026-11-15
category: meta
tier: 1
importance: major
status: open
tags: [rust, plugin, rule, skill, agent, composed-method, error-boundary, workflow, verification]
related:
  - adr/0015-rust-plugin-defaults.md
  - audit/2026-11-15-rust-plugin-verification.md
  - adr/0008-asset-tier-policy.md
---

# Rust plugin 추가: rule 1, skill 10, command 4, agent 1

Java/Spring에서 쓰던 구조 습관을 Rust 엔진 작업에 옮길 수 있게 Rust rule과 `rust` plugin을 추가했다.
결정은 [ADR 0015](../adr/0015-rust-plugin-defaults.md)에, 외부 사실과 컴파일 확인은 [검증 기록](../audit/2026-11-15-rust-plugin-verification.md)에 있다.
여기에는 경위와 진행 중 생긴 문제, 남은 일을 적는다. PR 생성 승인 전이라 `status: open`이다.

## Context

- 사용자는 Go가 API를 맡고 Rust가 엔진을 맡는 구조를 쓴다. 엔진은 세 가지다.
  - track-engine: Postgres 테이블 큐 워커(`SKIP LOCKED` + `LISTEN/NOTIFY`, outbox, `(activity_id, engine_version)` upsert, attempts 상한 → dead)
  - og-render: 내부 동기 HTTP로 공유 링크 미리보기 이미지를 만든다(한글 포함)
  - CRDT 협업 편집 동기화 엔진
- 요청: Java에서 쓰던 계층 분리, Composed Method(`createUser { checkEmail(); duplicateNicknameCheck(); }`), `@ControllerAdvice`식 에러 집중, 파일 길이 관리를 Rust에도 적용한다. 이것이 Rust에서도 관용적인지 대기업 가이드까지 확인한다.

## Issue

- 레포에 Rust 자산이 없었다. Go·Java는 rule과 plugin이 있지만 Rust는 요청할 때마다 처음부터 설명해야 했다.
- 레포 `clean-code` rule의 "Cognitive Complexity ≤ 15"는 Rust에서 잴 수 없다. clippy가 1.91에서 `cognitive_complexity`를 restriction으로 내리고 측정 도구로 쓰지 말라고 적었다.
- Java 습관 중 일부는 Rust에서 그대로 옮기면 틀린다.
  - 구간 미통과·부정 의심 같은 판정을 예외(`Err`)로 올리면 worker가 재시도하다 정상 판정을 dead로 보낸다.
  - `UserService` + `UserServiceImpl` 직역은 구현이 하나뿐인 trait가 된다.

## Action

### 판정 (조사 결론)

| Java 습관 | 판정 | Rust 형태 |
|---|---|---|
| Controller-Service-Repository | 조정해서 씀 | 엔진은 IO 없는 core lib crate + 얇은 shell bin crate (Functional Core / Imperative Shell). CI `cargo tree`로 core 순수성 검사 |
| Composed Method | 그대로 씀 | `fn check_x() -> Result<(), E>` + `?`. `self`가 필요 없으면 free fn. 필드를 빌린 채 `&mut self` helper를 부르면 E0502 |
| `@ControllerAdvice` | 조정해서 씀 | 경계마다 분류 지점 한 곳: HTTP `impl IntoResponse`, worker `apply_outcome`, WebSocket close frame. 판정은 `Ok(Verdict)` |
| 파일 길이 | 그대로 씀 | `foo.rs` + `foo/`. 공식·대기업 숫자 한도는 없어서 house rule로 정함 |

### 추가한 자산

- rule `.claude/rules/lang/rust.md`: 에러 처리, Composed Method, 타입과 검증, 추상화와 의존성, 모듈과 파일, async 기본, 네이밍, lint 설정, 테스트 위치
- skill 10개
  - 언어 공통: `rust-from-spring`, `rust-idioms`, `rust-error-handling`, `rust-engine-architecture`, `rust-async-tokio`, `rust-testing`
  - 엔진: `rust-pg-queue-worker`, `rust-og-image-render`, `rust-crdt-sync`, `rust-geo-track`
- command 4개: `/rust:review`, `/rust:lint`, `/rust:refactor`, `/rust:test-gen`
- agent `rust-reviewer`: Rust 고유 위험(소유권·에러 경계·panic 경로·async·core 순수성·`unsafe`·lint)만 본다. 일반 가독성은 `dx:code-reviewer`가 맡는다(ADR 0008 §3 관점 축)
- 공유 파일: marketplace, `generate-plugin-readmes.py` `RULES`, `layout.sh` 하한, AGENTS.md 3곳, README 2개, `agent-handoff.yml`, `code-reviewer.md`의 Rust 블록과 이관 경로

### house rule

`too_many_lines` warn + threshold 100 명시, `excessive-nesting-threshold = 4`로 시작, 테스트 모듈을 뺀 400줄 초과 시 분할 검토, `unwrap_used` warn + `allow-unwrap-in-tests`, `cognitive_complexity` 미사용, `panic = "unwind"`, 의존성 concrete > generic > `dyn`.

## 진행 기록

### 조사

- workflow 2개로 조사했다(언어 공통 179건, 엔진 173건). 주제마다 조사 담당과 반박 담당을 따로 두었고, mismatch 20건은 정정값으로 바꿨다.
- 정정 예: `spawn_blocking`은 CPU 계산에 "poorly suited"(rayon 또는 CPU Semaphore로 상한), rstar 0.14.0에 `bulk_load_parallel` 없음, Figma는 CRDT가 아니라 서버 권한 방식.

### 작성 workflow

- 자산마다 writer → 2관점 리뷰(사실·출처 / Rust 정확성·레포 규격) → fixer를 최대 3라운드 돌리고, 끝에 자산 간 일관성 critic과 audit·ADR writer를 붙였다.
- 사용량 한도로 세 번 멈췄고, resume으로 이어 네 번째 실행에서 끝났다. 멈출 때마다 스크립트를 고쳤다.
  - 리뷰가 실패해 `null`이 오면 pass로 셌다 → 한 번 재시도하고, 그래도 실패하면 `review_failed`로 기록하고 critic 전에 멈춘다.
  - fixer가 실패해도 다음 라운드 리뷰를 돌렸다 → 그 자산의 루프를 멈추고 `fix_failed`로 기록한다.
  - 3라운드 마지막 수정이 검증 없이 끝났다 → 3라운드에 blocking이 있던 자산은 수정 뒤 최종 검증 리뷰를 한 번 더 돌린다.
- critic의 blocking 4건 중 workflow가 고치지 못한 것과 audit writer가 찾은 불일치 6곳은 직접 고쳤다(CPU 오프로드 기본값, `check_duplicate_nickname` 이름, trait 예외 문구, `Rejected` 주석).

| 자산 | blocking 추이 |
|---|---|
| rule | 3 → 1 → 0 |
| `rust-idioms` · `rust-engine-architecture` | 2 → 1 → 0 |
| `rust-error-handling` | 3 → 1 → 3 → 최종 0 |
| `rust-async-tokio` | 3 → 1 → 1 → 최종 1 (critic 단계에서 수정) |
| `rust-testing` · `rust-pg-queue-worker` | 3 → 2·1 → 0 |
| `rust-og-image-render` | 3 → 1 → 1 → 최종 0 |
| `rust-crdt-sync` | 7 → 2 → 0 |
| `rust-geo-track` | 4 → 2 → 0 |
| `rust-from-spring` · commands · agent | 2·3·3 → 0 |

### PR 크기

- PR 하나는 400줄 이하여야 한다. skill이 400줄 안팎이라 생성 파일(inventory, plugin README), 하한 변경, 링크 복원이 붙으면 넘친다.
- 링크 복원: 뒤 PR에서 추가될 자산을 가리키는 링크는 앞 PR에서 평문으로 바꾸고, 대상이 들어오는 PR에서 되살린다. 되살린 줄은 삭제·추가 2줄로 센다.
- 그래서 (1) 링크 복원이 가장 적은 skill 순서를 탐색으로 정했고, (2) skill 9개와 agent를 모두 387줄 줄였다(skill 332~373줄, agent 368줄). 코드 블록은 빈 줄과 주석 줄만 지웠고, 겹치는 설명은 담당 skill 링크로 바꿨다. 지운 문장은 거의 없고 대부분 bullet·Sources 줄 합치기다.
- 대가: 일부 섹션은 bullet 1~2개짜리 긴 문단이 됐고, Sources는 링크 수십 개가 한 줄에 붙어 검증 메모가 어느 출처 것인지 덜 분명하다. 출처별 상세는 검증 기록에 있다.
- 크기는 실제 빌드로 쟀다. skill PR 하나에 생성 파일·하한 변경이 20줄(첫 skill은 30줄) 붙는다.
- 자산이 없는 plugin은 catalog 게이트가 막아서, plugin 골격은 rule·`/rust:lint`와 같은 PR에 넣었다.

## Result

- 레포 게이트 전체 통과: `make validate`, `make validate-links`, rules-drift, skill-frontmatter, agent-handoff, schemas, frontmatter-yaml, generator validate 3종, `test-gates.sh`, `make lint`.
- `verify-plugins.sh rust`: skill+command 14/14, agent 1/1 로드. Cursor adapter `--diff`는 변경 0건.
- 코드 예시는 scratch crate에서 로컬 rustc 1.96으로 확인했다. 자산별 결과(tested·clippy-clean·expected-fail·not-compiled와 사유)는 검증 기록에 있다.
- 실행 안 함
  - Postgres·docker가 없어 SQL, `LISTEN/NOTIFY`, `#[sqlx::test]`, testcontainers를 돌리지 않았다.
  - 1.97+ lint와 1.100 동작(`allow-unwrap-in-tests`가 workspace member `tests/`에 적용되는지)은 재지 않았다.
  - `rust-reviewer`를 실제 Rust workspace에서 end-to-end로 돌리지 않았다.

## 남은 일

- push·PR 생성은 사용자 승인 뒤에 한다.
- 첫 엔진 코드가 생기면 `excessive-nesting`·`too_many_lines` 경고 수를 재고 threshold를 다시 정한다(ADR 0015).
- 1.100으로 올린 뒤 `allow-unwrap-in-tests` 범위를 다시 잰다.
- 범위 밖으로 남긴 것(수정하지 않음)
  - `code-reviewer.md` description이 없는 agent(go-·java-·python-expert)를 가리킨다.
  - AGENT-SPEC 예시의 `tools` 쉼표 문자열은 스키마 검사에서 실패한다.
  - go command Usage가 접두사 없는 `/lint` 형태다.
  - `deep-thinking.md`가 없는 `docs/research/`를 가리킨다.
  - `clean-code` rule의 Cognitive Complexity는 Rust에서 잴 수 없다.

## Related Files

- .claude/rules/lang/rust.md
- plugins/rust/ (skills 10, commands 4, agents/rust-reviewer.md, .claude-plugin/plugin.json)
- .claude-plugin/marketplace.json, scripts/generate-plugin-readmes.py, scripts/lib/layout.sh
- AGENTS.md, README.md, README.ko.md
- .claude/agent-handoff.yml, plugins/dx/agents/code-reviewer.md
- docs/adr/0015-rust-plugin-defaults.md, docs/audit/2026-11-15-rust-plugin-verification.md
