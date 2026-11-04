<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# platform

Platform Engineering — Backstage, Golden Path, 셀프서비스, Kratix, IDP 전략

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install platform@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/platform/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (10)

| 이름 | 설명 |
|---|---|
| `/platform:backstage` | Backstage 가이드 — Developer Portal 구축, Software Catalog, 기본 설치 및 설정 |
| `/platform:dev-prod-parity-checklist` | dev/staging/prod 환경 간 configuration drift와 snowflake environment 방지 체크리스트. 12-factor X + Beyond 12-factor 기반. … |
| `/platform:developer-self-service` | 개발자 셀프서비스 플랫폼 가이드 — 개발자가 티켓 없이 환경 프로비저닝, 서비스 생성, DB/시크릿/도메인을 셀프서비스하는 플랫폼 구축 |
| `/platform:golden-paths` | Golden Paths 가이드 — 개발자를 위한 표준화된 경로 설계, 템플릿 패턴 |
| `/platform:golden-paths-infra` | Golden Paths: Infrastructure & CI/CD — Infrastructure 템플릿, CI/CD 파이프라인, Observability 기본값 |
| `/platform:kratix` | Kratix 플랫폼 오케스트레이터 가이드 — Kratix Promise 기반 셀프서비스 플랫폼 API, Backstage 연동, 소규모~대규모 팀 적용 전략 |
| `/platform:platform-backstage` | Backstage Platform Engineering 가이드 — Golden Paths, Software Templates, 셀프서비스 인프라 프로비저닝 |
| `/platform:resource-budget-calculator` | 메모리/CPU/connection pool/disk budget을 per-instance와 cluster 합계로 계산하는 공식과 체크리스트. HikariCP formula, K8s … |
| `/platform:wasm-edge` | WebAssembly Edge 가이드 — WASM/WASI, WasmEdge, Spin, Kubernetes WASM 워크로드 실행 |
| `/platform:wasm-edge-iot` | WASM Edge/IoT 활용 가이드 — Edge Computing, IoT 배포, 성능 최적화 |

## Agents (2)

| 이름 | 설명 |
|---|---|
| `platform:platform-engineer` | Platform Engineering *구현* 에이전트. Internal Developer Platform (IDP) 구축, Backstage 배포, Software Template 작성, … |
| `platform:platform-strategy-agent` | Internal Developer Platform(IDP) 전략 결정 에이전트 — Backstage 도입 여부, Golden Path 정의, MLOps/GPU 스케줄링/WASM Edge 등 … |
