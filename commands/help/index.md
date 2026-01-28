# ress-claude-agents Help

사용 가능한 명령어 목록입니다.

## Session

세션 컨텍스트 관리 (auto compact 대응)

| 명령어 | 설명 |
|--------|------|
| `/session save` | 현재 세션 저장 |
| `/session end` | 세션 종료 |

---

## Go

Go 백엔드 개발

| 명령어 | 설명 |
|--------|------|
| `/go review` | 코드 리뷰 |
| `/go test-gen` | 테스트 생성 |
| `/go lint` | 린트 실행 |
| `/go refactor` | 리팩토링 제안 |

---

## Backend

Java/Kotlin 백엔드 개발

| 명령어 | 설명 |
|--------|------|
| `/backend review` | 코드 리뷰 |
| `/backend test-gen` | 테스트 생성 |
| `/backend api-doc` | OpenAPI 문서 |
| `/backend refactor` | 리팩토링 제안 |

---

## Kubernetes

Kubernetes 운영

| 명령어 | 설명 |
|--------|------|
| `/k8s validate` | 매니페스트 검증 |
| `/k8s secure` | 보안 검사 |
| `/k8s netpol` | NetworkPolicy 생성 |
| `/k8s helm-check` | Helm 차트 검사 |

---

## Terraform

인프라 관리

| 명령어 | 설명 |
|--------|------|
| `/terraform plan-review` | plan 분석 |
| `/terraform security` | 보안 검사 |
| `/terraform module-gen` | 모듈 생성 |
| `/terraform validate` | 구성 검증 |

---

## DX

Developer Experience

| 명령어 | 설명 |
|--------|------|
| `/dx pr-create` | PR 생성 |
| `/dx issue-create` | Issue 생성 |
| `/dx changelog` | CHANGELOG 생성 |
| `/dx release` | 릴리스 생성 |

---

## 상세 도움말

```
/help session    # 세션 관리
/help go         # Go 명령어
/help backend    # Backend 명령어
/help k8s        # Kubernetes 명령어
/help terraform  # Terraform 명령어
/help dx         # DX 명령어
```

---

## 설치

```bash
./install.sh --global --all      # 전역 설치
./install.sh --local --modules go,k8s  # 로컬 설치
./install.sh                     # 대화형 설치
```
