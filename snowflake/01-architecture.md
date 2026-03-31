# Snowflake Architecture: Compute/Storage Separation

## Learning Outcomes

By completing this module, you should be able to:
- Explain Snowflake's unique compute/storage separation architecture
- Understand warehouse sizing and performance implications
- Leverage Time Travel for data recovery and testing
- Use Zero-Copy Clones for safe experimentation
- Choose appropriate Snowflake editions and deployment options

**Estimated Time:** 1.5-2 hours  
**Prerequisites:** Fundamentals 1-4

---

## 1. The Compute/Storage Separation Model

### Traditional Data Warehouse Architecture (Old Way)

```
┌─────────────────────────────────────────┐
│  Data + Compute + Memory (Tightly Coupled) │
│  Scale up by buying bigger hardware     │
│  Single machine or cluster limitation   │
└─────────────────────────────────────────┘
```

**Problems:**
- Can't scale either independently
- Storage full? Must upgrade entire system
- Query needs more power? Must buy bigger machines
- Unused resources during off-peak hours

### Snowflake's Cloud-Native Approach (Modern Way)

```
┌──────────────────────┐     ┌─────────────────────┐
│   Compute Layer      │     │   Storage Layer     │
│   (Virtual          │     │   (Cloud Storage:   │
│    Warehouses)      │     │    S3/Azure/GCS)    │
│                     │     │                     │
│   Multiple          │     │   Shared by all     │
│   warehouses can    │     │   warehouses        │
│   scale            │     │                     │
│   independently    │     │   Unlimited         │
│                     │     │   scalability       │
└──────────────────────┘     └─────────────────────┘
```

**Advantages:**
- Scale compute and storage independently
- Fair pricing (pay only for what you use)
- Multiple teams query same data without contention
- No resource conflicts

---

## 2. Virtual Warehouses: Compute Units

### What is a Virtual Warehouse?

A **virtual warehouse** is a cluster of compute resources (CPU, RAM, SSD cache) that Snowflake manages for you.

### Warehouse Sizes

| Size | Credits/sec | Use Case |
|------|------------|----------|
| XSMALL | 1 | Dev/test, small ad-hoc queries |
| SMALL | 2 | Light analytics, BI queries |
| MEDIUM | 4 | Standard analytics workloads |
| LARGE | 8 | Complex queries, many users |
| XLARGE | 16 | Heavy workloads, many parallel queries |
| 2XLARGE+ | 32+ | Enterprise scale |

**Key Point:** Bigger warehouse = faster queries but more expensive

### Warehouse Configuration

```sql
-- Create a warehouse
CREATE WAREHOUSE my_warehouse 
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 10        -- Suspend after 10 mins idle
  AUTO_RESUME = TRUE        -- Auto-resume on query
  MAX_CLUSTER_COUNT = 3     -- Max cluster for scaling
  MIN_CLUSTER_COUNT = 1;    -- Min cluster

-- Suspend manually (stops billing)
ALTER WAREHOUSE my_warehouse SUSPEND;

-- Resume to use again
ALTER WAREHOUSE my_warehouse RESUME;

-- Change size
ALTER WAREHOUSE my_warehouse SET WAREHOUSE_SIZE = 'LARGE';
```

### How Scaling Works

When warehouse is **MEDIUM** with 1 cluster:
- Queries run on 1 cluster
- CPU fully utilized → Query slows down

Solution: **Scaling**
- Create multi-cluster warehouse
- Each new query gets its own cluster
- Parallel query execution

```sql
-- Multi-cluster warehouse scales automatically
CREATE WAREHOUSE analytics_wh 
  WAREHOUSE_SIZE = 'MEDIUM'
  MAX_CLUSTER_COUNT = 5      -- Up to 5 clusters
  SCALING_POLICY = 'STANDARD';

-- When query arrives:
-- If clusters available → use one
-- If all busy → create new (up to MAX_CLUSTER_COUNT)
```

---

## 3. Time Travel: Access Historical Data

**Problem:** Data was deleted or modified incorrectly. Can you recover it?

**Traditional Solution:** Restore from backup (hours of downtime)

**Snowflake Solution:** Time Travel (instant recovery)

### Time Travel Concept

```
Time ─────────────────────────→
     v1      v2      v3      current
┌────░──┬────░──┬────░──┬────░──┐
│ Kept  │ Kept  │ Kept  │Active │
└───────┴───────┴───────┴───────┘
                               
0-10 min ago can always recover
(Standard Edition, all the way back to actual data retention period)
```

### Time Travel Examples

**Scenario: Accidental DELETE**

```sql
-- Someone ran (oops!):
DELETE FROM dim_customers WHERE region = 'Northeast';
-- 50,000 rows deleted

-- Recover using Time Travel:
-- Query data from 5 minutes ago (before delete)
SELECT * FROM dim_customers 
  AT(OFFSET => -5 * 60)  -- 5 minutes ago
WHERE region = 'Northeast';

-- Or restore entire table
CREATE TABLE dim_customers_restored AS
SELECT * FROM dim_customers 
  BEFORE(STATEMENT => '8eb7b274-a916-46f5-8b92-f85df06146cb');

-- Then swap tables
ALTER TABLE dim_customers RENAME TO dim_customers_deleted;
ALTER TABLE dim_customers_restored RENAME TO dim_customers;
```

**Scenario: Bad Data Load**

```sql
-- Check data at different times
SELECT COUNT(*) FROM fact_orders 
  AT(TIMESTAMP => '2025-03-27 10:00:00'::TIMESTAMP_NTZ);
-- 1000000 rows

SELECT COUNT(*) FROM fact_orders 
  AT(TIMESTAMP => '2025-03-27 11:00:00'::TIMESTAMP_NTZ);
-- 1500000 rows (something added bad data)

-- Restore from good state
ALTER TABLE fact_orders 
  SET STAGE_COPY_OPTIONS = (
    ENFORCE_LOGGED_ACTION_ON_SECONDARY = TRUE
  );

UNDROP TABLE fact_orders;  -- If dropped entirely
```

### Time Travel Retention

| Edition | Default Retention | Max Retention |
|---------|-----------------|----------------|
| Standard | 1 day | 1 day |
| Business Critical | 90 days | 90 days |

**Cost:** 1 day = included; beyond = storage costs

---

## 4. Zero-Copy Clones: Safe Testing

**Problem:** Need to test schema changes, data modifications, but can't risk production

**Traditional Solution:** Export, import to separate database (copies data, expensive)

**Snowflake Solution:** Zero-Copy Clones (instant, no data duplication)

### How Zero-Copy Clones Work

```
Original Table (Production)
    ↓
Create Clone (Instant, shares metadata)
    ↓
Modify Clone (Only changes written, original untouched)
    ↓
Test Complete
    ↓
Drop Clone (Only changes deleted, original unchanged)
```

### Zero-Copy Clone Examples

**Test schema changes safely:**

```sql
-- Production table exists
SELECT * FROM dim_products LIMIT 5;
-- (1M rows, original untouched)

-- Create instant clone (no time, no space!)
CREATE TABLE dim_products_test CLONE dim_products;

-- Now safe to experiment on clone:
ALTER TABLE dim_products_test ADD COLUMN new_field STRING;
UPDATE dim_products_test SET new_field = 'test';

-- Verify changes work
SELECT * FROM dim_products_test LIMIT 5;

-- Drop clone (safe - original untouched)
DROP TABLE dim_products_test;

-- Original still intact
SELECT * FROM dim_products LIMIT 5;
-- Exactly as before
```

**Test ETL logic safely:**

```sql
-- Clone schema before test load:
CREATE SCHEMA raw_test CLONE raw_production;

-- Run ETL on test (all tables cloned)
-- If bad: DROP SCHEMA raw_test
-- If good: Swap in production

-- No data duplication, no performance impact!
```

**Cost Impact:** Zero-copy clones cost zero dollars until you modify them!

---

## 5. Snowflake Editions and Deployment

### Edition Options

| Feature | Standard | Business Critical | Enterprise |
|---------|----------|------------------|-----------|
| **Cost** | $2/credit | $4/credit | $3/credit |
| **Time Travel** | 1 day | 90 days | 90 days |
| **Multi-Cluster** | Yes | Yes | Yes |
| **Customer-Managed Keys** | ✓ | ✓ | ✓ |
| **High Availability** | Regional | Multi-region | Multi-region |
| **Support** | Standard | 24/7 + Dedicated | 24/7 + Dedicated |

**Recommendation:**
- **Standard:** Most use cases (BI, analytics, testing)
- **Business Critical:** Financial/sensitive data + need 90-day recovery
- **Enterprise:** Large deployments or negotiated pricing

### Deployment Options

**Single Region:**
```
┌─────────────────────────┐
│  US-EAST-1              │
│  (Data + Warehouses)    │
└─────────────────────────┘
```
Fast, low latency for that region

**Multi-Region (Business Critical+):**
```
┌──────────────┐      ┌──────────────┐
│  US-EAST-1   │ ←→   │  EU-WEST-1   │
│              │      │              │
└──────────────┘      └──────────────┘
```
Replication for disaster recovery + compliance

**Cloud Multi-Cloud (AWS, Azure, GCP all supported):**
- Deploy on preferred cloud
- Some workloads AWS, others Azure (all same Snowflake)

---

## 6. Performance and Scaling Patterns

### Pattern 1: Right-Size for Workload

**Aggressive scaling (not recommended):**
```sql
CREATE WAREHOUSE dev_wh WAREHOUSE_SIZE = 'XLARGE';
-- EXPENSIVE! Cost 16 credits/second

-- Better:
CREATE WAREHOUSE dev_wh WAREHOUSE_SIZE = 'XSMALL';
-- Cost 1 credit/second (16x cheaper)
```

**For production:**
```sql
-- 1000 concurrent users, heavy workload
CREATE WAREHOUSE production_wh 
  WAREHOUSE_SIZE = 'LARGE'
  MAX_CLUSTER_COUNT = 10;

-- Snowflake auto-scales from 1→10 clusters as load increases
-- Each cluster runs 1 query
-- Result: 1000 queries run in parallel
-- Cost: 8 credits/cluster × however many active clusters
```

### Pattern 2: Isolated Workloads

**Multiple teams:** Each gets own warehouse (no resource contention)

```sql
-- Analytics team
CREATE WAREHOUSE analytics_wh WAREHOUSE_SIZE = 'MEDIUM';

-- Data Science team (may need more memory)
CREATE WAREHOUSE ml_wh WAREHOUSE_SIZE = 'LARGE';

-- BI team (light queries)
CREATE WAREHOUSE bi_wh WAREHOUSE_SIZE = 'SMALL';

-- All query same shared data in storage layer
-- No impact on each other!
```

### Pattern 3: Cost Optimization

**Auto-suspend saves money:**

```sql
CREATE WAREHOUSE temp_wh 
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 5        -- Suspend after 5 mins idle (IMPORTANT!)
  AUTO_RESUME = TRUE;     -- Resume when query arrives

-- During business hours:
-- Query runs → warehouse resumes → completes → auto-suspends
-- Off-hours: warehouse stays suspended (zero cost)
```

---

## Hands-On Lab: Explore Snowflake Architecture

### Exercise 1: Create and Scale Warehouse (20 minutes)

```sql
-- 1. Create small warehouse
CREATE WAREHOUSE learning_wh 
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 5
  AUTO_RESUME = TRUE;

-- 2. Set as default
USE WAREHOUSE learning_wh;

-- 3. Run a query (warehouse resumes)
SELECT COUNT(*) FROM snowflake_sample_data.tpch_sf1.orders;

-- 4. Check warehouse status
SHOW WAREHOUSES LIKE 'learning%';
-- STATE: RUNNING (after query)

-- 5. Wait 10 minutes (no queries)
SHOW WAREHOUSES LIKE 'learning%';
-- STATE: SUSPENDED (auto-suspended!)

-- 6. One more query (resumes)
SELECT COUNT(*) FROM snowflake_sample_data.tpch_sf1.customer;
-- Warehouse auto-resumed!

-- 7. Scale warehouse
ALTER WAREHOUSE learning_wh SET WAREHOUSE_SIZE = 'SMALL';
-- Now runs 2x faster (2 credits/sec instead of 1)
-- But costs 2x as much...

-- 8. Scale back
ALTER WAREHOUSE learning_wh SET WAREHOUSE_SIZE = 'XSMALL';
```

### Exercise 2: Time Travel (25 minutes)

```sql
-- 1. Create test table
CREATE TABLE test_customers AS
SELECT * FROM snowflake_sample_data.tpch_sf1.customer LIMIT 1000;

-- 2. Check current count
SELECT COUNT(*) FROM test_customers;
-- Result: 1000

-- 3. Delete some rows
DELETE FROM test_customers 
WHERE c_nationkey = 1;

-- 4. Check count (reduced)
SELECT COUNT(*) FROM test_customers;
-- Result: ~950

-- 5. Recover using Time Travel
SELECT COUNT(*) FROM test_customers 
  AT(OFFSET => -1 * 60);  -- 1 minute ago
-- Result: 1000 (before delete!)

-- 6. Restore table to 1 min ago
CREATE TABLE test_customers_recovered AS
SELECT * FROM test_customers 
  AT(OFFSET => -1 * 60);

SELECT COUNT(*) FROM test_customers_recovered;
-- Result: 1000 (fully recovered!)
```

### Exercise 3: Zero-Copy Clone (15 minutes)

```sql
-- 1. Verify original table
SELECT COUNT(*) FROM snowflake_sample_data.tpch_sf1.orders;
-- Result: 1.5M rows

-- 2. Create zero-copy clone (instant!)
CREATE TABLE orders_clone CLONE snowflake_sample_data.tpch_sf1.orders;

-- 3. Verify clone (same data, no copy time)
SELECT COUNT(*) FROM orders_clone;
-- Result: 1.5M rows (instantly!)

-- 4. Modify clone safely
UPDATE orders_clone SET o_totalprice = 0 WHERE o_orderkey = 100;

-- 5. Verify original unchanged
SELECT o_totalprice FROM snowflake_sample_data.tpch_sf1.orders 
WHERE o_orderkey = 100;
-- Original still intact!

-- 6. Drop clone (only changes deleted)
DROP TABLE orders_clone;
```

---

## Summary

✅ **Compute/Storage Separation:** Scale independently, shared data layer
✅ **Virtual Warehouses:** Flexible sizing for any workload
✅ **Time Travel:** Recover from mistakes instantly
✅ **Zero-Copy Clones:** Test safely without data duplication
✅ **Editions:** Standard for most, Business Critical for compliance

---

## Next Steps

- 👉 **[Data Loading](02-data-loading.md)** - Load data using COPY and Snowpipe
- 📖 **[Snowflake Docs](https://docs.snowflake.com/user-guide/warehouses-overview)** - Official reference

*Last Updated: March 2026*
