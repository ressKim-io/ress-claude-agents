---
date: 2026-05-12
category: meta
project: ress-claude-agents
tags: [verification, owasp, sdd, phase-workflow, skill-quality, external-source]
---

# PR #18-20 검증 후 외부 출처 사실 오류 + 부재 자산 정정 (PR #21/#22)

## Context

직전에 머지된 메타 자산 PR 3건(#18 M1-M10 skills / #19 pitfall + domain rules / #20 commands + templates)의 신규 자산 31건을 외부 검증 + 변수 일관성 + dangling reference 점검 관점에서 사후 검토했다.

검토는 3개 subagent 병렬로 카테고리 분담:
- PR #18: 외부 출처(공식 docs / 학술 / 실무) 정확성 + 일반화 품질
- PR #19: 도메인 정확성(EKS/Istio/Terraform/OTel) + controller 잔재 점검
- PR #20: 변수화(`{PROJECT_NAME}` 등) 일관성 + 의존 자산 존재 여부

## Issue

검토 결과 31건 중 3건이 정정 필요:

1. **M5 `defense-in-depth-layers.md`** — frontmatter에 "OWASP K8s Top 10 2025 기반"이라 명시했지만 본문 안티패턴 5종 헤딩 4건이 2022 버전 번호/제목으로 매핑되어 있음. 보안 룰이라 신뢰도 직결.
   - K02 Supply chain vulnerabilities (2022) ← 2025엔 직접 카테고리 없음
   - K03 Overly permissive RBAC (2022) → 2025는 K02 Overly Permissive Authorization Configurations
   - K06 Broken authentication (2022) → 2025는 K09
   - K08 Network segmentation (2022) → 2025는 K05

2. **M3 `config-explicit-defaults.md`** — 외부 근거 섹션 L180 "Kristian Glass — config sprawl 명명" attribution이 부정확. WebFetch로 블로그 원문 검색 결과 "config sprawl" 또는 "configuration sprawl" 표현 부재.

3. **`phase-workflow.md`** — rule이 `/phase-start` 커맨드(`.claude/commands/phase-start.md`)와 SDD 템플릿(`docs/templates/sdd-template.md`)을 참조하지만 둘 다 부재. path-scoped 자동 로딩되지만 Gate 1-5 흐름을 시작할 수단이 없어 사실상 비활성.

## Action

PR을 의미 단위로 2개 분리:

### PR #21 — fix(skills): OWASP K8s 2025 mapping + Glass attribution (804c02f)

- `defense-in-depth-layers.md` 안티패턴 4건 헤딩 정정 (2025 정식 번호/제목으로)
- `defense-in-depth-layers.md` L127 "Goti 실사례에서 가장 빈도 높음" → "운영 환경에서 빈도 높음" 일반화
- `config-explicit-defaults.md` L180 출처 부속 설명 정정 (`"config sprawl" 명명` → `12-factor config 함정 정리`)
- 본문 내 "config sprawl" 용어는 자체 사용 패턴으로 유지

### PR #22 — feat(workflow): /phase-start + SDD template (c867f95)

- `.claude/commands/phase-start.md` 신규 (131줄): Phase 진입점, 11항목 체크리스트, Gate 1-5 안내, Gate 위반 감지 매트릭스
- `.claude/templates/sdd.md.template` 신규 (162줄, 9 섹션): Background / Requirements / Design / Implementation Steps (의존성) / Test Strategy / Phase Gates / Risks / Rollback / References
- `phase-workflow.md` reference 경로 `docs/templates/sdd-template.md` → `.claude/templates/sdd.md.template` 갱신 (다른 5 template과 위치 일관)

### 검증 패턴(추출)

자산 추가 PR 직후 적용할 2단계 사후 검증:

```
1. 외부 출처 spot-check (WebFetch)
   - 인용된 공식 docs / 블로그 / paper의 실제 내용 확인
   - 버전 명시된 표준(OWASP, OTel, CIS 등)은 번호/제목까지 일치 확인
   - 표현 인용("X 가 명명")은 원문 검색으로 attribution 검증

2. Dangling reference grep
   - rule/command/skill 본문에 등장하는 다른 자산 경로(`/x` command,
     `.claude/.../X.md`, `docs/.../X.md`)를 `ls` 또는 `find`로 존재 확인
   - 부재한 자산 = 후속 PR 또는 즉시 보강
```

## Result

- 보안 룰 신뢰도 회복(M5는 OWASP 2025 권위 기반)
- Glass attribution 오류 해소 → 다른 프로젝트에 install 시 verbatim 인용 안전
- phase-workflow rule이 실효화 — `/phase-start <slug>` 호출로 Gate 1-5 흐름이 실제로 시작됨
- 다음 프로젝트 fork 후 30분~2시간 부트스트랩 흐름이 완결 (Phase 게이트 포함)
- 31건 자산 중 28건이 즉시 활용 가능 / 3건만 정정 → 메타 자산 품질 90%+ 유지

남은 일반화 권장(이번 범위 밖, hard fail 아님):
- PR #18 "Goti" 라벨 5건 (M4/M5/M8/M9 사례 라벨 — `${PROJECT_NAME}` 또는 "운영 사례"로 치환)
- PR #19 `logging-application-convention.md` 티켓팅 도메인 잔재 (Queue/Seat/Resale prefix + L186-211 모듈 섹션 + dead cross-ref)
- 7개 commands `.claude/commands/manifest.yml` 일괄 등록 (PR #20의 누락 패턴 + /phase-start)

## Related Files

- `.claude/skills/kubernetes/defense-in-depth-layers.md` (정정)
- `.claude/skills/architecture/config-explicit-defaults.md` (정정)
- `.claude/rules/phase-workflow.md` (reference 경로 갱신)
- `.claude/commands/phase-start.md` (신규)
- `.claude/templates/sdd.md.template` (신규)
- PR #21: https://github.com/ressKim-io/ress-claude-agents/pull/21
- PR #22: https://github.com/ressKim-io/ress-claude-agents/pull/22
- 머지 커밋: `804c02f` (PR #21), `c867f95` (PR #22)
