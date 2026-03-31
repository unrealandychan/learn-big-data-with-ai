# Apache Stack — Hands-On Labs

## Overview

These labs build a complete end-to-end data pipeline using the Apache stack covered in this module. Each lab can be run independently, but they flow together as a production-style reference architecture.

```
Lab 1: HDFS Setup & Hadoop Basics
Lab 2: Spark Batch Processing Pipeline
Lab 3: Kafka Event Streaming Setup
Lab 4: Flink Real-Time Processing
Lab 5: End-to-End Pipeline (Kafka → Flink → Spark → Warehouse)
```

**Time estimate:** 6 hours (all labs)
**Prerequisites:** Docker installed, Python 3.8+, Java 11+

---

## Lab 1: Hadoop HDFS Basics (45 minutes)

### Objective
Explore HDFS concepts hands-on: upload data, read it back, observe replication and block layout.

### Setup

```bash
# Clone the Docker Hadoop setup
git clone https://github.com/big-data-europe/docker-hadoop.git
cd docker-hadoop
docker-compose up -d

# Verify all services are healthy
docker-compose ps
# Expected: namenode, datanode, resourcemanager, nodemanager, historyserver — all Up

# Open HDFS Web UI
open http://localhost:9870    # NameNode UI — browse file system
open http://localhost:8088    # YARN ResourceManager UI
```

### Lab Tasks

```bash
# 1. Create a sample dataset locally
mkdir -p /tmp/lab-data
cat > /tmp/lab-data/sales.csv << 'EOF'
order_id,customer_id,product,amount,region,order_date
1001,CUST-001,Laptop,1299.99,North,2024-01-15
1002,CUST-002,Phone,699.99,South,2024-01-15
1003,CUST-001,Tablet,449.99,North,2024-01-16
1004,CUST-003,Laptop,1299.99,East,2024-01-16
1005,CUST-004,Monitor,349.99,West,2024-01-17
1006,CUST-002,Keyboard,89.99,South,2024-01-17
1007,CUST-005,Phone,699.99,North,2024-01-18
1008,CUST-003,Mouse,29.99,East,2024-01-18
EOF

# 2. Copy the file into the NameNode container and upload to HDFS
docker cp /tmp/lab-data/sales.csv namenode:/tmp/sales.csv

docker exec -it namenode bash -c "
  # Create directories
  hdfs dfs -mkdir -p /data/lab/sales
  
  # Upload file
  hdfs dfs -put /tmp/sales.csv /data/lab/sales/
  
  # List files
  hdfs dfs -ls /data/lab/sales/
  
  # Show file content
  hdfs dfs -cat /data/lab/sales/sales.csv
  
  # Check file info and block locations
  hdfs fsck /data/lab/sales/sales.csv -files -blocks
  
  # Show disk usage
  hdfs dfs -du -h /data/lab/
"

# 3. Run a built-in MapReduce example
docker exec -it namenode bash -c "
  hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
    wordcount /data/lab/sales /data/lab/wordcount-output
  
  hdfs dfs -cat /data/lab/wordcount-output/part-r-00000
"
```

### Expected Output

```
Block size: 128 MB (note: small file = 1 block)
Replication factor: 1 (single-node Docker cluster)
Word count output will list CSV tokens and their counts
```

### Checkpoint Questions

- What does the NameNode store? What does the DataNode store?
- What would the block layout look like for a 500 MB file (128 MB blocks)?
- Why is MapReduce not ideal for this word count workload in production?

---

## Lab 2: Spark Batch Processing (90 minutes)

### Objective
Load the sales CSV from HDFS, transform it, compute analytics, and write results as Parquet.

### Setup

```bash
# Install PySpark
pip install pyspark==3.5.0

# Or use the Docker container approach
docker run -it --name spark-lab \
  -p 4040:4040 \
  -v /tmp/lab-data:/data \
  apache/spark:3.5.0 \
  /opt/spark/bin/pyspark --master local[4]
```

### `spark_sales_analysis.py`

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("SalesAnalysis") \
    .master("local[4]") \
    .config("spark.sql.shuffle.partitions", "8") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

print("=== Lab 2: Spark Batch Sales Analysis ===\n")

# --- 1. Load Data ---
df = spark.read.csv(
    "/data/sales.csv",  # or "hdfs:///data/lab/sales/sales.csv"
    header=True,
    inferSchema=True
)

print("Schema:")
df.printSchema()
print(f"Total records: {df.count()}\n")

# --- 2. Data Quality Checks ---
null_counts = df.select([
    F.count(F.when(F.col(c).isNull(), c)).alias(c)
    for c in df.columns
])
print("Null counts per column:")
null_counts.show()

# --- 3. Transformations ---
df_enriched = df \
    .withColumn("order_date", F.to_date("order_date", "yyyy-MM-dd")) \
    .withColumn("month", F.month("order_date")) \
    .withColumn("week", F.weekofyear("order_date")) \
    .withColumn(
        "price_tier",
        F.when(F.col("amount") >= 1000, "premium")
         .when(F.col("amount") >= 300, "mid")
         .otherwise("economy")
    )

# --- 4. Regional Revenue Analysis ---
print("Regional Revenue Summary:")
regional = df_enriched.groupBy("region").agg(
    F.sum("amount").alias("total_revenue"),
    F.count("order_id").alias("order_count"),
    F.avg("amount").alias("avg_order_value"),
    F.countDistinct("customer_id").alias("unique_customers")
).orderBy(F.desc("total_revenue"))

regional.show()

# --- 5. Customer Spend Ranking (Window Function) ---
window_spec = Window.orderBy(F.desc("lifetime_spend"))

customer_summary = df_enriched.groupBy("customer_id").agg(
    F.sum("amount").alias("lifetime_spend"),
    F.count("order_id").alias("order_count")
).withColumn(
    "spend_rank", F.rank().over(window_spec)
)

print("Top Customers by Lifetime Spend:")
customer_summary.orderBy("spend_rank").show()

# --- 6. Product Trend Analysis ---
print("Daily Revenue by Product:")
daily_product = df_enriched.groupBy("order_date", "product").agg(
    F.sum("amount").alias("daily_revenue")
).orderBy("order_date", "product")
daily_product.show()

# --- 7. Self-Join — Customer Repeat Purchases ---
df_a = df_enriched.alias("a")
df_b = df_enriched.alias("b")

repeat_pairs = df_a.join(
    df_b,
    (F.col("a.customer_id") == F.col("b.customer_id")) &
    (F.col("a.order_id") < F.col("b.order_id")),
    "inner"
).select(
    F.col("a.customer_id"),
    F.col("a.product").alias("first_purchase"),
    F.col("b.product").alias("repeat_purchase"),
    F.col("a.order_date").alias("first_date"),
    F.col("b.order_date").alias("repeat_date")
)

print("Repeat Purchase Pairs:")
repeat_pairs.show()

# --- 8. Write Results ---
output_path = "/data/output"

regional.write.mode("overwrite").parquet(f"{output_path}/regional_summary/")
customer_summary.write.mode("overwrite").parquet(f"{output_path}/customer_summary/")

print(f"Results written to {output_path}/")

# --- 9. Verify output ---
df_verify = spark.read.parquet(f"{output_path}/regional_summary/")
df_verify.show()

# Open Spark UI for DAG visualization
print("Spark UI: http://localhost:4040")
input("Press Enter to stop Spark (Lab complete)...")

spark.stop()
```

```bash
# Run the analysis
python spark_sales_analysis.py
```

### Checkpoint Questions

- Open the Spark UI at `http://localhost:4040`. How many stages did your job have? What operation caused a stage boundary?
- Change `spark.sql.shuffle.partitions` to `4` and rerun. Does performance change? Why?
- Why is Parquet a better output format than CSV for downstream analytics?

---

## Lab 3: Kafka Setup and Producing Events (45 minutes)

### Objective
Set up a local Kafka cluster and build a simple producer/consumer for order events.

### Setup

```bash
# docker-compose.yml for Kafka
cat > docker-compose-kafka.yml << 'EOF'
version: "3"
services:
  kafka:
    image: apache/kafka:3.7.0
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qk"

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
    depends_on: [kafka]
EOF

docker-compose -f docker-compose-kafka.yml up -d
open http://localhost:8080    # Kafka UI

pip install kafka-python
```

### `kafka_producer.py`

```python
from kafka import KafkaProducer
import json
import time
import random
from datetime import datetime, timezone

producer = KafkaProducer(
    bootstrap_servers=["localhost:9092"],
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    key_serializer=lambda k: k.encode("utf-8"),
    acks="all"
)

PRODUCTS  = ["Laptop", "Phone", "Tablet", "Monitor", "Keyboard", "Mouse"]
REGIONS   = ["North", "South", "East", "West"]
CUSTOMERS = [f"CUST-{i:03d}" for i in range(1, 21)]
PRICES    = {"Laptop": 1299.99, "Phone": 699.99, "Tablet": 449.99,
             "Monitor": 349.99, "Keyboard": 89.99, "Mouse": 29.99}

print("Producing order events to Kafka... (Ctrl+C to stop)")
order_id = 2000

try:
    while True:
        product     = random.choice(PRODUCTS)
        customer_id = random.choice(CUSTOMERS)
        region      = random.choice(REGIONS)

        event = {
            "order_id":    f"ORD-{order_id}",
            "customer_id": customer_id,
            "product":     product,
            "amount":      round(PRICES[product] * random.uniform(0.9, 1.1), 2),
            "region":      region,
            "order_time":  datetime.now(timezone.utc).isoformat()
        }

        producer.send("orders", key=customer_id, value=event)
        print(f"Sent: {event['order_id']} | {product} | ${event['amount']}")

        order_id += 1
        time.sleep(0.5)  # Send 2 events/second
except KeyboardInterrupt:
    print("Stopping producer...")
finally:
    producer.flush()
    producer.close()
```

### `kafka_consumer_verify.py`

```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    "orders",
    bootstrap_servers=["localhost:9092"],
    group_id="lab-verifier",
    auto_offset_reset="earliest",
    value_deserializer=lambda v: json.loads(v.decode("utf-8"))
)

print("Reading orders from Kafka (first 10):")
count = 0
for message in consumer:
    order = message.value
    print(f"[{message.partition}:{message.offset}] {order['order_id']} "
          f"| {order['customer_id']} | {order['product']} | ${order['amount']}")
    count += 1
    if count >= 10:
        break

consumer.close()
```

```bash
# Terminal 1: Run producer
python kafka_producer.py

# Terminal 2: Verify consumption
python kafka_consumer_verify.py

# Check Kafka UI for topics, messages, and consumer lag
open http://localhost:8080
```

---

## Lab 4: Flink Real-Time Processing (90 minutes)

### Objective
Build a Flink job that reads from the `orders` Kafka topic, computes 1-minute windowed revenue by region, and prints alerts for high-value orders.

### Setup

```bash
pip install apache-flink==1.19.0

# Ensure Kafka is running from Lab 3
# Start the Kafka producer in the background first
python kafka_producer.py &
```

### `flink_orders_pipeline.py`

```python
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors.kafka import (
    KafkaSource, KafkaOffsetsInitializer
)
from pyflink.common.serialization import SimpleStringSchema
from pyflink.common.watermark_strategy import WatermarkStrategy
from pyflink.common.time import Time, Duration
from pyflink.datastream.window import TumblingProcessingTimeWindows
from pyflink.datastream import MapFunction, ProcessWindowFunction, RuntimeContext
from pyflink.datastream.state import ValueStateDescriptor
import json
from datetime import datetime

# ---- Environment Setup ----
env = StreamExecutionEnvironment.get_execution_environment()
env.set_parallelism(2)
env.enable_checkpointing(30_000)  # checkpoint every 30s

# Add Kafka connector JAR (download to jars/ directory)
env.add_jars("file:///jars/flink-connector-kafka-3.1.0-1.18.jar")

# ---- Kafka Source ----
kafka_source = KafkaSource.builder() \
    .set_bootstrap_servers("localhost:9092") \
    .set_topics("orders") \
    .set_group_id("flink-lab-group") \
    .set_starting_offsets(KafkaOffsetsInitializer.latest()) \
    .set_value_only_deserializer(SimpleStringSchema()) \
    .build()

stream = env.from_source(
    source=kafka_source,
    watermark_strategy=WatermarkStrategy.for_monotonous_timestamps(),
    source_name="Kafka Orders"
)

# ---- Parse JSON ----
class ParseOrder(MapFunction):
    def map(self, value: str):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return None

parsed = stream.map(ParseOrder()).filter(lambda e: e is not None)

# ---- Alert: High-Value Orders (> $1000) ----
class HighValueAlert(MapFunction):
    def map(self, event: dict) -> str:
        if event["amount"] > 1000:
            return (f"🚨 HIGH VALUE ORDER: {event['order_id']} "
                    f"| Customer: {event['customer_id']} "
                    f"| Amount: ${event['amount']:.2f} "
                    f"| Region: {event['region']}")
        return None

alerts = parsed.map(HighValueAlert()).filter(lambda msg: msg is not None)
alerts.print("ALERT")

# ---- Windowed Revenue by Region (1-minute tumbling) ----
class RevenueWindowFunction(ProcessWindowFunction):
    def process(self, key: str, context, elements, out):
        total   = sum(e["amount"] for e in elements)
        count   = len(list(elements))
        out.collect({
            "region":       key,
            "window_start": context.window().start,
            "window_end":   context.window().end,
            "total_revenue": round(total, 2),
            "order_count":  count
        })

windowed_revenue = (
    parsed
    .key_by(lambda e: e["region"])
    .window(TumblingProcessingTimeWindows.of(Time.minutes(1)))
    .process(RevenueWindowFunction())
)

class FormatRevenue(MapFunction):
    def map(self, r: dict) -> str:
        start = datetime.fromtimestamp(r["window_start"] / 1000).strftime("%H:%M")
        end   = datetime.fromtimestamp(r["window_end"] / 1000).strftime("%H:%M")
        return (f"[{start}─{end}] Region: {r['region']:6s} | "
                f"Revenue: ${r['total_revenue']:>10,.2f} | "
                f"Orders: {r['order_count']}")

windowed_revenue.map(FormatRevenue()).print("REVENUE")

# ---- Stateful: Per-Customer Spend Tracker ----
class SpendTracker(MapFunction):
    def open(self, runtime_context: RuntimeContext):
        self.lifetime_spend = runtime_context.get_state(
            ValueStateDescriptor("lifetime", float)
        )

    def map(self, event: dict) -> dict:
        current = self.lifetime_spend.value() or 0.0
        new_total = current + event["amount"]
        self.lifetime_spend.update(new_total)
        return {
            **event,
            "lifetime_spend": round(new_total, 2),
            "is_vip":         new_total >= 2000
        }

enriched = parsed.key_by(lambda e: e["customer_id"]).map(SpendTracker())

class VIPFilter(MapFunction):
    def map(self, event: dict):
        if event.get("is_vip"):
            return f"⭐ VIP Customer: {event['customer_id']} (lifetime: ${event['lifetime_spend']:.2f})"
        return None

enriched.map(VIPFilter()).filter(lambda m: m is not None).print("VIP")

# ---- Execute ----
print("Starting Flink job... (Ctrl+C to stop)")
env.execute("Orders Real-Time Pipeline")
```

```bash
# Run the Flink pipeline (ensure producer is running)
python flink_orders_pipeline.py
```

### Expected Output

```
REVENUE> [10:00─10:01] Region: North  | Revenue: $   4,299.97 | Orders: 4
REVENUE> [10:00─10:01] Region: South  | Revenue: $   1,389.98 | Orders: 2
ALERT>   🚨 HIGH VALUE ORDER: ORD-2003 | Customer: CUST-007 | Amount: $1,313.99 | Region: East
VIP>     ⭐ VIP Customer: CUST-001 (lifetime: $2,049.97)
```

### Checkpoint Questions

- What would happen to the VIP customer state if the Flink job crashed and restarted without checkpointing?
- Why did we use `TumblingProcessingTimeWindows` instead of event-time windows here?
- What would you change to add a sliding 5-minute window alongside the tumbling 1-minute window?

---

## Lab 5: End-to-End Pipeline (60 minutes)

### Objective
Connect everything: Kafka → Flink (real-time alerts) AND Kafka → Spark (hourly batch rollup) → Parquet output.

### Architecture

```
kafka_producer.py
      │
      ▼
  Kafka "orders"
      │
  ┌───┴──────────────────┐
  │                      │
  ▼                      ▼
Flink Pipeline         Spark Hourly Batch
(real-time, < 1s)      (runs every hour)
  │                      │
  ▼                      ▼
Print alerts         Parquet on disk
(or Kafka sink)      (for warehouse load)
```

### `spark_hourly_rollup.py`

```python
"""
Simulates an hourly batch job: reads the last hour of data from Kafka,
computes summaries, and writes to Parquet for warehouse ingestion.
In production, this would be orchestrated by Airflow.
"""

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from datetime import datetime, timedelta, timezone

spark = SparkSession.builder \
    .appName("HourlyOrderRollup") \
    .master("local[4]") \
    .config("spark.sql.shuffle.partitions", "8") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

# Read from Kafka (batch read of committed messages)
df_kafka = spark.read \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "orders") \
    .option("startingOffsets", "earliest") \
    .load()

# Parse Kafka message
from pyspark.sql.types import StructType, StringType, DoubleType

schema = StructType() \
    .add("order_id",    StringType()) \
    .add("customer_id", StringType()) \
    .add("product",     StringType()) \
    .add("amount",      DoubleType()) \
    .add("region",      StringType()) \
    .add("order_time",  StringType())

df_orders = df_kafka.select(
    F.from_json(F.col("value").cast("string"), schema).alias("data")
).select("data.*") \
 .withColumn("order_time", F.to_timestamp("order_time"))

# Filter to last hour (in production: parameterized by Airflow run date)
one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
df_recent = df_orders.filter(F.col("order_time") >= one_hour_ago)

print(f"Records in last hour: {df_recent.count()}")

# Hourly rollup by region and product
hourly_summary = df_recent.groupBy(
    F.date_trunc("hour", "order_time").alias("hour"),
    "region",
    "product"
).agg(
    F.sum("amount").alias("revenue"),
    F.count("order_id").alias("order_count"),
    F.avg("amount").alias("avg_order_value")
)

hourly_summary.show(truncate=False)

# Write to Parquet (partitioned by date for efficient warehouse loading)
output_path = "/tmp/warehouse_load"
hourly_summary.write \
    .partitionBy("region") \
    .mode("overwrite") \
    .parquet(f"{output_path}/hourly_orders/")

print(f"Hourly rollup written to {output_path}/hourly_orders/")

spark.stop()
```

```bash
# Terminal 1: Keep the producer running
python kafka_producer.py

# Terminal 2: Keep Flink real-time pipeline running
python flink_orders_pipeline.py

# Terminal 3: Run hourly Spark rollup (run ad-hoc or schedule with Airflow)
python spark_hourly_rollup.py

# View the Parquet output
python -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.master('local').getOrCreate()
spark.read.parquet('/tmp/warehouse_load/hourly_orders/').show()
"
```

---

## Final Project: Design Challenge

Now that you've built the Apache stack pipeline, answer these architectural questions:

1. **Scaling Kafka**: Your `orders` topic currently has 4 partitions but you're expecting 10x more traffic. What are the steps to safely increase partitions without losing data or causing consumer rebalances?

2. **Flink vs Spark decision**: Your team needs to build:
   - A fraud detection system (flag suspicious orders within 200ms)
   - A monthly P&L report joining 3 years of order history
   
   Which tool would you use for each, and why?

3. **HDFS → Cloud migration**: You inherit an on-premise Hadoop cluster storing 50 TB of data in HDFS with Hive tables on top. Your company is moving to AWS. What is your migration strategy? What replaces each component?

4. **End-to-end exactly-once**: Your pipeline is: `Kafka → Flink → PostgreSQL`. Under what conditions can Flink guarantee exactly-once delivery? What does the sink need to support?

5. **Partitioning strategy**: You're designing a Kafka topic for IoT sensor events from 10,000 devices. What would you use as the partition key, how many partitions would you create, and why?

---

## Summary: What You Built

```
┌────────────────────────────────────────────────────────┐
│         Your Complete Apache Stack Pipeline             │
│                                                        │
│  kafka_producer.py                                     │
│       │ (2 events/sec, key=customer_id)                │
│       ▼                                                │
│  Kafka "orders" topic (4 partitions)                   │
│       │                                                │
│  ┌────┴───────────────────────────┐                    │
│  │ Flink: flink_orders_pipeline.py│                    │
│  │   ├── Real-time alerts (< 1s) │                    │
│  │   ├── 1-min windowed revenue  │                    │
│  │   └── Stateful VIP detection  │                    │
│  └────────────────────────────────┘                    │
│  ┌────────────────────────────────┐                    │
│  │ Spark: spark_hourly_rollup.py  │                    │
│  │   ├── Batch read from Kafka    │                    │
│  │   ├── Hourly aggregations      │                    │
│  │   └── Parquet output for DW    │                    │
│  └────────────────────────────────┘                    │
└────────────────────────────────────────────────────────┘
```

**You have now completed the Apache Stack module.** Continue to [`platform-comparison/`](../platform-comparison/) to see how these open-source foundations compare to fully-managed cloud warehouse solutions.
