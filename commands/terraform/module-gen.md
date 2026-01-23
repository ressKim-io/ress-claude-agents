# Terraform Module Generator

새로운 Terraform 모듈 스케폴드를 생성합니다.

## Instructions

1. 모듈 이름과 목적을 확인합니다.
2. 표준 파일 구조를 생성합니다.
3. 기본 변수와 출력을 정의합니다.
4. README.md를 작성합니다.

## Module Structure

```
modules/{module_name}/
├── main.tf           # 리소스 정의
├── variables.tf      # 입력 변수
├── outputs.tf        # 출력 값
├── versions.tf       # 버전 제약
├── locals.tf         # 로컬 변수 (선택)
├── data.tf           # 데이터 소스 (선택)
└── README.md         # 문서
```

## File Templates

### versions.tf
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

### variables.tf
```hcl
variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
```

### locals.tf
```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"
  
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "{module_name}"
    },
    var.tags
  )
}
```

### outputs.tf
```hcl
output "id" {
  description = "The ID of the created resource"
  value       = aws_xxx.main.id
}

output "arn" {
  description = "The ARN of the created resource"
  value       = aws_xxx.main.arn
}
```

### README.md
```markdown
# {Module Name} Module

{Module description}

## Usage

\`\`\`hcl
module "{module_name}" {
  source = "../../modules/{module_name}"

  project     = "myproject"
  environment = "prod"
}
\`\`\`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project | Project name | string | - | yes |
| environment | Environment name | string | - | yes |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| id | Resource ID |
| arn | Resource ARN |
```

## Common Module Types

### VPC Module
```hcl
# main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Tier = "private"
  })
}
```

### RDS Module
```hcl
# main.tf
resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = true
  kms_key_id           = var.kms_key_id

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = local.common_tags
}
```

### S3 Module
```hcl
# main.tf
resource "aws_s3_bucket" "main" {
  bucket = "${local.name_prefix}-${var.bucket_suffix}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## Output Format

```markdown
## Module Generated

### Created Files
- modules/vpc/main.tf
- modules/vpc/variables.tf
- modules/vpc/outputs.tf
- modules/vpc/versions.tf
- modules/vpc/locals.tf
- modules/vpc/README.md

### Next Steps
1. main.tf에 리소스 정의 추가
2. variables.tf에 필요한 변수 추가
3. outputs.tf에 출력값 정의
4. README.md 업데이트
```

## Usage

```
/module-gen vpc                 # VPC 모듈 생성
/module-gen rds                 # RDS 모듈 생성
/module-gen s3 --bucket-name    # S3 모듈 (버킷 옵션 포함)
/module-gen eks --with-addons   # EKS 모듈 (애드온 포함)
```
