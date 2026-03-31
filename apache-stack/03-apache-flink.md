# Apache Flink

## Overview

Apache Flink is a distributed stream processing framework designed for stateful computations over unbounded and bounded data streams. While Spark Streaming uses micro-batches (tiny batch jobs), Flink processes each event truly one at a time — giving it lower latency and more expressive stateful processing primitives.

**When to choose Flink over Spark Streaming:**
- Sub-second latency is required (e.g., fraud detection, real-time recommendations)
- Complex event processing across time windows with precise event-time semantics
- Long-running stateful applications (session tracking, aggregations over days/weeks)
- Exactly-once processing guarantees are non-negotiable

---

## 1. Flink Architecture

```
┌──────────────────────────────────────────────────────────────┐
│              Flink Cluster                                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              JobManager                              │    │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────────┐  │    │
│  │  │  Dispatcher│  │  Scheduler │  │ Checkpoint   │  │    │
│  │  │  (REST API)│  │ (DAG plan) │  │ Coordinator  │  │    │
│  │  └────────────┘  └────────────┘  └──────────────┘  │    │
│  └──────────────────────────┬──────────────────────────┘    │
│                             │ deploy tasks                   │
│         ┌───────────────────┼───────────────┐               │
│         ▼                   ▼               ▼               │
│  ┌─────────────┐   ┌─────────────┐  ┌─────────────┐        │
│  │ TaskManager │   │ TaskManager │  │ TaskManager │        │
│  │  [Slot][Slot│   │  [Slot][Slot│  │  [Slot][Slot│        │
│  │  Task Task] │   │  Task Task] │  │  Task Task] │        │
│  └─────────────┘   └─────────────┘  └─────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

| Component | Role |
|-----------|------|
| **JobManager** | Receives jobs, plans execution graph, schedules tasks, coordinates checkpoints |
| **TaskManager** | Worker process — executes tasks, manages local state, communicates with Kafka |
| **Slot** | Unit of resource within a TaskManager (CPU + memory fraction) |
| **Checkpoint Coordinator** | Periodically saves consistent state snapshots for fault recovery |

### Flink vs Spark Streaming

| Aspect | Flink | Spark Structured Streaming |
|--------|-------|---------------------------|
| Processing model | True event-at-a-time streaming | Micro-batch (process N events per trigger) |
| Latency | Milliseconds | Seconds (100ms–few seconds) |
| State management | First-class native state (RocksDB) | External state (Delta, databases) |
| Event-time windowing | Rich, native | Limited |
| Fault tolerance | Asynchronous incremental checkpointing | WAL + replay |
| Batch support | Yes (same API) | Yes |
| ML integration | FlinkML (limited); integrates with PyFlink | MLlib (mature) |
| Best for | Low-latency stateful streaming | Analytics + ML pipelines at scale |

---

## 2. Core Concepts

### Bounded vs Unbounded Streams

```
Unbounded stream (streaming):    ──────────────────────────────→  (never ends)
                                  e1 e2 e3 e4 e5 ...

Bounded stream (batch):          ├──────────────────────────────┤ (has start and end)
                                  e1 e2 e3 ... eN
```

Flink uses the same API for both. A bounded stream is just a streaming job that happens to finish.

### Time Semantics

This is one of Flink's most important and differentiating features.

```
Event Time:        When the event ACTUALLY happened (embedded in the event payload)
Ingestion Time:    When the event arrived at Flink
Processing Time:   When Flink processed the event (wall clock)
```

**Use event time** for correct results when events can arrive late or out of order (almost always in production). **Use processing time** only for simple monitoring where slight inaccuracies are acceptable.

### Watermarks — Handling Late Data

A watermark tells Flink "I believe all events with timestamp ≤ T have now arrived."

```
Events arrive:    e(t=1)  e(t=3)  e(t=2)  e(t=5)  e(t=4)  e(t=8)  e(t=7) ...
                                                                    ↑
                                         Watermark (t=5) emitted here
                                         → triggers window [0, 5) to close
```

A watermark with **bounded out-of-orderness of 5 seconds** means Flink waits 5 seconds beyond the max seen timestamp before closing a window — accepting late events up to 5 seconds out of order.

---

## 3. DataStream API

### Environment Setup (PyFlink)

```python
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.common.time import Time, Duration

# Create the streaming environment
env = StreamExecutionEnvironment.get_execution_environment()
env.set_parallelism(4)                              # 4 parallel tasks
env.enable_checkpointing(60_000)                    # Checkpoint every 60s
env.get_checkpoint_config().set_min_pause_between_checkpoints(30_000)

# For batch (bounded) processing
from pyflink.datastream import RuntimeExecutionMode
env.set_runtime_mode(RuntimeExecutionMode.BATCH)
```

### Reading from Kafka

```python
from pyflink.datastream.connectors.kafka import (
    KafkaSource, KafkaOffsetsInitializer
)
from pyflink.common.serialization import SimpleStringSchema
from pyflink.common.watermark_strategy import (
    WatermarkStrategy, TimestampAssignerSupplier
)
import json
from datetime import datetime

# Define a Kafka source
kafka_source = KafkaSource.builder() \
    .set_bootstrap_servers("kafka-broker:9092") \
    .set_topics("user_events") \
    .set_group_id("flink-consumer-group") \
    .set_starting_offsets(KafkaOffsetsInitializer.latest()) \
    .set_value_only_deserializer(SimpleStringSchema()) \
    .build()

# Assign event-time timestamps from the event payload
class EventTimestampAssigner:
    def extract_timestamp(self, event_str: str, record_timestamp: int) -> int:
        event = json.loads(event_str)
        # Return millisecond epoch timestamp from the event
        return int(datetime.fromisoformat(event["event_time"]).timestamp() * 1000)

watermark_strategy = (
    WatermarkStrategy
    .for_bounded_out_of_orderness(Duration.of_seconds(10))
    .with_timestamp_assigner(EventTimestampAssigner())
)

stream = env.from_source(
    source=kafka_source,
    watermark_strategy=watermark_strategy,
    source_name="Kafka User Events"
)
```

### Transformations

```python
from pyflink.datastream import MapFunction, FilterFunction, FlatMapFunction

# Map — transform each element
class ParseEvent(MapFunction):
    def map(self, value: str):
        data = json.loads(value)
        return {
            "user_id":    data["user_id"],
            "event_type": data["event_type"],
            "amount":     float(data.get("amount", 0.0)),
            "event_time": data["event_time"]
        }

# Filter — keep only purchase events
class IsPurchase(FilterFunction):
    def filter(self, event: dict) -> bool:
        return event["event_type"] == "purchase"

# FlatMap — one input → zero or more outputs
class ExtractTags(FlatMapFunction):
    def flat_map(self, event: dict, collector):
        for tag in event.get("tags", []):
            collector.collect((event["user_id"], tag))

parsed = stream.map(ParseEvent())
purchases = parsed.filter(IsPurchase())

# Lambda equivalents (Python only)
large_purchases = purchases.filter(lambda e: e["amount"] > 100.0)
amounts = large_purchases.map(lambda e: (e["user_id"], e["amount"]))
```

### KeyedStream — Partition by Key

```python
# Key by user_id — all events for a user go to the same parallel instance
keyed = purchases.key_by(lambda e: e["user_id"])

# KeyedProcessFunction — full access to state and timers
from pyflink.datastream import KeyedProcessFunction, RuntimeContext
from pyflink.datastream.state import ValueStateDescriptor, ListStateDescriptor

class UserSpendTracker(KeyedProcessFunction):
    def open(self, runtime_context: RuntimeContext):
        # Declare state per user_id key
        self.total_spend = runtime_context.get_state(
            ValueStateDescriptor("total_spend", float)
        )
        self.purchase_count = runtime_context.get_state(
            ValueStateDescriptor("purchase_count", int)
        )

    def process_element(self, event: dict, ctx, out):
        # Update accumulated state
        current_total = self.total_spend.value() or 0.0
        current_count = self.purchase_count.value() or 0

        new_total = current_total + event["amount"]
        new_count = current_count + 1

        self.total_spend.update(new_total)
        self.purchase_count.update(new_count)

        # Emit enriched event
        out.collect({
            **event,
            "lifetime_spend":  new_total,
            "purchase_number": new_count,
            "is_vip":          new_total >= 10_000
        })

        # Register a timer to fire 1 hour from now (event time)
        ctx.timer_service().register_event_time_timer(
            ctx.timestamp() + 3_600_000  # +1 hour in ms
        )

    def on_timer(self, timestamp: int, ctx, out):
        # Called when the timer fires — e.g., emit an inactivity alert
        out.collect({
            "user_id":   ctx.get_current_key(),
            "alert":     "no_purchase_1h",
            "timestamp": timestamp
        })

result = keyed.process(UserSpendTracker())
```

---

## 4. Windowing

Windows let you group a stream into finite chunks for aggregation.

### Window Types

```
Tumbling Window (5 min):
  [00:00─────05:00) [05:00────10:00) [10:00───15:00)
  Events fall into exactly ONE window.

Sliding Window (10 min, sliding every 5 min):
  [00:00────────10:00)
         [05:00────────15:00)
                [10:00────────20:00)
  Events can appear in MULTIPLE windows.

Session Window (gap = 30 min):
  [e1─e2─e3]      [e4─e5]     [e6]
  ←gap > 30min→           ←gap > 30min→
  Windows close after inactivity gap. Size is DYNAMIC.
```

### Tumbling Window Example

```python
from pyflink.datastream.window import TumblingEventTimeWindows
from pyflink.datastream import ReduceFunction

# 5-minute tumbling windows on event time, keyed by user_id
windowed = (
    purchases
    .key_by(lambda e: e["user_id"])
    .window(TumblingEventTimeWindows.of(Time.minutes(5)))
    .reduce(lambda a, b: {
        **a,
        "amount": a["amount"] + b["amount"]
    })
)
```

### Sliding Window Example

```python
from pyflink.datastream.window import SlidingEventTimeWindows

# 10-minute window, updated every 2 minutes
sliding = (
    purchases
    .key_by(lambda e: e["event_type"])
    .window(SlidingEventTimeWindows.of(Time.minutes(10), Time.minutes(2)))
    .aggregate(CountAndSumAggregator())
)
```

### Session Window Example

```python
from pyflink.datastream.window import EventTimeSessionWindows

# Sessions close after 30 minutes of inactivity
sessions = (
    stream
    .key_by(lambda e: e["user_id"])
    .window(EventTimeSessionWindows.with_gap(Time.minutes(30)))
    .process(SessionSummaryFunction())
)
```

### WindowFunction for Custom Logic

```python
from pyflink.datastream import WindowFunction
from pyflink.datastream.window import TimeWindow

class RevenueWindowFunction(WindowFunction):
    def apply(self, key: str, window: TimeWindow, inputs, out):
        events = list(inputs)
        total  = sum(e["amount"] for e in events)
        count  = len(events)

        out.collect({
            "user_id":      key,
            "window_start": window.start,
            "window_end":   window.end,
            "total_spend":  total,
            "event_count":  count,
            "avg_spend":    total / count if count > 0 else 0
        })
```

---

## 5. Table API and Flink SQL

Flink's Table API provides a higher-level declarative interface, similar to Spark SQL.

```python
from pyflink.table import EnvironmentSettings, TableEnvironment
from pyflink.table.expressions import col, lit

# Create a streaming Table environment
settings = EnvironmentSettings.in_streaming_mode()
t_env = TableEnvironment.create(settings)

# Define Kafka source table using DDL
t_env.execute_sql("""
    CREATE TABLE user_events (
        user_id      STRING,
        event_type   STRING,
        amount       DOUBLE,
        event_time   TIMESTAMP(3),
        WATERMARK FOR event_time AS event_time - INTERVAL '10' SECOND
    ) WITH (
        'connector'                    = 'kafka',
        'topic'                        = 'user_events',
        'properties.bootstrap.servers' = 'kafka-broker:9092',
        'properties.group.id'          = 'flink-sql-group',
        'scan.startup.mode'            = 'latest-offset',
        'format'                       = 'json'
    )
""")

# Define a sink table (Delta / Filesystem for now, or Kafka topic)
t_env.execute_sql("""
    CREATE TABLE revenue_by_window (
        user_id        STRING,
        window_start   TIMESTAMP(3),
        window_end     TIMESTAMP(3),
        total_spend    DOUBLE,
        event_count    BIGINT,
        PRIMARY KEY (user_id, window_start) NOT ENFORCED
    ) WITH (
        'connector'  = 'filesystem',
        'path'       = 'hdfs:///output/revenue_windows/',
        'format'     = 'parquet'
    )
""")

# Flink SQL query with tumbling window
t_env.execute_sql("""
    INSERT INTO revenue_by_window
    SELECT
        user_id,
        TUMBLE_START(event_time, INTERVAL '5' MINUTE) AS window_start,
        TUMBLE_END  (event_time, INTERVAL '5' MINUTE) AS window_end,
        SUM(amount)                                    AS total_spend,
        COUNT(*)                                       AS event_count
    FROM user_events
    WHERE event_type = 'purchase'
    GROUP BY
        user_id,
        TUMBLE(event_time, INTERVAL '5' MINUTE)
""")

# Table API (Python-style)
events_table = t_env.from_path("user_events")
result = (
    events_table
    .filter(col("event_type") == "purchase")
    .group_by(col("user_id"))
    .select(
        col("user_id"),
        col("amount").sum.alias("total_spend"),
        col("amount").count.alias("event_count")
    )
)
result.execute().print()
```

---

## 6. State Backends

Flink stores operator state in a configurable backend:

| Backend | State Storage | Best For |
|---------|--------------|----------|
| `HashMapStateBackend` | JVM heap memory | Small–medium state, low latency |
| `EmbeddedRocksDBStateBackend` | RocksDB (local disk, off-heap) | Large state (GBs per task), recommended for production |

```python
from pyflink.datastream.checkpoint_storage import FileSystemCheckpointStorage
from pyflink.datastream.state_backend import EmbeddedRocksDBStateBackend

# Use RocksDB for large state (highly recommended for production)
env.set_state_backend(EmbeddedRocksDBStateBackend())

# Store checkpoints in HDFS or S3
env.get_checkpoint_config().set_checkpoint_storage(
    FileSystemCheckpointStorage("hdfs:///flink-checkpoints/my-job/")
)

# Checkpoint configuration
env.enable_checkpointing(30_000)  # checkpoint every 30s
env.get_checkpoint_config().set_min_pause_between_checkpoints(10_000)
env.get_checkpoint_config().set_checkpoint_timeout(60_000)
env.get_checkpoint_config().set_max_concurrent_checkpoints(1)
```

---

## 7. Fault Tolerance and Exactly-Once

Flink achieves exactly-once semantics through **distributed snapshots** (Chandy-Lamport algorithm adapted for streaming):

```
Normal operation:         ──[barrier B₁]──[barrier B₂]──[barrier B₃]──→
                             (inject barriers into the stream)

When all operators receive barrier B₁:
  → Each operator saves its local state to the checkpoint storage
  → Once all operators report done, checkpoint B₁ is complete
  → On failure: Flink restores all operators to the last completed checkpoint
```

**End-to-end exactly-once** also requires the sink to support it (e.g., Kafka transactions, database upserts with idempotent keys).

```python
# Exactly-once Kafka sink
from pyflink.datastream.connectors.kafka import (
    KafkaSink, KafkaRecordSerializationSchema, DeliveryGuarantee
)

kafka_sink = KafkaSink.builder() \
    .set_bootstrap_servers("kafka-broker:9092") \
    .set_record_serializer(
        KafkaRecordSerializationSchema.builder()
            .set_topic("enriched_events")
            .set_value_serialization_schema(SimpleStringSchema())
            .build()
    ) \
    .set_delivery_guarantee(DeliveryGuarantee.EXACTLY_ONCE) \
    .set_transactional_id_prefix("flink-exactly-once") \
    .build()

result_stream.sink_to(kafka_sink)
```

---

## 8. Running Flink (Setup)

```bash
# Download and extract
curl -O https://dlcdn.apache.org/flink/flink-1.19.0/flink-1.19.0-bin-scala_2.12.tgz
tar -xzf flink-1.19.0-bin-scala_2.12.tgz
cd flink-1.19.0

# Start a local cluster (1 JobManager + 1 TaskManager)
./bin/start-cluster.sh

# Open the Flink Web UI
open http://localhost:8081

# Submit a job
./bin/flink run examples/streaming/WordCount.jar

# Install PyFlink
pip install apache-flink==1.19.0

# Submit a PyFlink job
./bin/flink run --pythonModule my_pipeline --python my_pipeline.py

# Stop the local cluster
./bin/stop-cluster.sh

# Docker Compose (recommended for learning)
# docker-compose.yml with jobmanager + taskmanager
docker-compose up -d
open http://localhost:8081
```

---

## 9. Flink vs Spark Streaming — When to Choose Each

| Use Case | Choose Flink | Choose Spark Streaming |
|----------|-------------|----------------------|
| Real-time fraud detection (< 100ms) | ✓ | - |
| Complex event processing (CEP) | ✓ | - |
| Long-running user sessions | ✓ (native state) | - |
| Large-scale ML training pipelines | - | ✓ (MLlib) |
| Batch + streaming on same codebase | ✓ | ✓ |
| Already on Databricks | - | ✓ |
| Event-time precision matters greatly | ✓ | - |
| Micro-batch analytics (5s+ latency OK) | - | ✓ |

---

## Knowledge Check

1. What is the difference between processing time, ingestion time, and event time? Why does event time matter for correct results?
2. You have a stream of login events. You need to detect users who log in more than 5 times in any 10-minute window. Which window type would you use and why?
3. A Flink job fails partway through. How does Flink recover, and what guarantees does it provide?
4. What is a watermark and what problem does it solve?
5. When would you choose `EmbeddedRocksDBStateBackend` over `HashMapStateBackend`?
6. Explain the difference between `KeyedProcessFunction` and a simple `map()` operation.

---

## Next Module

→ [`04-apache-kafka.md`](./04-apache-kafka.md) — Kafka is the distributed messaging backbone that connects data sources to Spark, Flink, and downstream systems. Almost every real-time pipeline starts with Kafka.
