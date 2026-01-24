# ress-claude-agents Help

사용 가능한 명령어 목록입니다.

## Session (세션 컨텍스트 관리)

긴 작업 시 auto compact로 인한 컨텍스트 손실 방지

| 명령어 | 설명 |
|--------|------|
| `/session save` | 현재 세션 컨텍스트 저장 |
| `/session end` | 세션 종료 및 정리 |

**자동 기능**: 복잡한 작업 시 `.claude/session-context.md` 자동 생성/삭제

---

## Go (Go 백엔드 개발)

| 명령어 | 설명 |
|--------|------|
| `/go review` | Go 코드 리뷰 |
| `/go test-gen` | 테스트 코드 생성 |
| `/go lint` | golangci-lint 실행 및 수정 |
| `/go refactor` | 리팩토링 제안 |

**Skills**: `/go-errors`, `/go-gin`, `/go-testing`

---

## Backend (Java/Kotlin 백엔드)

| 명령어 | 설명 |
|--------|------|
| `/backend review` | 코드 리뷰 |
| `/backend test-gen` | 테스트 코드 생성 |
| `/backend api-doc` | OpenAPI 문서 생성 |
| `/backend refactor` | 리팩토링 제안 |

---

## K8s (Kubernetes)

| 명령어 | 설명 |
|--------|------|
| `/k8s validate` | 매니페스트 검증 |
| `/k8s secure` | 보안 검사 |
| `/k8s netpol` | NetworkPolicy 생성 |
| `/k8s helm-check` | Helm 차트 검사 |

**Skills**: `/k8s-security`, `/k8s-helm`

---

## Terraform

| 명령어 | 설명 |
|--------|------|
| `/terraform plan-review` | plan 결과 분석 |
| `/terraform security` | 보안 검사 |
| `/terraform module-gen` | 모듈 생성 |
| `/terraform validate` | 구성 검증 |

**Skills**: `/terraform-modules`, `/terraform-security`

---

## DX (Developer Experience)

| 명령어 | 설명 |
|--------|------|
| `/dx pr-create` | PR 생성 |
| `/dx issue-create` | Issue 생성 |
| `/dx changelog` | CHANGELOG 생성 |
| `/dx release` | 릴리스 생성 |

**Skills**: `/git-workflow`

---

## 상세 도움말

```
/help session    # 세션 관리 상세
/help go         # Go 명령어 상세
/help backend    # Backend 명령어 상세
/help k8s        # Kubernetes 명령어 상세
/help terraform  # Terraform 명령어 상세
/help dx         # DX 명령어 상세
```

---

## 설치 정보

```bash
# 전역 설치 (모든 프로젝트)
./install.sh --global --all

# 로컬 설치 (현재 프로젝트만)
./install.sh --local --modules go,k8s

# 대화형 설치
./install.sh
```
