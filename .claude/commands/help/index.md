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

## Java

Java 21+ / Spring Boot 3.x 개발

| 명령어 | 설명 |
|--------|------|
| `/java review` | Java/Spring 코드를 리뷰합니다 (Virtual Threads, DI, Security) |
| `/java test-gen` | JUnit 5 + Testcontainers 테스트를 생성합니다 |
| `/java lint` | SonarQube/Qodana 정적 분석을 수행합니다 |
| `/java refactor` | Modern Java 패턴 및 Virtual Threads 리팩토링을 제안합니다 |
| `/java performance` | Native Image, CDS, GC 튜닝 등 성능 최적화를 제안합니다 |

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

## Memory & Dev-logs

dev-log 작성·정리·승격, 지식 횡단 검색

| 명령어 | 설명 |
|--------|------|
| `/log-trouble` | 트러블슈팅 과정을 기록합니다 (원인 분석, 해결, 회귀 테스트) |
| `/log-decision` | 기술/아키텍처 의사결정을 기록합니다 (A vs B, 트레이드오프) |
| `/log-meta` | Rule/Skill/Agent 추가·변경 사유를 기록합니다 |
| `/log-feedback` | AI 출력 수정 요청을 기록합니다 (패턴 불일치, 누락) |
| `/log-summary` | 현재 세션의 주요 활동을 자동 요약합니다 |
| `/consolidate-devlogs` | dev-log tier 자동 산출, 클러스터 발견, superseded 식별 (dry-run) |
| `/consolidate-memory` | MEMORY.md + memory/*.md 정리, stale/duplicate 분류 (dry-run) |
| `/promote-devlog` | Tier 2 dev-log를 ADR/skill로 승격 (Episodic → Semantic) |
| `/archive-devlog` | Tier 4 dev-log를 _archive/로 이동, replaced_by 링크 보존 |
| `/where` | 키워드로 INDEX/repo-cards/MEMORY/dev-logs 횡단 검색 |
| `/related` | 개념·주제로 dev-logs/ADR/memory를 timeline 순으로 묶어 반환 |

---

## PR Review

다관점 PR 코드 리뷰

| 명령어 | 설명 |
|--------|------|
| `/review-pr` | PR 코드 리뷰를 3개 관점의 에이전트로 병렬 실행해 종합합니다 |
| `/review-pr-k8s` | K8s/Helm/ArgoCD 영역 PR을 3개 전문 관점으로 병렬 리뷰합니다 |
| `/review-pr-monitoring` | 모니터링 영역 PR을 3개 전문 관점으로 병렬 리뷰합니다 |
| `/review-pr-terraform` | Terraform PR을 3개 전문 관점으로 병렬 리뷰합니다 |

---

## Workflow

SDD Phase 게이트 워크플로우

| 명령어 | 설명 |
|--------|------|
| `/phase-start` | SDD Phase 게이트 작업 시작 (11항목 체크리스트 + Gate 1-5) |

---

## 상세 도움말

```
/help session    # Session 명령어
/help go    # Go 명령어
/help java    # Java 명령어
/help backend    # Backend 명령어
/help k8s    # Kubernetes 명령어
/help terraform    # Terraform 명령어
/help dx    # DX 명령어
/help memory    # Memory & Dev-logs 명령어
/help review    # PR Review 명령어
/help workflow    # Workflow 명령어
```

---

## 설치

```bash
./install.sh --global --all      # 전역 설치
./install.sh --local --modules go,k8s  # 로컬 설치
./install.sh                     # 대화형 설치
```

