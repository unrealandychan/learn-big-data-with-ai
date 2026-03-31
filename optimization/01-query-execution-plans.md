# Module 4.1: Query Execution Plans Across Platforms

**Duration:** 4 hours  
**Prerequisites:** All Platform modules OR any 2 platform modules + Fundamentals  
**Level:** Advanced

---

## Learning Outcomes

- Read and interpret execution plans on each platform
- Identify bottlenecks (shuffles, full scans, skewed joins)
- Optimize queries based on plan analysis
- Compare plan efficiency across platforms

---

## 1. What Is an Execution Plan?

When you submit a SQL query, the engine doesn't run your code directly — it compiles it into a **physical plan**: a tree of operations describing exactly how data moves through memory and disk.

```
Your SQL query
     ↓
  Parser → Logical Plan → Optimizer → Physical Plan → Execution
```

Reading the physical plan lets you see:
- Which tables are scanned (and how much data)
- How joins are executed (hash vs. nested loop vs. broadcast)
- Where data is shuffled across nodes
- Where the most time is spent

---

## 2. Snowflake — EXPLAIN and Query Profile

### Getting the Plan

```sql
-- Text plan
EXPLAIN
SELECT c.customer_name, SUM(o.amount) AS total
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date >= '2024-01-01'
GROUP BY c.customer_name
ORDER BY total DESC;
```

### Reading the Profile (Snowflake UI)

Open **Query History → [query] → Query Profile** in the Snowflake UI.

Key nodes to look for:

| Node | What It Means | Red Flag |
|------|---------------|----------|
| `TableScan` | Reading a table | `partitionsTotal >> partitionsScanned` means poor pruning |
| `Join` | Hash join between two streams | Cartesian join (no join key) |
| `Aggregate` | GROUP BY, SUM, COUNT | Spilling to disk ("spill to local storage") |
| `Sort` | ORDER BY | Spilling to disk |
| `ExternalScan` | Reading external stage | Expected; can't prune |

### Common Bottlenecks and Fixes

```sql
-- ❌ BAD: Function on filter column prevents micro-partition pruning
SELECT * FROM orders WHERE YEAR(order_date) = 2024;

-- ✅ GOOD: Direct date range — Snowflake can prune micro-partitions
SELECT * FROM orders
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';

-- ❌ BAD: Leading wildcard — disables search optimization
SELECT * FROM customers WHERE email LIKE '%@gmail.com';

-- ✅ GOOD (if Search Optimization enabled): suffix match
-- ALTER TABLE customers ADD SEARCH OPTIMIZATION ON SUBSTRING(email);
SELECT * FROM customers WHERE email LIKE '%@gmail.com'; -- now uses search index
```

### Detecting Spill to Disk

```sql
-- Check if a query spilled
SELECT
  query_id,
  total_elapsed_time / 1000 AS elapsed_sec,
  bytes_spilled_to_local_storage,
  bytes_spilled_to_remote_storage
FROM snowflake.account_usage.query_history
WHERE query_id = '<your_query_id>';
```

**Fix:** Increase warehouse size (XL → 2XL) or reduce the data being processed before the aggregation.

---

## 3. Databricks — Spark UI and Adaptive Query Execution

### Getting the Plan

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("explain-demo").getOrCreate()

df = spark.sql("""
  SELECT c.customer_name, SUM(o.amount) AS total
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_date >= '2024-01-01'
  GROUP BY c.customer_name
  ORDER BY total DESC
""")

# Show the plan (extended = physical + logical)
df.explain("extended")
# Or formatted (easier to read)
df.explain("formatted")
```

### Reading the Spark UI

Go to **Databricks UI → Cluster → Spark UI → SQL / DataFrame**.

Key stages to watch:

| Stage | What It Means | Red Flag |
|-------|---------------|----------|
| `FileScan` | Reading Delta/Parquet files | `numFiles` very high; push predicates not applied |
| `Exchange` (shuffle) | Data redistribution across nodes | Large shuffle size = slow; `SortMergeJoin` often causes this |
| `BroadcastHashJoin` | Small table broadcast | Good — avoids shuffle |
| `SortMergeJoin` | Two large tables joined | High shuffle bytes = potential to broadcast one side |
| `HashAggregate` | GROUP BY | Spill metric > 0 is a warning |

### Forcing a Broadcast Join

```python
from pyspark.sql.functions import broadcast

# Broadcast the small dimension table to avoid shuffle
result = orders_df.join(broadcast(customers_df), "customer_id")
result.explain()
```

### Adaptive Query Execution (AQE)

AQE (enabled by default in Spark 3.x) automatically:
- Coalesces small shuffle partitions
- Switches join strategies at runtime
- Handles skew joins

```python
# Verify AQE is on
spark.conf.get("spark.sql.adaptive.enabled")  # should be "true"

# AQE will auto-broadcast if it determines one side is small after execution
# You can also set the threshold
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 100 * 1024 * 1024)  # 100 MB
```

### Data Skew Detection

```python
# Check partition sizes — large variance = skew
from pyspark.sql.functions import spark_partition_id, count

orders_df.groupBy(spark_partition_id()).agg(count("*").alias("rows")) \
  .orderBy("rows", ascending=False) \
  .show(20)
```

**Fix:** Use AQE skew join hint, salt the skewed key, or repartition.

---

## 4. BigQuery — Execution Details and INFORMATION_SCHEMA

### Getting the Plan

```sql
-- Use EXPLAIN (preview feature) or check job details in Cloud Console
-- After running a query, click "Execution details" tab in BigQuery UI

-- Or query job metadata
SELECT
  job_id,
  total_bytes_processed,
  total_slot_ms,
  statement_type,
  query
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY total_bytes_processed DESC
LIMIT 10;
```

### Reading the Execution Graph (BigQuery UI)

Click **Execution details** after a query runs. You'll see a DAG of stages:

| Stage | What It Means | Red Flag |
|-------|---------------|----------|
| `Input` | Table/partition scan | Bytes read >> expected; partition filter not applied |
| `Repartition` | Shuffle for JOIN/GROUP BY | High output rows with high skew |
| `Join` | Hash join | Large broadcast side; skewed keys |
| `Aggregate` | GROUP BY, DISTINCT | Slow = large intermediate result |
| `Output` | Writing results | Bytes written to temp table |

### Partition Elimination Check

```sql
-- ❌ BAD: Casting prevents partition elimination
SELECT * FROM `project.dataset.orders`
WHERE CAST(order_date AS STRING) = '2024-03-15';

-- ✅ GOOD: Direct filter on partitioned column
SELECT * FROM `project.dataset.orders`
WHERE order_date = '2024-03-15';

-- Verify partition elimination: check "Bytes processed" in query details
-- A full-table scan on a year's data reads ~365x more than a single day
```

### Slot Usage and Reservation

```sql
-- Check slot consumption per job
SELECT
  job_id,
  total_slot_ms,
  ROUND(total_slot_ms / 1000 / 60, 2) AS slot_minutes
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY total_slot_ms DESC
LIMIT 20;
```

---

## 5. Redshift — EXPLAIN and SVL Tables

### Getting the Plan

```sql
-- Get estimated plan
EXPLAIN
SELECT c.customer_name, SUM(o.amount) AS total
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date >= '2024-01-01'
GROUP BY c.customer_name
ORDER BY total DESC;

-- Get actual execution stats from system tables
SELECT
  query,
  elapsed,
  cpu_time,
  blocks_read,
  rows_processed
FROM svl_query_summary
WHERE query = pg_last_query_id()
ORDER BY seg, step;
```

### Reading the EXPLAIN Output

Key operators in Redshift plans:

| Operator | Description | Watch For |
|----------|-------------|-----------|
| `Seq Scan` | Full table scan | No sort/dist key used |
| `Hash Join` | Hash join (large tables) | DS_BCAST_INNER = broadcasting large table |
| `Nested Loop` | Row-by-row join | Always a red flag at scale |
| `Merge Join` | Sorted input join (efficient) | Ideal for co-located sorted tables |
| `Aggregate` | GROUP BY | Spill to disk in `svl_query_summary` |
| `DS_DIST_NONE` | No redistribution needed | ✅ Good — tables are co-located |
| `DS_BCAST_INNER` | Inner table broadcast to all nodes | OK for small tables |
| `DS_DIST_ALL` | Redistribute all rows | ❌ Expensive — join keys don't match dist keys |

### Detecting Redistribution Issues

```sql
-- Find queries with expensive data redistribution
SELECT
  query,
  step,
  label,
  rows,
  bytes
FROM svl_query_summary
WHERE label LIKE '%DS_DIST%'
  AND query > (SELECT MAX(query) - 100 FROM svl_query_summary)
ORDER BY bytes DESC;
```

**Fix:** Align distribution keys so join columns are co-located on the same node.

---

## 6. Common Bottleneck Patterns (Cross-Platform)

| Pattern | Symptom | Fix |
|---------|---------|-----|
| **Full table scan** | Bytes read >> expected | Add partition filter; use clustering/sort keys |
| **Large shuffle** | Long "exchange" stage; high network I/O | Broadcast small table; change join key; use co-location |
| **Data skew** | One task takes 10× longer than others | Salt the key; AQE skew handling; redistribute |
| **Cartesian join** | Row count explodes | Ensure join condition is present; check for missing `ON` clause |
| **Aggregate spill** | Disk I/O during GROUP BY | Increase memory/warehouse size; pre-aggregate upstream |
| **Unnecessary DISTINCT** | Deduplication on huge set | Check if DISTINCT is truly needed; push down earlier |
| **SELECT \*** | Reading all columns including unused ones | Project only needed columns |

---

## 7. Hands-On Labs

### Lab 1 — Snowflake Plan Reading (45 min)
1. Run the queries below and capture the Query Profile screenshot
2. Identify which node uses the most time (%)
3. Apply one fix and re-run — document the improvement

```sql
-- Baseline: intentionally bad query
SELECT
  YEAR(o.order_date) AS yr,
  c.region,
  COUNT(*) AS orders,
  SUM(o.amount) AS revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY 1, 2
ORDER BY revenue DESC;
```

### Lab 2 — Databricks Plan Analysis (45 min)
1. Run a multi-join query and call `.explain("formatted")`
2. Identify whether `SortMergeJoin` or `BroadcastHashJoin` is used
3. Add a `broadcast()` hint to the smaller table and re-run
4. Compare execution time

### Lab 3 — BigQuery Bytes Scanned Reduction (30 min)
1. Run a query against an unpartitioned table and note bytes scanned
2. Create a partitioned version of the same table
3. Re-run the query with a date filter — compare bytes scanned

### Lab 4 — Redshift Distribution Key Impact (45 min)
1. Run a JOIN query and inspect the EXPLAIN plan for `DS_DIST_ALL`
2. Recreate both tables with matching `DISTKEY` on the join column
3. Re-run and compare plan — `DS_DIST_ALL` should disappear

### Lab 5 — Cross-Platform Comparison (60 min)
Run the same analytical query (provided in [04-performance-benchmarks.md](04-performance-benchmarks.md)) on at least 2 platforms. Document:
- Execution time
- Bytes/data scanned
- Key plan bottleneck
- One fix applied

---

## Summary

| Platform | Plan Command | Key Tool | Main Bottleneck to Watch |
|----------|-------------|----------|--------------------------|
| Snowflake | `EXPLAIN` | Query Profile UI | Partition pruning; disk spill |
| Databricks | `.explain("formatted")` | Spark UI | Shuffle size; skew |
| BigQuery | Execution Details UI | INFORMATION_SCHEMA.JOBS | Bytes scanned; partition filter |
| Redshift | `EXPLAIN` | SVL system tables | Data redistribution (DS_DIST_ALL) |

---

*Next: [Module 4.2 — Data Organization and Indexing Strategies](02-data-organization.md)*

