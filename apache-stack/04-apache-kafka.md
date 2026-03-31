# Apache Kafka

## Overview

Apache Kafka is a distributed event streaming platform. It acts as the central nervous system of a modern data architecture — a highly durable, high-throughput message bus that decouples event producers from consumers.

Kafka is not a database and not a message queue in the traditional sense. It is a **distributed log** — an append-only, ordered, replayable record of events.

---

## 1. Core Concepts

### The Fundamental Model

```
Producers               Kafka Cluster               Consumers
(data sources)          (distributed log)           (data processors)

App Server ──┐                                  ┌── Flink Job
Mobile App ──┤──► Topic: "user_events" ─────────┤── Spark Streaming
IoT Sensor ──┤                                  ├── Elasticsearch
CDC feed  ───┘                                  └── Data Warehouse
```

### Topics, Partitions, and Offsets

```
Topic: "orders"
┌─────────────────────────────────────────────────────────────┐
│  Partition 0:  [msg0] [msg1] [msg4] [msg7] [msg9]           │
│                   0      1      2      3      4  ← offset   │
│                                                             │
│  Partition 1:  [msg2] [msg3] [msg6] [msg8]                 │
│                   0      1      2      3  ← offset          │
│                                                             │
│  Partition 2:  [msg5] [msg10] [msg11]                       │
│                   0       1       2   ← offset              │
└─────────────────────────────────────────────────────────────┘
```

| Concept | Definition |
|---------|-----------|
| **Topic** | A named, ordered log of events. Like a table in a database, but append-only. |
| **Partition** | A topic is split into N partitions for parallelism and scalability. |
| **Offset** | A sequential integer identifying each message within a partition. Never reused. |
| **Broker** | A single Kafka server. A cluster has 3–100+ brokers. |
| **Replication Factor** | Each partition is replicated across N brokers (default: 3). |
| **Leader/Follower** | One broker is the leader for a partition (handles reads/writes); others are followers (replicas). |
| **Retention** | Kafka keeps messages for a configurable time (default: 7 days) regardless of consumption. |

### Why Kafka is Different from Traditional Message Queues

| Feature | Traditional Queue (RabbitMQ, SQS) | Kafka |
|---------|----------------------------------|-------|
| Message deletion | Deleted after consumer acknowledges | Retained for configured period (days/weeks) |
| Replay | Not possible once consumed | Any consumer can re-read from any offset |
| Multiple consumers | Fan-out copies required | Multiple consumer groups read independently |
| Ordering | Per-queue | Guaranteed within a partition |
| Scale (msg/sec) | Thousands–tens of thousands | Millions+ |
| Durability | In-memory (often) | Disk-based, replicated |

---

## 2. Producer API

```python
from kafka import KafkaProducer
import json
import time

# Create a producer
producer = KafkaProducer(
    bootstrap_servers=["kafka-broker1:9092", "kafka-broker2:9092"],
    key_serializer=lambda k: k.encode("utf-8") if k else None,
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    acks="all",             # Wait for all replicas (strongest durability)
    retries=5,
    max_in_flight_requests_per_connection=1,  # Enable idempotent producer
    compression_type="lz4" # Compress messages (gzip, snappy, lz4, zstd)
)

# Send a message (async by default)
event = {
    "order_id":   "ORD-12345",
    "customer_id": "CUST-789",
    "amount":     149.99,
    "event_time": "2024-03-15T10:30:00Z"
}

# Key determines partition — use customer_id so all events for one customer
# go to the same partition (guarantees order per customer)
producer.send(
    topic="orders",
    key="CUST-789",
    value=event
)

# Send with callback for confirmation
def on_send_success(record_metadata):
    print(f"Sent to {record_metadata.topic}[{record_metadata.partition}] "
          f"offset={record_metadata.offset}")

def on_send_error(exc):
    print(f"Failed to send: {exc}")

producer.send("orders", key="CUST-789", value=event) \
    .add_callback(on_send_success) \
    .add_errback(on_send_error)

# Flush all pending messages before exiting
producer.flush()
producer.close()
```

### Producer Acks and Durability

```
acks=0:   Fire and forget. No confirmation. Fastest, may lose messages.
acks=1:   Leader confirms receipt. Fast. Messages lost if leader fails before replicating.
acks=all: All in-sync replicas confirm. Slowest. No data loss. Use for financial/critical data.
```

### Partitioning Strategy

```python
# Default: hash(key) % num_partitions
# Explicit: implement a custom partitioner

class RegionPartitioner:
    """Route messages to partitions by region."""
    REGIONS = {"north": 0, "south": 1, "east": 2, "west": 3}

    def __call__(self, key_bytes: bytes, all_partitions: list, available_partitions: list) -> int:
        region = key_bytes.decode("utf-8").split(":")[0]  # e.g., "north:CUST-123"
        return self.REGIONS.get(region, 0)

producer = KafkaProducer(
    bootstrap_servers=["kafka-broker:9092"],
    partitioner=RegionPartitioner()
)
```

---

## 3. Consumer API

### Basic Consumer

```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    "orders",                                    # topics to subscribe to
    bootstrap_servers=["kafka-broker:9092"],
    group_id="order-processor-v1",              # consumer group ID
    auto_offset_reset="earliest",               # start from beginning if no committed offset
    enable_auto_commit=False,                   # manual commit for control
    key_deserializer=lambda k: k.decode("utf-8") if k else None,
    value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    max_poll_records=500,
    session_timeout_ms=30_000
)

# Poll loop
try:
    for message in consumer:
        # message has: topic, partition, offset, key, value, timestamp
        order = message.value
        print(f"Processing order {order['order_id']} "
              f"from partition {message.partition} "
              f"at offset {message.offset}")

        # Process the event
        process_order(order)

        # Manually commit offset after successful processing
        consumer.commit()
finally:
    consumer.close()
```

### Consumer Groups and Partition Assignment

```
Topic "orders" with 6 partitions:

Consumer Group "analytics":
  Consumer 1 ← [Partition 0, Partition 1]
  Consumer 2 ← [Partition 2, Partition 3]
  Consumer 3 ← [Partition 4, Partition 5]

Consumer Group "ml-pipeline":         (reads independently, from its own offsets)
  Consumer A ← [Partition 0, Partition 1, Partition 2]
  Consumer B ← [Partition 3, Partition 4, Partition 5]
```

**Key rules:**
- Each partition is assigned to exactly ONE consumer within a group
- Number of active consumers in a group ≤ number of partitions
- Multiple consumer groups are completely independent
- When a consumer joins or leaves, Kafka **rebalances** partition assignments

### Seeking to Specific Offsets

```python
from kafka import TopicPartition

# Manually assign partitions and seek to specific offsets (no rebalancing)
tp0 = TopicPartition("orders", 0)
tp1 = TopicPartition("orders", 1)

consumer.assign([tp0, tp1])

# Seek to a specific offset (replay from offset 1000)
consumer.seek(tp0, 1000)
consumer.seek(tp1, 0)

# Seek to the beginning or end
consumer.seek_to_beginning(tp0)
consumer.seek_to_end(tp1)
```

---

## 4. Kafka Topics — Administration

### CLI Commands

```bash
# Create a topic
kafka-topics.sh --bootstrap-server localhost:9092 \
  --create \
  --topic orders \
  --partitions 12 \
  --replication-factor 3 \
  --config retention.ms=604800000   # 7 days in ms

# List all topics
kafka-topics.sh --bootstrap-server localhost:9092 --list

# Describe a topic (partitions, leader, replicas, ISR)
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic orders

# Alter retention
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter \
  --entity-type topics \
  --entity-name orders \
  --add-config retention.ms=2592000000  # 30 days

# Delete a topic
kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic orders

# Monitor consumer group lag
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group order-processor-v1

# Reset consumer group offsets (replay from beginning)
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group order-processor-v1 \
  --topic orders \
  --reset-offsets \
  --to-earliest \
  --execute
```

### Key Topic Configuration

| Config | Description | Typical Value |
|--------|-------------|---------------|
| `num.partitions` | Parallelism level | Match your peak consumer count |
| `replication.factor` | Fault tolerance | 3 (minimum for production) |
| `retention.ms` | How long to keep messages | 7–30 days |
| `retention.bytes` | Max topic size (per partition) | Unlimited for event logs |
| `min.insync.replicas` | Min replicas that must ack writes | 2 (use with `acks=all`) |
| `compression.type` | Broker-side compression | `lz4` (speed) or `zstd` (ratio) |
| `cleanup.policy` | `delete` (TTL) or `compact` (latest-per-key) | `delete` for events, `compact` for state |

---

## 5. Kafka Connect — No-Code Integrations

Kafka Connect is a framework for streaming data between Kafka and external systems without writing producer/consumer code.

```
Database     ──[JDBC Source Connector]──►  Kafka  ──[S3 Sink Connector]──► S3
Postgres         (CDC via Debezium)                                       (Parquet files)

MySQL        ──[Debezium CDC Connector]──► Kafka  ──[HDFS Sink]──────────► HDFS

Kafka        ──[BigQuery Sink]──────────────────────────────────────────► BigQuery
```

### Example: Debezium CDC (Change Data Capture from Postgres)

```json
// POST to Kafka Connect REST API: http://connect:8083/connectors
{
  "name": "postgres-orders-cdc",
  "config": {
    "connector.class":              "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname":            "postgres-host",
    "database.port":                "5432",
    "database.user":                "debezium",
    "database.password":            "secret",
    "database.dbname":              "sales_db",
    "database.server.name":         "sales",
    "table.include.list":           "public.orders,public.customers",
    "plugin.name":                  "pgoutput",
    "topic.prefix":                 "cdc",
    "slot.name":                    "debezium_slot",
    "publication.name":             "debezium_pub",
    "include.schema.changes":       "true"
  }
}
```

This creates Kafka topics `cdc.public.orders` and `cdc.public.customers` that stream every INSERT/UPDATE/DELETE from Postgres in real time.

### Example: S3 Sink Connector

```json
{
  "name": "orders-to-s3",
  "config": {
    "connector.class":           "io.confluent.connect.s3.S3SinkConnector",
    "tasks.max":                 "8",
    "topics":                    "orders",
    "s3.region":                 "us-east-1",
    "s3.bucket.name":            "my-data-lake",
    "s3.part.size":              "67108864",
    "flush.size":                "10000",
    "storage.class":             "io.confluent.connect.s3.storage.S3Storage",
    "format.class":              "io.confluent.connect.s3.format.parquet.ParquetFormat",
    "schema.compatibility":      "FULL",
    "partitioner.class":         "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
    "path.format":               "'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH",
    "locale":                    "en_US",
    "timezone":                  "UTC",
    "timestamp.extractor":       "RecordField",
    "timestamp.field":           "order_time"
  }
}
```

```bash
# Check connector status
curl http://connect:8083/connectors/postgres-orders-cdc/status

# List all connectors
curl http://connect:8083/connectors

# Pause / resume
curl -X PUT http://connect:8083/connectors/orders-to-s3/pause
curl -X PUT http://connect:8083/connectors/orders-to-s3/resume
```

---

## 6. Schema Registry

When producers and consumers evolve independently, schemas can break. The Schema Registry centrally manages Avro/Protobuf/JSON schemas and enforces compatibility.

```python
from confluent_kafka import Producer, Consumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer, AvroDeserializer

# Avro schema for orders
order_schema_str = json.dumps({
    "type": "record",
    "name": "Order",
    "namespace": "com.company.sales",
    "fields": [
        {"name": "order_id",     "type": "string"},
        {"name": "customer_id",  "type": "string"},
        {"name": "amount",       "type": "double"},
        {"name": "order_time",   "type": "string"}
    ]
})

schema_registry_client = SchemaRegistryClient({"url": "http://schema-registry:8081"})

# Producer with schema serialization
avro_serializer = AvroSerializer(schema_registry_client, order_schema_str)

producer = Producer({
    "bootstrap.servers": "kafka-broker:9092"
})

def delivery_report(err, msg):
    if err is not None:
        print(f"Delivery failed: {err}")

producer.produce(
    topic="orders",
    key="CUST-789",
    value=avro_serializer(
        {"order_id": "ORD-123", "customer_id": "CUST-789",
         "amount": 99.99, "order_time": "2024-03-15T10:00:00Z"},
        SerializationContext("orders", MessageField.VALUE)
    ),
    on_delivery=delivery_report
)
producer.flush()
```

**Schema compatibility levels:**
- `BACKWARD`: New schema can read old messages
- `FORWARD`: Old schema can read new messages
- `FULL`: Both directions compatible (recommended)
- `NONE`: No compatibility check

---

## 7. Kafka Streams (Stream Processing Inside Kafka)

Kafka Streams is a client library for building stream processing applications that run inside your service — no external cluster needed.

```java
// Kafka Streams DSL — Java
StreamsBuilder builder = new StreamsBuilder();

// Read from "orders" topic
KStream<String, Order> orders = builder.stream(
    "orders",
    Consumed.with(Serdes.String(), orderSerde)
);

// Filter, transform, and aggregate
KTable<Windowed<String>, Long> revenueTable = orders
    .filter((customerId, order) -> order.getAmount() > 0)
    .groupByKey()
    .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5)))
    .aggregate(
        () -> 0L,
        (customerId, order, accumulator) -> accumulator + (long) order.getAmount(),
        Materialized.with(Serdes.String(), Serdes.Long())
    );

// Write to output topic
revenueTable.toStream()
    .map((windowedKey, revenue) -> KeyValue.pair(
        windowedKey.key(),
        new RevenueEvent(windowedKey.key(), revenue, windowedKey.window())
    ))
    .to("customer-revenue", Produced.with(Serdes.String(), revenueSerde));

KafkaStreams streams = new KafkaStreams(builder.build(), config);
streams.start();
```

**Kafka Streams vs Flink/Spark Streaming:**
- Kafka Streams: embedded in your app, no cluster, limited scale (single JVM)
- Flink/Spark: separate cluster, scales to thousands of nodes, richer operations

Use Kafka Streams for lightweight, low-complexity transformations inside a microservice. Use Flink/Spark for complex analytics with external state and large-scale processing.

---

## 8. Complete Architecture Pattern

```
┌─────────────────────────────────────────────────────────────────────┐
│                  Production Event Streaming Pipeline                 │
│                                                                      │
│  Sources:                                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │  Web App │  │  Mobile  │  │ Postgres │  │   IoT    │           │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘           │
│       │              │              │              │                  │
│       └──────────────┴──────────────┴──────────────┘                │
│                              │                                        │
│                              ▼                                        │
│                    ┌──────────────────┐                              │
│                    │   Apache Kafka   │ ← Schema Registry            │
│                    └────────┬─────────┘   (Avro schemas)            │
│                             │                                         │
│            ┌────────────────┼────────────────┐                       │
│            │                │                │                        │
│            ▼                ▼                ▼                        │
│      ┌──────────┐   ┌────────────┐   ┌─────────────┐               │
│      │  Apache  │   │   Apache   │   │  Kafka       │               │
│      │  Flink   │   │   Spark    │   │  Connect     │               │
│      │(real-time│   │  (batch +  │   │  (S3/BQ/     │               │
│      │ < 100ms) │   │  streaming)│   │  HDFS sink)  │               │
│      └────┬─────┘   └─────┬──────┘   └──────┬───────┘              │
│           │                │                  │                       │
│           ▼                ▼                  ▼                       │
│       Alerts DB       Delta Lake /        Data Lake                  │
│       (low latency)   Data Warehouse      (S3 / HDFS)               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9. Local Setup with Docker

```yaml
# docker-compose.yml
version: "3"
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    depends_on: [zookeeper]
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"

  schema-registry:
    image: confluentinc/cp-schema-registry:7.5.0
    depends_on: [kafka]
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:9092

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    depends_on: [kafka]
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
```

```bash
docker-compose up -d

# Open Kafka UI
open http://localhost:8080

# Produce test messages from CLI
kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test-topic

# Consume test messages
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic test-topic --from-beginning
```

---

## Knowledge Check

1. Explain the difference between a **partition** and an **offset**. Why does key-based partitioning guarantee ordering?
2. You have 6 partitions and 8 consumers in one consumer group. What happens? How many consumers are active?
3. Your consumer group is falling behind (consumer lag is growing). What are 3 ways to address this?
4. Why would you use `cleanup.policy=compact` instead of `delete` for a Kafka topic? Give a real-world example.
5. What does Kafka Connect provide that plain producer/consumer code doesn't?
6. Explain CDC (Change Data Capture) via Debezium. What problem does it solve and how does it work?

---

## Next Module

→ [`05-hands-on-labs.md`](./05-hands-on-labs.md) — End-to-end labs that connect Kafka → Flink/Spark → Data Warehouse in a complete pipeline.
