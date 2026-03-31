# BigQuery: Cloud Data Warehouse Architecture

## Learning Outcomes
- Understand BigQuery's columnar storage and query engine architecture
- Master nested STRUCT and ARRAY data types
- Design datasets and optimize slot allocation
- Implement storage optimizations (partitioning, clustering)
- Compare on-demand vs reserved capacity pricing models

**Estimated Time:** 2.5 hours  
**Prerequisites:** Fundamentals modules 1-4

## BigQuery Architecture

BigQuery separates storage and compute using Google Dremel technology:

```
┌─────────────────────────────────────────┐
│    Query Interface (SQL)                │
│    ─Job Scheduler & Execution           │
└──────────────┬──────────────────────────┘
               │
        ┌──────▼──────────┐
        │ Compute Cluster │
        │ (Shuffle Layer) │
        └──────┬──────────┘
               │
        ┌──────▼──────────────────────┐
        │ Google Cloud Storage (GCS)  │
        │ ─Columnar Storage (Dremel)  │
        │ ─Compression & Replication  │
        └─────────────────────────────┘
```

### Key Advantages
- **Petabyte-scale:** Process terabytes in seconds
- **Columnstore:** Only scan needed columns (90%+ resource savings)
- **Serverless:** No cluster management
- **Automatic replication:** 99.99% availability

## Creating and Managing Datasets

Datasets organize tables and views in BigQuery:

```sql
-- Create dataset (database equivalent)
CREATE SCHEMA IF NOT EXISTS project.analytics
OPTIONS(
  description = "Analytics dataset for customer insights",
  location = "US",
  default_table_expiration_ms = 7776000000 -- 90 days
);

-- Set dataset access controls
GRANT `roles/bigquery.dataViewer` ON SCHEMA `project`.analytics
TO "user@company.com";

-- Create table with schema
CREATE OR REPLACE TABLE `project`.analytics.customers (
  customer_id INT64 NOT NULL,
  name STRING,
  email STRING,
  created_date DATE,
  updated_timestamp TIMESTAMP,
  is_active BOOL
)
PARTITION BY DATE(created_date)
CLUSTER BY customer_id, updated_timestamp
OPTIONS(
  description = "Customer dimension table",
  partition_expiration_days = 2555 -- 7 years
);
```

## Nested STRUCT and ARRAY Types

BigQuery's STRUCT and ARRAY enable semi-structured data in tabular format:

```sql
-- Create table with nested data
CREATE OR REPLACE TABLE `project`.analytics.orders_nested (
  order_id INT64,
  customer_id INT64,
  order_info STRUCT<
    order_date DATE,
    total_amount NUMERIC,
    currency STRING,
    status STRING
  >,
  items ARRAY<STRUCT<
    item_id INT64,
    product_name STRING,
    quantity INT64,
    unit_price NUMERIC
  >>,
  shipping_address STRUCT<
    street STRING,
    city STRING,
    state STRING,
    zip_code STRING,
    country STRING
  >
);

-- Insert nested data
INSERT INTO `project`.analytics.orders_nested
SELECT
  order_id,
  customer_id,
  STRUCT(
    order_date,
    total_amount,
    currency,
    order_status
  ) as order_info,
  ARRAY(
    SELECT AS STRUCT
      item_id,
      product_name,
      quantity,
      unit_price
    FROM order_items
    WHERE order_items.order_id = orders.order_id
  ) as items,
  STRUCT(
    street,
    city,
    state,
    zip_code,
    country
  ) as shipping_address
FROM orders;

-- Query nested data with UNNEST
SELECT
  order_id,
  order_info.order_date,
  order_info.total_amount,
  item.product_name,
  item.quantity,
  item.unit_price
FROM `project`.analytics.orders_nested,
UNNEST(items) as item
WHERE order_info.order_date >= '2024-01-01';

-- Access deeply nested fields
SELECT
  order_id,
  shipping_address.city,
  ARRAY_LENGTH(items) as item_count,
  -- Unnest array and aggregate
  ARRAY_AGG(STRUCT(
    item.product_name,
    item.quantity * item.unit_price as line_total
  )) as item_details
FROM `project`.analytics.orders_nested
GROUP BY order_id, shipping_address.city;
```

## Partitioning and Clustering Strategy

Optimize query performance and reduce costs:

```sql
-- Partition by date and cluster for common filters
CREATE OR REPLACE TABLE `project`.analytics.transactions (
  transaction_id INT64,
  customer_id INT64,
  store_id INT64,
  amount NUMERIC,
  transaction_date TIMESTAMP,
  payment_method STRING,
  product_category STRING
)
PARTITION BY DATE(transaction_date)
CLUSTER BY customer_id, store_id, payment_method
OPTIONS(
  description = "Transaction fact table",
  require_partition_filter = true -- Enforce partition filter
);

-- Query with partition and cluster filters (efficient)
SELECT
  DATE(transaction_date) as sale_date,
  payment_method,
  COUNT(*) as transaction_count,
  SUM(amount) as total_sales
FROM `project`.analytics.transactions
WHERE DATE(transaction_date) >= '2024-01-01'
  AND customer_id IN (1, 2, 3, 4, 5)
GROUP BY sale_date, payment_method;

-- Schema evolution - add column
ALTER TABLE `project`.analytics.transactions
ADD COLUMN loyalty_points INT64;
```

## Pricing: On-Demand vs Slots

Choose the right capacity model:

```
On-Demand:
├─ Pay per TB scanned (~$6.25/TB)
├─ No commitment
├─ Flexible for variable workloads
└─ 1 TB free per month

Slots (Reservation):
├─ Fixed monthly cost ($4,000-2,000,000/month)
├─ 100-100,000 slots available
├─ Committed capacity
├─ Better for predictable, high-volume workloads
└─ Flex Slots for up to 100% overcommit
```

## Materialized Views

Pre-compute aggregations for performance:

```sql
-- Create materialized view
CREATE MATERIALIZED VIEW `project`.analytics.daily_sales_summary AS
SELECT
  DATE(transaction_date) as sale_date,
  store_id,
  payment_method,
  COUNT(*) as transaction_count,
  SUM(amount) as total_sales,
  AVG(amount) as avg_transaction,
  MIN(amount) as min_transaction,
  MAX(amount) as max_transaction
FROM `project`.analytics.transactions
WHERE DATE(transaction_date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
GROUP BY sale_date, store_id, payment_method;

-- Enable automatic refresh
ALTER MATERIALIZED VIEW `project`.analytics.daily_sales_summary
SET OPTIONS(enable_refresh = true, refresh_interval_ms = 3600000);

-- Query uses materialized view automatically
SELECT * FROM `project`.analytics.daily_sales_summary
WHERE sale_date = '2024-03-15' AND store_id = 1;
```

## Key Concepts

- **Dremel:** Google's columnar query engine
- **STRUCT/ARRAY:** Semi-structured data in tabular form
- **Partitioning:** Physical table division for query pruning
- **Clustering:** Logical organization within partitions
- **Slots:** Reserved compute capacity

## Hands-On Lab

### Part 1: Dataset and Table Creation
1. Create dataset in your project
2. Create table with nested STRUCT/ARRAY
3. Insert sample hierarchical JSON data
4. Query using UNNEST for nested joins

### Part 2: Partitioning & Clustering
1. Create partitioned table
2. Add clustering keys
3. Compare query costs with/without clustering
4. Analyze execution plans in UI

### Part 3: Capacity Planning
1. Calculate on-demand vs slots cost for your workload
2. Set up materialized view for summary metrics
3. Monitor query costs in Cloud Billing
4. Optimize clustering strategy

*See Part 2 of course for complete lab walkthrough*

*Last Updated: March 2026*
