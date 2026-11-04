<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# python

Python — FastAPI, Django, 비동기, 성능, 테스트

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install python@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/python/skills/<이름> <프로젝트>/.claude/skills/
```

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (6)

| 이름 | 설명 |
|---|---|
| `/python:django` | Django 웹 앱 — Django ORM, DRF, Middleware, Signals, Admin 커스터마이징, Celery, Migration, 배포 |
| `/python:fastapi` | FastAPI 서버 — Pydantic v2 스키마, lifespan, Depends 의존성 주입, async SQLAlchemy, BackgroundTasks, WebSocket, … |
| `/python:python-async` | Python asyncio — TaskGroup(구조적 동시성), aiohttp, 커넥션 풀, 동기화 primitive, uvloop, 비동기 에러 처리·디버깅 |
| `/python:python-patterns` | Python 설계 — 타입 힌트, dataclass vs Pydantic, 디자인 패턴, 의존성 주입, Context Manager, SOLID, Clean Architecture |
| `/python:python-performance` | Python 성능 최적화 — 프로파일링 도구, 메모리 최적화, 캐싱, 동시성, 직렬화, DB 쿼리·커넥션 풀, 벤치마크 |
| `/python:python-testing` | pytest 테스트 전략 — fixture·mocking, async 테스트, Testcontainers 통합 테스트, coverage, Hypothesis 속성 기반 테스트, CI |
