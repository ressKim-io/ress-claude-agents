# Terraform Validation

Terraform 코드의 best practice 및 품질을 검증합니다.

## Instructions

1. Terraform 코드를 분석합니다.
2. Best practice 준수 여부를 확인합니다.
3. 코드 품질 이슈를 식별합니다.
4. 개선 제안을 제공합니다.

## Validation Checklist

### File Structure

- [ ] 표준 파일 구조 준수 (main.tf, variables.tf, outputs.tf, versions.tf)
- [ ] 모듈별 README.md 존재
- [ ] versions.tf에 버전 제약 명시
- [ ] backend.tf 분리 (환경별)

### Variables

- [ ] 모든 변수에 description 존재
- [ ] 적절한 type 지정
- [ ] 필요한 경우 validation 블록 사용
- [ ] 민감 변수에 sensitive = true
- [ ] 기본값이 적절한 경우만 default 사용

### Naming Conventions

- [ ] 리소스 이름: snake_case
- [ ] 변수 이름: snake_case
- [ ] 로컬 변수: snake_case
- [ ] 출력 이름: snake_case
- [ ] 태그 Name: kebab-case 또는 snake_case

### Code Quality

- [ ] 하드코딩된 값 없음 (변수 또는 로컬 사용)
- [ ] 중복 코드 없음 (모듈화 또는 for_each 사용)
- [ ] 적절한 주석 존재
- [ ] 불필요한 리소스 없음

### State Management

- [ ] 원격 백엔드 설정
- [ ] State 잠금 설정 (DynamoDB)
- [ ] 암호화 활성화
- [ ] 환경별 State 분리

### Security

- [ ] 민감 정보 하드코딩 없음
- [ ] 암호화 설정 존재
- [ ] 최소 권한 원칙 적용
- [ ] 공개 접근 제한

## Best Practice Rules

### BP001: 변수 description 누락
```hcl
# Bad
variable "vpc_cidr" {
  type = string
}

# Good
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}
```

### BP002: 버전 제약 누락
```hcl
# Bad - versions.tf 없음

# Good
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

### BP003: 하드코딩된 값
```hcl
# Bad
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.medium"
}

# Good
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
}
```

### BP004: 태그 누락
```hcl
# Bad
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

# Good
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = local.common_tags
}
```

### BP005: count 대신 for_each 권장
```hcl
# Bad - count는 인덱스 기반
resource "aws_subnet" "private" {
  count      = length(var.subnet_cidrs)
  cidr_block = var.subnet_cidrs[count.index]
}

# Good - for_each는 키 기반 (안정적)
resource "aws_subnet" "private" {
  for_each   = toset(var.subnet_cidrs)
  cidr_block = each.value
}
```

### BP006: 출력값 누락
```hcl
# 모듈은 주요 리소스의 ID, ARN 등을 출력해야 함
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.main.arn
}
```

## Format Check

```bash
# 포맷 확인
terraform fmt -check -recursive

# 포맷 적용
terraform fmt -recursive

# 유효성 검사
terraform validate
```

## Output Format

```markdown
## Terraform Validation Report

### Summary
- Errors: 2
- Warnings: 5
- Info: 3

### Errors (수정 필수)

#### [BP001] Variable missing description
- **File**: variables.tf:15
- **Variable**: db_password
- **Fix**: description 추가

#### [BP002] Missing version constraints
- **File**: versions.tf 없음
- **Fix**: versions.tf 파일 생성 및 버전 제약 추가

### Warnings (수정 권장)

#### [BP003] Hardcoded value
- **File**: main.tf:22
- **Resource**: aws_instance.web
- **Value**: ami-12345678
- **Fix**: 변수로 추출

### Info (참고)

#### [BP004] Consider using for_each
- **File**: main.tf:45
- **Resource**: aws_subnet.private
- **Suggestion**: count 대신 for_each 사용 권장

### Format Check
- ✅ All files properly formatted

### Validate Check
- ✅ Configuration is valid
```

## Usage

```
/validate                       # 현재 디렉토리 검증
/validate modules/vpc/          # 특정 모듈만 검증
/validate --fix                 # 자동 수정 가능한 항목 수정
/validate --format              # 포맷팅도 함께 확인
```
