# Terraform Commands

Terraform 인프라 관리를 위한 명령어입니다.

## 명령어

| 명령어 | 설명 |
|--------|------|
| `/terraform plan-review` | plan 결과 분석 |
| `/terraform security` | 보안 검사 |
| `/terraform module-gen` | 모듈 생성 |
| `/terraform validate` | 구성 검증 |

## 관련 Skills

| Skill | 내용 |
|-------|------|
| `/terraform-modules` | 모듈 개발 패턴 |
| `/terraform-security` | 보안 베스트 프랙티스 |

## Quick Reference

```bash
# 기본 명령어
terraform init
terraform plan -out=plan.out
terraform apply plan.out

# 검증
terraform fmt -check -recursive
terraform validate
tfsec .
checkov -d .
```
