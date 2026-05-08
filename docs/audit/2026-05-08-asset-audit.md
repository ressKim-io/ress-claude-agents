# 자산 audit 리포트 (2026-05-08)

## 요약

| 항목 | 수치 |
|---|---|
| Skills | 239 |
| Agents | 46 |
| Commands | 43 |
| Plugins | 12 |
| Workflows | 10 |
| Rules | 14 |

본 audit은 사용자 요청("오래되거나 안 쓰는 자산 종합 audit")에 따라 Explore 에이전트 3개를 병렬 실행해 **참조 그래프 / 중복·오버랩 / agent 조합** 3축으로 분석했다. 결과는 다음과 같다.

- **모델 ID drift**: 0건 (Phase D cleanup 완료, 추가 작업 불필요)
- **Deprecated 마킹**: 3개 (자명한 stub만)
- **통합 권장**: 5개 그룹 (별도 PR)
- **신규 plugin/workflow 후보**: 5개 (별도 PR)

---

## 1. 모델 ID drift

```bash
grep -rn -E "claude-(3-(opus|sonnet|haiku)|sonnet-4-2025|opus-4-2025|haiku-4-2025|3-5-)" .claude/ docs/ \
  | grep -v "/dev-logs/" | grep -v "/migration/" | grep -v "/retrospective/"
```

→ **0건**. `dev-logs/2026-05-04-opus-4-7-phase-d.md`의 검증 마커가 그대로 유효함을 재확인.

정책 (변경 없음): OTel 예시는 `opus-4-7`, SDK 예시는 `sonnet-4-6`, Routing matrix는 `haiku-4-5`/`sonnet-4-6`/`opus-4-7`.

---

## 2. Orphan 분석

### 통계

| 자산 종류 | 총수 | grep 기준 참조됨 | "Orphan" | 해석 |
|---|---|---|---|---|
| Skills | 239 | 87 | **152 (63.6%)** | 절반 이상이 참조 안 됨. 단, 스킬은 description 매칭으로 자동 발견되므로 orphan ≠ 미사용 |
| Agents | 46 | 8 | **38 (82.6%)** | agents는 `Agent(subagent_type=...)` 직접 호출이 정상. orphan 자체가 문제 아님 |
| Commands | 43 | 0 | 43 | CLI 직접 호출 방식. orphan 판정 부적합 |

> **결론**: 단순 grep 기반 orphan 판정은 false positive가 많다. 정리는 **자명한 stub(redirect 또는 깊이 부족)**에만 한정한다.

### High-risk orphan (재검토 권장)

inventory-labels.yml에서 `model_dependency=high`이면서 어디에서도 참조되지 않는 4개. 모델/프레임워크 진화에 민감하므로 **분기별 검토** 필요.

| 파일 | 줄 수 | 위험 |
|---|---|---|
| `.claude/skills/ai/agentic-coding.md` | 312 | Agent Supervision/Conductor 패턴 (Claude 모델별 동작 차이) |
| `.claude/skills/ai/langchain-langgraph.md` | 490 | LangChain/LangGraph 버전 추적 |
| `.claude/skills/architecture/agentic-ai-architecture.md` | 485 | AI 시스템 아키텍처 패턴 |
| `.claude/skills/dx/ai-first-playbook.md` | 289 | AI-first 조직 전환 (시장 변화 빠름) |

**권장**: 분기별 재검토 시점을 frontmatter에 추가하는 것 검토 (예: `review_due: 2026-08-08`).

---

## 3. Deprecated 마킹 (이번 PR)

자명하게 정리 가능한 100줄 미만 stub 3개에 frontmatter 추가.

| 파일 | 줄 수 | replaced_by | 근거 |
|---|---|---|---|
| `.claude/skills/platform/mlops-llmops.md` | 7 | `[mlops, mlops-tracking, llmops]` | 본문 자체가 redirect 안내. 3개 후속 파일 모두 존재 |
| `.claude/skills/go/go-errors.md` | 91 | `[effective-go]` | `effective-go.md` §"CRITICAL: 에러 처리"(L107~)에 wrapping/Is/As/errgroup 풍부 |
| `.claude/skills/service-mesh/istio-kiali.md` | 93 | `[istio-observability]` | 본문 마지막에 자체적으로 가리킴 ("관련 skill: /istio-observability") |

### Deprecated frontmatter 표준

다음 키를 도입한다 (본 PR이 첫 사례).

```yaml
---
name: <skill-name>
description: (DEPRECATED) <기존 설명>. <대체 안내>.
deprecated: true
deprecated_since: YYYY-MM-DD
replaced_by: [skill1, skill2]   # 다른 스킬에 흡수된 경우
# 또는
merge_into: [skill1]            # 통합 작업이 진행 중인 경우
---
```

`validate-skill-frontmatter.sh`는 `name` 존재만 검증하므로 추가 키는 호환성 유지된다. 다음 audit 사이클에서 deprecated 자산을 수집하려면 다음 명령 사용:

```bash
grep -rln "^deprecated: true" .claude/skills/
```

---

## 4. 통합 권장 (별도 PR)

이번 audit에서 발견했지만 **이번 PR에서는 처리하지 않은** 통합 후보. 각 항목별 별도 PR 권장.

### 4.1 dx-onboarding 4종 → 단일 문서 + 섹션화

| 파일 | 줄 수 |
|---|---|
| `.claude/skills/dx/dx-onboarding.md` | 메인 (허브) |
| `.claude/skills/dx/dx-onboarding-deploy.md` | 배포 환경 |
| `.claude/skills/dx/dx-onboarding-environment.md` | 로컬 환경 |
| `.claude/skills/dx/dx-onboarding-gitpod.md` | Gitpod 특화 |
| **합계** | **1,267** |

권장: dx-onboarding.md를 메인 문서로 확장하고 3개 변형은 섹션 또는 deprecated stub로.

### 4.2 istio-gateway 3종 재정리

| 파일 | 줄 수 | 역할 |
|---|---|---|
| `.claude/skills/service-mesh/istio-gateway.md` | 114 | 허브 (너무 짧음 — 거의 빈 파일) |
| `.claude/skills/service-mesh/istio-gateway-classic.md` | ? | 구식 Gateway resource |
| `.claude/skills/service-mesh/istio-gateway-api.md` | ? | K8s Gateway API |

권장: `istio-gateway-api.md`를 메인으로 승격, `istio-gateway.md`는 비교표 + redirect.

### 4.3 aws-eks-advanced (176줄) → aws-eks 본체

`aws-eks-advanced.md`가 176줄로 깊이 부족. 메인 EKS 가이드에 흡수.

### 4.4 terraform-modules (169줄) / terraform-security (171줄) → terraform-k8s-bootstrap (462줄)

170줄 미만 2개 → 더 큰 통합 가이드 흡수 검토.

### 4.5 observability/ 카테고리 계층화

28개 파일 중 모니터링(6) + 로깅(4) + AIops(2) + OTel(5) + tracing 등 세분화 과다. 진입점 명확화 필요 (별도 회고 권장).

---

## 5. agent 조합 신규 후보 (별도 PR)

handoff.yml의 produces/consumes를 따라가서 **자연스러운 호출 흐름**이 있는 조합만 제안. 현재 plugin/workflow 미커버 영역.

### 5.1 신규 plugin: `finops`

**포함**: `cost-analyzer` + `finops-advisor` + `ci-optimizer`
**페르소나**: DevOps / Platform Engineer / FinOps Lead
**흐름**: 비용 리포트 → 전략 수립 → 파이프라인 비용 최적화

기존 plugin/workflow에 비용 최적화 사이클이 없음.

### 5.2 신규 plugin: `security-posture`

**포함**: `security-scanner` + `container-security-reviewer` + `k8s-security-reviewer` + `network-security-reviewer` + `cicd-security-reviewer` + `anti-bot` + `compliance-auditor`
**페르소나**: Security Engineer / CISO / Compliance Officer
**흐름**: 코드→컨테이너→K8s→네트워크→런타임 방어→컴플라이언스 (defense-in-depth)

`incident-to-action`은 사후 대응에 집중. 사전 방어 + 컴플라이언스 통합 plugin 부재.

### 5.3 신규 workflow: `data-migration-tune`

```
discovery (product-engineer)
  → data-design (database-expert | -mysql)
    → cache-strategy (redis-expert)
      → migration-exec (migration-expert)
        → perf-validate (load-tester*)
          → finops-check (finops-advisor)
            → record (dev-logger)
```

**트리거**: DB 버전 업그레이드, 대규모 데이터 마이그레이션, 성능 저하 알림
**Gap**: feature-development와 new-domain은 데이터 모델까지만 다룸.

### 5.4 신규 workflow: `security-incident-hardening`

```
incident-detection (security-scanner)
  → container-audit (container-security-reviewer)
  → k8s-audit (k8s-security-reviewer)
  → network-audit (network-security-reviewer)
    → runtime-defense (anti-bot)
      → compliance-check (compliance-auditor)
        → decision (tech-lead)
          → enforce (platform-engineer)
```

**Gap**: incident-to-action(반응형) + 사전 방어 + 사후 컴플라이언스 통합 부재.

### 5.5 신규 workflow: `platform-evolution`

```
roadmap (infra-roadmap-planner)
  → platform-design (platform-engineer)
    → iac-review (terraform-reviewer)
      → migration-exec (migration-expert)
        → cost-analysis (cost-analyzer)
          → finops-decision (finops-advisor)
            → record (dev-logger)
```

**Gap**: `eks-gitops-setup`/`gke-gitops-setup`는 final 상태만 정의. `infra-roadmap-planner` produce → 그 후 단계가 비어 있음.

---

## 6. Out of Scope (의도적으로 안 한 것)

- agents 38개 "orphan" 정리 — 직접 호출 방식이 정상 사용
- commands 43개 — CLI 호출 방식
- 152개 orphan skills 개별 마킹 — grep 정확도 한계로 false positive 위험
- 통합 작업 (위 4.1~4.5) — 큰 PR이 됨, 개별 진행 권장
- 신규 plugin/workflow 추가 (5.1~5.5) — 별도 RFC/ADR 필요

---

## 7. 다음 액션 (우선순위)

| 우선순위 | 작업 | 난이도 | 영향도 |
|---|---|---|---|
| 1 | 본 PR 머지 후 다음 audit 사이클에서 deprecated 자산 회수 정책 결정 | 낮음 | 낮음 |
| 2 | `finops` plugin 추가 (5.1) | 낮음 | 높음 — orphan agent 3개 활용 |
| 3 | `dx-onboarding` 4종 통합 (4.1) | 중간 | 중간 — 1,267줄 → 단일 문서화 |
| 4 | `security-posture` plugin (5.2) | 중간 | 높음 — 7개 보안 reviewer 활용 |
| 5 | `istio-gateway` 3종 재정리 (4.2) | 중간 | 중간 — 진입점 명확화 |
| 6 | High-risk AI 4종 분기별 검토 사이클 자동화 | 낮음 | 중간 — drift 예방 |

---

## 부록 A: 사용한 검증 명령

```bash
# 모델 ID drift
grep -rn -E "claude-(3-(opus|sonnet|haiku)|sonnet-4-2025|opus-4-2025|haiku-4-2025|3-5-)" .claude/ docs/ \
  | grep -v "/dev-logs/" | grep -v "/migration/" | grep -v "/retrospective/"

# 100줄 미만 skills
find .claude/skills -name "*.md" -type f | while read f; do
  lines=$(wc -l < "$f")
  [ "$lines" -lt 100 ] && echo "$lines $f"
done | sort -n

# Deprecated 자산 수집
grep -rln "^deprecated: true" .claude/skills/

# 라벨 분포
grep -E "^\s+(model_dependency|portability|domain_specificity):" .claude/inventory-labels.yml \
  | sort | uniq -c | sort -rn
```

## 부록 B: 관련 문서

- [docs/dev-logs/2026-05-04-opus-4-7-phase-d.md](../dev-logs/2026-05-04-opus-4-7-phase-d.md) — Phase D 검증 마커
- [docs/migration/0001-agents-md-adoption.md](../migration/0001-agents-md-adoption.md) — AGENTS.md 도입
- [docs/retrospective/2026-05-06-0002-p0-p5-milestone.md](../retrospective/2026-05-06-0002-p0-p5-milestone.md) — 0002 마이그레이션 절반 회고
- `.claude/inventory.yml`, `.claude/inventory-labels.yml` — 자산 인덱스 + 라벨
- `.claude/agents/_handoff.yml` — 46 agents 산출물 매핑
