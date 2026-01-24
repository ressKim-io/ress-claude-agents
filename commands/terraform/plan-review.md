# Terraform Plan Review

terraform plan 결과를 분석하고 리뷰합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | terraform plan 결과 또는 plan 파일 |
| Output | 위험도별 변경 사항 분석 리포트 |
| Required Tools | terraform |
| Verification | 모든 Critical 변경 사항 검토 완료 |

## Analysis Categories

```
+ create    # 새 리소스 생성
- destroy   # 리소스 삭제
~ update    # 리소스 수정 (in-place)
-/+ replace # 리소스 재생성
```

## Risk Levels

### Critical (즉시 확인)
- RDS 인스턴스 삭제/재생성
- S3 버킷 삭제
- EBS 볼륨 삭제
- VPC 삭제

### High (주의 필요)
- EC2 인스턴스 재생성
- Security Group 규칙 변경
- NAT Gateway 변경

### Medium (검토 권장)
- 태그 변경
- IAM 정책 수정

## Checklist

- [ ] 데이터 손실 위험 확인
- [ ] 다운타임 발생 여부
- [ ] 보안 영향 확인
- [ ] 비용 영향 확인

## Output Format

```markdown
## Terraform Plan Review

### Summary
- Resources to create: 3
- Resources to delete: 1

### Critical Changes
⚠️ **RDS Instance 삭제 예정**
- Resource: aws_db_instance.main
- 권장: 백업 확인 후 진행
```

## Usage

```
/plan-review                 # plan 실행 후 분석
/plan-review tfplan          # 저장된 plan 분석
```
