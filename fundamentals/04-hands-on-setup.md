# Hands-On Setup: Getting Started with Cloud Data Warehouses

## Learning Outcomes

By completing this module, you should be able to:
- Create and configure accounts on all 4 cloud warehouse platforms
- Load sample datasets into each platform
- Execute basic queries to verify setup
- Compare user experience across platforms
- Set up cost monitoring and alerts

**Estimated Time:** 2 hours (1 hour setup + 1 hour labs)  
**Prerequisites:** Modules 1-3  
**Knowledge Assumed:** Comfortable with basic SQL and cloud platforms

---

## 1. Snowflake Setup

### Create a Free Trial Account

1. Go to [signup.snowflake.com](https://signup.snowflake.com)
2. Select:
   - **Edition:** Standard (or Enterprise for trial)
   - **Cloud Provider:** AWS/Azure/GCP (recommend AWS us-east-1)
   - **Region:** us-east-1 (us-west-2 also works)
3. Enter email and password
4. Verify email and activate account

**What you get:** 30-day trial with $400 in free credits (~1-2 months of moderate usage)

### Initial Configuration

After login to Snowflake web UI:

```sql
-- 1. Create a warehouse (compute cluster)
CREATE WAREHOUSE learning_wh 
  WAREHOUSE_SIZE = 'XSMALL'  -- Auto-scales up if needed
  AUTO_SUSPEND = 5;           -- Suspend after 5 mins of inactivity (saves credits)

-- 2. Create a database
CREATE DATABASE learning_db;

-- 3. Create a schema
USE DATABASE learning_db;
CREATE SCHEMA raw_data;

-- 4. Create a table from sample data
CREATE TABLE dim_products (
    product_id INT,
    product_name VARCHAR,
    category VARCHAR,
    price NUMERIC(10,2)
);

-- 5. Insert sample data
INSERT INTO dim_products VALUES 
  (1, 'Widget A', 'Tools', 29.99),
  (2, 'Gadget B', 'Gadgets', 49.99),
  (3, 'Tool C', 'Tools', 79.99);

-- 6. Test query
SELECT * FROM dim_products LIMIT 10;
```

### Load Sample Data: TPC-H

Snowflake has built-in sample database:

```sql
-- View available sample databases
SHOW DATABASES LIKE '%SNOWFLAKE%';

-- Use Snowflake sample data (SNOWFLAKE_SAMPLE_DATA database)
USE DATABASE snowflake_sample_data;
USE SCHEMA tpch_sf1;  -- 1GB sample
SHOW TABLES;

-- Run a sample query
SELECT 
    c_name,
    COUNT(*) as order_count,
    SUM(o_totalprice) as total_spent
FROM customer c
INNER JOIN orders o ON c.c_custkey = o.o_custkey
GROUP BY c_name
LIMIT 10;
```

### Cost Tracking in Snowflake

Access Billing: Account → Admin → Billing

**Key metrics:**
- **Credits Used:** Shows USD cost ($2-4 per credit for Standard)
- **Top 10 Queries by Cost:** Identify expensive queries
- **Daily Usage Graph:** Track consumption over time

---

## 2. Databricks Setup

### Create a Workspace (Community Edition is Free)

1. Go to [databricks.com](https://databricks.com/product/pricing)
2. Select **"Community Edition"** (free tier)
3. Create account with email/password
4. Select cloud (AWS, Azure, or GCP)
5. Workspace auto-provisions (takes 1-2 minutes)

**What you get:** Community Edition = 10GB storage, shared compute, permanent free access

### Initial Configuration

In Databricks workspace:

```python
# 1. Create a cluster (compute environment)
# UI: Compute → Create Cluster
# Settings: 
#   - Cluster Mode: Single Node
#   - Runtime: Latest (e.g., 13.3)
#   - Worker Type: i3.xlarge
#   - (If first time, just click "Create" to use defaults)

# 2. Create a notebook
# UI: Workspace → Create → Notebook
# Language: SQL (or Python)

-- 3. Create a table
CREATE TABLE delta_sample_products (
    product_id INT,
    product_name STRING,
    category STRING,
    price DECIMAL(10,2)
)
USING DELTA;

-- 4. Insert sample data
INSERT INTO delta_sample_products VALUES 
  (1, 'Widget A', 'Tools', 29.99),
  (2, 'Gadget B', 'Gadgets', 49.99),
  (3, 'Tool C', 'Tools', 79.99);

-- 5. Test query
SELECT * FROM delta_sample_products LIMIT 10;
```

### Load Public Datasets

Databricks has Databricks' datasets available:

```sql
-- View available datasets
SHOW DATABASES;

-- Use samples_retail database
USE samples_retail;
SHOW TABLES;

-- Query sample retail data
SELECT 
    customer_id,
    COUNT(*) as purchase_count,
    SUM(amount) as total_spent
FROM sales
GROUP BY customer_id
LIMIT 10;
```

### Cost Tracking in Databricks

Dashboard → Billing → Usage

**Key metrics:**
- **DBUs (Databricks Units):** $0.40-$0.52 per DBU
- **Cluster Hours:** Total compute minutes used
- **Storage:** GB stored in workspace
- **Queries by Cost:** Identify expensive operations

---

## 3. BigQuery Setup

### Create a GCP Project and Enable BigQuery

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a new project (takes 2-3 minutes)
3. Go to **BigQuery** in left menu
4. Accept terms (one-time)

**What you get:** $300 free credits for 90 days + 1TB free query data per month permanently

### Initial Configuration

In BigQuery web UI:

```sql
-- 1. Create a dataset
CREATE SCHEMA `[project-id].learning_dataset`
  OPTIONS(
    description="Learning dataset for warehouse course",
    location="US",
    default_table_expiration_ms=7776000000);  -- 90 days

-- 2. Create a table
CREATE TABLE `[project-id].learning_dataset.dim_products` (
    product_id INT64,
    product_name STRING,
    category STRING,
    price NUMERIC
);

-- 3. Insert sample data
INSERT INTO `[project-id].learning_dataset.dim_products` VALUES 
  (1, 'Widget A', 'Tools', 29.99),
  (2, 'Gadget B', 'Gadgets', 49.99),
  (3, 'Tool C', 'Tools', 79.99);

-- 4. Test query (shows cost estimate at top!)
SELECT * FROM `[project-id].learning_dataset.dim_products` LIMIT 10;
```

Replace `[project-id]` with your actual project ID (shown at top of BigQuery editor)

### Load Sample Public Datasets

BigQuery has 100+ public datasets for free:

```sql
-- Query public NYC taxi data (no cost estimation shown for public data)
SELECT 
    pickup_datetime,
    pickup_borough,
    payment_type,
    COUNT(*) as trip_count,
    AVG(fare_amount) as avg_fare
FROM `bigquery-public-data.new_york_taxi.tlc_yellow_trips_2015`
WHERE DATE(pickup_datetime) = '2015-01-01'
GROUP BY pickup_datetime, pickup_borough, payment_type
LIMIT 100;
```

### Cost Tracking in BigQuery

Go to **Billing** → Project → Cost Analysis

**Key metrics:**
- **Analysis cost:** $/TB scanned ($7.50/TB on-demand)
- **Storage cost:** $/GB stored
- **Query details:** See what you spent on before/after any optimization

### BigQuery ML Cost Estimate

```sql
-- Creates model for free during testing
CREATE OR REPLACE MODEL `[project-id].learning_dataset.demand_forecast`
OPTIONS(model_type='linear_reg') AS
SELECT 
    CAST(ABS(FARM_FINGERPRINT(DATE(pickup_datetime))) % 100 as INT64) as day_feature,
    fare_amount as label
FROM `bigquery-public-data.new_york_taxi.tlc_yellow_trips_2015`
WHERE DATE(pickup_datetime) >= '2015-01-01'
  AND DATE(pickup_datetime) <= '2015-01-10'
LIMIT 10000;
```

---

## 4. Amazon Redshift Setup

### Create a Redshift Cluster (Free Trial Available)

1. Go to [AWS Console → Redshift](https://console.aws.amazon.com/redshift)
2. Create cluster:
   - **Node type:** RA3 (free trial available)
   - **Number of nodes:** 1
   - **Database name:** learning
   - **Admin user:** admin
   - **Password:** [secure password]

**What you get:** 
- RA3 free trial (2 months or $200 credits)
- Or use DC2 dense compute ($0.25/hour)

### Initial Configuration

Connect via Query Editor or SQL Client:

```sql
-- 1. Create schema
CREATE SCHEMA learning_data;

-- 2. Create table
CREATE TABLE learning_data.dim_products (
    product_id INT,
    product_name VARCHAR(100),
    category VARCHAR(100),
    price NUMERIC(10,2)
);

-- 3. Insert sample data
INSERT INTO learning_data.dim_products VALUES 
  (1, 'Widget A', 'Tools', 29.99),
  (2, 'Gadget B', 'Gadgets', 49.99),
  (3, 'Tool C', 'Tools', 79.99);

-- 4. Test query
SELECT * FROM learning_data.dim_products LIMIT 10;
```

### Load Public Data: TPC-H

Redshift provides sample TPC-H data:

```sql
-- Download TPC-H scripts from redshift docs
-- Create TPC-H tables automatically, then:

SELECT COUNT(*) as customer_count FROM customer;
SELECT COUNT(*) as order_count FROM orders;

-- Sample query
SELECT 
    c_name,
    COUNT(*) as order_count,
    SUM(o_totalprice) as total_spent
FROM customer c
INNER JOIN orders o ON c.c_custkey = o.o_custkey
GROUP BY c_name
LIMIT 10;
```

### Cost Tracking in Redshift

AWS Console → Redshift → Clusters → [cluster name]

**Key metrics:**
- **Node count & type:** Determines hourly cost
- **Query monitoring:** See duration and query details
- **Disk usage:** Track storage

---

## Hands-On Labs

### Lab 1: Set Up All 4 Platforms (45 minutes)

**Objective:** Create accounts and run first query on each

**Checklist:**
- [ ] Snowflake: Create warehouse & database, run sample query
- [ ] Databricks: Create cluster & notebook, run sample query
- [ ] BigQuery: Create dataset & table, run sample query
- [ ] Redshift: Create cluster & schema, run sample query

**Verification:** Each platform should show ~3 rows returned

---

### Lab 2: Compare Sample Queries (45 minutes)

Run the same query on each platform and compare:

**Query:**
```sql
SELECT 
    -- Get top products by count (adjust table names per platform)
    product_name,
    COUNT(*) as count,
    AVG(price) as avg_price
FROM <product_table>
GROUP BY product_name
ORDER BY count DESC
LIMIT 5;
```

**Document:**
1. Query execution time
2. Ease of writing query (UI friendliness: 1-5 stars)
3. Result formatting
4. Cost (if shown)

**Expected Output:**
| Platform | Time (ms) | Ease | Cost |
|----------|-----------|------|------|
| Snowflake | 200-500 | 5/5 | $0.01 |
| Databricks | 1000-2000 | 4/5 | Free tier |
| BigQuery | 100-300 | 5/5 | $0.00 |
| Redshift | 500-1000 | 3/5 | ~$0.01 |

---

## Cost Comparison: First Month

| Platform | Trial/Free | Estimated Cost | Notes |
|----------|-----------|-----------------|-------|
| Snowflake | $400 credits | $20-50 | Compute credits burn quickly |
| Databricks | Community Edition ∞ | $0 | Limited compute, adequate for learning |
| BigQuery | $300 + $1TB free/mo | $0-30 | 1TB free query quota great for learning |
| Redshift | $200 credits or RA3 free | $0-50 | RA3 trial or low-cost DC2 |
| **Total** | **~$1.5K total** | **$20-130/mo** | Use free tiers for learning |

### Cost-Saving Tips

1. **Auto-suspend:** Turn off compute when not using (Snowflake, Redshift)
2. **Use free tier datasets:** Public Databricks/BigQuery datasets = free queries
3. **Start small:** XSMALL warehouse, Single-node cluster, 1 DC2 node
4. **Clean up:** Drop test tables, databases, clusters after use
5. **Monitor:** Check billing weekly while learning

---

## Common Setup Issues

### Snowflake

**Issue:** "Insufficient privileges to operate on warehouse 'X_WH'"  
**Solution:** Switch to correct role or create warehouse with proper permissions

**Issue:** "Syntax error" when using reserved keywords  
**Solution:** Quote table/schema names: `"TABLE_NAME"`

### Databricks

**Issue:** "Cluster is not running" when trying to query  
**Solution:** Start cluster first (Compute → click cluster → Start)

**Issue:** Community Edition storage is full  
**Solution:** Delete test notebooks and tables. Community = limited storage.

### BigQuery

**Issue:** "Project ID not found"  
**Solution:** Use exact project ID (shown at top of console), not project name

**Issue:** "Access Denied" on public datasets  
**Solution:** Public datasets are read-only. Create your own dataset for writes.

### Redshift

**Issue:** "Cluster is paused"  
**Solution:** Resume cluster (Redshift → Clusters → click cluster → Resume)

**Issue:** "Network timeout" connecting to cluster  
**Solution:** Check security groups allow inbound on port 5439

---

## Verification Checklist

Before moving to platform-specific modules:

- [ ] **Snowflake:** Account created, warehouse running, sample data loaded
- [ ] **Databricks:** Workspace created, cluster running, notebook executable
- [ ] **BigQuery:** Project created, dataset created, query executing
- [ ] **Redshift:** Cluster running, schema created, data loaded
- [ ] **Cost alerts:** Set up billing alerts on each platform
- [ ] **Baseline query:** Ran identical query on all 4, documented results
- [ ] **Documentation:** Saved project IDs, usernames, passwords securely

---

## Next Steps

You're ready to dive into platform-specific modules!

- 👉 **Next:** First Platform Deep-Dive
  - Recommended order: Snowflake → Databricks → BigQuery → Redshift
  - Or choose based on your role/interest

- 📖 **Platform Documentation:**
  - [Snowflake Docs](https://docs.snowflake.com)
  - [Databricks Docs](https://docs.databricks.com)
  - [BigQuery Docs](https://cloud.google.com/bigquery/docs)
  - [Redshift Docs](https://docs.aws.amazon.com/redshift)

---

*Last Updated: March 2026*
