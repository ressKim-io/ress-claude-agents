[English](../../scenarios/new-microservice.md) | **한국어**

# 시나리오: 신규 MSA 서비스 개발

> Go 기반 주문 서비스(Order Service)를 처음부터 개발하는 워크스루

---

## 개요

| 항목 | 내용 |
|------|------|
| **대상** | 백엔드 개발자 (Go 또는 Java) |
| **소요 시간** | 2-3시간 |
| **필요 조건** | Go 1.21+, Docker, Claude Code 설치 |
| **결과물** | 프로덕션 준비된 Go 주문 서비스 + 테스트 + PR |

---

## 전체 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 1     │     │  Step 2     │     │  Step 3     │
│  서비스 설계  │────►│  구조 생성   │────►│  핵심 구현   │
│             │     │             │     │             │
│ architect   │     │ go-expert   │     │ go-expert   │
│ /msa-ddd    │     │ /go-micro   │     │ /go-database│
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       │
       ▼                                       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Step 4     │     │  Step 5     │     │  Step 6     │
│  복원력 패턴  │────►│  테스트     │────►│  보안 검증   │
│             │     │             │     │             │
│ /resilience │     │ /go-testing │     │ security-   │
│ saga-agent  │     │ code-review │     │ scanner     │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  Step 7     │
                                        │  PR 생성    │
                                        │             │
                                        │ git-workflow│
                                        └─────────────┘
```

---

## Step 1: 서비스 설계

**사용 도구**: `architect-agent` + `/msa-ddd`

### 이렇게 요청하세요

```
"주문 서비스(Order Service) 설계해줘.
 - 결제 서비스, 재고 서비스와 연동
 - Bounded Context 정의
 - API 계약 (gRPC 또는 REST) 설계
 - 이벤트 목록 정의"
```

### Claude가 하는 일

- Bounded Context Map 작성
- Aggregate Root 정의 (Order, OrderItem)
- 도메인 이벤트 목록 (OrderCreated, OrderPaid, OrderCancelled)
- API 엔드포인트 설계

### 체크포인트

- [ ] Bounded Context 경계가 명확한가?
- [ ] 다른 서비스와의 의존성이 정의되었는가?
- [ ] 이벤트 스키마가 정의되었는가?

---

## Step 2: 프로젝트 구조 생성

**사용 도구**: `go-expert` + `/go-microservice`

### 이렇게 요청하세요

```
"Go 주문 서비스 프로젝트 구조를 헥사고날 아키텍처로 생성해줘.
 - /go-microservice 스킬 참고
 - cmd/server, internal/domain, internal/adapter, internal/port 구조"
```

### 예상 결과

```
order-service/
├── cmd/server/main.go
├── internal/
│   ├── domain/          # 도메인 모델, 비즈니스 로직
│   │   ├── order.go
│   │   └── event.go
│   ├── port/            # 인터페이스 (인바운드/아웃바운드)
│   │   ├── inbound.go
│   │   └── outbound.go
│   └── adapter/         # 구현체
│       ├── http/
│       ├── grpc/
│       └── postgres/
├── go.mod
└── Dockerfile
```

### 체크포인트

- [ ] 헥사고날 아키텍처 레이어가 분리되었는가?
- [ ] 도메인 레이어에 외부 의존성이 없는가?

---

## Step 3: 핵심 비즈니스 로직 구현

**사용 도구**: `go-expert` + `/go-database` + `/effective-go`

### 이렇게 요청하세요

```
"Order Aggregate 핵심 로직을 구현해줘.
 - 주문 생성, 결제 확인, 취소
 - 상태 전이: CREATED → PAID → SHIPPED → DELIVERED / CANCELLED
 - PostgreSQL 저장소 (pgx 사용)"
```

### Claude가 하는 일

- Order 도메인 모델 + 상태 머신 구현
- Repository 인터페이스 + PostgreSQL 어댑터
- HTTP/gRPC 핸들러

### 체크포인트

- [ ] 상태 전이가 도메인 모델 안에서 관리되는가?
- [ ] 에러 처리가 Go idiom을 따르는가?

---

## Step 4: 복원력 패턴 적용

**사용 도구**: `saga-agent` + `/msa-resilience` + `/msa-event-driven`

### 이렇게 요청하세요

```
"결제 서비스 호출에 복원력 패턴 적용해줘.
 - Retry (Exponential Backoff + Jitter)
 - Circuit Breaker
 - Timeout
 - Transactional Outbox로 이벤트 발행"
```

### Claude가 하는 일

- 외부 서비스 호출에 Retry/Circuit Breaker/Timeout 적용
- Transactional Outbox 패턴으로 이벤트 발행 보장
- 보상 트랜잭션 (주문 취소 시 결제 환불)

### 체크포인트

- [ ] Circuit Breaker 상태 전이가 올바른가?
- [ ] 멱등성이 보장되는가?
- [ ] 이벤트 발행이 트랜잭션과 함께 처리되는가?

---

## Step 5: 테스트 작성

**사용 도구**: `code-reviewer` + `/go-testing`

### 이렇게 요청하세요

```
"주문 서비스 테스트를 작성해줘.
 - 도메인 로직 단위 테스트 (Table-driven)
 - Repository 통합 테스트 (Testcontainers)
 - HTTP 핸들러 테스트
 - Happy path + Edge case + Error case"
```

### Claude가 하는 일

- Given-When-Then 구조의 테스트
- Table-driven 패턴 활용
- 외부 의존성 Mock/Stub
- 커버리지 95%+ 목표

### 체크포인트

- [ ] 핵심 비즈니스 로직 커버리지 95%+?
- [ ] Edge case (빈 주문, 중복 결제 등) 테스트 존재?
- [ ] 테스트가 독립적으로 실행 가능한가?

---

## Step 6: 보안 검증

**사용 도구**: `security-scanner`

### 이렇게 요청하세요

```
"보안 취약점 검사해줘"
```

### Claude가 하는 일

- OWASP Top 10 점검
- SQL Injection 방지 확인 (파라미터 바인딩)
- 시크릿 하드코딩 여부 확인
- 입력 검증 로직 확인

### 체크포인트

- [ ] SQL 쿼리가 파라미터 바인딩 사용?
- [ ] 시크릿이 환경변수로 관리되는가?
- [ ] 입력 검증이 존재하는가?

---

## Step 7: PR 생성

**사용 도구**: `git-workflow`

### 이렇게 요청하세요

```
"PR 만들어줘"
```

### Claude가 하는 일

- Conventional Commits 형식 커밋
- PR 제목 + 본문 자동 생성
- 테스트 통과 확인

### 체크포인트

- [ ] 커밋 메시지가 Conventional Commits 형식?
- [ ] PR 크기가 400줄 이내?
- [ ] 테스트가 모두 통과?

---

## 마무리

### 검증 방법

```bash
# 테스트 실행
go test ./... -v -cover

# 린트 검사
golangci-lint run

# Docker 빌드
docker build -t order-service .

# 로컬 실행
docker compose up -d
curl http://localhost:8080/health
```

### 다음 단계

- [프로덕션 장애 대응](production-incident.md) — 서비스 운영 중 장애 대응
- `/deployment-strategies` — Canary/Blue-Green 배포 전략
- `/gitops-argocd` — ArgoCD로 GitOps 배포 설정
- `/observability-otel` — OpenTelemetry 계측 추가
