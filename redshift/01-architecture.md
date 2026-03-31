# Amazon Redshift: MPP Data Warehouse

## Learning Outcomes
- Understand Redshift's distributed MPP architecture
- Master distribution keys and their impact on performance
- Implement sort keys and compression strategies
- Design scalable cluster configurations
- Optimize query performance with Redshift-specific patterns

**Estimated Time:** 2.5 hours  
**Prerequisites:** Fundamentals modules 1-4

## Redshift Architecture: Massively Parallel Processing

Redshift uses distributed parallel processing across multiple nodes:

```
┌─────────────────────────────────┐
│   Leader Node                   │
│   ├─ Query parsing & planning   │
│   ├─ Compilation                │
│   └─ Result aggregation         │
└────────────┬────────────────────┘
             │
    ┌────────┴────────┬────────────┬─────────┐
    │                 │            │         │
┌───▼────┐       ┌───▼────┐   ┌───▼────┐   ┌───▼────┐
│Compute┼─┐      │Compute │   │Compute │   │Compute │
│ Node 1││ │(copy)│ Node 2 │   │ Node 3 │   │ Node 4 │
└───────┘ │      └────┬───┘   └────┬───┘   └────┬───┘
          │           │            │            │
          └───────────┴────────────┴────────────┘
                   (Network)
```

### Node Types

```
Dense Compute (DC): SSD-based, fast for hot data
├─ dc2.large, dc2.8xlarge
├─ High memory, high I/O
└─ For OLAP workloads

Dense Storage (DS): HDD-based, cost-effective for large volumes
├─ ds2.xlarge, ds2.8xlarge
├─ Large storage, lower cost
└─ For data warehouses

RA3: NVMe + managed storage (newer, flexible)
├─ ra3.xlplus, ra3.4xlarge, ra3.16xlarge
├─ Decoupled storage/compute
└─ Recommended for new clusters
```

## Distribution Keys: Critical Performance Factor

Distribution key determines how rows are distributed across nodes:

```sql
-- Even distribution (default, round-robin)
-- Each row goes to next node in sequence
CREATE TABLE transactions_even (
  transaction_id BIGINT,
  customer_id INT,
  amount DECIMAL(10,2),
  transaction_date DATE
);

-- Key distribution
-- Rows with same key go to same node
-- MUST match join columns for co-location
CREATE TABLE orders_key_dist (
  order_id BIGINT,
  customer_id INT,
  order_date DATE,
  total_amount DECIMAL(10,2)
)
DISTSTYLE KEY
DISTKEY (customer_id);

-- Co-located tables for efficient joins
CREATE TABLE customers_key_dist (
  customer_id INT,
  name VARCHAR(100),
  email VARCHAR(100)
)
DISTSTYLE KEY
DISTKEY (customer_id);

-- This join is efficient (no data redistribution)
SELECT
  o.order_id,
  c.name,
  o.total_amount
FROM orders_key_dist o
JOIN customers_key_dist c ON o.customer_id = c.customer_id
WHERE o.order_date >= '2024-01-01';

-- All distribution
-- Small dimension tables replicated to all nodes
CREATE TABLE product_dim (
  product_id INT,
  product_name VARCHAR(100),
  category VARCHAR(50),
  price DECIMAL(10,2)
)
DISTSTYLE ALL;

-- Efficient join with broadcast dimension
SELECT
  o.order_id,
  p.product_name,
  oi.quantity,
  p.price * oi.quantity as line_total
FROM orders_key_dist o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN product_dim p ON oi.product_id = p.product_id;
```

## Sort Keys: Query Performance Optimization

Sort keys enable zone maps for faster queries:

```sql
-- Single sort key
CREATE TABLE sales_fact (
  sale_id BIGINT,
  customer_id INT,
  product_id INT,
  sale_date DATE,
  amount DECIMAL(10,2),
  quantity INT
)
DISTSTYLE KEY
DISTKEY (customer_id)
SORTKEY (sale_date);

-- Compound sort key (multiple columns)
CREATE TABLE transactions_compound (
  transaction_id BIGINT,
  customer_id INT,
  store_id INT,
  transaction_date DATE,
  amount DECIMAL(10,2)
)
DISTSTYLE KEY
DISTKEY (customer_id)
COMPOUND SORTKEY (transaction_date, store_id);

-- Interleaved sort key (less common, multi-query optimization)
CREATE TABLE events (
  event_id BIGINT,
  user_id INT,
  event_date DATE,
  event_type VARCHAR(50),
  event_timestamp TIMESTAMP
)
DISTSTYLE KEY
DISTKEY (user_id)
INTERLEAVED SORTKEY (event_date, event_type);
```

## Compression and Encoding

Reduce storage and improve query performance:

```sql
-- Check column compression
SELECT
  schema_name,
  table_name,
  column_name,
  encoding,
  distkey,
  sortkey
FROM pg_catalog.pg_table_def
WHERE schema_name = 'public'
ORDER BY table_name, ordinal_position;

-- Manual compression for specific columns
CREATE TABLE events_compressed AS
SELECT
  event_id,
  user_id ENCODE LZO,
  event_date ENCODE DELTA,
  event_type ENCODE BYTEDICT,
  amount ENCODE MOSTLY32,
  description ENCODE TEXT255
FROM events_staging;
```

## Vacuum and Analyze

Maintain optimal performance:

```sql
-- VACUUM: Reclaim space and re-sort
VACUUM sales_fact;

-- VACUUM with specific sort key
VACUUM FULL SORT ONLY sales_fact;

-- ANALYZE: Update statistics for query optimization
ANALYZE sales_fact;

-- Analyze specific column
ANALYZE sales_fact (sale_date, customer_id);
```

## Spectrum: Query External Data

Query data directly in S3 without loading:

```sql
-- Create external schema
CREATE EXTERNAL SCHEMA spectrum_schema
FROM DATA CATALOG
DATABASE 'spectrum_db'
IAM_ROLE 'arn:aws:iam::123456789012:role/redshift-spectrum-role';

-- Create external table (schema inference)
CREATE EXTERNAL TABLE spectrum_schema.sales_external (
  sale_id BIGINT,
  customer_id INT,
  sale_date DATE,
  amount DECIMAL(10,2)
)
STORED AS PARQUET
LOCATION 's3://my-bucket/sales-data/'
TABLE PROPERTIES ('classification'='parquet');

-- Query as if local table
SELECT
  DATE_TRUNC('month', sale_date) as month,
  COUNT(*) as transactions,
  SUM(amount) as revenue
FROM spectrum_schema.sales_external
WHERE sale_date >= '2024-01-01'
GROUP BY DATE_TRUNC('month', sale_date);
```

## Key Concepts

- **MPP:** Rows distributed across nodes for parallel processing
- **DISTKEY:** Distribution strategy critical for join performance
- **SORTKEY:** Physical row ordering for query acceleration
- **Spectrum:** Query external S3 data without loading
- **Zone Maps:** Skip data blocks based on sort order

## Hands-On Lab

### Part 1: Distribution Key Impact
1. Create tables with EVEN, KEY, and ALL distribution
2. Load sample data
3. Query with different joins and observe performance
4. Check query plan for redistribution steps

### Part 2: Sort Key Optimization
1. Add different sort keys to fact table copies
2. Run queries with various filter patterns
3. Compare execution plans and timing
4. Analyze zone map effectiveness

### Part 3: Cluster Configuration
1. Calculate cluster size for your workload
2. Compare node types (DC2 vs RA3 pricing)
3. Plan storage requirements
4. Design scaling strategy

*See Part 2 of course for complete lab walkthrough*

*Last Updated: March 2026*
