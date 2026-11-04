<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# observability

관측성 — OpenTelemetry, Prometheus, Grafana, Loki, eBPF, AIOps, 설정 리뷰

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install observability@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/observability/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`infra/monitoring.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/infra/monitoring.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (31)

| 이름 | 설명 |
|---|---|
| `/observability:aiops` | AIOps 가이드 — AI 기반 IT 운영: 이상 탐지, OpenTelemetry 통합 |
| `/observability:aiops-remediation` | AIOps: RCA & 자동 복구 — 근본 원인 분석 (RCA), 자동 복구 (Auto-Remediation) |
| `/observability:alerting-discord` | Alerting & Discord 가이드 — Prometheus AlertManager 설정 및 Discord 웹훅 연동 |
| `/observability:ebpf-observability` | eBPF Observability 가이드 — Zero-code 분산 추적: Grafana Beyla, Odigos, Cilium Hubble 활용 |
| `/observability:ebpf-observability-advanced` | eBPF Observability 고급 가이드 — Cilium Hubble, DeepFlow, 프로덕션 요구사항, OpenTelemetry 연동 |
| `/observability:kube-prometheus-stack` | kube-prometheus-stack 가이드 — Helm chart 설치, values 커스터마이징, Phase별 환경 overlay, ArgoCD 통합 |
| `/observability:logging-application-convention` | Application Logging Convention — 애플리케이션 코드에서 로그를 작성할 때 따라야 할 양식과 패턴 |
| `/observability:logging-compliance` | Compliance Logging Patterns — 결제, 개인정보, 법적 요구사항을 충족하는 로그 저장 가이드 |
| `/observability:logging-elk` | ELK Stack Log Analysis Guide — Elasticsearch + Kibana를 활용한 로그 검색/분석 가이드 (보안팀/개발팀용) |
| `/observability:logging-loki` | Loki Log Analysis Guide — Grafana Loki + LogQL을 활용한 로그 검색/분석 가이드 (보안팀/개발팀용) |
| `/observability:logging-security` | Security & Bot Detection Logging — 보안 감사, 봇/매크로 탐지, AI 공격 방어를 위한 로그 패턴 |
| `/observability:monitoring-grafana` | Grafana Monitoring Patterns — Grafana 대시보드, 알림, RBAC 설정 가이드 |
| `/observability:monitoring-logs` | Log Monitoring Patterns — Fluent Bit, Loki, 로그 파이프라인 설정 가이드 |
| `/observability:monitoring-metrics` | Metrics Monitoring Patterns — Prometheus 스케일링, Thanos, VictoriaMetrics 설정 가이드 |
| `/observability:monitoring-prometheus-operator` | Prometheus Operator CRD 패턴 가이드 — ServiceMonitor, PodMonitor, PrometheusRule CRD 패턴 및 앱 Helm chart 통합 |
| `/observability:monitoring-self-monitoring` | Observability Stack Self-Monitoring — Who watches the watchmen? — 모니터링 스택 자체의 건강 상태를 감시하는 전략과 패턴 |
| `/observability:monitoring-troubleshoot` | Monitoring Troubleshooting Guide — 알림 대응, 역할별 가이드, 트러블슈팅 패턴 |
| `/observability:observability` | Observability Patterns — 로깅, 트레이싱, 메트릭을 위한 기본 패턴 |
| `/observability:observability-alloy-to-otel` | Alloy → OTel Collector 마이그레이션 가이드 — Grafana Alloy에서 표준 OTel Collector로 전환하기 위한 컴포넌트 매핑, 설정 변환, 영향 분석 |
| `/observability:observability-cost` | Observability Cost Management — Metrics, Traces, Logs, Profiles 스택 전반의 비용 최적화 전략과 실행 가이드 |
| `/observability:observability-from-day-zero` | 관찰성을 사후 조립하지 않고 코드 작성 첫 줄부터 trace/metric/log 3-pillar를 설계하는 ODD(Observability-Driven Development) 체크리스트. … |
| `/observability:observability-genai` | GenAI Observability — OTel GenAI Semantic Conventions, LLM 호출 Tracing, Token Usage Metrics, Quality Metrics, … |
| `/observability:observability-incident-playbook` | Observability Incident Playbook — Alert 수신 -> 진단 -> RCA -> 복구 -> 포스트모템까지 E2E 인시던트 대응 워크플로우 |
| `/observability:observability-mimir-monolithic` | Mimir 싱글바이너리 (Monolithic) 모드 가이드 — 분산 모드 대비 경량, 중소 규모 배포를 위한 Mimir 모놀리식 설정 |
| `/observability:observability-otel` | OpenTelemetry Patterns — Spring Boot, Go를 위한 OpenTelemetry 설정 및 Collector 구성 |
| `/observability:observability-otel-collector-helm` | OTel Collector Helm Chart 패턴 — Kubernetes 환경별 OTel Collector 배포, ArgoCD 통합, TLS/인증 설정 |
| `/observability:observability-otel-migration` | OTel Migration Patterns — Grafana Agent → Alloy, Zipkin → OTLP, Semantic Conventions 마이그레이션 전략 및 Declarative … |
| `/observability:observability-otel-optimization` | OpenTelemetry 비용 최적화 가이드 — Kafka 버퍼 아키텍처, 데이터 볼륨 절감, Collector 모니터링 & 알림 |
| `/observability:observability-otel-scale` | OpenTelemetry 대규모 트래픽 설정 가이드 — 초당 수만~수십만 요청 환경을 위한 OTel Collector 스케일링, 샘플링 전략, 비용 최적화 |
| `/observability:observability-pyroscope` | Continuous Profiling with Pyroscope — Pyroscope 기반 Continuous Profiling: eBPF/SDK/Java Agent 통합, Span … |
| `/observability:otel-pitfalls` | OTel 실전 Pitfalls — 실전 트러블슈팅 기반 OpenTelemetry 실전 함정. SDK 버전 충돌 / label cardinality / exporter protocol / agent … |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `observability:observability-reviewer` | AI-powered observability configuration reviewer |
