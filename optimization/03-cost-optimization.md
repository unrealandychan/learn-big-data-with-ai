# Module 4.3: Cost Optimization Framework

**Duration:** 4 hours  
**Prerequisites:** Module 4.2 (Data Organization)  
**Level:** Advanced

---

## Learning Outcomes

- Understand cost drivers for each platform
- Calculate total cost of ownership (TCO)
- Design cost-aware architectures
- Identify and prioritize cost optimization opportunities

---

## 1. The Cost Mindset

Cloud data warehouse costs have three failure modes:

```
1. You don't know what you're spending (no monitoring)
2. You know but can't explain it (no attribution)
3. You can explain it but don't act on it (no governance)
```

This module gives you the tools to avoid all three.

---

## 2. Platform Cost Models

### 2.1 Snowflake

Snowflake charges separately for **compute** and **storage**:

| Component | Charged For | Unit |
|-----------|-------------|------|
| **Compute (Virtual Warehouse)** | Time the warehouse is running (billed per second, 60s minimum) | Credits/hour |
| **Storage** | Compressed data stored (daily average) | $/TB/month |
| **Cloud Services** | Metadata operations (free up to 10% of compute) | Credits |
| **Data Transfer** | Egress between regions/clouds | $/GB |

```sql
-- Monitor credits consumed by warehouse
SELECT
  warehouse_name,
  SUM(credits_used)           AS total_credits,
  SUM(credits_used_compute)   AS compute_credits,
  SUM(credits_used_cloud_services) AS cloud_credits,
  MIN(start_time)             AS period_start,
  MAX(end_time)               AS period_end
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD(MONTH, -1, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;

-- Credit price varies by edition and cloud region (~$2–$4 per credit)
-- XS warehouse = 1 credit/hour, S = 2, M = 4, L = 8, XL = 16, ...

-- Storage usage
SELECT
  DATE(usage_date)           AS date,
  ROUND(storage_bytes / 1e12, 2) AS storage_tb,
  ROUND(stage_bytes / 1e12, 2)   AS stage_tb,
  ROUND(failsafe_bytes / 1e12, 2) AS failsafe_tb
FROM snowflake.account_usage.storage_usage
ORDER BY date DESC
LIMIT 30;
```

**Key Snowflake cost levers:**
- Auto-suspend warehouses (set to 1–5 minutes)
- Use the smallest warehouse that fits the workload
- Leverage query result cache (free — re-running same query costs nothing)
- Use Resource Monitors to cap spending

```sql
-- Set auto-suspend and auto-resume
ALTER WAREHOUSE analytics_wh SET
  AUTO_SUSPEND = 120       -- suspend after 2 min idle
  AUTO_RESUME = TRUE;

-- Create a resource monitor to alert at 90% and suspend at 100%
CREATE RESOURCE MONITOR monthly_cap
  WITH CREDIT_QUOTA = 500
  TRIGGERS
    ON 90 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE analytics_wh SET RESOURCE_MONITOR = monthly_cap;
```

### 2.2 Databricks

Databricks charges in **DBUs (Databricks Units)** — a normalized compute unit:

| Cluster Type | DBU Rate | Use Case |
|-------------|---------|---------|
| All-Purpose Compute | ~2× | Interactive notebooks, development |
| Jobs Compute | ~1× | Automated pipelines (cheapest) |
| SQL Warehouse (Serverless) | ~1.5× | BI and SQL queries |
| SQL Warehouse (Classic) | ~1×–1.5× | Steady BI workloads |

DBU price depends on cloud, region, and contract (~$0.07–$0.50/DBU).

```python
# Databricks has no built-in SQL for cost — use the REST API or Cost Management UI
# Monitor via: Databricks Account Console → Cost Analysis

# Practical cost tips in code:
# 1. Use auto-termination on clusters
# 2. Use job clusters (not all-purpose) for production
# 3. Use spot/preemptible instances for non-critical jobs

# Check cluster config in notebook
spark.conf.get("spark.databricks.clusterUsageTags.clusterName")
```

**Key Databricks cost levers:**
- Always use **Job Clusters** for automated pipelines (half the cost of all-purpose)
- Enable **auto-scaling** with appropriate min/max worker counts
- Use **spot instances** for batch jobs (70–90% cheaper, with retries)
- Use **Photon** for SQL-heavy workloads (faster = fewer DBU-hours)

### 2.3 BigQuery

BigQuery has two pricing models:

| Model | Charged For | Best For |
|-------|-------------|---------|
| **On-demand** | Bytes scanned ($6.25/TB) | Sporadic queries, unpredictable workloads |
| **Capacity (Reservations)** | Slots purchased (flat rate) | Predictable, high-volume workloads |

```sql
-- Estimate query cost before running
-- In BigQuery UI: dry run shows bytes processed before execution

-- Programmatic dry run
-- bq query --dry_run --use_legacy_sql=false "SELECT * FROM dataset.table WHERE date = '2024-01-01'"

-- Find expensive queries
SELECT
  user_email,
  query,
  total_bytes_processed / 1e12 AS tb_scanned,
  ROUND(total_bytes_processed / 1e12 * 6.25, 4) AS estimated_cost_usd,
  creation_time
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND statement_type = 'SELECT'
ORDER BY total_bytes_processed DESC
LIMIT 20;

-- Set cost controls: dataset-level maximum bytes billed
-- In code (Python client):
-- job_config.maximum_bytes_billed = 10 * 1024**3  # 10 GB cap
```

**Key BigQuery cost levers:**
- Always filter on **partition columns** (reduces bytes scanned = direct cost reduction)
- Use **SELECT specific columns**, not `SELECT *` (BigQuery is columnar — you pay per column)
- Cache results and avoid re-running identical queries within 24h
- Use **BI Engine** for repeated dashboard queries
- Move cold data to long-term storage (>90 days auto-discount: 50% storage discount)

### 2.4 Redshift

Redshift charges for:

| Component | Model | Notes |
|-----------|-------|-------|
| **Cluster nodes** | Hourly per node | RA3 = compute/storage separated; DC2 = all-in-one |
| **Managed storage (RA3)** | Per GB/month | Data stored in S3, billed separately |
| **Redshift Serverless** | Per RPU-second | Good for variable/dev workloads |
| **Spectrum** | Per TB scanned (S3) | $5/TB |
| **Data transfer** | Egress | Standard AWS rates |

```sql
-- Monitor query cost via WLM
SELECT
  service_class,
  num_queued_queries,
  num_executing_queries,
  total_exec_time
FROM stv_wlm_service_class_state;

-- Find the most expensive queries
SELECT
  query,
  elapsed / 1e6    AS elapsed_seconds,
  cpu_time / 1e6   AS cpu_seconds,
  blocks_read,
  rows_processed
FROM svl_query_summary
GROUP BY 1, 2, 3, 4, 5
ORDER BY elapsed_seconds DESC
LIMIT 20;
```

**Key Redshift cost levers:**
- Use **RA3 nodes** — you only pay for compute when running + storage separately
- Use **Redshift Serverless** for dev/test (no idle cost)
- Use **Concurrency Scaling** only when needed (extra cost per hour)
- Offload cold data to **Redshift Spectrum** (S3 = cheaper storage, scanned on demand)
- Pause clusters during off-hours (scripts or scheduled actions)

---

## 3. Total Cost of Ownership (TCO)

TCO includes more than the query bill:

```
TCO = Compute + Storage + Data Transfer + Engineering Time + Licensing + Support
```

| Hidden Cost | Description |
|-------------|-------------|
| **Data transfer** | Moving data between regions or clouds |
| **Engineering time** | Time spent managing the platform |
| **Failed/retried jobs** | Paying for compute even when jobs fail |
| **Over-provisioning** | Warehouse/cluster running idle |
| **Technical debt** | Slow queries = pay for more compute to compensate |

### TCO Calculation Template

| Cost Category | Snowflake | Databricks | BigQuery | Redshift |
|---------------|-----------|------------|----------|----------|
| Compute (monthly) | X credits × $Y/credit | X DBU-hours × $Y/DBU | X TB × $6.25 | X nodes × $Y/node/hr × 730 hrs |
| Storage (monthly) | X TB × $23/TB | X TB × cloud storage rate | X TB × $0.02/GB | X TB × $0.024/GB (RA3) |
| Data transfer | Egress GB × rate | Egress GB × rate | Egress GB × rate | Egress GB × rate |
| **Total** | | | | |

---

## 4. Cost Monitoring and Alerting

### Snowflake — Resource Monitors + Budget Alerts

```sql
-- View all resource monitors
SHOW RESOURCE MONITORS;

-- Create per-team monitor
CREATE RESOURCE MONITOR data_science_team
  WITH CREDIT_QUOTA = 200
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE ds_wh SET RESOURCE_MONITOR = data_science_team;

-- Weekly spend report
SELECT
  DATE_TRUNC('week', start_time)  AS week,
  warehouse_name,
  ROUND(SUM(credits_used), 2)     AS credits,
  ROUND(SUM(credits_used) * 3, 2) AS approx_usd   -- adjust rate
FROM snowflake.account_usage.warehouse_metering_history
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;
```

### BigQuery — Budget Alerts (Google Cloud Console)

```sql
-- Tag queries with labels for cost attribution
-- In query options: labels = {"team": "data-science", "project": "q1-report"}

-- Cost per team using labels
SELECT
  labels.value                                  AS team,
  SUM(total_bytes_processed) / 1e12             AS tb_scanned,
  ROUND(SUM(total_bytes_processed) / 1e12 * 6.25, 2) AS cost_usd
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT,
     UNNEST(labels) AS labels
WHERE labels.key = 'team'
  AND creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY 1
ORDER BY cost_usd DESC;
```

---

## 5. Cost Optimization Decision Tree

```
Is my bill higher than expected?
├── YES → Where is it coming from?
│   ├── Compute (warehouse/cluster/slots)
│   │   ├── Warehouses idle? → Lower auto-suspend threshold
│   │   ├── Warehouse too large? → Downsize; test with smaller warehouse
│   │   ├── Many small queries? → Use connection pooling; batch queries
│   │   └── Long-running queries? → Optimize queries (see Module 4.1/4.2)
│   ├── Storage
│   │   ├── Too much raw data? → Implement retention policies
│   │   ├── Duplicate data? → Deduplicate; review ETL
│   │   └── Failed job temp data? → Add cleanup steps to pipelines
│   └── Data Transfer
│       ├── Cross-region queries? → Co-locate data with compute
│       └── Frequent exports? → Evaluate if export is necessary
└── NO → Set up monitoring so you know when it changes
```

---

## 6. Hands-On Labs

### Lab 1 — Cost Audit (30 min)
On your platform of choice, run the cost queries from this module and answer:
1. What are the top 5 most expensive queries?
2. Which warehouse/cluster is consuming the most credits?
3. What is your current monthly storage cost?

### Lab 2 — Auto-Suspend Impact (Snowflake, 20 min)
1. Check your warehouse's current auto-suspend setting
2. Set it to 60 seconds
3. Run a query, wait 2 minutes, run again
4. Verify the warehouse started up again — confirm auto-resume works

### Lab 3 — BigQuery Scan Reduction (30 min)
1. Find a query in your history that scans > 1 GB
2. Identify if it filters on the partition column
3. Add the partition filter if missing; re-run and compare bytes scanned
4. Calculate the dollar savings at $6.25/TB

### Lab 4 — TCO Calculation (45 min)
For a hypothetical team running 50 queries/day (average 10 GB each) on each platform:
1. Calculate monthly cost (on-demand pricing)
2. Compare the 4 platforms in a table
3. Identify which factors would change the decision

### Lab 5 — Cost Monitoring Dashboard (60 min)
Set up a simple cost monitoring query or dashboard that:
1. Runs daily and records credits/cost used
2. Alerts when daily spend exceeds a threshold
3. Breaks down cost by team or workload type

---

## Summary

| Platform | Key Cost Driver | #1 Quick Win |
|----------|----------------|-------------|
| Snowflake | Idle warehouses | Set AUTO_SUSPEND = 60 |
| Databricks | All-purpose clusters | Switch pipelines to Job Clusters |
| BigQuery | Full table scans | Always filter on partition column |
| Redshift | Cluster size | Use RA3 + pause during off-hours |

---

*Previous: [Module 4.2 — Data Organization](02-data-organization.md)*  
*Next: [Module 4.4 — Performance Benchmarking](04-performance-benchmarks.md)*

