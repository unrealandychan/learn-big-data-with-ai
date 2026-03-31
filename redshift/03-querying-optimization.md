# Amazon Redshift: Query Optimization

## Learning Outcomes
- Design optimal distribution keys
- Choose appropriate sort keys
- Understand query execution plans
- Minimize data redistribution overhead

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01-02

## Distribution Key Strategy

```sql
-- Key Distribution: Rows with same key go to same node
-- Best for: Dimension tables, join keys
CREATE TABLE customers (
  customer_id INT,
  name VARCHAR(100),
  email VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (customer_id);

CREATE TABLE orders (
  order_id BIGINT,
  customer_id INT,
  order_date DATE,
  amount DECIMAL(10,2)
)
DISTSTYLE KEY
DISTKEY (customer_id);

-- EFFICIENT: Co-located join (no redistribution)
SELECT
  o.order_id,
  c.name,
  o.amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date >= '2024-01-01';

-- All Distribution: Small dimension tables
-- Replicated to all nodes
CREATE TABLE product_dim (
  product_id INT,
  product_name VARCHAR(100),
  category VARCHAR(50)
)
DISTSTYLE ALL;

-- Efficient broadcast join
SELECT
  o.order_id,
  p.product_name,
  p.category
FROM orders o
JOIN product_dim p ON o.product_id = p.product_id;

-- Even Distribution: Round-robin
-- Use only when join column not available
CREATE TABLE daily_metrics (
  metric_date DATE,
  metric_value NUMERIC
)
DISTSTYLE EVEN;
```

## Sort Keys Selection

```sql
-- Compound sort key (multiple columns)
CREATE TABLE transactions (
  transaction_id BIGINT,
  customer_id INT,
  transaction_date DATE,
  amount DECIMAL(10,2),
  status VARCHAR(20)
)
DISTSTYLE KEY
DISTKEY (customer_id)
COMPOUND SORTKEY (transaction_date, customer_id);

-- Query benefits from sort key
SELECT
  customer_id,
  SUM(amount) as daily_total,
  COUNT(*) as transaction_count
FROM transactions
WHERE transaction_date >= '2024-01-01'
  AND customer_id IN (100, 101, 102, 103)
GROUP BY customer_id;

-- Interleaved sort key (rare, multi-predicate optimization)
CREATE TABLE events (
  event_id BIGINT,
  user_id INT,
  event_date DATE,
  event_type VARCHAR(50)
)
INTERLEAVED SORTKEY (event_date, event_type);
```

## Query Plan Analysis

```sql
-- View query plan
EXPLAIN
SELECT
  customer_id,
  COUNT(*) as order_count,
  SUM(amount) as total_spent
FROM orders
WHERE order_date >= '2024-01-01'
GROUP BY customer_id;

-- Verbose plan with timing
EXPLAIN ANALYZE
SELECT o.order_id, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id;

-- Analyze plan shows:
-- - Seq Scan or Index Scan
-- - Hash Join or Nested Loop
-- - Aggregate functions
-- - Redistribution steps (red flag)
```

## Avoiding Redistribution

```sql
-- GOOD: Filtered before join
SELECT o.order_id, c.name, o.amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date >= '2024-01-01'
-- Plan: Scan -> Filter -> Hash Join (co-located)

-- BAD: Join then filter (extra data moved)
SELECT o.order_id, c.name, o.amount
FROM orders o
JOIN customers c ON o.order_id = c.customer_id
WHERE o.order_date >= '2024-01-01'
-- Plan: Hash Join -> Redistribution -> Filter
```

## Zone Maps and Statistics

```sql
-- VACUUM: Reclaim space and re-sort
VACUUM orders;

-- ANALYZE: Update statistics
ANALYZE customers;

-- View statistics
SELECT * FROM pg_stats
WHERE tablename = 'orders'
LIMIT 10;

-- Zone maps (automatic)
-- Redshift tracks min/max values per block
-- Enables block-level pruning
```

## Key Concepts

- **DISTKEY:** Distribution column determines node placement
- **SORTKEY:** Physical row ordering for query acceleration
- **Zone Maps:** Block-level min/max for pruning
- **Redistribution:** Cost when keys don't match
- **Vacuum:** Maintenance for optimal performance

## Hands-On Lab

### Part 1: Distribution Impact
1. Create tables with EVEN dist
2. Create tables with KEY dist
3. Run same join query on both
4. Compare execution plans

### Part 2: Sort Key Optimization
1. Create unsorted fact table
2. Add compound sort key
3. Run range and equality queries
4. Measure query time improvement

### Part 3: Query Plan Analysis
1. Generate query plans
2. Identify redistribution steps
3. Redesign tables to minimize redistribution
4. Verify improvement

*See Part 2 of course for complete lab*

*Last Updated: March 2026*
