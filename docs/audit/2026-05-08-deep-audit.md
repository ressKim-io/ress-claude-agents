# 깊이 audit 리포트 (2026-05-08)

> 본 리포트는 [2026-05-08-asset-audit.md](2026-05-08-asset-audit.md)(휴리스틱 audit)의 후속이다. 이전이 grep+줄수 기반이었다면 이번은 본문/구조/메타 깊이 분석.

## 1. 요약

| 분석 축 | 도구 | 결과 |
|---|---|---|
| 콘텐츠 (observability+dx 54개) | subagent + 본문 grep | 4.8-4.9/5 — 매우 건강 |
| 콘텐츠 (언어 spring/go/python/frontend 33개) | subagent + 본문 grep | 3.5-4.5/5 — 2건 본문 버그 발견 |
| Agents 메타 46개 | subagent + frontmatter grep | 2.8/5 — model inherit 100%, description 트리거 부재 22% |
| Rules + dev-logs + install.sh | subagent | 4/5 — 빠진 영역 3건 / install.sh dedup 미구현 |

**즉시 수정 가능한 명백한 버그 2건만 본 PR에서 처리**, 나머지는 별도 PR로 분리.

---

## 2. 카테고리 건강도 매트릭스

| 카테고리 | 건강도 | 핵심 평가 |
|---|---|---|
| observability/ (28) | **4.8/5** | Grafana Agent EOL / Zipkin deprecated 선제 문서화. 의미 중복 0. 모든 파일 ≥199줄. |
| dx/ (26) | **4.9/5** | onboarding 4종, docs-as-code 2종 모두 의도된 계층. 모든 파일 ≥181줄. |
| spring/ (12) | **4.5/5** | 1건 본문 버그(spring-cache L187 anti-pattern을 권장으로 표기). Virtual Threads 보강 여지. |
| frontend/ (7) | **4/5** | React 19+ / Next.js 15 App Router 중심 — modern. typescript "5.x" 표기 → 5.5+ 명시 권장. |
| python/ (6) | **4/5** | 1건 본문 결함(python-async uvloop universal 권장 — caveat 부재). |
| go/ (9) | **3.5/5** | go-gin.md 153줄 thin (middleware ordering / graceful shutdown 누락). go-errors.md 본 PR 직전 deprecated 처리됨. |
| **agents/ (46)** | **2.8/5** | 🔴 **model: inherit 100%** (비용 최적화 기회), description "Use when/for" 트리거 22% 부재 (10/46), reviewer 4쌍 역할 경계 모호. |
| rules/ (14) | **4/5** | 중복 미미. cloud-cli-safety.md 202줄은 모듈식 활성화 패턴이라 의도적. 빠진 영역 3건. |

---

## 3. 즉시 수정 (본 PR에서 처리)

본문이 직접 검증된 잘못된 권장만 수정. 추정 기반 수정은 안 함.

### 3-1. `.claude/skills/spring/spring-cache.md` L187 — Entity Serializable 안티패턴 권장

**검증** (`sed -n '185,191p'`):
```
| 실수 | 올바른 방법 |
|------|------------|
| TTL 없이 캐싱 | 항상 적절한 TTL 설정 |
| 대용량 객체 캐싱 | 필요한 필드만 DTO로 |
| Serializable 누락 | Entity에 Serializable 구현 |   ← 안티패턴을 권장으로 표기
```

**문제**: JPA Entity에 `Serializable` 구현은 lazy loading proxy 직렬화 / version 충돌 / 캐시-DB 결합 문제 유발. Spring Data Redis는 GenericJackson2JsonRedisSerializer (JSON) 또는 DTO 변환이 표준.

**수정**: 본 PR에서 해당 행 + 인근 컨텍스트 수정.

### 3-2. `.claude/skills/python/python-async.md` L403~ uvloop 무조건 권장

**검증** (`sed -n '403,415p'`):
```
## uvloop Optimization

```python
# uvloop: libuv 기반 이벤트 루프 (2-4x faster)
# pip install uvloop
```

**문제**: caveat 부재. 실제로는:
- CPython 한정 최적화 (PyPy는 자체 asyncio가 종종 더 빠름)
- Python 3.12+ asyncio도 큰 폭 개선 (uvloop 격차 축소)
- Windows 미지원

**수정**: 코드 블록 첫 주석 한 줄 + 섹션 캡션에 caveat 추가.

---

## 4. 별도 PR 권장 (★★ 중기)

### 4-1. Agents 46개 model 재분배 — 가장 큰 비용 임팩트

**현재**: `grep "^model:" .claude/agents/*.md | uniq -c` → 46/46 모두 `inherit`.

**권장 분배**:

| Model | Agents | 수 |
|---|---|---|
| `opus` | tech-lead, architect-agent, debugging-expert | 3 |
| `sonnet` | go/java/python/frontend-expert, database-expert(/-mysql), redis-expert, otel-expert, mlops-expert, messaging-expert, service-mesh-expert, code-reviewer, k8s-reviewer, k8s-security-reviewer, terraform-reviewer, cicd-reviewer, cicd-security-reviewer, dockerfile-reviewer, container-security-reviewer, network-security-reviewer, observability-reviewer, gitops-reviewer, security-scanner, compliance-auditor, incident-responder, k8s-troubleshooter, finops-advisor, cost-analyzer, ci-optimizer, anti-bot, ticketing-expert, saga-agent, migration-expert, infra-roadmap-planner, platform-engineer, product-engineer, load-tester(/k6/gatling/ngrinder) | 약 38 |
| `haiku` | dev-logger, git-workflow, pr-review-bot, claude-code-guide, statusline-setup | 5 |

**예상 효과**: Haiku로 충분한 5개 + Sonnet 적정화로 25-30% 비용 절감 잠재.

### 4-2. Description 10개 "Use when/for" 트리거 보완

**현재**: `grep -c "Use (when|for|PROACTIVELY)" .claude/agents/*.md/description` → 36/46 (78%) 트리거 보유.

**가장 모호한 5개** (subagent 분석):
- `cicd-reviewer`: "Use PROACTIVELY after..." → "Use when GitHub Actions / GitLab CI workflow files change"
- `terraform-reviewer`: "Use PROACTIVELY before terraform apply" → "Use when *.tf or *.tofu files change"
- `debugging-expert`: 한국어만 → "Use when service cascade failures, timeouts, or cross-service errors occur"
- `compliance-auditor`: 69 chars → "Use for SOC2 / HIPAA / GDPR / PCI-DSS audit and evidence collection"
- `otel-expert`: 한국어만 → "Use for OTel pipeline design, sampling strategy, cardinality optimization"

### 4-3. install.sh dedup 추가

**현재** (subagent 분석 기반, 본 PR 외 검증 권장): `--plugin backend-go --plugin backend-java` 같은 조합 시 `code-reviewer` 등 다중 등록 agent를 중복 로드 가능.

**수정 방향**: `INSTALLED_COMPONENTS`에 associative array 도입 (`declare -A`), plugin/workflow merge 시 이미 추가된 자산은 skip.

### 4-4. Reviewer 4쌍 역할 경계 재정의

| 쌍 | 현재 충돌 | 권장 |
|---|---|---|
| `cicd-reviewer` ↔ `cicd-security-reviewer` | 같은 PR 호출 시 중복 보고 | 전자=비용/best-practice, 후자=OWASP CI/CD + SLSA만 |
| `k8s-reviewer` ↔ `k8s-security-reviewer` | manifest 동시 검토 | 전자=PSS/RBAC/리소스, 후자=MITRE ATT&CK exploitation만 |
| `dockerfile-reviewer` ↔ `container-security-reviewer` | ~80% 오버랩 | 전자=size/build optim, 후자=CIS Docker Benchmark attack surface만 |
| `code-reviewer` ↔ `{go/java/python/frontend}-expert` | 4쌍 cross-language vs language-specific | code-reviewer=cross-language patterns, expert=idiom/perf만 |

각 description에 "vs ..." 명시 + 자동 dispatch 가이드라인 추가.

### 4-5. go-gin.md 확장 또는 thin 마킹

153줄. 누락: middleware ordering / context safety / panic recovery / graceful shutdown / goroutine leak. 확장하거나 deprecated stub와 동일한 thinness 마킹.

---

## 5. 권장만 (★ 장기)

### 5-1. Rules 빠진 영역 3건

1. **AI 에이전트 운영** — subagent fallback / timeout / parallel 결과 병합
2. **Tool 안전 (PreToolUse hook 기반)** — control-plane PoC에서 관찰되는 패턴
3. **Context 오염 감지 기준** — N회 동일 에러 → /clear 트리거

별도 RFC/ADR 후 rule 신설 권장. Migration 0002 완료 후가 적절.

### 5-2. typescript.md 5.5+ 명시 (minor)

L1 "TypeScript 5.x 타입 시스템" → "TypeScript 5.5+ 타입 시스템".

### 5-3. observability/dx 4건에 review_due frontmatter

`aiops.md`, `aiops-remediation.md`, `ebpf-observability.md`, `ebpf-observability-advanced.md` — 모델/툴체인 진화 빠른 영역. `review_due: 2026-08-08` 같은 필드로 ops 신뢰성 부스트.

---

## 6. 확정된 non-issue (헛 짚지 말 것)

- ✅ **모델 ID drift 0건** — Phase D 마커 재실행 결과 유지
- ✅ **observability/dx orphan 152개** — agents/commands는 직접 호출이 정상 (이전 리포트 결론 동일)
- ✅ **Rules 200줄 초과(cloud-cli-safety.md 202)** — 모듈식 활성화 패턴(주석 토글)이라 의도적
- ✅ **dx-onboarding 4종 / istio-gateway 3종 분리** — 카테고리 내 의도된 계층, 통합은 별도 PR (이전 리포트에 이미 권장 등록)
- ✅ **load-tester hub + 3 도구 / database-expert + -mysql** — 정당한 분리 (역할 경계 명확)

---

## 7. 다음 PR 우선순위

| 순위 | 작업 | 임팩트 | 난이도 |
|---|---|---|---|
| 1 | Agents 46개 model 재분배 (4-1) | 🔥 매우 높음 (비용 25-30%) | 낮음 (frontmatter 일괄 수정) |
| 2 | install.sh dedup (4-3) | 높음 (회귀 방지) | 중간 (회귀 테스트 필요) |
| 3 | Reviewer 역할 재정의 (4-4) | 중간 (PR 리뷰 품질) | 중간 (4쌍 + AGENTS.md 영향) |
| 4 | Description 10개 보완 (4-2) | 중간 (auto-trigger) | 낮음 |
| 5 | Rules 빠진 영역 3건 (5-1) | 중간 | 높음 (RFC 필요) |

---

## 부록 A: 4개 subagent 산출물 요약

### A-1. observability+dx 분석 (subagent #1)

- 54개 파일 본문 점검 (Grafana Agent EOL / Zipkin deprecated / SB 4 future-ref)
- EOL 매트릭스 0건 problematic — 모두 선제 문서화됨
- 의미 중복 5개 그룹 모두 의도된 계층 (logging-loki vs logging-elk vs monitoring-logs 등)
- 빈 깡통 0건 (최소 181줄)
- 종합: **4.8-4.9/5**, action 거의 없음

### A-2. 언어 skills 분석 (subagent #2)

- 33개 본문 점검
- **본문 버그 2건** (본 PR에서 처리):
  - spring-cache.md L187 — Entity Serializable 안티패턴 권장
  - python-async.md L403~ — uvloop universal 권장 caveat 부재
- thin 후보 1건: go-gin.md 153줄 (별도 PR)
- minor: typescript.md 버전 표기 (별도 PR)
- 종합: 언어별 3.5-4.5/5

### A-3. agents 메타 분석 (subagent #3)

- 46개 frontmatter + description + role 검증
- **🔴 model inherit 100%** — 비용 최적화 기회 25-30%
- description 트리거 부재 10/46 (22%)
- reviewer 4쌍 역할 경계 모호 (cicd, k8s, dockerfile/container, code-reviewer vs experts)
- 정상 분리 확인: database-expert(/-mysql), load-tester(/k6/gatling/ngrinder)
- 종합: **2.8/5** — 가장 액션이 시급한 영역

### A-4. rules+dev-logs+install (subagent #4)

- Rules 14개: 중복 미미 (security ↔ cloud-cli-safety 60% 부분 오버랩만, 분리 필요 낮음)
- 200줄 초과 1건(cloud-cli-safety.md 202) — 모듈식 활성화로 의도적
- dev-logs 10개: 반복 트러블슈팅 패턴 미발견 (rule 승격 6개월 후 재검토)
- install.sh: dedup 미구현 (subagent 분석, 본 PR 외 검증)
- 빠진 rule 영역 3건 (AI 에이전트 운영 / Tool 안전 / Context 오염)
- 종합: **4/5**

---

## 부록 B: 검증 명령

```bash
# Agents model 분포
grep -h "^model:" .claude/agents/*.md | sort | uniq -c | sort -rn

# Description 트리거 보유율
grep -h "^description:" .claude/agents/*.md | grep -cE "Use (when|for|PROACTIVELY)"

# spring-cache 본문
sed -n '180,200p' .claude/skills/spring/spring-cache.md

# python-async uvloop 섹션
sed -n '395,420p' .claude/skills/python/python-async.md

# Rules 200줄 초과
find .claude/rules -name "*.md" -type f -exec wc -l {} + | awk '$1 > 200 && $2 != "total"'
```
