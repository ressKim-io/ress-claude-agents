# /review-pr — 멀티 관점 PR 코드 리뷰

PR 코드 리뷰를 3개 관점의 에이전트로 병렬 실행하여 종합한다.

## 실행 절차

### 1. PR diff 확인
```bash
gh pr diff <PR번호> --repo <repo>
```
diff 내용을 확보한다.

### 1.5 영역 자동 감지 및 전문 리뷰 전환 (Auto-Routing)

PR diff 파일 패턴으로 영역을 판별하고, **전문 리뷰의 에이전트 구성과 체크 항목으로 교체**한다.

| 패턴 | 영역 | 동작 |
|------|------|------|
| `docker-compose*`, `prometheus*`, `grafana*`, `alloy*`, `alerting/*`, `dashboards/*`, `recording-rules/*` | monitoring | 아래 Agent 1/2/3을 `/review-pr:monitoring`의 3개 관점으로 **교체** |
| `charts/**`, `values*.yaml`, `Chart.yaml`, `templates/**`, `environments/**/*.yaml`, `infrastructure/**/*.yaml`, `gitops/**` | k8s | 아래 Agent 1/2/3을 `/review-pr:k8s`의 3개 관점으로 **교체** |
| `src/main/java/**`, `build.gradle*`, `application*.yml`, `**/test/**` | server | 기존 범용 리뷰 (향후 `/review-pr:server` 추가 예정) |

**라우팅 규칙:**
- **단일 영역 감지** → 해당 영역 전문 커맨드 파일을 읽고, 그 파일의 에이전트 구성/체크 항목으로 실행. 아래 범용 Agent 1/2/3은 무시.
- **2개 이상 영역 감지** → 범용 Agent 1/2/3 + 각 전문 커맨드의 고유 체크 항목을 해당 에이전트 프롬프트에 **추가 병합**
- **영역 감지 안 됨** → 기존 범용 리뷰 실행 (아래 Agent 1/2/3)

**구현 방법 (단일 영역 교체 시):**
1. 감지된 영역의 전문 커맨드 파일을 읽는다 (예: `.claude/commands/review-pr-k8s.md`)
2. 해당 파일의 Agent 1/2/3 정의, subagent_type, 체크 항목을 그대로 사용
3. 종합/코멘트 양식은 전문 커맨드 파일의 헤더/태그를 따름
4. 아래 "2. 3개 에이전트 병렬 실행" 섹션은 **범용 리뷰 전용** (영역 미감지 시에만 적용)

### 1.6 K8s/Helm PR 감지 및 사전 검증 (조건부)

PR diff에 아래 파일이 포함된 경우에만 실행:
- `charts/**`, `values*.yaml`, `Chart.yaml`, `templates/**`
- `environments/**/*.yaml`, `infrastructure/**/*.yaml`

**검증:**
```bash
# Helm lint
helm lint <chart-dir>/ -f <values-file> 2>&1

# Helm template 렌더링
helm template test <chart-dir>/ -f <values-file> --debug 2>&1 | grep -E "(image:|latest|securityContext|resources:)"
```

- lint 에러 → Blocker로 분류
- helm 미설치 시 graceful skip ("helm 미설치로 사전 검증 스킵" 메시지)
- 결과를 3개 에이전트 프롬프트에 추가 컨텍스트로 포함

### 2. 3개 에이전트 병렬 실행

**반드시 3개 에이전트를 동시에 (하나의 메시지에서) 실행한다.**

#### 전체 에이전트 공통 원칙
- **Best Practice 우선**: 기존 패턴이 best practice에 위반되면 기존 패턴이 아니라 best practice를 기준으로 판단
- **Confidence Score 필수**: 모든 발견 사항에 0-100 confidence score 부여. 50 미만은 보고하지 않음
- **도구 제한 단정 금지**: 특정 도구가 표준 기능을 지원하지 않는다고 확인 없이 단정하지 않음

각 에이전트에 PR diff 전체를 전달하고, 아래 관점에서 리뷰하도록 지시한다.

#### Agent 1: 보안 + 권한 (Security & Access)
- subagent_type: `security-scanner`
- 체크 항목:
  - 시크릿/credential 하드코딩
  - securityContext (runAsNonRoot, readOnlyRootFilesystem, capabilities)
  - RBAC, ServiceAccount 권한 범위
  - Network exposure (NodePort, LoadBalancer 의도치 않은 노출)
  - TLS/mTLS 설정
  - Container image tag 고정 여부 (latest 사용 경고)
  - OWASP Top 10 해당 사항
- **학습된 추가 체크 (review-gaps 기반):**
  - `image.tag: "latest"` 발견 시 **무조건 경고** — 의도적이라도 주석 사유 요구
  - `kind: "*"` 와일드카드: 2개 이상 API 그룹에서 사용 시 "전체적 최소 권한 위반" 상위 경고
  - dev 환경이라도 보안 설정 비활성화(`insecure: true`, TLS 끔 등) 시 "dev 한정" 명시 또는 대안 제시 요구
  - 비밀번호/토큰을 stdout에 직접 출력하는 스크립트 경고
  - **맥락 변경 시 severity 재평가**: 이전 PR에서 발견된 이슈라도, 현재 PR이 공격 표면을 확대(내부→외부 노출, 신규 경로 추가 등)하면 severity를 재평가하여 별도 CR-ID 부여
  - VirtualService URI prefix 매칭 정밀도: 외부 노출 서비스에서 `prefix` 단독 사용 시 `exact + prefix` 조합 권장
  - AppProject sourceRepos, destinations 와일드카드 범위 검증

#### Agent 2: 운영 + 성능 (Operations & Performance)
- subagent_type: `code-reviewer`
- 체크 항목:
  - Resource requests/limits 적정성 (OOM 가능성)
  - Health probe 설정 (startup/liveness/readiness 분리, 타이밍)
  - Logging/observability 설정 (구조화 로그, trace 연동)
  - 스케일링 설정 (HPA 메트릭, PDB)
  - 서비스 간 통신 (endpoint URL 정확성, timeout 설정)
  - 데이터 영속성 (PVC 크기, retention)
  - 장애 시 디버깅 편의 (NOTES.txt, 에러 메시지)
- **학습된 추가 체크 (review-gaps 기반):**
  - Makefile/스크립트 내 하드코딩 설정값(namespace, 서비스명, 포트 등) → 변수 중앙화 가능 여부 체크
  - 스크립트 안전성: `trap` cleanup, background process 정리, 변수 quoting(`"${VAR}"`)
  - 환경변수 fallback 패턴: `${VAR:-default}` 미사용 시 경고
  - Makefile 변수 선언 시 `?=` (override 허용) vs `:=` (고정) 적절성 검토
  - **Good Practice 오판 주의**: 개인 환경 정보(PC 스펙, 로컬 IP)를 "좋은 관행"으로 평가하지 않음. 팀 공유 설정 파일에는 환경 비의존적 정보만 포함되어야 함
  - Helm template 렌더링 결과 기반 실제 manifest 검증 (values만으로 놓치는 template 로직 버그)
  - Kind extraPortMappings ↔ Service NodePort 매핑 일관성

#### Agent 3: 패턴 + 일관성 (Patterns & Consistency)
- subagent_type: `code-reviewer`
- 체크 항목:
  - Values ↔ Template 정합성 (values에 정의했는데 template에서 미사용 또는 그 반대)
  - Helm chart best practices (Chart.yaml 필드, 네이밍)
  - DRY 원칙 (중복 코드/설정)
  - 네이밍 컨벤션 일관성 (서비스 주소 형식, 라벨 등)
  - 환경별 values에서 기본값 중복 정의
  - API 버전 (deprecated API 사용 여부)
  - 문서화 (주석, NOTES.txt 정확성)
- **학습된 추가 체크 (review-gaps 기반):**
  - **파일 내부 일관성**: 동일 파일 내 서비스 주소 형식 혼용 검출 (`svc` vs `svc.cluster.local` FQDN)
  - **DRY 범위 확장**: cross-file 중복뿐 아니라 **file-internal** 하드코딩 문자열도 변수 추출 가능 여부 체크
  - 변수 quoting 일관성: 같은 파일 내 `$VAR` vs `"$VAR"` vs `${VAR}` 혼용 시 경고
  - Makefile ↔ 스크립트 간 설정값 동기화 여부 (Makefile에서 export한 변수를 스크립트에서 활용하는지)
  - **기존 패턴 맹신 금지**: "기존 패턴과 동일"이라도 best practice 위반이면 최소 Minor로 지적. 예: `targetRevision: main`은 dev 한정 허용 주석 없으면 경고
  - **도구 기능 단정 금지**: YAML anchor/alias/merge key 등 표준 기능은 Go/Python YAML 파서에서 대부분 지원. "지원 안 됨"이라고 확인 없이 단정하지 않음
  - **개인 환경 정보 경고**: 설정 파일 주석에 개인 PC 스펙, 로컬 IP 등 포함 시 경고. "최소 권장 스펙"으로 일반화하거나 README로 분리 권장

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
- 90-100: 명확한 best practice 위반, 도구로 검증 가능 (latest 태그, 하드코딩 시크릿)
- 70-89: 높은 확률의 문제, 맥락에 따라 예외 가능 (resource limits 미설정)
- 50-69: 권장 사항, 프로젝트 상황에 따라 다름 (FQDN 일관성)
- 50 미만: 보고하지 않음 (noise 제거)

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
3. **severity 조정**: 여러 관점에서 동시 지적된 이슈는 severity 상향 고려. 기존 이슈라도 PR 변경으로 공격 표면이 확대된 경우 severity 재평가.
4. **CR-ID 순차 부여**: [CR-001]부터 번호 매김
5. **코멘트 양식**: `.claude/rules/code-review.md`의 PR 코멘트 양식을 따름
6. **관점 태그 추가**: 각 이슈에 어떤 관점에서 발견됐는지 표시

최종 코멘트 헤더:
```markdown
## Code Review - Claude Code (Multi-Perspective)

> 3개 관점 병렬 리뷰: 🔒 보안/권한 | ⚙️ 운영/성능 | 📐 패턴/일관성
```

각 이슈 제목에 관점 이모지 태그:
```markdown
**[CR-001] 🔒 securityContext 미설정**
**[CR-002] ⚙️ Resource limits OOM 가능성**
**[CR-003] 📐 Values-Template 불일치**
```

### 5. PR 코멘트 게시

```bash
gh pr comment <PR번호> --repo <repo> --body "<종합된 리뷰>"
```

## 사용법

```
/review-pr 12                    # PR #12 리뷰 (현재 repo)
/review-pr 12 Team-Ikujo/Goti-k8s  # 특정 repo PR 리뷰
```

## 주의사항

- 리뷰 후 직접 코드 수정하지 않는다 (코멘트만)
- Gemini 리뷰 갭 추적은 별도로 수행 (기존 루틴 유지)
- 에이전트 3개를 반드시 **동시에** 실행하여 병렬성 확보
