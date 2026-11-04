<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# service-mesh

서비스 메시 — Istio Core·Ambient·Gateway·보안·관측, Linkerd, Gateway API

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install service-mesh@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/service-mesh/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`infra/istio.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/infra/istio.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (17)

| 이름 | 설명 |
|---|---|
| `/service-mesh:istio-advanced-traffic` | Istio 고급 트래픽 — Fault Injection, Traffic Mirroring, Retry/Timeout 심화, JWT claim 라우팅, Canary·Blue-Green |
| `/service-mesh:istio-ambient` | Istio Ambient 모드 심화 — ztunnel, HBONE, Waypoint 설정, targetRefs 정책, Cilium 통합, 마이그레이션 |
| `/service-mesh:istio-core` | Istio 핵심 개념 — Sidecar vs Ambient 비교표, Ambient 제한사항, 하이브리드 구성, mTLS 강제 |
| `/service-mesh:istio-ext-authz` | Istio 외부 인증 — ExtensionProvider, CUSTOM AuthorizationPolicy, OPA·OAuth2 Proxy 연동, 다계층 정책 조합 |
| `/service-mesh:istio-gateway` | Gateway API 와 Istio Gateway 비교 허브 — 기능 매핑, 선택 기준, 마이그레이션 |
| `/service-mesh:istio-gateway-api` | Istio 에서 Kubernetes Gateway API 와 HTTPRoute 로 트래픽 라우팅 — ReferenceGrant 로 cross-namespace 허용 |
| `/service-mesh:istio-gateway-classic` | Istio 고유 Gateway + VirtualService 기반 라우팅과 TLS 설정 |
| `/service-mesh:istio-gitops` | ArgoCD 로 Istio 설치·업그레이드 — CRD sync wave, cert-manager 통합, kind 주의점, ignoreDifferences |
| `/service-mesh:istio-metrics` | Istio 메트릭 수집 — Prometheus ServiceMonitor, RED 쿼리, Telemetry API 로 메트릭 커스터마이징, Grafana 대시보드 |
| `/service-mesh:istio-multicluster` | Istio 멀티클러스터 — Multi-Primary, Primary-Remote, East-West Gateway, Shared Root CA, cross-cluster discovery |
| `/service-mesh:istio-observability` | Istio 모니터링 허브 — 모드별(sidecar/ambient) 메트릭 수집 구조, 메트릭·트레이싱·Kiali 구성요소 안내 |
| `/service-mesh:istio-otel` | Istio 와 OpenTelemetry 통합 — Telemetry API v1, ExtensionProvider, W3C Trace Context 전파, access log 를 OTel … |
| `/service-mesh:istio-pitfalls` | Istio 실전 함정 — VirtualService FQDN, AuthorizationPolicy 경로 매칭, PeerAuthentication selector, JWKS, native … |
| `/service-mesh:istio-security` | Istio 보안 — mTLS, PeerAuthentication, AuthorizationPolicy, RequestAuthentication(JWT), Zero Trust |
| `/service-mesh:istio-tracing` | Istio 분산 트레이싱 — Jaeger·Tempo 연동, span 생성, Ambient 트레이싱, access logging |
| `/service-mesh:k8s-traffic-istio` | Istio 기반 Global·Local Rate Limiting 과 Circuit Breaker 패턴 |
| `/service-mesh:linkerd` | Linkerd 서비스 메시 — Rust micro-proxy, 자동 mTLS, ServiceProfile, TrafficSplit 카나리, 멀티클러스터, Istio Ambient 와 비교 |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `service-mesh:service-mesh-expert` | Istio/Linkerd 서비스 메시 전문가 — mTLS 디버깅, 트래픽 관리(VirtualService/DestinationRule), AuthorizationPolicy, Ambient … |
