# FinOps Advanced 가이드

태그 기반 비용 할당, Showback/Chargeback, 비용 이상 탐지, Infracost PR 통합

## Quick Reference (결정 트리)

```
비용 거버넌스 유형?
    │
    ├─ Showback ──────────> 비용 가시성 (인식만)
    │       │
    │       └─ Kubecost + PromQL + Grafana
    │
    ├─ Chargeback ────────> 실제 비용 청구
    │       │
    │       └─ AWS CUR + Athena + QuickSight
    │
    └─ FinOps 자동화 ──────> 이상 탐지 + 자동 대응
            │
            ├─ 비용 이상 탐지 → ML 기반 알림
            ├─ Infracost PR → IaC 비용 예측
            └─ 유휴 리소스 정리 → 자동화 스크립트
```

---

## CRITICAL: FinOps 성숙도 모델

```
┌─────────────────────────────────────────────────────────────────┐
│                    FinOps Maturity Model                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Level 1: Crawl          Level 2: Walk          Level 3: Run    │
│  ──────────────          ─────────────          ────────────    │
│  - 비용 가시성            - Showback 구현       - Chargeback     │
│  - 태그 정책 수립         - 팀별 대시보드       - 자동 최적화     │
│  - 기본 알림              - 예산 관리           - ML 비용 예측    │
│                          - Right-sizing         - IaC 비용 통합  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 핵심 지표: Unit Economics (서비스/기능당 비용)           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**FinOps 원칙 (심화)**:
| 원칙 | Level 1 | Level 3 |
|------|---------|---------|
| **비용 인식** | 월별 리포트 | 실시간 대시보드 |
| **할당** | 부서별 | 기능/서비스별 |
| **최적화** | 수동 조정 | 자동화 + 예측 |
| **거버넌스** | 가이드라인 | 정책 자동 적용 |

---

## 태그 기반 비용 할당

### CRITICAL: 필수 태그 정책

```yaml
# 필수 태그 (모든 리소스)
required_tags:
  - team           # 담당 팀
  - environment    # dev/staging/prod
  - cost-center    # 비용 귀속 부서
  - service        # 서비스명
  - owner          # 담당자 이메일

# 선택 태그
optional_tags:
  - project        # 프로젝트명
  - feature        # 기능 식별
  - expiry-date    # 만료일 (개발/테스트)
```

### Kyverno 필수 라벨 정책 (강화)

```yaml
# enforce-cost-labels.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-cost-labels
  annotations:
    policies.kyverno.io/title: Enforce Cost Labels
    policies.kyverno.io/category: FinOps
    policies.kyverno.io/severity: high
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: require-finops-labels
      match:
        any:
          - resources:
              kinds:
                - Deployment
                - StatefulSet
                - DaemonSet
      validate:
        message: >-
          FinOps 필수 라벨이 누락되었습니다: team, environment, cost-center, service.
          예시: team=backend, environment=prod, cost-center=platform, service=order-api
        pattern:
          metadata:
            labels:
              team: "?*"
              environment: "dev | staging | prod"
              cost-center: "?*"
              service: "?*"

    - name: require-owner-annotation
      match:
        any:
          - resources:
              kinds:
                - Deployment
                - StatefulSet
      validate:
        message: "owner 어노테이션이 필요합니다 (이메일 형식)"
        pattern:
          metadata:
            annotations:
              owner: "*@*.*"
```

### AWS 태그 정책 (Terraform)

```hcl
# aws-tag-policy.tf
resource "aws_organizations_policy" "cost_tags" {
  name        = "cost-allocation-tags"
  description = "Required tags for cost allocation"
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      team = {
        tag_key = {
          @@assign = "team"
        }
        enforced_for = {
          @@assign = [
            "ec2:instance",
            "ec2:volume",
            "rds:db",
            "eks:cluster",
            "s3:bucket"
          ]
        }
      }
      environment = {
        tag_key = {
          @@assign = "environment"
        }
        tag_value = {
          @@assign = ["dev", "staging", "prod"]
        }
      }
      cost-center = {
        tag_key = {
          @@assign = "cost-center"
        }
      }
    }
  })
}

# 모든 리소스에 기본 태그 적용
locals {
  default_tags = {
    team         = var.team
    environment  = var.environment
    cost-center  = var.cost_center
    service      = var.service_name
    managed-by   = "terraform"
  }
}

provider "aws" {
  default_tags {
    tags = local.default_tags
  }
}
```

---

## Showback 구현

### Kubecost 고급 설정

```yaml
# kubecost-values.yaml
kubecostModel:
  # 실제 클라우드 가격 연동
  cloudIntegrationEnabled: true

# AWS 가격 통합
cloudCost:
  enabled: true
  aws:
    enabled: true
    athenaQueryEnabled: true
    athenaBucketName: "s3://aws-cur-reports"
    athenaRegion: "ap-northeast-2"
    athenaDatabase: "athenacurcfn_cost_report"
    athenaTable: "cost_report"

# 사용자 정의 비용 할당
customCostAllocation:
  enabled: true
  # 네임스페이스 → 팀 매핑
  teamMappings:
    - namespace: "order-*"
      team: "commerce"
    - namespace: "user-*"
      team: "platform"
    - namespace: "infra-*"
      team: "sre"
```

### Showback 대시보드 (PromQL)

```promql
# 팀별 일일 비용 (CPU + Memory + Storage)
sum(
  (
    # CPU 비용
    sum(rate(container_cpu_usage_seconds_total{namespace!~"kube-system|istio-system"}[1h])) by (namespace)
    * on() group_left()
    scalar(kubecost_cpu_hourly_cost) * 24
  )
  +
  (
    # Memory 비용
    sum(container_memory_working_set_bytes{namespace!~"kube-system|istio-system"}) by (namespace)
    / 1024 / 1024 / 1024
    * on() group_left()
    scalar(kubecost_memory_hourly_cost) * 24
  )
  * on(namespace) group_left(team)
  kube_namespace_labels
) by (label_team)

# 팀별 월간 비용 추정
sum(
  kubecost_cluster_daily_cost{type!="idle"}
  * on(namespace) group_left(team)
  kube_namespace_labels
) by (label_team) * 30

# 환경별 비용 분포
sum(
  kubecost_cluster_daily_cost
  * on(namespace) group_left(environment)
  kube_namespace_labels
) by (label_environment) * 30

# 서비스별 비용 (세분화)
sum(
  kubecost_container_cost_daily
  * on(namespace, pod) group_left(service)
  kube_pod_labels
) by (label_service) * 30
```

### Grafana 대시보드 JSON

```json
{
  "title": "FinOps Showback Dashboard",
  "panels": [
    {
      "title": "팀별 월간 비용 (예상)",
      "type": "piechart",
      "targets": [{
        "expr": "sum(kubecost_cluster_daily_cost * on(namespace) group_left(team) kube_namespace_labels) by (label_team) * 30"
      }]
    },
    {
      "title": "환경별 비용 추이",
      "type": "timeseries",
      "targets": [{
        "expr": "sum(kubecost_cluster_daily_cost * on(namespace) group_left(environment) kube_namespace_labels) by (label_environment)",
        "legendFormat": "{{label_environment}}"
      }]
    },
    {
      "title": "비용 Top 10 서비스",
      "type": "bargauge",
      "targets": [{
        "expr": "topk(10, sum(kubecost_container_cost_daily * on(namespace, pod) group_left(service) kube_pod_labels) by (label_service) * 30)"
      }]
    }
  ]
}
```

---

## Chargeback 구현

### AWS CUR (Cost and Usage Report) 설정

```hcl
# aws-cur.tf
resource "aws_cur_report_definition" "cost_report" {
  report_name                = "cost-report"
  time_unit                  = "HOURLY"
  format                     = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES", "SPLIT_COST_ALLOCATION_DATA"]
  s3_bucket                  = aws_s3_bucket.cur_bucket.id
  s3_prefix                  = "cur"
  s3_region                  = "ap-northeast-2"
  additional_artifacts       = ["ATHENA"]
  refresh_closed_reports     = true
  report_versioning          = "OVERWRITE_REPORT"
}

resource "aws_s3_bucket" "cur_bucket" {
  bucket = "${var.company}-aws-cur-reports"
}

# Athena 데이터베이스 자동 생성 (AWS가 관리)
```

### Athena 쿼리 (팀별 Chargeback)

```sql
-- 팀별 월간 비용 (EC2 + EKS + RDS)
SELECT
  resource_tags_user_team AS team,
  resource_tags_user_environment AS environment,
  DATE_FORMAT(line_item_usage_start_date, '%Y-%m') AS month,
  SUM(line_item_unblended_cost) AS total_cost,
  SUM(CASE WHEN product_product_name = 'Amazon Elastic Compute Cloud'
      THEN line_item_unblended_cost ELSE 0 END) AS ec2_cost,
  SUM(CASE WHEN product_product_name = 'Amazon Elastic Container Service for Kubernetes'
      THEN line_item_unblended_cost ELSE 0 END) AS eks_cost,
  SUM(CASE WHEN product_product_name = 'Amazon Relational Database Service'
      THEN line_item_unblended_cost ELSE 0 END) AS rds_cost
FROM
  "athenacurcfn_cost_report"."cost_report"
WHERE
  line_item_usage_start_date >= DATE_ADD('month', -1, CURRENT_DATE)
  AND resource_tags_user_team IS NOT NULL
GROUP BY
  resource_tags_user_team,
  resource_tags_user_environment,
  DATE_FORMAT(line_item_usage_start_date, '%Y-%m')
ORDER BY
  total_cost DESC;

-- 태그 없는 리소스 비용 (미할당)
SELECT
  product_product_name,
  line_item_resource_id,
  SUM(line_item_unblended_cost) AS untagged_cost
FROM
  "athenacurcfn_cost_report"."cost_report"
WHERE
  line_item_usage_start_date >= DATE_ADD('month', -1, CURRENT_DATE)
  AND resource_tags_user_team IS NULL
  AND line_item_unblended_cost > 1
GROUP BY
  product_product_name,
  line_item_resource_id
ORDER BY
  untagged_cost DESC
LIMIT 100;
```

### 자동 리포트 생성 (Lambda)

```python
# chargeback_report.py
import boto3
import pandas as pd
from datetime import datetime, timedelta

def lambda_handler(event, context):
    athena = boto3.client('athena')
    s3 = boto3.client('s3')
    ses = boto3.client('ses')

    # 팀별 비용 쿼리 실행
    query = """
    SELECT
      resource_tags_user_team AS team,
      SUM(line_item_unblended_cost) AS total_cost
    FROM "athenacurcfn_cost_report"."cost_report"
    WHERE line_item_usage_start_date >= DATE_ADD('month', -1, CURRENT_DATE)
    GROUP BY resource_tags_user_team
    """

    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={'Database': 'athenacurcfn_cost_report'},
        ResultConfiguration={'OutputLocation': 's3://query-results/'}
    )

    # 결과 처리 및 이메일 발송
    # ... (결과 대기 및 CSV 생성 로직)

    return {'statusCode': 200}
```

---

## 비용 이상 탐지

### Prometheus 알림 규칙

```yaml
# finops-alerts.yaml
groups:
  - name: finops-anomaly
    rules:
      # 일일 비용 급증 (전일 대비 30% 이상)
      - alert: DailyCostSpike
        expr: |
          (
            sum(kubecost_cluster_daily_cost)
            -
            sum(kubecost_cluster_daily_cost offset 1d)
          )
          /
          sum(kubecost_cluster_daily_cost offset 1d)
          > 0.3
        for: 30m
        labels:
          severity: warning
          category: finops
        annotations:
          summary: "클러스터 일일 비용이 30% 이상 증가"
          description: |
            현재 비용: {{ $value | humanize }}% 증가
            비용 검토가 필요합니다.

      # 팀별 예산 초과
      - alert: TeamBudgetExceeded
        expr: |
          sum(
            kubecost_cluster_daily_cost
            * on(namespace) group_left(team)
            kube_namespace_labels
          ) by (label_team) * 30 > 10000
        for: 1h
        labels:
          severity: warning
          category: finops
        annotations:
          summary: "팀 {{ $labels.label_team }} 월간 예산 초과 예상"
          description: "예상 비용: ${{ $value | humanize }}"

      # 비정상적인 리소스 증가
      - alert: UnexpectedResourceGrowth
        expr: |
          (
            sum(kube_pod_info) - sum(kube_pod_info offset 1h)
          ) > 50
        for: 15m
        labels:
          severity: info
          category: finops
        annotations:
          summary: "1시간 내 Pod 50개 이상 증가"

      # 유휴 리소스 비율 과다
      - alert: HighIdleCost
        expr: |
          sum(kubecost_cluster_daily_cost{type="idle"})
          /
          sum(kubecost_cluster_daily_cost)
          > 0.3
        for: 2h
        labels:
          severity: warning
          category: finops
        annotations:
          summary: "유휴 리소스 비용이 30%를 초과"
          description: "Right-sizing 검토가 필요합니다."
```

### 비용 예측 (Prophet 기반)

```python
# cost_forecasting.py
from prophet import Prophet
import pandas as pd
from prometheus_api_client import PrometheusConnect

def forecast_cost(prometheus_url, days_ahead=30):
    prom = PrometheusConnect(url=prometheus_url)

    # 지난 90일 비용 데이터 조회
    query = 'sum(kubecost_cluster_daily_cost)'
    result = prom.custom_query_range(
        query=query,
        start_time=datetime.now() - timedelta(days=90),
        end_time=datetime.now(),
        step='1d'
    )

    # Prophet 입력 형식으로 변환
    df = pd.DataFrame({
        'ds': [r['values'][0][0] for r in result],
        'y': [float(r['values'][0][1]) for r in result]
    })

    # 예측 모델 학습
    model = Prophet(
        yearly_seasonality=False,
        weekly_seasonality=True,
        daily_seasonality=False
    )
    model.fit(df)

    # 미래 예측
    future = model.make_future_dataframe(periods=days_ahead)
    forecast = model.predict(future)

    return forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']]
```

---

## Infracost PR 통합

### GitHub Actions 워크플로우

```yaml
# .github/workflows/infracost.yaml
name: Infracost

on:
  pull_request:
    paths:
      - 'terraform/**'
      - '**/*.tf'

jobs:
  infracost:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - name: Setup Infracost
        uses: infracost/actions/setup@v3
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      # 기준선 (main 브랜치) 비용 계산
      - name: Checkout base branch
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.base.ref }}
          path: base

      - name: Generate base cost
        run: |
          infracost breakdown --path=base/terraform \
            --format=json \
            --out-file=/tmp/base.json

      # PR 브랜치 비용 계산
      - name: Checkout PR branch
        uses: actions/checkout@v4
        with:
          path: pr

      - name: Generate PR cost
        run: |
          infracost breakdown --path=pr/terraform \
            --format=json \
            --out-file=/tmp/pr.json

      # 비용 비교 및 PR 코멘트
      - name: Generate diff
        run: |
          infracost diff \
            --path=/tmp/pr.json \
            --compare-to=/tmp/base.json \
            --format=json \
            --out-file=/tmp/diff.json

      - name: Post PR comment
        run: |
          infracost comment github \
            --path=/tmp/diff.json \
            --repo=${{ github.repository }} \
            --pull-request=${{ github.event.pull_request.number }} \
            --github-token=${{ secrets.GITHUB_TOKEN }} \
            --behavior=update

      # 비용 증가 시 경고
      - name: Check cost threshold
        run: |
          DIFF=$(cat /tmp/diff.json | jq '.diffTotalMonthlyCost | tonumber')
          if (( $(echo "$DIFF > 100" | bc -l) )); then
            echo "::warning::Monthly cost increase exceeds $100"
          fi
```

### Infracost 정책 파일

```yaml
# infracost-policy.yml
version: 0.1
policies:
  # 월간 비용 증가 제한
  - name: cost-increase-limit
    resource_type: "*"
    description: "PR당 월간 비용 증가 $500 제한"
    conditions:
      - path: diffTotalMonthlyCost
        operator: gt
        value: 500
    action: deny
    message: "이 PR은 월간 비용을 $500 이상 증가시킵니다. FinOps 팀 승인이 필요합니다."

  # 고비용 인스턴스 제한
  - name: no-xlarge-instances
    resource_type: "aws_instance"
    description: "2xlarge 이상 인스턴스 승인 필요"
    conditions:
      - path: values.instance_type
        operator: regex
        value: ".*[2-9]xlarge.*"
    action: warn
    message: "대형 인스턴스 사용 시 비용 검토가 필요합니다."
```

---

## 유휴 리소스 자동 정리

### 유휴 리소스 탐지

```promql
# 미사용 PVC (마운트되지 않음)
kube_persistentvolumeclaim_status_phase{phase="Bound"}
unless on(persistentvolumeclaim, namespace)
kube_pod_spec_volumes_persistentvolumeclaims_info

# 오래된 ReplicaSet (replicas=0, 7일 이상)
kube_replicaset_spec_replicas == 0
and
(time() - kube_replicaset_created) > 86400 * 7

# 미사용 Service (Endpoint 없음)
kube_service_info
unless on(service, namespace)
kube_endpoint_address_available

# 유휴 Pod (CPU 사용률 1% 미만, 24시간 이상)
avg_over_time(
  rate(container_cpu_usage_seconds_total[5m])[24h:]
) < 0.01
and on(pod, namespace)
kube_pod_status_phase{phase="Running"}
```

### 자동 정리 CronJob

```yaml
# cleanup-idle-resources.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-idle-resources
  namespace: finops
spec:
  schedule: "0 2 * * *"  # 매일 새벽 2시
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: finops-cleanup
          containers:
            - name: cleanup
              image: bitnami/kubectl:latest
              command:
                - /bin/bash
                - -c
                - |
                  set -e

                  # 1. 완료된 Job 정리 (7일 이상)
                  kubectl get jobs --all-namespaces -o json | \
                    jq -r '.items[] | select(.status.succeeded == 1) |
                      select((now - (.status.completionTime | fromdateiso8601)) > 604800) |
                      "\(.metadata.namespace)/\(.metadata.name)"' | \
                    xargs -I {} kubectl delete job -n {}

                  # 2. Evicted Pod 정리
                  kubectl get pods --all-namespaces -o json | \
                    jq -r '.items[] | select(.status.reason == "Evicted") |
                      "\(.metadata.namespace)/\(.metadata.name)"' | \
                    xargs -I {} kubectl delete pod -n {}

                  # 3. 미사용 ConfigMap 리포트 (삭제는 수동)
                  echo "=== Orphaned ConfigMaps ===" > /tmp/report.txt
                  # 분석 로직...

          restartPolicy: OnFailure
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: finops-cleanup
  namespace: finops
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: finops-cleanup
rules:
  - apiGroups: [""]
    resources: ["pods", "configmaps", "secrets", "persistentvolumeclaims"]
    verbs: ["get", "list", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "delete"]
  - apiGroups: ["apps"]
    resources: ["replicasets"]
    verbs: ["get", "list", "delete"]
```

### AWS 유휴 리소스 정리 (Lambda)

```python
# cleanup_aws_resources.py
import boto3
from datetime import datetime, timedelta

def cleanup_idle_resources(event, context):
    ec2 = boto3.client('ec2')
    ebs = boto3.client('ec2')

    results = {
        'unattached_volumes': [],
        'old_snapshots': [],
        'unused_eips': []
    }

    # 1. 미연결 EBS 볼륨 (30일 이상)
    volumes = ec2.describe_volumes(
        Filters=[{'Name': 'status', 'Values': ['available']}]
    )['Volumes']

    for vol in volumes:
        create_time = vol['CreateTime'].replace(tzinfo=None)
        if (datetime.now() - create_time).days > 30:
            results['unattached_volumes'].append({
                'id': vol['VolumeId'],
                'size': vol['Size'],
                'created': str(create_time)
            })
            # 삭제 (주의: 실제 환경에서는 승인 프로세스 필요)
            # ec2.delete_volume(VolumeId=vol['VolumeId'])

    # 2. 미사용 Elastic IP
    addresses = ec2.describe_addresses()['Addresses']
    for addr in addresses:
        if 'InstanceId' not in addr and 'NetworkInterfaceId' not in addr:
            results['unused_eips'].append({
                'ip': addr['PublicIp'],
                'allocation_id': addr['AllocationId']
            })

    # SNS로 리포트 발송
    sns = boto3.client('sns')
    sns.publish(
        TopicArn='arn:aws:sns:ap-northeast-2:123456789:finops-alerts',
        Subject='AWS Idle Resources Report',
        Message=json.dumps(results, indent=2)
    )

    return results
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 태그 없는 리소스 | Chargeback 불가 | Kyverno 강제 정책 |
| Showback만 구현 | 책임 소재 불명확 | Chargeback 도입 |
| 월간 리포트만 | 이상 탐지 지연 | 실시간 알림 구축 |
| IaC 비용 미검토 | 예상치 못한 비용 | Infracost PR 통합 |
| 수동 정리 | 좀비 리소스 누적 | 자동 정리 CronJob |
| 과도한 자동 삭제 | 서비스 장애 위험 | 리포트 → 승인 → 삭제 |

---

## 체크리스트

### 태그 정책
- [ ] 필수 태그 정의 (team, environment, cost-center)
- [ ] Kyverno 라벨 강제 정책
- [ ] AWS Organizations 태그 정책
- [ ] 태그 준수율 대시보드

### Showback
- [ ] Kubecost 설치 및 클라우드 연동
- [ ] 팀별/환경별 대시보드 구축
- [ ] 월간 비용 리포트 자동화

### Chargeback
- [ ] AWS CUR 설정
- [ ] Athena 쿼리 최적화
- [ ] 자동 리포트 생성 (Lambda)
- [ ] 부서별 청구 프로세스

### 자동화
- [ ] 비용 이상 탐지 알림
- [ ] Infracost PR 통합
- [ ] 유휴 리소스 자동 정리
- [ ] 비용 예측 모델

**관련 skill**: `/finops`, `/k8s-autoscaling`, `/monitoring-metrics`
