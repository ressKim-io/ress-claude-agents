---
date: 2026-05-08
type: meta
phase: 0002-P6
related:
  - ../migration/0002-standardization-and-control-plane.md
  - ../migration/0002-progress.md
  - ../adr/0004-admit-baseline-sink.md
  - ../adr/0005-admit-deny-transition.md
  - 2026-05-06-p5-admit-hook.md
---

# 0002 P6 — Pilot kubernetes 카테고리 + baseline sink

P5 종결(`b5fc5bd`, CI run 25421483270 success) 후 절반 마일스톤 회고(`docs/retrospective/2026-05-06-0002-p0-p5-milestone.md`)와 함께 멈춰있던 사이클. 이틀 휴지 후 P6 진입. 이전 회고의 "단계 압축 sweet spot = 4 commit (P4) / 3 commit (P5)" 패턴 유지.

## 진입 시점 상태

- assets/skills/kubernetes/: P2 변환 5 (helm/autoscaling/security/scheduling/traffic) + 미변환 5 (gateway-api/gateway-api-migration/k8s-autoscaling-advanced/k8s-scheduling-advanced/k8s-traffic-ingress)
- 5 lint green / 108 vitest green
- ADR 디렉토리 존재 (0001~0003 Proposed, deep audit 산물). P6는 0004부터.
- baseline sink 미해결 (P5 dev-log §"Open questions" 인용)

## 변환 5개 — frontmatter 매트릭스 결정

5개 본문은 손대지 않음(P2 결정 정합). frontmatter 35줄 prepend만. 핵심은 `applies_when` 매처와 `description` Skip when 정성 표현.

| Skill | 핵심 차별 | files_present 주력 | files_contain regex 주력 | produces |
|---|---|---|---|---|
| gateway-api | Gateway API CRD 핵심 | gateway/httproute/grpcroute/tcproute/envoyproxy | `gateway.networking.k8s.io\|gateway.envoyproxy.io\|kind:(Gateway\|HTTPRoute\|...)` | k8s-manifest |
| gateway-api-migration | Ingress→Gateway 전환 | ingress + gateway + httproute 동시 | `Ingress\|gateway.networking.k8s.io\|nginx.ingress.kubernetes.io/` | migration-plan + k8s-manifest |
| k8s-autoscaling-advanced | Karpenter NodePool 중심 | nodepool/ec2nodeclass/karpenter | `karpenter.sh/v1\|consolidationPolicy:\|disruption:\s*$` | k8s-manifest, consumes cost-report |
| k8s-scheduling-advanced | topologySpread + 디버깅 | deployment/statefulset | `topologySpreadConstraints:\|maxSkew:\|podAntiAffinity:\|topology.kubernetes.io/zone` | k8s-manifest + runbook |
| k8s-traffic-ingress | NGINX/Kong rate-limit | ingress/kongplugin/kongconsumer | `nginx.ingress.kubernetes.io/limit\|konghq.com/plugins\|plugin: rate-limiting` | k8s-manifest |

## 결정 1 — base ↔ advanced 매처 overlap (사용자 결정)

문제: k8s-autoscaling(base 광범위 매처)과 k8s-autoscaling-advanced(Karpenter narrow)가 동시 활성화될 수 있음. exclude_when으로 강제 분리할지, 의도적 overlap 인정할지.

3 옵션 비교 후 사용자 Recommended 선택 = **의도적 overlap + Skip when 정성 표현**:
- exclude_when 강제 분리는 마이그레이션 진행 중(둘 다 존재) 상태에서 advanced 누락 위험
- description의 "Skip when basic only (use k8s-autoscaling)" → Claude selection 단계에서 차별
- false positive 비율은 P6.5 baseline의 핵심 메트릭 (per-skill warn rate ≥ 15% 임계 ADR 0004)

거부된 옵션 B(exclude_when 강제)는 정확도 1차원적이지만, 마이그레이션 진행이라는 비-binary 상태를 반영 못함. C(advanced 통합)는 plan §54 "kubernetes 카테고리 ~10개 전체 변환" 정신과 충돌.

## 결정 2 — gateway-api-migration의 'AND' 의미 (사용자 결정)

문제: '`Ingress` AND `Gateway`가 동시에 있을 때 = 마이그레이션 컨텍스트' 의미를 control-plane match.ts의 OR-only 매칭 안에서 어떻게 표현?

선택지:
- A: OR-매처 + description 정성 표현
- B: schema MAJOR bump (`all_of: [files_contain]`)
- C: gateway-api/SKILL.md에 마이그레이션 섹션 흡수, 별도 skill 폐기

A 채택 (사용자 Recommended). schema 확장은 P3 정책 위반 + P6 범위 외. baseline 1주에서 description-driven selection이 실제 유효한지 측정.

## lint 갱신 — hardcoded 숫자 제거

`validate-schemas.sh`의 P2 시점 `POC_FILES=(...)` 10개 hardcoded 발견. P6 신규 5개가 schema strict 검증에 안 들어감. P2 시점부터 잠재된 fragility.

→ glob 기반(`find assets/skills -mindepth 3 -name SKILL.md`)으로 변경 + `MIN_POC_COUNT=15` 회귀 차단 게이트. P7 진입 시 다시 갱신(점진 증가).

연관: `tests/skill-loader.test.ts:37`의 `toHaveLength(10)` 단언도 P6에서 fail. 단순 10 → 15가 아니라 신규 5개 회귀 단언 1건 추가(`includes the P6 kubernetes pilot skills`) — 매처 깨짐(파일은 있어도 metadata 손상) catch.

P5 회고 lessons §"lint/gitignore는 plan 단계에서 미리 점검"의 자연스러운 적용. P7 진입 시 같은 종류의 hardcoded 잠재성을 미리 검수해야 함.

## ADR 첫 활용 — 0004/0005

deep audit(2026-05-08)의 산물인 ADR 디렉토리(현재 0001~0003 Proposed)에 처음으로 **결정에 직결된 ADR** 추가:

- ADR 0004 (Accepted) — baseline sink + 메트릭 정의. 4 옵션 비교 후 환경변수 옵트인 JSONL 채택. 사용자 결정 4(Registry publish 미래) 정신과 LLM-free 정책으로 외부 텔레메트리 옵션 거부.
- ADR 0005 (Proposed placeholder) — 1주 baseline 후 채울 deny 전환 결정. Option A/B/C 3 시나리오의 임계와 작업 미리 박음.

이건 P5 회고 §"Decision Log 1줄 규율"의 다음 단계 — 큰 결정은 ADR로 분리, 작은 sub-decision은 progress.md Decision Log 1줄. P6 결정 8건은 1줄, 사실상 ADR 1건은 본문(0004), placeholder 1건(0005).

## sink 구현 — admit.ts 안 건드림

`admit.ts`는 pure function 보존. side-effect는 `index.ts` admit handler에 한정 (`appendBaselineRecord` 헬퍼 ~30줄). 환경변수 미설정 시 early return (no-op), 설정 시 mkdir -p + JSONL append + 에러 silent swallow.

silent swallow 결정: PreToolUse hook context에서 FS 권한 제한 가능. logging이 admit 자체를 깨면 hook 동작 자체가 위태. 사용자 sanity check(`wc -l $CLAUDE_AGENTS_ADMIT_LOG`)는 progress.md P6.5 setup 가이드에 명시.

vitest 2건 추가:
- env unset → sink 파일 미생성 (no-op 회귀)
- env set → JSONL 1라인 append + ADR 0004 schema 8 필드 검증 (ts ISO8601, tool, path, skill, mode, decision, reason, version)

`Read` 도구는 read-only라 admit decision = "allow" + outcome = "allow". cleanup은 try/finally + previous env restore (vitest는 process env 공유).

## 매칭 정확도 — k8s-only fixture에서 false positive 0

`control-plane/tests/profiles/k8s-only`(Helm chart only)에 신규 5개 매처 dry-run:

```
install: k8s-helm (score 65)
skip: k8s-scheduling-advanced (score 20, files_present 부분 매칭),
      k8s-scheduling (score 13.33), gateway-api (0), gateway-api-migration (0), ...
```

신규 5개 모두 threshold 50 미만 → skip. **false positive 0건**. k8s-scheduling-advanced score 20이 흥미 — `**/deployment*.yaml` 매처가 base보다 narrow한데 점수 비율이 높음. files_contain regex(topologySpread/maxSkew)가 빈 manifest엔 안 매칭되어 안전 영역.

P6.5 baseline의 다른 fixture(gateway-api 매칭 시나리오, Karpenter NodePool 시나리오 등)는 P7 카테고리 작업과 함께 fixture 추가가 자연스러움. 지금 fixture 5개 추가는 over-engineering.

## 메트릭 (P5 → P6)

| 항목 | P5 종료 | P6 종료 | Δ |
|---|---|---|---|
| Vitest | 108 | 111 | +3 (skill-loader 1 + cli sink 2) |
| Lint scripts | 5 | 5 | 0 (validate-schemas 갱신은 동일 스크립트) |
| 변환된 SKILL.md | 10 | 15 | +5 |
| ADR (Accepted) | 0 | 1 (0004) | +1 |
| ADR (Proposed) | 3 | 4 (0001-3 + 0005) | +1 |
| Decision Log 누적 | 52 | 60 | +8 |

## 비용

| 활동 | 시간 |
|---|---|
| EXPLORE (plan + reference frontmatter + 5 본문 + admit handler) | ~30분 |
| 결정 매트릭스 + 사용자 Q&A 2건 | ~15분 |
| 변환 5개 (frontmatter + 디렉토리 생성) | ~25분 |
| lint 갱신 (validate-schemas + skill-loader test) | ~15분 |
| ADR 0004 + 0005 placeholder | ~30분 |
| sink 구현 + vitest 2건 + build | ~20분 |
| progress.md + dev-log 작성 | ~25분 |
| **누적** | **~2.5시간** |

P5 회고에서 P6~P8 ~10~15시간 추정 → P6는 plan 추정 범위 내. P7 카테고리 변환이 가장 큼.

## P5 회고 lessons 적용 점검

- ✅ **단계 압축 sweet spot** — 1 commit으로 묶음 (변환 5 + lint 갱신 + sink 구현 + ADR + dev-log + progress). P5의 3 commit보다 더 압축. 변경 의미 단위가 일관(P6 = pilot)이라 분리 ROI 낮음.
- ✅ **Decision Log 1줄 규율** — 8건 박음 (52→60). 큰 결정 1건(sink + 메트릭)은 ADR로 별도 분리.
- ✅ **dev-log narrative** — 본 글. 결정 2건의 사용자 Q&A 흐름과 거부된 옵션 명시.
- ✅ **lint/gitignore 사전 점검** — validate-schemas 10 hardcoded 발견은 작업 중 catch했지만, P7 진입 시점 plan 본문에 "hardcoded 숫자 검수" 체크리스트 추가 가치.
- ✅ **의존성 정책** — sink 구현에 fs append 외 새 의존성 추가 없음. runtime deps 4/5 유지.

## 다음 — P6.5 baseline 1주

사용자가 환경변수 setup 후 일상 작업 1주. 1주 후:
1. `wc -l $CLAUDE_AGENTS_ADMIT_LOG` — 50 이상이면 메트릭 분석 진행
2. ADR 0005 본문 채움 (jq 결과 인용 + 4 임계 통과 여부 + 결정 Option A/B/C)
3. 통과 → P7 진입 + hookMode default 'warn' → 'deny'
4. 미통과 → Option B(매처 튜닝 후 재baseline 1주) 또는 Option C(warn 영구)

P7는 카테고리/주 페이스 (10주 작업, plan §54). P6.5 결과 OK 가정 시 다음 카테고리 = `go`(이미 5 PoC) 추가 변환은 비교적 적음. `observability`(24개)·`platform`(16개)·`dx`(21개) 등 큰 카테고리가 P7 후반 작업.
