# 시나리오: 플랫폼 팀 환경 구축

> Backstage + ArgoCD + OpenTelemetry로 Internal Developer Platform을 구축하는 워크스루

---

## 개요

| 항목 | 내용 |
|------|------|
| **대상** | 플랫폼 엔지니어, DevOps 리드 |
| **소요 시간** | 1-2일 |
| **필요 조건** | K8s 클러스터, Helm, GitHub 조직 |
| **결과물** | Backstage 포탈 + GitOps 파이프라인 + 관측성 스택 + Golden Path |

---

## 전체 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 1     │     │  Step 2     │     │  Step 3     │
│  IDP 설계   │────►│  Backstage  │────►│  Golden Path│
│             │     │  구축        │     │  정의       │
│ platform-   │     │ /backstage  │     │ /golden-    │
│ engineer    │     │ /platform-  │     │ paths       │
│ architect   │     │ backstage   │     │ architect   │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       │
       ▼                                       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 4     │     │  Step 5     │     │  Step 6     │
│  GitOps     │────►│  관측성     │────►│  보안 기반   │
│  설정       │     │  스택 구축   │     │  라인 구축   │
│ /gitops-    │     │ otel-expert │     │ security-   │
│ argocd      │     │ /observ-    │     │ scanner     │
│ ci-optimizer│     │ ability     │     │ terraform-  │
└─────────────┘     └─────────────┘     │ reviewer    │
                                        └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  Step 7     │
                                        │  DX 측정    │
                                        │             │
                                        │ /dx-metrics │
                                        │ finops-     │
                                        │ advisor     │
                                        └─────────────┘
```

---

## Step 1: IDP 설계

**사용 도구**: `platform-engineer` + `architect-agent`

### 이렇게 요청하세요

```
"Internal Developer Platform을 설계해줘.
 - 개발팀 5-10팀, 서비스 20-50개 규모
 - 셀프서비스 목표: 개발자가 티켓 없이 환경 프로비저닝
 - 기술 스택: K8s + ArgoCD + Backstage + OTel"
```

### Claude가 하는 일

- IDP 아키텍처 설계 (셀프서비스 레이어 정의)
- 팀 구조에 맞는 서비스 카탈로그 설계
- 기술 스택 선택 근거 정리

### 예상 결과

```
IDP Architecture:
┌─────────────────────────────────────────────┐
│           Backstage (Developer Portal)       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ Catalog  │ │ Template │ │ TechDocs │    │
│  └──────────┘ └──────────┘ └──────────┘    │
├─────────────────────────────────────────────┤
│           ArgoCD (GitOps Engine)             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ App of   │ │ AppSet   │ │ Sync     │    │
│  │ Apps     │ │ Generator│ │ Policies │    │
│  └──────────┘ └──────────┘ └──────────┘    │
├─────────────────────────────────────────────┤
│           OpenTelemetry (Observability)      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ Traces   │ │ Metrics  │ │ Logs     │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└─────────────────────────────────────────────┘
```

### 체크포인트

- [ ] 셀프서비스 범위가 정의되었는가?
- [ ] 팀 구조와 권한 모델이 설계되었는가?

---

## Step 2: Backstage 구축

**사용 도구**: `/backstage` + `/platform-backstage`

### 이렇게 요청하세요

```
"Backstage Developer Portal을 구축해줘.
 - Software Catalog 설정
 - Software Templates (서비스 생성 템플릿)
 - TechDocs 통합
 - ArgoCD 플러그인 연동"
```

### Claude가 하는 일

- Backstage 설치 + 기본 설정
- Software Catalog에 기존 서비스 등록
- Software Templates 작성 (Go/Java 서비스 템플릿)
- TechDocs 설정

### 체크포인트

- [ ] Backstage에 접속 가능한가?
- [ ] Software Catalog에 서비스가 등록되었는가?
- [ ] 새 서비스 생성 템플릿이 동작하는가?

---

## Step 3: Golden Path 정의

**사용 도구**: `architect-agent` + `/golden-paths` + `/golden-paths-infra`

### 이렇게 요청하세요

```
"Golden Path를 정의해줘.
 - Go 서비스 Golden Path (헥사고날 아키텍처)
 - Java/Spring 서비스 Golden Path
 - 인프라 Golden Path (Terraform 모듈)"
```

### Claude가 하는 일

- 서비스 템플릿 표준화 (프로젝트 구조, CI/CD, 관측성 기본값)
- Backstage Software Templates에 Golden Path 반영
- 인프라 Terraform 모듈 템플릿

### 체크포인트

- [ ] Go/Java 서비스 템플릿이 Golden Path를 따르는가?
- [ ] Backstage에서 원클릭 서비스 생성이 가능한가?
- [ ] CI/CD 파이프라인이 자동 포함되는가?

---

## Step 4: GitOps 설정

**사용 도구**: `ci-optimizer` + `/gitops-argocd` + `/gitops-argocd-advanced`

### 이렇게 요청하세요

```
"ArgoCD GitOps 환경을 설정해줘.
 - App of Apps 패턴
 - 환경별 분리 (dev/staging/prod)
 - ApplicationSet으로 자동 생성
 - Sync 정책 + 시크릿 관리"
```

### Claude가 하는 일

- ArgoCD 설치 + 설정
- App of Apps 패턴으로 전체 앱 관리
- ApplicationSet Generator로 환경별 자동 생성
- Sealed Secrets 또는 External Secrets Operator 연동

### 체크포인트

- [ ] ArgoCD에서 모든 앱이 Synced 상태인가?
- [ ] Git 변경이 자동 배포되는가?
- [ ] 시크릿이 안전하게 관리되는가?

---

## Step 5: 관측성 스택 구축

**사용 도구**: `otel-expert` + `/observability-otel` + `/monitoring-grafana`

### 이렇게 요청하세요

```
"관측성 스택을 구축해줘.
 - OpenTelemetry Collector (Traces + Metrics + Logs)
 - Grafana + Prometheus + Tempo + Loki
 - Golden Path 서비스에 자동 계측 포함"
```

### Claude가 하는 일

- OTel Collector DaemonSet 배포
- Grafana 스택 설치 (Prometheus, Tempo, Loki)
- 기본 대시보드 생성 (RED 메트릭)
- 알림 규칙 설정

### 체크포인트

- [ ] Grafana 대시보드에 메트릭이 표시되는가?
- [ ] 트레이스가 수집되는가?
- [ ] 로그가 검색 가능한가?

---

## Step 6: 보안 기반라인 구축

**사용 도구**: `security-scanner` + `terraform-reviewer`

### 이렇게 요청하세요

```
"플랫폼 보안 기반라인을 설정해줘.
 - K8s Pod Security Standards
 - Kyverno 정책 (이미지 서명 검증, 리소스 제한)
 - 네트워크 정책 기본값
 - RBAC 팀별 권한"
```

### Claude가 하는 일

- Pod Security Admission 설정
- Kyverno 정책 배포 (필수 라벨, 리소스 제한, 이미지 검증)
- 기본 NetworkPolicy 적용
- 팀별 RBAC 권한 설정

### 체크포인트

- [ ] 보안 정책이 적용되었는가?
- [ ] 정책 위반 시 경고/차단이 동작하는가?
- [ ] 팀별 권한이 분리되었는가?

---

## Step 7: DX 측정 + 비용 전략

**사용 도구**: `/dx-metrics` + `finops-advisor`

### 이렇게 요청하세요

```
"IDP 효과를 측정할 DX 메트릭과 FinOps 전략을 설정해줘.
 - DORA 메트릭 (배포 빈도, 리드 타임, MTTR, 변경 실패율)
 - Time-to-First-Deploy 추적
 - Kubecost 비용 모니터링"
```

### Claude가 하는 일

- DORA 메트릭 수집 파이프라인 설정
- Backstage에 DX 대시보드 추가
- Kubecost 설치 + 팀별 비용 가시화

### 체크포인트

- [ ] DORA 메트릭이 수집되는가?
- [ ] 팀별 비용이 가시화되는가?
- [ ] 베이스라인 수치가 기록되었는가?

---

## 마무리

### 검증 방법

```bash
# Backstage 접속 확인
curl -s http://backstage.internal/api/health | jq .status

# ArgoCD 전체 앱 상태
argocd app list --output json | jq '.[].status.sync.status'

# OTel Collector 상태
kubectl get pods -n observability -l app=otel-collector

# Grafana 접속 확인
curl -s http://grafana.internal/api/health
```

### IDP 성숙도 체크리스트

```
Level 1 (기본):
  [x] Backstage 포탈 운영 중
  [x] GitOps 배포 자동화
  [x] 기본 관측성 스택

Level 2 (셀프서비스):
  [ ] Golden Path 서비스 생성 자동화
  [ ] 개발 환경 셀프 프로비저닝
  [ ] 팀별 비용 가시화

Level 3 (최적화):
  [ ] DORA 메트릭 기반 개선
  [ ] AI-assisted GitOps
  [ ] FinOps 자동화
```

### 다음 단계

- `/developer-self-service` — 셀프서비스 플랫폼 심화
- `/kratix` — Kratix Promise 기반 플랫폼 API
- `/secrets-management` — 시크릿 관리 고도화
- `/ephemeral-environments` — PR별 프리뷰 환경
- `/dx-onboarding` — 신규 개발자 온보딩 자동화
