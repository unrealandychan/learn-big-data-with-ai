# Amazon Redshift: Data Loading & Transformation

## Learning Outcomes
- Load data efficiently with COPY command
- Optimize compression and encoding
- Handle large-scale incremental ingestion
- Manage data quality during load

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01

## COPY Command for Batch Loading

```sql
-- Basic COPY from S3
COPY orders
FROM 's3://my-bucket/orders/'
IAM_ROLE 'arn:aws:iam::account:role/redshift-role'
FORMAT AS PARQUET;

-- CSV with options
COPY customers
FROM 's3://my-bucket/customers/2024/*.csv'
IAM_ROLE 'arn:aws:iam::account:role/redshift-role'
FORMAT AS CSV
DELIMITER ','
QUOTE '"'
IGNOREHEADER 1
COMPUPDATE ON
TRUNCATECOLUMNS;

-- With error handling
COPY transactions
FROM 's3://my-bucket/transactions/'
IAM_ROLE 'arn:aws:iam::account:role/redshift-role'
MAXERROR 100
STATUPDATE ON
MANIFEST;
```

## Compression and Encoding

```sql
-- Create table with specific encoding
CREATE TABLE orders_compressed (
  order_id BIGINT ENCODE DELTA,
  customer_id INT ENCODE BYTE,
  order_date DATE ENCODE DELTA32K,
  amount DECIMAL(10,2) ENCODE MOSTLY32,
  description VARCHAR(255) ENCODE TEXT255
);

-- Auto-detect best encoding
CREATE TABLE orders_auto AS
SELECT *
FROM orders_source;

-- ANALYZE for encoding analysis
ANALYZE COMPRESSION orders_auto;
-- Shows which columns benefit from compression
```

## Incremental Loading with Checkpoints

```sql
-- Track last load time
CREATE TABLE load_checkpoints (
  table_name VARCHAR(256),
  last_load_time TIMESTAMP,
  row_count INTEGER
);

-- Incremental load strategy
-- 1. Identify new/changed records
WITH new_data AS (
  SELECT *
  FROM s3://my-bucket/orders/daily/
  WHERE load_date > (SELECT MAX(last_load_time) FROM load_checkpoints WHERE table_name = 'orders')
)
-- 2. Load staging table
COPY staging_orders
FROM 's3://my-bucket/orders/'
WHERE load_date >= CURRENT_DATE - 1
IAM_ROLE 'arn:aws:iam::account:role/redshift-role'
FORMAT AS PARQUET;

-- 3. Merge into target table
INSERT INTO orders
SELECT * FROM staging_orders
WHERE order_id NOT IN (SELECT order_id FROM orders);

-- 4. Update checkpoint
INSERT INTO load_checkpoints
VALUES ('orders', CURRENT_TIMESTAMP, (SELECT COUNT(*) FROM staging_orders));
```

## Data Quality Validation

```sql
-- Post-load validation
SELECT
  table_name,
  row_count,
  DATEDIFF(day, last_load_time, CURRENT_TIMESTAMP) as hours_since_load
FROM load_checkpoints
WHERE row_count > 0
  AND last_load_time > CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY last_load_time DESC;

-- Identify duplicates
SELECT order_id, COUNT(*) as duplicate_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Find null values in critical columns
SELECT
  COUNT(*) as null_count,
  ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2) as null_pct
FROM orders
WHERE customer_id IS NULL OR order_date IS NULL OR amount IS NULL;
```

## Key Concepts

- **COPY:** Distributed loading from S3
- **Encoding:** Compression strategy (DELTA, BYTE, MOSTLY32, TEXT255)
- **IAM Role:** S3 access authentication
- **ANALYZE:** Compression effectiveness analysis
- **Error Handling:** MAXERROR for fault tolerance

## Hands-On Lab

### Part 1: Load Data
1. Create S3 bucket with sample CSV
2. Create IAM role for Redshift
3. Use COPY to load data
4. Verify row count and statistics

### Part 2: Compression
1. Create uncompressed table
2. Create compressed version
3. Compare table size
4. Measure query performance

### Part 3: Incremental Loads
1. Set up checkpoint table
2. Load initial data
3. Load daily increments
4. Verify no duplicates

*See Part 2 of course for complete lab*

*Last Updated: March 2026*
