# /review-pr:k8s — K8s/Helm/ArgoCD 전문 PR 코드 리뷰

K8s 영역 PR을 3개 전문 관점의 에이전트로 병렬 리뷰한다.

## 대상 파일 패턴

- `charts/**`, `values*.yaml`, `Chart.yaml`, `templates/**`
- `environments/**/*.yaml`, `infrastructure/**/*.yaml`
- `kind-config*.yaml`, `Makefile`, `scripts/*.sh`
- ArgoCD Application/ApplicationSet YAML

## 실행 절차

### 1. PR diff 확인
```bash
gh pr diff <PR번호> --repo <repo>
```

### 2. 3개 에이전트 병렬 실행

**반드시 3개 에이전트를 동시에 (하나의 메시지에서) 실행한다.**

#### 전체 에이전트 공통 원칙
- **Confidence Score 필수**: 모든 발견 사항에 0-100 confidence score 부여. 50 미만은 보고하지 않음
- **K8s 스킬 참조**: `/k8s-helm`, `/k8s-security`, `/gitops-argocd`, `/gitops-argocd-advanced`, `/gitops-argocd-helm` 기반

#### Agent 1: Helm Chart 구조 + values 검증
- subagent_type: `code-reviewer`
- 체크 항목:
  - Library Chart ↔ Application Chart 의존성 정합성 (`goti-common` 참조 확인)
  - values.yaml ↔ templates 정합성 (values 정의 → template 미사용 또는 그 반대)
  - values.schema.json 존재 여부 및 필수값 검증
  - 환경별 values에서 기본값 중복 정의 감지
  - `image.tag: "latest"` 사용 → 무조건 경고
  - YAML anchor/alias 활용 가능한 반복 패턴 감지 (Go YAML 파서 정상 지원)
  - `helm lint` 에러 여부 (실행 가능 시)
  - ArgoCD 환경에서 Helm Hook(`helm.sh/hook`) 사용 감지 → ArgoCD Hook 전환 권장
  - 멀티 환경 values 구조: `$values/` 패턴 활용 여부

#### Agent 2: ArgoCD GitOps + 보안
- subagent_type: `security-scanner`
- 체크 항목:
  - `targetRevision: main/HEAD` 사용 → dev 한정 허용 + `# dev only:` 주석 요구, prod는 Blocker
  - AppProject `kind: "*"` 와일드카드 카운트 → 2개+ API 그룹이면 최소 권한 위반 경고
  - AppProject `sourceRepos`/`destinations` 와일드카드 범위
  - RBAC `create` verb + `resourceNames` 조합 감지 → 분리 제안 (K8s API가 무시함)
  - ExternalSecret sync-wave 순서: ESO(-2 이하) → Secret → Deployment(0)
  - securityContext (runAsNonRoot, readOnlyRootFilesystem, capabilities.drop: ALL)
  - 시크릿/credential 하드코딩, image tag 고정 여부
  - dev 환경이라도 보안 비활성화(`insecure: true`) 시 사유 명시 요구
  - Bootstrap Application sync-wave 순서 논리성

#### Agent 3: 운영 + 패턴 일관성
- subagent_type: `code-reviewer`
- 체크 항목:
  - Kind extraPortMappings ↔ Service NodePort 매핑 일관성
  - 서비스 주소 FQDN 일관성 (같은 파일 내 `svc` vs `svc.cluster.local` 혼용)
  - Makefile/스크립트 내 하드코딩 namespace/포트 → 변수 중앙화
  - Makefile ↔ 스크립트 간 설정값 동기화
  - 변수 quoting 일관성 (`$VAR` vs `"$VAR"` vs `${VAR}`)
  - AWS 환경 종속값(Account ID, 리전) 하드코딩 감지 → values 변수화 권장
  - 개인 환경 정보(PC 스펙, 로컬 IP) 팀 공유 설정 파일 포함 경고
  - sync-wave 순서 논리성 (CRDs → Operators → Apps)
  - Bootstrap Application vs ApplicationSet 혼합 사용 감지
  - Resource requests/limits 적정성, Health probe 설정

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
- 90-100: 명확한 best practice 위반 (latest 태그, 하드코딩 시크릿, create+resourceNames)
- 70-89: 높은 확률의 문제 (targetRevision: main on prod, AppProject 와일드카드)
- 50-69: 권장 사항 (FQDN 일관성, YAML anchor 활용 가능)
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
## Code Review - Claude Code (K8s Specialist)

> 3개 관점 병렬 리뷰: ⎈ Helm Chart/values | 🔒 ArgoCD GitOps/보안 | ⚙️ 운영/패턴 일관성
```

각 이슈 제목에 관점 태그:
```markdown
**[CR-001] ⎈ Library Chart 의존성 불일치** `confidence: 90`
**[CR-002] 🔒 AppProject kind: "*" 와일드카드 남용** `confidence: 85`
**[CR-003] ⚙️ Kind ↔ NodePort 매핑 불일치** `confidence: 92`
```

### 5. PR 코멘트 게시

```bash
gh pr comment <PR번호> --repo <repo> --body "<종합된 리뷰>"
```

## 사용법

```
/review-pr:k8s 15                       # PR #15 K8s 리뷰 (현재 repo)
/review-pr:k8s 15 Team-Ikujo/Goti-k8s  # 특정 repo PR 리뷰
```

## 주의사항

- 리뷰 후 직접 코드 수정하지 않는다 (코멘트만)
- 범용 `/review-pr`에서 K8s 파일 감지 시 자동으로 이 체크 항목이 적용됨
- 에이전트 3개를 반드시 **동시에** 실행하여 병렬성 확보
