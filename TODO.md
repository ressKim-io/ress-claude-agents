# TODO - ress-claude-agents 로드맵

## 현재 상태 (2026-02-07)

| 항목 | 수량 | 상태 |
|------|------|------|
| **Agents** | 26 files (~8,900줄) | ✅ 최적화 완료 |
| **Skills** | 142 files (~48,700줄) | ✅ 9개 카테고리 서브디렉토리 |
| **Commands** | 35 files | ✅ |
| **Templates** | 4 projects | ✅ |
| **Tests** | 36 cases | ✅ |

---

## 🔴 높음 (다음 작업)

### 1. Awesome Lists 등록
- [ ] [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)에 PR 제출
- [ ] [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)에 PR 제출
- [ ] [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)에 PR 제출

### 2. Agent 추가 (검토 필요)
- [ ] `monitoring-expert.md` - Prometheus, Grafana, 알림 설정 전문가

---

## 🟡 중간 (검토 필요)

### 3. MCP Server 통합
- [ ] Kubernetes MCP Server 테스트
- [ ] GitHub MCP Server 연동
- [ ] Slack MCP Server 알림 연동

### 4. 문서 개선
- [ ] Skills 사용 예시 GIF 추가
- [ ] Agent 워크플로우 다이어그램
- [ ] Video 튜토리얼 (YouTube)

### 5. 테스트 강화
- [ ] Agent 통합 테스트 추가
- [ ] Skills 로드 성능 테스트
- [ ] CI/CD 파이프라인 최적화

---

## 🟢 낮음 (나중에)

### 6. 국제화
- [ ] 영문 README 작성
- [ ] Skills 영문 버전

### 7. 커뮤니티
- [ ] Discord 서버 개설
- [ ] Contributing 가이드 상세화
- [ ] Issue/PR 템플릿 추가

---

## 완료된 마일스톤

### v1.7 - Spring jOOQ & Go Database 스킬 추가 (2026-02-13)
- [x] `spring-jooq.md` Skill 추가 (~498줄) - jOOQ DSL, 코드 생성(Flyway+Testcontainers), MULTISET, Keyset Pagination, R2DBC
- [x] `go-database.md` Skill 추가 (~426줄) - pgx, sqlc, sqlx, ent, bun 패턴
- [x] 140 → 142 Skills, spring 카테고리 8 → 9 files, go 카테고리 6 → 7 files, ~57K → ~58K lines

### v1.6 - Platform Engineering 셀프서비스 확장 (2026-02-10)
- [x] `developer-self-service.md` Skill 추가 (~486줄) - Backstage Templates, Crossplane Claims, 셀프서비스 플랫폼
- [x] `secrets-management.md` Skill 추가 (~499줄) - ESO, Vault VSO, Infisical, SOPS+age, 자동 로테이션
- [x] `kratix.md` Skill 추가 (~497줄) - Promise CRD, Pipeline, 멀티클러스터, 소규모 적용 가능성 평가
- [x] 137 → 140 Skills, platform 카테고리 13 → 16 files, ~56K → ~57K lines

### v1.5 - 토이프로젝트 지원 확장 (2026-02-07)
- [x] `architect-agent.md` Agent 추가 (~513줄) - MSA 설계, 서비스 경계, API 계약 정의
- [x] `saga-agent.md` Agent 추가 (~475줄) - 분산 트랜잭션 오케스트레이션, Temporal.io
- [x] `go-microservice.md` Skill 추가 (~494줄) - Go MSA 프로젝트 구조, 헥사고날 아키텍처
- [x] `nats-messaging.md` Skill 추가 (~431줄) - NATS JetStream, KV Store, Consumer 패턴
- [x] `state-machine.md` Skill 추가 (~412줄) - 도메인 상태머신, FSM, Event Sourcing 통합
- [x] 24 → 26 Agents, 134 → 137 Skills, ~52K → ~56K lines

### v1.4 - Skills 서브디렉토리 재편 + 6개 신규 스킬 (2026-02-07)
- [x] 128개 Skills → 9개 카테고리 서브디렉토리 재편 (dx, go, spring, msa, kubernetes, observability, platform, sre, infrastructure)
- [x] `redis-streams.md` Skill 추가 - Redis Streams, Consumer Groups, PEL 관리
- [x] `rabbitmq.md` Skill 추가 - RabbitMQ v4.1, Quorum Queues, AMQP 1.0
- [x] `aws-messaging.md` Skill 추가 - SQS, SNS, EventBridge 선택 가이드
- [x] `graphql-federation.md` Skill 추가 - Apollo Federation v2, GraphOS Router
- [x] `linkerd.md` Skill 추가 - Linkerd v2.17, Rust micro-proxy, vs Istio 비교
- [x] `task-queue.md` Skill 추가 - Celery, BullMQ, Go asynq, Priority Queue 패턴
- [x] `generate-inventory.sh` 재귀 탐색 + 디렉토리 기반 카테고리 지원
- [x] `install.sh` flatten symlink 로직 추가 (하위 호환성)
- [x] 128 → 134 Skills, ~41,900 → ~44,900줄

### v1.3 - Skills & Agent 확장 (2026-02-06)
- [x] `redis-expert.md` Agent 추가 (~370줄) - Redis Cluster, Sentinel, 캐싱 전략
- [x] `aws-lambda.md` Skill 추가 (~570줄) - Serverless 패턴, SnapStart, 콜드 스타트 최적화
- [x] `grpc.md` Skill 추가 (~490줄) - gRPC 서비스 설계, Protocol Buffers, 스트리밍
- [x] `local-dev-makefile.md` Skill 추가 (~630줄) - make up 풀스택 로컬 개발 환경
- [x] CI 개선: inventory timestamp 무시 로직 (근본 수정)

### v1.2 - FinOps 확장 (2026-02-01)
- [x] finops-advisor Agent 추가 (17 → 18 agents)
- [x] finops-tools, finops-greenops Skills 추가 (66 → 68 skills)
- [x] FinOps Foundation Framework 2025 반영
- [x] GreenOps (지속가능성) 영역 추가

### v1.1 - Agent 최적화 (2026-02-01)
- [x] load-tester 3분할 (14 → 17 agents)
- [x] 대용량 파일 압축 (7,800줄 → 5,100줄)
- [x] Quick Reference 섹션 추가
- [x] README 전면 개편

### v1.0 - 초기 릴리스 (2026-01)
- [x] 14개 Agent 작성
- [x] 66개 Skills 작성
- [x] 29개 Commands 작성
- [x] BATS 테스트 36 cases
- [x] GitHub Actions CI 설정

---

## 참고 자료

### Claude Code Best Practices
- [Anthropic 공식 가이드](https://www.anthropic.com/engineering/claude-code-best-practices)
- Agent 파일 권장: 200-300줄, 최대 600줄
- Skill 파일 권장: 500줄 미만
- 150-200개 명령어 초과 시 무시 시작
- CLAUDE.md가 너무 길면 약 절반 무시

### Awesome Claude Code 레포지토리
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
- [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)
- [anthropics/skills](https://github.com/anthropics/skills) (공식)
