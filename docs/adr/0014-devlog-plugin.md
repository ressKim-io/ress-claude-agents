# ADR 0014 — dev-log 자산을 `devlog` plugin 으로 분리해 user scope 로 켠다

- **Status**: Accepted
- **Date**: 2026-11-12
- **Driver**: dev-log 를 이 레포 밖의 모든 레포에서도 각 레포의 `docs/dev-logs/` 에 남기고 싶다는 사용자 요청
- **Partially supersedes**: [ADR 0012](0012-native-plugin-structure.md) §Decision 2 의 "이 레포는 `dx` 만 켠다". plugin 구조 자체는 유지한다.
- **Related**: [ADR 0013](0013-ops-perspective-placement.md)

## Context

dev-log 명령 8개(`log-*` 5개, `consolidate-devlogs`·`promote-devlog`·`archive-devlog`)와 `dev-logger` agent 는 `dx` 안에 있었다. `dx` 는 이 레포의 `.claude/settings.json` 에서만 켜져 있다. 그래서 다른 레포에서는 이 명령들을 쓸 수 없었다. 2026-11-12 에 레포 밖 디렉토리에서 `claude plugin list` 를 돌리면 `dx@ress` 가 `✘ disabled` 로 나왔다.

user scope 로 켤 단위를 고를 때 걸리는 사실 (✅ 2026-11-12 공식 docs):

| 사실 | 출처 |
|---|---|
| user scope plugin 은 "enabled for you in every project on this computer" | https://code.claude.com/docs/en/plugins |
| "Plugin skills are not affected by `skillOverrides`. Manage those through `/plugin` instead." plugin 의 일부만 끌 수 없다 | https://code.claude.com/docs/en/skills |
| plugin 에 rule 을 실을 수 없다. "To include instructions that load into Claude's context, put them in a skill." | https://code.claude.com/docs/en/plugins-reference |
| "Personal rules in `~/.claude/rules/` apply to every project on your machine." | https://code.claude.com/docs/en/memory |
| "A path-scoped rule loads when Claude uses the Read, Write, or Edit tool on a matching file." | https://code.claude.com/docs/en/memory |
| 로컬 경로로 추가한 marketplace 의 상대 경로 plugin 은 "loads in place from its path inside the marketplace folder" | https://code.claude.com/docs/en/plugins/loading.md |

마지막 사실 때문에 `devlog-lifecycle.md` 의 "작성 시점 트리거" 는 dev-log 파일을 열기 전에는 컨텍스트에 없다. 이 rule 은 `paths:` 가 붙어 있기 때문이다.

## Decision

1. dev-log 명령 8개와 `dev-logger` agent 를 새 `devlog` plugin(`plugins/devlog/`)으로 옮긴다. 명령 이름은 `/dx:log-trouble` 에서 `/devlog:log-trouble` 으로 바뀐다.
2. `where`·`related` 는 `dx` 에 남긴다. 둘 다 레포에 `INDEX.md` 와 `docs/repo-cards/` 가 있어야 동작한다. `session-save`·`session-end` 도 남긴다. dev-log 가 아니라 세션 컨텍스트를 저장하는 명령이다.
3. 이 레포는 `dx`·`devlog` 를 켠다. ADR 0012 §Decision 2 의 "`dx` 만 켠다" 를 고친다. 자산을 옮긴 것이라 이 레포에서 로드되는 총량은 같다.
4. 옮기기 전에 dev-log frontmatter 를 `devlog-lifecycle.md` 표준 하나로 맞춘다. `feedback` category 를 표준에 더한다.
5. 사용자 개인 설정(레포 밖)은 다음과 같다. `devlog@ress` 를 user scope 로 설치하고, `~/.claude/rules/` 에 `paths` 없는 짧은 트리거 rule 을 둔다. 이 rule 은 조건이 맞으면 묻지 않고 `docs/dev-logs/` 에 쓰게 한다.

## 대안 비교

| 안 | 강점 | 약점 | 판단 |
|---|---|---|---|
| a. `dx` 전체를 user scope 로 켠다 | 설정 한 줄. 레포 변경 없음 | `skillOverrides` 가 plugin skill 에 적용되지 않아 `dx` 의 command·skill·agent 가 전부 모든 레포에 실린다. ADR 0012 가 피하려던 목록 예산 문제가 모든 레포로 번진다 | ❌ |
| **b. `devlog` plugin 분리 + user scope** | dev-log 자산만 모든 레포에 실린다. 설치 단위가 기존 plugin 구조와 같다 | 명령 이름이 바뀐다. 레포 문서의 참조와 생성기 맵, 루트 README 표를 고친다 | ✅ 채택 |
| c. `~/.claude/{skills,agents,rules}` 에 symlink | 레포 변경 없음 | 이 레포에서는 `/log-trouble` 과 `/dx:log-trouble` 이 함께 뜨고 rule 도 두 번 로드된다. 개인 설정이라 git 이 추적하지 않는다. 다른 사용자는 가져갈 수 없다 | ❌ |

ADR 0013 은 새 plugin 대신 기존 plugin 에 두기로 했다. 그때는 새 skill 이 들어갈 자리가 문제였고, 켜는 단위는 바뀌지 않았다. 이번에는 켜는 단위 자체가 달라야 한다. `dx` 의 나머지 없이 dev-log 만 모든 레포에 켜야 하기 때문이다.

## Consequences

**얻는 것**
- 이 기기의 모든 레포에서 `/devlog:log-*` 와 Tier 관리 명령을 쓸 수 있다
- dev-log 형식이 rule·명령·agent·템플릿에서 하나로 맞는다

**잃는 것 / 위험**
- `/dx:log-*` 를 외운 사용자는 새 이름을 써야 한다. 이력 문서(`docs/dev-logs`, `docs/audit`, `docs/migration`, 이전 ADR)의 옛 이름은 그대로 둔다
- `devlog-lifecycle.md` 는 plugin 에 실리지 않는다. 설치본의 형식 기준은 각 `log-*` 명령의 출력 형식과 "frontmatter 값" 절이다
- `ress` marketplace 는 로컬 경로라 plugin 을 작업 트리에서 읽는다. `plugins/devlog` 가 없는 브랜치를 checkout 하면 그동안 전역 devlog 가 로드되지 않는다
- 트리거 rule 은 개인 설정이라 이 레포가 추적하지 않는다. 자동 작성이 실제로 일어나는지는 새 세션에서만 확인된다 ⚠️ 미확인 (2026-11-12, 이 결정을 만든 세션 안에서는 확인할 수 없음)

## 검증

```bash
./scripts/verify-plugins.sh devlog dx   # 로드 확인 (로컬, 모델 호출 없음)
./scripts/validate-catalog.sh           # marketplace·plugin.json·enabledPlugins 일치, /plugin:명령 참조
python3 scripts/generate-plugin-readmes.py validate
```

레포 밖 디렉토리에서 `claude plugin list` 를 돌리면 `devlog@ress` 가 `✔ enabled` 로 나와야 한다.

## Sources

- Context 표의 공식 docs 5곳, 2026-11-12 확인 (web-fetch subagent)
- 레포 사실: 본문에 적은 파일, 2026-11-12 확인
