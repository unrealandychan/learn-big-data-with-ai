# Apache Big Data Stack

This module covers the open-source Apache ecosystem that underpins much of the modern data engineering world. Before cloud warehouses dominated, and still today in hybrid and on-premise environments, these tools power the world's largest data pipelines.

## Why Learn the Apache Stack?

Cloud warehouses like Snowflake, BigQuery, and Databricks **run on top of** or were inspired by these technologies. Understanding the Apache stack makes you a more effective engineer because:

- Databricks is built on **Apache Spark** — you're already using it
- Many pipelines still use **Kafka → Flink/Spark → warehouse** architectures
- On-premise and hybrid cloud environments still rely heavily on Hadoop
- Recognizing the origins of cloud abstractions helps you debug, tune, and architect better

---

## Module Contents

| File | Topic | Duration |
|------|-------|----------|
| [`01-hadoop-ecosystem.md`](./01-hadoop-ecosystem.md) | Hadoop: HDFS, MapReduce, YARN, and the ecosystem | 5 hours |
| [`02-apache-spark.md`](./02-apache-spark.md) | Spark: architecture, DataFrames, SQL, Streaming, MLlib | 8 hours |
| [`03-apache-flink.md`](./03-apache-flink.md) | Flink: real-time streaming, event-time, stateful processing | 7 hours |
| [`04-apache-kafka.md`](./04-apache-kafka.md) | Kafka: distributed messaging, the backbone of real-time data | 6 hours |
| [`05-hands-on-labs.md`](./05-hands-on-labs.md) | End-to-end labs connecting all four technologies | 6 hours |

**Total:** ~32 hours

---

## How the Apache Stack Fits Together

```
Raw events / CDC / IoT / Logs
          │
          ▼
  ┌──────────────┐
  │ Apache Kafka │  ← Real-time ingestion bus
  └──────┬───────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 Apache     Apache        ← Stream or batch processing
  Flink      Spark
    │         │
    └────┬────┘
         │
         ▼
  ┌─────────────┐
  │    HDFS /   │   ← Distributed storage
  │  Data Lake  │
  └──────┬──────┘
         │
         ▼
  ┌─────────────────────┐
  │ Cloud Data Warehouse │  ← Analytics layer
  │ (Snowflake, BigQuery,│
  │  Redshift, etc.)    │
  └─────────────────────┘
```

---

## Prerequisites

- Fundamentals modules 1–4 completed
- Basic Python (for PySpark/PyFlink examples)
- Basic command-line familiarity
- Java 8+ or 11 installed (for local Hadoop/Flink)
