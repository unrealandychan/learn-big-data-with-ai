# Module 4.4: Performance Benchmarking and Comparison

**Duration:** 3 hours  
**Prerequisites:** Module 4.3 (Cost Optimization)  
**Level:** Advanced

---

## Learning Outcomes

- Run standardized benchmark tests across platforms
- Compare platform performance fairly and transparently
- Interpret and present benchmark results
- Understand the limits of benchmarks

---

## 1. Why Benchmarks Are Tricky

A benchmark is only meaningful if it's **fair**:

```
Unfair benchmark: Run TPC-H on tuned Snowflake vs. default Redshift
Fair benchmark: Run TPC-H on both platforms with reasonable, equivalent configuration
               for the same workload type and cost tier
```

**Rules for a fair benchmark:**
1. Same data (same rows, same schema)
2. Same query (no platform-specific rewrites that change semantics)
3. Same cost tier (e.g., $X/hour equivalent on both platforms)
4. Cold run + warm run (report both — caching matters)
5. Multiple runs (take median, not min)
6. Document exactly what was configured

---

## 2. Benchmark Dataset: TPC-H at 10GB Scale

TPC-H is an industry-standard benchmark simulating a wholesale supplier database. We use **SF=10** (~10GB uncompressed) — small enough to run on free tiers.

### Schema

```
REGION (5 rows)
  └── NATION (25 rows)
        └── SUPPLIER (100K rows)
        └── CUSTOMER (1.5M rows)
              └── ORDERS (15M rows)
                    └── LINEITEM (60M rows)
PART (2M rows)
PARTSUPP (8M rows)
```

### Loading TPC-H Data

**Snowflake (built-in sample data):**
```sql
-- TPC-H SF=10 is pre-loaded in Snowflake sample data
USE DATABASE snowflake_sample_data;
USE SCHEMA tpch_sf10;
SHOW TABLES;
```

**BigQuery:**
```sql
-- BigQuery public dataset
-- Project: bigquery-public-data, Dataset: tpch
SELECT * FROM `bigquery-public-data.tpch.lineitem` LIMIT 5;
```

**Databricks:**
```python
# Generate TPC-H data using built-in generator (Databricks Runtime 12+)
spark.sql("CREATE DATABASE IF NOT EXISTS tpch")

# Or download from: https://www.tpc.org/tpch/ and load as Parquet
# Use the dbgen tool to generate 10GB scale factor data
```

**Redshift:**
```sql
-- Download TPC-H data to S3, then COPY
COPY lineitem FROM 's3://your-bucket/tpch-sf10/lineitem/'
IAM_ROLE 'arn:aws:iam::your-account:role/RedshiftRole'
FORMAT AS PARQUET;
```

---

## 3. The 20-Query Benchmark Suite

These 20 queries range from simple aggregations to complex multi-table joins and window functions. They are adapted from TPC-H for clarity.

### Simple Aggregations (Q1–Q5)

```sql
-- Q1: Linitem summary by status and ship mode
SELECT
  l_returnflag,
  l_linestatus,
  SUM(l_quantity)                                      AS sum_qty,
  SUM(l_extendedprice)                                 AS sum_base_price,
  SUM(l_extendedprice * (1 - l_discount))             AS sum_disc_price,
  SUM(l_extendedprice * (1 - l_discount) * (1 + l_tax)) AS sum_charge,
  AVG(l_quantity)                                      AS avg_qty,
  AVG(l_extendedprice)                                 AS avg_price,
  AVG(l_discount)                                      AS avg_disc,
  COUNT(*)                                             AS count_order
FROM lineitem
WHERE l_shipdate <= DATE '1998-09-02'
GROUP BY l_returnflag, l_linestatus
ORDER BY l_returnflag, l_linestatus;

-- Q2: Minimum cost supplier per part in Europe
SELECT
  s_acctbal, s_name, n_name, p_partkey, p_mfgr,
  s_address, s_phone, s_comment
FROM part, supplier, partsupp, nation, region
WHERE p_partkey = ps_partkey
  AND s_suppkey = ps_suppkey
  AND p_size = 15
  AND p_type LIKE '%BRASS'
  AND s_nationkey = n_nationkey
  AND n_regionkey = r_regionkey
  AND r_name = 'EUROPE'
  AND ps_supplycost = (
    SELECT MIN(ps_supplycost)
    FROM partsupp, supplier, nation, region
    WHERE p_partkey = ps_partkey
      AND s_suppkey = ps_suppkey
      AND s_nationkey = n_nationkey
      AND n_regionkey = r_regionkey
      AND r_name = 'EUROPE'
  )
ORDER BY s_acctbal DESC, n_name, s_name, p_partkey
LIMIT 100;

-- Q3: Unshipped orders with highest revenue
SELECT
  l_orderkey,
  SUM(l_extendedprice * (1 - l_discount)) AS revenue,
  o_orderdate,
  o_shippriority
FROM customer, orders, lineitem
WHERE c_mktsegment = 'BUILDING'
  AND c_custkey = o_custkey
  AND l_orderkey = o_orderkey
  AND o_orderdate < DATE '1995-03-15'
  AND l_shipdate > DATE '1995-03-15'
GROUP BY l_orderkey, o_orderdate, o_shippriority
ORDER BY revenue DESC, o_orderdate
LIMIT 10;

-- Q4: Order priority checking
SELECT
  o_orderpriority,
  COUNT(*) AS order_count
FROM orders
WHERE o_orderdate >= DATE '1993-07-01'
  AND o_orderdate < DATE '1993-10-01'
  AND EXISTS (
    SELECT * FROM lineitem
    WHERE l_orderkey = o_orderkey
      AND l_commitdate < l_receiptdate
  )
GROUP BY o_orderpriority
ORDER BY o_orderpriority;

-- Q5: Local supplier revenue by region/nation
SELECT
  n_name,
  SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM customer, orders, lineitem, supplier, nation, region
WHERE c_custkey = o_custkey
  AND l_orderkey = o_orderkey
  AND l_suppkey = s_suppkey
  AND c_nationkey = s_nationkey
  AND s_nationkey = n_nationkey
  AND n_regionkey = r_regionkey
  AND r_name = 'ASIA'
  AND o_orderdate >= DATE '1994-01-01'
  AND o_orderdate < DATE '1995-01-01'
GROUP BY n_name
ORDER BY revenue DESC;
```

### Multi-Join Queries (Q6–Q10)

```sql
-- Q6: Revenue change from discounts
SELECT
  SUM(l_extendedprice * l_discount) AS revenue
FROM lineitem
WHERE l_shipdate >= DATE '1994-01-01'
  AND l_shipdate < DATE '1995-01-01'
  AND l_discount BETWEEN 0.05 AND 0.07
  AND l_quantity < 24;

-- Q7: Volume shipping between nations
SELECT
  supp_nation, cust_nation, l_year,
  SUM(volume) AS revenue
FROM (
  SELECT
    n1.n_name AS supp_nation,
    n2.n_name AS cust_nation,
    EXTRACT(YEAR FROM l_shipdate) AS l_year,
    l_extendedprice * (1 - l_discount) AS volume
  FROM supplier, lineitem, orders, customer, nation n1, nation n2
  WHERE s_suppkey = l_suppkey
    AND o_orderkey = l_orderkey
    AND c_custkey = o_custkey
    AND s_nationkey = n1.n_nationkey
    AND c_nationkey = n2.n_nationkey
    AND ((n1.n_name = 'FRANCE' AND n2.n_name = 'GERMANY')
         OR (n1.n_name = 'GERMANY' AND n2.n_name = 'FRANCE'))
    AND l_shipdate BETWEEN DATE '1995-01-01' AND DATE '1996-12-31'
) AS shipping
GROUP BY supp_nation, cust_nation, l_year
ORDER BY supp_nation, cust_nation, l_year;

-- Q8: Market share of a nation over time
SELECT
  o_year,
  SUM(CASE WHEN nation = 'BRAZIL' THEN volume ELSE 0 END) / SUM(volume) AS mkt_share
FROM (
  SELECT
    EXTRACT(YEAR FROM o_orderdate) AS o_year,
    l_extendedprice * (1 - l_discount) AS volume,
    n2.n_name AS nation
  FROM part, supplier, lineitem, orders, customer, nation n1, nation n2, region
  WHERE p_partkey = l_partkey
    AND s_suppkey = l_suppkey
    AND l_orderkey = o_orderkey
    AND o_custkey = c_custkey
    AND c_nationkey = n1.n_nationkey
    AND n1.n_regionkey = r_regionkey
    AND r_name = 'AMERICA'
    AND s_nationkey = n2.n_nationkey
    AND o_orderdate BETWEEN DATE '1995-01-01' AND DATE '1996-12-31'
    AND p_type = 'ECONOMY ANODIZED STEEL'
) AS all_nations
GROUP BY o_year
ORDER BY o_year;
```

### Window Functions (Q11–Q15)

```sql
-- Q11: Top customers by revenue with running total
SELECT
  c_custkey,
  c_name,
  revenue,
  SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) AS running_total,
  RANK() OVER (ORDER BY revenue DESC) AS rank
FROM (
  SELECT
    c_custkey,
    c_name,
    SUM(l_extendedprice * (1 - l_discount)) AS revenue
  FROM customer, orders, lineitem
  WHERE c_custkey = o_custkey
    AND l_orderkey = o_orderkey
    AND o_orderdate >= DATE '1993-10-01'
    AND o_orderdate < DATE '1994-01-01'
  GROUP BY c_custkey, c_name
) revenue_summary
ORDER BY rank
LIMIT 20;

-- Q12: Shipping mode revenue with percentage share
SELECT
  l_shipmode,
  SUM(CASE WHEN o_orderpriority IN ('1-URGENT','2-HIGH') THEN 1 ELSE 0 END) AS high_line_count,
  SUM(CASE WHEN o_orderpriority NOT IN ('1-URGENT','2-HIGH') THEN 1 ELSE 0 END) AS low_line_count,
  COUNT(*) AS total,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM orders, lineitem
WHERE o_orderkey = l_orderkey
  AND l_shipmode IN ('MAIL','SHIP')
  AND l_commitdate < l_receiptdate
  AND l_shipdate < l_commitdate
  AND l_receiptdate >= DATE '1994-01-01'
  AND l_receiptdate < DATE '1995-01-01'
GROUP BY l_shipmode
ORDER BY l_shipmode;

-- Q13: Customer order distribution (including zero-order customers)
SELECT
  c_count,
  COUNT(*) AS custdist
FROM (
  SELECT c_custkey, COUNT(o_orderkey) AS c_count
  FROM customer
  LEFT OUTER JOIN orders ON c_custkey = o_custkey
    AND o_comment NOT LIKE '%special%requests%'
  GROUP BY c_custkey
) AS c_orders
GROUP BY c_count
ORDER BY custdist DESC, c_count DESC;

-- Q14: Promotional revenue contribution
SELECT
  ROUND(100.00 * SUM(CASE WHEN p_type LIKE 'PROMO%'
                     THEN l_extendedprice * (1 - l_discount)
                     ELSE 0 END) /
        SUM(l_extendedprice * (1 - l_discount)), 2) AS promo_revenue
FROM lineitem, part
WHERE l_partkey = p_partkey
  AND l_shipdate >= DATE '1995-09-01'
  AND l_shipdate < DATE '1995-10-01';

-- Q15: Top supplier by revenue in a quarter (using CTE)
WITH revenue AS (
  SELECT
    l_suppkey AS supplier_no,
    SUM(l_extendedprice * (1 - l_discount)) AS total_revenue
  FROM lineitem
  WHERE l_shipdate >= DATE '1996-01-01'
    AND l_shipdate < DATE '1996-04-01'
  GROUP BY l_suppkey
)
SELECT s_suppkey, s_name, s_address, s_phone, total_revenue
FROM supplier, revenue
WHERE s_suppkey = supplier_no
  AND total_revenue = (SELECT MAX(total_revenue) FROM revenue)
ORDER BY s_suppkey;
```

### Subquery and Analytical Patterns (Q16–Q20)

```sql
-- Q16: Part/supplier relationships (NOT IN subquery)
SELECT
  p_brand, p_type, p_size,
  COUNT(DISTINCT ps_suppkey) AS supplier_cnt
FROM partsupp, part
WHERE p_partkey = ps_partkey
  AND p_brand <> 'Brand#45'
  AND p_type NOT LIKE 'MEDIUM POLISHED%'
  AND p_size IN (49, 14, 23, 45, 19, 3, 36, 9)
  AND ps_suppkey NOT IN (
    SELECT s_suppkey FROM supplier
    WHERE s_comment LIKE '%Customer%Complaints%'
  )
GROUP BY p_brand, p_type, p_size
ORDER BY supplier_cnt DESC, p_brand, p_type, p_size;

-- Q17: Average yearly revenue loss from small orders
SELECT
  SUM(l_extendedprice) / 7.0 AS avg_yearly
FROM lineitem, part
WHERE p_partkey = l_partkey
  AND p_brand = 'Brand#23'
  AND p_container = 'MED BOX'
  AND l_quantity < (
    SELECT 0.2 * AVG(l_quantity)
    FROM lineitem
    WHERE l_partkey = p_partkey
  );

-- Q18: Large volume customers
SELECT
  c_name, c_custkey, o_orderkey, o_orderdate, o_totalprice,
  SUM(l_quantity) AS total_qty
FROM customer, orders, lineitem
WHERE o_orderkey IN (
  SELECT l_orderkey FROM lineitem
  GROUP BY l_orderkey HAVING SUM(l_quantity) > 300
)
AND c_custkey = o_custkey
AND o_orderkey = l_orderkey
GROUP BY c_name, c_custkey, o_orderkey, o_orderdate, o_totalprice
ORDER BY o_totalprice DESC, o_orderdate
LIMIT 100;

-- Q19: Discounted revenue across part types and sizes
SELECT
  SUM(l_extendedprice * (1 - l_discount)) AS revenue
FROM lineitem, part
WHERE (
  p_partkey = l_partkey AND p_brand = 'Brand#12'
  AND p_container IN ('SM CASE','SM BOX','SM TRUST','SM PKG')
  AND l_quantity >= 1 AND l_quantity <= 11
  AND p_size BETWEEN 1 AND 5
  AND l_shipmode IN ('AIR','AIR REG')
  AND l_shipinstruct = 'DELIVER IN PERSON'
) OR (
  p_partkey = l_partkey AND p_brand = 'Brand#23'
  AND p_container IN ('MED BAG','MED BOX','MED PKG','MED PACK')
  AND l_quantity >= 10 AND l_quantity <= 20
  AND p_size BETWEEN 1 AND 10
  AND l_shipmode IN ('AIR','AIR REG')
  AND l_shipinstruct = 'DELIVER IN PERSON'
) OR (
  p_partkey = l_partkey AND p_brand = 'Brand#34'
  AND p_container IN ('LG CASE','LG BOX','LG TRUST','LG PKG')
  AND l_quantity >= 20 AND l_quantity <= 30
  AND p_size BETWEEN 1 AND 15
  AND l_shipmode IN ('AIR','AIR REG')
  AND l_shipinstruct = 'DELIVER IN PERSON'
);

-- Q20: Excess inventory suppliers in Europe
SELECT s_name, s_address
FROM supplier, nation
WHERE s_suppkey IN (
  SELECT ps_suppkey FROM partsupp
  WHERE ps_partkey IN (
    SELECT p_partkey FROM part WHERE p_name LIKE 'forest%'
  )
  AND ps_availqty > (
    SELECT 0.5 * SUM(l_quantity)
    FROM lineitem
    WHERE l_partkey = ps_partkey
      AND l_suppkey = ps_suppkey
      AND l_shipdate >= DATE '1994-01-01'
      AND l_shipdate < DATE '1995-01-01'
  )
)
AND s_nationkey = n_nationkey
AND n_name = 'CANADA'
ORDER BY s_name;
```

---

## 4. Running the Benchmark

### Step 1 — Record Configuration

Before running, document:
- Warehouse size / cluster type / slot count
- Estimated hourly cost for this configuration
- Cold vs. warm cache state
- Data format (Parquet / Delta / native columnar)
- Whether clustering/sorting/partitioning is applied

### Step 2 — Benchmark Template

```
| Query | Cold Run 1 (s) | Cold Run 2 (s) | Warm Run (s) | Bytes Scanned | Cost ($) |
|-------|---------------|---------------|-------------|---------------|---------|
| Q1    |               |               |             |               |         |
| Q2    |               |               |             |               |         |
...
| TOTAL |               |               |             |               |         |
```

**Cold run** = first execution (no cached results)  
**Warm run** = second identical execution (may use result/data cache)

### Step 3 — Collect Results

```sql
-- Snowflake: query timing
SELECT
  query_id,
  query_text,
  total_elapsed_time / 1000 AS elapsed_sec,
  bytes_scanned / 1e9 AS gb_scanned
FROM snowflake.account_usage.query_history
WHERE session_id = CURRENT_SESSION()
ORDER BY start_time DESC
LIMIT 20;
```

```sql
-- BigQuery: job timing and bytes
SELECT
  job_id,
  total_bytes_processed / 1e9 AS gb_processed,
  total_slot_ms / 1000 AS slot_seconds,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS elapsed_sec
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
ORDER BY creation_time DESC
LIMIT 20;
```

```python
# Databricks: timing via magic command
%timeit spark.sql("SELECT ...").collect()
```

---

## 5. Interpreting Results

### Metrics That Matter

| Metric | What It Tells You | Watch Out For |
|--------|-------------------|---------------|
| **Wall clock time (cold)** | Real user-perceived latency | Affected by cluster startup (Databricks) |
| **Wall clock time (warm)** | Caching effectiveness | Can be misleadingly fast |
| **Bytes scanned** | Data efficiency of the engine | Affected by partitioning config |
| **Cost per query** | Economic efficiency | Depends on pricing model |
| **Cost per TB-query** | Normalized comparison | Most fair cross-platform metric |

### Common Benchmark Mistakes

| Mistake | How to Avoid |
|---------|-------------|
| Comparing XL Snowflake to S Redshift | Use equivalent cost-tier nodes |
| Only using warm runs | Always include cold runs; note the difference |
| Single query | Use the full 20-query suite |
| One team tuned, one not | Apply basic best practices to all platforms equally |
| Ignoring variance | Run 3× and report median |

---

## 6. Presenting Findings to Stakeholders

Use this structure:

```
1. Context: What workload did we test? What data? What config?
2. Results Summary: 1-2 charts — total time, total cost
3. Key Findings: Top 3 observations (e.g., "BigQuery was 2× faster on scan-heavy queries")
4. Limitations: What we didn't test; what could change the result
5. Recommendation: Given our workload, X performs best because...
```

**Sample Summary Chart Data:**

| Platform | Avg Cold (s) | Avg Warm (s) | Total Cost ($) | Best At |
|----------|-------------|-------------|---------------|---------|
| Snowflake | ? | ? | ? | Concurrent queries, ease of use |
| Databricks | ? | ? | ? | Large joins, ML pipelines |
| BigQuery | ? | ? | ? | Ad-hoc scan-heavy queries |
| Redshift | ? | ? | ? | Co-located MPP joins |

*Fill in your results from the benchmark run.*

---

## 7. Hands-On Labs

### Lab 1 — Single Platform Benchmark (60 min)
1. Load TPC-H SF=10 on your chosen platform
2. Run Q1–Q5 cold, record times and bytes scanned
3. Run Q1–Q5 again (warm run), compare results
4. Write 3 observations

### Lab 2 — Cross-Platform Comparison (90 min)
1. Run Q1, Q3, Q7, Q11, Q18 on at least 2 platforms
2. Fill in the benchmark template from Section 4
3. Calculate cost per query on each platform
4. Prepare a 1-page summary with your recommendation

### Lab 3 — Optimization Before vs. After (45 min)
1. Run Q3 (multi-join) cold and record time
2. Apply one optimization from Module 4.1 or 4.2
3. Re-run Q3 cold — document the improvement
4. Calculate the cost reduction

---

## Summary

| Concept | Key Point |
|---------|-----------|
| Fair benchmarks | Same data, same cost tier, cold + warm, multiple runs |
| TPC-H | Industry-standard benchmark; use SF=10 for free tier |
| Key metric | Cost per query (not just speed) |
| Presenting results | Lead with context and limitations, not just numbers |
| Rule of thumb | No single platform wins on all query types |

---

## What's Next?

You've now completed Level 4. You can:
- Move to [Level 5: Governance & Integration](../governance-integration/README.md)
- Revisit [platform-specific optimization](../platform-comparison/01-architecture-comparison.md) with fresh eyes
- Start the [Capstone Project](../advanced-patterns/01-capstone-project.md) if you've also completed Level 5

---

*Previous: [Module 4.3 — Cost Optimization Framework](03-cost-optimization.md)*  
*Back to: [Optimization README](README.md)*

