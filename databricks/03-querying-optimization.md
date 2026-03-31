# Databricks: Querying & Performance Optimization

## Learning Outcomes
- Optimize Spark SQL query execution
- Master Z-order indexing and clustering
- Implement cost optimization strategies
- Debug slow queries with Spark UI
- Benchmark and compare performance

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01-02

## Spark SQL Query Optimization

### Predicate Pushdown

Filter pushed to storage layer means only relevant data is scanned:

```sql
-- Efficient partition elimination
SELECT * FROM orders
WHERE order_date >= '2024-03-01' 
  AND order_date < '2024-04-01'
  AND amount > 1000;
```

### Join Optimization

```sql
-- Broadcast join for small table
SELECT o.order_id, p.product_name
FROM orders o
JOIN products p ON o.product_id = p.product_id;
```

## Z-Order Clustering

Multi-dimensional indexing:

```sql
-- Create Z-order clustered table
CREATE TABLE orders_zorder USING DELTA
CLUSTER BY (customer_id, order_date)
AS SELECT * FROM orders;

-- Optimize existing table
OPTIMIZE orders_zorder ZORDER BY (customer_id, order_date);
```

## Adaptive Query Execution

```sql
SET spark.sql.adaptive.enabled = true;
SET spark.sql.adaptive.skewJoin.enabled = true;
```

## Key Concepts
- Predicate pushdown: Push filters to storage
- Broadcast joins: Copy small table to all nodes
- Z-order: Multi-column indexing
- AQE: Adaptive optimization at runtime

*Last Updated: March 2026*
