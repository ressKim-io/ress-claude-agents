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
| `/observability:aiops` | AIOps 개요 — 성숙도 모델, ML 기반 이상 탐지(Anomaly Detection), OpenTelemetry 통합, 핵심 메트릭 |
| `/observability:aiops-remediation` | AIOps 근본 원인 분석(RCA)과 자동 복구 — 이벤트 상관 분석, auto-remediation 실행·안전장치, 복구 대시보드 |
| `/observability:alerting-discord` | Prometheus AlertManager 설정과 Discord 웹훅 연동 — receiver, route, inhibit, silence, 알림 템플릿, alert rule |
| `/observability:ebpf-observability` | eBPF 기반 zero-code 분산 추적 — Grafana Beyla, Odigos, 기존 agent 계측과의 비교, eBPF 기초 개념 |
| `/observability:ebpf-observability-advanced` | eBPF 관측 심화 — Cilium Hubble 네트워크 흐름 가시성, DeepFlow, 커널 버전 등 프로덕션 요구사항, OTel 연동 |
| `/observability:kube-prometheus-stack` | kube-prometheus-stack Helm chart — ArgoCD Application 설치, values 커스터마이징, Phase별 환경 overlay, EKS·GKE 차이, 트러블슈팅 |
| `/observability:logging-application-convention` | 애플리케이션 로깅 컨벤션 — Java·Go·Python 공통 로그 양식, 레벨 규칙, 금지 패턴, OTel TraceID 연동, 모듈별 필수 로그 포인트 |
| `/observability:logging-compliance` | 규제 대응 로그 저장 — 결제 로그(PCI-DSS, 전자금융거래법), 개인정보 접속기록(개인정보보호법), 보존·분리 아키텍처, 감사 대응 |
| `/observability:logging-elk` | ELK 로그 분석 — Elasticsearch Query DSL, 역할별 쿼리, Kibana 대시보드·알림, 인덱스 수명 관리, 보안 설정 |
| `/observability:logging-loki` | Loki 로그 분석 — LogQL 문법과 역할별 쿼리, Native OTLP vs LokiExporter, Grafana 대시보드·Alerting |
| `/observability:logging-security` | 보안 감사 로그 — 봇·매크로 탐지 신호, AI 공격 로그, 인증·인가 보안 로그, SIEM 연동, 실시간 쿼리 |
| `/observability:monitoring-grafana` | Grafana 운영 — 역할별 RBAC, 데이터소스, 대시보드 템플릿, 알림, Cross-Datasource 변수, Reverse Proxy 뒤 보안 설정 |
| `/observability:monitoring-logs` | 로그 파이프라인 — Fluent Bit 설정, Loki 설정, LogQL 패턴, OTel Collector 로그 처리, 로그 비용 최적화 |
| `/observability:monitoring-metrics` | 메트릭 스케일링 — Prometheus 장기 저장을 위한 Thanos·VictoriaMetrics 비교와 설정, OTel→Prometheus 메트릭, cardinality 관리 |
| `/observability:monitoring-prometheus-operator` | Prometheus Operator CRD — ServiceMonitor, PodMonitor, PrometheusRule 작성과 앱 Helm chart 통합, 메트릭 노출 |
| `/observability:monitoring-self-monitoring` | 모니터링 스택 자체 감시 — 독립 알림 채널, Prometheus·OTel Collector·Grafana·Loki·Tempo 헬스 점검, 증상별 컴포넌트 매핑 |
| `/observability:monitoring-troubleshoot` | 모니터링 알림 대응 — 알림 대응 프로세스, 역할별 가이드, 흔한 문제와 해결, 로그 기반 디버깅, Grafana RBAC 빠른 설정 |
| `/observability:observability` | 관측 기본 패턴 — 3 Pillars, 구조화 로깅, RED 메트릭, Context Propagation, OpenTelemetry 입문, 안티패턴 |
| `/observability:observability-alloy-to-otel` | Grafana Alloy 를 표준 OTel Collector 로 전환 — 컴포넌트 매핑, 설정 변환 도구·예시, 메트릭 호환성, 전환 시 잃는 기능 |
| `/observability:observability-cost` | 관측 비용 절감 — 메트릭·트레이스·로그·프로파일별 비용 드라이버, cardinality·샘플링·보존 최적화, 클라우드 벤더 비용 비교 |
| `/observability:observability-from-day-zero` | 관찰성 선설계(ODD) — 3-Pillar 상관관계, 코드 작성 전 결정 사항, 사후 보강 안티패턴(TraceID 누락·cardinality 폭발) |
| `/observability:observability-genai` | GenAI 관측 — OTel GenAI Semantic Conventions, LLM 호출 tracing, token usage 메트릭, RAG 파이프라인 tracing, 품질·안전 메트릭 |
| `/observability:observability-incident-playbook` | 인시던트 대응 플레이북 — 증상별 시작 도구 결정 트리, 5단계 대응 흐름, 시그널 기반 조사, runbook·회고 템플릿 |
| `/observability:observability-mimir-monolithic` | Mimir 싱글바이너리(monolithic) 모드 — 분산 모드와 선택 기준, dev·prod Helm values, OTel Collector 연동, 전환 주의점, 스케일링 한계 |
| `/observability:observability-otel` | OTel 기본 설정 — Spring Boot·Go 계측, Collector 구성, 샘플링 전략, Collector 버전 관리, Tempo v2 Scoped Tag API |
| `/observability:observability-otel-collector-helm` | OTel Collector Helm chart — 환경별 values, ArgoCD Application 통합, presets, ServiceMonitor, Kafka TLS·SASL 인증 |
| `/observability:observability-otel-migration` | OTel 마이그레이션 — Grafana Agent→Alloy, Zipkin→OTLP, Semantic Conventions 전환, Declarative Configuration 1.0.0 |
| `/observability:observability-otel-optimization` | OTel 비용·안정성 최적화 — Kafka 버퍼 아키텍처, 데이터 볼륨 절감, Collector 모니터링·알림, Alloy 알려진 이슈, HikariCP 메트릭 |
| `/observability:observability-otel-scale` | OTel 대규모 트래픽 구성 — 규모별 아키텍처, Agent DaemonSet·Gateway Deployment+HPA, tail-based sampling 설정 |
| `/observability:observability-pyroscope` | Pyroscope continuous profiling — eBPF·SDK·Java Agent 연동, Alloy 통합, Span Profiles(trace-profile 연결), OTLP … |
| `/observability:otel-pitfalls` | OpenTelemetry 실전 함정 — Spring Boot BOM 버전 충돌, Java Agent 메모리, OTLP protocol 변경, HikariCP 초기화 순서, Agent·Starter … |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `observability:observability-reviewer` | AI-powered observability configuration reviewer |
