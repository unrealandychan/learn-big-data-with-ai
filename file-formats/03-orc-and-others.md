# Module: ORC and Other Formats

**Duration:** 1 hour  
**Prerequisites:** Parquet and Avro modules  
**Level:** Intermediate

---

## Learning Outcomes

- Understand ORC's internal structure and when it outperforms Parquet
- Know when JSON Lines and CSV are acceptable vs. harmful
- Understand Delta Lake as a format layer on top of Parquet

---

## 1. Apache ORC (Optimized Row Columnar)

### What Is ORC?

ORC was created in 2013 by Hortonworks and Facebook as a replacement for Hive's existing formats. Like Parquet, it is **columnar** — but it was designed specifically for the **Apache Hive** query engine, with features like:

- File-level ACID transactions (before Delta Lake existed)
- Built-in lightweight indexes (bloom filters, row-level statistics)
- Stripe-level metadata (equivalent to Parquet's row groups)
- Native compression per column (ZLIB, Snappy, LZO, ZSTD)

### ORC Physical Structure

```
ORC File
├── Postscript (metadata about the file)
│
├── File Footer
│   ├── Schema
│   ├── Stripe metadata (offset, length, row count per stripe)
│   └── Column statistics: count, min, max, sum, hasNull
│
├── Stripe 1  (~256 MB default, vs Parquet's 128 MB row groups)
│   ├── Index Data
│   │   └── Row group index (every 10,000 rows): min/max for predicate pushdown
│   ├── Row Data
│   │   └── Column streams (each column separately, like Parquet column chunks)
│   └── Stripe Footer
│       └── Column encoding info per stream
│
├── Stripe 2
│   └── ...
```

### ORC vs Parquet Key Differences

| Feature | ORC | Parquet |
|---------|-----|---------|
| **Created for** | Apache Hive | General purpose (Spark, Hive, Presto) |
| **Default stripe/row group size** | 256 MB | 128 MB |
| **Bloom filters** | ✅ Built-in per column | ✅ Built-in (Parquet 2.0+) |
| **File-level ACID** | ✅ Native (ORC ACID) | ❌ Need Delta/Iceberg on top |
| **Nested types** | ✅ Supported | ✅ Supported |
| **Read performance** | ≈ Parquet (slight edge in Hive) | ≈ ORC (slight edge in Spark) |
| **Ecosystem support** | Hive-heavy; less Spark native | Spark, Databricks, Athena, Presto — near universal |
| **Complex type encoding** | More efficient for maps | More efficient for nested records |

**When to choose ORC over Parquet:**
- Your primary engine is **Apache Hive**
- You need **ORC ACID** transactions without Delta Lake
- You are on an existing Hadoop cluster where ORC is the standard

**When to choose Parquet over ORC:**
- Apache Spark, Databricks, Athena, Presto — essentially everywhere modern
- You want Delta Lake (which uses Parquet as its base)
- You need maximum ecosystem compatibility

### Reading and Writing ORC in PySpark

```python
# Write ORC
df.write \
  .format("orc") \
  .option("compression", "snappy") \
  .mode("overwrite") \
  .save("/data/orders_orc/")

# Read ORC
df = spark.read.format("orc").load("/data/orders_orc/")
df.printSchema()

# ORC with bloom filter for faster equality predicates
df.write \
  .format("orc") \
  .option("orc.bloom.filter.columns", "customer_id,status") \
  .option("orc.bloom.filter.fpp", "0.05") \  # false positive probability
  .save("/data/orders_orc_bloom/")
```

### ORC Bloom Filters

A bloom filter is a probabilistic data structure that answers: **"Is this value definitely NOT in this stripe?"**

```
Query: WHERE customer_id = 42

Without bloom filter:
→ Must check min/max of customer_id in each stripe
→ If 42 is within min/max range, must read the stripe
→ Many false positives → more stripes read

With bloom filter:
→ Bloom filter says "customer_id=42 is DEFINITELY NOT in stripes 3, 5, 7"
→ Those stripes are skipped entirely
→ Especially useful for high-cardinality equality predicates (IDs, UUIDs)
```

---

## 2. JSON Lines (JSONL / NDJSON)

### What Is It?

JSON Lines is a text format where each line is a self-contained, valid JSON object:

```
{"order_id":1,"customer_id":101,"amount":50.00,"status":"SHIPPED"}
{"order_id":2,"customer_id":102,"amount":25.00,"status":"PENDING"}
{"order_id":3,"customer_id":101,"amount":75.00,"status":"CANCELLED"}
```

### When JSON Lines Is Acceptable

| Use Case | OK? | Reason |
|----------|-----|--------|
| API responses / webhooks | ✅ | Easy to parse in any language; schema-flexible |
| Debugging and sampling | ✅ | Human-readable |
| Configuration / small reference data | ✅ | No performance concern |
| Staging area (hours of data before converting) | ✅ | Temporary; convert to Parquet before loading |
| Long-term analytical storage at scale | ❌ | Too large; no column pruning; slow |
| Production Kafka messages | ❌ | Use Avro: typed, compact, schema-governed |
| Data lake storage (millions of rows) | ❌ | 3–10× larger than Parquet; no predicate pushdown |

### Reading JSON Lines in Spark

```python
# Spark can infer schema from JSONL
df = spark.read.json("/data/events/*.jsonl")

# Explicit schema for reliability (schema inference is slow on large datasets)
from pyspark.sql.types import StructType, StructField, LongType, DoubleType, StringType

schema = StructType([
    StructField("order_id",    LongType(),   nullable=False),
    StructField("customer_id", LongType(),   nullable=True),
    StructField("amount",      DoubleType(), nullable=True),
    StructField("status",      StringType(), nullable=True),
])

df = spark.read.schema(schema).json("/data/events/*.jsonl")

# Convert to Parquet for long-term storage
df.write.format("parquet").mode("overwrite").save("/data/orders_parquet/")
```

---

## 3. CSV

### When CSV Is Acceptable

CSV (Comma-Separated Values) is the lowest common denominator format:

| Use Case | OK? |
|----------|-----|
| One-time data exports to Excel/Google Sheets | ✅ |
| Sharing data with non-technical users | ✅ |
| Ingesting from legacy systems with no other option | ✅ |
| Long-term storage or production pipelines | ❌ |
| Any data with commas or newlines in values | ❌ (use quoted fields, but error-prone) |

### CSV Problems at Scale

```
1. No types — everything is a string; "2024-01-01" could be a date or a string
2. No schema — headers are optional and inconsistent
3. No compression metadata — must compress the whole file
4. No column pruning — reading 1 column = reading all columns
5. Encoding issues — UTF-8 vs Latin-1 causes silent corruption
6. Quoting edge cases — values with commas/newlines break naive parsers
```

### Reading CSV in Spark (Properly)

```python
# Never let Spark infer schema from CSV in production
from pyspark.sql.types import *

schema = StructType([
    StructField("order_id",    LongType(),   False),
    StructField("customer_id", IntegerType(), True),
    StructField("amount",      DoubleType(), True),
    StructField("status",      StringType(), True),
    StructField("order_date",  DateType(),   True),
])

df = spark.read \
  .schema(schema) \
  .option("header", "true") \
  .option("delimiter", ",") \
  .option("dateFormat", "yyyy-MM-dd") \
  .option("nullValue", "NULL") \
  .option("mode", "FAILFAST") \   # fail on bad rows, don't silently skip them
  .csv("/data/exports/*.csv")

# Always convert to Parquet immediately
df.write.format("parquet").mode("overwrite").save("/data/orders/")
```

---

## 4. Delta Lake (Format Layer)

Delta Lake is not a raw file format — it's a **storage layer built on top of Parquet**. Understanding it as a "format" helps clarify what it adds.

### What Delta Lake Actually Is

```
/delta/orders/
├── _delta_log/                      ← The transaction log
│   ├── 00000000000000000000.json    ← Commit 0: CREATE TABLE
│   ├── 00000000000000000001.json    ← Commit 1: INSERT 1M rows
│   ├── 00000000000000000002.json    ← Commit 2: UPDATE status='CANCELLED'
│   └── 00000000000000000010.checkpoint.parquet  ← Checkpoint (every 10 commits)
│
├── part-00000-abc123.snappy.parquet  ← Actual data (regular Parquet!)
├── part-00001-def456.snappy.parquet
└── part-00002-ghi789.snappy.parquet
```

The data files ARE regular Parquet. The `_delta_log/` directory records every operation as a JSON commit — this is what adds:

| Feature | How Delta Adds It |
|---------|------------------|
| **ACID transactions** | Each write is a new commit; partial writes are invisible until the commit completes |
| **Time travel** | Query any previous commit: `VERSION AS OF 5` or `TIMESTAMP AS OF '2024-01-01'` |
| **Schema enforcement** | Schema is stored in the log; writes that don't match are rejected |
| **MERGE / UPSERT** | Log records which rows were changed; Parquet files are rewritten only for changed data |
| **Audit history** | Every commit has metadata: what changed, who did it, when |

```python
from delta.tables import DeltaTable

# Write Delta
df.write.format("delta").mode("overwrite").save("/delta/orders/")

# Time travel — read data as it was 5 commits ago
df_old = spark.read \
  .format("delta") \
  .option("versionAsOf", 5) \
  .load("/delta/orders/")

# Time travel by timestamp
df_jan = spark.read \
  .format("delta") \
  .option("timestampAsOf", "2024-01-01") \
  .load("/delta/orders/")

# Show full history
delta_table = DeltaTable.forPath(spark, "/delta/orders/")
delta_table.history().show(truncate=False)

# MERGE (upsert)
delta_table.alias("target").merge(
    source_df.alias("source"),
    "target.order_id = source.order_id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()
```

---

## 5. Format Quick Reference

| Format | Type | Best Write Scenario | Best Read Scenario | Schema | Compression |
|--------|------|--------------------|--------------------|--------|-------------|
| Parquet | Columnar | Batch ETL → analytical storage | Analytical queries (SELECT few columns) | Footer | Per page (Snappy, ZSTD) |
| Avro | Row | Streaming events, Kafka | Sequential full-row reads | Header | Block-level (Snappy, Deflate) |
| ORC | Columnar | Hive pipelines, ACID workloads | Hive analytical queries | Footer | Per column (Snappy, ZLIB) |
| Delta Lake | Columnar + log | DML (INSERT/UPDATE/DELETE/MERGE) | ACID analytics with time travel | Log + footer | Per page (Parquet codecs) |
| JSON Lines | Row (text) | API outputs, debugging | Never at scale | None | External only |
| CSV | Row (text) | Legacy exports, Excel handoffs | Never at scale | None | External only |

---

## Hands-On Lab

### Lab — ORC Bloom Filter vs No Bloom Filter (20 min)

```python
from pyspark.sql import SparkSession
import pyspark.sql.functions as F

spark = SparkSession.builder.appName("orc-lab").getOrCreate()

# Generate 5M row dataset
df = spark.range(5_000_000) \
  .withColumn("customer_id", (F.rand() * 10000).cast("int")) \
  .withColumn("amount",       (F.rand() * 500).cast("double")) \
  .withColumn("status",       F.when(F.rand() < 0.5, "SHIPPED").otherwise("PENDING"))

# Write WITHOUT bloom filter
df.write.format("orc").mode("overwrite").save("/tmp/orders_no_bloom/")

# Write WITH bloom filter on customer_id
df.write \
  .format("orc") \
  .option("orc.bloom.filter.columns", "customer_id") \
  .mode("overwrite") \
  .save("/tmp/orders_bloom/")

# Query both — filter on a specific customer
target = 4242

import time

start = time.time()
spark.read.orc("/tmp/orders_no_bloom/").filter(F.col("customer_id") == target).count()
print(f"No bloom filter: {time.time() - start:.2f}s")

start = time.time()
spark.read.orc("/tmp/orders_bloom/").filter(F.col("customer_id") == target).count()
print(f"With bloom filter: {time.time() - start:.2f}s")
```

---

*Previous: [Module — Apache Avro](02-avro.md)*  
*Next: [Module — Format Comparison](04-format-comparison.md)*  
*Back to: [File Formats README](README.md)*

