<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# rust

Rust — 관용 패턴, 에러 경계, 엔진 core/shell 구조, Tokio, Postgres 큐 워커, OG 이미지 렌더, CRDT 동기화, GPS 트랙 판정, 테스트

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install rust@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/rust/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`java`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/java/README.md)
- [`security`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/security/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)
- [`go`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/go/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`lang/rust.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (9)

| 이름 | 설명 |
|---|---|
| `/rust:rust-async-tokio` | Tokio 비동기 운영 패턴 — CPU 작업 rayon·spawn_blocking 분리, actor·bounded channel, select! 취소 안전성, CancellationToken 종료 … |
| `/rust:rust-crdt-sync` | Rust CRDT 협업 편집 동기화 — yrs·automerge·loro 선택, 문서당 actor, y-sync·awareness, 메시지 단위 권한 필터, update … |
| `/rust:rust-engine-architecture` | Rust 계산 엔진 구조 — IO 없는 core·얇은 shell crate(Functional Core·sans-IO), 경계 CI 검사, concrete·generic·dyn 의존성 선택, … |
| `/rust:rust-error-handling` | Rust 에러 설계 — thiserror·anyhow 선택, From 과 ? 로 변환 모으기, 판정 결과(Ok)와 Err 구분, HTTP·큐 워커·WebSocket 경계마다 분류 지점 하나, … |
| `/rust:rust-geo-track` | Rust GPS 트랙 판정 — geo crate 거리 API·미터 평면 투영, 방향 게이트·순서 체크포인트·corridor 커버리지 구간 판정, 순간이동·과속·시간 역행 탐지, 수치 안정성, … |
| `/rust:rust-idioms` | Rust 관용 패턴 — Composed Method 를 ?·free fn 으로 쓰기, helper 추출 시 borrow 충돌(E0502) 회피, let-else·let chains 로 중첩 … |
| `/rust:rust-og-image-render` | Rust OG 미리보기 이미지 렌더 — resvg·usvg·tiny-skia 파이프라인, 한글 폰트 번들·keep-all 줄바꿈, SVG escape·외부 리소스 차단, CPU 오프로드·동시성 … |
| `/rust:rust-pg-queue-worker` | Postgres 테이블 큐 워커 (Rust·sqlx) — FOR UPDATE SKIP LOCKED claim, LISTEN/NOTIFY 와 polling fallback, … |
| `/rust:rust-testing` | Rust 테스트 — #[cfg(test)] 단위와 tests/ 통합 테스트 배치, proptest 속성 테스트, insta·golden fixture, #[sqlx::test] 실제 DB, … |

## Commands (1)

| 이름 | 설명 |
|---|---|
| `/rust:lint` | cargo fmt·clippy 로 이슈를 찾고 요청하면 수정합니다 |
