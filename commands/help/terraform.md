# Terraform Commands

Terraform 인프라 관리를 위한 명령어입니다.

## 명령어

### `/terraform plan-review`
plan 결과를 분석합니다.

```
/terraform plan-review              # 현재 plan 분석
/terraform plan-review plan.out     # 저장된 plan
```

**분석 항목:**
- 리소스 변경 요약
- 위험한 변경 감지 (destroy, recreate)
- 비용 영향 추정
- 의존성 분석

---

### `/terraform security`
보안 검사를 수행합니다.

```
/terraform security                 # 전체 검사
/terraform security ./modules/vpc  # 특정 모듈
/terraform security --fix           # 자동 수정
```

**검사 항목:**
- 하드코딩된 시크릿
- 과도한 IAM 권한
- 암호화 미설정
- 퍼블릭 접근 설정

---

### `/terraform module-gen`
재사용 가능한 모듈을 생성합니다.

```
/terraform module-gen vpc           # VPC 모듈
/terraform module-gen rds           # RDS 모듈
```

**생성 파일:**
- `main.tf`
- `variables.tf`
- `outputs.tf`
- `README.md`

---

### `/terraform validate`
구성을 검증합니다.

```
/terraform validate                 # 전체 검증
/terraform validate ./environments/prod
```

**검사 항목:**
- 문법 오류
- 변수 타입
- 리소스 참조
- 백엔드 설정

---

## Skills (상세 지식)

| 명령어 | 내용 |
|--------|------|
| `/terraform-modules` | 모듈 개발 패턴 |
| `/terraform-security` | 보안 베스트 프랙티스 |

---

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
