# GraphQL Federation 가이드

Apollo Federation v2 기반 Supergraph 설계, Subgraph 구현 (Go gqlgen / Spring DGS), Router 배포, Schema CI

## Quick Reference (결정 트리)

```
GraphQL API 전략 선택
    │
    ├─ 단일 서비스, 단일 팀 ──────────> Standalone GraphQL (Federation 불필요)
    │
    ├─ 다수 서비스, 통합 Graph 필요 ──> Apollo Federation v2
    │   │
    │   ├─ Subgraph 런타임 선택
    │   │   ├─ Go 서비스 ────────────> gqlgen + federation plugin
    │   │   ├─ Spring 서비스 ────────> Netflix DGS Framework
    │   │   └─ Node.js 서비스 ───────> @apollo/subgraph
    │   │
    │   └─ Router 선택
    │       ├─ 프로덕션 (고성능) ────> GraphOS Router (Rust 기반)
    │       └─ 셀프호스트 / OSS ────> Apollo Router (OSS)
    │
    ├─ gRPC 서비스만 존재 ──────────> gRPC Gateway 또는 직접 gRPC 사용
    │
    └─ REST + GraphQL 혼합 ────────> Federation + REST Data Source

Subgraph 경계 설계
    │
    ├─ DDD Bounded Context 정의됨 ──> Context = Subgraph (권장)
    ├─ 팀 경계 기반 ────────────────> 팀당 1~2 Subgraph
    └─ Entity 공유 필요 ────────────> @key + Entity Resolver 패턴
```

---

## CRITICAL: Federation v2 아키텍처

```
Federation v2 Supergraph 구조:

  Client (Web / Mobile / BFF)
      │
      │  단일 GraphQL 엔드포인트
      ▼
  ┌─────────────────────────────┐
  │     GraphOS Router          │  ← Rust 기반, Query Planning, 인증
  │  (Supergraph Schema 보유)   │     OTel Tracing, Rate Limiting
  └──────┬──────┬──────┬────────┘
         │      │      │
    ┌────▼─┐ ┌─▼────┐ ┌▼──────┐
    │User  │ │Order │ │Product│   ← 각 Subgraph = Bounded Context
    │Subgraph│ │Subgraph│ │Subgraph│     독립 배포, 독립 스키마
    │(DGS) │ │(gqlgen)│ │(DGS) │
    └──┬───┘ └──┬───┘ └──┬────┘
       │        │        │
    ┌──▼───┐ ┌──▼───┐ ┌──▼────┐
    │UserDB│ │OrderDB│ │ProductDB│  ← Database per Service
    └──────┘ └──────┘ └───────┘

Schema Composition 흐름:
  Subgraph SDL → Composition → Supergraph Schema → Router 배포
  (각 서비스)    (CI/CD)        (단일 스키마)       (런타임)
```

### Federation v2 핵심 디렉티브

| 디렉티브 | 용도 | 예시 |
|----------|------|------|
| `@key` | Entity의 고유 식별 필드 지정 | `@key(fields: "id")` |
| `@shareable` | 여러 Subgraph에서 같은 필드 정의 허용 | 공통 필드 공유 시 |
| `@external` | 다른 Subgraph에서 정의된 필드 참조 | Entity 확장 시 필요 |
| `@override` | 필드 소유권을 다른 Subgraph로 이전 | 점진적 마이그레이션 |
| `@provides` | 특정 쿼리 경로에서 외부 필드 제공 | 성능 최적화 |
| `@requires` | 필드 resolve 시 다른 필드 필요 | 계산 필드 |
| `@inaccessible` | Supergraph에서 숨김 (내부용) | 내부 전용 필드 |
| `@tag` | 메타데이터 태그 | 스키마 분류 |

---

## CRITICAL: Subgraph 스키마 설계 원칙

```
Entity 소유권 원칙:

  Subgraph A (User)              Subgraph B (Order)
  ┌──────────────────┐           ┌──────────────────────┐
  │ type User @key   │           │ type Order @key      │
  │   id: ID!        │  ◄─ ref ─│   id: ID!            │
  │   email: String! │           │   user: User!        │
  │   name: String!  │           │   items: [OrderItem!]│
  │   address: Addr  │           │   totalAmount: Money │
  └──────────────────┘           │                      │
  ※ User 정의의 원본 소유자        │ extend type User @key│
                                 │   id: ID! @external  │
                                 │   orders: [Order!]   │
                                 └──────────────────────┘
                                 ※ User에 orders 필드 추가 (확장)

핵심 규칙:
  1. Entity는 하나의 Subgraph가 "원본 소유" (@key 정의)
  2. 다른 Subgraph는 Entity를 "확장"하여 필드 추가 가능
  3. Subgraph 경계 = DDD Bounded Context 경계
  4. 순환 의존 금지: A→B→A 구조는 설계 결함
```

### Subgraph 스키마 예시 (User Subgraph)

```graphql
# schema/user.graphql
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.7",
        import: ["@key", "@shareable"])

type Query {
  user(id: ID!): User
  users(first: Int = 20, after: String): UserConnection!
}

type User @key(fields: "id") {
  id: ID!
  email: String!
  name: String!
  status: UserStatus!
  createdAt: DateTime!
}

enum UserStatus {
  ACTIVE
  INACTIVE
  SUSPENDED
}

type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
}

type UserEdge {
  node: User!
  cursor: String!
}

type PageInfo @shareable {
  hasNextPage: Boolean!
  endCursor: String
}

scalar DateTime
```

### Subgraph 스키마 예시 (Order Subgraph)

```graphql
# schema/order.graphql
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.7",
        import: ["@key", "@external", "@requires"])

type Query {
  order(id: ID!): Order
  ordersByUser(userId: ID!, first: Int = 20): OrderConnection!
}

type Order @key(fields: "id") {
  id: ID!
  userId: ID!
  user: User!
  items: [OrderItem!]!
  totalAmount: Int!
  status: OrderStatus!
  createdAt: DateTime!
}

# User Entity 확장 - orders 필드 추가
type User @key(fields: "id") {
  id: ID!
  orders(first: Int = 10): [Order!]!
}

type OrderItem {
  product: Product!
  quantity: Int!
  unitPrice: Int!
}

# Product Entity 참조 (Product Subgraph에서 정의)
type Product @key(fields: "id") {
  id: ID!
}

enum OrderStatus {
  PENDING
  CONFIRMED
  SHIPPED
  DELIVERED
  CANCELLED
}

scalar DateTime
```

---

## Go gqlgen Federation 구현

### 프로젝트 구조

```
order-subgraph/
├── gqlgen.yml
├── graph/
│   ├── schema/
│   │   └── order.graphql
│   ├── model/
│   │   └── models_gen.go        # 자동 생성
│   ├── generated.go             # 자동 생성
│   ├── resolver.go              # Resolver 루트
│   ├── schema.resolvers.go      # Query/Mutation Resolver
│   └── entity.resolvers.go      # Entity Resolver (Federation)
├── internal/
│   ├── domain/
│   │   └── order.go
│   └── repository/
│       └── order_repo.go
└── cmd/
    └── server/
        └── main.go
```

### gqlgen.yml 설정

```yaml
# gqlgen.yml
schema:
  - graph/schema/*.graphql

exec:
  filename: graph/generated.go
  package: graph

model:
  filename: graph/model/models_gen.go
  package: model

resolver:
  layout: follow-schema
  dir: graph

# Federation v2 활성화
federation:
  filename: graph/federation.go
  package: graph
  version: 2
```

### Entity Resolver 구현

```go
// graph/entity.resolvers.go
package graph

import (
    "context"
    "fmt"

    "order-subgraph/graph/model"
)

// Order Entity Resolver - Router가 Order를 ID로 조회할 때 호출
func (r *entityResolver) FindOrderByID(
    ctx context.Context, id string,
) (*model.Order, error) {
    order, err := r.orderRepo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("order %s 조회 실패: %w", id, err)
    }
    return order, nil
}

// User Entity Resolver - User.orders 필드 resolve 시 사용
func (r *entityResolver) FindUserByID(
    ctx context.Context, id string,
) (*model.User, error) {
    // User 자체 데이터는 User Subgraph가 제공
    // 여기서는 stub만 반환하고 orders 필드만 resolve
    return &model.User{ID: id}, nil
}
```

### Query Resolver 구현

```go
// graph/schema.resolvers.go
package graph

import (
    "context"

    "order-subgraph/graph/model"
)

func (r *queryResolver) Order(
    ctx context.Context, id string,
) (*model.Order, error) {
    return r.orderRepo.FindByID(ctx, id)
}

func (r *queryResolver) OrdersByUser(
    ctx context.Context, userID string, first *int,
) (*model.OrderConnection, error) {
    limit := 20
    if first != nil {
        limit = *first
    }
    return r.orderRepo.FindByUserID(ctx, userID, limit)
}

// User.orders 필드 Resolver
func (r *userResolver) Orders(
    ctx context.Context, obj *model.User, first *int,
) ([]*model.Order, error) {
    limit := 10
    if first != nil {
        limit = *first
    }
    orders, err := r.orderRepo.FindByUserID(ctx, obj.ID, limit)
    if err != nil {
        return nil, err
    }
    return orders.Edges, nil
}
```

### DataLoader 패턴 (N+1 방지)

```go
// internal/dataloader/loader.go
package dataloader

import (
    "context"
    "time"

    "github.com/graph-gophers/dataloader/v7"
    "order-subgraph/graph/model"
    "order-subgraph/internal/repository"
)

type Loaders struct {
    ProductLoader *dataloader.Loader[string, *model.Product]
}

func NewLoaders(repo repository.ProductRepo) *Loaders {
    return &Loaders{
        ProductLoader: dataloader.NewBatchedLoader(
            func(ctx context.Context, keys []string) []*dataloader.Result[*model.Product] {
                // 배치로 한 번에 조회 (N+1 방지)
                products, _ := repo.FindByIDs(ctx, keys)
                productMap := make(map[string]*model.Product)
                for _, p := range products {
                    productMap[p.ID] = p
                }
                results := make([]*dataloader.Result[*model.Product], len(keys))
                for i, key := range keys {
                    results[i] = &dataloader.Result[*model.Product]{Data: productMap[key]}
                }
                return results
            },
            dataloader.WithWait[string, *model.Product](2*time.Millisecond),
        ),
    }
}
```

---

## Spring Netflix DGS Federation 구현

### 의존성 설정

```kotlin
// build.gradle.kts
plugins {
    id("com.netflix.dgs.codegen") version "7.0.3"
}

dependencies {
    implementation(platform("com.netflix.graphql.dgs:graphql-dgs-platform-dependencies:9.1.2"))
    implementation("com.netflix.graphql.dgs:graphql-dgs-spring-graphql-starter")
    implementation("com.netflix.graphql.dgs:graphql-dgs-extended-scalars")
    // Federation 지원 내장 (별도 의존성 불필요)
}

// DGS Codegen 설정
tasks.generateJava {
    schemaPaths.add("${projectDir}/src/main/resources/schema")
    packageName = "com.example.user.generated"
    generateClient = true
}
```

### 스키마 파일

```graphql
# src/main/resources/schema/user.graphql
# DGS는 Federation 디렉티브를 자동 인식

type Query {
    user(id: ID!): User
    users(first: Int = 20, after: String): UserConnection!
}

type User @key(fields: "id") {
    id: ID!
    email: String!
    name: String!
    status: UserStatus!
    createdAt: DateTime
}
```

### DGS DataFetcher 구현

```java
// UserDataFetcher.java
@DgsComponent
@RequiredArgsConstructor
public class UserDataFetcher {

    private final UserRepository userRepository;

    @DgsQuery
    public User user(@InputArgument String id) {
        return userRepository.findById(id)
            .orElseThrow(() -> new DgsEntityNotFoundException("User not found: " + id));
    }

    @DgsQuery
    public UserConnection users(
            @InputArgument Integer first,
            @InputArgument String after) {
        int limit = (first != null) ? first : 20;
        return userRepository.findAllPaginated(limit, after);
    }

    // Federation Entity Resolver
    // Router가 User Entity를 ID로 조회할 때 호출됨
    @DgsEntityFetcher(name = "User")
    public User resolveUser(Map<String, Object> values) {
        String id = (String) values.get("id");
        return userRepository.findById(id)
            .orElseThrow(() -> new DgsEntityNotFoundException(
                "Entity User(" + id + ") not found"));
    }
}
```

### DGS DataLoader (N+1 방지)

```java
// UserDataLoader.java
@DgsDataLoader(name = "users")
@RequiredArgsConstructor
public class UserDataLoader implements BatchLoaderWithContext<String, User> {

    private final UserRepository userRepository;

    @Override
    public CompletionStage<List<User>> load(
            List<String> userIds,
            BatchLoaderEnvironment env) {
        return CompletableFuture.supplyAsync(() ->
            userRepository.findAllByIdIn(userIds)
        );
    }
}

// Order Subgraph에서 User 참조 시
@DgsComponent
@RequiredArgsConstructor
public class OrderUserDataFetcher {

    @DgsData(parentType = "Order", field = "user")
    public CompletableFuture<User> user(
            DgsDataFetchingEnvironment dfe) {
        Order order = dfe.getSource();
        DataLoader<String, User> loader = dfe.getDataLoader("users");
        return loader.load(order.getUserId());
    }
}
```

---

## CRITICAL: Router 배포 및 운영

### Supergraph 구성 (rover CLI)

```bash
# rover CLI로 Supergraph Schema 생성
# 각 Subgraph SDL을 합성하여 단일 Supergraph Schema 생성

# supergraph.yaml - Subgraph 목록 정의
cat <<'EOF' > supergraph.yaml
federation_version: =2.7.1
subgraphs:
  user:
    routing_url: http://user-subgraph:4000/graphql
    schema:
      file: ./schemas/user.graphql
  order:
    routing_url: http://order-subgraph:4000/graphql
    schema:
      file: ./schemas/order.graphql
  product:
    routing_url: http://product-subgraph:4000/graphql
    schema:
      file: ./schemas/product.graphql
EOF

# Supergraph Schema 생성 (Composition)
rover supergraph compose --config supergraph.yaml > supergraph.graphql

# Composition 에러 시 Breaking Change 감지
rover subgraph check my-graph@prod \
  --name user \
  --schema ./schemas/user.graphql
```

### Router 설정 (router.yaml)

```yaml
# router.yaml - GraphOS Router 설정
supergraph:
  path: /supergraph.graphql     # 로컬 파일 사용 시
  # apollo_graph_ref: my-graph@prod  # GraphOS 사용 시

# CORS 설정
cors:
  origins:
    - https://app.example.com
  allow_headers:
    - Content-Type
    - Authorization
    - X-Request-ID

# 인증 설정 (JWT 검증)
authentication:
  router:
    jwt:
      jwks:
        - url: https://auth.example.com/.well-known/jwks.json

# 헤더 전파 (Subgraph로 전달)
headers:
  all:
    request:
      - propagate:
          named: Authorization
      - propagate:
          named: X-Request-ID

# 성능 설정
traffic_shaping:
  all:
    timeout: 30s
  subgraphs:
    user:
      timeout: 5s
    order:
      timeout: 10s

# Telemetry 설정 (OTel)
telemetry:
  exporters:
    tracing:
      otlp:
        enabled: true
        endpoint: http://otel-collector:4317
        protocol: grpc
    metrics:
      prometheus:
        enabled: true
        listen: 0.0.0.0:9090
        path: /metrics

  instrumentation:
    spans:
      mode: spec_compliant
      router:
        attributes:
          http.request.method: true
          url.path: true
      subgraph:
        attributes:
          subgraph.name: true
          graphql.operation.name: true
```

### Kubernetes Deployment + HPA

```yaml
# k8s/router-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: graphql-router
  labels:
    app: graphql-router
spec:
  replicas: 3
  selector:
    matchLabels:
      app: graphql-router
  template:
    metadata:
      labels:
        app: graphql-router
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: router
          image: ghcr.io/apollographql/router:v2.1.1
          args:
            - --config
            - /app/config/router.yaml
            - --supergraph
            - /app/config/supergraph.graphql
          ports:
            - name: http
              containerPort: 4000
            - name: metrics
              containerPort: 9090
          env:
            - name: APOLLO_ROUTER_LOG
              value: info
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: "2"
              memory: 1Gi
          livenessProbe:
            httpGet:
              path: /health
              port: 4000
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health?ready
              port: 4000
            initialDelaySeconds: 3
            periodSeconds: 5
          volumeMounts:
            - name: config
              mountPath: /app/config
      volumes:
        - name: config
          configMap:
            name: router-config
---
apiVersion: v1
kind: Service
metadata:
  name: graphql-router
spec:
  selector:
    app: graphql-router
  ports:
    - name: http
      port: 80
      targetPort: 4000
    - name: metrics
      port: 9090
      targetPort: 9090
---
# HPA - 요청 기반 오토스케일링
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: graphql-router-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: graphql-router
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
```

---

## OTel 분산 트레이싱 설정

### Subgraph OTel 설정 (Go gqlgen)

```go
// cmd/server/main.go
package main

import (
    "context"
    "log"
    "net/http"

    "github.com/99designs/gqlgen/graphql/handler"
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/propagation"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    "go.opentelemetry.io/otel/sdk/resource"
    semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

func initTracer(ctx context.Context) (*sdktrace.TracerProvider, error) {
    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint("otel-collector:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        return nil, err
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String("order-subgraph"),
            semconv.ServiceVersionKey.String("1.0.0"),
        )),
        sdktrace.WithSampler(sdktrace.ParentBased(
            sdktrace.TraceIDRatioBased(0.1), // 프로덕션: 10% 샘플링
        )),
    )

    otel.SetTracerProvider(tp)
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{},
        propagation.Baggage{},
    ))
    return tp, nil
}

func main() {
    ctx := context.Background()
    tp, _ := initTracer(ctx)
    defer tp.Shutdown(ctx)

    srv := handler.NewDefaultServer(
        generated.NewExecutableSchema(generated.Config{Resolvers: &Resolver{}}),
    )

    // OTel HTTP 미들웨어로 Trace Context 전파
    http.Handle("/graphql",
        otelhttp.NewHandler(srv, "graphql",
            otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
                return "GraphQL " + r.Method
            }),
        ),
    )

    log.Println("Order Subgraph on :4000")
    log.Fatal(http.ListenAndServe(":4000", nil))
}
```

### Subgraph OTel 설정 (Spring DGS)

```yaml
# application.yaml
management:
  tracing:
    sampling:
      probability: 0.1          # 프로덕션 10% 샘플링
  otlp:
    tracing:
      endpoint: http://otel-collector:4318/v1/traces

spring:
  application:
    name: user-subgraph
```

```kotlin
// build.gradle.kts
dependencies {
    implementation("io.micrometer:micrometer-tracing-bridge-otel")
    implementation("io.opentelemetry:opentelemetry-exporter-otlp")
}
```

---

## Schema CI/CD 파이프라인

### GitHub Actions - Schema Validation

```yaml
# .github/workflows/schema-ci.yaml
name: GraphQL Schema CI

on:
  pull_request:
    paths:
      - 'schemas/**'
      - '**/src/main/resources/schema/**'
      - '**/graph/schema/**'

jobs:
  schema-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Rover CLI
        run: |
          curl -sSL https://rover.apollo.dev/nix/latest | sh
          echo "$HOME/.rover/bin" >> $GITHUB_PATH

      - name: Subgraph Schema 검증 (Lint)
        run: |
          for schema in schemas/*.graphql; do
            echo "Validating: $schema"
            rover subgraph lint \
              --name "$(basename $schema .graphql)" \
              --schema "$schema" \
              my-graph@prod
          done

      - name: Composition 검증 (Breaking Change 탐지)
        run: |
          # 변경된 Subgraph 감지
          CHANGED=$(git diff --name-only origin/main -- schemas/)
          for file in $CHANGED; do
            SUBGRAPH=$(basename "$file" .graphql)
            echo "Checking: $SUBGRAPH"
            rover subgraph check my-graph@prod \
              --name "$SUBGRAPH" \
              --schema "$file"
          done

      - name: Supergraph Composition 테스트
        run: |
          rover supergraph compose \
            --config supergraph.yaml \
            > /dev/null 2>&1 \
            && echo "Composition 성공" \
            || (echo "Composition 실패" && exit 1)

  deploy-schema:
    needs: schema-check
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Rover CLI
        run: |
          curl -sSL https://rover.apollo.dev/nix/latest | sh
          echo "$HOME/.rover/bin" >> $GITHUB_PATH

      - name: Publish Subgraph Schemas
        env:
          APOLLO_KEY: ${{ secrets.APOLLO_KEY }}
        run: |
          rover subgraph publish my-graph@prod \
            --name user \
            --schema schemas/user.graphql \
            --routing-url http://user-subgraph:4000/graphql

          rover subgraph publish my-graph@prod \
            --name order \
            --schema schemas/order.graphql \
            --routing-url http://order-subgraph:4000/graphql
```

---

## Anti-Patterns

| 실수 | 문제 | 올바른 방법 |
|------|------|------------|
| 단일 거대 Subgraph | 모놀리스와 동일, Federation 의미 상실 | DDD Bounded Context 기반 분리 |
| Subgraph 간 순환 참조 | 배포 순서 의존, 장애 전파 | 단방향 의존, 이벤트 기반 동기화 |
| N+1 Query 미처리 | Entity Resolver 호출 폭발, 성능 저하 | DataLoader 패턴 필수 적용 |
| Router 없이 직접 호출 | 클라이언트가 Subgraph 위치 알아야 함 | 항상 Router 경유, 단일 엔드포인트 |
| Schema Composition CI 미구축 | Breaking Change가 프로덕션 유입 | PR 단계에서 `rover subgraph check` 필수 |
| 모든 필드 @shareable | 소유권 모호, 데이터 불일치 | 원본 소유 Subgraph 명확히 지정 |
| Subgraph에 인증 로직 중복 | 코드 중복, 정책 불일치 | Router에서 JWT 검증, Subgraph에 헤더 전파 |
| Query depth 제한 없음 | 악의적 깊은 쿼리로 DoS 공격 가능 | Router에서 query depth/complexity 제한 설정 |

---

## 체크리스트

### 스키마 설계
- [ ] Subgraph 경계가 DDD Bounded Context와 일치하는가?
- [ ] Entity `@key`가 모든 공유 타입에 정의되어 있는가?
- [ ] `@external`, `@requires` 사용 시 필드 의존성이 명확한가?
- [ ] Relay 스타일 Cursor Pagination (Connection 패턴) 적용했는가?
- [ ] 스키마 네이밍이 일관적인가? (camelCase 필드, PascalCase 타입)

### 구현
- [ ] Entity Resolver가 모든 `@key` 타입에 구현되어 있는가?
- [ ] DataLoader로 N+1 문제를 해결했는가?
- [ ] 에러 처리가 GraphQL errors 표준 형식을 따르는가?
- [ ] Subgraph health check 엔드포인트가 있는가?

### Router 운영
- [ ] Router HPA가 CPU/RPS 기반으로 설정되어 있는가?
- [ ] JWT 인증이 Router 레벨에서 처리되는가?
- [ ] Subgraph별 timeout이 적절히 설정되어 있는가?
- [ ] Query depth/complexity 제한이 설정되어 있는가?

### Observability
- [ ] OTel tracing이 Router → Subgraph 전 구간에 설정되어 있는가?
- [ ] Prometheus 메트릭이 Router에서 노출되고 있는가?
- [ ] GraphQL operation별 latency/error 대시보드가 있는가?

### CI/CD
- [ ] PR 단계에서 `rover subgraph check`로 Breaking Change 탐지하는가?
- [ ] `rover supergraph compose`로 Composition 유효성 검사하는가?
- [ ] Main 머지 시 `rover subgraph publish`로 Schema Registry 업데이트하는가?

---

## 관련 Skills

- `/api-design` - REST API 설계 원칙, GraphQL과의 비교
- `/msa-ddd` - Bounded Context 설계, Subgraph 경계 도출
- `/grpc` - gRPC 서비스 통신, Subgraph 간 내부 통신 대안
- `/observability-otel` - OpenTelemetry 분산 트레이싱 심화
- `/msa-api-gateway-patterns` - API Gateway vs Federation Router 비교
