# 2026-05-05 — Control Plane 표준화 토의: 결정에 이르는 길

> 본 문서는 Migration 0002의 **사고 과정·논의 흐름**을 narrative로 보존한다.
> 결과물(`0002-standardization-and-control-plane.md`)이 "무엇을 할 것인가"라면,
> 본 문서는 "어떻게 그 결론에 도달했는가"의 기록이다. 나중에 글로 풀어쓸 때 1차 재료.

> 글로 발전시킬 가설 제목 후보:
> - "AI 코딩 에이전트 표준화 — RDB 인덱스 비유에서 K8s scheduler까지"
> - "옵티마이저를 LLM 밖으로: 결정적 매칭이 표준화의 본질이었다"
> - "Skill 활성화 50% 동전 던지기를 100%로: 8개 도구가 호환되는 자산을 만드는 법"

---

## 1. 출발점 — RDB 인덱스 비유와 Ollama 가설

토의는 한 가지 직관에서 시작했다. 프로젝트가 커지면 AI가 한 번에 읽을 수 있는 양은 한정된다. 그러면 RDB가 데이터가 많아질 때 인덱스를 만들어 빠르게 찾는 것처럼, 코드베이스에도 인덱스가 필요하지 않을까. 단 RDB의 옵티마이저가 결정적이듯 우리 시스템의 "옵티마이저 역할"도 결정적이어야 표준이 된다. 그런데 LLM은 모델·버전마다 다르게 동작한다. 그래서 Ollama 같은 로컬 LLM을 옵티마이저로 둬서 일관성을 잡으면 어떨까 — 이게 첫 가설이었다.

이 비유에서 짚을 점은 두 개였다.

첫째, RDB 인덱스는 **schema가 안정적**이지만 코드베이스는 매일 변한다. 즉 인덱스 갱신 비용·지연이 핵심 변수가 된다.

둘째, 옵티마이저를 LLM에 맡기면 그 자체가 stochastic이라, 같은 질문에 다른 retrieval 경로가 나온다. 표준화의 적이다.

검색 전에 의심했던 결론은 "**LLM을 옵티마이저로 쓰지 말고**, 결정적 retrieval(grep/AST/graph/embedding) + LLM은 reasoning"으로 분리하는 게 업계 트렌드일 것이라는 점이었다. 이걸 검증해야 했다.

## 2. 첫 검색 — 옵티마이저는 LLM 자리가 아니다

다섯 키워드로 병렬 검색했다: large codebase indexing, Aider repo map / Cursor indexing, RAG vs code graph, MCP code index, local LLM router. 여기서 굳어진 합의가 명확했다.

**RAG 실패의 73%는 generation이 아니라 retrieval에서 터진다.** 즉 똑똑한 LLM을 갖다 놔도 retrieval이 부정확하면 결과는 무너진다. 그래서 retrieval은 결정적으로(grep/AST/graph/embedding), reasoning은 LLM이 — 이 분리가 거의 모든 메이저 도구의 답안이었다.

세 가지 패턴이 굳어져 있었다.

| 패턴 | 대표 | 구조 |
|---|---|---|
| Pre-built index | Cursor, Sourcegraph, Augment | Merkle tree + vector embedding, 10분마다 재인덱싱 |
| On-demand exploration | Claude Code, Aider | grep/glob/AST 실시간 탐색, Aider는 tree-sitter + PageRank로 repo map |
| MCP-as-index | Serena, Claude Context, CocoIndex | hybrid (BM25 + dense + AST), 외부 도구로 노출 |

특히 **Aider repo map**이 흥미로웠다 — tree-sitter로 모든 심볼 추출 → 파일 의존 그래프 → PageRank로 중요도 → 토큰 예산에 맞춰 압축. 이게 정확히 "결정적 옵티마이저"의 코딩판이었다. 우리 비유의 답이 이미 있었던 거다.

Ollama는? 옵티마이저로는 약했다. 자리를 옮기면 강력했다. embedder, lightweight router, utility agent(explore/librarian), summarizer로는 검증된 사례가 많았다. 함정 하나 — Ollama 기본 context가 4096 tokens라서 코딩 에이전트로 쓰면 conversation + tools + system prompt에 다 잡아먹힌다. 첫 가설은 "자리"가 잘못됐다는 게 결론.

## 3. 사용자 의도의 재정의 — 휴대용 표준 인덱스 패키지

여기서 사용자가 방향을 다잡았다. "이 레포 안에서 인덱스를 만드는 게 아니라, 이걸 들고 가서 다른 프로젝트에 적용했을 때 일관되게 똑똑해지는 표준이 필요해."

비유가 한 단계 정밀해졌다.

| RDB | 여기서는 |
|---|---|
| 테이블 + 컬럼 정의 | 이 레포의 skill/agent + 그 메타데이터 |
| 인덱스 (B-tree, GIN…) | 프로젝트 코드에서 추출된 시그널 |
| 옵티마이저 | 시그널 → 자산 매칭 규칙 (결정적) |
| 쿼리 | 사용자 요청 + 작업 맥락 |
| 실행 엔진 | LLM (reasoning만) |

그리고 4개 layer가 자연스럽게 떨어졌다.

```
Layer 4: Bootstrap (다른 프로젝트에서 1회 실행)
Layer 3: Matching Rule (결정적, 도구 무관)
Layer 2: Project Probe (프로젝트 → 시그널)
Layer 1: Asset Capability Manifest (자산 → 적용 조건)
```

## 4. 두 진영의 표준 — SKILL.md vs A2A AgentCard

자산 manifest는 무에서 만들 필요가 없었다. 이미 두 표준이 굳어져 있었다.

**Anthropic SKILL.md** — YAML frontmatter (`name` ≤64, `description` ≤1024) + markdown. Claude Code 네이티브. 그리고 이게 8개 도구(Claude Code, Codex CLI, Cursor, Gemini CLI, Copilot agent mode, Cline, Roo Code, Goose)에서 자동 호환되는 사실상 표준이라는 사실이 결정적이었다.

**A2A AgentCard** (Google + Linux Foundation) — JSON, `.well-known/agent-card.json`. 포터블. MCP 친화. 

그 외에 **agent-manifest.txt**(웹 표준 제안), **Microsoft Declarative Agent Schema**, **JSON Agents**, **AgentSpec** 같은 것들도 있었지만, 코드 자산 표준은 SKILL.md + AGENTS.md 조합이 명백한 사실상 표준이었다.

**ADL (Agent Definition Language)** — "OpenAPI for agents", define once / deploy anywhere — 도 발견했다. universal manifest가 SKILL.md 위층에 한 번 더 있을 수 있다는 가능성. 단 우리 1차 목표는 8개 도구 호환이라 SKILL.md primary로 충분.

흥미로운 발견 한 가지. Anthropic 공식은 `when_to_use` 별도 필드를 **비공식**으로 본다. **trigger 조건은 description에 직접 박는다.** 즉 우리가 만들 `applies_when` 확장은 표준 위에 비공식 부가 필드가 되는 형태. 표준을 깨지 않으면서 결정적 매칭에 필요한 시그널을 더 풍부하게 담는 길.

## 5. Skill 활성화 50%의 동전 던지기

여기서 진짜 충격적인 발견이 나왔다. GitHub issue #38588 외 다수 보고 — **매칭되는 description이 있어도 skill이 첫 턴에 안 부르는 게 정설**이었다. 활성화율 50% 수준. "동전 던지기"라는 표현까지 등장했다.

원인 분석은 두 갈래.

첫째, **활성화 실패** — Claude가 skill을 아예 invoke 안 하고 자기 방식으로 진행. 둘째, **실행 실패** — skill 부르고 단계를 건너뜀. 특히 procedural step.

해결책 두 축.

**Description style 차이**가 결정적이었다. Passive ("Use when creating Dockerfiles") = 77%. Directive ("ALWAYS invoke this skill when... Do NOT attempt directly") = **100%**. 단순한 어미 차이로 활성화율이 23% 포인트 올라갔다. 650회 trial 연구가 이 격차를 검증했다.

**Hooks (PreToolUse)** = 결정적 강제 레이어. permission mode조차 우회 못 함. async hooks (2026-01)와 HTTP hooks까지 더해져 admission webhook 같은 자리가 만들어져 있었다. 즉 description은 보조, hooks가 본진이라는 그림.

여기서 K8s admission webhook 비유가 자연스럽게 떠올랐다. **PreToolUse hook = admission webhook**. 둘 다 "결정적, 우회 불가, 정책 강제" 자리.

이 발견이 5층 그림에 한 층을 더 추가시켰다.

```
Layer 5: Enforcement (PreToolUse hook = admission webhook)
Layer 4: Bootstrap
Layer 3: Matching Rule
Layer 2: Project Probe
Layer 1: Asset Capability Manifest
```

## 6. 4개 결정 — 섹션 분리, 컨트롤러, 멀티-AI, 락인

사용자가 다음 질문 묶음을 던졌다. "섹션 분리해야 하나, 레포를 더 파야 하나, K8s 컨트롤러 같은 결정 주체가 도입되어야 하나, Claude 표준에 묶이면 Codex에서 약해지지 않나."

여기서 추가 검색 5개. 답이 뚜렷이 나왔다.

**Q1·Q2 (섹션 분리·레포 분리)**: NO. AI 시대엔 monorepo가 정답이었다. Augment, Nx, Spectro Cloud, Monorepo Tools 모두 한 방향. Copilot 64K, Cursor 더 큰 컨텍스트로 여러 서비스 코어 로직이 한 컨텍스트에 들어간다. **Atomic cross-project change** — polyrepo에선 몇 주, monorepo에선 하루. 결정적이었다.

**Q3 (Controller/Scheduler)**: YES. 정확히 업계가 가는 방향이었다. 발견한 두 프로젝트가 결정타였다.

- **klaw** — "Kubernetes for AI Agents". K8s가 Pod를 Node에 schedule하듯, klaw는 agent를 node에 schedule.
- **Gas Town** — 20-30 Claude Code 인스턴스를 병렬 조정. "Kubernetes for AI coding agents"라고 자칭.
- **Context Kubernetes** (arxiv 2604.11623) — Declarative orchestration of enterprise knowledge.

비유가 1:1로 떨어졌다.

| K8s | 우리 시스템 |
|---|---|
| etcd | inventory.yml + manifest |
| kube-scheduler | Layer 3 Matching Rule |
| kube-controller-manager | Layer 4 Bootstrap |
| **admission webhook** | **Layer 5 PreToolUse Hook** |
| kubelet | Claude Code / Codex / Cursor |
| CRI / CSI | SKILL.md / MCP |

SDTimes 인용이 모든 걸 정리했다 — "**AI's biggest bottleneck isn't intelligence, it's orchestration**." 우리가 그 자리를 채우는 거였다.

**Q4 (Multi-AI 락인)**: 정당한 우려고, 답이 이미 있었다. AGENTS.md(Linux Foundation 표준, 2026-02 NIST 합류)와 SKILL.md(Anthropic) 조합이 8개 도구 자동 호환. 80% 공통 룰은 AGENTS.md, 20% 도구별 차이만 도구별 파일(`.claude/`, `.codex/`, `.cursor/rules/`).

Claude Code만 AGENTS.md 지원이 pending이라 CLAUDE.md → AGENTS.md symlink 우회가 표준 패턴이었다. "포터블 자산"이 가능하다는 게 검증됨.

## 7. Description Budget — 시한폭탄

같은 검색에서 또 하나 발견했다. **모든 skill description은 컨텍스트의 1-2%를 공유한다.** 너무 많이 install하면 자동 truncate → keyword가 잘려서 매칭 자체가 안 된다.

우리 레포 계산. 239 skills × 1024 chars = 239KB. 단순 install.sh로 다 깔면 description이 잘려서 표준 만들어도 작동 안 한다. **Tool Search 패턴이 95% context 절감**한다는 이유가 정확히 이거였다.

해법은 두 축. **계층화** (카테고리 단위로 묶고 진입 후 하위 노출) + **Selective install** (probe 결과로 매칭된 plugin만 install). 둘 다 필요하다는 결론.

## 8. Skill Registry의 발견 — 그리고 보안 경고

publish 옵션을 점검할 때 **skills.sh** (Vercel, 2026-01-20 런칭 — 90,000+ skills, 19 AI agents)와 **ClawHub** (20,000+ skills)이 이미 거대하게 돌아가고 있었다. Lobehub Skills Marketplace까지.

그런데 같이 발견된 The Register 기사 — "30 ClawHub skills secretly turn AI agents into crypto swarm" (2026-04-29). **13.4% 스킬에 critical 보안 이슈, 전체의 1/3에 어떤 형태든 이슈.** 30개 스킬이 비밀리에 crypto mining swarm으로 변신한 사건도 있었다.

이게 사용자의 가장 큰 고민으로 떠올랐다 — "registry publish 목표를 잡을지 말지." 추천을 줘야 했다.

내 답: **포맷만 호환, publish는 미래 옵션**. 이유 4가지.

1. 1차 목표는 "다른 프로젝트에서 일관되게 쓰는 것" — distribution은 부차
2. publish 즉시 audit/signing/sandbox 의무 발생 — 코어 검증 전엔 부담 과함
3. 1년 안 publish 마감 잡으면 표준 검증보다 "보여줄 거 만들기"로 흘러감
4. SKILL.md + AGENTS.md + applies_when 100% 준수면 **언제든 publish 가능** — 옵션을 닫지 않음

publish 시 우선순위는 skills.sh > Lobehub > ClawHub(보안 사건으로 보류). 자체 registry는 NO — 90,000개 vs 후발주자, ROI 마이너스.

## 9. 사용자 결정 4개

여기까지 와서 사용자가 4개 답을 정리했다.

| 질문 | 결정 |
|---|---|
| 레포 구조 | mono + 내부 재배치 |
| Multi-AI 우선 | Claude + Codex + Cursor (어차피 8개 호환) |
| Control plane | **처음부터 별도 패키지** (내 추천 PoC 후 분리와 다름) |
| Registry publish | **포맷만, 미래 옵션** (추천 채택) |

3번에서 사용자는 PoC 검증과 빌드 파이프라인을 동시에 가져가는 길을 택했다. 이중 부담이지만 SSOT를 schema로 박으면 분리 시 마찰이 적다는 판단. 인정하고 plan에 명시.

## 10. Phase 1 탐색 — 가정과 실제의 격차

3개 Explore agent를 병렬로 띄워 현 상태를 정확히 파악했다. 가정과 실제에 격차가 있었다.

- **Skills frontmatter 0%** — 메모리엔 "10개 frontmatter + 224개 H1 컨벤션"이라 적혀있었지만, k8s 10개·go 9개 모두 0개. 사실상 0%. 즉 SKILL.md 표준 호환은 거의 빈 상태.
- **Agents 100% frontmatter** — 46개 모두 directive 스타일 ("Use PROACTIVELY after K8s manifest changes"). 거의 ready.
- **`.codex/agents/*.toml` 46개 사전 존재** — adapter pipeline이 부분 가동 중이었다는 게 큰 발견. 변환 로직이 어딘가에 이미 있고 그걸 reverse-engineering만 하면 P4 부담이 1일 spike로 줄어듦.
- **`.claude/skills/`와 `.agents/skills/` diff 0** — mirror 관계. 단일 SSOT로 안전하게 통합 가능.
- **Hooks 블록 absent** — settings.local.json에 permissions만. PreToolUse 자리는 완전 공백, 새로 만들어야.

이 검증이 plan을 한 단계 정밀하게 만들었다. 특히 `.codex/agents/`의 사전 존재가 P4 견적을 깎았다.

## 11. 5층 그림 확정 + Phase 8개

최종적으로 구조가 떨어졌다.

```
Layer 1: Asset Capability Manifest    SKILL.md frontmatter + applies_when 비공식 부가
Layer 2: Project Probe                 deterministic, no LLM (git ls-files + glob)
Layer 3: Matching Rule (scheduler)     cost-based scoring (40+30+20+15)
Layer 4: Bootstrap CLI                 claude-agents init 5 step
Layer 5: Enforcement (admission)       PreToolUse hook, applies_when 재평가
```

8개 Phase로 분할.

P1 Schema 동결 → P2 PoC 10개 변환(k8s 5 + go 5) → P3 Control plane PoC → P4 Multi-AI adapter → P5 Enforcement hook → P6 Pilot 1 카테고리 → P7 전체 마이그레이션 → P8 Registry-ready 동결.

각 phase 게이트를 박았다. 통과 못 하면 다음 진입 금지. 기존 5종 lint와 같은 원칙.

검증은 6개 메트릭. Frontmatter compliance, Matching accuracy(precision ≥0.9 / recall ≥0.85), Activation rate(≥70% baseline), Determinism(10회 hash 일치), Adapter parity(diff 0), CI drift(green).

## 12. 영구 기록 첫 commit

마지막에 사용자가 던진 한마디 — "세션 꺼져도 되도록, 어디 기록하고 시작해줘." 

이게 plan mode 임시 파일(`~/.claude/plans/plan-rippling-spindle.md`)의 휘발 위험을 인지한 결정이었다. 첫 implementation step이 영구 기록 생성이 됐다.

3개 파일을 만들었다.

- `docs/migration/0002-standardization-and-control-plane.md` — plan 본문 (Status: Proposed)
- `docs/migration/0002-progress.md` — Phase status tracker + decision log + 재개 명령
- `docs/dev-logs/2026-05-05-control-plane-poc-start.md` — 시작 시점 컨텍스트

commit `f6fb2fe`, 3 files / 468 insertions. origin/main으로 push 완료. 로컬 휘발해도 GitHub에 영구 사본.

## 결론 — 글로 풀어쓸 때 핵심 메시지

이 토의에서 진짜 가치가 있었던 통찰을 5개로 압축한다.

1. **옵티마이저를 LLM 밖으로** — 비결정성을 결정적 retrieval로 빼면 모델·버전 차이가 자산 선택 결과에 안 묻힌다. 이게 표준화의 본질.
2. **K8s 비유가 진짜로 1:1로 매칭된다** — etcd, scheduler, controller-manager, admission webhook까지 자리가 그대로 있다. klaw·Gas Town 같은 선례가 같은 길 위에 있다.
3. **Skill activation 동전 던지기 문제는 description style + hooks로 해결 가능** — directive 어미와 admission webhook 두 축. 보조와 본진이 명확.
4. **Multi-AI 시대 락인은 회피 가능** — AGENTS.md + SKILL.md 조합이 8개 도구 자동 호환. 무에서 만들 필요 없이 두 표준 위에 비공식 부가 필드만 얹으면 된다.
5. **Description budget 1-2%가 시한폭탄** — 자산이 많아질수록 description 자체가 잘린다. 계층화 + selective install이 필수. Tool Search가 95% 절감하는 이유가 이거.

마지막 메타 통찰 하나. 이 토의 자체가 **"AI를 어떻게 쓸까"를 AI와 같이 결정한 과정**이었다. 외부 검색 5회 + Phase 1 Explore 3개 + Plan agent 1회 + 직접 read 4회. 사람 혼자 같은 결론에 도달했다면 더 오래 걸렸을 것이다. 그 자체가 이 시스템이 무엇을 자동화하려는지의 메타 데모.

---

## 글로 발전시킬 때 추가로 다룰 거리

본 log엔 안 들어갔지만 글에서 다룰 만한 디테일.

- Aider repo map의 PageRank 가중치 — tree-sitter + 그래프 알고리즘이 어떻게 토큰 예산에 맞춰 압축하는지 코드 레벨 설명
- 13.4% critical 보안 이슈의 구체 패턴 (prompt injection, exposed secrets, malware)
- ADL이 OpenAPI에 비유되는 정당성 — define once / deploy anywhere가 진짜로 가능한지
- AAIF (Agentic AI Foundation, Linux Foundation, 2025-12)와 NIST AI Agent Standards Initiative (2026-02)의 권한 영역 분담
- klaw / Gas Town의 실제 구현이 K8s scheduler와 얼마나 닮았는가 — 코드 비교
- "Authorization, not instructions" 패러다임 (Oso) — instruction은 probabilistic, 권한 시스템이 결정적

## 1차 sources (글에서 인용할 수 있는 것)

- [Skills not invoked on first turn — anthropics/claude-code#38588](https://github.com/anthropics/claude-code/issues/38588)
- [How to Make Claude Code Skills Actually Activate (650 Trials)](https://medium.com/@ivan.seleznov1/why-claude-code-skills-dont-activate-and-how-to-fix-it-86f679409af1)
- [Claude Code Hooks: The Deterministic Control Layer](https://www.dotzlaw.com/insights/claude-hooks/)
- [Aider Repository map (tree-sitter + PageRank)](https://aider.chat/2023/10/22/repomap.html)
- [How Cursor Actually Indexes Your Codebase](https://towardsdatascience.com/how-cursor-actually-indexes-your-codebase/)
- [klaw — Kubernetes for AI Agents](https://medium.com/illumination/someone-just-built-kubernetes-for-ai-agents-and-it-might-change-how-we-deploy-everything-d07681ee1770)
- [Gas Town: Kubernetes for AI Coding Agents](https://cloudnativenow.com/features/gas-town-what-kubernetes-for-ai-coding-agents-actually-looks-like/)
- [Will AI turn 2026 into the year of the monorepo? (Spectro Cloud)](https://www.spectrocloud.com/blog/will-ai-turn-2026-into-the-year-of-the-monorepo)
- [AGENTS.md vs CLAUDE.md: Cross-Tool Standard](https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard)
- [Skills.sh Marketplace (Vercel)](https://virtualuncle.com/agent-skills-marketplace-skills-sh-2026/)
- [30 ClawHub skills crypto swarm (The Register)](https://www.theregister.com/2026/04/29/30_clawhub_skills_mine_crypto/)
- [A2A Protocol Specification](https://a2a-protocol.org/latest/specification/)
- [ADL — Agent Definition Language](https://github.com/inference-gateway/adl)
- [Why AI's Biggest Bottleneck Isn't Intelligence (SDTimes)](https://sdtimes.com/control-plane/why-ais-biggest-bottleneck-isnt-intelligence-its-orchestration/)
- [Harness Engineering for AI Coding Agents (Augment)](https://www.augmentcode.com/guides/harness-engineering-ai-coding-agents)
- [Context Engineering for Coding Agents (Martin Fowler)](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html)
- [AI Gone Rogue: Authorization vs Instructions (Oso)](https://www.osohq.com/post/why-authorization-keeps-llms-in-check)
- [Claude Code MCP Tool Search: Save 95% Context](https://claudefa.st/blog/tools/mcp-extensions/mcp-tool-search)
- [agent-manifest.txt — proposed web standard](https://dev.to/jaspervanveen/agentstxt-a-proposed-web-standard-for-ai-agents-20lb)
- [Anthropic Skills repo (skill-creator SKILL.md)](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)
