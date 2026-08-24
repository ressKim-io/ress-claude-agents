---
date: 2026-08-24
category: refactor
tier: 2
importance: critical
status: resolved
tags: [harness-engineering, agent-tier, demotion, skill-migration, workflow-schema, step3]
related:
  - audit/2026-08-24-agent-harness-readiness.md
  - dev-logs/2026-08-24-step2-skill-skillmd-migration.md
  - adr/0008-asset-tier-policy.md
---

# Step 3 — agent 티어 강등: 레퍼런스를 skill 로 내리기

## Context

[2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) §6 **Step 3** 실행.
F6(agent 티어 오배치) 해소. Step 2 로 skill 260개가 실제로 로드되기 시작했으므로 "옮겨갈 곳이 동작한다"는 전제가 충족된 상태에서 착수했다.

## 착수 직후 발견 — 판정 정규식 오탐 (F7)

대조를 시작하자마자 초판 판정이 틀렸다는 게 드러났다.

§3.1 의 출력 계약 판정 정규식은 `Output Format|Report Template|출력` 인데, 이 레포가 실제로 쓰는 표기는 **`## Output Template(s)`** 다. 매칭되지 않는다.

```bash
# 초판 (틀림)
grep -qE "^## .*(Output Format|Report Template|출력)" "$f"
# 정정
grep -qE "^## .*(Output Format|Report Template|Output Template|출력)" "$f"
```

이 한 단어 때문에 **7개가 오분류**됐다.

| 방향 | 대상 | 실제 |
|---|---|---|
| 강등으로 잘못 분류 | `architect-agent` `finops-advisor` `mlops-expert` `platform-engineer` `product-engineer` | ` ```markdown ` fence 안에 반환할 보고서 구조 보유 → borderline |
| borderline 으로 잘못 분류 | `migration-expert` `tech-lead` | 프로토콜 + 출력 계약 양쪽 보유 → 정당한 agent |

반대 방향 오탐도 하나 있었다. `pr-review-bot` 의 `## Workflow 파일 생성 헬퍼` 는 GitHub Actions **YAML 생성기**인데 `Workflow` 부분일치로 조사 프로토콜로 잡혔다. 손으로 확인해보니 본문 296/486줄(61%)이 도구 설정 카탈로그였다 → 강등.

### 왜 손 검증이 이걸 못 잡았나

§3.3 은 "휴리스틱 오탐을 의심해 6개를 손으로 검증했고 전부 판정이 유지됐다"고 적었다. 그런데 그 6건의 검증은 전부 **조사 프로토콜 축**만 봤다 ("Step 1/2/3 은 방법론 설명이지 실행 프로토콜이 아님"). 출력 계약 축은 정규식 결과를 그대로 신뢰했다.

**정규식이 틀린 축을 손 검증이 덮지 못하면 오탐은 살아남는다.** 손 검증 대상을 고를 때가 아니라, 손 검증할 **축**을 고를 때 편향이 들어갔다.

## 대조 결과

강등 14개(+ pr-review-bot = 15) × skill 260개를 H2/H3 구조 비교 + 키워드 실측(`grep -c`)으로 전수 대조했다. 전체 표는 audit §3.5.

| 그룹 | 건수 | 처리 |
|---|---|---|
| B. 폐기 — 기존 skill 이 이미 커버 | 5 | 고유분만 흡수 후 삭제 |
| C. 신규 skill 로 이관 — 커버 0 | 8 | 신규 skill 생성 |
| D. 부분 이관 — 분할 | 2 | 성능/보안 축으로 각 2개 분할 |

대조에서 실제로 갈린 지점 몇 개:

- `python-expert`: `python-async` 가 TaskGroup·asyncpg·Semaphore·aiohttp·redis 를 그대로 갖고 있어 거의 완전 중복. 고유분은 Framework Selection 표와 `pyproject.toml` 2건뿐이었다.
- `redis-expert`: `redis-streams` 가 있어서 중복일 줄 알았는데 Streams **전용**이었다. 캐싱·Sentinel·Cluster·Redlock·Operator·메모리 커버가 **0**. 전량 신규 이관.
- `messaging-expert`: `rabbitmq` skill 에 `quorum` 은 16회 나오는데 `queue depth` / `unacked` / `memory alarm` 은 **각 0회**. 트러블슈팅 축이 통째로 비어 있었다.
- `otel-expert`: 본문에 `## 참조 스킬` 이 있는 index 구조. 고유분 **0**. 그대로 폐기.

## 실행 규율

**"1건 먼저 검증" 게이트**를 `load-tester-gatling` 으로 통과시켰다. 고른 이유는 plugins/workflows 참조 0건 + 기존 skill 중복 0건이라 신규 skill 생성 → agent 삭제 → inventory → validator → install 스모크 전 경로를 최소 위험으로 관통할 수 있어서다.

게이트에서 **참조가 0건이 아니라는 것**이 바로 드러났다. plugins/workflows 만 0이고 README·`_handoff.yml`·자매 agent·validator LEGACY 배열에 7건이 있었다. 이후 커밋부터 참조 갱신을 기본 작업에 포함시켰다.

커밋은 카테고리/의미 단위로 10개. 매 커밋 전 validator 5종 + shellcheck + inventory 재생성을 돌렸다.

## workflow stage 실행자 표기 규약 도입

강등이 workflow 를 비운다는 게 중간에 드러났다. `handoff-flow` 워크플로의 구현 stage 가 전부 언어 expert 를 실행자로 지정하고 있었고, 강등 후 `produces: [code]` 는 `frontend-expert` 하나만 남았다.

사용자 결정으로 표기 규약을 새로 만들었다.

```yaml
  - name: saga-design
    agent: (main)          # 서브에이전트 없음 — skill 주도
    inputs: [bounded-context, api-contract]
    outputs: [code, runbook]
    skills: [msa/msa-saga, msa/msa-event-driven, msa/distributed-lock]
```

- `<agent-name>` = 해당 subagent 에 위임 (별도 컨텍스트)
- `(main)` = 서브에이전트 없이 메인 세션이 `skills:` 를 로드해 수행

규약은 `.claude/workflows/_base.yml` 헤더에 명시했다. 9개 stage 에 적용.

## 부수 발견 — workflow 의 dangling skill 참조

stage 를 고치다가 `skills:` 목록의 참조가 실제 skill 과 안 맞는 걸 여러 건 발견했다. install.sh 는 없는 skill 을 조용히 건너뛰므로 **아무도 모르게 죽어 있었다.**

수정한 것: `infrastructure/database-postgres` / `sre/sli-slo-design` / `security/secure-coding-2026` / `security/owasp-top-10` / `msa/idempotent-consumer` / `msa/distributed-tracing-trouble` / `messaging/outbox-pattern`

아직 남은 것: `kubernetes/k8s-cluster-evolution` `kubernetes/k8s-troubleshooting` `sre/finops-fundamentals` `sre/finops-unit-economics` `sre/load-testing-strategy` — **workflow skill 참조를 검증하는 CI job 이 없다.** Step 5 의 `validate-schemas.sh` CI 편입 논의와 같은 성격이다.

## 결과

| 항목 | 이전 | 이후 |
|---|---|---|
| agents | 49 / 19,819줄 | **34 / 12,736줄** (-36%) |
| skills | 260 / 97,912줄 | **272 / 102,102줄** |
| 강등 대상 | 19 (측정 오류) → 15 | **0** |
| 정당한 agent | 19 | **21** |
| borderline | 11 | **13** (결손 축 목록화 → Step 4) |

신규 skill 12개: `load-testing-gatling` `postgresql-operations` `mysql-operations` `redis-operations` `broker-troubleshooting` `virtual-waiting-room` `anti-bot` `go-performance` `go-security` `jvm-performance` `spring-security-review` `pr-review-automation`

`load-tester` 4→1, `database-expert` 2→0 으로 §3.4 과잉 분할 2건도 해소됐다. 엔진별/도구별 분리는 skill 층에서 유지했다 — ADR 0008 §3 의 승인된 분할 축이고, 합치면 description 매칭이 뭉개져 발견이 나빠진다.

## 배운 것

1. **판정 자동화의 정규식은 그 자체가 검증 대상이다.** 한 단어(`Template` vs `Format`) 때문에 7개가 뒤집혔다. 부록 A 의 재측정 명령을 문서에 박아둔 게 다행이었다 — 재현이 되니까 오탐도 잡혔다.
2. **손 검증은 축 단위로 설계해야 한다.** "6개를 손으로 봤다"는 표본 수의 문제가 아니라 **어느 축을 봤는가**의 문제였다.
3. **자산을 지우면 그 자산을 가리키던 것들이 조용히 죽는다.** agent 15개를 지우면서 참조 100건 이상을 고쳤는데, 그중 상당수는 CI 가 검증하지 않는 위치(README, docs/guides, skill 본문, workflow skills 목록)였다. 검증되지 않는 참조는 시간이 지나면 반드시 drift 한다.

## 후속

- **Step 4**: borderline 13 의 결손 축 보강 (audit §3.6 표), `disallowedTools`/`permissionMode`/`effort` frontmatter, `## Verification Criteria`
- **Step 5**: `--plugin X --with-skills` 범위 무시 결함, `validate-schemas.sh` CI 편입
- **신규**: workflow `skills:` 참조 검증 CI job (본 Step 에서 발견)
