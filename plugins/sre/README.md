<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# sre

SRE — SLI/SLO, 장애 대응, 포스트모템, 카오스, DR, 부하 테스트, FinOps

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install sre@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/sre/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`messaging`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/messaging/README.md)

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (18)

| 이름 | 설명 |
|---|---|
| `/sre:chaos-engineering` | Chaos Engineering 가이드 — LitmusChaos를 활용한 시스템 복원력 테스트 및 GameDay 운영 |
| `/sre:chaos-engineering-gameday` | Chaos Engineering GameDay 가이드 — GameDay 운영, 모니터링, 알림 |
| `/sre:disaster-recovery` | Disaster Recovery 가이드 — DR 전략, RTO/RPO 정의, Velero 백업, 멀티 클러스터 복구 |
| `/sre:disaster-recovery-advanced` | Disaster Recovery 고급 가이드 — 멀티 클러스터 DR, 데이터베이스 DR, 테스트 |
| `/sre:finops` | FinOps 가이드 — 클라우드 비용 최적화, Right-sizing, Spot Instance 활용 |
| `/sre:finops-advanced` | FinOps Advanced 가이드 — 태그 기반 비용 할당, FinOps 성숙도 모델, 기업 비용 거버넌스 |
| `/sre:finops-ai` | FinOps for AI — AI 워크로드 비용 관리 — AI/LLM 비용 구조, Token Economics, GPU 비용 최적화, Shift-Left FinOps, Model Routing |
| `/sre:finops-automation` | FinOps: 자동화 가이드 — Infracost PR 통합, 유휴 리소스 자동 정리, 비용 최적화 자동화 |
| `/sre:finops-greenops` | GreenOps 가이드 — 클라우드 탄소 발자국 측정, 지속가능성 최적화, FinOps + GreenOps 통합 |
| `/sre:finops-showback` | FinOps: Showback & Chargeback 가이드 — 팀별 비용 가시화, Kubecost 대시보드, AWS CUR 기반 Chargeback |
| `/sre:finops-tools` | FinOps Tools 가이드 — Kubecost, OpenCost, Infracost 비교 및 설정, KEDA+Karpenter 통합 |
| `/sre:finops-tools-advanced` | FinOps Tools 고급 최적화 가이드 — Cast AI 자동 최적화, Kubecost 고급 설정, 4Rs Framework, Right-sizing 자동화 |
| `/sre:incident-postmortem` | 인시던트 회고 표준 + Blameless 문화 — Severity 분류(SEV1~4), 24/48/72h 회고 SLA, postmortem 템플릿(timeline/impact/RCA 5 … |
| `/sre:load-testing` | 부하 테스트 가이드 — K6, nGrinder를 활용한 성능 테스트 및 결과 분석 |
| `/sre:load-testing-analysis` | 부하 테스트 분석 가이드 — nGrinder, 결과 분석, SLO 기반 Threshold |
| `/sre:load-testing-gatling` | Gatling 부하 테스트 — Scala/Java DSL, injection 프로파일, Assertions, 분산 실행, HTML 리포트 분석 |
| `/sre:runbook-driven-ops` | SRE Runbook 표준 + 실행 자동화 — preventive/reactive/recovery/change 분류, 작성 … |
| `/sre:sre-sli-slo` | SRE: SLI/SLO/SLA 정의 가이드 — 서비스 신뢰성 목표 설정 및 에러 버짓 관리 |

## Agents (5)

| 이름 | 설명 |
|---|---|
| `sre:cost-analyzer` | AI-powered FinOps cost analyzer |
| `sre:debugging-expert` | Cascade failure 분석 / cross-service 디버깅 전문가 — 의존성 그래프 매핑, blast radius 추적, 타임라인 상관분석으로 근본 원인 식별 |
| `sre:finops-advisor` | FinOps 전략 조언자 에이전트. FinOps Foundation Framework 기반 성숙도 평가, 도구 선택, Unit Economics, GreenOps 통합에 특화 |
| `sre:incident-responder` | AI-powered SRE incident responder. Use during production incidents for rapid triage, root cause analysis, and … |
| `sre:load-tester` | 부하 테스트 허브 에이전트. K6, Gatling, nGrinder 도구 비교 및 선택 가이드 |
