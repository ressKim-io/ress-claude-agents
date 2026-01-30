# Backstage (Platform Engineering) 가이드

Internal Developer Platform (IDP), Software Catalog, Golden Paths, TechDocs

## Quick Reference (결정 트리)

```
IDP 구성요소 선택?
    │
    ├─ Software Catalog ──> 서비스/팀/API 등록 및 검색
    │       │
    │       └─ catalog-info.yaml 작성
    │
    ├─ Software Templates ─> Golden Paths (표준화된 프로젝트 생성)
    │       │
    │       └─ scaffolder-templates 작성
    │
    ├─ TechDocs ───────────> 문서 자동 생성/호스팅
    │
    └─ Plugins ────────────> K8s, ArgoCD, Prometheus 통합
```

---

## CRITICAL: Platform Engineering 원칙

```
┌─────────────────────────────────────────────────────────────────┐
│               Internal Developer Platform (IDP)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Backstage Portal                       │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐ │   │
│  │  │  Catalog    │ │  Templates  │ │     TechDocs        │ │   │
│  │  │  (검색/탐색) │ │  (생성)     │ │     (문서)          │ │   │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘ │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐ │   │
│  │  │  K8s Plugin │ │ ArgoCD      │ │   Prometheus        │ │   │
│  │  │  (운영)     │ │ (배포)      │ │   (모니터링)         │ │   │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                    ┌─────────▼─────────┐                        │
│                    │   Golden Paths    │                        │
│                    │  (표준화된 방식)   │                        │
│                    └───────────────────┘                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**핵심 가치**:
| 가치 | 설명 |
|------|------|
| **Self-Service** | 개발자가 직접 인프라 프로비저닝 |
| **Golden Paths** | 표준화된 best practice 경로 |
| **Discoverability** | 서비스/API/문서 통합 검색 |
| **Automation** | 반복 작업 자동화 |

---

## Backstage 설치

### Helm 설치

```bash
# Helm repo 추가
helm repo add backstage https://backstage.github.io/charts
helm repo update

# 설치
helm install backstage backstage/backstage \
  --namespace backstage \
  --create-namespace \
  --values backstage-values.yaml
```

### backstage-values.yaml

```yaml
# backstage-values.yaml
backstage:
  image:
    registry: ghcr.io
    repository: backstage/backstage
    tag: latest

  extraEnvVars:
    - name: POSTGRES_HOST
      value: "backstage-postgresql"
    - name: POSTGRES_USER
      value: "backstage"

  appConfig:
    app:
      title: "My Company IDP"
      baseUrl: https://backstage.example.com

    organization:
      name: "My Company"

    backend:
      baseUrl: https://backstage.example.com
      cors:
        origin: https://backstage.example.com

    # GitHub 통합
    integrations:
      github:
        - host: github.com
          token: ${GITHUB_TOKEN}

    # 카탈로그 소스
    catalog:
      import:
        entityFilename: catalog-info.yaml
        pullRequestBranchName: backstage-integration
      rules:
        - allow: [Component, System, API, Resource, Location, Template, User, Group]
      locations:
        - type: url
          target: https://github.com/myorg/software-catalog/blob/main/catalog-info.yaml
        - type: url
          target: https://github.com/myorg/templates/blob/main/all-templates.yaml

    # Kubernetes 플러그인
    kubernetes:
      serviceLocatorMethod:
        type: multiTenant
      clusterLocatorMethods:
        - type: config
          clusters:
            - url: https://kubernetes.default.svc
              name: production
              authProvider: serviceAccount
              skipTLSVerify: true
              serviceAccountToken: ${K8S_TOKEN}

postgresql:
  enabled: true
  auth:
    username: backstage
    password: backstage
    database: backstage

ingress:
  enabled: true
  className: nginx
  host: backstage.example.com
  tls:
    - secretName: backstage-tls
      hosts:
        - backstage.example.com
```

---

## Software Catalog

### catalog-info.yaml 구조

```yaml
# catalog-info.yaml - 서비스 등록
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: order-service
  title: Order Service
  description: 주문 처리 마이크로서비스
  annotations:
    # GitHub 연동
    github.com/project-slug: myorg/order-service
    # ArgoCD 연동
    argocd/app-name: order-service-prod
    # Kubernetes 연동
    backstage.io/kubernetes-id: order-service
    backstage.io/kubernetes-namespace: order
    # TechDocs
    backstage.io/techdocs-ref: dir:.
    # Prometheus
    prometheus.io/rule: "sum(rate(http_requests_total{service=\"order-service\"}[5m]))"
  tags:
    - java
    - spring-boot
    - grpc
  links:
    - url: https://grafana.example.com/d/order-service
      title: Grafana Dashboard
    - url: https://argocd.example.com/applications/order-service
      title: ArgoCD
spec:
  type: service
  lifecycle: production
  owner: team-commerce
  system: e-commerce
  dependsOn:
    - component:default/user-service
    - resource:default/order-database
  providesApis:
    - order-api
```

### System 정의

```yaml
# system.yaml - 시스템 그룹
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: e-commerce
  title: E-Commerce Platform
  description: 전자상거래 플랫폼 시스템
spec:
  owner: team-platform
  domain: commerce
```

### API 정의

```yaml
# api.yaml - API 스펙
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: order-api
  title: Order API
  description: 주문 생성 및 조회 API
  tags:
    - rest
    - orders
spec:
  type: openapi
  lifecycle: production
  owner: team-commerce
  system: e-commerce
  definition:
    $text: https://raw.githubusercontent.com/myorg/order-service/main/openapi.yaml
```

### Team/User 정의

```yaml
# teams.yaml
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: team-commerce
  title: Commerce Team
  description: 전자상거래 개발팀
spec:
  type: team
  children: []
  members:
    - john.doe
    - jane.smith
---
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: john.doe
  title: John Doe
spec:
  memberOf:
    - team-commerce
```

### Resource 정의 (인프라)

```yaml
# resources.yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: order-database
  title: Order Database
  description: 주문 데이터베이스 (PostgreSQL)
  annotations:
    backstage.io/kubernetes-id: order-db
    backstage.io/kubernetes-namespace: order
spec:
  type: database
  owner: team-commerce
  system: e-commerce
```

---

## Software Templates (Golden Paths)

### CRITICAL: 템플릿 구조

```yaml
# templates/spring-service/template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: spring-boot-service
  title: Spring Boot Microservice
  description: 표준 Spring Boot 마이크로서비스 프로젝트 생성
  tags:
    - java
    - spring-boot
    - recommended
spec:
  owner: team-platform
  type: service

  # 입력 파라미터
  parameters:
    - title: 서비스 정보
      required:
        - serviceName
        - owner
        - system
      properties:
        serviceName:
          title: 서비스 이름
          type: string
          description: 서비스 식별자 (예: order-service)
          pattern: '^[a-z0-9-]+$'
        description:
          title: 설명
          type: string
        owner:
          title: 담당 팀
          type: string
          ui:field: OwnerPicker
          ui:options:
            catalogFilter:
              kind: Group
        system:
          title: 소속 시스템
          type: string
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: System

    - title: 기술 옵션
      properties:
        javaVersion:
          title: Java 버전
          type: string
          default: "21"
          enum:
            - "17"
            - "21"
        database:
          title: 데이터베이스
          type: string
          enum:
            - postgresql
            - mysql
            - none
          default: postgresql
        includeKafka:
          title: Kafka 포함
          type: boolean
          default: false

    - title: 인프라 설정
      properties:
        namespace:
          title: K8s Namespace
          type: string
          default: default
        replicas:
          title: 초기 Replica 수
          type: integer
          default: 2
          minimum: 1
          maximum: 10

  # 실행 단계
  steps:
    # 1. 템플릿 코드 생성
    - id: fetch-base
      name: Fetch Base Template
      action: fetch:template
      input:
        url: ./skeleton
        values:
          serviceName: ${{ parameters.serviceName }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          system: ${{ parameters.system }}
          javaVersion: ${{ parameters.javaVersion }}
          database: ${{ parameters.database }}
          namespace: ${{ parameters.namespace }}
          replicas: ${{ parameters.replicas }}

    # 2. Kafka 템플릿 추가 (선택)
    - id: fetch-kafka
      name: Fetch Kafka Config
      if: ${{ parameters.includeKafka }}
      action: fetch:template
      input:
        url: ./kafka-addon
        targetPath: ./src/main/java/kafka

    # 3. GitHub 저장소 생성
    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: ['github.com']
        repoUrl: github.com?owner=myorg&repo=${{ parameters.serviceName }}
        repoVisibility: internal
        defaultBranch: main
        description: ${{ parameters.description }}
        topics:
          - spring-boot
          - microservice
          - ${{ parameters.system }}

    # 4. ArgoCD Application 생성
    - id: create-argocd-app
      name: Create ArgoCD Application
      action: argocd:create-resources
      input:
        appName: ${{ parameters.serviceName }}
        argoInstance: production
        namespace: ${{ parameters.namespace }}
        repoUrl: https://github.com/myorg/${{ parameters.serviceName }}
        path: k8s

    # 5. Backstage 카탈로그 등록
    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

  # 출력
  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: Open in catalog
        icon: catalog
        entityRef: ${{ steps.register.output.entityRef }}
      - title: ArgoCD Application
        url: https://argocd.example.com/applications/${{ parameters.serviceName }}
```

### 템플릿 Skeleton 구조

```
templates/spring-service/
├── template.yaml
├── skeleton/
│   ├── catalog-info.yaml          # Backstage 카탈로그 메타데이터
│   ├── mkdocs.yml                 # TechDocs 설정
│   ├── docs/
│   │   └── index.md               # 문서
│   ├── src/
│   │   └── main/
│   │       └── java/
│   │           └── Application.java
│   ├── k8s/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── .github/
│   │   └── workflows/
│   │       └── ci.yaml
│   ├── Dockerfile
│   └── build.gradle
└── kafka-addon/
    └── KafkaConfig.java
```

### Skeleton 템플릿 예시

```yaml
# skeleton/catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.serviceName }}
  description: ${{ values.description }}
  annotations:
    github.com/project-slug: myorg/${{ values.serviceName }}
    backstage.io/techdocs-ref: dir:.
    backstage.io/kubernetes-id: ${{ values.serviceName }}
    backstage.io/kubernetes-namespace: ${{ values.namespace }}
spec:
  type: service
  lifecycle: production
  owner: ${{ values.owner }}
  system: ${{ values.system }}
```

```yaml
# skeleton/k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ values.serviceName }}
  labels:
    app: ${{ values.serviceName }}
    team: ${{ values.owner }}
spec:
  replicas: ${{ values.replicas }}
  selector:
    matchLabels:
      app: ${{ values.serviceName }}
  template:
    metadata:
      labels:
        app: ${{ values.serviceName }}
    spec:
      containers:
        - name: ${{ values.serviceName }}
          image: ghcr.io/myorg/${{ values.serviceName }}:latest
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

---

## TechDocs 통합

### mkdocs.yml 설정

```yaml
# mkdocs.yml (각 서비스 루트에 위치)
site_name: Order Service Documentation
site_description: 주문 서비스 기술 문서

nav:
  - Home: index.md
  - Architecture: architecture.md
  - API Reference: api.md
  - Runbook: runbook.md
  - ADRs:
      - 'ADR-001: Database Selection': adrs/001-database.md
      - 'ADR-002: Event Sourcing': adrs/002-events.md

plugins:
  - techdocs-core

markdown_extensions:
  - admonition
  - codehilite
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
```

### TechDocs 빌드 (CI)

```yaml
# .github/workflows/techdocs.yaml
name: Publish TechDocs

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install mkdocs-techdocs-core

      - name: Build TechDocs
        run: |
          mkdocs build --strict

      - name: Publish to S3
        run: |
          aws s3 sync ./site s3://techdocs-bucket/default/component/order-service/
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

## Kubernetes 플러그인

### app-config.yaml 설정

```yaml
# Kubernetes 플러그인 설정
kubernetes:
  serviceLocatorMethod:
    type: multiTenant
  clusterLocatorMethods:
    - type: config
      clusters:
        - url: https://prod-cluster.example.com
          name: production
          authProvider: serviceAccount
          serviceAccountToken: ${K8S_PROD_TOKEN}
          skipTLSVerify: false
          caData: ${K8S_PROD_CA}
        - url: https://staging-cluster.example.com
          name: staging
          authProvider: serviceAccount
          serviceAccountToken: ${K8S_STAGING_TOKEN}
  customResources:
    - group: 'argoproj.io'
      apiVersion: 'v1alpha1'
      plural: 'applications'
    - group: 'argoproj.io'
      apiVersion: 'v1alpha1'
      plural: 'rollouts'
```

### 컴포넌트 어노테이션

```yaml
# catalog-info.yaml
metadata:
  annotations:
    # K8s 리소스 연결
    backstage.io/kubernetes-id: order-service
    backstage.io/kubernetes-namespace: order
    backstage.io/kubernetes-label-selector: app=order-service
```

---

## 셀프서비스 인프라 프로비저닝

### Terraform 통합 템플릿

```yaml
# templates/terraform-rds/template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: provision-rds
  title: Provision RDS Database
  description: 셀프서비스 RDS 데이터베이스 프로비저닝
spec:
  owner: team-platform
  type: resource

  parameters:
    - title: 데이터베이스 설정
      required:
        - name
        - owner
        - environment
      properties:
        name:
          title: DB 이름
          type: string
          pattern: '^[a-z0-9-]+$'
        owner:
          title: 담당 팀
          type: string
          ui:field: OwnerPicker
        environment:
          title: 환경
          type: string
          enum:
            - dev
            - staging
            - prod
        engine:
          title: DB 엔진
          type: string
          enum:
            - postgres
            - mysql
          default: postgres
        instanceClass:
          title: 인스턴스 크기
          type: string
          enum:
            - db.t3.micro
            - db.t3.small
            - db.t3.medium
          default: db.t3.small

  steps:
    # 1. Terraform 코드 생성
    - id: fetch-terraform
      name: Generate Terraform
      action: fetch:template
      input:
        url: ./terraform
        values:
          name: ${{ parameters.name }}
          environment: ${{ parameters.environment }}
          engine: ${{ parameters.engine }}
          instanceClass: ${{ parameters.instanceClass }}

    # 2. GitOps 저장소에 PR 생성
    - id: create-pr
      name: Create PR in Infra Repo
      action: publish:github:pull-request
      input:
        repoUrl: github.com?owner=myorg&repo=terraform-infra
        branchName: provision-${{ parameters.name }}-db
        title: 'Provision RDS: ${{ parameters.name }}'
        description: |
          ## New RDS Database Request
          - **Name**: ${{ parameters.name }}
          - **Environment**: ${{ parameters.environment }}
          - **Engine**: ${{ parameters.engine }}
          - **Instance**: ${{ parameters.instanceClass }}

          Requested by: ${{ parameters.owner }}

    # 3. Backstage 리소스 등록
    - id: register
      name: Register Resource
      action: catalog:register
      input:
        catalogInfoPath: /catalog-info.yaml

  output:
    links:
      - title: Pull Request
        url: ${{ steps['create-pr'].output.remoteUrl }}
      - title: Resource in Catalog
        entityRef: ${{ steps.register.output.entityRef }}
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| Catalog 미등록 | 서비스 검색 불가 | CI에서 catalog-info.yaml 검증 |
| 템플릿 과복잡 | 사용자 혼란 | 필수 옵션만 최소화 |
| TechDocs 미작성 | 문서 없는 서비스 | 템플릿에 기본 문서 포함 |
| 플러그인 과다 | 성능 저하 | 필수 플러그인만 활성화 |
| Golden Path 없음 | 일관성 부재 | 표준 템플릿 제공 |
| 수동 인프라 요청 | 프로비저닝 지연 | 셀프서비스 템플릿 |

---

## 체크리스트

### 초기 설정
- [ ] Backstage Helm 설치
- [ ] GitHub/GitLab 통합 설정
- [ ] PostgreSQL 데이터베이스 연결
- [ ] Ingress/TLS 설정

### Software Catalog
- [ ] catalog-info.yaml 표준 정의
- [ ] System/Domain 계층 구조 설계
- [ ] API 스펙 등록 (OpenAPI)
- [ ] Team/Owner 매핑

### Software Templates
- [ ] Golden Path 템플릿 작성
- [ ] 언어/프레임워크별 템플릿
- [ ] 인프라 프로비저닝 템플릿
- [ ] GitOps 통합 (ArgoCD)

### TechDocs
- [ ] mkdocs.yml 표준 설정
- [ ] CI에서 TechDocs 빌드
- [ ] S3/GCS 스토리지 연결

### 플러그인
- [ ] Kubernetes 플러그인 설정
- [ ] ArgoCD 플러그인
- [ ] Prometheus/Grafana 연동

**관련 skill**: `/gitops-argocd`, `/cicd-devsecops`, `/k8s-helm`
