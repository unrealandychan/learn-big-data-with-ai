# Module: Format Comparison & Decision Guide

**Duration:** 30 minutes  
**Prerequisites:** Modules 01–03  
**Level:** Intermediate

---

## The Decision Framework

```
Step 1: What workload type?
    Writing individual events in real-time  →  Avro
    Batch analytical reads                  →  Parquet or ORC
    Need ACID + upserts + time travel       →  Delta Lake (over Parquet)
    Sharing with external teams or systems  →  CSV / JSON Lines (temporary only)

Step 2: What engine?
    Apache Spark / Databricks               →  Parquet or Delta Lake
    Apache Hive                             →  ORC
    Apache Kafka                            →  Avro
    Any engine (max compatibility)          →  Parquet

Step 3: What matters most?
    Read performance                        →  Parquet
    Write performance                       →  Avro or ORC
    Schema versioning & streaming           →  Avro
    Storage cost on cold data               →  Parquet + ZSTD
    ACID transactions without Delta         →  ORC
    Full lakehouse (MERGE, time travel)     →  Delta Lake
```

---

## Side-by-Side Comparison

### Storage & Performance

| | Parquet | Avro | ORC | Delta Lake | JSON Lines | CSV |
|---|---------|------|-----|------------|------------|-----|
| **Storage style** | Columnar | Row | Columnar | Columnar (Parquet) | Row (text) | Row (text) |
| **Typical compression vs CSV** | 5–10× smaller | 3–5× smaller | 5–10× smaller | 5–10× smaller | 1.5–2× | baseline |
| **Read speed (analytics)** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ⭐ |
| **Write speed (streaming)** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Column pruning** | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| **Predicate pushdown** | ✅ Row group skipping | ❌ | ✅ Stripe skipping | ✅ | ❌ | ❌ |
| **Bloom filters** | ✅ (v2+) | ❌ | ✅ Built-in | ✅ (via Parquet) | ❌ | ❌ |

### Schema & Evolution

| | Parquet | Avro | ORC | Delta Lake | JSON Lines | CSV |
|---|---------|------|-----|------------|------------|-----|
| **Schema location** | Footer | Header | Footer | `_delta_log/` | None | Optional header row |
| **Self-describing** | ✅ | ✅ | ✅ | ✅ | ⚠️ (untyped) | ❌ |
| **Add column** | ✅ safe | ✅ safe (with default) | ✅ safe | ✅ + enforced | ✅ informal | ✅ informal |
| **Rename column** | ❌ breaks | ❌ breaks | ❌ breaks | ✅ with column mapping | N/A | N/A |
| **Type change** | ❌ | ❌ unsafe | ❌ | ⚠️ | N/A | N/A |
| **Versioned evolution** | ❌ | ✅ (Schema Registry) | ❌ | ✅ (log) | ❌ | ❌ |

### Features & Ecosystem

| | Parquet | Avro | ORC | Delta Lake | JSON Lines | CSV |
|---|---------|------|-----|------------|------------|-----|
| **ACID transactions** | ❌ | ❌ | ✅ (file-level) | ✅ (table-level) | ❌ | ❌ |
| **Time travel** | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **MERGE / UPSERT** | ❌ | ❌ | ✅ (Hive) | ✅ | ❌ | ❌ |
| **Spark native** | ✅ | ✅ (spark-avro) | ✅ | ✅ | ✅ | ✅ |
| **Kafka native** | ❌ | ✅ | ❌ | ❌ | ⚠️ slow | ❌ |
| **Hive optimized** | ✅ | ✅ | ✅✅ best | ✅ | ⚠️ | ⚠️ |
| **BigQuery ingest** | ✅ | ✅ | ✅ | ✅ (via Parquet) | ✅ | ✅ |
| **Redshift COPY** | ✅ | ✅ | ✅ | ✅ (via Parquet) | ✅ | ✅ |
| **Human readable** | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |

---

## Common Architecture Patterns

### Pattern 1: Kafka → Data Lake → Warehouse

```
[Source Systems]
      │
      ▼ (Avro — typed, compact, schema-governed)
[Kafka Topics]
      │
      ▼ (Spark Structured Streaming or Flink)
[Raw Layer: Parquet on S3/GCS/ADLS]
      │
      ▼ (dbt or Spark batch transform)
[Curated Layer: Delta Lake]
      │
      ▼ (external table or COPY INTO)
[Cloud Warehouse: Snowflake / BigQuery / Redshift]
```

**Formats used:**
- Kafka messages: **Avro** (Schema Registry for governance)
- Raw landing: **Parquet** (fast write, column pruning on read)
- Curated/silver: **Delta Lake** (MERGE for deduplication, schema enforcement)
- Warehouse: native columnar (platform handles format internally)

---

### Pattern 2: Batch ETL from OLTP

```
[PostgreSQL / MySQL]
      │
      ▼ (COPY TO CSV or pg_dump)
[Staging: CSV or JSON on S3]   ← acceptable here; temporary
      │
      ▼ (Spark: read CSV, validate, transform)
[Processed: Parquet on S3]     ← convert immediately
      │
      ▼ (COPY INTO / external table)
[Warehouse]
```

---

### Pattern 3: Hive-Based Hadoop

```
[Ingestion: Sqoop / Flume]
      │
      ▼
[HDFS Raw: Avro or ORC]
      │
      ▼ (Hive ETL)
[HDFS Processed: ORC]   ← ORC is Hive's best format
      │
      ▼
[Hive Analytical Tables: ORC + ACID]
```

---

## Size Benchmark (Same 10M row dataset)

Numbers are approximate — actual ratios vary by data content and cardinality.

| Format + Codec | Approx Size | Read Time (full scan) | Notes |
|----------------|-------------|----------------------|-------|
| CSV (uncompressed) | 1,500 MB | baseline | Reference |
| CSV + GZIP | 420 MB | slow (decompress everything) | Not splittable |
| JSON Lines | 1,800 MB | slow | Field names repeated |
| Avro + Snappy | 380 MB | fast sequential | Best for row-at-a-time |
| ORC + Snappy | 180 MB | fast (Hive) | Best for Hive |
| Parquet + Snappy | 185 MB | fast (Spark) | Best for Spark |
| Parquet + ZSTD | 140 MB | fast (Spark) | Best overall storage efficiency |
| Delta (Parquet + ZSTD) | 145 MB | fast + ACID | Slight overhead from `_delta_log/` |

---

## Schema Evolution Decision Matrix

| You want to... | Use this format | Approach |
|----------------|----------------|---------|
| Add a new optional column | Any (Avro safest) | Avro: add with `default: null`; Parquet: `mergeSchema=true`; Delta: auto |
| Remove a column | Avro (FORWARD compat) | Delete field; old consumers with `default` still work |
| Rename a column | Delta Lake only | Delta column mapping (`RENAME COLUMN`) |
| Change a type safely | Avoid if possible | Avro: `int → long` is safe; `string → int` is never safe |
| Version and audit changes | Avro (Schema Registry) or Delta | Schema Registry keeps version history; Delta logs every schema change |

---

## Quick-Pick Reference Card

```
I'm ingesting streaming events from Kafka          → Avro
I'm storing processed data in a data lake          → Parquet (or Delta)
I'm building a Databricks lakehouse                → Delta Lake
I'm running Hive on Hadoop                         → ORC
I need to send data to a non-technical stakeholder → CSV (small) or JSONL
I need MERGE/UPSERT on a data lake                 → Delta Lake
I need maximum compatibility across all tools      → Parquet
I need schema versioning with full history         → Avro + Schema Registry
I want time travel on my data lake                 → Delta Lake
```

---

*Previous: [ORC and Other Formats](03-orc-and-others.md)*  
*Back to: [File Formats README](README.md)*

