# BigQuery: Query Optimization & Cost Control

## Learning Outcomes
- Write efficient BigQuery SQL
- Use partitioning and clustering
- Monitor query costs in real-time
- Optimize materialized views

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01-02

## Query Best Practices

```sql
-- Best: Only select needed columns
SELECT customer_id, email, created_date
FROM `project`.dataset.customers
WHERE country = 'US';

-- Avoid: SELECT *
SELECT *
FROM `project`.dataset.customers;

-- Efficient aggregation
SELECT
  DATE_TRUNC(order_date, MONTH) as month,
  COUNT(*) as transaction_count,
  SUM(amount) as revenue
FROM `project`.dataset.orders
WHERE DATE(order_date) >= CURRENT_DATE() - 365
GROUP BY month;
```

## Partition and Cluster Impact

```sql
-- Partitioned table: Only scans 1 day
SELECT COUNT(*) FROM `project`.dataset.orders
WHERE DATE(order_date) = '2024-03-15';
-- Scanned: ~100MB (1/(365) of total)

-- Without partitioning: Full table scan
SELECT COUNT(*) FROM `project`.dataset.orders_no_partition
WHERE DATE(order_date) = '2024-03-15';
-- Scanned: 36TB (full table)
```

## Materialized Views for Performance

```sql
-- Pre-compute daily summary
CREATE MATERIALIZED VIEW `project`.dataset.daily_sales_summary AS
SELECT
  DATE(order_date) as sale_date,
  payment_method,
  COUNT(*) as transactions,
  SUM(amount) as revenue,
  AVG(amount) as avg_order
FROM `project`.dataset.orders
WHERE DATE(order_date) >= CURRENT_DATE() - 90
GROUP BY sale_date, payment_method;

-- Auto-refresh hourly
ALTER MATERIALIZED VIEW `project`.dataset.daily_sales_summary
SET OPTIONS(enable_refresh = true, refresh_interval_ms = 3600000);

-- Query uses materialized view automatically
SELECT * FROM `project`.dataset.daily_sales_summary
WHERE payment_method = 'credit_card';
```

## Cost Monitoring

```sql
-- Estimate query cost before running
WITH query_dimensions AS (
  SELECT
    COUNT(*) as row_count,
    BYTES_PROCESSED as bytes_processed
  FROM `project.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
  WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
)
SELECT
  bytes_processed / POW(10, 12) as tb_processed,
  ROUND((bytes_processed / POW(10, 12)) * 6.25, 2) as estimated_cost_usd
FROM query_dimensions;
```

## Key Concepts

- **Partition Pruning:** Query only needed partitions
- **Clustering:** Physical organization within partitions
- **Materialized Views:** Pre-computed aggregations
- **Slot Reservation:** Buy compute capacity upfront
- **Query Cost:** Based on bytes scanned, not time

## Hands-On Lab

### Part 1: Partitioning Effects
1. Query with and without partition filter
2. Compare bytes scanned
3. Monitor query cost
4. Analyze execution plan

### Part 2: Clustering Strategy
1. Create clustered table
2. Run range + equality queries
3. Compare performance
4. Adjust clustering keys

### Part 3: Cost Optimization
1. Identify expensive queries
2. Add partitioning/clustering
3. Measure cost reduction
4. Calculate ROI

*See Part 2 of course for complete lab*

*Last Updated: March 2026*
