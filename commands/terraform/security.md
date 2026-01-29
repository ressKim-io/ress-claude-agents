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

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `command not found: tfsec` | tfsec 미설치 | `brew install tfsec` 또는 바이너리 다운로드 |
| 오탐 (false positive) 발생 | 특정 패턴 오인식 | `#tfsec:ignore:AWS009` 주석으로 무시 (사유 명시) |
| 커스텀 모듈 검사 안됨 | 모듈 다운로드 필요 | `terraform init` 먼저 실행 |
| 민감 변수 경고 | sensitive = true 누락 | variable 정의에 `sensitive = true` 추가 |
| tfsec 버전 호환성 문제 | 최신 Terraform 문법 미지원 | tfsec 최신 버전으로 업그레이드 |
| CI/CD 파이프라인 실패 | exit code 0이 아님 | `--soft-fail` 옵션 또는 severity threshold 조정 |
