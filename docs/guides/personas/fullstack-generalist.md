# 풀스택 / 제너럴리스트 가이드

> "모르면 물어봐" — 전반적인 개발에 Claude Code를 활용하는 가이드

---

## 설치 후 첫 5분

- [ ] `./install.sh --global --all --with-skills` 실행
- [ ] Claude Code에서 `/agents` 입력 → 에이전트 목록 확인
- [ ] `"이 프로젝트 구조 분석해줘"` 시도
- [ ] `"코드 리뷰해줘"` 시도

---

## 매일 쓰는 조합

> 전체 조합 테이블: [quick-reference.md](../quick-reference.md#4-풀스택--제너럴리스트-콤보)

### "모르면 물어봐" 패턴

Claude Code에 자연어로 요청하면 적절한 에이전트가 자동 선택됩니다.

```
"보안 취약점 검사해줘"           → security-scanner 자동 선택
"프로덕션 파드가 죽어요"         → k8s-troubleshooter 자동 선택
"코드 리뷰해줘"                 → code-reviewer 자동 선택
"PR 만들어줘"                   → git-workflow 자동 선택
"클라우드 비용 분석해줘"         → cost-analyzer 자동 선택
```

특정 스킬이 필요하면 슬래시 명령으로 직접 로드:

```
/api-design         → REST API 설계 가이드 로드
/docker             → Dockerfile 최적화 가이드 로드
/effective-java     → Java 패턴 결정 가이드 로드
```

---

## 개발환경 구축

### 로컬 개발

| 스킬 | 용도 |
|------|------|
| `/local-dev-makefile` | `make up`으로 풀스택 실행, Hot Reload |
| `/docker` | Dockerfile 최적화, 멀티스테이지 빌드 |
| `/dx-onboarding-environment` | Dev Container 자동화 |

```
"로컬 개발환경 Docker로 설정해줘"
→ /local-dev-makefile + /docker
```

### 클라우드 IDE

| 스킬 | 용도 |
|------|------|
| `/dx-onboarding-gitpod` | Gitpod/Codespaces 설정 |
| `/dx-onboarding` | Time-to-First-Deploy 최적화 |
| `/dx-onboarding-deploy` | 첫 배포 가이드 |

---

## 코드 품질

### 필수 에이전트

| 에이전트 | 언제 쓰나 |
|---------|----------|
| `code-reviewer` | 코드 변경 후 (자동 리뷰) |
| `security-scanner` | 코드 변경 후 (보안 점검) |
| `git-workflow` | 커밋, PR 생성 시 |

### 리팩토링

| 스킬 | 대상 |
|------|------|
| `/refactoring-principles` | 언어 무관 기본 원칙 |
| `/refactoring-spring` | Spring Boot 코드 |
| `/refactoring-go` | Go 코드 |

### 기술 의사결정

기술 선택에 고민될 때:

```
"A vs B 비교해줘"
→ architect-agent가 트레이드오프 분석

"이 아키텍처 괜찮을까?"
→ architect-agent + 해당 도메인 스킬

"Kafka vs RabbitMQ vs NATS 비교해줘"
→ /kafka + /rabbitmq + /nats-messaging
```

---

## 기록 관리

### dev-logger 에이전트

개발 과정을 구조화된 마크다운으로 기록합니다.

| 명령 | 용도 | 예시 |
|------|------|------|
| `/log-feedback` | AI 수정 요청 기록 | 코드 패턴 불일치, 누락 등 |
| `/log-decision` | 기술 의사결정 기록 | A vs B 선택 근거 |
| `/log-meta` | Rule/Skill 변경 기록 | 워크플로우 개선 |
| `/log-trouble` | 트러블슈팅 기록 | 에러 원인, 해결 과정 |
| `/log-summary` | 세션 요약 | 세션 종료 전 실행 |

```
세션 종료 전:
  /log-summary → 오늘 작업 요약 자동 생성
```

---

## 문서화

| 스킬 | 용도 |
|------|------|
| `/docs-as-code` | MkDocs, Docusaurus, TechDocs |
| `/docs-as-code-automation` | API 문서 자동화, Vale 린터 |
| `/conventional-commits` | 커밋 메시지 규칙, Changelog 자동화 |
| `/token-efficiency` | Claude Code 세션 토큰 효율화 |

---

## 자주 쓰는 Commands

| 카테고리 | 명령 | 설명 |
|---------|------|------|
| 리뷰 | `/backend review` | 백엔드 코드 리뷰 |
| 테스트 | `/backend test-gen` | 테스트 코드 생성 |
| 문서 | `/backend api-doc` | API 문서 생성 |
| Git | `/dx pr-create` | PR 자동 생성 |
| Git | `/dx changelog` | Changelog 생성 |
| 세션 | `/session save` | 세션 상태 저장 |

---

## 추천 학습 순서

```
Week 1: 기본 사이클 익히기
  - code-reviewer, security-scanner, git-workflow
  - /effective-java 또는 /effective-go

Week 2: 프로젝트 구조
  - /api-design, /docker, /local-dev-makefile
  - architect-agent 활용

Week 3: 테스트 + 관측성
  - /spring-testing 또는 /go-testing
  - /observability, /monitoring-grafana

Week 4+: 도메인 심화
  - 관심 분야에 따라 MSA, K8s, 또는 Platform 스킬 확장
```

---

## 관련 시나리오

- [신규 MSA 서비스 개발](../scenarios/new-microservice.md) — 처음부터 서비스 구축하는 과정
- [프로덕션 장애 대응](../scenarios/production-incident.md) — 장애 대응 경험해보기
