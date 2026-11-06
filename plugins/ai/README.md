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
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (14)

| 이름 | 설명 |
|---|---|
| `/ai:agentic-ai-architecture` | AI Agent 시스템 설계 — MCP·A2A 프로토콜 비교, multi-agent 오케스트레이션 패턴, Spring AI·Go 구현, 가드레일 아키텍처 |
| `/ai:agentic-coding` | AI 코딩 에이전트 활용 — 4가지 agentic coding 모드, agent supervision, multi-agent 조율, 코드 리뷰 방식, 모델 라우팅 |
| `/ai:ai-first-playbook` | AI-First 조직 전환 플레이북 — 파일럿(0-30일)→팀 확산→문화 정착 단계, ROI 측정 프레임워크, Claude Code 운영 전략 |
| `/ai:dx-ai-agents` | AI 코딩 에이전트 거버넌스 — 엔지니어 역할 변화, 성숙도 모델, Copilot·Claude Code 통합, 권한 범위, 금지 사항, 작업 완료 기준 |
| `/ai:dx-ai-agents-orchestration` | AI Agent 오케스트레이션 — 멀티 에이전트 협업, 가드레일, Self-Healing 인프라, 메트릭 수집 |
| `/ai:dx-ai-security` | AI 생성 코드의 보안 검증과 품질 게이트 — 보안 가이드라인, 품질 보증, AI 비용(FinOps) 관리, 메트릭·모니터링 |
| `/ai:langchain-langgraph` | LangChain v0.3 LCEL, tool calling, LangGraph 에이전트, multi-agent 패턴, RAG, streaming, 프로덕션 배포 |
| `/ai:llmops` | LLMOps — RAG 운영, 프롬프트 버전 관리, Ragas 기반 LLM 평가, NeMo 가드레일 |
| `/ai:ml-serving` | K8s 기반 ML·LLM 모델 서빙 — 서빙 엔진 비교, KServe, vLLM, TensorRT-LLM, llm-d, KEDA 오토스케일링, 최적화 |
| `/ai:mlops` | MLOps — Kubeflow 로 ML 파이프라인을 구성하고 KServe 로 서빙, MLOps 와 LLMOps 비교 |
| `/ai:mlops-tracking` | MLflow 실험 추적 — 설치, experiment tracking, 모델 레지스트리, KServe 연동 |
| `/ai:prompt-engineering` | 프롬프트 설계 — 기법 선택, 시스템 프롬프트 작성, structured output, 가드레일, 평가 방법론, Claude 5.5 프롬프팅 주의점 |
| `/ai:rag-patterns` | RAG 아키텍처 — 청킹 전략, 임베딩 모델, 검색 최적화, vector store 연동, advanced RAG, RAGAS 평가 |
| `/ai:vector-db` | 벡터 DB — 제품 비교 매트릭스, ANN 인덱싱 알고리즘, pgvector·Weaviate·Pinecone, 성능 튜닝, 비용 분석 |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `ai:mlops-expert` | MLOps 전문가 에이전트. Kubernetes 기반 ML 파이프라인, GPU 스케줄링, 모델 서빙, LLM 배포에 특화 |
