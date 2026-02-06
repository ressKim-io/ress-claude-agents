# Task Queue 패턴 가이드

비동기 작업 분산 처리, 우선순위 큐, 재시도 전략, Worker 오토스케일링 패턴

## Quick Reference (결정 트리)

```
Task Queue 필요한가?
    │
    ├─ HTTP 응답 시간 내 완료 가능 ──> 동기 처리 (REST/gRPC)
    │
    ├─ 수초~수분 소요 작업 ──────────> Task Queue (Celery/BullMQ/asynq)
    │
    ├─ 이벤트 스트림 처리 ──────────> Kafka Consumer (이벤트 드리븐)
    │
    └─ 배치 대량 처리 ──────────────> K8s Job / Spark

Task Queue 기술 선택?
    │
    ├─ Python 에코시스템 ──────────> Celery 5.6 (Redis/RabbitMQ)
    │
    ├─ Node.js 에코시스템 ─────────> BullMQ 5.x (Redis Streams)
    │
    ├─ Go 에코시스템 ──────────────> asynq (Redis 기반)
    │
    └─ Java/Spring 에코시스템 ─────> Spring + RabbitMQ / Redis

Worker 배포 방식?
    │
    ├─ 상시 실행 + 오토스케일링 ───> K8s Deployment + KEDA
    │
    ├─ 일회성 배치 작업 ──────────> K8s Job (completions 지정)
    │
    └─ 주기적 작업 ───────────────> K8s CronJob
```

---

## CRITICAL: Task Queue 아키텍처

```
Producer (API Server)                    Broker (Redis/RabbitMQ)
┌─────────────────┐                    ┌─────────────────────────┐
│  POST /orders   │───enqueue─────────>│  Priority Queue         │
│  POST /reports  │                    │  ┌─────┬─────┬─────┐   │
│  Webhook Handler│                    │  │ P:1 │ P:5 │ P:10│   │
└─────────────────┘                    │  └──┬──┴──┬──┴──┬──┘   │
                                       │     │     │     │       │
                                       │  Dead Letter Queue      │
                                       │  ┌─────────────────┐   │
                                       │  │ 재시도 소진 태스크  │   │
                                       │  └─────────────────┘   │
                                       └──────────┬─────────────┘
                                                  │ dequeue
                                       ┌──────────▼─────────────┐
                                       │  Worker Pool            │
                                       │  ┌───┐ ┌───┐ ┌───┐    │
                                       │  │W1 │ │W2 │ │W3 │    │
                                       │  └───┘ └───┘ └───┘    │
                                       │  KEDA 오토스케일링       │
                                       └─────────────────────────┘
```

### 핵심 개념 비교

| 항목 | Celery 5.6 | BullMQ 5.x | Go asynq | Spring + RabbitMQ |
|------|-----------|------------|----------|-------------------|
| 언어 | Python | Node.js (TS) | Go | Java/Kotlin |
| 브로커 | Redis/RabbitMQ | Redis Streams | Redis | RabbitMQ/Redis |
| 우선순위 큐 | 지원 | 네이티브 지원 | 지원 | 네이티브 지원 |
| 지연 실행 | countdown/eta | delay/repeat | ProcessIn | TTL + DLX |
| 워크플로우 | chain/group/chord | FlowProducer | Group (제한적) | Spring Batch |
| 모니터링 | Flower | BullBoard | asynqmon | RabbitMQ Console |
| K8s 스케일링 | KEDA Redis Scaler | KEDA Redis Scaler | KEDA Redis Scaler | KEDA RabbitMQ Scaler |

---

## Celery 5.6 패턴 (Python)

### 기본 설정 및 태스크 정의

```python
# celery_app.py
from celery import Celery

app = Celery('tasks', broker='redis://redis:6379/0', backend='redis://redis:6379/1')

app.conf.update(
    task_serializer='json',
    result_serializer='json',
    accept_content=['json'],
    timezone='Asia/Seoul',
    task_acks_late=True,              # 처리 완료 후 ACK (Worker 장애 시 재처리)
    worker_prefetch_multiplier=1,      # 공정한 분배 (우선순위 큐 필수)
    task_reject_on_worker_lost=True,   # Worker 비정상 종료 시 재큐잉
    task_default_queue='default',
    task_routes={
        'tasks.send_email': {'queue': 'email'},
        'tasks.generate_report': {'queue': 'reports', 'priority': 5},
    },
    # 재시도 설정
    task_default_retry_delay=60,       # 기본 재시도 간격 60초
    task_max_retries=3,
)
```

### Chain, Group, Chord 워크플로우

```python
from celery import chain, group, chord

# 태스크 정의
@app.task(bind=True, max_retries=3, acks_late=True)
def validate_order(self, order_id: str) -> dict:
    """주문 유효성 검증"""
    try:
        order = OrderService.validate(order_id)
        return {"order_id": order_id, "status": "validated"}
    except ValidationError as exc:
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)

@app.task(bind=True, max_retries=3)
def charge_payment(self, validated: dict) -> dict:
    """결제 처리 - 멱등성 키 사용"""
    idempotency_key = f"payment:{validated['order_id']}"
    result = PaymentService.charge(validated['order_id'], idempotency_key)
    return {"order_id": validated['order_id'], "payment_id": result.id}

@app.task
def send_notification(result: dict) -> None:
    """알림 발송"""
    NotificationService.send(result['order_id'], "주문이 완료되었습니다")

@app.task
def update_inventory(result: dict) -> dict:
    """재고 차감"""
    InventoryService.decrease(result['order_id'])
    return result

@app.task
def finalize_order(results: list) -> None:
    """주문 최종 확정 - chord callback"""
    order_id = results[0]['order_id']
    OrderService.finalize(order_id)

# Chain: 순차 실행 (validate -> charge -> notify)
order_pipeline = chain(
    validate_order.s(order_id="ord-123"),
    charge_payment.s(),
    send_notification.s(),
)
order_pipeline.apply_async()

# Group: 병렬 실행
parallel_tasks = group(
    send_notification.s({"order_id": "ord-123"}),
    update_inventory.s({"order_id": "ord-123"}),
)
parallel_tasks.apply_async()

# Chord: 병렬 실행 후 콜백 (모든 태스크 완료 후 finalize 실행)
post_payment = chord(
    [send_notification.s({"order_id": "ord-123"}),
     update_inventory.s({"order_id": "ord-123"})],
    finalize_order.s()
)
post_payment.apply_async()
```

---

## BullMQ 5.x 패턴 (Node.js / TypeScript)

### 기본 설정 및 Job 등록

```typescript
// queue.ts - Redis Streams 기반 Task Queue
import { Queue, Worker, FlowProducer } from 'bullmq';
import IORedis from 'ioredis';

const connection = new IORedis({
  host: 'redis',
  port: 6379,
  maxRetriesPerRequest: null,  // BullMQ 필수 설정
});

// 큐 생성
const orderQueue = new Queue('order-processing', {
  connection,
  defaultJobOptions: {
    attempts: 3,                          // 최대 재시도 횟수
    backoff: { type: 'exponential', delay: 1000 },  // 지수 백오프 (1s, 2s, 4s)
    removeOnComplete: { age: 86400 },     // 완료 후 24시간 보관
    removeOnFail: { age: 604800 },        // 실패 후 7일 보관
  },
});

// Job 등록: 우선순위, 지연, 반복
await orderQueue.add('send-invoice', { orderId: 'ord-123' }, {
  priority: 1,                            // 1이 최고 우선순위
});

await orderQueue.add('generate-report', { reportType: 'monthly' }, {
  delay: 60000,                           // 60초 후 실행
});

await orderQueue.add('daily-summary', { type: 'summary' }, {
  repeat: { pattern: '0 9 * * *' },       // 매일 오전 9시 실행 (cron)
});
```

### Worker 및 FlowProducer

```typescript
// worker.ts - 태스크 처리 Worker
const worker = new Worker('order-processing', async (job) => {
  switch (job.name) {
    case 'send-invoice':
      await InvoiceService.generate(job.data.orderId);
      break;
    case 'generate-report':
      // 진행률 업데이트
      await job.updateProgress(10);
      const report = await ReportService.generate(job.data.reportType);
      await job.updateProgress(100);
      return { reportUrl: report.url };
    default:
      throw new Error(`알 수 없는 Job 타입: ${job.name}`);
  }
}, {
  connection,
  concurrency: 5,                         // 동시 처리 수
  limiter: { max: 100, duration: 60000 }, // Rate Limit: 분당 100건
});

worker.on('failed', (job, err) => {
  if (job && job.attemptsMade >= (job.opts.attempts ?? 3)) {
    // Dead Letter 처리: 모든 재시도 소진
    alertService.notify(`DLQ 도달: ${job.name}, error: ${err.message}`);
  }
});

// FlowProducer: 의존 관계가 있는 Job 체인
const flow = new FlowProducer({ connection });
await flow.add({
  name: 'finalize-order',
  queueName: 'order-processing',
  data: { orderId: 'ord-123' },
  children: [
    { name: 'charge-payment', queueName: 'order-processing', data: { orderId: 'ord-123' } },
    { name: 'update-inventory', queueName: 'order-processing', data: { orderId: 'ord-123' } },
  ],
});
```

---

## Go asynq 패턴

### Client (태스크 발행)

```go
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hibiken/asynq"
)

// 태스크 타입 상수 정의
const (
    TypeOrderProcess    = "order:process"
    TypeEmailSend       = "email:send"
    TypeReportGenerate  = "report:generate"
)

// 태스크 페이로드 구조체
type OrderPayload struct {
    OrderID    string `json:"order_id"`
    CustomerID string `json:"customer_id"`
}

// 태스크 생성 함수
func NewOrderTask(orderID, customerID string) (*asynq.Task, error) {
    payload, err := json.Marshal(OrderPayload{OrderID: orderID, CustomerID: customerID})
    if err != nil {
        return nil, fmt.Errorf("페이로드 직렬화 실패: %w", err)
    }
    return asynq.NewTask(
        TypeOrderProcess,
        payload,
        asynq.MaxRetry(5),                         // 최대 재시도 5회
        asynq.Timeout(30*time.Second),              // 태스크 타임아웃 30초
        asynq.Queue("critical"),                    // 큐 이름 지정
        asynq.Unique(24*time.Hour),                 // 24시간 내 중복 방지 (멱등성 키)
    ), nil
}

func main() {
    client := asynq.NewClient(asynq.RedisClientOpt{Addr: "redis:6379"})
    defer client.Close()

    // 즉시 실행
    task, _ := NewOrderTask("ord-123", "cust-456")
    info, err := client.Enqueue(task)
    if err != nil {
        panic(fmt.Sprintf("태스크 등록 실패: %v", err))
    }
    fmt.Printf("태스크 등록: id=%s queue=%s\n", info.ID, info.Queue)

    // 지연 실행: 10분 후
    _, _ = client.Enqueue(task, asynq.ProcessIn(10*time.Minute))

    // 스케줄러: cron 패턴으로 주기 실행
    scheduler := asynq.NewScheduler(
        asynq.RedisClientOpt{Addr: "redis:6379"}, nil,
    )
    reportTask := asynq.NewTask(TypeReportGenerate, nil)
    scheduler.Register("0 9 * * *", reportTask)  // 매일 오전 9시
    scheduler.Run()
}
```

### Server 및 Handler (태스크 처리)

```go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "math"
    "time"

    "github.com/hibiken/asynq"
)

func main() {
    srv := asynq.NewServer(
        asynq.RedisClientOpt{Addr: "redis:6379"},
        asynq.Config{
            Concurrency: 10,  // 동시 처리 goroutine 수
            Queues: map[string]int{
                "critical": 6,  // 가중치 기반 우선순위
                "default":  3,
                "low":      1,
            },
            RetryDelayFunc: func(n int, e error, t *asynq.Task) time.Duration {
                // 지수 백오프: 2^n * 1초 (1s, 2s, 4s, 8s, 16s)
                return time.Duration(math.Pow(2, float64(n))) * time.Second
            },
            ErrorHandler: asynq.ErrorHandlerFunc(func(ctx context.Context, task *asynq.Task, err error) {
                retried, _ := asynq.GetRetryCount(ctx)
                maxRetry, _ := asynq.GetMaxRetry(ctx)
                if retried >= maxRetry {
                    // Dead Letter: 모든 재시도 소진 시 알림
                    log.Printf("[DLQ] task=%s, error=%v", task.Type(), err)
                }
            }),
        },
    )

    mux := asynq.NewServeMux()
    mux.HandleFunc(TypeOrderProcess, HandleOrderProcess)
    mux.HandleFunc(TypeEmailSend, HandleEmailSend)

    if err := srv.Run(mux); err != nil {
        log.Fatalf("Worker 시작 실패: %v", err)
    }
}

func HandleOrderProcess(ctx context.Context, t *asynq.Task) error {
    var p OrderPayload
    if err := json.Unmarshal(t.Payload(), &p); err != nil {
        return fmt.Errorf("페이로드 파싱 실패: %w", err)
    }

    // 멱등성 확인: 이미 처리된 주문인지 검증
    if processed, _ := orderRepo.IsProcessed(ctx, p.OrderID); processed {
        log.Printf("이미 처리된 주문, 건너뜀: %s", p.OrderID)
        return nil
    }

    // 비즈니스 로직 수행
    if err := orderService.Process(ctx, p.OrderID); err != nil {
        return fmt.Errorf("주문 처리 실패: %w", err)  // 반환된 에러 -> 자동 재시도
    }

    return nil  // nil 반환 -> 성공, ACK 처리
}

func HandleEmailSend(ctx context.Context, t *asynq.Task) error {
    // 이메일 발송 핸들러 구현
    return nil
}
```

---

## Spring 통합 (RabbitMQ / Redis)

### Spring AMQP + RabbitMQ Task Queue

```java
// RabbitMQ 큐 설정 - 우선순위 큐 + DLQ
@Configuration
public class TaskQueueConfig {
    @Bean
    public Queue taskQueue() {
        return QueueBuilder.durable("task-queue")
            .withArgument("x-max-priority", 10)         // 우선순위 큐 (0~10)
            .withArgument("x-dead-letter-exchange", "dlx")
            .withArgument("x-dead-letter-routing-key", "dlq")
            .build();
    }

    @Bean
    public Queue deadLetterQueue() {
        return QueueBuilder.durable("task-dlq").build();
    }

    @Bean
    public DirectExchange dlxExchange() {
        return new DirectExchange("dlx");
    }

    @Bean
    public Binding dlqBinding() {
        return BindingBuilder.bind(deadLetterQueue()).to(dlxExchange()).with("dlq");
    }
}

// 태스크 발행
@Service
@RequiredArgsConstructor
public class TaskProducer {
    private final RabbitTemplate rabbitTemplate;

    public void enqueue(String taskType, Object payload, int priority) {
        rabbitTemplate.convertAndSend("task-queue", payload, message -> {
            message.getMessageProperties().setPriority(priority);
            message.getMessageProperties().setHeader("taskType", taskType);
            message.getMessageProperties().setHeader("idempotencyKey",
                UUID.randomUUID().toString());
            return message;
        });
    }
}

// 태스크 처리 Worker
@Component
@RequiredArgsConstructor
public class TaskWorker {
    private final ProcessedTaskRepository processedTaskRepo;

    @RabbitListener(queues = "task-queue", concurrency = "3-10")
    public void process(Message message) {
        String idempotencyKey = message.getMessageProperties()
            .getHeader("idempotencyKey");

        // 멱등성 체크
        if (processedTaskRepo.existsById(idempotencyKey)) {
            log.info("중복 태스크 무시: {}", idempotencyKey);
            return;
        }

        try {
            String taskType = message.getMessageProperties().getHeader("taskType");
            taskHandlerRegistry.handle(taskType, message.getBody());
            processedTaskRepo.save(new ProcessedTask(idempotencyKey, Instant.now()));
        } catch (Exception e) {
            // AmqpRejectAndDontRequeueException -> DLQ로 즉시 이동
            throw new AmqpRejectAndDontRequeueException("처리 실패: " + e.getMessage());
        }
    }
}
```

---

## CRITICAL: 핵심 패턴

### 1. Priority Queue 패턴

```
우선순위 설계 기준:
  P1 (Critical) : 결제 확인, 주문 처리 (즉시 처리)
  P5 (Normal)   : 이메일 발송, 알림 (수초 이내)
  P10 (Low)     : 리포트 생성, 통계 (수분 허용)

큐 분리 vs 단일 큐 우선순위:
  큐 분리 (권장)  : critical, default, low 큐 별도 → Worker 가중치 할당
  단일 큐 우선순위 : 한 큐에 priority 필드 → 브로커가 정렬 (RabbitMQ 네이티브)
```

### 2. Exponential Backoff + Jitter

```python
# Python (Celery) - 지수 백오프 + 랜덤 지터
import random

@app.task(bind=True, max_retries=5, autoretry_for=(TransientError,))
def process_payment(self, order_id: str):
    try:
        PaymentGateway.charge(order_id)
    except TransientError as exc:
        # 지수 백오프: 2^retry * base_delay + random jitter
        backoff = (2 ** self.request.retries) * 60  # 60s, 120s, 240s, 480s, 960s
        jitter = random.uniform(0, backoff * 0.1)   # 최대 10% 지터
        raise self.retry(exc=exc, countdown=backoff + jitter)
```

### 3. Idempotency Key 패턴

```
멱등성 보장 전략:
  1. DB 기반  : processed_tasks 테이블에 idempotency_key 저장 (가장 안전)
  2. Redis 기반: SET key NX EX 86400 (TTL 24시간, 경량)
  3. asynq    : asynq.Unique(duration) 옵션 (Redis SETNX 내장)
  4. BullMQ   : jobId 지정 시 동일 ID 중복 등록 방지

주의: Redis 기반은 TTL 만료 후 중복 처리 가능 → 부작용 큰 작업은 DB 기반 권장
```

---

## Kubernetes Worker 배포

### Worker Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: task-worker
  namespace: worker
spec:
  replicas: 2
  selector:
    matchLabels:
      app: task-worker
  template:
    metadata:
      labels:
        app: task-worker
    spec:
      terminationGracePeriodSeconds: 300    # Worker가 진행 중인 태스크 완료할 시간
      containers:
        - name: worker
          image: myapp/worker:latest
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          env:
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: redis-secret
                  key: url
            - name: WORKER_CONCURRENCY
              value: "10"
          # Graceful Shutdown: SIGTERM 수신 시 진행 중 태스크 완료 후 종료
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "kill -SIGTERM 1 && sleep 30"]
```

### KEDA Queue-Length Scaler

```yaml
# Redis List 기반 스케일링 (Celery, asynq 등)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: task-worker-scaler
  namespace: worker
spec:
  scaleTargetRef:
    name: task-worker
  pollingInterval: 10                       # 10초마다 큐 길이 확인
  cooldownPeriod: 120                       # 스케일다운 대기 2분
  minReplicaCount: 1                        # 최소 1대 (0으로 하면 scale-to-zero)
  maxReplicaCount: 30                       # 최대 30대
  triggers:
    - type: redis
      metadata:
        address: redis:6379
        listName: celery                    # Celery 기본 큐 이름
        listLength: "50"                    # 큐에 50개 이상이면 스케일업
        activationListLength: "5"           # 5개 이상이면 0→1 활성화
        databaseIndex: "0"
---
# RabbitMQ 기반 스케일링 (Spring AMQP Worker)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: rabbitmq-worker-scaler
  namespace: worker
spec:
  scaleTargetRef:
    name: rabbitmq-worker
  triggers:
    - type: rabbitmq
      metadata:
        host: amqp://guest:guest@rabbitmq:5672/
        queueName: task-queue
        queueLength: "100"                  # 큐에 100개 이상이면 스케일업
        activationQueueLength: "10"
```

### Job vs Deployment 선택 기준

```
┌──────────────────────┬──────────────────┬─────────────────────┐
│ 기준                  │ Deployment       │ Job / CronJob       │
├──────────────────────┼──────────────────┼─────────────────────┤
│ 실행 주기             │ 상시 실행         │ 일회성 / 주기적      │
│ 큐 모니터링           │ 지속적 폴링       │ 외부 트리거 필요      │
│ KEDA 연동             │ ScaledObject     │ ScaledJob           │
│ 장애 복구             │ 자동 재시작       │ backoffLimit 설정    │
│ 스케일링              │ replicas 조정     │ parallelism 조정     │
│ 비용                  │ 상시 리소스 점유   │ 실행 시에만 점유      │
│ 적합한 작업           │ 이메일, 알림 등   │ 리포트, 마이그레이션  │
│                      │ 상시 처리 큐      │ 배치 데이터 처리      │
└──────────────────────┴──────────────────┴─────────────────────┘

KEDA ScaledJob 예시 (일회성 배치):
```

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: batch-report-job
  namespace: worker
spec:
  jobTargetRef:
    template:
      spec:
        containers:
          - name: report-worker
            image: myapp/report-worker:latest
        restartPolicy: OnFailure
  pollingInterval: 30
  maxReplicaCount: 10
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 3
  triggers:
    - type: redis
      metadata:
        address: redis:6379
        listName: report-tasks
        listLength: "1"                     # 태스크 1개당 Job 1개 생성
```

---

## 모니터링

### 핵심 메트릭

```
Queue Depth (큐 깊이):
  - 큐에 대기 중인 태스크 수
  - 임계값: 평시 대비 5배 이상 → 경보
  - Prometheus: redis_list_length{list="celery"} 또는 rabbitmq_queue_messages

Processing Latency (처리 지연):
  - 태스크 등록~처리 완료까지 소요 시간
  - P95 기준 SLO 설정 (예: 이메일 5초, 리포트 60초)
  - 히스토그램: task_processing_duration_seconds

Worker Utilization (Worker 활용률):
  - 활성 Worker 수 / 전체 Worker 수
  - 70% 이상 지속 → 스케일업 필요
  - Gauge: active_workers / total_workers

Failure Rate (실패율):
  - 실패 태스크 수 / 전체 처리 태스크 수
  - 5% 이상 → 경보, DLQ 확인
  - Counter: task_failures_total / task_processed_total

DLQ Size (Dead Letter 큐 크기):
  - DLQ에 적재된 메시지 수
  - 0이 아니면 즉시 확인 필요
  - Gauge: dlq_messages_count
```

### Prometheus + Grafana 알림 설정

```yaml
# Celery Exporter (prometheus-celery-exporter)
# asynq: asynqmon 내장 Prometheus 엔드포인트
# BullMQ: bull-monitor 또는 커스텀 메트릭

# PrometheusRule 알림 설정
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: task-queue-alerts
spec:
  groups:
    - name: task-queue
      rules:
        - alert: HighQueueDepth
          expr: redis_list_length{list="celery"} > 500
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "큐 깊이 500 초과 (현재: {{ $value }})"
        - alert: HighTaskFailureRate
          expr: rate(task_failures_total[5m]) / rate(task_processed_total[5m]) > 0.05
          for: 3m
          labels:
            severity: critical
          annotations:
            summary: "태스크 실패율 5% 초과"
        - alert: DLQNotEmpty
          expr: dlq_messages_count > 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "DLQ에 미처리 메시지 {{ $value }}건"
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 멱등성 미구현 | 재시도 시 중복 처리 (이중 결제 등) | Idempotency Key + DB/Redis 중복 체크 |
| 무한 재시도 | 영구 실패 태스크가 큐 점유 | max_retries 설정 + DLQ 이동 |
| 고정 재시도 간격 | 장애 서버에 부하 집중 (Thundering Herd) | Exponential Backoff + Jitter |
| ACK 먼저 전송 | Worker 장애 시 태스크 유실 | acks_late=True (처리 완료 후 ACK) |
| 큐 하나로 통합 | 저우선순위가 고우선순위 블로킹 | 우선순위별 큐 분리 + 가중치 할당 |
| Worker 타임아웃 미설정 | 행(hang) 태스크가 Worker 점유 | task timeout + visibility timeout 설정 |
| 큐 깊이 모니터링 없음 | 백프레셔 없이 메모리 초과 | KEDA 스케일링 + 큐 깊이 알림 |
| Graceful Shutdown 미구현 | 배포 시 진행 중 태스크 손실 | terminationGracePeriodSeconds + SIGTERM 처리 |
| Fat Payload 큐잉 | 브로커 메모리 과다, 처리 지연 | ID만 큐잉, 상세 데이터는 DB/S3 조회 |
| 결과 저장소 미정리 | Redis 메모리 누수 | result_expires / removeOnComplete 설정 |

---

## 체크리스트

### 설계 단계
- [ ] Task Queue vs Event Streaming 경계를 명확히 구분했는가?
- [ ] 태스크 우선순위 레벨을 정의하고 큐를 분리했는가?
- [ ] 모든 태스크에 멱등성 키(Idempotency Key)를 부여했는가?
- [ ] 태스크 타임아웃과 최대 재시도 횟수를 설정했는가?
- [ ] Dead Letter Queue 및 실패 알림을 구성했는가?

### 구현 단계
- [ ] 지수 백오프 + Jitter로 재시도 전략을 구현했는가?
- [ ] acks_late=True로 처리 완료 후 ACK를 보내는가?
- [ ] Worker의 Graceful Shutdown을 구현했는가? (SIGTERM 처리)
- [ ] 페이로드를 최소화하고 대용량 데이터는 참조만 전달하는가?
- [ ] 결과 저장소(backend)의 TTL/정리 정책을 설정했는가?

### 배포/운영 단계
- [ ] KEDA ScaledObject로 큐 깊이 기반 오토스케일링을 구성했는가?
- [ ] terminationGracePeriodSeconds를 최대 태스크 처리 시간 이상으로 설정했는가?
- [ ] Queue Depth, Processing Latency, Failure Rate 메트릭을 수집하는가?
- [ ] DLQ 모니터링 알림을 설정하고 재처리 절차를 문서화했는가?
- [ ] Job vs Deployment 중 적합한 배포 방식을 선택했는가?

---

## 참조 스킬

- `/redis-streams` - Redis Streams 기반 메시징 패턴
- `/rabbitmq` - RabbitMQ 큐 설계, Exchange/Binding 패턴
- `/k8s-autoscaling` - KEDA, HPA, VPA 오토스케일링 전략
- `/msa-event-driven` - 이벤트 드리븐 아키텍처, Kafka, Outbox 패턴
