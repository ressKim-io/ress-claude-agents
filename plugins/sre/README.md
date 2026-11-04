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
| `/sre:chaos-engineering` | LitmusChaos 카오스 엔지니어링 — 원칙, 설치, 기본 실험, Probe 검증, 안티패턴 |
| `/sre:chaos-engineering-gameday` | Chaos GameDay 운영 — Pre·During·Post 단계, 진행 중 모니터링·알림, 안티패턴, 체크리스트 |
| `/sre:disaster-recovery` | 재해 복구 기본 — RTO/RPO 정의, DR 전략 비교, Velero 백업 설치·설정, 복구 절차 |
| `/sre:disaster-recovery-advanced` | DR 심화 — 멀티 클러스터 DR, 데이터베이스 DR, 정기 DR 테스트(월간), 안티패턴 |
| `/sre:finops` | 클라우드 비용 최적화 기본 — FinOps 프레임워크, 비용 가시성, right-sizing, Spot Instance, 예약 인스턴스·Savings Plan, 미사용 리소스 정리 |
| `/sre:finops-advanced` | FinOps 거버넌스 — 성숙도 모델, 태그 기반 비용 할당, 비용 이상 탐지, 안티패턴 |
| `/sre:finops-ai` | AI 워크로드 비용 관리 — LLM 비용 구조, token economics·귀속, GPU 최적화, Shift-Left FinOps, model routing |
| `/sre:finops-automation` | FinOps 자동화 — Infracost PR 비용 리뷰, 유휴 리소스 자동 정리, 비정상 리소스 알림 |
| `/sre:finops-greenops` | GreenOps — 클라우드 탄소 발자국 측정, 저탄소 리전 선택, ARM 인스턴스 전환, 오프피크 스케줄링, SCI(Software Carbon Intensity) |
| `/sre:finops-showback` | 팀별 비용 가시화 — Showback·Chargeback 구현, Kubecost 대시보드, AWS CUR 기반 배분, Prophet 비용 예측 |
| `/sre:finops-tools` | FinOps 도구 비교와 설치 — OpenCost, Kubecost, Infracost 설정, KEDA+Karpenter 통합 |
| `/sre:finops-tools-advanced` | FinOps 도구 심화 — Cast AI 자동 최적화, Kubecost 고급 설정, 4Rs Framework, right-sizing 자동화, Infracost OPA 정책 |
| `/sre:incident-postmortem` | Blameless 인시던트 회고 — Severity 매트릭스, 회고 템플릿(Summary·Impact·Timeline KST), 재발 방지 Action Item 추적 |
| `/sre:load-testing` | K6 부하 테스트 — 테스트 유형, 기본·고급 시나리오, Kubernetes 실행, Grafana Cloud K6 분산 테스트, 안티패턴 |
| `/sre:load-testing-analysis` | 부하 테스트 결과 분석 — nGrinder 사용, 결과 요약·병목 지점·권장 사항 정리, SLO 기반 threshold |
| `/sre:load-testing-gatling` | Gatling 부하 테스트 — Scala/Java DSL, injection 프로파일, Assertions, 분산 실행, HTML 리포트 분석 |
| `/sre:runbook-driven-ops` | Runbook 표준 — 분류 매트릭스, 작성 템플릿(Trigger·Prerequisites·Steps·Verification), 알림-runbook 연결, 실행 audit 누적 |
| `/sre:sre-sli-slo` | SRE 신뢰성 목표 — SLI 유형별 정의, SLO 설정, SLA 구분, error budget 정책, burn rate 알림, Grafana 대시보드 |

## Agents (5)

| 이름 | 설명 |
|---|---|
| `sre:cost-analyzer` | AI-powered FinOps cost analyzer |
| `sre:debugging-expert` | Cascade failure 분석 / cross-service 디버깅 전문가 — 의존성 그래프 매핑, blast radius 추적, 타임라인 상관분석으로 근본 원인 식별 |
| `sre:finops-advisor` | FinOps 전략 조언자 에이전트. FinOps Foundation Framework 기반 성숙도 평가, 도구 선택, Unit Economics, GreenOps 통합에 특화 |
| `sre:incident-responder` | AI-powered SRE incident responder. Use during production incidents for rapid triage, root cause analysis, and … |
| `sre:load-tester` | 부하 테스트 허브 에이전트. K6, Gatling, nGrinder 도구 비교 및 선택 가이드 |
