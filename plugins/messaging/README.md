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
| `/messaging:aws-messaging` | AWS 메시징 — SQS, SNS, EventBridge 비교와 구현 패턴, K8s 통합 |
| `/messaging:broker-troubleshooting` | 메시지 브로커 장애 진단 — Kafka consumer lag·partition rebalancing·ISR shrink, RabbitMQ queue depth·unacked 누적·quorum … |
| `/messaging:kafka` | Apache Kafka 기초 — 클러스터 개념, 토픽·파티션 전략, Strimzi Operator 설치 |
| `/messaging:kafka-advanced` | Kafka 고급 Producer/Consumer — Transactional API, Exactly-Once, KIP-848 리밸런싱, offset 전략, Inbox 패턴 |
| `/messaging:kafka-connect-cdc` | Kafka Connect 와 CDC — Source/Sink Connector, Debezium, Outbox Event Router, Schema Registry, Strimzi 운영 |
| `/messaging:kafka-k8s-operations` | Kafka on Kubernetes 운영 — Strimzi·ArgoCD 통합, kind에서 EKS(MSK)/GKE 전환, JMX→Prometheus 모니터링, Schema Registry 배포 |
| `/messaging:kafka-msa-patterns` | Kafka MSA 실전 패턴 — MSA에서 Kafka를 올바르게 사용하기 위한 실전 패턴. Idempotency, DLQ, Retry, Outbox, Schema Evolution |
| `/messaging:kafka-patterns` | Kafka Producer/Consumer 기본 구현 패턴 — Producer 설정, Consumer 처리, KEDA 오토스케일링, 모니터링 |
| `/messaging:kafka-streams` | Kafka Streams — KTable, GlobalKTable, Windowing, Interactive Queries, stateful 처리, RocksDB 튜닝 |
| `/messaging:nats-messaging` | NATS 메시징 — Core NATS, JetStream, Key-Value·Object Store, subject 설계, Go 클라이언트, K8s 배포, Kafka·RabbitMQ 비교 |
| `/messaging:rabbitmq` | RabbitMQ — Quorum Queues, AMQP 1.0, Exchange 패턴, Publisher Confirms, Dead Letter Exchange, Go·Spring AMQP, … |
| `/messaging:redis-streams` | Redis Streams — Consumer Group, PEL 관리, XREADGROUP 등 핵심 명령, MAXLEN 트리밍, Go·Spring 구현, K8s 배포 |
