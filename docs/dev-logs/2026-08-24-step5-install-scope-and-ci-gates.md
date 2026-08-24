---
date: 2026-08-24
category: fix
tier: 2
importance: high
status: resolved
tags: [install-sh, plugin-scope, ci, validator, dangling-reference, step5]
related:
  - audit/2026-08-24-agent-harness-readiness.md
  - dev-logs/2026-08-24-step3-agent-tier-demotion.md
  - adr/0007-install-sh-narrow-scope.md
---

# Step 5 — install.sh 범위 축소 결함 + 검증 CI 게이트

## Context

[2026-08-24 audit](../audit/2026-08-24-agent-harness-readiness.md) §6 **Step 5** 실행.
Step 2 수행 중 발견돼 별건으로 분리해둔 2건 + Step 3 에서 추가로 발견한 1건.

## 1. `--plugin X --with-skills` 가 범위를 무시한다

### 재현

```
$ ./install.sh --local --plugin backend-go --with-skills
설치된 skill: 272   (backend-go 가 선언한 카테고리는 go / msa / architecture = 40)
```

`git stash` 후 HEAD 에서도 동일하게 재현된다. **기존 결함이며 Step 2 의 회귀가 아니다.**

### 원인

`install.sh` 는 plugin 의 카테고리를 정확히 설치한다 (`install_skills_by_category`).
그런데 그 뒤에 오는 전체 설치 블록이 **plugin 여부를 보지 않는다.**

```bash
# 719: plugin 이 선언한 카테고리만 설치 — 여기까지는 맞다
if [[ "$WITH_SKILLS" == true && ${#PLUGIN_SKILL_CATEGORIES[@]} -gt 0 ]]; then
    for category in ...; do install_skills_by_category ...; done
fi

# 827: 그리고 이게 무조건 실행된다
if [[ "$WITH_SKILLS" == true ]]; then
    backup_and_link "$SKILLS_SOURCE" "$SKILLS_TARGET" "$INSTALL_SCOPE" "dir"   # ← skills/ 통째로
fi
```

`backup_and_link ... "dir"` 이 `skills/` 디렉터리 전체를 링크해 앞서 좁혀놓은 산출물을 덮는다.
**[ADR 0007](../adr/0007-install-sh-narrow-scope.md) 의 "안 쓰는 것까지 다 깔린다" 문제 해결이 코드상 무효화돼 있었다.**

### 수정

전체 설치는 범위를 좁히는 인자가 **하나도 없을 때만** 수행한다.

```bash
if [[ "$WITH_SKILLS" == true && ${#PLUGIN_NAMES[@]} -eq 0 && ${#WORKFLOW_NAMES[@]} -eq 0 ]]; then
    ...전체 설치...
elif [[ "$WITH_SKILLS" == true ]]; then
    log_info "[skills] Scope narrowed by --plugin/--workflow — installing only the declared skill sets."
fi
```

좁혀졌을 때 왜 전체가 안 깔리는지 사용자에게 알리는 줄을 같이 넣었다 — 조용히 적게 까는 건 조용히 많이 까는 것만큼 나쁘다.

### 검증

| 명령 | skills | 판정 |
|---|---|---|
| `--all --with-skills` | 272 | 전체 설치 경로 유지 |
| `--plugin backend-go --with-skills` | 40 (go 12 + msa 16 + architecture 12) | 범위 축소 동작 |
| `--plugin backend-go` | 0 | `--with-skills` 없으면 skill 미설치 |
| `--workflow msa-migration --with-skills` | 71 | workflow 범위 동작 |
| `--plugin backend-go --plugin messaging --with-skills` | 50 | 복수 plugin 합집합 |

> `--with-skills` **단독**은 모듈 선택 프롬프트에 걸려 비대화형에서 실패한다. HEAD 에서도 동일한 기존 동작이라 이번 수정과 무관하다 (`--all` 또는 `--modules` 와 함께 써야 한다).

## 2. `validate-schemas.sh` 가 CI 에 없었다

Step 1 이 발견한 `.agents/` dangling ref 실패가 **로컬에서만 잡혔다.** CI `drift` job 은 validator 5종 중 4종만 돌리고 있었다.

`drift` job 에 스텝을 추가했다. 검증 스크립트가 있는데 CI 가 안 돌리면 그 스크립트는 없는 것과 같다.

## 3. workflow 의 skill 참조가 죽어도 아무도 모른다 (Step 3 발견)

`install.sh` 는 존재하지 않는 skill 참조를 **조용히 건너뛴다.** 그래서 이름이 바뀌거나 skill 이 사라져도 워크플로가 반쯤 빈 채로 설치된다.

Step 3 에서 총 11건을 발견했다.

| 죽은 참조 | 실제 |
|---|---|
| `infrastructure/database-postgres` | `postgresql-operations` |
| `sre/sli-slo-design` | `sre-sli-slo` |
| `security/secure-coding-2026` | `secure-coding` |
| `security/owasp-top-10` | `owasp-top10` |
| `kubernetes/k8s-cluster-evolution` | `compose-to-k8s` |
| `kubernetes/k8s-troubleshooting` | `k8s-troubleshoot-trees` |
| `sre/finops-fundamentals` | `finops` |
| `sre/finops-unit-economics` | `finops-advanced` |
| `sre/load-testing-strategy` (2곳) | `load-testing` |
| `msa/idempotent-consumer` / `msa/distributed-tracing-trouble` / `messaging/outbox-pattern` | 대응 skill 없음 → 실재 skill 로 교체 |

전부 수정하고, `validate-agent-handoff.sh` 에 `check_skill_refs` 를 추가했다. workflow 의 `skills:` (inline 배열 + 리스트 두 형태) 와 plugin/workflow 의 `categories:` 를 모두 검사한다.

**음성 테스트로 확인**했다 — 죽은 참조를 고의로 주입하니 정확히 잡고 exit 1 한다.

```
MISSING  .claude/workflows/new-domain.yml:80  →  msa/DOES-NOT-EXIST
MISSING  plugins/backend-go.yml:8  →  category:NOPE-CATEGORY
FAIL  죽은 skill/category 참조: 2건 (install.sh 가 조용히 건너뛴다)
```

## 4. 범위 회귀 방지 CI 케이스

기존 `install-macos` 스모크 job 은 **install.sh 가 에러 없이 끝나는지만** 본다. 1번 결함은 에러 없이 잘못된 결과를 내므로 이 job 을 통과했다.

`--plugin backend-go --with-skills` 의 설치 개수를 카테고리 기대값과 대조하는 스텝을 추가했다. 전체 개수와 같아도 실패시킨다.

## 배운 것

세 건 모두 **"조용히 잘못되는" 부류**다. 예외도 없고 종료 코드도 0이다.

- 1번: 요청보다 많이 설치 — 결과가 "성공"으로 보인다
- 3번: 요청보다 적게 설치 — 역시 "성공"으로 보인다
- 2번: 검증 스크립트는 있는데 안 돌린다

셋 다 CI 가 **개수/실재성을 대조**하기 전에는 잡히지 않는다. exit code 만 보는 스모크 테스트는 이 부류에 무력하다.

## 후속

- ADR 0007 의 `--skill <cat>/<name>` / `--agent <name>` / `--rule <name>` 단위 옵션은 여전히 **PR-8 미착수**. 본 수정은 plugin/workflow 범위가 존중되도록 만든 것이지 자산 단위 선택을 구현한 게 아니다.
- `--all` 이 agents / rules 를 설치하지 않는다 (commands + skills 만). 도움말의 "Install all modules" 와 어긋난다 — **범위 밖이라 손대지 않았고 목록으로만 남긴다.**
