# TODO - ress-claude-agents 로드맵

## 현재 상태 (2026-02-06)

| 항목 | 수량 | 상태 |
|------|------|------|
| **Agents** | 24 files (~7,900줄) | ✅ 최적화 완료 |
| **Skills** | 128 files (~41,900줄) | ✅ |
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
