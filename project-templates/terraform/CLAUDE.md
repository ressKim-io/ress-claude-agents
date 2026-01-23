# Terraform Project - Claude Settings

AWS 인프라를 위한 Terraform 프로젝트 Claude Code 설정입니다.

## Project Structure

환경별 디렉토리 구조:
```
terraform-project/
├── modules/                     # 재사용 가능한 내부 모듈
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── eks/
│   ├── rds/
│   └── s3/
├── envs/                        # 환경별 구성
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── prod/
├── global/                      # 전역 리소스 (IAM, Route53 등)
│   ├── iam/
│   └── dns/
└── scripts/                     # 헬퍼 스크립트
```

## File Naming Convention

### 표준 파일 구성
```
main.tf          # 리소스 정의, 모듈 호출
variables.tf     # 입력 변수 선언
outputs.tf       # 출력 값 정의
versions.tf      # Terraform 및 프로바이더 버전
backend.tf       # 백엔드 설정 (환경별)
locals.tf        # 로컬 변수 (필요시)
data.tf          # 데이터 소스 (필요시)
```

### 리소스별 분리 (대규모 프로젝트)
```
vpc.tf           # VPC 관련 리소스
ec2.tf           # EC2 인스턴스
rds.tf           # RDS 데이터베이스
security.tf      # 보안 그룹
```

## Naming Conventions

### 리소스 네이밍
```hcl
# 패턴: {project}-{env}-{resource}-{description}
resource "aws_vpc" "main" {
  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  tags = {
    Name = "${var.project}-${var.environment}-private-${count.index + 1}"
  }
}
```

### 변수 네이밍
```hcl
# snake_case 사용
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}
```

### 로컬 변수
```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

## State Management

**IMPORTANT:** S3 + DynamoDB 백엔드 필수

### backend.tf
```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "envs/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### State 버킷 설정 (최초 1회)
```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "company-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

## Module Structure

### 내부 모듈 작성 규칙

```
modules/vpc/
├── main.tf          # 리소스 정의
├── variables.tf     # 입력 변수 (설명, 타입, 기본값)
├── outputs.tf       # 출력 값
├── versions.tf      # 버전 제약
└── README.md        # 사용법 문서
```

### variables.tf 예시
```hcl
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### 모듈 호출
```hcl
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr    = var.vpc_cidr
  environment = var.environment
  project     = var.project

  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}
```

## Security Best Practices

### 민감 정보 관리
```hcl
# NEVER 하드코딩 금지
# Bad
variable "db_password" {
  default = "mypassword123"  # 절대 금지!
}

# Good - AWS Secrets Manager 사용
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

# Good - 변수로 전달 (tfvars에서 제외, 환경변수 사용)
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
```

### IAM 최소 권한
```hcl
# Broad 권한 금지
# Bad
resource "aws_iam_policy" "bad" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

# Good - 최소 권한
resource "aws_iam_policy" "good" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}
```

### 암호화 필수
```hcl
# S3 버킷 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.example.arn
    }
  }
}

# RDS 암호화
resource "aws_db_instance" "example" {
  storage_encrypted = true
  kms_key_id       = aws_kms_key.example.arn
  # ...
}

# EBS 암호화
resource "aws_ebs_volume" "example" {
  encrypted  = true
  kms_key_id = aws_kms_key.example.arn
  # ...
}
```

### Security Group 규칙
```hcl
# 0.0.0.0/0 최소화
# Bad - SSH 전체 오픈
resource "aws_security_group_rule" "bad" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # 위험!
}

# Good - 특정 IP만 허용
resource "aws_security_group_rule" "good" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8"]  # VPN/사내 IP만
}
```

## Security Scanning

### tfsec 사용
```bash
# 설치
brew install tfsec

# 실행
tfsec .

# 특정 심각도 이상만
tfsec --minimum-severity HIGH .

# CI/CD 통합
tfsec --format json --out results.json .
```

### 주요 체크 항목
- AWS002: S3 버킷 로깅 미설정
- AWS004: S3 버킷 공개 접근
- AWS009: Security Group 0.0.0.0/0 허용
- AWS017: S3 버킷 암호화 미설정
- AWS018: 민감 변수 미표시
- AWS089: CloudWatch 로그 암호화 미설정

## Plan Review Checklist

### 변경 사항 검토
- [ ] 삭제되는 리소스 확인 (- 표시)
- [ ] 재생성되는 리소스 확인 (-/+ 표시)
- [ ] 예상치 못한 변경 여부
- [ ] 종속성 영향 분석

### 위험 변경 확인
- [ ] 데이터 손실 가능성 (RDS, S3 삭제)
- [ ] 다운타임 발생 여부
- [ ] 보안 그룹 변경 영향
- [ ] IAM 정책 변경 영향

## Validation Tools

```bash
# 포맷팅
terraform fmt -recursive

# 유효성 검사
terraform validate

# 보안 스캐닝
tfsec .

# Plan 검토
terraform plan -out=tfplan
terraform show tfplan
```

## Git Workflow

### .gitignore
```gitignore
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
crash.log
*.tfvars
!*.tfvars.example

# IDE
.idea/
.vscode/

# OS
.DS_Store
```

### 커밋 규칙
```
feat(vpc): add NAT gateway for private subnets
fix(rds): correct security group ingress rules
refactor(modules): extract common tags to locals
docs(readme): add module usage examples
```

## Commands

다음 명령어 사용 가능:
- `/plan-review` - terraform plan 결과 분석 및 리뷰
- `/security` - tfsec 기반 보안 검사
- `/module-gen` - 새 모듈 스케폴드 생성
- `/validate` - best practice 및 코드 품질 검증

---

*global CLAUDE.md 설정도 함께 적용됩니다*
