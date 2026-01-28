# Terraform Validation

Terraform 코드의 best practice 및 품질을 검증합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Terraform 파일 또는 디렉토리 |
| Output | 검증 리포트 및 개선 제안 |
| Required Tools | terraform |
| Verification | `terraform validate` 통과 |

## Checklist

### File Structure
- [ ] 표준 파일 구조 (main.tf, variables.tf, outputs.tf, versions.tf)
- [ ] 모듈별 README.md 존재
- [ ] versions.tf에 버전 제약 명시

### Variables
- [ ] 모든 변수에 description 존재
- [ ] 적절한 type 지정
- [ ] 필요한 경우 validation 블록
- [ ] 민감 변수에 sensitive = true

### Code Quality
- [ ] 하드코딩된 값 없음
- [ ] 중복 코드 없음
- [ ] 적절한 주석 존재

### State Management
- [ ] 원격 백엔드 설정
- [ ] State 잠금 설정
- [ ] 암호화 활성화

### Best Practice Rules
- BP001: 변수 description 누락
- BP002: 버전 제약 누락
- BP003: 하드코딩된 값
- BP004: 태그 누락
- BP005: count 대신 for_each 권장

## Output Format

```markdown
## Terraform Validation Report

### Summary
- Errors: 2
- Warnings: 5

### Errors
#### [BP001] Variable missing description
- File: variables.tf:15
- Fix: description 추가
```

## Usage

```
/validate                    # 현재 디렉토리
/validate modules/vpc/       # 특정 모듈
/validate --fix              # 자동 수정
```

## Best Practices

### Format Check

```bash
terraform fmt -check -recursive
terraform validate
```
