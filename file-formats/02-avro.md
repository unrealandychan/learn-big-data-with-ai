# Module: Apache Avro

**Duration:** 1.5 hours  
**Prerequisites:** Basic data serialization concepts  
**Level:** Intermediate

---

## Learning Outcomes

- Explain how Avro stores data and why it's suited for streaming
- Read and write Avro schemas
- Use Avro with Kafka and Schema Registry
- Handle schema evolution safely with compatibility modes

---

## 1. What is Avro?

Apache Avro is an **open-source row-based binary serialization format** originally built for the Apache Hadoop ecosystem in 2009. Unlike Parquet (which was built for reads), Avro was designed for **fast sequential writes and compact network transmission**.

Today, Avro is the dominant format for:
- **Apache Kafka** messages (the de-facto standard with Schema Registry)
- **Hadoop/HDFS** sequence files
- **Event streaming and CDC** pipelines
- Any scenario where you write millions of small records quickly

---

## 2. Row-Based Storage — What That Means

Avro stores data **row by row**, just like a traditional relational database row:

```
Row 1: [order_id=1, customer_id=101, amount=50.00, status='SHIPPED']
Row 2: [order_id=2, customer_id=102, amount=25.00, status='PENDING']
Row 3: [order_id=3, customer_id=101, amount=75.00, status='SHIPPED']
```

**Write pattern:** Fast — you append one record at a time sequentially. No column re-organization needed.

**Read pattern:** Slow for analytics — to compute `SUM(amount)`, you must deserialize every field of every row.

```
When to choose Avro:    Write speed matters > read speed
                        Streaming / event-driven data
                        Schema must travel WITH the data
                        Kafka integration

When NOT to choose:     Analytics queries reading subsets of columns
                        Long-term analytical storage (use Parquet for that)
```

---

## 3. Avro File Structure

```
Avro File
├── Header
│   ├── Magic bytes: "Obj\x01"
│   ├── Schema (JSON, embedded in file)  ← KEY differentiator from Parquet
│   └── Sync marker (16 random bytes)
│
├── Data Block 1
│   ├── Row count
│   ├── Byte count
│   ├── Serialized rows (binary encoded)
│   └── Sync marker
│
├── Data Block 2
│   └── ...
│
└── (no footer — schema is in the header)
```

### The Critical Difference: Schema Is in the Header

In Parquet, the schema is in the **footer** (you must have the whole file to get the schema).  
In Avro, the schema is in the **header** — the very first bytes. This means:
- You can read/deserialize the data without any external schema registry
- The file is self-describing
- Schema is always consistent with the data in that file

---

## 4. Avro Schemas

Schemas are defined in **JSON** and describe exactly the shape of each record.

### Basic Schema

```json
{
  "type": "record",
  "name": "Order",
  "namespace": "com.company.events",
  "doc": "A customer order event",
  "fields": [
    {"name": "order_id",    "type": "long",   "doc": "Unique order identifier"},
    {"name": "customer_id", "type": "int"},
    {"name": "amount",      "type": "double"},
    {"name": "status",      "type": "string"},
    {"name": "order_date",  "type": "string", "logicalType": "date"}
  ]
}
```

### Avro Primitive Types

| Avro Type | Maps To | Notes |
|-----------|---------|-------|
| `null` | NULL | Only value is `null` |
| `boolean` | BOOLEAN | |
| `int` | INT32 | 4-byte signed integer |
| `long` | INT64 | 8-byte signed integer |
| `float` | FLOAT32 | |
| `double` | FLOAT64 | |
| `bytes` | BYTES | Sequence of 8-bit bytes |
| `string` | STRING | UTF-8 |

### Avro Complex Types

```json
// Array
{"type": "array", "items": "string"}

// Map (key=string, value=any type)
{"type": "map", "values": "int"}

// Enum
{"type": "enum", "name": "Status", "symbols": ["PENDING", "SHIPPED", "DELIVERED"]}

// Union (nullable field — very common)
{"name": "discount", "type": ["null", "double"], "default": null}

// Nested record
{
  "name": "shipping_address",
  "type": {
    "type": "record",
    "name": "Address",
    "fields": [
      {"name": "street", "type": "string"},
      {"name": "city",   "type": "string"},
      {"name": "zip",    "type": "string"}
    ]
  }
}
```

### Logical Types (Semantic Annotations)

```json
// Date (days since epoch)
{"name": "order_date", "type": "int",  "logicalType": "date"}

// Timestamp (microseconds since epoch)
{"name": "created_at", "type": "long", "logicalType": "timestamp-micros"}

// Decimal (precise numeric)
{"name": "amount", "type": "bytes",
 "logicalType": "decimal", "precision": 10, "scale": 2}
```

---

## 5. Reading and Writing Avro — Practical Examples

### Python (fastavro)

```python
# Install: pip install fastavro

import fastavro
from io import BytesIO

# Define schema
schema = fastavro.parse_schema({
    "type": "record",
    "name": "Order",
    "fields": [
        {"name": "order_id",    "type": "long"},
        {"name": "customer_id", "type": "int"},
        {"name": "amount",      "type": "double"},
        {"name": "status",      "type": "string"},
    ]
})

# Write Avro file
records = [
    {"order_id": 1, "customer_id": 101, "amount": 50.00, "status": "SHIPPED"},
    {"order_id": 2, "customer_id": 102, "amount": 25.00, "status": "PENDING"},
]

with open("orders.avro", "wb") as f:
    fastavro.writer(f, schema, records)

# Read Avro file
with open("orders.avro", "rb") as f:
    reader = fastavro.reader(f)
    print(reader.schema)          # Schema is embedded — no external file needed
    for record in reader:
        print(record)

# Read into Pandas
import pandas as pd

with open("orders.avro", "rb") as f:
    records = list(fastavro.reader(f))
df = pd.DataFrame(records)
```

### PySpark

```python
# Spark supports Avro via spark-avro package (included in Databricks)
# For open-source Spark: add --packages org.apache.spark:spark-avro_2.12:3.5.0

# Read Avro
df = spark.read.format("avro").load("/data/orders.avro")
df.printSchema()
df.show(5)

# Write Avro
df.write \
  .format("avro") \
  .mode("overwrite") \
  .save("/data/orders_output/")

# Use an external schema file (useful for schema evolution)
df = spark.read \
  .format("avro") \
  .option("avroSchema", open("order_schema.avsc").read()) \
  .load("/data/orders/")
```

---

## 6. Avro with Kafka and Schema Registry

This is where Avro truly shines. Kafka messages are raw bytes — the consumer has no idea what format they're in without prior agreement. Avro + Schema Registry solves this elegantly.

### How It Works

```
Producer                   Schema Registry              Consumer
   │                              │                         │
   │──(1) Register schema ───────>│                         │
   │<──(2) Schema ID: 42 ─────────│                         │
   │                              │                         │
   │──(3) Kafka message: ─────────────────────────────────>│
   │     [magic byte][schema_id=42][avro binary payload]   │
   │                              │                         │
   │                       (4) Consumer fetches            │
   │                       schema 42 if not cached ───────>│
   │                              │<──────────────────────  │
   │                       (5) Consumer deserializes       │
   │                       using schema 42                 │
```

The message only contains the **schema ID** (4 bytes), not the full schema. The full schema is fetched from the registry once and cached — this keeps messages compact.

### Confluent Python Client

```python
# Install: pip install confluent-kafka fastavro requests

from confluent_kafka import Producer, Consumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer, AvroDeserializer
from confluent_kafka.serialization import SerializationContext, MessageField

# Schema Registry client
sr_conf = {"url": "http://localhost:8081"}
sr_client = SchemaRegistryClient(sr_conf)

# Order schema
order_schema_str = """
{
  "type": "record",
  "name": "Order",
  "namespace": "com.company.events",
  "fields": [
    {"name": "order_id",    "type": "long"},
    {"name": "customer_id", "type": "int"},
    {"name": "amount",      "type": "double"},
    {"name": "status",      "type": "string"}
  ]
}
"""

# Produce Avro messages
avro_serializer = AvroSerializer(sr_client, order_schema_str)

producer = Producer({"bootstrap.servers": "localhost:9092"})

order = {"order_id": 1001, "customer_id": 42, "amount": 99.99, "status": "PENDING"}

producer.produce(
    topic="orders",
    value=avro_serializer(order, SerializationContext("orders", MessageField.VALUE))
)
producer.flush()
print("Order published!")

# Consume and deserialize Avro messages
avro_deserializer = AvroDeserializer(sr_client, order_schema_str)

consumer = Consumer({
    "bootstrap.servers": "localhost:9092",
    "group.id": "order-processor",
    "auto.offset.reset": "earliest"
})
consumer.subscribe(["orders"])

while True:
    msg = consumer.poll(1.0)
    if msg is None:
        continue
    order = avro_deserializer(msg.value(), SerializationContext("orders", MessageField.VALUE))
    print(f"Received order: {order}")
```

---

## 7. Schema Evolution and Compatibility

Schema evolution is Avro's **superpower** — and where it beats almost every other format.

The Schema Registry enforces **compatibility rules** when you try to register a new schema version.

### Compatibility Modes

| Mode | Rule | What You Can Do |
|------|------|----------------|
| `BACKWARD` (default) | New schema can read data written with old schema | Add fields with defaults; delete fields without defaults |
| `FORWARD` | Old schema can read data written with new schema | Add fields without defaults; delete fields with defaults |
| `FULL` | Both backward AND forward compatible | Only add/remove fields that have defaults |
| `NONE` | No compatibility check | Anything goes — dangerous in production |

### Safe Evolution Patterns

```json
// Original schema (v1)
{
  "type": "record",
  "name": "Order",
  "fields": [
    {"name": "order_id",    "type": "long"},
    {"name": "customer_id", "type": "int"},
    {"name": "amount",      "type": "double"}
  ]
}

// v2: Add optional field — SAFE (backward compatible)
{
  "type": "record",
  "name": "Order",
  "fields": [
    {"name": "order_id",    "type": "long"},
    {"name": "customer_id", "type": "int"},
    {"name": "amount",      "type": "double"},
    {"name": "discount",    "type": ["null", "double"], "default": null}
    // ↑ default: null means old consumers reading new data → get null for discount
  ]
}

// v3: Remove a field — SAFE if field had a default
// (Remove 'customer_id' only if old consumers won't break needing it)
```

### Unsafe Evolution Patterns

```json
// ❌ NEVER do these:

// Rename a field (treated as delete old + add new — data is lost)
{"name": "customer_identifier", ...}  // was "customer_id"

// Change a field type incompatibly
{"name": "amount", "type": "string"}  // was "double" — BREAKS everything

// Remove a required field (no default) — BACKWARD INCOMPATIBLE
// Old data had the field; new schema says it doesn't exist
// New consumers reading old data → fail
```

### Checking Compatibility via API

```python
import requests

schema_registry_url = "http://localhost:8081"
subject = "orders-value"

new_schema = {
    "schema": '{"type":"record","name":"Order","fields":[...]}'
}

# Test compatibility before registering
response = requests.post(
    f"{schema_registry_url}/compatibility/subjects/{subject}/versions/latest",
    json=new_schema,
    headers={"Content-Type": "application/vnd.schemaregistry.v1+json"}
)
result = response.json()
print(f"Compatible: {result.get('is_compatible')}")  # True = safe to register
```

---

## 8. Avro vs JSON: Why Avro is Better for Streaming

| | JSON | Avro |
|---|------|------|
| **Format** | Text (UTF-8) | Binary |
| **Size** | Large (field names repeated every record) | Compact (no field names in data — schema defines them) |
| **Speed** | Slow to parse | Fast binary decode |
| **Schema** | None (untyped) | Strongly typed, versioned |
| **Compression** | Possible but applied after text | Binary is already much smaller; Snappy/Deflate on top |

A typical JSON event vs Avro binary for the same record:

```
JSON:  {"order_id":1001,"customer_id":42,"amount":99.99,"status":"PENDING"}
       → 67 bytes as text

Avro:  [varint:1001][varint:42][double:99.99][string:7][P,E,N,D,I,N,G]
       → ~22 bytes binary (67% smaller, no schema overhead per message)
```

At 1 million messages/second, this difference is significant.

---

## 9. Hands-On Labs

### Lab 1 — Write and Read Avro (20 min)

```python
import fastavro

schema = fastavro.parse_schema({
    "type": "record",
    "name": "Order",
    "fields": [
        {"name": "order_id",    "type": "long"},
        {"name": "customer_id", "type": "int"},
        {"name": "amount",      "type": ["null", "double"], "default": None},
        {"name": "status",      "type": "string"},
    ]
})

# Generate 10,000 records and write to Avro
import random
records = [
    {
        "order_id":    i,
        "customer_id": random.randint(1, 100),
        "amount":      round(random.uniform(10, 500), 2),
        "status":      random.choice(["PENDING", "SHIPPED", "DELIVERED"])
    }
    for i in range(1, 10001)
]

with open("orders.avro", "wb") as f:
    fastavro.writer(f, schema, records)

# Read back and count by status
from collections import Counter
with open("orders.avro", "rb") as f:
    loaded = list(fastavro.reader(f))

print(Counter(r["status"] for r in loaded))
```

### Lab 2 — Schema Evolution (20 min)
1. Write records using v1 schema (no `discount` field)
2. Define v2 schema (add `discount` as `["null","double"]` with `default: null`)
3. Read v1 data using v2 schema — verify `discount` is `null` for all rows
4. Try renaming `status` to `order_status` — observe the error or data loss

### Lab 3 — Size Comparison vs JSON (15 min)
1. Write the same 10,000 records as JSON Lines (one JSON object per line)
2. Compare file sizes: `orders.jsonl` vs `orders.avro`
3. Time reading both files using Python

---

## Summary

| Concept | Key Point |
|---------|-----------|
| Row-based | Fast sequential writes; full row must be read for any query |
| Self-describing | Schema is embedded in the file header — no external dependency |
| Kafka integration | Avro + Schema Registry is the standard for typed Kafka messages |
| Schema evolution | Add fields with defaults (safe); never rename or retype fields |
| Compatibility modes | BACKWARD (default), FORWARD, FULL — set per subject in Schema Registry |
| vs Parquet | Avro = fast writes + streaming; Parquet = fast reads + analytics |

---

*Previous: [Module — Apache Parquet](01-parquet.md)*  
*Next: [Module — ORC and Other Formats](03-orc-and-others.md)*  
*Back to: [File Formats README](README.md)*

