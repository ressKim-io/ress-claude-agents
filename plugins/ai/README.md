<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# ai

AI — RAG, Vector DB, LLMOps, MLOps, 모델 서빙, Agentic 아키텍처, 프롬프트 엔지니어링

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install ai@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/ai/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (14)

| 이름 | 설명 |
|---|---|
| `/ai:agentic-ai-architecture` | Agentic AI Architecture 가이드 — AI Agent 시스템 설계, MCP/A2A 프로토콜, Multi-Agent 오케스트레이션, Spring AI/Go 구현 패턴 |
| `/ai:agentic-coding` | Agentic Coding Patterns — AI 코딩 에이전트 활용 패턴, Agent Supervision, Multi-Agent 조율, Agentic Era 코드 리뷰 |
| `/ai:ai-first-playbook` | AI-First Engineering Playbook — AI-First 조직 전환, 워크플로우 재설계, ROI 측정, Claude Code 운영 전략 |
| `/ai:dx-ai-agents` | AI Agents 플랫폼 통합 가이드 — AI 코딩 에이전트 거버넌스, Copilot/Claude 통합, 엔터프라이즈 AI 정책 |
| `/ai:dx-ai-agents-orchestration` | AI Agent 오케스트레이션 가이드 — 멀티 에이전트 협업, 가드레일, Self-Healing 인프라, 메트릭 수집 |
| `/ai:dx-ai-security` | AI 코드 보안 & 품질 보증 가이드 — AI 생성 코드 보안 검증, 품질 게이트, 비용 관리 |
| `/ai:langchain-langgraph` | LangChain & LangGraph — LangChain v0.3 LCEL, LangGraph 에이전트, 멀티 에이전트 오케스트레이션 |
| `/ai:llmops` | LLMOps 가이드 — RAG 운영, 프롬프트 버전 관리, LLM 평가(Ragas), 가드레일(NeMo) |
| `/ai:ml-serving` | ML Model Serving 가이드 — Kubernetes 기반 ML/LLM 모델 서빙, KServe, vLLM, TensorRT-LLM 최적화 |
| `/ai:mlops` | MLOps 가이드 — Kubeflow, KServe를 활용한 ML 파이프라인과 모델 서빙 |
| `/ai:mlops-tracking` | MLflow 실험 추적 가이드 — MLflow 설치, 실험 추적, 모델 레지스트리, KServe 연동 |
| `/ai:prompt-engineering` | Prompt Engineering — 프롬프트 설계 기법, 시스템 프롬프트, 가드레일, 평가 방법론 |
| `/ai:rag-patterns` | RAG Patterns — RAG(Retrieval-Augmented Generation) 아키텍처, 청킹 전략, 임베딩 모델, 검색 최적화 |
| `/ai:vector-db` | Vector Database — 벡터 데이터베이스 비교, 인덱싱 전략, ANN 알고리즘, 운영 패턴 |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `ai:mlops-expert` | MLOps 전문가 에이전트. Kubernetes 기반 ML 파이프라인, GPU 스케줄링, 모델 서빙, LLM 배포에 특화 |
