# /review-pr:monitoring — 모니터링 전문 PR 코드 리뷰

모니터링 영역 PR을 3개 전문 관점의 에이전트로 병렬 리뷰한다.

## 대상 파일 패턴

- `docker-compose*`, `prometheus*`, `grafana*`, `alloy*`
- `alerting/*`, `dashboards/*`, `recording-rules/*`
- OTel 설정 파일, Grafana provisioning 파일

## 실행 절차

### 1. PR diff 확인
```bash
gh pr diff <PR번호> --repo <repo>
```

### 2. 3개 에이전트 병렬 실행

**반드시 3개 에이전트를 동시에 (하나의 메시지에서) 실행한다.**

#### 전체 에이전트 공통 원칙
- **Confidence Score 필수**: 모든 발견 사항에 0-100 confidence score 부여. 50 미만은 보고하지 않음
- **모니터링 스킬 참조**: `/monitoring-metrics`, `/monitoring-grafana`, `/observability-otel`, `/observability-otel-optimization` 기반

#### Agent 1: OTel 메트릭/레이블 정합성
- subagent_type: `code-reviewer`
- 체크 항목:
  - OTel resource attributes → Prometheus 레이블 매핑 정확성
    - `service.name` → `job`, `service.namespace` 있으면 `job="ns/name"`
    - `service.instance.id` → `instance`
  - 메트릭 suffix 규칙 (`_total`, `_bucket`, `_milliseconds` vs `_seconds`)
  - OTel 기본 히스토그램 버킷 확인 (`le="2.0"` 없음 → `le="2.5"` 사용)
  - Recording rule에서 `or on() vector(0)` 패턴 사용 여부 (MSA 환경 필수)
  - Alert/recording rules의 `job` 레이블이 실제 OTel 설정과 일치하는지
  - Semantic conventions 버전 확인 (레거시 `_milliseconds` vs stable `_seconds`)
  - OTel SDK 버전과 Spring Boot dependency-management 플러그인 충돌 여부

#### Agent 2: 환경 동기화 + 보안
- subagent_type: `code-reviewer`
- 체크 항목:
  - docker-compose ↔ Terraform ↔ 앱 config 설정값 동기화
  - 포트 바인딩: ALB 뒤 컨테이너에 `127.0.0.1` 바인딩 감지 → `0.0.0.0` 필수
  - Healthcheck 프로토콜: `wget --spider` (HEAD) 사용 감지 → `wget -qO /dev/null` (GET) 대안 제안
  - CSRF trusted origins: reverse proxy(HTTPS) 뒤 Grafana 설정 누락 감지
  - Docker Compose 네트워크: `external: true` vs `name:`+`driver:` 충돌 감지
  - CD 파이프라인 timeout: waiter/polling 기본값이 배포 시간보다 큰지
  - 환경변수 참조 정합성 (docker-compose에서 사용하는 변수가 실제 존재하는지)
- **보안 체크 항목:**
  - Grafana admin credential: `existingSecret` 사용 여부, 하드코딩 비밀번호 경고
  - Prometheus/Grafana 외부 노출: NodePort/LoadBalancer 의도치 않은 노출
  - 시크릿/API 키 하드코딩 (datasource URL에 token 포함 등)
  - Grafana anonymous access 활성화 여부 확인
  - TLS 미설정 상태에서 외부 접근 허용 시 경고 (dev 한정이라도 사유 명시 요구)

#### Agent 3: Grafana 대시보드/변수 검증
- subagent_type: `code-reviewer`
- 체크 항목:
  - Cross-datasource 변수 정합성
    - Prometheus: `job="$service_name"` (namespace/name 형식)
    - Loki/Tempo: `resource.service.name="$svc"` (name만)
    - 숨겨진 파생 변수 `$svc` (regex `.*/(.+)`) 존재 여부
  - 대시보드 PromQL 쿼리의 레이블이 실제 Prometheus 레이블과 일치하는지
  - File provisioning 설정 (`updateIntervalSeconds`) 존재 여부
  - Alloy known issues: `loki.attribute.labels` v1.8.x 미작동 → `loki.process` 대안
  - GC legendFormat: `{{jvm_gc_name}}` (OTel) vs `{{action}} - {{cause}}` (Micrometer) 구분
  - Apdex 계산 시 `le="2.0"` 대신 `le="2.5"` 사용 확인

### 3. 에이전트 프롬프트 형식

각 에이전트에게 아래 형식으로 결과를 요청한다:

```
PR diff를 아래 관점에서 리뷰하라.
관점: {관점 이름}
체크 항목: {위 체크 항목 목록}

결과는 아래 형식으로 반환:
- 각 발견 사항에 severity (Blocker/Critical/Major/Minor) 부여
- 모든 발견 사항에 confidence score (0-100) 부여. 50 미만은 보고하지 않음
- 파일 경로와 line 번호 명시
- 현재 문제와 수정 제안을 구체적으로 작성
- 문제 없는 항목은 생략
- 잘된 부분은 Good Practices로 1-2개만

Confidence Score 기준:
- 90-100: 명확한 best practice 위반 (job 레이블 불일치, HEAD healthcheck)
- 70-89: 높은 확률의 문제 (CSRF 미설정, recording rule 패턴)
- 50-69: 권장 사항 (대시보드 변수 최적화)
- 50 미만: 보고하지 않음

형식:
[{severity}] {제목} (confidence: {0-100})
- 파일: {path} (line X)
- 현재: {문제 설명}
- 수정 제안: {구체적 해결 방안}
```

### 4. 종합 및 코멘트 작성

3개 에이전트 결과를 종합한다:

1. **confidence 필터링**: confidence < 50인 이슈는 제외
2. **중복 제거**: 같은 파일/라인의 동일 이슈는 하나로 병합
3. **severity 조정**: 여러 관점에서 동시 지적된 이슈는 severity 상향 고려
4. **CR-ID 순차 부여**: [CR-001]부터 번호 매김
5. **관점 태그**: 각 이슈에 어떤 관점에서 발견됐는지 표시

최종 코멘트 헤더:
```markdown
## Code Review - Claude Code (Monitoring Specialist)

> 3개 관점 병렬 리뷰: 📊 OTel 메트릭/레이블 | 🔄 환경 동기화+보안 | 📈 Grafana 대시보드
```

각 이슈 제목에 관점 태그:
```markdown
**[CR-001] 📊 job 레이블 매핑 불일치** `confidence: 95`
**[CR-002] 🔄 ALB 뒤 컨테이너 localhost 바인딩** `confidence: 90`
**[CR-003] 📈 Cross-datasource 변수 미설정** `confidence: 85`
```

### 5. PR 코멘트 게시

```bash
gh pr comment <PR번호> --repo <repo> --body "<종합된 리뷰>"
```

## 사용법

```
/review-pr:monitoring 12                       # PR #12 모니터링 리뷰 (현재 repo)
/review-pr:monitoring 12 Team-Ikujo/Goti-monitoring  # 특정 repo PR 리뷰
```

## 주의사항

- 리뷰 후 직접 코드 수정하지 않는다 (코멘트만)
- 범용 `/review-pr`에서 모니터링 파일 감지 시 자동으로 이 체크 항목이 적용됨
- 에이전트 3개를 반드시 **동시에** 실행하여 병렬성 확보
