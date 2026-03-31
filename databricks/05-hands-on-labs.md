# Databricks: Hands-On Labs & Capstone

## Learning Outcomes
- Implement complete Bronze-Silver-Gold pipeline
- Build production-grade transformations
- Optimize performance and costs
- Deploy to production cluster

**Estimated Time:** 3 hours  
**Prerequisites:** Module 01-04

## Lab 1: Medallion Architecture

### Part 1: Bronze Layer
Create raw ingestion layer with no transformations:

```sql
-- Bronze: Raw data ingestion (no transformations)
CREATE TABLE bronze_customers USING DELTA
LOCATION '/bronze/customers' AS
SELECT
  *,
  current_timestamp() as _ingestion_time,
  input_file_name() as _source_file
FROM (SELECT * FROM cloud_files(
  'gs://bucket/raw/customers/',
  'json',
  map('cloudFiles.schemaInferenceMode', 'rescue')
));
```

### Part 2: Silver Layer
Clean, deduplicate, and standardize:

```sql
-- Silver: Cleansed data
CREATE TABLE silver_customers USING DELTA
LOCATION '/silver/customers' AS
SELECT
  customer_id,
  TRIM(name) as customer_name,
  LOWER(email) as email,
  CAST(created_date AS DATE) as created_date,
  current_timestamp() as _processed_at,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY _ingestion_time DESC) as rn
FROM bronze_customers
WHERE customer_id IS NOT NULL AND email IS NOT NULL;

-- Keep only latest versions
DELETE FROM silver_customers WHERE rn > 1;
```

### Part 3: Gold Layer
Create aggregations and dimensional models:

```sql
-- Gold: Aggregated metrics
CREATE TABLE gold_customer_metrics USING DELTA
LOCATION '/gold/customer_metrics' AS
SELECT
  c.customer_id,
  c.customer_name,
  c.email,
  COUNT(DISTINCT t.transaction_id) as total_transactions,
  SUM(t.amount) as lifetime_value,
  MAX(t.transaction_date) as last_purchase_date,
  CURRENT_TIMESTAMP() as _metrics_calculated_at
FROM silver_customers c
LEFT JOIN silver_transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.customer_name, c.email;
```

## Lab 2: Performance Optimization

### Step 1: Baseline Query
```sql
SELECT * FROM silver_customers WHERE customer_id = 12345;
-- Measure: Execution time (should be >1 second with large data)
```

### Step 2: Add Clustering
```sql
CREATE TABLE silver_customers_clustered USING DELTA
CLUSTER BY customer_id
AS SELECT * FROM silver_customers;
```

### Step 3: Compare Performance
```sql
SELECT * FROM silver_customers_clustered WHERE customer_id = 12345;
-- Measure: Execution time (should be <100ms)
```

### Step 4: Optimize Query
```sql
OPTIMIZE silver_customers_clustered ZORDER BY (customer_id, email);
```

## Lab 3: Cost Analysis

### Track DBU Usage
```python
# Get cluster metrics
cluster_info = dbutils.notebook.run("/Workspace/get_cluster_metrics", 60)

# Calculate costs
# Cost = DBUs used × DBU rate
# Example: 100 DBUs × $0.30 = $30

print(f"Estimated monthly cost: ${100 * 30 * 24 * 30 * 0.30}")
```

### Identify Expensive Queries
```sql
SELECT
  query_text,
  total_execution_time_ms,
  bytes_scanned,
  ROUND(bytes_scanned / 1099511627776, 2) as tb_scanned
FROM system.query_history
WHERE total_execution_time_ms > 60000
ORDER BY total_execution_time_ms DESC
LIMIT 10;
```

## Submission Checklist

- [ ] Azure/AWS credentials configured
- [ ] Databricks workspace accessible
- [ ] All three layers (bronze/silver/gold) created
- [ ] dbt models with tests passing
- [ ] Performance metrics documented
- [ ] Cost analysis completed
- [ ] Airflow DAG scheduled
- [ ] Documentation in GitHub/Wiki

*Last Updated: March 2026*
