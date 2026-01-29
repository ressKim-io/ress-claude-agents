# ress-claude-agents Help

사용 가능한 명령어 목록입니다.

## Session

세션 컨텍스트 관리

| 명령어 | 설명 |
|--------|------|
| `/session save` | 현재 세션 컨텍스트를 저장합니다 |
| `/session end` | 세션을 종료하고 컨텍스트 파일을 정리합니다 |

---

## Go

Go 백엔드 개발

| 명령어 | 설명 |
|--------|------|
| `/go review` | Go 코드를 리뷰하고 개선점을 제안합니다 |
| `/go test-gen` | Table-driven 테스트 코드를 생성합니다 |
| `/go lint` | golangci-lint를 실행하고 이슈를 수정합니다 |
| `/go refactor` | Go 코드 리팩토링을 제안합니다 |

---

## Backend

Java/Kotlin 백엔드 개발

| 명령어 | 설명 |
|--------|------|
| `/backend review` | Java/Kotlin 백엔드 코드를 리뷰합니다 |
| `/backend test-gen` | JUnit 테스트 코드를 생성합니다 |
| `/backend api-doc` | OpenAPI/Swagger 어노테이션을 추가합니다 |
| `/backend refactor` | 코드 품질 개선을 위한 리팩토링을 제안합니다 |

---

## Kubernetes

Kubernetes 운영

| 명령어 | 설명 |
|--------|------|
| `/k8s validate` | 매니페스트의 best practice를 검증합니다 |
| `/k8s secure` | 보안 설정을 자동으로 추가합니다 |
| `/k8s netpol` | NetworkPolicy를 생성하고 검증합니다 |
| `/k8s helm-check` | Helm chart의 best practice를 검증합니다 |

---

## Terraform

인프라 관리

| 명령어 | 설명 |
|--------|------|
| `/terraform plan-review` | terraform plan 결과를 분석합니다 |
| `/terraform security` | 보안 취약점을 검사합니다 |
| `/terraform module-gen` | 재사용 가능한 모듈을 생성합니다 |
| `/terraform validate` | best practice 및 품질을 검증합니다 |

---

## DX

Developer Experience

| 명령어 | 설명 |
|--------|------|
| `/dx pr-create` | 커밋 기반으로 PR을 자동 생성합니다 |
| `/dx issue-create` | 템플릿 기반으로 Issue를 생성합니다 |
| `/dx changelog` | 커밋 히스토리 기반으로 CHANGELOG를 생성합니다 |
| `/dx release` | 버전 태그 및 GitHub Release를 생성합니다 |

---

## 상세 도움말

```
/help session    # Session 명령어
/help go    # Go 명령어
/help backend    # Backend 명령어
/help k8s    # Kubernetes 명령어
/help terraform    # Terraform 명령어
/help dx    # DX 명령어
```

---

## 설치

```bash
./install.sh --global --all      # 전역 설치
./install.sh --local --modules go,k8s  # 로컬 설치
./install.sh                     # 대화형 설치
```

