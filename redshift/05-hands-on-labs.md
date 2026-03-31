# Amazon Redshift: Hands-On Labs & Capstone

## Learning Outcomes
- Create and populate Redshift cluster
- Optimize distribution and sort keys
- Benchmark performance improvements
- Deploy production workloads

**Estimated Time:** 3 hours  
**Prerequisites:** Module 01-04

## Lab 1: Cluster Setup & Basic Queries

### Part 1: Create Cluster
```yaml
Cluster Configuration:
├─ Node Type: dc2.large
├─ Node Count: 3
├─ Database Name: analytics_db
├─ Master User: admin
└─ Parameter Group: default
```

### Part 2: Load Sample Data
```sql
-- Create landing zone
CREATE TABLE raw_sales (
  order_id INT,
  customer_id INT,
  product_id INT,
  sale_amount DECIMAL(10,2),
  sale_date DATE
);

-- Load from S3
COPY raw_sales
FROM 's3://data-bucket/sales.parquet'
IAM_ROLE 'arn:aws:iam::account:role/redshift'
FORMAT AS PARQUET;

-- Verify load
SELECT COUNT(*) FROM raw_sales;
SELECT MIN(sale_date), MAX(sale_date) FROM raw_sales;
```

### Part 3: Basic Analytics
```sql
SELECT
  DATE_TRUNC('month', sale_date) as month,
  COUNT(*) as transactions,
  SUM(sale_amount) as revenue,
  AVG(sale_amount) as avg_order
FROM raw_sales
GROUP BY DATE_TRUNC('month', sale_date)
ORDER BY month DESC;
```

## Lab 2: Distribution Key Impact

### Part 1: Create Test Tables
```sql
-- Table with EVEN distribution
CREATE TABLE sales_even (
  order_id INT,
  customer_id INT,
  sale_amount DECIMAL(10,2),
  sale_date DATE
)
DISTSTYLE EVEN;

-- Table with KEY distribution
CREATE TABLE sales_key (
  order_id INT,
  customer_id INT,
  sale_amount DECIMAL(10,2),
  sale_date DATE
)
DISTSTYLE KEY
DISTKEY (customer_id);

-- Load same data to both
INSERT INTO sales_even SELECT * FROM raw_sales;
INSERT INTO sales_key SELECT * FROM raw_sales;
```

### Part 2: Compare Join Performance
```sql
-- Create customer table
CREATE TABLE customers (
  customer_id INT,
  name VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (customer_id);

-- INEFFICIENT: EVEN join (data redistributed)
EXPLAIN SELECT
  s.order_id,
  c.name,
  s.sale_amount
FROM sales_even s
JOIN customers c ON s.customer_id = c.customer_id;

-- EFFICIENT: KEY join (co-located)
EXPLAIN SELECT
  s.order_id,
  c.name,
  s.sale_amount
FROM sales_key s
JOIN customers c ON s.customer_id = c.customer_id;

-- Measure execution time
```

## Lab 3: Sort Key Optimization

### Part 1: Create Sorted Tables
```sql
-- No sort key (baseline)
CREATE TABLE sales_unsorted (
  sale_date DATE,
  customer_id INT,
  sale_amount DECIMAL(10,2)
);

-- With sort key
CREATE TABLE sales_sorted (
  sale_date DATE,
  customer_id INT,
  sale_amount DECIMAL(10,2)
)
COMPOUND SORTKEY (sale_date, customer_id);

-- Load same data
INSERT INTO sales_unsorted SELECT * FROM raw_sales;
INSERT INTO sales_sorted SELECT * FROM raw_sales;
```

### Part 2: Compare Range Queries
```sql
-- Query unsorted table
SELECT SUM(sale_amount)
FROM sales_unsorted
WHERE sale_date >= '2024-01-01' AND sale_date < '2024-02-01';

-- Query sorted table (should be faster)
SELECT SUM(sale_amount)
FROM sales_sorted
WHERE sale_date >= '2024-01-01' AND sale_date < '2024-02-01';

-- Check zone maps effectiveness
SELECT * FROM stl_plan_info
WHERE query_id IN (SELECT query FROM stl_query ORDER BY query DESC LIMIT 2);
```

## Lab 4: Cluster Tuning

### Monitor Performance
```sql
-- Active connections
SELECT * FROM stv_sessions;

-- Current queries
SELECT query, starttime, execution_time
FROM stl_query
WHERE status = 'Running';

-- Storage utilization
SELECT * FROM stv_space_used_recalc;
```

### Optimize Storage
```sql
-- Run VACUUM (reclaim space)
VACUUM FULL SORT ONLY sales_key;

-- Update statistics
ANALYZE sales_key;

-- Check disk usage before/after
SELECT schemaname, tablename, size_gb
FROM stv_space_used_recalc
ORDER BY size_gb DESC;
```

## Submission Checklist

- [ ] Cluster created and running
- [ ] Sample data loaded successfully
- [ ] Distribution key impact measured (show timing)
- [ ] Sort key improvement validated (show query plans)
- [ ] VACUUM and ANALYZE completed
- [ ] Zone map effectiveness documented
- [ ] Query optimization recommendations provided
- [ ] Documentation complete

## Performance Benchmarks

Target improvements:
- Distribution key join: 10-100x faster than EVEN
- Sort key range query: 5-20x faster than unsorted
- VACUUM effectiveness: 15-30% space reclaimed

*Last Updated: March 2026*
