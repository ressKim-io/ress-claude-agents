# Terraform Plan Review

terraform plan 결과를 분석하고 리뷰합니다.

## Instructions

1. `terraform plan` 결과를 분석합니다.
2. 변경 사항을 카테고리별로 분류합니다.
3. 위험 요소를 식별하고 경고합니다.
4. 리뷰 결과를 요약합니다.

## Analysis Categories

### Resource Changes
```
+ create    # 새 리소스 생성
- destroy   # 리소스 삭제
~ update    # 리소스 수정 (in-place)
-/+ replace # 리소스 재생성 (삭제 후 생성)
+/- replace # 리소스 재생성 (생성 후 삭제)
<= read     # 데이터 소스 읽기
```

### Risk Levels

#### Critical (즉시 확인 필요)
- RDS 인스턴스 삭제/재생성
- S3 버킷 삭제
- EBS 볼륨 삭제
- VPC 삭제
- IAM 역할/정책 삭제

#### High (주의 필요)
- EC2 인스턴스 재생성
- Security Group 규칙 변경
- Route Table 변경
- NAT Gateway 변경

#### Medium (검토 권장)
- 태그 변경
- 리소스 설정 변경
- IAM 정책 수정

#### Low (정보성)
- 새 리소스 추가
- 출력값 변경

## Checklist

### 데이터 손실 위험
- [ ] RDS 인스턴스가 삭제되는가?
- [ ] S3 버킷이 삭제되는가?
- [ ] EBS 볼륨이 삭제되는가?
- [ ] `prevent_destroy` 설정된 리소스가 영향받는가?

### 다운타임 위험
- [ ] EC2 인스턴스가 재생성되는가?
- [ ] RDS 인스턴스가 재생성되는가?
- [ ] NAT Gateway가 변경되는가?
- [ ] VPC/Subnet이 변경되는가?

### 보안 영향
- [ ] Security Group 인바운드 규칙이 열리는가?
- [ ] IAM 정책에 새 권한이 추가되는가?
- [ ] 암호화 설정이 변경되는가?
- [ ] Public 접근이 허용되는가?

### 비용 영향
- [ ] 새로운 유료 리소스가 생성되는가?
- [ ] 리소스 스펙이 증가하는가?
- [ ] 예약 인스턴스/스팟에서 온디맨드로 변경되는가?

## Output Format

```markdown
## Terraform Plan Review

### Summary
- Resources to create: 3
- Resources to update: 2
- Resources to delete: 1
- Resources to replace: 0

### Critical Changes (즉시 확인 필요)
⚠️ **RDS Instance 삭제 예정**
- Resource: aws_db_instance.main
- 영향: 데이터 손실 가능
- 권장: 백업 확인 후 진행

### High Priority Changes
🔶 **Security Group 규칙 변경**
- Resource: aws_security_group.web
- 변경: ingress 규칙 추가
- 검토: 0.0.0.0/0 허용 여부 확인 필요

### Resource Details

#### Creates (+)
1. aws_instance.new_web
   - AMI: ami-xxx
   - Type: t3.medium

#### Updates (~)
1. aws_security_group.web
   - ingress.0: 추가

#### Destroys (-)
1. aws_db_instance.old
   - ⚠️ 데이터 손실 위험

### Recommendations
1. RDS 삭제 전 스냅샷 생성 필요
2. Security Group 변경은 비즈니스 시간 외 적용 권장
```

## Usage

```
/plan-review                    # 현재 디렉토리에서 plan 실행 후 분석
/plan-review tfplan             # 저장된 plan 파일 분석
/plan-review --json plan.json   # JSON 형식 plan 분석
```
