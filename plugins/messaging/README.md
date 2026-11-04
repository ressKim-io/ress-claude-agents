<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# messaging

메시징 — Kafka, RabbitMQ, NATS, Redis Streams, AWS 메시징, 브로커 장애 진단

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install messaging@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/messaging/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)
- [`sre`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/sre/README.md)

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (12)

| 이름 | 설명 |
|---|---|
| `/messaging:aws-messaging` | AWS 메시징 서비스 가이드 — SQS, SNS, EventBridge 비교 및 구현 패턴, K8s 통합 |
| `/messaging:broker-troubleshooting` | 메시지 브로커 장애 진단 — Kafka consumer lag·partition rebalancing·ISR shrink, RabbitMQ queue depth·unacked 누적·quorum … |
| `/messaging:kafka` | Apache Kafka 가이드 — Kafka 클러스터, Strimzi Operator, 핵심 개념 |
| `/messaging:kafka-advanced` | Kafka 고급 Producer/Consumer 가이드 — Transactional API, Exactly-Once, KIP-848 리밸런싱, Offset 전략, Inbox 패턴 |
| `/messaging:kafka-connect-cdc` | Kafka Connect & CDC (Debezium) 가이드 — Source/Sink Connector, Debezium CDC, Outbox Event Router, Schema … |
| `/messaging:kafka-k8s-operations` | Kafka on Kubernetes 운영 가이드 — Strimzi+ArgoCD 통합, kind→EKS(MSK)/GKE 전환, JMX 모니터링, Schema Registry K8s 배포 |
| `/messaging:kafka-msa-patterns` | Kafka MSA 실전 패턴 — MSA에서 Kafka를 올바르게 사용하기 위한 실전 패턴. Idempotency, DLQ, Retry, Outbox, Schema Evolution |
| `/messaging:kafka-patterns` | Kafka Producer/Consumer 패턴 — Producer/Consumer 구현, KEDA 오토스케일링, 모니터링 |
| `/messaging:kafka-streams` | Kafka Streams 가이드 — KTable, GlobalKTable, Windowing, Interactive Queries, Stateful Processing, RocksDB 튜닝 |
| `/messaging:nats-messaging` | NATS 메시징 가이드 — NATS v2.10+ Core NATS, JetStream, Key-Value Store, Object Store, K8s 운영 |
| `/messaging:rabbitmq` | RabbitMQ 가이드 — RabbitMQ v4.1 Quorum Queues, AMQP 1.0, Exchange 패턴, Publisher Confirms, DLX, K8s 운영 |
| `/messaging:redis-streams` | Redis Streams 가이드 — Redis 8.x Streams 기반 메시지 스트리밍, Consumer Group, PEL 관리, K8s 배포 |
