# Databricks: Data Loading & Integration

## Learning Outcomes
- Master Spark SQL COPY INTO for efficient data loading
- Implement CDC (Change Data Capture) patterns
- Use Auto Loader for cloud storage ingestion
- Optimize data ingestion performance
- Handle schema evolution gracefully

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01 (Databricks Architecture)

## COPY INTO: Efficient Batch Loading

COPY INTO loads files from cloud storage into Delta tables:

```sql
-- Simple COPY INTO from S3
COPY INTO bronze_customers
FROM 's3://my-bucket/data/customers/'
FILEFORMAT = PARQUET;

-- With format options
COPY INTO bronze_transactions
FROM 's3://my-bucket/data/transactions/'
FILEFORMAT = CSV
FORMAT_OPTIONS ('inferSchema' = 'true', 'header' = 'true');

-- With explicit column mapping and expressions
COPY INTO silver_orders (
  order_id,
  customer_id,
  order_date,
  amount,
  _loaded_at
)
FROM (
  SELECT
    CAST(order_id AS INT),
    CAST(customer_id AS INT),
    CAST(order_date AS DATE),
    CAST(amount AS DECIMAL(10,2)),
    current_timestamp()
  FROM 's3://my-bucket/orders/'
)
FILEFORMAT = JSON
FORMAT_OPTIONS ('badRecordsPath' = 's3://my-bucket/bad-records/');
```

## Auto Loader: Automated Cloud Ingestion

Auto Loader automatically detects new files and ingests incrementally:

```sql
-- Create streaming table with Auto Loader
CREATE OR REPLACE TEMPORARY VIEW raw_events AS
SELECT * FROM cloud_files(
  'C:/my-bucket/events/',
  'json',
  map('cloudFiles.inferColumnTypes', 'true')
);

-- Persist to Delta table
CREATE TABLE IF NOT EXISTS bronze_events AS
SELECT
  current_timestamp() as _ingestion_time,
  _metadata.file_path,
  *
FROM raw_events;

-- Auto Loader with Spark Structured Streaming
CREATE OR REPLACE TABLE bronze_daily_sales USING DELTA AS
SELECT
  window(event_timestamp, '1 day') as event_day,
  COUNT(*) as transactions,
  SUM(amount) as revenue
FROM (
  SELECT * FROM cloud_files(
    's3://my-bucket/sales/',
    'parquet',
    map('cloudFiles.schemaLocation', 's3://my-bucket/.schema',
        'cloudFiles.schemaEvolutionMode', 'addNewColumns')
  )
)
GROUP BY event_day;
```

## Change Data Capture (CDC) Patterns

Implement CDC to capture upstream changes efficiently:

```sql
-- Source system with CDC column
-- (id, name, email, phone, updated_at, change_type)

-- Type 2 SCD using CDC source
MERGE INTO dim_customers t
USING (
  SELECT
    customer_id,
    name,
    email,
    phone,
    updated_at,
    current_timestamp() as processed_at
  FROM bronze_cdc_events
  WHERE change_type IN ('INSERT', 'UPDATE')
    AND processed_at > (SELECT MAX(processed_at) FROM dim_customers WHERE is_current = true)
) s
ON t.customer_id = s.customer_id AND t.is_current = true
WHEN MATCHED AND s.updated_at > t.updated_at THEN
  UPDATE SET
    is_current = false,
    end_date = current_date()
WHEN NOT MATCHED THEN
  INSERT (customer_id, name, email, phone, start_date, end_date, is_current)
  VALUES (s.customer_id, s.name, s.email, s.phone, current_date(), null, true);

-- Handle deletes
DELETE FROM dim_customers
WHERE customer_id IN (
  SELECT customer_id FROM bronze_cdc_events WHERE change_type = 'DELETE'
);
```

## Schema Evolution

Handle changing source schemas gracefully:

```sql
-- Auto-add new columns to table
ALTER TABLE silver_customers
SET TBLPROPERTIES (
  'delta.columnMapping.mode' = 'name',
  'delta.minReaderVersion' = '2',
  'delta.minWriterVersion' = '5'
);

-- Merge with allowMissingColumns
MERGE INTO silver_customers t
USING (
  SELECT
    * EXCEPT (_metadata),
    current_timestamp() as _processed_at
  FROM (
    SELECT * FROM cloud_files(
      's3://my-bucket/customers/',
      'parquet',
      map('cloudFiles.allowMissingColumns', 'true')
    )
  )
) s
ON t.customer_id = s.customer_id
WHEN NOT MATCHED THEN INSERT *
WHEN MATCHED THEN UPDATE SET * EXCLUDING (customer_id);
```

## Incremental Loading Patterns

Optimize repeated loads with checkpoints:

```sql
-- Track last load time
CREATE TABLE IF NOT EXISTS _load_checkpoints (
  table_name STRING,
  last_load_time TIMESTAMP,
  row_count INT
);

-- Load only new data since last checkpoint
COPY INTO silver_orders
FROM (
  SELECT * FROM red '://my-bucket/orders/'
  WHERE extract_date > (
    SELECT COALESCE(MAX(last_load_time), '1900-01-01')
    FROM _load_checkpoints
    WHERE table_name = 'orders'
  )
)
FILEFORMAT = PARQUET;

-- Update checkpoint
INSERT INTO _load_checkpoints
SELECT 'orders', current_timestamp(), COUNT(*)
FROM silver_orders
WHERE _loaded_at >= date_sub(current_date(), 1);
```

## Performance Optimization

Best practices for fast data loading:

```sql
-- Disable optimized writes for faster load
SET spark.databricks.delta.optimizeWrite.enabled = false;

-- Increase parallelism for large files
-- File with 100GB+, set coalesce to match partition count
COPY INTO bronze_large_dataset
FROM 's3://my-bucket/large-files/'
FILEFORMAT = PARQUET
COPY_OPTIONS ('force' = 'true');

-- Use Z-order clustering for frequently filtered columns
CREATE TABLE IF NOT EXISTS gold_transactions
USING DELTA
CLUSTER BY (customer_id, transaction_date)
AS SELECT * FROM silver_transactions;

-- Optimize table after bulk loads
OPTIMIZE silver_orders ZORDER BY (customer_id, order_date);
```

## Hands-On Lab

### Part 1: Auto Loader Setup
1. Create Auto Loader pipeline from S3
2. Test with sample JSON files
3. Add schema evolution handling
4. Monitor ingestion in cluster logs

### Part 2: CDC Implementation
1. Create source table with change_type column
2. Implement merge logic for Type 2 SCD
3. Load sample CDC events
4. Verify dimension table updates

### Part 3: Performance Tuning
1. Compare COPY INTO vs Auto Loader timing
2. Run OPTIMIZE and measure query improvement
3. Test with/without clustering
4. Analyze execution plans

*See Part 2 for complete lab walkthrough and data files*

*Last Updated: March 2026*
