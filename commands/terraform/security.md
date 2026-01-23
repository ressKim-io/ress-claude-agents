# Terraform Security Check

tfsec 기반으로 Terraform 코드의 보안을 검사합니다.

## Instructions

1. Terraform 코드를 분석합니다.
2. tfsec 규칙에 따라 보안 이슈를 식별합니다.
3. 심각도별로 분류하여 보고합니다.
4. 수정 방법을 제안합니다.

## Security Check Categories

### AWS - Critical

#### AWS002: S3 버킷 로깅 미설정
```hcl
# Bad
resource "aws_s3_bucket" "bad" {
  bucket = "my-bucket"
}

# Good
resource "aws_s3_bucket_logging" "good" {
  bucket        = aws_s3_bucket.main.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}
```

#### AWS004: S3 버킷 공개 접근
```hcl
# Bad
resource "aws_s3_bucket_public_access_block" "bad" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = false
  block_public_policy     = false
}

# Good
resource "aws_s3_bucket_public_access_block" "good" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

#### AWS009: Security Group 0.0.0.0/0 허용
```hcl
# Bad
resource "aws_security_group_rule" "bad" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
}

# Good
resource "aws_security_group_rule" "good" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["10.0.0.0/8"]
}
```

### AWS - High

#### AWS017: S3 버킷 암호화 미설정
```hcl
# Good
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}
```

#### AWS018: 민감 변수 미표시
```hcl
# Bad
variable "db_password" {
  type = string
}

# Good
variable "db_password" {
  type      = string
  sensitive = true
}
```

#### AWS050: RDS 암호화 미설정
```hcl
# Good
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn
}
```

### AWS - Medium

#### AWS089: CloudWatch 로그 암호화 미설정
```hcl
# Good
resource "aws_cloudwatch_log_group" "main" {
  name              = "/app/logs"
  kms_key_id        = aws_kms_key.logs.arn
  retention_in_days = 30
}
```

#### AWS092: DynamoDB 암호화 미설정
```hcl
# Good
resource "aws_dynamodb_table" "main" {
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }
}
```

## IAM Security

### 최소 권한 위반
```hcl
# Bad - 와일드카드 사용
resource "aws_iam_policy" "bad" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

# Good - 명시적 권한
resource "aws_iam_policy" "good" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}
```

### MFA 미적용
```hcl
# Good - MFA 조건 추가
resource "aws_iam_policy" "mfa_required" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:*"]
      Resource = "*"
      Condition = {
        Bool = {
          "aws:MultiFactorAuthPresent" = "true"
        }
      }
    }]
  })
}
```

## Output Format

```markdown
## Terraform Security Report

### Summary
- Critical: 2
- High: 5
- Medium: 8
- Low: 3

### Critical Issues

#### [AWS009] Security Group allows 0.0.0.0/0
- **File**: modules/ec2/security.tf:15
- **Resource**: aws_security_group_rule.ssh
- **Impact**: SSH 포트가 인터넷에 노출됨
- **Fix**:
  ```hcl
  cidr_blocks = ["10.0.0.0/8"]  # VPN/사내 IP로 제한
  ```

#### [AWS004] S3 bucket has public access
- **File**: modules/s3/main.tf:8
- **Resource**: aws_s3_bucket.uploads
- **Impact**: 버킷 내용이 공개될 수 있음
- **Fix**: public_access_block 설정 추가

### High Issues
...

### Recommendations
1. 모든 S3 버킷에 암호화 및 로깅 설정
2. Security Group은 필요한 최소 IP만 허용
3. 민감한 변수에 sensitive = true 설정
```

## Usage

```
/security                       # 현재 디렉토리 검사
/security modules/vpc/          # 특정 모듈만 검사
/security --severity HIGH       # HIGH 이상만 표시
/security --fix                 # 자동 수정 가능한 항목 수정
```
