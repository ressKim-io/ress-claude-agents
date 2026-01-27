# GitOps & ArgoCD 가이드

ArgoCD를 활용한 선언적 GitOps 배포 및 App of Apps 패턴

## Quick Reference (결정 트리)

```
GitOps 도구 선택?
    │
    ├─ 단일 클러스터 ────────> ArgoCD (추천)
    ├─ 멀티 클러스터 ────────> ArgoCD + ApplicationSet
    ├─ 파이프라인 통합 ──────> ArgoCD + Tekton
    └─ Flux 생태계 ─────────> Flux CD

매니페스트 관리?
    │
    ├─ 단순한 앱 ──────> Kustomize
    ├─ 복잡한 앱 ──────> Helm Chart
    └─ 멀티 환경 ──────> Kustomize + Helm
        │
        └─ App of Apps ──> 조직 전체 관리
```

---

## CRITICAL: GitOps 원칙

```
┌─────────────────────────────────────────────────────────────┐
│                    GitOps Workflow                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Git Repository (Single Source of Truth)                     │
│       │                                                      │
│       ▼                                                      │
│  ArgoCD (Reconciliation Loop)                                │
│       │                                                      │
│       ├─ Sync: Git → K8s                                    │
│       ├─ Diff: Git ↔ K8s                                    │
│       └─ Health: K8s 상태 모니터링                           │
│       │                                                      │
│       ▼                                                      │
│  Kubernetes Cluster                                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**핵심 원칙**:
| 원칙 | 설명 |
|------|------|
| **선언적** | 원하는 상태를 Git에 선언 |
| **버전 관리** | 모든 변경은 Git 커밋 |
| **자동 적용** | Git 변경 → 자동 배포 |
| **자가 치유** | Drift 감지 → 자동 복구 |

---

## ArgoCD 설치

### Helm 설치

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --set configs.params."server\.insecure"=true
```

### 초기 설정

```bash
# 초기 admin 비밀번호
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# CLI 로그인
argocd login <ARGOCD_SERVER>

# 비밀번호 변경
argocd account update-password
```

---

## Application 정의

### 기본 Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # 삭제 시 리소스도 삭제
spec:
  project: default

  source:
    repoURL: https://github.com/myorg/my-app.git
    targetRevision: main  # 브랜치, 태그, 또는 커밋 SHA
    path: k8s/overlays/prod

  destination:
    server: https://kubernetes.default.svc
    namespace: my-app

  syncPolicy:
    automated:
      prune: true      # 삭제된 리소스 정리
      selfHeal: true   # Drift 자동 복구
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Helm Chart Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-ingress
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://kubernetes.github.io/ingress-nginx
    chart: ingress-nginx
    targetRevision: 4.8.3
    helm:
      releaseName: nginx-ingress
      values: |
        controller:
          replicaCount: 2
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
      # 또는 외부 values 파일
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Kustomize Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/my-app.git
    targetRevision: main
    path: k8s/overlays/prod
    kustomize:
      images:
        - myapp=ghcr.io/myorg/myapp:v1.2.3
      namePrefix: prod-
      commonLabels:
        env: production
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-prod
```

---

## App of Apps 패턴

### CRITICAL: 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    App of Apps Pattern                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  root-app (ArgoCD Application)                               │
│       │                                                      │
│       ├── apps/                                              │
│       │   ├── app-a.yaml ──> Application A                  │
│       │   ├── app-b.yaml ──> Application B                  │
│       │   └── app-c.yaml ──> Application C                  │
│       │                                                      │
│       └── infra/                                             │
│           ├── cert-manager.yaml                              │
│           ├── ingress.yaml                                   │
│           └── monitoring.yaml                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Root Application

```yaml
# apps/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/gitops-config.git
    targetRevision: main
    path: apps  # Application 매니페스트가 있는 폴더
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Child Applications

```yaml
# apps/app-a.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-a
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/app-a.git
    targetRevision: v1.0.0  # 고정 버전 권장
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: app-a
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 폴더 구조 (권장)

```
gitops-config/
├── apps/
│   ├── root-app.yaml        # Root application
│   ├── app-a.yaml           # 비즈니스 앱
│   ├── app-b.yaml
│   └── app-c.yaml
├── infra/
│   ├── cert-manager.yaml    # 인프라 컴포넌트
│   ├── ingress-nginx.yaml
│   ├── monitoring.yaml
│   └── sealed-secrets.yaml
└── clusters/
    ├── dev/
    │   └── values.yaml
    ├── staging/
    │   └── values.yaml
    └── prod/
        └── values.yaml
```

---

## ApplicationSet (멀티 클러스터/환경)

### Generator 유형

| Generator | 용도 |
|-----------|------|
| **List** | 명시적 클러스터/환경 목록 |
| **Cluster** | 등록된 클러스터 기반 |
| **Git Directory** | Git 폴더 구조 기반 |
| **Git File** | Git 파일 내용 기반 |
| **Matrix** | Generator 조합 |

### 멀티 환경 ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            namespace: my-app-dev
            revision: develop
          - env: staging
            namespace: my-app-staging
            revision: main
          - env: prod
            namespace: my-app-prod
            revision: v1.2.3  # 프로덕션은 태그

  template:
    metadata:
      name: 'my-app-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/my-app.git
        targetRevision: '{{revision}}'
        path: k8s/overlays/{{env}}
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Git Directory Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/myorg/gitops-config.git
        revision: main
        directories:
          - path: addons/*

  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/gitops-config.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
```

---

## Sync 전략

### Sync Options

```yaml
syncPolicy:
  automated:
    prune: true           # Git에서 삭제된 리소스 정리
    selfHeal: true        # 수동 변경 되돌리기
    allowEmpty: false     # 빈 앱 허용 안함
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true      # 마지막에 정리
    - Validate=true       # 매니페스트 검증
    - ApplyOutOfSyncOnly=true  # 변경된 것만 적용
    - ServerSideApply=true     # 서버 사이드 적용
```

### Sync Waves (순서 제어)

```yaml
# 1단계: Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "-1"

---
# 2단계: ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  annotations:
    argocd.argoproj.io/sync-wave: "0"

---
# 3단계: Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

### Sync Hooks

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migration
          image: myapp-migration:latest
          command: ["./migrate.sh"]
      restartPolicy: Never
```

| Hook | 실행 시점 |
|------|----------|
| **PreSync** | Sync 전 |
| **Sync** | Sync 중 |
| **PostSync** | Sync 후 |
| **SyncFail** | Sync 실패 시 |

---

## Repository 구조 Best Practices

### CRITICAL: Config 분리

```
# 권장: 설정 저장소 분리
app-source/          # 애플리케이션 소스 코드
gitops-config/       # K8s 매니페스트 (ArgoCD가 바라봄)

# 비권장: 같은 저장소
my-app/
├── src/
└── k8s/             # CI가 이미지 태그 변경 → 무한 루프 위험
```

### 환경별 구조 (Kustomize)

```
gitops-config/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patch-resources.yaml
    └── prod/
        ├── kustomization.yaml
        ├── patch-replicas.yaml
        └── patch-resources.yaml
```

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namePrefix: prod-
namespace: my-app-prod

images:
  - name: myapp
    newName: ghcr.io/myorg/myapp
    newTag: v1.2.3

patchesStrategicMerge:
  - patch-replicas.yaml
  - patch-resources.yaml
```

---

## 프로젝트 & RBAC

### AppProject 정의

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: my-team
  namespace: argocd
spec:
  description: My Team Project

  # 허용되는 소스 저장소
  sourceRepos:
    - 'https://github.com/myorg/*'
    - 'https://charts.helm.sh/*'

  # 배포 대상 제한
  destinations:
    - namespace: 'my-team-*'
      server: https://kubernetes.default.svc
    - namespace: 'my-team-*'
      server: https://prod-cluster.example.com

  # 허용되는 리소스 종류
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'

  # 금지되는 리소스
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange

  roles:
    - name: developer
      description: Developer role
      policies:
        - p, proj:my-team:developer, applications, get, my-team/*, allow
        - p, proj:my-team:developer, applications, sync, my-team/*, allow
      groups:
        - my-team-developers
```

---

## 시크릿 관리

### Sealed Secrets

```bash
# 설치
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# Secret → SealedSecret 변환
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
```

```yaml
# sealed-secret.yaml (Git에 커밋 가능)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-secret
  namespace: my-app
spec:
  encryptedData:
    password: AgBy3i4OJSWK+...
```

### External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: my-secret
  data:
    - secretKey: password
      remoteRef:
        key: prod/myapp/db
        property: password
```

---

## 모니터링 & 알림

### Notifications 설정

```yaml
# argocd-notifications-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  template.app-sync-succeeded: |
    message: |
      {{.app.metadata.name}} 동기화 성공!
      Revision: {{.app.status.sync.revision}}
  trigger.on-sync-succeeded: |
    - when: app.status.sync.status == 'Synced'
      send: [app-sync-succeeded]
```

### Application 알림 설정

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: my-channel
    notifications.argoproj.io/subscribe.on-sync-failed.slack: alerts-channel
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 소스/설정 같은 저장소 | 무한 Sync 루프 | 설정 저장소 분리 |
| HEAD/main 직접 참조 | 예측 불가 배포 | 태그/커밋 SHA 사용 |
| selfHeal 없음 | Drift 방치 | selfHeal: true |
| 시크릿 평문 커밋 | 보안 취약 | Sealed Secrets |
| 단일 root-app | SPOF | 계층화된 App of Apps |
| Sync Wave 미사용 | 순서 문제 | Wave로 순서 제어 |

---

## 체크리스트

### 초기 설정
- [ ] ArgoCD 설치
- [ ] 저장소 연결 (SSH/HTTPS)
- [ ] AppProject 생성

### Application
- [ ] 적절한 targetRevision (태그/SHA)
- [ ] syncPolicy 설정 (automated, prune, selfHeal)
- [ ] finalizers 설정

### App of Apps
- [ ] Root Application 생성
- [ ] 폴더 구조 설계
- [ ] ApplicationSet 고려 (멀티 환경)

### 보안
- [ ] Sealed Secrets 또는 External Secrets
- [ ] AppProject로 권한 제한
- [ ] RBAC 설정

### 모니터링
- [ ] Notifications 설정
- [ ] Health 체크 확인
- [ ] Sync 상태 대시보드

**관련 skill**: `/cicd-devsecops`, `/k8s-helm`, `/deployment-strategies`
