# Snowflake: Querying & Performance Optimization

## Learning Outcomes
- Optimize Snowflake query execution
- Understand clustering keys and benefits
- Monitor query performance
- Implement caching strategies
- Analyze query plans

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01-02

## Query Optimization Techniques

### Predicate Pushdown and Pruning

```sql
-- Efficient: Partition pruning via clustering key
SELECT * FROM orders
WHERE order_date = CURRENT_DATE()
  AND customer_id = 12345;
-- Only scans micropartitions matching both predicates

-- Inefficient: Function calls prevent pruning
SELECT * FROM orders
WHERE YEAR(order_date) = 2024;
-- Scans all micropartitions (cannot prune on YEAR function)

-- Better: Direct date filter
SELECT * FROM orders
WHERE order_date >= '2024-01-01' AND order_date < '2024-02-01';
```

### Clustering Key Strategy

```sql
-- Create clustered table (on frequently filtered columns)
CREATE OR REPLACE TABLE orders CLUSTER BY (customer_id, order_date) AS
SELECT * FROM raw_orders;

-- Monitor clustering effectiveness
SELECT
  table_name,
  clustering_key,
  system$clustering_depth(orders) as depth,
  system$clustering_information(orders) as info
FROM information_schema.tables
WHERE table_name = 'orders';
```

### Query Result Caching

```sql
-- Results cached for 24 hours by default
SELECT * FROM orders
WHERE DATE(order_date) = '2024-03-15';

-- Re-run same query (milliseconds, from cache)
SELECT * FROM orders
WHERE DATE(order_date) = '2024-03-15';

-- Clear result cache if needed
ALTER SESSION SET USE_CACHED_RESULT = false;
```

## Query Plan Analysis

```sql
-- Explain query plan
EXPLAIN SELECT * FROM orders
WHERE order_date >= '2024-01-01'
  AND customer_id = 123;

-- Detailed plan with statistics
EXPLAIN USING TABULAR SELECT * FROM orders
WHERE order_date >= '2024-01-01';
```

## Materialized Views for Performance

```sql
-- Pre-compute daily aggregations
CREATE OR REPLACE MATERIALIZED VIEW daily_sales AS
SELECT
  DATE(order_date) as sale_date,
  customer_id,
  COUNT(*) as transactions,
  SUM(amount) as revenue
FROM orders
WHERE order_date >= CURRENT_DATE() - 90
GROUP BY DATE(order_date), customer_id;

-- Auto-refresh every hour
ALTER MATERIALIZED VIEW daily_sales SET
  CHANGE_TRACKING = ON
  REFRESH_ON_DEMAND = TRUE
  ENABLE_AUTO_CLUSTERING = TRUE;

-- Query automatically uses materialized view
SELECT * FROM daily_sales
WHERE sale_date = CURRENT_DATE();
```

## Key Concepts

- **Clustering Keys:** Physical organization for faster scans
- **Micropartitions:** Automatic 50-500MB chunks
- **Result Caching:** 24-hour cache of query results
- **Pruning:** Skip micropartitions not matching filter
- **Query Plan:** Explain USING TABULAR for insights

## Hands-On Lab

### Part 1: Clustering Benefits
1. Create table without clustering
2. Create table with clustering
3. Run same query on both
4. Compare execution time

### Part 2: Caching
1. Run query and measure time
2. Re-run same query (should be cached)
3. Modify query slightly (no cache hit)
4. Monitor cache hit/miss ratio

### Part 3: Query Analysis
1. Generate query plans
2. Identify expensive operations
3. Add clustering or indexes
4. Re-analyze and compare

*See Part 2 of course for complete lab*

*Last Updated: March 2026*
