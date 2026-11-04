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
| `/platform:backstage` | Backstage 개발자 포털 — 아키텍처, 설치·초기 설정, Software Catalog, TechDocs, 주요 플러그인 |
| `/platform:dev-prod-parity-checklist` | dev·prod 환경 parity 점검 — 6차원 비교, snowflake 환경 안티패턴, parity 강화 패턴, 자가 검증 체크리스트 |
| `/platform:developer-self-service` | 개발자 셀프서비스 — 성숙도 모델, make new-service 원커맨드 생성, Crossplane 환경 프로비저닝, Backstage Templates, Port Actions, DNS 자동 … |
| `/platform:golden-paths` | Golden Path 설계 — 원칙, 구성 요소, 서비스 템플릿, best practice |
| `/platform:golden-paths-infra` | Golden Path 인프라편 — Infrastructure 템플릿, CI/CD 파이프라인 템플릿, observability 기본값 |
| `/platform:kratix` | Kratix 플랫폼 오케스트레이터 — Promise CRD 작성, PostgreSQL·Redis as-a-Service 예제, Backstage 연동, 소규모 팀 적용 판단 |
| `/platform:platform-backstage` | Backstage 기반 플랫폼 엔지니어링 — Software Templates(Golden Path), 셀프서비스 인프라 프로비저닝, 고급 Catalog 구성, TechDocs CI 빌드 |
| `/platform:resource-budget-calculator` | 리소스 budget 계산 — 4영역 공식, 인스턴스별 vs 클러스터 합계 점검, 미계산 안티패턴, 자가 검증 체크리스트 |
| `/platform:wasm-edge` | WebAssembly 엣지 런타임 — WASM/WASI 기초, 컨테이너와 비교, WasmEdge, Spin(Fermyon), Kubernetes WASM 워크로드 |
| `/platform:wasm-edge-iot` | WASM Edge·IoT 적용 — 엣지 컴퓨팅과 IoT 배포 사례, 성능 최적화, 안티패턴, 체크리스트 |

## Agents (2)

| 이름 | 설명 |
|---|---|
| `platform:platform-engineer` | Platform Engineering *구현* 에이전트. Internal Developer Platform (IDP) 구축, Backstage 배포, Software Template 작성, … |
| `platform:platform-strategy-agent` | Internal Developer Platform(IDP) 전략 결정 에이전트 — Backstage 도입 여부, Golden Path 정의, MLOps/GPU 스케줄링/WASM Edge 등 … |
