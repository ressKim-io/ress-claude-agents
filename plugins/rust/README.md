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

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`lang/rust.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/lang/rust.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Commands (1)

| 이름 | 설명 |
|---|---|
| `/rust:lint` | cargo fmt·clippy 로 이슈를 찾고 요청하면 수정합니다 |
