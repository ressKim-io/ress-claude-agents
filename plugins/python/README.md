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
| `/python:django` | Django Production Patterns — Django + DRF + Celery 기반 풀스택 웹 애플리케이션 구축 가이드 |
| `/python:fastapi` | FastAPI Production Patterns — FastAPI + Pydantic v2 + SQLAlchemy async 기반 고성능 API 서버 구축 가이드 |
| `/python:python-async` | Python Async Patterns — asyncio 기반 동시성 프로그래밍. TaskGroup, 커넥션 풀, 동기화, 에러 처리 패턴 |
| `/python:python-patterns` | Python Design Patterns — 타입 힌트, 디자인 패턴, Clean Architecture, SOLID 원칙의 Python 구현 가이드 |
| `/python:python-performance` | Python Performance Optimization — 프로파일링, 메모리 최적화, 캐싱, 동시성, 직렬화 성능 튜닝 가이드 |
| `/python:python-testing` | Python Testing Patterns — pytest 기반 테스트 전략. 단위/통합/E2E 테스트와 async 테스트 패턴 |
