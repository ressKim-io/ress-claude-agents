# /review-pr:terraform — Terraform 전문 PR 코드 리뷰

Terraform PR을 3개 전문 관점의 에이전트로 병렬 리뷰한다.

## 대상 파일 패턴

- `**/*.tf`, `**/*.tfvars`
- `modules/**`, `environments/**`
- `backend.tf`, `provider.tf`, `variables.tf`, `outputs.tf`

## 실행 절차

### 1. PR diff 확인
```bash
gh pr diff <PR번호> --repo <repo>
```

### 2. 3개 에이전트 병렬 실행

**반드시 3개 에이전트를 동시에 (하나의 메시지에서) 실행한다.**

#### 전체 에이전트 공통 원칙
- **Confidence Score 필수**: 모든 발견 사항에 0-100 confidence score 부여. 50 미만은 보고하지 않음
- **Terraform 스킬 참조**: `infrastructure/terraform-pitfalls`, `infrastructure/eks-pitfalls` 기반
- **한국어**로 리뷰 결과 작성

#### Agent 1: 보안/IAM 검증
- subagent_type: `terraform-reviewer`
- 체크 항목:
  - Security Group inline + separate rule 혼용 감지
  - IAM policy 누락 (EKS 필수 정책: `AmazonEKSClusterPolicy`, `AmazonEKSVPCResourceController`)
  - S3 public access block 설정
  - RDS `publicly_accessible = false` 확인
  - State 파일 보안 (backend 암호화, KMS)
  - IMDS v2 강제 (`http_tokens = "required"`) + hop limit 1
  - 시크릿 하드코딩 여부

#### Agent 2: 비용/리소스 검증
- subagent_type: `cost-analyzer`
- 체크 항목:
  - VPC CIDR 크기 vs prefix delegation IP 소모량 계산
  - 인스턴스 타입 적정성 (over-provisioning)
  - `prevent_destroy` 미설정 critical 리소스 감지 (RDS, S3, KMS)
  - 사용하지 않는 리소스 감지
  - Reserved Instance / Savings Plan 추천 가능 여부
  - Bottlerocket user_data `max-pods` 설정 확인

#### Agent 3: 안정성/상태 관리 검증
- subagent_type: `code-reviewer`
- 체크 항목:
  - `create_before_destroy` 패턴 적절성
  - `ignore_changes` 사용 적절성 (보안 설정 ignore 금지)
  - WARM_IP_TARGET vs WARM_PREFIX_TARGET 설정 정합성
  - Terraform state 관리 (backend 설정, locking)
  - Module versioning (source pinning)
  - Provider version constraint 확인
  - `depends_on` vs implicit dependency 선택

### 3. 결과 종합

3개 에이전트 결과를 병합하여 코드 리뷰 양식으로 출력한다.

## 코멘트 양식

```markdown
## Code Review - Claude Code (Terraform)

### Summary
| Severity | Count |
|----------|-------|
| Blocker  | 0     |
| Critical | 0     |
| Major    | 0     |
| Minor    | 0     |

> Confidence threshold: 50 | Avg confidence: --

### Blocker
**[TF-001] 🔒 제목** `confidence: 95`
- 파일: `path/to/file.tf` (line X)
- 현재: 문제 설명
- 수정 제안: 구체적 해결 방안

### Critical
### Major
### Minor
### Good Practices
```

## 심각도 기준

| 심각도 | 기준 | 예시 |
|--------|------|------|
| Blocker | 적용 시 장애 발생 | SG 규칙 충돌, state 보안 위반, IAM 누락 |
| Critical | 보안/비용 심각 이슈 | IMDS 미차단, public RDS, CIDR 부족 |
| Major | 운영 안정성 문제 | prevent_destroy 미설정, ignore_changes 오용 |
| Minor | 개선 권장 | 네이밍, 태깅, provider 버전 |
