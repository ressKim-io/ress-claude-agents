# Redis Streams 가이드

Redis 8.x Streams 기반 메시지 스트리밍, Consumer Group, PEL 관리, K8s 배포

## Quick Reference (결정 트리)

```
메시지 스트리밍 기술 선택?
    │
    ├─ 대규모 이벤트 소싱 ──────> Kafka (파티션 기반 수평 확장)
    ├─ 경량 이벤트 큐 ──────────> Redis Streams (낮은 지연, 간단한 운영)
    ├─ 단순 Pub/Sub ───────────> Redis Pub/Sub (메시지 유실 허용)
    └─ 작업 큐 ─────────────────> Redis Streams + Consumer Group

Consumer Group 전략?
    │
    ├─ 최소 1회 처리 ──────────> XREADGROUP + XACK (at-least-once)
    ├─ 장애 복구 ───────────────> XCLAIM + PEL 모니터링
    └─ 정확히 1회 처리 ────────> XREADGROUP + 외부 idempotency (DB unique key)

Stream 트리밍?
    │
    ├─ 고정 크기 ───────────────> MAXLEN ~ N (근사 트리밍, 성능 우선)
    ├─ 시간 기반 ───────────────> MINID ~ <timestamp> (Redis 6.2+)
    └─ 수동 관리 ───────────────> XTRIM 주기적 실행
```

---

## CRITICAL: Redis Streams 아키텍처

```
┌──────────────────────────────────────────────────────────────────┐
│                    Redis Streams Architecture                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Producer ─── XADD ──────────> Stream (orders)                   │
│                                   │                               │
│                          ┌────────┴────────┐                     │
│                          │  Entry Log       │                     │
│                          │  1718000000-0    │                     │
│                          │  1718000001-0    │                     │
│                          │  1718000002-0    │                     │
│                          └────────┬────────┘                     │
│                                   │                               │
│                          ┌────────┴────────┐                     │
│                          │ Consumer Group   │                     │
│                          │ "order-workers"  │                     │
│                          │                  │                     │
│                          │ last_delivered:  │                     │
│                          │  1718000001-0    │                     │
│                          │                  │                     │
│                          │ PEL (Pending):   │                     │
│                          │  C1: [0001-0]    │                     │
│                          │  C2: [0000-0]    │                     │
│                          └────────┬────────┘                     │
│                                   │                               │
│                     ┌─────────────┼─────────────┐                │
│                     │             │             │                │
│                   [C1]          [C2]          [C3]               │
│                 XREADGROUP    XREADGROUP    XREADGROUP           │
│                   + XACK       + XACK        + XACK             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

핵심 포인트:
- Stream = append-only log (Kafka의 partition과 유사)
- Consumer Group = 메시지를 분산 전달 (각 메시지는 그룹 내 1명만 수신)
- PEL = 전달되었으나 ACK 되지 않은 메시지 목록
- Entry ID = <밀리초 타임스탬프>-<시퀀스> (자동 생성)
```

### Redis Streams vs Kafka 비교

| 항목 | Redis Streams | Kafka |
|------|--------------|-------|
| **아키텍처** | 단일/클러스터 인메모리 | 분산 브로커 클러스터 |
| **지연시간** | sub-ms ~ 수 ms | 수 ms ~ 수십 ms |
| **처리량** | 수십만 msg/s (단일 노드) | 수백만 msg/s (클러스터) |
| **내구성** | AOF/RDB (메모리 제약) | 디스크 기반 (무제한 보존) |
| **Consumer Group** | XREADGROUP (단일 Stream) | Partition 기반 병렬 처리 |
| **파티셔닝** | 수동 (여러 Stream key) | 네이티브 파티션 지원 |
| **메시지 보존** | MAXLEN/MINID 트리밍 | retention.ms 기반 |
| **Exactly-once** | 외부 구현 필요 | 트랜잭션 네이티브 지원 |
| **운영 복잡도** | 낮음 | 높음 (ZooKeeper/KRaft) |
| **적합 시나리오** | 경량 이벤트, 실시간 알림 | 대규모 이벤트 소싱, 로그 |

---

## CRITICAL: Consumer Group 핵심 명령어

```
┌──────────────────────────────────────────────────────┐
│             Consumer Group Lifecycle                  │
├──────────────────────────────────────────────────────┤
│                                                       │
│  1. XGROUP CREATE stream group $ MKSTREAM             │
│     └─ 그룹 생성 ($ = 신규 메시지만, 0 = 처음부터)    │
│                                                       │
│  2. XADD stream * field value                         │
│     └─ 메시지 발행 (* = 자동 ID)                      │
│                                                       │
│  3. XREADGROUP GROUP group consumer COUNT n           │
│     BLOCK ms STREAMS stream >                         │
│     └─ 신규 메시지 읽기 (> = 새 메시지만)              │
│                                                       │
│  4. XACK stream group id                              │
│     └─ 처리 완료 확인 (PEL에서 제거)                   │
│                                                       │
│  5. XPENDING stream group - + count                   │
│     └─ 미확인 메시지 조회                              │
│                                                       │
│  6. XCLAIM stream group consumer min-idle-time id     │
│     └─ 타임아웃된 메시지를 다른 Consumer에게 재할당    │
│                                                       │
│  7. XAUTOCLAIM stream group consumer min-idle-time    │
│     start COUNT n                                     │
│     └─ 자동으로 유휴 메시지 클레임 (Redis 6.2+)       │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### PEL (Pending Entry List) 관리 전략

```
PEL 상태 확인:
    │
    ├─ XPENDING stream group
    │   └─ 요약: 총 pending 수, min/max ID, Consumer별 개수
    │
    ├─ XPENDING stream group - + 10
    │   └─ 상세: 각 메시지 ID, Consumer, idle time, 전달 횟수
    │
    └─ 장애 복구 흐름:
        │
        ├─ idle time > 임계값 ──> XCLAIM으로 재할당
        ├─ 전달 횟수 > 3회 ────> Dead Letter Stream으로 이동
        └─ Consumer 사망 ──────> XAUTOCLAIM으로 자동 복구
```

---

## Go 구현 (go-redis v9)

### Producer

```go
package stream

import (
    "context"
    "fmt"
    "time"

    "github.com/redis/go-redis/v9"
)

type StreamProducer struct {
    client     *redis.Client
    streamKey  string
    maxLen     int64
}

func NewStreamProducer(client *redis.Client, streamKey string, maxLen int64) *StreamProducer {
    return &StreamProducer{
        client:    client,
        streamKey: streamKey,
        maxLen:    maxLen,
    }
}

// Publish는 메시지를 Stream에 추가하고 Entry ID를 반환한다.
// MAXLEN ~ (근사 트리밍)을 사용하여 성능 영향을 최소화한다.
func (p *StreamProducer) Publish(ctx context.Context, fields map[string]interface{}) (string, error) {
    id, err := p.client.XAdd(ctx, &redis.XAddArgs{
        Stream: p.streamKey,
        MaxLen: p.maxLen,
        Approx: true,  // ~ 연산자: 정확한 길이 대신 근사값으로 성능 최적화
        ID:     "*",    // 자동 ID 생성
        Values: fields,
    }).Result()
    if err != nil {
        return "", fmt.Errorf("XADD 실패 stream=%s: %w", p.streamKey, err)
    }
    return id, nil
}

// PublishOrder는 주문 이벤트를 발행하는 헬퍼 메서드이다.
func (p *StreamProducer) PublishOrder(ctx context.Context, orderID, action, payload string) (string, error) {
    return p.Publish(ctx, map[string]interface{}{
        "order_id": orderID,
        "action":   action,
        "payload":  payload,
        "ts":       time.Now().UnixMilli(),
    })
}
```

### Consumer (Consumer Group)

```go
package stream

import (
    "context"
    "fmt"
    "log/slog"
    "time"

    "github.com/redis/go-redis/v9"
)

type MessageHandler func(ctx context.Context, msg redis.XMessage) error

type StreamConsumer struct {
    client       *redis.Client
    streamKey    string
    groupName    string
    consumerName string
    handler      MessageHandler
    batchSize    int64
    blockTime    time.Duration
    claimMinIdle time.Duration
    maxRetries   int
    dlqStream    string  // Dead Letter Queue Stream
}

type ConsumerConfig struct {
    StreamKey    string
    GroupName    string
    ConsumerName string
    BatchSize    int64
    BlockTime    time.Duration
    ClaimMinIdle time.Duration
    MaxRetries   int
    DLQStream    string
}

func NewStreamConsumer(client *redis.Client, cfg ConsumerConfig, handler MessageHandler) *StreamConsumer {
    if cfg.BatchSize == 0 {
        cfg.BatchSize = 10
    }
    if cfg.BlockTime == 0 {
        cfg.BlockTime = 5 * time.Second
    }
    if cfg.ClaimMinIdle == 0 {
        cfg.ClaimMinIdle = 30 * time.Second
    }
    if cfg.MaxRetries == 0 {
        cfg.MaxRetries = 3
    }
    if cfg.DLQStream == "" {
        cfg.DLQStream = cfg.StreamKey + ":dlq"
    }
    return &StreamConsumer{
        client:       client,
        streamKey:    cfg.StreamKey,
        groupName:    cfg.GroupName,
        consumerName: cfg.ConsumerName,
        handler:      handler,
        batchSize:    cfg.BatchSize,
        blockTime:    cfg.BlockTime,
        claimMinIdle: cfg.ClaimMinIdle,
        maxRetries:   cfg.MaxRetries,
        dlqStream:    cfg.DLQStream,
    }
}

// EnsureGroup은 Consumer Group이 없으면 생성한다.
func (c *StreamConsumer) EnsureGroup(ctx context.Context) error {
    err := c.client.XGroupCreateMkStream(ctx, c.streamKey, c.groupName, "0").Err()
    if err != nil && err.Error() != "BUSYGROUP Consumer Group name already exists" {
        return fmt.Errorf("그룹 생성 실패: %w", err)
    }
    return nil
}

// Run은 메시지 소비 루프를 시작한다. ctx 취소 시 graceful하게 종료된다.
func (c *StreamConsumer) Run(ctx context.Context) error {
    if err := c.EnsureGroup(ctx); err != nil {
        return err
    }

    slog.Info("Consumer 시작", "stream", c.streamKey, "group", c.groupName, "consumer", c.consumerName)

    // 1단계: 이전에 전달되었으나 ACK 안 된 메시지 재처리
    if err := c.processPending(ctx); err != nil {
        slog.Warn("Pending 메시지 처리 실패", "error", err)
    }

    // 2단계: 신규 메시지 소비 루프
    for {
        select {
        case <-ctx.Done():
            slog.Info("Consumer 종료", "consumer", c.consumerName)
            return ctx.Err()
        default:
        }

        streams, err := c.client.XReadGroup(ctx, &redis.XReadGroupArgs{
            Group:    c.groupName,
            Consumer: c.consumerName,
            Streams:  []string{c.streamKey, ">"},  // ">" = 신규 메시지만
            Count:    c.batchSize,
            Block:    c.blockTime,
        }).Result()
        if err != nil {
            if err == redis.Nil {
                continue  // 타임아웃, 메시지 없음
            }
            slog.Error("XREADGROUP 실패", "error", err)
            time.Sleep(time.Second)
            continue
        }

        for _, stream := range streams {
            for _, msg := range stream.Messages {
                if err := c.processMessage(ctx, msg); err != nil {
                    slog.Error("메시지 처리 실패", "id", msg.ID, "error", err)
                    // ACK하지 않음 → PEL에 남아 재처리 대상
                    continue
                }
                // 처리 성공 시 ACK
                c.client.XAck(ctx, c.streamKey, c.groupName, msg.ID)
            }
        }
    }
}

// processPending은 재시작 시 미처리 메시지를 복구한다.
func (c *StreamConsumer) processPending(ctx context.Context) error {
    for {
        pending, err := c.client.XPendingExt(ctx, &redis.XPendingExtArgs{
            Stream: c.streamKey,
            Group:  c.groupName,
            Start:  "-",
            End:    "+",
            Count:  c.batchSize,
        }).Result()
        if err != nil || len(pending) == 0 {
            return err
        }

        for _, p := range pending {
            // 재시도 횟수 초과 시 DLQ로 이동
            if int(p.RetryCount) > c.maxRetries {
                c.moveToDLQ(ctx, p.ID)
                c.client.XAck(ctx, c.streamKey, c.groupName, p.ID)
                continue
            }

            // XCLAIM으로 메시지 소유권 가져오기
            msgs, err := c.client.XClaim(ctx, &redis.XClaimArgs{
                Stream:   c.streamKey,
                Group:    c.groupName,
                Consumer: c.consumerName,
                MinIdle:  c.claimMinIdle,
                Messages: []string{p.ID},
            }).Result()
            if err != nil || len(msgs) == 0 {
                continue
            }

            if err := c.processMessage(ctx, msgs[0]); err != nil {
                slog.Warn("Pending 메시지 재처리 실패", "id", p.ID, "retry", p.RetryCount)
                continue
            }
            c.client.XAck(ctx, c.streamKey, c.groupName, p.ID)
        }

        if len(pending) < int(c.batchSize) {
            break
        }
    }
    return nil
}

// moveToDLQ는 재시도 초과 메시지를 Dead Letter Stream으로 이동한다.
func (c *StreamConsumer) moveToDLQ(ctx context.Context, msgID string) {
    msgs, err := c.client.XRangeN(ctx, c.streamKey, msgID, msgID, 1).Result()
    if err != nil || len(msgs) == 0 {
        return
    }
    msgs[0].Values["original_stream"] = c.streamKey
    msgs[0].Values["original_id"] = msgID
    msgs[0].Values["failed_at"] = time.Now().UnixMilli()

    c.client.XAdd(ctx, &redis.XAddArgs{
        Stream: c.dlqStream,
        MaxLen: 10000,
        Approx: true,
        ID:     "*",
        Values: msgs[0].Values,
    })
    slog.Warn("DLQ 이동", "stream", c.dlqStream, "original_id", msgID)
}

func (c *StreamConsumer) processMessage(ctx context.Context, msg redis.XMessage) error {
    return c.handler(ctx, msg)
}
```

### 사용 예시

```go
func main() {
    rdb := redis.NewClient(&redis.Options{
        Addr:         "redis-master:6379",
        Password:     os.Getenv("REDIS_PASSWORD"),
        DB:           0,
        PoolSize:     10,
        MinIdleConns: 5,
    })

    ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer cancel()

    // Producer
    producer := stream.NewStreamProducer(rdb, "orders", 100000)
    id, _ := producer.PublishOrder(ctx, "ord-123", "created", `{"item":"widget","qty":5}`)
    slog.Info("발행 완료", "id", id)

    // Consumer
    consumer := stream.NewStreamConsumer(rdb, stream.ConsumerConfig{
        StreamKey:    "orders",
        GroupName:    "order-workers",
        ConsumerName: "worker-" + os.Getenv("HOSTNAME"),
        BatchSize:    10,
        BlockTime:    5 * time.Second,
        ClaimMinIdle: 30 * time.Second,
        MaxRetries:   3,
    }, func(ctx context.Context, msg redis.XMessage) error {
        slog.Info("주문 처리", "id", msg.ID, "order_id", msg.Values["order_id"])
        // 비즈니스 로직 처리
        return nil
    })

    consumer.Run(ctx)
}
```

---

## Spring Data Redis 구현

### 의존성

```groovy
implementation 'org.springframework.boot:spring-boot-starter-data-redis'
implementation 'io.lettuce:lettuce-core'  // 기본 Redis 클라이언트
```

### StreamListener 구현

```java
@Configuration
public class RedisStreamConfig {

    @Value("${stream.key:orders}")
    private String streamKey;

    @Value("${stream.group:order-workers}")
    private String groupName;

    @Bean
    public RedisTemplate<String, String> redisTemplate(RedisConnectionFactory factory) {
        RedisTemplate<String, String> template = new RedisTemplate<>();
        template.setConnectionFactory(factory);
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(new StringRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(new StringRedisSerializer());
        return template;
    }

    @Bean
    public Subscription orderStreamSubscription(
            RedisConnectionFactory factory,
            OrderStreamListener listener) {

        // Consumer Group 생성 (없으면)
        try {
            StreamOperations<String, Object, Object> ops =
                redisTemplate(factory).opsForStream();
            ops.createGroup(streamKey, ReadOffset.from("0"), groupName);
        } catch (Exception e) {
            // 이미 존재하면 무시
        }

        String consumerName = "consumer-" + UUID.randomUUID().toString().substring(0, 8);

        StreamMessageListenerContainer.StreamMessageListenerContainerOptions<String,
            MapRecord<String, String, String>> options =
            StreamMessageListenerContainer.StreamMessageListenerContainerOptions.builder()
                .pollTimeout(Duration.ofSeconds(2))
                .batchSize(10)
                .targetType(String.class)
                .build();

        StreamMessageListenerContainer<String, MapRecord<String, String, String>> container =
            StreamMessageListenerContainer.create(factory, options);

        Subscription subscription = container.receive(
            Consumer.from(groupName, consumerName),
            StreamOffset.create(streamKey, ReadOffset.lastConsumed()),
            listener
        );

        container.start();
        return subscription;
    }
}

@Component
@Slf4j
public class OrderStreamListener
        implements StreamListener<String, MapRecord<String, String, String>> {

    private final StringRedisTemplate redisTemplate;

    @Value("${stream.key:orders}")
    private String streamKey;

    @Value("${stream.group:order-workers}")
    private String groupName;

    public OrderStreamListener(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Override
    public void onMessage(MapRecord<String, String, String> message) {
        try {
            String orderId = message.getValue().get("order_id");
            String action = message.getValue().get("action");
            log.info("주문 수신: id={}, orderId={}, action={}", message.getId(), orderId, action);

            // 비즈니스 로직 처리
            processOrder(orderId, action, message.getValue());

            // ACK 전송
            redisTemplate.opsForStream().acknowledge(streamKey, groupName, message.getId());
            log.debug("ACK 완료: {}", message.getId());

        } catch (Exception e) {
            log.error("메시지 처리 실패: id={}", message.getId(), e);
            // ACK 하지 않으면 PEL에 남아 재처리 대상
        }
    }

    private void processOrder(String orderId, String action, Map<String, String> data) {
        // 주문 처리 비즈니스 로직
    }
}
```

### Producer (Spring)

```java
@Service
@RequiredArgsConstructor
public class OrderStreamProducer {

    private final StringRedisTemplate redisTemplate;

    @Value("${stream.key:orders}")
    private String streamKey;

    @Value("${stream.maxlen:100000}")
    private long maxLen;

    public RecordId publish(String orderId, String action, String payload) {
        Map<String, String> fields = Map.of(
            "order_id", orderId,
            "action", action,
            "payload", payload,
            "ts", String.valueOf(System.currentTimeMillis())
        );

        StringRecord record = StreamRecords.string(fields).withStreamKey(streamKey);

        RecordId recordId = redisTemplate.opsForStream().add(record);
        log.info("발행 완료: recordId={}, orderId={}", recordId, orderId);
        return recordId;
    }
}
```

---

## K8s 배포

### Redis Operator (Bitnami Helm Chart)

```bash
# Bitnami Redis Helm 설치 (Sentinel HA 구성)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis bitnami/redis \
  --namespace redis --create-namespace \
  --set architecture=replication \
  --set replica.replicaCount=3 \
  --set sentinel.enabled=true \
  --set sentinel.quorum=2 \
  --set master.persistence.size=10Gi \
  --set master.persistence.storageClass=gp3 \
  --set master.resources.requests.memory=1Gi \
  --set master.resources.requests.cpu=500m \
  --set auth.password=<REDIS_PASSWORD>
```

### Redis Operator (OpsTree) CRD

```yaml
# OpsTree Redis Operator 사용 시
apiVersion: redis.redis.opstreelabs.in/v1beta2
kind: RedisReplication
metadata:
  name: redis-streams
  namespace: redis
spec:
  clusterSize: 3
  kubernetesConfig:
    image: redis:8.0-alpine
    imagePullPolicy: IfNotPresent
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: "1"
        memory: 2Gi
  storage:
    volumeClaimTemplate:
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: gp3
        resources:
          requests:
            storage: 10Gi
  redisConfig:
    additionalRedisConfig: |
      maxmemory 1gb
      maxmemory-policy noeviction
      stream-node-max-bytes 4096
      stream-node-max-entries 100
```

### Consumer Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-stream-consumer
  namespace: default
spec:
  replicas: 1  # KEDA가 관리
  selector:
    matchLabels:
      app: order-stream-consumer
  template:
    metadata:
      labels:
        app: order-stream-consumer
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: consumer
          image: order-stream-consumer:latest
          env:
            - name: REDIS_ADDR
              value: "redis-streams-master.redis:6379"
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: redis-streams-secret
                  key: password
            - name: STREAM_KEY
              value: "orders"
            - name: GROUP_NAME
              value: "order-workers"
            - name: CONSUMER_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name  # Pod 이름을 Consumer 이름으로
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
```

### KEDA Redis Streams Scaler

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-stream-consumer-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: order-stream-consumer
  pollingInterval: 15
  cooldownPeriod: 30
  minReplicaCount: 1
  maxReplicaCount: 10
  advanced:
    restoreToOriginalReplicaCount: true
  triggers:
    - type: redis-streams
      metadata:
        # Redis 연결 정보
        addressFromEnv: REDIS_ADDR
        passwordFromEnv: REDIS_PASSWORD
        # Stream 설정
        stream: orders
        consumerGroup: order-workers
        # PEL 기반 스케일링: pending 메시지 수 기준
        pendingEntriesCount: "50"  # pending > 50이면 스케일업
        enableTLS: "false"
        databaseIndex: "0"
---
# TriggerAuthentication (비밀번호를 Secret에서 참조)
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: redis-stream-auth
  namespace: default
spec:
  secretTargetRef:
    - parameter: password
      name: redis-streams-secret
      key: password
```

---

## MAXLEN 트리밍 전략

```
XADD 시 트리밍 (권장):
    │
    ├─ XADD stream MAXLEN ~ 100000 * field value
    │   └─ 근사 트리밍: ~를 사용하면 radix tree 노드 단위로 정리
    │      실제 길이가 정확히 100000이 아닐 수 있지만 성능이 좋음
    │
    ├─ XADD stream MAXLEN 100000 * field value
    │   └─ 정확한 트리밍: 정확히 100000개 유지, 성능 영향 있음
    │
    └─ XADD stream MINID ~ 1718000000000-0 * field value
        └─ 시간 기반 트리밍: 특정 타임스탬프 이전 메시지 제거 (Redis 6.2+)

주기적 트리밍 (CronJob):
    XTRIM stream MAXLEN ~ 100000
    XTRIM stream MINID ~ <24시간 전 타임스탬프>
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| XREAD만 사용 | Consumer Group 없이 모든 Consumer가 전체 메시지 수신 | XREADGROUP 사용 |
| XACK 누락 | PEL 무한 증가, 메모리 누수 | 처리 후 반드시 XACK |
| MAXLEN 미설정 | Stream 크기 무한 증가, OOM | XADD 시 MAXLEN ~ N |
| BLOCK 0 사용 | 영구 블로킹, graceful shutdown 불가 | BLOCK 2000~5000ms |
| Consumer 이름 고정 | 여러 Pod가 같은 이름으로 충돌 | Pod 이름/UUID 사용 |
| PEL 모니터링 안 함 | 장애 Consumer의 메시지 방치 | XCLAIM/XAUTOCLAIM 주기 실행 |
| DLQ 없음 | 무한 재시도로 리소스 낭비 | 재시도 초과 시 DLQ 이동 |
| noeviction 미설정 | maxmemory 도달 시 Stream 데이터 삭제 | maxmemory-policy noeviction |
| 큰 메시지 저장 | Redis 메모리 낭비 | 메시지에 참조 ID만, 본문은 외부 저장 |

---

## 체크리스트

### Stream 설정
- [ ] MAXLEN 또는 MINID 트리밍 설정
- [ ] maxmemory-policy noeviction 설정
- [ ] stream-node-max-bytes / stream-node-max-entries 튜닝
- [ ] 메시지 크기 최소화 (참조 패턴)

### Consumer Group
- [ ] XGROUP CREATE MKSTREAM으로 그룹 생성
- [ ] Consumer 이름에 Pod 이름 또는 UUID 사용
- [ ] XREADGROUP + XACK 쌍으로 at-least-once 보장
- [ ] 시작 시 pending 메시지 먼저 처리

### PEL / 장애 복구
- [ ] XPENDING으로 미처리 메시지 모니터링
- [ ] XCLAIM 또는 XAUTOCLAIM으로 장애 복구
- [ ] 재시도 횟수 초과 시 DLQ로 이동
- [ ] DLQ 모니터링 및 알림

### K8s 배포
- [ ] Redis Sentinel 또는 Replication 구성 (HA)
- [ ] KEDA redis-streams scaler 설정
- [ ] pendingEntriesCount 임계값 적절히 설정
- [ ] terminationGracePeriodSeconds 설정 (graceful shutdown)
- [ ] Redis 비밀번호 Secret으로 관리

### 모니터링
- [ ] PEL 크기 메트릭 수집
- [ ] Stream 길이 메트릭 수집
- [ ] Consumer lag 알림 설정
- [ ] DLQ 크기 알림 설정

**관련 skill**: `/kafka` (대규모 이벤트 스트리밍), `/kafka-patterns` (Producer/Consumer 패턴, KEDA), `/distributed-lock` (Redis 분산 락)
