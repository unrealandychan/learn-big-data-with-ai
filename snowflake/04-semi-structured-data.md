# Snowflake: Semi-Structured Data & Advanced Features

## Learning Outcomes
- Query JSON, Parquet, and semi-structured data
- Work with VARIANT and ARRAY types
- Parse nested hierarchies efficiently
- Implement dynamic schema discovery

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01-03

## VARIANT Type for JSON

```sql
-- Store JSON data in VARIANT column
CREATE TABLE json_events (
  event_id INT,
  event_data VARIANT,
  ingestion_timestamp TIMESTAMP
);

-- Insert JSON
INSERT INTO json_events VALUES
(1, PARSE_JSON('{"user_id": 123, "action": "login", "timestamp": "2024-03-27T10:00:00Z"}'), CURRENT_TIMESTAMP()),
(2, PARSE_JSON('{"user_id": 456, "action": "purchase", "amount": 99.99}'), CURRENT_TIMESTAMP());

-- Query VARIANT fields
SELECT
  event_data:user_id::INT as user_id,
  event_data:action::VARCHAR as action,
  event_data:amount::DECIMAL as purchase_amount
FROM json_events;
```

## Flattening Nested Structures

```sql
-- Parse nested JSON arrays
CREATE TABLE orders_with_items (
  order_id INT,
  order_data VARIANT
);

INSERT INTO orders_with_items VALUES
(1, PARSE_JSON('{
  "customer_id": 100,
  "order_date": "2024-03-27",
  "items": [
    {"product_id": 1, "qty": 2, "price": 10.00},
    {"product_id": 2, "qty": 1, "price": 25.00}
  ]
}'::VARIANT));

-- Flatten items array
SELECT
  o.order_id,
  o.order_data:customer_id::INT as customer_id,
  o.order_data:order_date::DATE as order_date,
  i.value:product_id::INT as product_id,
  i.value:qty::INT as quantity,
  i.value:price::DECIMAL as price
FROM orders_with_items o,
LATERAL FLATTEN(INPUT => o.order_data:items) i;
```

## Working with Parquet

```sql
-- Create table from Parquet files in stage
CREATE OR REPLACE TABLE parquet_data AS
SELECT *
FROM @my_stage/data/*.parquet
(FILE_FORMAT = (TYPE = 'PARQUET'));

-- Query Parquet directly without loading
SELECT * FROM
  @my_stage/large_dataset.parquet
(FILE_FORMAT = (TYPE = 'PARQUET'))
LIMIT 100;
```

## Dynamic Schema Discovery

```sql
-- Automatic schema inference for nested data
CREATE OR REPLACE TABLE auto_schema AS
SELECT
  $1:id as id,
  $1:name as name,
  $1:email as email,
  $1 as raw_data
FROM (
  SELECT * FROM @my_stage/customers.json
)
WHERE $1 IS NOT NULL;

-- Schema from Parquet inference
SELECT INFER_SCHEMA(LOCATION => '@my_stage/parquet_folder/')
FROM TABLE (RESULT_SCAN(LAST_QUERY_ID()));
```

## Processing Large JSON

```sql
-- Efficient JSON processing for 100GB+ files
CREATE EXTERNAL TABLE external_json (
  raw_data VARIANT
)
LOCATION = 's3://my-bucket/json-data/'
FILE_FORMAT = (TYPE = 'JSON', COMPRESSION = 'GZIP');

-- Query without full load
SELECT
  raw_data:user_id,
  raw_data:action,
  COUNT(*) as action_count
FROM external_json
GROUP BY raw_data:user_id, raw_data:action;
```

## Key Concepts

- **VARIANT:** Flexible column type for semi-structured data
- **FLATTEN:** Explode arrays and objects
- **External Tables:** Query cloud data directly
- **PARSE_JSON:** Convert string to parsed JSON
- **Dynamic Schema:** Auto-detect structure

## Hands-On Lab

### Part 1: JSON Processing
1. Load JSON sample data
2. Parse nested fields with VARIANT
3. Extract multiple levels
4. Compare performance vs relational

### Part 2: FLATTEN Nested Arrays
1. Create nested array data
2. Use LATERAL FLATTEN
3. Create fact table from flattened data
4. Validate cardinality

### Part 3: Semi-Structured Files
1. Load Parquet files to stage
2. Query without COPY
3. Infer schema automatically
4. Create managed table

*See Part 2 of course for complete lab*

*Last Updated: March 2026*
