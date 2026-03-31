# Data File Formats

**Duration:** 5 hours total  
**Level:** Intermediate  
**Prerequisites:** Fundamentals modules 1–3, basic Apache Stack familiarity

---

## Why File Formats Matter

Every byte your pipeline reads, writes, and stores is encoded in a file format. The choice of format directly affects:

| Concern | Impact |
|---------|--------|
| **Query speed** | Columnar formats skip columns and push down predicates; row formats must read everything |
| **Storage cost** | Format + compression can mean 5–10× difference in bytes stored |
| **Pipeline throughput** | Row formats write faster; columnar formats read faster |
| **Schema evolution** | Some formats break when you add or rename columns; others handle it gracefully |
| **Tool compatibility** | Not every format is supported by every engine |

Choosing the wrong format is one of the most common (and expensive) mistakes in data engineering.

---

## The Big Three

| Format | Style | Best For | Created By |
|--------|-------|---------|------------|
| [**Parquet**](01-parquet.md) | Columnar | Analytical reads, data lakes, cloud warehouses | Twitter + Cloudera (2013) |
| [**Avro**](02-avro.md) | Row-based | Streaming, Kafka, write-heavy ingestion | Apache Hadoop project (2009) |
| [**ORC**](03-orc-and-others.md) | Columnar | Hive-heavy environments, ACID workloads | Hortonworks + Facebook (2013) |

Other formats covered: **JSON Lines**, **CSV**, **Delta Lake** (not a raw format, but worth understanding).

---

## Format Selection Cheat Sheet

```
What are you doing with the data?
│
├── Writing events/messages in real-time (Kafka, CDC)?
│     → Avro  (schema embedded, compact binary, Kafka-native)
│
├── Reading aggregate analytics on large tables?
│     → Parquet  (columnar = skip unused columns, predicate pushdown)
│
├── Using Apache Hive heavily or need file-level ACID?
│     → ORC  (Hive-native, built-in bloom filters, ACID transactions)
│
├── Debugging / external tools / human-readable?
│     → JSON Lines / CSV  (never for production at scale)
│
└── Using Databricks Delta Lake?
      → Delta  (Parquet files + transaction log = best of all worlds)
```

---

## Contents

| # | File | Topic | Time |
|---|------|-------|------|
| 1 | [01-parquet.md](01-parquet.md) | Columnar internals, compression, predicate pushdown, schema evolution | 2 hrs |
| 2 | [02-avro.md](02-avro.md) | Row storage, schema-in-header, Kafka integration, schema evolution | 1.5 hrs |
| 3 | [03-orc-and-others.md](03-orc-and-others.md) | ORC internals, JSON Lines, CSV, Delta Lake as a format | 1 hr |
| 4 | [04-format-comparison.md](04-format-comparison.md) | Side-by-side comparison, benchmarks, decision guide | 0.5 hr |

---

*Part of the [Big Data Warehouse Learning Course](../README.md)*

