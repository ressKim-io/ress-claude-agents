# Golden Paths 가이드

개발자를 위한 표준화된 경로 설계, 템플릿 패턴, Self-Service 구축

## Quick Reference (결정 트리)

```
Golden Path 유형?
    │
    ├─ 서비스 생성 ─────────> Service Template
    │       │
    │       ├─ Backend API ───> Spring Boot / Go
    │       ├─ Frontend ──────> React / Next.js
    │       └─ Worker ────────> K8s Job / CronJob
    │
    ├─ 인프라 프로비저닝 ───> Infrastructure Template
    │       │
    │       ├─ Database ──────> RDS / CloudSQL
    │       ├─ Cache ─────────> ElastiCache / Redis
    │       └─ Queue ─────────> SQS / Kafka
    │
    └─ 환경 구성 ───────────> Environment Template
            │
            ├─ Dev ───────────> 개발 환경
            ├─ Staging ───────> 스테이징
            └─ Production ────> 프로덕션
```

---

## CRITICAL: Golden Path 원칙

### 정의

> **Golden Path**: 개발자가 일반적인 작업을 수행할 때 따르는 사전 정의된, 권장되는 경로. 인지 부하를 줄이고 Best Practices를 자동으로 적용.

### 4가지 필수 원칙

| 원칙 | 설명 | 예시 |
|------|------|------|
| **Optional** | 강제가 아닌 선택 | 표준 외 도구 허용 |
| **Transparent** | 내부 동작이 투명 | 생성된 코드 확인 가능 |
| **Extensible** | 팀별 확장 가능 | 플러그인 추가 가능 |
| **Customizable** | 필요시 수정 가능 | 설정 오버라이드 |

### Golden Path 성숙도

```
Level 1: Documented
  └─ 위키/문서로 Best Practice 정리

Level 2: Templated
  └─ 코드 템플릿, 파이프라인 템플릿 제공

Level 3: Automated
  └─ 셀프서비스 포탈에서 원클릭 생성

Level 4: Product
  └─ 릴리스 관리, 피드백 루프, 지속 개선
```

---

## Golden Path 구성 요소

### 전체 구조

```
Golden Path = Repository Template
            + CI/CD Pipeline
            + Infrastructure as Code
            + Observability Defaults
            + Security Baseline
            + Documentation
```

### 예시: Spring Boot 서비스 Golden Path

```
spring-boot-golden-path/
│
├── 1. Repository Template
│   ├── src/main/java/...
│   ├── Dockerfile
│   ├── build.gradle
│   └── catalog-info.yaml
│
├── 2. CI/CD Pipeline
│   └── .github/workflows/
│       ├── ci.yaml           # 빌드, 테스트
│       ├── security.yaml     # SAST, SCA
│       └── deploy.yaml       # CD
│
├── 3. Infrastructure
│   └── terraform/
│       ├── database.tf       # RDS
│       ├── cache.tf          # ElastiCache
│       └── iam.tf            # IAM Role
│
├── 4. Kubernetes Manifests
│   └── helm/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── hpa.yaml
│           └── pdb.yaml
│
├── 5. Observability
│   ├── grafana/
│   │   └── dashboard.json
│   └── prometheus/
│       └── alerts.yaml
│
└── 6. Documentation
    ├── docs/
    │   ├── index.md
    │   ├── architecture.md
    │   └── runbook.md
    └── mkdocs.yml
```

---

## Service Templates

### Spring Boot API Template

```yaml
# Backstage template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: spring-boot-api
  title: Spring Boot REST API
  description: |
    Production-ready Spring Boot API with:
    - Java 21, Spring Boot 3.2+
    - PostgreSQL + Redis
    - GitHub Actions CI/CD
    - Helm + ArgoCD deployment
    - Grafana dashboards
  tags:
    - java
    - spring-boot
    - recommended
    - golden-path
spec:
  owner: group:team-platform
  type: service

  parameters:
    - title: Service Details
      required: [serviceName, owner]
      properties:
        serviceName:
          title: Service Name
          type: string
          pattern: '^[a-z][a-z0-9-]{2,30}$'
          description: 소문자, 하이픈 허용, 3-31자
        owner:
          title: Owner Team
          type: string
          ui:field: OwnerPicker
        tier:
          title: Service Tier
          type: string
          enum: ['tier-1', 'tier-2', 'tier-3']
          default: 'tier-2'
          description: |
            tier-1: 99.9% SLO, 24/7 on-call
            tier-2: 99.5% SLO, 업무시간 on-call
            tier-3: Best effort

    - title: Technical Options
      properties:
        database:
          title: Database
          type: string
          enum: ['postgresql', 'mysql', 'none']
          default: 'postgresql'
        cache:
          title: Cache
          type: boolean
          default: true
        messaging:
          title: Messaging
          type: string
          enum: ['kafka', 'sqs', 'none']
          default: 'none'

  steps:
    - id: fetch-template
      action: fetch:template
      input:
        url: ./skeleton
        values:
          serviceName: ${{ parameters.serviceName }}
          owner: ${{ parameters.owner }}
          tier: ${{ parameters.tier }}
          database: ${{ parameters.database }}
          cache: ${{ parameters.cache }}
          messaging: ${{ parameters.messaging }}

    - id: publish
      action: publish:github
      input:
        repoUrl: github.com?owner=my-org&repo=${{ parameters.serviceName }}
        defaultBranch: main

    - id: register
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: Open in Catalog
        entityRef: ${{ steps.register.output.entityRef }}
```

### Go Service Template

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: go-service
  title: Go Microservice
  description: |
    High-performance Go service with:
    - Go 1.22+, Gin framework
    - Docker multi-stage build
    - Kubernetes-native design
spec:
  owner: group:team-platform
  type: service

  parameters:
    - title: Service Details
      required: [serviceName, owner]
      properties:
        serviceName:
          title: Service Name
          type: string
          pattern: '^[a-z][a-z0-9-]{2,30}$'
        owner:
          title: Owner Team
          type: string
          ui:field: OwnerPicker

    - title: Framework
      properties:
        framework:
          title: HTTP Framework
          type: string
          enum: ['gin', 'echo', 'chi', 'stdlib']
          default: 'gin'
        grpc:
          title: Enable gRPC
          type: boolean
          default: false

  steps:
    - id: fetch-template
      action: fetch:template
      input:
        url: ./go-skeleton
        values:
          serviceName: ${{ parameters.serviceName }}
          framework: ${{ parameters.framework }}
          grpc: ${{ parameters.grpc }}
```

### React Frontend Template

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: react-frontend
  title: React Frontend Application
  description: |
    React SPA with:
    - React 18+, TypeScript
    - Vite build tool
    - Testing (Vitest, RTL)
    - CloudFront + S3 deployment
spec:
  owner: group:team-platform
  type: website

  parameters:
    - title: Application Details
      properties:
        appName:
          title: Application Name
          type: string
        owner:
          title: Owner Team
          type: string
          ui:field: OwnerPicker

    - title: Features
      properties:
        stateManagement:
          title: State Management
          type: string
          enum: ['zustand', 'redux-toolkit', 'jotai', 'none']
          default: 'zustand'
        testing:
          title: Testing Framework
          type: string
          enum: ['vitest', 'jest']
          default: 'vitest'
```

---

## Infrastructure Templates

### Database Provisioning

```hcl
# terraform/modules/database/main.tf

variable "service_name" {
  description = "Service name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "postgresql"
}

variable "instance_class" {
  description = "Instance class based on tier"
  type        = map(string)
  default = {
    "tier-1" = "db.r6g.xlarge"
    "tier-2" = "db.r6g.large"
    "tier-3" = "db.t4g.medium"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.service_name}-${var.environment}"

  engine         = var.engine
  engine_version = "15.4"
  instance_class = var.instance_class[var.tier]

  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_encrypted     = true

  multi_az               = var.environment == "prod"
  deletion_protection    = var.environment == "prod"
  skip_final_snapshot    = var.environment != "prod"

  performance_insights_enabled = true
  monitoring_interval          = 60

  tags = {
    Service     = var.service_name
    Environment = var.environment
    ManagedBy   = "terraform"
    GoldenPath  = "true"
  }
}
```

### Cache Provisioning

```hcl
# terraform/modules/cache/main.tf

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.service_name}-${var.environment}"
  description          = "Redis cache for ${var.service_name}"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.environment == "prod" ? "cache.r6g.large" : "cache.t4g.medium"
  num_cache_clusters   = var.environment == "prod" ? 2 : 1

  automatic_failover_enabled = var.environment == "prod"
  multi_az_enabled          = var.environment == "prod"

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = {
    Service     = var.service_name
    Environment = var.environment
    GoldenPath  = "true"
  }
}
```

---

## CI/CD Pipeline Templates

### GitHub Actions CI

```yaml
# .github/workflows/ci.yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: 'gradle'

      - name: Build
        run: ./gradlew build

      - name: Test
        run: ./gradlew test

      - name: Upload coverage
        uses: codecov/codecov-action@v4

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'CRITICAL,HIGH'

      - name: Run Semgrep
        uses: semgrep/semgrep-action@v1
        with:
          config: p/ci

  docker:
    needs: [build, security]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.sha }}
            ghcr.io/${{ github.repository }}:latest
```

---

## Observability Defaults

### Grafana Dashboard Template

```json
{
  "title": "${service_name} Dashboard",
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "query": "label_values(namespace)"
      }
    ]
  },
  "panels": [
    {
      "title": "Request Rate",
      "type": "timeseries",
      "targets": [{
        "expr": "sum(rate(http_server_requests_seconds_count{namespace=\"$namespace\"}[5m]))"
      }]
    },
    {
      "title": "Error Rate",
      "type": "stat",
      "targets": [{
        "expr": "sum(rate(http_server_requests_seconds_count{namespace=\"$namespace\",status=~\"5..\"}[5m])) / sum(rate(http_server_requests_seconds_count{namespace=\"$namespace\"}[5m]))"
      }]
    },
    {
      "title": "P99 Latency",
      "type": "timeseries",
      "targets": [{
        "expr": "histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket{namespace=\"$namespace\"}[5m])) by (le))"
      }]
    }
  ]
}
```

### Prometheus Alerts

```yaml
# prometheus/alerts.yaml
groups:
  - name: ${service_name}-alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_server_requests_seconds_count{namespace="${namespace}",status=~"5.."}[5m]))
          / sum(rate(http_server_requests_seconds_count{namespace="${namespace}"}[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
          service: ${service_name}
        annotations:
          summary: "High error rate for ${service_name}"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket{namespace="${namespace}"}[5m])) by (le)) > 1
        for: 10m
        labels:
          severity: warning
          service: ${service_name}
```

---

## Best Practices

### Do's ✅

| Practice | 이유 |
|----------|------|
| 80% 규칙 적용 | 대부분 케이스만 커버, 예외는 허용 |
| 개발자와 공동 설계 | 실제 필요 반영 |
| 정기 업데이트 | 보안 취약점, 버전 관리 |
| 피드백 수집 | 지속적 개선 |
| 문서화 | 선택 이유, 탈출구 명시 |

### Don'ts ❌

| Anti-Pattern | 문제 |
|--------------|------|
| 강제 채택 | 반발, 우회 |
| 과도한 추상화 | 디버깅 어려움 |
| 모든 것 표준화 | 혁신 저해 |
| 업데이트 방치 | 보안 위험 |
| 피드백 무시 | 사용자 이탈 |

---

## 체크리스트

### Golden Path 설계
- [ ] 80% 유스케이스 식별
- [ ] 팀별 요구사항 인터뷰
- [ ] 기존 Best Practice 문서화
- [ ] 탈출구(Escape Hatch) 정의

### 템플릿 구현
- [ ] Repository template
- [ ] CI/CD pipeline
- [ ] Infrastructure modules
- [ ] Observability defaults
- [ ] Security baseline

### 운영
- [ ] 분기별 템플릿 리뷰
- [ ] 보안 취약점 스캔
- [ ] 사용률 메트릭 수집
- [ ] 개발자 피드백 수집

**관련 agent**: `platform-engineer`
**관련 skill**: `/backstage`, `/gitops-argocd`

---

## Sources

- [What are Golden Paths](https://platformengineering.org/blog/what-are-golden-paths-a-guide-to-streamlining-developer-workflows)
- [Designing Golden Paths - Red Hat](https://www.redhat.com/en/blog/designing-golden-paths)
- [Golden Paths - Google Cloud](https://cloud.google.com/blog/products/application-development/golden-paths-for-engineering-execution-consistency)
- [AWS IDP Examples](https://docs.aws.amazon.com/prescriptive-guidance/latest/internal-developer-platform/examples.html)
