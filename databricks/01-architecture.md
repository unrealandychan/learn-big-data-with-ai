# Databricks: Lakehouse Architecture

## Learning Outcomes
- Understand Databricks' lakehouse model and its evolution from data lakes
- Master Delta Lake ACID transactions and versioning capabilities
- Design data medallion architectures (bronze/silver/gold)
- Navigate Databricks workspace and compute options
- Implement Unity Catalog for governance

**Estimated Time:** 2.5 hours  
**Prerequisites:** Fundamentals modules 1-4

## What is the Databricks Lakehouse?

The lakehouse combines the best of data lakes (low-cost, flexible schema, scalability) with data warehouse capabilities (ACID transactions, data quality, performance). Built on Apache Spark and Delta Lake.

### Key Advantages
- **ACID Transactions:** Delta Lake provides traditional database guarantees
- **Time Travel:** Access data from any point in time
- **Schema Enforcement:** Prevent bad data and schema mismatches
- **Unified Platform:** Data engineering, analytics, ML in one system

## Delta Lake Fundamentals

Delta Lake is an open-source storage layer that brings ACID properties to data lakes.

### Creating Delta Tables

```sql
-- Create managed delta table
CREATE TABLE customers (
  customer_id INT,
  name STRING,
  email STRING,
  created_date TIMESTAMP,
  updated_date TIMESTAMP
)
USING DELTA;

-- Create external delta table
CREATE TABLE IF NOT EXISTS transactions (
  transaction_id BIGINT,
  customer_id INT,
  amount DECIMAL(10,2),
  transaction_date TIMESTAMP,
  status STRING
)
USING DELTA
LOCATION 's3://my-bucket/transactions';

-- Create table from Parquet with Delta
CREATE TABLE legacy_data USING DELTA AS
SELECT * FROM parquet.`s3://my-bucket/old_data`;
```

### ACID Transactions and MVCC

Delta Lake uses Multi-Version Concurrency Control (MVCC) to allow simultaneous reads and writes:

```sql
-- Multiple writers can write simultaneously
INSERT INTO customers VALUES (1, 'Alice', 'alice@example.com', current_timestamp(), current_timestamp());

-- Readers see consistent snapshots regardless of concurrent writes
SELECT COUNT(*) FROM customers;

-- All writes succeed or fail atomically
BEGIN TRANSACTION;
  UPDATE customers SET updated_date = current_timestamp() WHERE customer_id = 1;
  DELETE FROM transactions WHERE customer_id = 1;
COMMIT;
```

### Time Travel and Versioning

Access previous versions of data:

```sql
-- Query previous version
SELECT * FROM customers VERSION AS OF 0;

-- Query as of specific timestamp
SELECT * FROM customers TIMESTAMP AS OF '2024-01-15 12:00:00';

-- Show version history
DESCRIBE HISTORY customers;
LIMIT 10;

-- Restore to previous version
RESTORE TABLE customers TO VERSION AS OF 2;
```

## Bronze-Silver-Gold Architecture

The three-layer medallion architecture ensures data quality progression:

```
Bronze (Raw)    -> Silver (Cleaned)    -> Gold (Analytics Ready)
├─ Raw ingestion   ├─ Deduplication    ├─ Dimensional tables
├─ No transforms   ├─ Type casting     ├─ Business metrics
├─ Full history    ├─ Null handling    ├─ Aggregations
└─ Schema inference└─ Validation       └─ Pre-joined views
```

### Implementation Example

```sql
-- Bronze: Raw data ingestion
CREATE TABLE bronze_customers (
  raw_data STRING,
  ingestion_timestamp TIMESTAMP
)
USING DELTA
LOCATION 's3://my-bucket/bronze/customers';

-- Silver: Cleaned and validated
CREATE TABLE silver_customers (
  customer_id INT,
  name STRING,
  email STRING NOT NULL,
  created_date DATE,
  _last_updated TIMESTAMP
)
USING DELTA
LOCATION 's3://my-bucket/silver/customers';

-- Populate silver from bronze
MERGE INTO silver_customers t
USING (
  SELECT
    get_json_object(raw_data, '$.id') as customer_id,
    get_json_object(raw_data, '$.name') as name,
    get_json_object(raw_data, '$.email') as email,
    CAST(get_json_object(raw_data, '$.created_date') AS DATE) as created_date,
    current_timestamp() as _last_updated
  FROM bronze_customers
  WHERE ingestion_timestamp >= (SELECT MAX(_last_updated) FROM silver_customers)
) s
ON t.customer_id = s.customer_id
WHEN MATCHED AND s._last_updated > t._last_updated THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- Gold: Analytics-ready aggregations
CREATE TABLE gold_customer_metrics AS
SELECT
  customer_id,
  name,
  email,
  COUNT(*) as total_purchases,
  SUM(transaction_amount) as lifetime_value,
  MAX(last_purchase_date) as last_purchase_date
FROM silver_customers sc
JOIN silver_transactions st ON sc.customer_id = st.customer_id
GROUP BY customer_id, name, email;
```

## Unity Catalog: Multi-tenant Governance

Unity Catalog (UC) provides centralized governance across Databricks workspaces:

```sql
-- Create catalog (organization-level)
CREATE CATALOG IF NOT EXISTS main;

-- Create schema within catalog
CREATE SCHEMA main.analytics;

-- Create managed table with catalog qualification
CREATE TABLE main.analytics.sales_fact (
  sale_id BIGINT,
  product_id INT,
  customer_id INT,
  sale_amount DECIMAL(10,2),
  sale_date DATE
)
USING DELTA;

-- Set access controls
GRANT SELECT ON SCHEMA main.analytics TO group_name;
GRANT MODIFY ON TABLE main.analytics.sales_fact TO analyst_group;

-- Explore catalog hierarchy
SHOW CATALOGS;
SHOW SCHEMAS IN main;
SHOW TABLES IN main.analytics;

-- Access external locations
CREATE EXTERNAL LOCATION my_s3_location
URL 's3://my-bucket/data'
WITH (CREDENTIAL s3_credential);

CREATE TABLE main.analytics.external_data
USING DELTA
LOCATION 's3://my-bucket/data/';
```

## Cluster and Compute Options

Databricks offers flexible compute for different workloads:

### SQL Warehouses (formerly SQL Endpoints)
- Managed compute for SQL queries
- Auto-scaling based on workload
- Best for: BI tools, SQL analytics

```sql
-- No setup needed - use warehouse directly
SELECT * FROM gold_customer_metrics LIMIT 100;
```

### All-Purpose Clusters
- For interactive development and notebooks
- Supports Python, SQL, R, Scala
- Can run Spark jobs

### Jobs Clusters
- Created on-demand for scheduled jobs
- Cost-efficient for batch processing
- Spin down automatically when job completes

## Key Concepts Review

- **Lakehouse:** Unified system combining lake scalability with warehouse governance
- **Delta Lake:** ACID layer enabling reliable data operations
- **Medallion Architecture:** Three-stage data quality progression
- **Unity Catalog:** Enterprise governance and data discovery
- **MVCC:** Allows concurrent access without locking

## Hands-On Lab

### Part 1: Create Bronze-Silver-Gold Pipeline
1. Create bronze table from raw JSON data
2. Build silver layer with data quality checks
3. Create gold aggregation table
4. Write Merge statements for incremental updates

### Part 2: Time Travel and Versioning
1. Insert data into silver table
2. Query previous versions using TIMESTAMP AS OF
3. Restore table to earlier version
4. Explore version history

### Part 3: Unity Catalog Setup
1. Create catalog and schema structure
2. Set table-level access controls
3. Create external location for cloud storage
4. Grant permissions to analytics group

*See Part 2 of course for complete lab walkthrough*

*Last Updated: March 2026*
