# TODO - ress-claude-agents 로드맵

## 현재 상태 (2026-02-01)

| 항목 | 수량 | 상태 |
|------|------|------|
| **Agents** | 18 files (~5,400줄) | ✅ 최적화 완료 |
| **Skills** | 68 files (~19,000줄) | ✅ |
| **Commands** | 29 files | ✅ |
| **Templates** | 4 projects | ✅ |
| **Tests** | 36 cases | ✅ |

### 최근 완료 (2026-02-01)

#### Agent 파일 최적화
- [x] `load-tester.md` (1,110줄) → 허브 + 3개 전문 에이전트로 분할
  - `load-tester.md` (150줄) - 도구 비교, 선택 가이드
  - `load-tester-k6.md` (292줄) - K6, Grafana Cloud
  - `load-tester-gatling.md` (270줄) - Scala/Java DSL
  - `load-tester-ngrinder.md` (375줄) - Groovy, Controller/Agent
- [x] `anti-bot.md` 압축 (950줄 → 288줄)
- [x] `ticketing-expert.md` 압축 (759줄 → 276줄)
- [x] `java-expert.md` 압축 (578줄 → 282줄)
- [x] `go-expert.md` 압축 (511줄 → 346줄)
- [x] 모든 에이전트에 Quick Reference 섹션 추가

**결과**: 모든 Agent 파일 600줄 미만 (Claude 권장 범위 내)

#### FinOps 확장 (2026-02-01)
- [x] `finops-advisor.md` Agent 추가 (~300줄)
  - FinOps Foundation Framework 2025 기반
  - 성숙도 평가 (Crawl/Walk/Run)
  - 도구 선택 가이드, Unit Economics
  - GreenOps 통합
- [x] `finops-tools.md` Skill 추가 (~400줄)
  - Kubecost vs OpenCost vs Infracost 비교
  - KEDA + Karpenter + Spot 통합 가이드
- [x] `finops-greenops.md` Skill 추가 (~350줄)
  - 탄소 발자국 측정 (Cloud Carbon Footprint)
  - 저탄소 리전 선택 가이드
  - ARM 인스턴스 (Graviton/T2A) 전환
  - SCI (Software Carbon Intensity) 측정

**결과**: FinOps 영역 완전 커버 (기본 → 고급 → 도구 → 지속가능성)

---

## 🔴 높음 (다음 작업)

### 1. Awesome Lists 등록
- [ ] [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)에 PR 제출
- [ ] [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)에 PR 제출
- [ ] [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)에 PR 제출

### 2. Agent 추가
- [ ] `database-expert.md` - PostgreSQL, MySQL 최적화 전문가
- [ ] `redis-expert.md` - Redis 클러스터, 캐싱 전략 전문가
- [ ] `monitoring-expert.md` - Prometheus, Grafana, 알림 설정 전문가

### 3. Skills 추가
- [ ] `k8s-gateway-api.md` - Gateway API 표준 (Istio, NGINX 통합)
- [ ] `aws-lambda.md` - Serverless 패턴
- [ ] `grpc.md` - gRPC 서비스 설계

---

## 🟡 중간 (검토 필요)

### 4. MCP Server 통합
- [ ] Kubernetes MCP Server 테스트
- [ ] GitHub MCP Server 연동
- [ ] Slack MCP Server 알림 연동

### 5. 문서 개선
- [ ] Skills 사용 예시 GIF 추가
- [ ] Agent 워크플로우 다이어그램
- [ ] Video 튜토리얼 (YouTube)

### 6. 테스트 강화
- [ ] Agent 통합 테스트 추가
- [ ] Skills 로드 성능 테스트
- [ ] CI/CD 파이프라인 최적화

---

## 🟢 낮음 (나중에)

### 7. 국제화
- [ ] 영문 README 작성
- [ ] Skills 영문 버전

### 8. 커뮤니티
- [ ] Discord 서버 개설
- [ ] Contributing 가이드 상세화
- [ ] Issue/PR 템플릿 추가

---

## 완료된 마일스톤

### v1.0 - 초기 릴리스 (2026-01)
- [x] 14개 Agent 작성
- [x] 66개 Skills 작성
- [x] 29개 Commands 작성
- [x] BATS 테스트 36 cases
- [x] GitHub Actions CI 설정

### v1.1 - Agent 최적화 (2026-02)
- [x] load-tester 3분할 (14 → 17 agents)
- [x] 대용량 파일 압축 (7,800줄 → 5,100줄)
- [x] Quick Reference 섹션 추가
- [x] README 전면 개편

### v1.2 - FinOps 확장 (2026-02)
- [x] finops-advisor Agent 추가 (17 → 18 agents)
- [x] finops-tools, finops-greenops Skills 추가 (66 → 68 skills)
- [x] FinOps Foundation Framework 2025 반영
- [x] GreenOps (지속가능성) 영역 추가

---

## 참고 자료

### Claude Code Best Practices
- [Anthropic 공식 가이드](https://www.anthropic.com/engineering/claude-code-best-practices)
- Agent 파일 권장: 200-300줄, 최대 600줄
- 150-200개 명령어 초과 시 무시 시작
- CLAUDE.md가 너무 길면 약 절반 무시

### Awesome Claude Code 레포지토리
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
- [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)
- [anthropics/skills](https://github.com/anthropics/skills) (공식)
