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
| `/service-mesh:istio-advanced-traffic` | Istio 고급 트래픽 관리 — Fault Injection, Traffic Mirroring, Retry/Timeout 심화, JWT Claim 라우팅, Blue-Green/Canary 패턴 |
| `/service-mesh:istio-ambient` | Istio Ambient Mode 심화 가이드 — Ambient GA (Istio 1.24+), ztunnel, HBONE, Waypoint 고급 설정, targetRefs, Cilium 통합 |
| `/service-mesh:istio-core` | Istio Core Patterns — Istio Service Mesh 핵심 개념: Sidecar vs Ambient 모드 비교 및 선택 가이드 |
| `/service-mesh:istio-ext-authz` | Istio External Authorization (ext-authz) — CUSTOM AuthorizationPolicy, OPA/외부 인증 서버 연동, 다계층 정책 조합 |
| `/service-mesh:istio-gateway` | Istio Gateway Patterns — Gateway API vs Istio Gateway 비교 허브, 트래픽 라우팅 선택 가이드 |
| `/service-mesh:istio-gateway-api` | Gateway API (K8s Native) — Kubernetes Gateway API + HTTPRoute 기반 트래픽 라우팅 |
| `/service-mesh:istio-gateway-classic` | Istio Gateway (Classic) — Istio Gateway + VirtualService 기반 트래픽 라우팅 |
| `/service-mesh:istio-gitops` | Istio GitOps 통합 가이드 — ArgoCD로 Istio 설치/관리, CRD sync wave, kind 주의점, cert-manager 통합 |
| `/service-mesh:istio-metrics` | Istio Metrics & Prometheus Integration — Istio Prometheus 연동, ServiceMonitor 설정, RED 메트릭 |
| `/service-mesh:istio-multicluster` | Istio 멀티클러스터 가이드 — Multi-Primary vs Primary-Remote, East-West Gateway, Shared Root CA, Cross-Cluster Discovery |
| `/service-mesh:istio-observability` | Istio Observability Patterns — Istio 모니터링 통합 허브: 메트릭, 트레이싱, Kiali 가이드 |
| `/service-mesh:istio-otel` | Istio + OpenTelemetry 통합 가이드 — Telemetry API v1, ExtensionProviders, W3C Trace Context, OTel Collector 연동 |
| `/service-mesh:istio-pitfalls` | Istio 실전 Pitfalls — 실전 트러블슈팅 + 보안 검증 기반 Istio 실전 함정. FQDN/AuthZ/PeerAuthentication/Gateway/sidecar injection |
| `/service-mesh:istio-security` | Istio Security 가이드 — mTLS, PeerAuthentication, AuthorizationPolicy, JWT 인증 |
| `/service-mesh:istio-tracing` | Istio Distributed Tracing — Jaeger/Tempo 연동, Span 생성, Access Logging |
| `/service-mesh:k8s-traffic-istio` | Istio Rate Limiting & Circuit Breaker — Istio 기반 Global/Local Rate Limiting, Circuit Breaker 패턴 |
| `/service-mesh:linkerd` | Linkerd Service Mesh 가이드 — Linkerd v2.17 핵심 운영 가이드: Rust micro-proxy 기반 경량 서비스 메시, 자동 mTLS, 멀티클러스터, Gateway … |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `service-mesh:service-mesh-expert` | Istio/Linkerd 서비스 메시 전문가 — mTLS 디버깅, 트래픽 관리(VirtualService/DestinationRule), AuthorizationPolicy, Ambient … |
