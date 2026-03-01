[English](../README.md) | **한국어**

# 사용 가이드

> 160개 Skills + 27개 Agents + 5개 Rules — "내 상황에 뭘 써야 하지?"를 해결하는 가이드

---

## 핵심 개념 3줄 요약

| 구분 | 역할 | 로드 방식 |
|------|------|----------|
| **Skills** | 도메인 지식 (패턴, 가이드, 레퍼런스) | `/skill-name`으로 필요할 때 로드 |
| **Agents** | 자율 실행 전문가 (진단, 분석, 자동화) | 자연어 요청 또는 `/agents`에서 선택 |
| **Rules** | 항상 적용되는 코딩 규칙 (Git, 테스트, 보안) | 파일 경로 기반 자동 적용 |

---

## 페르소나별 가이드

나에게 맞는 가이드를 선택하세요.

| 페르소나 | 주요 관심사 | 가이드 |
|----------|-----------|--------|
| **백엔드 개발자** | Java/Go, API 설계, MSA, 테스트 | [personas/backend-dev.md](personas/backend-dev.md) |
| **DevOps / SRE** | K8s, IaC, GitOps, 인시던트, 관측성 | [personas/devops-sre.md](personas/devops-sre.md) |
| **풀스택 / 제너럴리스트** | 전반적인 개발, 빠른 시작, 학습 | [personas/fullstack-generalist.md](personas/fullstack-generalist.md) |

---

## 시나리오 워크스루

실전 상황을 단계별로 따라하세요.

| 시나리오 | 소요 시간 | 핵심 도구 |
|----------|----------|----------|
| [신규 MSA 서비스 개발](scenarios/new-microservice.md) | 2-3시간 | `architect-agent`, `/msa-ddd`, `/go-microservice` |
| [프로덕션 장애 대응](scenarios/production-incident.md) | 30-60분 | `incident-responder`, `k8s-troubleshooter`, `/observability` |
| [플랫폼 팀 환경 구축](scenarios/platform-bootstrap.md) | 1-2일 | `platform-engineer`, `/backstage`, `/gitops-argocd` |

---

## 빠른 시작

1. **콤보 레퍼런스 확인**: [quick-reference.md](quick-reference.md) — 상황별 추천 조합 한눈에 보기
2. **내 페르소나 가이드 읽기**: 위 테이블에서 선택
3. **시나리오 따라하기**: 실전 상황에 맞는 워크스루 실행

---

## 전체 구조

```
docs/guides/
├── README.md                     ← 지금 보고 있는 파일
├── quick-reference.md            ← 상황별 콤보 테이블 (핵심)
├── personas/
│   ├── backend-dev.md            ← 백엔드 개발자 (Java/Go)
│   ├── devops-sre.md             ← DevOps/SRE
│   └── fullstack-generalist.md   ← 풀스택/제너럴리스트
└── scenarios/
    ├── new-microservice.md       ← 신규 MSA 서비스 개발
    ├── production-incident.md    ← 프로덕션 장애 대응
    └── platform-bootstrap.md     ← 플랫폼 팀 환경 구축
```
