# Terraform Security Check

tfsec 기반으로 Terraform 코드의 보안을 검사합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Terraform 파일 또는 디렉토리 |
| Output | 보안 이슈 리포트 및 수정 제안 |
| Required Tools | tfsec (optional) |
| Verification | `tfsec .` 통과 (HIGH 이상 없음) |

## Checklist

### Critical
- [ ] AWS009: Security Group 0.0.0.0/0 허용
- [ ] AWS004: S3 버킷 공개 접근
- [ ] IAM 와일드카드 권한 (*:*)

### High
- [ ] AWS017: S3 버킷 암호화 미설정
- [ ] AWS018: 민감 변수 sensitive 미설정
- [ ] AWS050: RDS 암호화 미설정

### Medium
- [ ] AWS002: S3 버킷 로깅 미설정
- [ ] AWS089: CloudWatch 로그 암호화 미설정

### IAM Security
```hcl
# Bad
Action   = "*"
Resource = "*"

# Good
Action   = ["s3:GetObject"]
Resource = "arn:aws:s3:::my-bucket/*"
```

## Output Format

```markdown
## Terraform Security Report

### Summary
- Critical: 2
- High: 5

### Critical Issues

#### [AWS009] Security Group allows 0.0.0.0/0
- File: modules/ec2/security.tf:15
- Fix: cidr_blocks = ["10.0.0.0/8"]
```

## Usage

```
/security                    # 현재 디렉토리
/security modules/vpc/       # 특정 모듈
/security --severity HIGH    # HIGH 이상만
```
