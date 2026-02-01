# MLOps/LLMOps 가이드

Kubeflow, MLflow, RAG 운영, LLM 평가 및 가드레일

## Quick Reference (결정 트리)

```
ML 플랫폼 선택?
    |
    +-- Kubernetes 네이티브 ---------> Kubeflow
    |       |
    |       +-- 파이프라인 중심 -----> Kubeflow Pipelines
    |       +-- 모델 서빙 -----------> KServe
    |
    +-- 경량/실험 추적 --------------> MLflow
    |       |
    |       +-- 로컬 + 클라우드 -----> MLflow + S3/GCS
    |       +-- 모델 레지스트리 -----> MLflow Model Registry
    |
    +-- LLM 특화 -------------------> LLMOps 도구
            |
            +-- RAG 운영 ------------> LangChain + 벡터 스토어
            +-- 프롬프트 관리 -------> LangSmith / PromptLayer
            +-- 평가 ----------------> LangSmith / Ragas

MLOps vs LLMOps?
    |
    +-- 전통 ML (분류, 회귀) --------> MLOps
    +-- LLM (생성형 AI) ------------> LLMOps
    +-- 하이브리드 -----------------> 둘 다 필요
```

---

## CRITICAL: MLOps vs LLMOps 비교

| 항목 | MLOps | LLMOps |
|------|-------|--------|
| **모델 훈련** | 직접 훈련 | 파인튜닝 또는 프롬프트 엔지니어링 |
| **데이터** | 구조화된 데이터 | 비정형 텍스트, 문서 |
| **평가 지표** | 정확도, F1, AUC | 유창성, 관련성, 안전성 |
| **버전 관리** | 모델 가중치 | 프롬프트 + 모델 버전 |
| **추론 비용** | 상대적 저렴 | 토큰당 비용 (고가) |
| **레이턴시** | ms 단위 | 초 단위 가능 |
| **컨텍스트** | 고정 입력 | RAG, 대화 기록 |

### 성숙도 모델

```
Level 0: Manual
    +-- 주피터 노트북 실험
    +-- 수동 모델 배포
    +-- 로그 없음

Level 1: Pipeline
    +-- 자동화된 학습 파이프라인
    +-- 모델 레지스트리
    +-- 기본 모니터링

Level 2: CI/CD for ML
    +-- 자동 재학습 트리거
    +-- A/B 테스트 배포
    +-- 데이터 품질 검증

Level 3: Full Automation
    +-- 자동 피처 엔지니어링
    +-- 자동 모델 선택
    +-- 자동 롤백
```

---

## Kubeflow

### 아키텍처

```
+------------------------------------------------------------------+
|                        Kubeflow Platform                           |
+------------------------------------------------------------------+
|                                                                    |
|  +-------------+  +-------------+  +-------------+  +-------------+|
|  | Notebooks   |  | Pipelines   |  | KServe      |  | Katib       ||
|  | (Jupyter)   |  | (Argo)      |  | (Serving)   |  | (AutoML)    ||
|  +-------------+  +-------------+  +-------------+  +-------------+|
|                                                                    |
|  +-------------+  +-------------+  +-------------+                 |
|  | Training    |  | Feature     |  | Model       |                 |
|  | Operators   |  | Store       |  | Registry    |                 |
|  +-------------+  +-------------+  +-------------+                 |
|                                                                    |
+------------------------------------------------------------------+
|                     Kubernetes Cluster                             |
+------------------------------------------------------------------+
```

### 설치

```bash
# Kubeflow 설치 (kustomize)
git clone https://github.com/kubeflow/manifests.git
cd manifests

# 전체 설치
while ! kustomize build example | kubectl apply -f -; do
  echo "Retrying..."
  sleep 10
done

# 또는 개별 컴포넌트
kustomize build apps/pipeline/upstream/env/platform-agnostic-multi-user | kubectl apply -f -
```

### Kubeflow Pipeline 정의

```python
# pipeline.py
from kfp import dsl
from kfp import compiler
from kfp.dsl import component, Input, Output, Dataset, Model, Metrics

@component(
    base_image="python:3.11-slim",
    packages_to_install=["pandas", "scikit-learn"]
)
def preprocess_data(
    input_data: Input[Dataset],
    output_data: Output[Dataset],
    test_size: float = 0.2
):
    import pandas as pd
    from sklearn.model_selection import train_test_split

    df = pd.read_csv(input_data.path)
    train, test = train_test_split(df, test_size=test_size)
    train.to_csv(output_data.path, index=False)

@component(
    base_image="python:3.11-slim",
    packages_to_install=["pandas", "scikit-learn", "joblib"]
)
def train_model(
    train_data: Input[Dataset],
    model: Output[Model],
    metrics: Output[Metrics],
    n_estimators: int = 100
):
    import pandas as pd
    from sklearn.ensemble import RandomForestClassifier
    import joblib

    df = pd.read_csv(train_data.path)
    X = df.drop('target', axis=1)
    y = df['target']

    clf = RandomForestClassifier(n_estimators=n_estimators)
    clf.fit(X, y)

    # 모델 저장
    joblib.dump(clf, model.path)

    # 메트릭 기록
    metrics.log_metric("accuracy", clf.score(X, y))

@dsl.pipeline(
    name="ML Training Pipeline",
    description="Train and deploy ML model"
)
def ml_pipeline(
    input_data_path: str,
    n_estimators: int = 100
):
    preprocess_task = preprocess_data(
        input_data=dsl.importer(
            artifact_uri=input_data_path,
            artifact_class=Dataset
        )
    )

    train_task = train_model(
        train_data=preprocess_task.outputs["output_data"],
        n_estimators=n_estimators
    )

# 파이프라인 컴파일
compiler.Compiler().compile(ml_pipeline, "pipeline.yaml")
```

### KServe 모델 배포

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sklearn-model
  namespace: kubeflow
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      storageUri: "s3://my-bucket/models/sklearn-model"
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi

    # 오토스케일링
    minReplicas: 1
    maxReplicas: 10
    scaleTarget: 10  # 동시 요청
    scaleMetric: concurrency
---
# Transformer (전처리/후처리)
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: model-with-transformer
spec:
  transformer:
    containers:
      - name: transformer
        image: myorg/transformer:latest
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
  predictor:
    model:
      modelFormat:
        name: sklearn
      storageUri: "s3://my-bucket/models/model"
```

---

## MLflow

### 설치 및 설정

```bash
# 설치
pip install mlflow

# 서버 실행 (로컬)
mlflow server \
  --backend-store-uri postgresql://user:pass@localhost/mlflow \
  --default-artifact-root s3://mlflow-artifacts \
  --host 0.0.0.0 \
  --port 5000

# Kubernetes 배포
helm repo add community-charts https://community-charts.github.io/helm-charts
helm install mlflow community-charts/mlflow \
  --set backendStore.postgres.enabled=true \
  --set artifactRoot.s3.enabled=true \
  --set artifactRoot.s3.bucket=mlflow-artifacts
```

### 실험 추적

```python
import mlflow
from mlflow.tracking import MlflowClient

# 트래킹 서버 설정
mlflow.set_tracking_uri("http://mlflow-server:5000")
mlflow.set_experiment("my-experiment")

# 실험 실행
with mlflow.start_run(run_name="training-run-1"):
    # 파라미터 로깅
    mlflow.log_params({
        "learning_rate": 0.01,
        "epochs": 100,
        "batch_size": 32
    })

    # 훈련 루프
    for epoch in range(100):
        loss = train_epoch()
        accuracy = evaluate()

        # 메트릭 로깅
        mlflow.log_metrics({
            "loss": loss,
            "accuracy": accuracy
        }, step=epoch)

    # 모델 로깅
    mlflow.sklearn.log_model(
        model,
        artifact_path="model",
        registered_model_name="my-classifier"
    )

    # 추가 아티팩트
    mlflow.log_artifact("confusion_matrix.png")
```

### 모델 레지스트리

```python
from mlflow import MlflowClient

client = MlflowClient()

# 모델 버전 등록
result = client.create_model_version(
    name="my-classifier",
    source="runs:/abc123/model",
    run_id="abc123"
)

# 스테이지 전환
client.transition_model_version_stage(
    name="my-classifier",
    version=1,
    stage="Staging"
)

# Production 배포
client.transition_model_version_stage(
    name="my-classifier",
    version=1,
    stage="Production"
)

# 모델 로드 (Production)
model = mlflow.pyfunc.load_model("models:/my-classifier/Production")
predictions = model.predict(data)
```

### MLflow + KServe 연동

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: mlflow-model
spec:
  predictor:
    model:
      modelFormat:
        name: mlflow
      storageUri: "s3://mlflow-artifacts/1/abc123/artifacts/model"
```

---

## LLMOps: RAG 운영

### RAG 아키텍처

```
+------------------------------------------------------------------+
|                         RAG Pipeline                               |
+------------------------------------------------------------------+
|                                                                    |
|  사용자 쿼리                                                        |
|       |                                                            |
|       v                                                            |
|  +-------------+                                                   |
|  | Embedding   |                                                   |
|  | Model       |                                                   |
|  +-------------+                                                   |
|       |                                                            |
|       v                                                            |
|  +-------------+     +-------------+                               |
|  | Vector      |<--->| Document    |                               |
|  | Store       |     | Store       |                               |
|  | (Pinecone,  |     | (S3, etc.)  |                               |
|  |  Weaviate)  |     +-------------+                               |
|  +-------------+                                                   |
|       |                                                            |
|       v (Top-K 문서)                                               |
|  +-------------+                                                   |
|  | LLM         |                                                   |
|  | (GPT-4,     |                                                   |
|  |  Claude)    |                                                   |
|  +-------------+                                                   |
|       |                                                            |
|       v                                                            |
|  응답 생성                                                          |
|                                                                    |
+------------------------------------------------------------------+
```

### LangChain RAG 구현

```python
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import Weaviate
from langchain.chains import RetrievalQA
from langchain.prompts import PromptTemplate
import weaviate

# 벡터 스토어 연결
client = weaviate.Client(
    url="http://weaviate:8080",
    auth_client_secret=weaviate.AuthApiKey(api_key="...")
)

embeddings = OpenAIEmbeddings(model="text-embedding-3-small")

vectorstore = Weaviate(
    client=client,
    index_name="Documents",
    text_key="content",
    embedding=embeddings
)

# RAG Chain 구성
llm = ChatOpenAI(model="gpt-4-turbo", temperature=0)

prompt_template = """다음 컨텍스트를 사용하여 질문에 답하세요.
컨텍스트에 답이 없으면 "정보를 찾을 수 없습니다"라고 답하세요.

컨텍스트:
{context}

질문: {question}

답변:"""

PROMPT = PromptTemplate(
    template=prompt_template,
    input_variables=["context", "question"]
)

qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=vectorstore.as_retriever(search_kwargs={"k": 5}),
    chain_type_kwargs={"prompt": PROMPT},
    return_source_documents=True
)

# 실행
result = qa_chain.invoke({"query": "API 인증 방법은?"})
print(result["result"])
```

### 벡터 스토어 Kubernetes 배포

```yaml
# Weaviate 배포
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: weaviate
  namespace: llmops
spec:
  serviceName: weaviate
  replicas: 1
  selector:
    matchLabels:
      app: weaviate
  template:
    metadata:
      labels:
        app: weaviate
    spec:
      containers:
        - name: weaviate
          image: semitechnologies/weaviate:1.27.0
          ports:
            - containerPort: 8080
          env:
            - name: QUERY_DEFAULTS_LIMIT
              value: "25"
            - name: AUTHENTICATION_APIKEY_ENABLED
              value: "true"
            - name: AUTHENTICATION_APIKEY_ALLOWED_KEYS
              valueFrom:
                secretKeyRef:
                  name: weaviate-secrets
                  key: api-key
            - name: PERSISTENCE_DATA_PATH
              value: "/var/lib/weaviate"
            - name: DEFAULT_VECTORIZER_MODULE
              value: "text2vec-openai"
            - name: ENABLE_MODULES
              value: "text2vec-openai,generative-openai"
          volumeMounts:
            - name: data
              mountPath: /var/lib/weaviate
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 2
              memory: 4Gi
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
```

---

## 프롬프트 버전 관리

### LangSmith 연동

```python
import os
from langsmith import Client
from langchain_core.prompts import ChatPromptTemplate

os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = "..."
os.environ["LANGCHAIN_PROJECT"] = "my-llm-app"

client = Client()

# 프롬프트 저장
prompt = ChatPromptTemplate.from_messages([
    ("system", "당신은 유용한 AI 어시스턴트입니다."),
    ("human", "{input}")
])

client.push_prompt("my-prompt", object=prompt)

# 프롬프트 로드 (버전 관리)
prompt_v1 = client.pull_prompt("my-prompt:v1")
prompt_latest = client.pull_prompt("my-prompt")
```

### 프롬프트 템플릿 관리 (Git 기반)

```yaml
# prompts/qa_prompt.yaml
name: qa_prompt
version: "1.0.0"
description: "Question answering prompt for RAG"

template: |
  You are a helpful assistant. Answer the question based on the context.

  Context:
  {context}

  Question: {question}

  Answer:

input_variables:
  - context
  - question

metadata:
  model: gpt-4-turbo
  temperature: 0
  max_tokens: 1000
```

---

## LLM 평가 & 가드레일

### Ragas 평가

```python
from ragas import evaluate
from ragas.metrics import (
    faithfulness,
    answer_relevancy,
    context_precision,
    context_recall
)
from datasets import Dataset

# 평가 데이터셋 준비
eval_data = {
    "question": ["API 인증 방법은?", "에러 처리는?"],
    "answer": ["OAuth2 토큰 인증을 사용합니다.", "try-catch로 처리합니다."],
    "contexts": [
        ["OAuth2를 사용한 인증...", "Bearer 토큰..."],
        ["예외 처리 가이드...", "에러 핸들러..."]
    ],
    "ground_truth": ["OAuth2 Bearer 토큰", "예외 처리"]
}

dataset = Dataset.from_dict(eval_data)

# 평가 실행
result = evaluate(
    dataset,
    metrics=[
        faithfulness,      # 응답이 컨텍스트에 충실한가
        answer_relevancy,  # 응답이 질문과 관련있는가
        context_precision, # 검색된 컨텍스트가 정확한가
        context_recall     # 필요한 컨텍스트를 모두 검색했는가
    ]
)

print(result)
# {'faithfulness': 0.92, 'answer_relevancy': 0.88, ...}
```

### 가드레일 (NeMo Guardrails)

```python
from nemoguardrails import LLMRails, RailsConfig

config = RailsConfig.from_path("./guardrails_config")

rails = LLMRails(config)

# 안전한 응답 생성
response = rails.generate(messages=[{
    "role": "user",
    "content": "비밀번호를 알려줘"
}])
# 가드레일이 부적절한 요청 차단
```

```yaml
# guardrails_config/config.yml
models:
  - type: main
    engine: openai
    model: gpt-4-turbo

rails:
  input:
    flows:
      - check topic  # 주제 확인
      - check jailbreak  # 탈옥 시도 감지

  output:
    flows:
      - check facts  # 사실 확인
      - check hallucination  # 환각 감지

prompts:
  - task: self_check_input
    content: |
      이 메시지가 부적절하거나 유해한 내용을 요청하는지 확인하세요.
      메시지: {{ user_input }}
      결과 (yes/no):
```

### 출력 검증

```python
from pydantic import BaseModel, Field
from langchain_core.output_parsers import PydanticOutputParser

class StructuredResponse(BaseModel):
    answer: str = Field(description="질문에 대한 답변")
    confidence: float = Field(ge=0, le=1, description="신뢰도 (0-1)")
    sources: list[str] = Field(description="참조 문서 목록")

parser = PydanticOutputParser(pydantic_object=StructuredResponse)

# 프롬프트에 포맷 지시 추가
prompt = prompt.partial(format_instructions=parser.get_format_instructions())

# 응답 파싱 및 검증
chain = prompt | llm | parser
result = chain.invoke({"question": "..."})  # StructuredResponse 객체
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 실험 추적 없음 | 재현 불가 | MLflow/W&B 사용 |
| 모델 버전 미관리 | 롤백 불가 | Model Registry |
| RAG 평가 생략 | 품질 저하 모름 | Ragas 정기 평가 |
| 가드레일 없음 | 유해 응답 생성 | NeMo Guardrails |
| 프롬프트 하드코딩 | 관리 어려움 | 버전 관리 시스템 |
| 비용 모니터링 없음 | 예산 초과 | 토큰 사용량 추적 |

---

## 체크리스트

### MLOps
- [ ] Kubeflow 또는 MLflow 설치
- [ ] 파이프라인 정의 (학습/배포)
- [ ] 모델 레지스트리 설정
- [ ] KServe 배포

### LLMOps
- [ ] 벡터 스토어 설정
- [ ] RAG 파이프라인 구축
- [ ] 프롬프트 버전 관리

### 평가
- [ ] Ragas 평가 파이프라인
- [ ] 가드레일 설정
- [ ] 출력 검증 스키마

### 모니터링
- [ ] 토큰 사용량 추적
- [ ] 응답 품질 메트릭
- [ ] 비용 알림 설정

**관련 skill**: `/ml-serving`, `/k8s-gpu`, `/finops`

---

## Sources

- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [KServe](https://kserve.github.io/website/)
- [LangChain RAG](https://python.langchain.com/docs/tutorials/rag/)
- [Ragas Evaluation](https://docs.ragas.io/)
- [NeMo Guardrails](https://docs.nvidia.com/nemo/guardrails/)
- [MLOps Guide 2026](https://rahulkolekar.com/mlops-in-2026-the-definitive-guide-tools-cloud-platforms-architectures-and-a-practical-playbook/)
- [LLMOps Roadmap](https://medium.com/@sanjeebmeister/the-complete-mlops-llmops-roadmap-for-2026-building-production-grade-ai-systems-bdcca5ed2771)
