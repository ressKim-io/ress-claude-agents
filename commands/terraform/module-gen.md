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
