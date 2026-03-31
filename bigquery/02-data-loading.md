# BigQuery: Data Loading & Schema Evolution

## Learning Outcomes
- Load data from multiple sources
- Handle nested and semi-structured data
- Implement schema evolution gracefully
- Optimize load performance

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01

## Loading from Cloud Storage

```sql
-- Load from GCS with format detection
CREATE OR REPLACE TABLE `project`.dataset.orders(
  order_id INT64,
  customer_id INT64,
  order_date DATE,
  items ARRAY<STRUCT<product_id INT64, quantity INT64>>
) AS
SELECT * FROM 
  `project.region-us.EXTERNAL_QUERY_FUNCTION`(
    'gs://my-bucket/orders/*.parquet'
  );

-- Load CSV with auto-detection
CREATE OR REPLACE TABLE `project`.dataset.customers AS
SELECT *
FROM `project`.region-us.EXTERNAL_QUERY_FUNCTION`(
    'SELECT * FROM opencsv.load(\'gs://my-bucket/customers/*.csv\')'
  );
```

## Schema Evolution

```sql
-- Add new column (backward compatible)
ALTER TABLE `project`.dataset.orders
ADD COLUMN promo_code STRING;

-- Add nested column
ALTER TABLE `project`.dataset.orders
ADD COLUMN shipping_info STRUCT<
  address STRING,
  city STRING,
  state STRING
>;

-- Query with evolved schema
SELECT order_id, promo_code, shipping_info.city
FROM `project`.dataset.orders;
```

## Nested Data Handling

```sql
-- UNNEST for flattening
SELECT
  order_id,
  item.product_id,
  item.quantity
FROM `project`.dataset.orders,
UNNEST(items) as item
WHERE ARRAY_LENGTH(items) > 0;

-- CREATE complex nested structure
CREATE TABLE `project`.dataset.customer_profiles AS
SELECT
  customer_id,
  name,
  STRUCT(
    COUNT(*) as order_count,
    SUM(order_amount) as lifetime_value,
    ARRAY_AGG(DISTINCT product_category) as favorite_categories
  ) as purchase_summary
FROM `project`.dataset.customers c
LEFT JOIN `project`.dataset.orders o ON c.customer_id = o.customer_id
GROUP BY customer_id, name;
```

## Key Concepts

- **External Tables:** Query data without loading
- **Schema Inference:** Auto-detect schema or define explicitly
- **UNNEST:** Flatten nested arrays and structs
- **STRUCT:** Nested record type
- **ARRAY:** Repeated values

## Hands-On Lab

### Part 1: Load from GCS
1. Create dataset
2. Load CSV, JSON, Parquet
3. Inspect schema
4. Verify row counts

### Part 2: Handle Nested Data
1. Create table with STRUCT/ARRAY
2. Insert sample nested data
3. Query with UNNEST
4. Aggregate nested values

### Part 3: Schema Evolution
1. Add columns to existing table
2. Verify backward compatibility
3. Query with new columns
4. Update data dictionary

*See Part 2 of course for complete lab*

*Last Updated: March 2026*
