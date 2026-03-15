# Monitoring Rules

모니터링 관련 코드 작업 시 반드시 따라야 할 규칙.
Grafana 대시보드 JSON, Tempo/Loki/Mimir/Alloy/Pyroscope 설정, PromQL/LogQL/TraceQL 쿼리, recording/alerting rule 작업에 적용된다.

---

## 필수 참조 (MANDATORY)

모니터링 관련 코드를 작성하거나 수정하기 전, 반드시 `docs/monitoring-pitfalls.md`를 읽고 해당 섹션을 확인하라.

---

## 핵심 체크리스트 (Quick Reference)

### TraceQL

- `=~` regex에 Grafana multi-value 변수 사용 금지 → `select()`로 대체
- Tempo v2 API: tag key에 scope prefix 필수 (`resource.service.name`, `span.http.route`)
- 서비스 필터: `{resource.service.name="$svc"}` (`$service_name` 아님)

### LogQL (Loki Native OTLP)

- 로그 레벨 필터: `detected_level="ERROR"` (대문자) — `level="error"` 사용 금지
- 서비스 필터: `{service_name=~"$svc"}` — `{job=...}` 사용 금지

### PromQL

- `histogram_quantile`에 `by (le)` 필수 — 누락 시 결과 NaN
- 나눗셈에 `> 0` 보호: `/ (sum(rate(total[...])) > 0)`
- multi-value 변수는 반드시 `=~` 사용

### Recording Rule

- `or on() vector(0)` — MSA 대비 `on()` 명시 필수
- MSA 전환 시 `by (job)` 추가 필요 (현재 주석으로 표시)

### OTel Semantic Conventions

- stable conventions 사용: `http.request.method`, `http.response.status_code`
- 구버전(`http.method`, `http.status_code`) 사용 금지

### Datasource UID (고정)

- `prometheus`, `loki`, `tempo`, `pyroscope` — 변경 절대 금지

### Alloy

- River 문법 사용 (표준 OTel Collector YAML 아님)
- `loki.attribute.labels` 미작동 → Loki native OTLP + `otlp_config.index_label` 사용

### Pyroscope

- tag에 `.` 사용 불가 → `_`로 대체 (`service_name`, not `service.name`)

### Apdex

- OTel 기본 버킷에 `le="2.0"` 없음 → `le="2.5"` 사용

---

## 변수 매핑 빠른 참조

```
$service_name = job label ("{namespace}/{service-name}") → PromQL용
$svc          = hidden, regex .*/(.+) → Loki/Tempo용

PromQL:  job="$service_name"
LogQL:   {service_name=~"$svc"}
TraceQL: {resource.service.name="$svc"}
```

---

## 대시보드 수정 후 체크리스트 (MANDATORY)

대시보드 JSON을 수정한 후 반드시 아래 순서를 따른다:

1. `grafana/dashboards/` 수정 (SSOT — 원본은 여기)
2. `charts/{monitoring-chart}/dashboards/`에 복사
3. `{infra-repo}/scripts/validate/extract-queries.sh`에 새 변수 치환 추가
4. `{infra-repo}/scripts/validate/payloads/`에 새 attribute 추가
5. JSON 유효성 검증 (`jq empty` 또는 `python3 -m json.tool`)

---

## 절대 금지 사항

| 금지 행위 | 이유 |
|---|---|
| TraceQL에서 `=~` + Grafana multi-value 변수 | TraceQL plugin이 pipe-separated 변환 미지원, 400 에러 |
| Loki `level="error"` (소문자) | Native OTLP는 `detected_level="ERROR"` (대문자) |
| `histogram_quantile`에서 `by (le)` 누락 | 결과가 NaN |
| Datasource UID 변경 | 모든 대시보드 참조 깨짐 |
| Pyroscope tag에 점(`.`) 사용 | Pyroscope가 invalid로 거부 |
| OTel Java Agent + Spring Boot Starter 동시 사용 | 이중 계측 발생 |
| Tempo span_metrics에 unbounded 차원 추가 (`http.url`, `user.id`) | 카디널리티 폭발 |
| `grafana/dashboards/` 수정 없이 chart 내 JSON만 수정 | SSOT 위반, 다음 동기화 시 덮어씀 |
| `or vector(0)`에서 `on()` 생략 | MSA 전환 시 다중 서비스 환경에서 오류 |
| Alloy에서 표준 OTel Collector YAML 문법 사용 | River 문법만 동작 |
