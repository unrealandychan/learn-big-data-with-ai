# Module 4.2: Data Organization and Indexing Strategies

**Duration:** 5 hours  
**Prerequisites:** Module 4.1 (Query Execution Plans)  
**Level:** Advanced

---

## Learning Outcomes

- Design partitioning strategies matched to query patterns
- Choose clustering approaches for each platform
- Implement and measure materialized views
- Optimize data order, storage footprint, and statistics

---

## 1. The Core Idea: Stop Reading Data You Don't Need

Every optimization strategy in this module shares one goal: **reduce the amount of data the engine touches**. The hierarchy:

```
1. Don't store unnecessary data (compression, column pruning at design time)
2. Don't read unnecessary files/blocks (partitioning, sort keys, zone maps)
3. Don't recompute what you've already computed (materialized views, caching)
4. Don't move data across nodes (distribution keys, co-location)
```

---

## 2. Partitioning

Partitioning splits a table into separate physical files/segments based on a column's value. When a query filters on the partition column, the engine skips all non-matching partitions entirely.

### 2.1 Choosing a Partition Key

| Query Pattern | Recommended Partition Key |
|---------------|--------------------------|
| Filter by date range (most common) | `DATE(event_time)`, `YEAR/MONTH` |
| Filter by region/country | `region`, `country_code` |
| Filter by tenant/customer | `tenant_id` (if cardinality is manageable) |
| Filter by status | Only if queries are heavily skewed to one value |

**Rule of thumb:** Partition on the column that appears in `WHERE` clauses most often. Avoid columns with very high cardinality (e.g., `user_id` with millions of values = millions of tiny files).

### 2.2 Snowflake — Clustering Keys (Micro-Partitions)

Snowflake automatically partitions data into micro-partitions (~50–500 MB). You can guide which columns are used for pruning:

```sql
-- Create table with clustering key
CREATE TABLE orders (
  order_id      NUMBER,
  customer_id   NUMBER,
  order_date    DATE,
  region        VARCHAR,
  amount        DECIMAL(10,2)
) CLUSTER BY (order_date, region);

-- Check clustering health
SELECT
  system$clustering_depth('orders')           AS depth,
  system$clustering_information('orders')     AS info;
-- Depth < 3 is healthy; > 6 needs reclustering

-- Manually recluster if needed (background task)
ALTER TABLE orders RECLUSTER;

-- Monitor automatic clustering cost
SELECT *
FROM snowflake.account_usage.automatic_clustering_history
ORDER BY start_time DESC
LIMIT 20;
```

### 2.3 Databricks — Delta Lake Partitioning and Z-Order

```python
# Write with partition
df.write \
  .format("delta") \
  .partitionBy("order_date") \
  .mode("overwrite") \
  .save("/delta/orders")

# Z-order: co-locates related values within each partition file
# Use for high-cardinality columns filtered WITHIN a partition
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, "/delta/orders")
delta_table.optimize().zorderBy("customer_id", "region").executeCompaction()

# After Z-order, check the table history
delta_table.history(5).show(truncate=False)
```

**When to use Z-order vs. partitioning:**
- **Partition** → low-cardinality column, always in `WHERE` (e.g., date)
- **Z-order** → high-cardinality column, sometimes in `WHERE` (e.g., customer_id)

```python
# Compact small files first (important before Z-order)
spark.sql("OPTIMIZE delta.`/delta/orders`")
# Then Z-order
spark.sql("OPTIMIZE delta.`/delta/orders` ZORDER BY (customer_id)")
```

### 2.4 BigQuery — Partitioning and Clustering

```sql
-- Partition by date (ingestion time)
CREATE TABLE `project.dataset.orders`
PARTITION BY DATE(order_date)
CLUSTER BY region, customer_id
AS SELECT * FROM `project.dataset.orders_raw`;

-- Check partition metadata
SELECT
  partition_id,
  total_rows,
  total_logical_bytes / 1024 / 1024 AS size_mb
FROM `project.dataset.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'orders'
ORDER BY partition_id DESC
LIMIT 20;

-- Range partitioning (non-date column)
CREATE TABLE `project.dataset.orders_by_id`
PARTITION BY RANGE_BUCKET(order_id, GENERATE_ARRAY(0, 10000000, 100000))
AS SELECT * FROM `project.dataset.orders`;
```

**BigQuery clustering:** After partitioning, clustering further sorts data within each partition by up to 4 columns. Queries filtering on clustered columns scan less data within each partition.

### 2.5 Redshift — Sort Keys and Zone Maps

```sql
-- Compound sort key (good for range queries on first column)
CREATE TABLE orders (
  order_id    BIGINT,
  order_date  DATE       ENCODE az64,
  customer_id INTEGER    ENCODE az64,
  region      VARCHAR(20) ENCODE lzo,
  amount      DECIMAL(10,2) ENCODE az64
)
DISTKEY(customer_id)
SORTKEY(order_date, region);

-- Interleaved sort key (good when multiple columns are equally important)
CREATE TABLE orders_interleaved (
  order_id    BIGINT,
  order_date  DATE,
  customer_id INTEGER,
  region      VARCHAR(20),
  amount      DECIMAL(10,2)
)
DISTKEY(customer_id)
INTERLEAVED SORTKEY(order_date, customer_id, region);

-- Check sort key effectiveness (% of table sorted)
SELECT
  trim(name) AS table_name,
  rows,
  unsorted,
  stats_off
FROM svv_table_info
WHERE schema = 'public'
ORDER BY unsorted DESC;

-- Vacuum to reclaim space and re-sort
VACUUM SORT ONLY orders;
ANALYZE orders;
```

---

## 3. Clustering Depth and Maintenance

Over time, as data is inserted or updated, clustering degrades. Each platform has a way to measure and fix this:

| Platform | Health Metric | Fix Command |
|----------|--------------|-------------|
| Snowflake | `system$clustering_depth()` — target < 3 | `ALTER TABLE ... RECLUSTER` |
| Databricks | `delta.optimize.maxFileSize` + file count | `OPTIMIZE ... ZORDER BY` |
| BigQuery | Partition row counts (check for skew) | Re-partition or re-cluster table |
| Redshift | `svv_table_info.unsorted` — target < 5% | `VACUUM SORT ONLY` |

---

## 4. Materialized Views

A materialized view stores the **result** of a query, not just its definition. When the underlying data changes, the view is refreshed (automatically or manually). Use them for:
- Pre-aggregated summaries queried repeatedly
- Expensive cross-table joins used in dashboards
- Flattened semi-structured data

### 4.1 Snowflake

```sql
-- Create a materialized view
CREATE OR REPLACE MATERIALIZED VIEW mv_daily_revenue AS
SELECT
  order_date,
  region,
  COUNT(*)          AS order_count,
  SUM(amount)       AS total_revenue,
  AVG(amount)       AS avg_order_value
FROM orders
GROUP BY order_date, region;

-- Snowflake auto-refreshes this in the background
-- Query it like a normal table
SELECT * FROM mv_daily_revenue
WHERE order_date >= '2024-01-01'
ORDER BY total_revenue DESC;

-- Check refresh history
SELECT *
FROM snowflake.account_usage.materialized_view_refresh_history
ORDER BY refresh_start_time DESC
LIMIT 10;
```

### 4.2 Databricks — Delta Materialized Pattern

Databricks doesn't have native SQL materialized views in all tiers, but you can implement the pattern with Delta tables:

```python
# Write a "materialized" summary table
daily_revenue = spark.sql("""
  SELECT
    DATE(order_date)  AS order_date,
    region,
    COUNT(*)          AS order_count,
    SUM(amount)       AS total_revenue
  FROM orders
  GROUP BY 1, 2
""")

daily_revenue.write \
  .format("delta") \
  .mode("overwrite") \
  .option("overwriteSchema", "true") \
  .save("/delta/mv_daily_revenue")

# Incremental refresh using MERGE (append only new dates)
spark.sql("""
  MERGE INTO delta.`/delta/mv_daily_revenue` AS target
  USING (
    SELECT DATE(order_date) AS order_date, region,
           COUNT(*) AS order_count, SUM(amount) AS total_revenue
    FROM orders
    WHERE order_date >= CURRENT_DATE() - INTERVAL 3 DAYS
    GROUP BY 1, 2
  ) AS source
  ON target.order_date = source.order_date AND target.region = source.region
  WHEN MATCHED THEN UPDATE SET *
  WHEN NOT MATCHED THEN INSERT *
""")
```

### 4.3 BigQuery

```sql
-- Create materialized view (auto-refreshed within 5 min of source change)
CREATE MATERIALIZED VIEW `project.dataset.mv_daily_revenue`
OPTIONS (
  enable_refresh = true,
  refresh_interval_minutes = 60
)
AS
SELECT
  order_date,
  region,
  COUNT(*)    AS order_count,
  SUM(amount) AS total_revenue,
  AVG(amount) AS avg_order_value
FROM `project.dataset.orders`
GROUP BY order_date, region;

-- BigQuery query rewriting: if you query orders and filter by date+region,
-- BigQuery may automatically use the materialized view instead
```

### 4.4 Redshift

```sql
-- Auto-refreshed materialized view
CREATE MATERIALIZED VIEW mv_daily_revenue
AUTO REFRESH YES
AS
SELECT
  order_date,
  region,
  COUNT(*)    AS order_count,
  SUM(amount) AS total_revenue
FROM orders
GROUP BY order_date, region;

-- Manual refresh
REFRESH MATERIALIZED VIEW mv_daily_revenue;

-- Check staleness
SELECT
  mv_name,
  state,
  state_change_time
FROM stv_mv_info;
```

---

## 5. File Compaction (Databricks / Delta Lake)

Small files are a silent performance killer. Delta Lake accumulates small files from frequent writes.

```python
# Check file count
spark.sql("DESCRIBE DETAIL delta.`/delta/orders`").select("numFiles", "sizeInBytes").show()

# Compact to target file size (default 128MB)
spark.sql("""
  OPTIMIZE delta.`/delta/orders`
  WHERE order_date >= '2024-01-01'
""")

# Enable auto-compaction
spark.conf.set("spark.databricks.delta.autoCompact.enabled", "true")
spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")
```

---

## 6. Storage Footprint Optimization

### Column Compression

| Platform | Approach |
|----------|---------|
| Snowflake | Automatic compression (AZ64, LZO, ZSTD) — no manual action needed |
| Databricks | Parquet handles column encoding automatically; use `ZORDER BY` for data locality |
| BigQuery | Capacitor format handles compression automatically |
| Redshift | Specify encoding: `ENCODE az64` for numbers, `ENCODE lzo` for strings |

```sql
-- Redshift: analyze compression recommendations
ANALYZE COMPRESSION orders;

-- Apply recommended encodings when recreating
CREATE TABLE orders_compressed (
  order_id    BIGINT    ENCODE az64,
  order_date  DATE      ENCODE az64,
  customer_id INTEGER   ENCODE az64,
  region      VARCHAR   ENCODE lzo,
  amount      DECIMAL   ENCODE az64
);
```

### Statistics Management

Outdated statistics cause the optimizer to choose bad plans.

```sql
-- Redshift: update stats after bulk loads
ANALYZE orders;

-- BigQuery: statistics are automatic; no manual ANALYZE needed

-- Snowflake: statistics are maintained automatically

-- Databricks: stats for Delta
spark.sql("ANALYZE TABLE delta.`/delta/orders` COMPUTE STATISTICS FOR ALL COLUMNS")
```

---

## 7. Hands-On Labs

### Lab 1 — Partition Strategy Design (30 min)
Given the following query patterns, design a partition + clustering strategy for each platform:
1. `WHERE order_date = TODAY AND region = 'US'`
2. `WHERE customer_id = 12345 AND status = 'COMPLETED'`
3. `WHERE product_category = 'Electronics' AND price > 500`

### Lab 2 — Clustering Impact Measurement (45 min)
1. Create a table WITHOUT clustering, load 10M rows, run a filtered query, record bytes scanned
2. Recreate WITH clustering on the filter column
3. Re-run the same query — compare bytes scanned and execution time

### Lab 3 — Materialized View for Dashboard (45 min)
1. Identify a "heavy" repeated query in your hands-on labs (e.g., daily revenue by region)
2. Create a materialized view for it
3. Run the original query and compare execution time before vs. after

### Lab 4 — File Compaction (Databricks, 30 min)
1. Write 1,000 micro-batch DataFrames (10 rows each) to a Delta table
2. Check file count: should be ~1,000 files
3. Run `OPTIMIZE` — check file count again
4. Run the original query before and after and compare times

### Lab 5 — Cross-Platform Storage Comparison (60 min)
Load the same 1M-row dataset into all 4 platforms. Record:
- Storage bytes consumed (uncompressed vs. stored)
- Query time on a filtered aggregation
- Which platform prunes the most data

---

## Summary

| Strategy | Best For | Platforms |
|----------|---------|-----------|
| Partitioning | Date/region range filters | All 4 |
| Clustering keys | High-cardinality filters within partitions | Snowflake, BigQuery |
| Z-order | Multi-column local optimization | Databricks (Delta) |
| Sort keys | Range scans on large tables | Redshift |
| Materialized views | Repeated expensive aggregations | All 4 |
| File compaction | Streaming/micro-batch workloads | Databricks (Delta) |
| Column compression | Storage cost reduction | Redshift (manual), others (auto) |

---

*Previous: [Module 4.1 — Query Execution Plans](01-query-execution-plans.md)*  
*Next: [Module 4.3 — Cost Optimization Framework](03-cost-optimization.md)*

