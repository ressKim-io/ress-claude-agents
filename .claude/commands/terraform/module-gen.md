# Terraform Module Generator

새로운 Terraform 모듈 스케폴드를 생성합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | 모듈 이름 및 타입 |
| Output | 표준 모듈 파일 구조 |
| Required Tools | - |
| Verification | `terraform validate` 통과 |

## Checklist

### Module Structure
```
modules/{name}/
├── main.tf          # 리소스 정의
├── variables.tf     # 입력 변수
├── outputs.tf       # 출력 값
├── versions.tf      # 버전 제약
├── locals.tf        # 로컬 변수
└── README.md        # 문서
```

### File Templates

#### versions.tf
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

#### variables.tf
```hcl
variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}
```

### Common Module Types
- VPC: vpc_cidr, subnets, NAT gateway
- RDS: engine, instance_class, encryption
- S3: versioning, encryption, public access block
- EKS: node groups, addons

## Output Format

생성된 모듈 파일 구조

## Usage

```
/module-gen vpc              # VPC 모듈
/module-gen rds              # RDS 모듈
/module-gen s3               # S3 모듈
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `terraform init` 실패 | provider 버전 제약 오류 | versions.tf의 required_providers 버전 확인 |
| 모듈 경로 인식 안됨 | source 경로 오류 | 상대 경로 `./modules/name` 또는 절대 경로 확인 |
| variable validation 에러 | 조건식 문법 오류 | `condition` 표현식이 bool 반환하는지 확인 |
| output 참조 에러 | 모듈 output 미정의 | outputs.tf에 필요한 output 추가 |
| 중복 리소스 이름 | naming convention 충돌 | `${var.project}-${var.environment}` 패턴 사용 |
| provider 설정 충돌 | 모듈 내 provider 중복 정의 | 모듈은 provider 상속, 루트에서만 정의 |
