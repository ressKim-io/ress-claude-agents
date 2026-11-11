<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# devlog

dev-log — 트러블슈팅·결정·meta·피드백 기록, Tier 산출·승격·archive

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install devlog@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/devlog/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`process/devlog-lifecycle.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/process/devlog-lifecycle.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Agents (1)

| 이름 | 설명 |
|---|---|
| `devlog:dev-logger` | 개발 과정 기록 에이전트. AI 수정 요청(feedback), 아키텍처 결정(decision), 시스템 개선(meta), 트러블슈팅(troubleshoot) 기록을 구조화된 마크다운으로 저장 |

## Commands (8)

| 이름 | 설명 |
|---|---|
| `/devlog:archive-devlog` | Tier 4 dev-log를 _archive/ 로 이동, replaced_by 링크 보존. superseded 처리 |
| `/devlog:consolidate-devlogs` | docs/dev-logs/*.md tier 자동 산출, 클러스터 발견, superseded 식별. dry-run 기본, 사용자 승인 후 적용 |
| `/devlog:log-decision` | 기술/아키텍처 의사결정을 기록합니다. A vs B 선택, 트레이드오프, 근거 등 |
| `/devlog:log-feedback` | AI 출력 수정 요청을 기록합니다. 코드 패턴 불일치, 누락, 잘못된 접근 등을 기록 |
| `/devlog:log-meta` | Rule, Skill, Agent 추가/변경 사유를 기록합니다. AI 워크플로우 자체의 개선 기록 |
| `/devlog:log-summary` | 현재 세션의 주요 활동을 자동 요약합니다. 세션 종료 전에 실행 권장 |
| `/devlog:log-trouble` | 트러블슈팅 과정을 기록합니다. 에러 원인 분석, 해결 과정, 회귀 테스트 |
| `/devlog:promote-devlog` | Tier 2 dev-log를 ADR/skill로 승격 (Episodic → Semantic). 패턴 정착 시 사용 |
