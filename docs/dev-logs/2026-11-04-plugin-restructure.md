---
date: 2026-11-04
category: meta
tier: 2
importance: major
status: resolved
tags: [plugins, marketplace, skills, description, gates, migration, claude-5-5]
related:
  - adr/0012-native-plugin-structure.md
  - migration/0003-plugin-restructure.md
  - audit/2026-11-04-claude-spec-verification.md
---

# 영역별 plugin 구조 개편과 현행 Claude 사양 정합

skill 272개가 한곳에 몰려 있어 무엇을 가져갈지 판단하기 어려웠고, 규칙은 Opus 4.7 기준이었다. 결과와 수치는 [Migration 0003](../migration/0003-plugin-restructure.md), 구조 결정은 [ADR 0012](../adr/0012-native-plugin-structure.md) 에 있다. 여기에는 작업 중 나온 문제와 재발 방지를 남긴다.

## 문제와 재발 방지

| 문제 | 어떻게 잡았나 | 원인 | 재발 방지 |
|---|---|---|---|
| 치환 도구가 코드 안의 `mws[i](h)`, `[name](file.md)` 을 링크로 보고 URL 로 바꿨다. `dx` 예시 5줄은 PR #42 로 올라갔다 | 치환 후 `.claude/skills` 잔여 언급을 grep 하다 발견 | 링크 정규식이 코드 구간을 구분하지 않았고, 링크 게이트도 코드 구간을 건너뛰어 CI 가 통과했다 | 도구를 코드 인식으로 고치고 원본과 전수 대조. 일회성 도구라 영구 게이트는 두지 않았다 |
| 위 수정이 `` [`/x`](...) `` 처럼 라벨에 백틱이 있는 정상 링크까지 건너뛰었다 | 링크 게이트 | 백틱으로 줄을 나눠 링크가 쪼개졌다 | 링크 시작 위치 앞의 백틱 수로 판단 |
| `/observability:observability:observability-cost` 접두사 중복 | 치환 전수 분류 | skill 과 plugin 의 이름이 같은데 정규식이 `:` 뒤를 막지 않았다 | 참조 게이트가 plugin 접두사 표기를 전부 해석 |
| XML `</database>` 가 `</infra:database>` 로 바뀌었다 | 치환 전수 분류 | skill 이름이 경로처럼 보였다 | 도구의 앞쪽 경계에 `<` 추가. 펜스 안 치환을 원본과 대조 |
| `/gitops-argocd로` 처럼 조사가 붙은 언급 3건이 빠졌다 | 잔여 언급 스캔 | Python `\w` 가 한글에도 일치해 경계로 보지 않았다 | ASCII 경계로 재스캔. 규칙·AGENTS.md 의 bare 이름은 게이트가 실패시킨다 |
| `/terraform:security` 의 새 이름이 skill `terraform-security` 와 겹쳐 command 가 사라졌다 | `make verify-plugins` 의 infra 25/25 가 예상(26)과 달랐다 | 같은 이름이면 skill 이 이긴다. 계획의 이름 규칙이 이를 고려하지 않았다 | `/infra:terraform-security-check` 로 변경, 겹침 게이트 추가 |
| 제거한 스텁 3개가 가이드와 README 에서 쓰이고 있었다 | 제거 전 grep | 계획의 "들어오는 참조 없음" 이 skill 간 링크만 본 결과였다 | 대체 skill 로 치환 |
| `plugin.json` 16개가 빈 파일이 됐다 | README 생성기의 JSON 오류 | `git add -N` 으로 올린 뒤, 도구 출력을 되돌리는 `git checkout --` 목록에 함께 들어갔다 | 다시 생성. **변경 목록을 일괄 되돌릴 때 intent-to-add 항목을 제외한다** |
| `skill-category` 파서를 지운 뒤 "영역 없음" 테스트 2건이 의미를 잃었다 | 음성 테스트 | 영역을 경로에서 얻게 되어 그 분기가 사라졌다 | 테스트 삭제. 옛 폴더가 되살아나면 실패하는 테스트로 대체 |
| 3단계에서 "살아 있는 문서만 고쳤다" 고 했지만 옛 rule 경로가 남았다 | 4단계의 경로 grep | 링크 게이트 범위 밖이었다 | 게이트를 `docs/architecture`, `docs/guides`, `docs/onboarding`, README 로 확대 |
| `.md` 로 된 README 를 `.claude/rules/` 에 두면 rule 로 로드된다 | 사전 검토 | `.claude/rules/**/*.md` 가 전부 로드 대상이다 | 폴더 설명을 AGENTS.md 에 둔다 |
| CI `Shellcheck` 가 #47~#55 에서 전부 실패했다 (SC2059) | PR 을 연 뒤의 CI | `scripts/test-gates.sh` 의 테스트 도우미가 `$fields` 를 `printf` 형식 문자열에 넣었다. 아래 `make lint` 때문에 로컬에서 드러나지 않았다 | `%b` 인자로 옮기고 생성 파일이 바이트 단위로 같음을 확인. 뒤 브랜치는 merge-forward 로 반영 (force push 없음) |
| `make lint` 가 shellcheck 실패에도 exit 0 이었다 | 위 실패의 원인을 좇다 발견 | `find ...; echo` 형태라 `echo` 의 종료 코드만 남았다. 2026-01-29 (`34fed08`) 부터 그랬고, 머지 전 사전 게이트가 이 결과를 믿었다 | `&&` 로 변경, `should_fail_make_lint_when_shellcheck_reports_issue` 추가. 고친 `make lint` 가 새 테스트 줄의 SC2016 을 바로 잡았다 |

## 계획의 확인 방법이 틀렸던 것

- `claude plugin details dx` 는 프로젝트의 marketplace 를 읽지 않아 레포 루트에서 "not found" 다. 자체 활성화는 `initialize` control request 로 확인한다. 모델을 호출하지 않아 토큰도 들지 않는다.
- `claude plugin validate --strict` 는 `version` 누락으로 실패한다. 커밋 SHA 로 업데이트를 감지하려고 `version` 을 일부러 비웠으므로 `version` 경고만 허용한다.
- `claude plugin marketplace add .` 는 형식 오류다. `./path` 또는 `owner/repo#ref` 를 쓴다.

## 재사용할 만한 것

- **rename 과 내용 변경을 커밋으로 나눈다.** 인덱스에 rename 만 올리고 작업 트리에 치환을 두면, 커밋마다 `git diff --cached -M100%` 로 순수 이동을 증명할 수 있다.
- **새 도구 출력은 원본과 줄 단위로 대조한다.** 줄 수가 같으면 코드 구간의 변경만 뽑아 볼 수 있다. 게이트가 보지 않는 구간을 보는 유일한 방법이었다.
- **subagent 결과는 기계로 다시 검사한다.** description 의 영문 용어를 본문과 대조해 근거 없는 내용이 없음을 확인했다. 자체 보고만으로는 알 수 없다.
- **`initialize` control request** 는 무토큰으로 실제 로드 상태를 보여 준다.
- **`CLAUDE_CONFIG_DIR` 를 임시 폴더로** 두면 사용자 설정을 건드리지 않고 설치를 시험할 수 있다. 브랜치 지정(`owner/repo#ref`)을 쓰면 머지 전에도 된다.
- **통과만 해 온 게이트는 먼저 실패시켜 본다.** `make lint` 는 약 9개월 동안 실패할 수 없었다. 로컬 확인은 CI 와 같은 명령으로 하고, 게이트를 믿으려면 음성 테스트를 둔다.
- **변수로 명령을 돌리는 반복문은 bash 파일로 실행한다.** 이 환경의 Bash 도구는 zsh 라 `$var` 가 단어로 나뉘지 않는다. 공백이 든 명령 5건이 거짓 FAIL 로 나왔고 bash 로 다시 돌리니 모두 통과했다.
- **strict 보호 규칙 아래의 체인 머지는 스크립트로 돌린다.** `gh pr edit --base main` → 뒤처졌으면 `gh pr update-branch` → CI 대기 → `gh pr merge --merge --match-head-commit <sha>` 순서다. `--admin` 없이 #37~#54 를 약 1시간에 머지했다. 머지마다 `main` tree 와 PR head tree 가 같은지 대조하면 잘못된 머지를 바로 알 수 있다.

## 남은 일

[Migration 0003 §실행하지 못한 것](../migration/0003-plugin-restructure.md#검증) 참조.
