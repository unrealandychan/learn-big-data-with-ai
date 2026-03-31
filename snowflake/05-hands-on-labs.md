# Snowflake: Hands-On Labs & Capstone

## Learning Outcomes
- Implement end-to-end Snowflake warehouse
- Build dimensional models with Time Travel
- Optimize cluster configuration
- Deploy production pipelines
- Monitor costs and performance

**Estimated Time:** 3 hours  
**Prerequisites:** Module 01-04

## Lab 1: Warehouse & Database Setup

### Part 1: Create Infrastructure
```sql
-- Create compute warehouse
CREATE WAREHOUSE analytics_wh WITH
  WAREHOUSE_SIZE = LARGE
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 3
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = FALSE;

-- Create database
CREATE DATABASE analytics;

-- Create schemas
CREATE SCHEMA raw;
CREATE SCHEMA staging;
CREATE SCHEMA marts;

-- Add lifecycle management
CREATE FILE FORMAT csv_format
TYPE = 'CSV'
COMPRESSION = 'GZIP'
FIELD_DELIMITER = ','
SKIP_HEADER = 1;
```

### Part 2: Load Sample Data
```sql
-- Create raw tables
CREATE TABLE raw.customers (
  customer_id INT,
  name VARCHAR,
  email VARCHAR,
  created_at TIMESTAMP
);

-- Load from stage
PUT file:///data/customers.csv @~/staged;
COPY INTO raw.customers FROM @~/staged
FILE_FORMAT = csv_format;

-- Verify
SELECT COUNT(*) FROM raw.customers;
```

## Lab 2: Time Travel & Zero-Copy Clones

### Part 1: Time Travel Recovery
```sql
-- Accidentally deleted some rows
DELETE FROM raw.customers WHERE customer_id > 1000;

-- Oh no! Recover from 1 hour ago
CREATE TABLE raw.customers_recovered AS
SELECT * FROM raw.customers
AT(OFFSET => -3600);  -- 1 hour ago in seconds

-- Compare row counts
SELECT
  (SELECT COUNT(*) FROM raw.customers) as current_count,
  (SELECT COUNT(*) FROM raw.customers_recovered) as recovered_count;

-- Restore from recovered table
INSERT INTO raw.customers
SELECT * FROM raw.customers_recovered
WHERE customer_id NOT IN (SELECT customer_id FROM raw.customers);
```

### Part 2: Zero-Copy Clone for Testing
```sql
-- Create clone (instant, no additional storage initially)
CREATE TABLE staging.customers_test CLONE staging.customers;

-- Make changes safely (doesn't affect production)
UPDATE staging.customers_test
SET name = UPPER(name)
WHERE LENGTH(name) > 50;

-- Verify changes
SELECT COUNT(*) as modified_count
FROM staging.customers_test
WHERE name LIKE '%COMPANY NAME%';

-- If good, promote; if bad, just drop
DROP TABLE staging.customers_test;
```

## Lab 3: Dimensional Modeling

### Create Fact and Dimension Tables
```sql
-- Dimension: Slowly Changing Dimension Type 2
CREATE TABLE marts.dim_customer_scd2 (
  sk_customer INT IDENTITY,
  customer_id INT,
  name VARCHAR,
  email VARCHAR,
  tier VARCHAR,
  start_date DATE,
  end_date DATE,
  is_current BOOLEAN
) CLUSTER BY (customer_id);

-- Fact: Order transactions
CREATE TABLE marts.fct_orders (
  order_id BIGINT,
  sk_customer INT,
  order_date DATE,
  amount DECIMAL(10,2),
  quantity INT
) CLUSTER BY (order_date, sk_customer);

-- Slowly changing dimension update
MERGE INTO marts.dim_customer_scd2 t
USING (
  SELECT
    customer_id,
    name,
    email,
    tier,
    CURRENT_DATE() as today
  FROM staging.customers_latest
) s
ON t.customer_id = s.customer_id AND t.is_current = TRUE
  AND (t.name != s.name OR t.email != s.email OR t.tier != s.tier)
WHEN MATCHED THEN
  UPDATE SET is_current = FALSE, end_date = s.today - 1
WHEN NOT MATCHED THEN
  INSERT (customer_id, name, email, tier, start_date, end_date, is_current)
  VALUES (s.customer_id, s.name, s.email, s.tier, s.today, NULL, TRUE);
```

## Lab 4: Performance Optimization

### Analyze Warehouse Performance
```sql
-- Check query history and performance
SELECT
  query_id,
  query_text,
  execution_time,
  warehouse_name,
  total_elapsed_time,
  bytes_scanned,
  ROUND(bytes_scanned / POW(10,9), 2) as gb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD('hours', -24, CURRENT_TIMESTAMP())
  AND COMPILATION_TIME > 0
ORDER BY execution_time DESC
LIMIT 20;

-- Identify inefficient queries
SELECT
  query_text,
  COUNT(*) as frequency,
  AVG(execution_time) as avg_time_ms,
  SUM(bytes_scanned) as total_gb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD('days', -7, CURRENT_TIMESTAMP())
GROUP BY query_text
HAVING SUM(bytes_scanned) > 1000000000  -- >1GB
ORDER BY SUM(bytes_scanned) DESC;

-- Apply clustering
ALTER TABLE marts.fct_orders
CLUSTER BY (order_date, sk_customer);

-- Monitor clustering depth
SELECT SYSTEM$CLUSTERING_DEPTH('marts.fct_orders');
```

## Lab 5: Cost Optimization

### Monitor and Control Costs
```sql
-- Warehouse compute costs
SELECT
  warehouse_name,
  SUM(credits_used) as total_credits,
  COUNT(*) as queries,
  ROUND(SUM(credits_used) / COUNT(*), 2) as avg_credits_per_query
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD('days', -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;

-- Set resource monitor
CREATE RESOURCE MONITOR analytics_monitor WITH
  CREDIT_QUOTA = 1000
  FREQUENCY = MONTHLY
  START_TIMESTAMP = '2024-03-01 00:00:00 UTC'
  NOTIFY_USERS = ('data-admin@company.com');

-- Assign warehouse to monitor
ALTER WAREHOUSE analytics_wh SET
  RESOURCE_MONITOR = analytics_monitor;

-- Auto-suspend if overage
ALTER RESOURCE MONITOR analytics_monitor SET
  TRIGGERS ON 80 DO NOTIFY
  ON 100 DO SUSPEND
  ON 110 DO SUSPEND_IMMEDIATE;
```

## Submission Checklist

- [ ] Database and warehouse created
- [ ] Sample data loaded successfully
- [ ] Time Travel recovery demonstrated
- [ ] Zero-Copy Clone created and tested
- [ ] Dimensional model implemented
- [ ] SCD Type 2 updates working
- [ ] Clustering applied and verified
- [ ] Cost monitoring configured
- [ ] Query optimization completed
- [ ] Documentation in git/wiki

## Performance Targets

- Query latency: <5 seconds for standard queries
- Clustering depth: <3 levels
- Cache hit ratio: >60% for repeated queries
- Warehouse utilization: >60%
- Monthly cost: <$5K for 3-10GB data

*Last Updated: March 2026*
