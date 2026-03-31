# Amazon Redshift: Cluster Management

## Learning Outcomes
- Design cluster configurations
- Monitor cluster performance
- Implement Spectrum for external queries
- Scale and optimize for cost
- Plan disaster recovery

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01-03

## Cluster Planning

```
Node Type Selection:
┌────────────┬─────────────┬──────────────┬──────────┐
│ Node Type  │ Memory      │ Storage      │ vCPU     │
├────────────┼─────────────┼──────────────┼──────────┤
│ dc2.large  │ 160GB       │ 160GB SSD    │ 2        │
│ dc2.8xl    │ 2.56TB      │ 2.56TB SSD   │ 32       │
│ ra3.4xl    │ 128TB       │ Managed      │ 32       │
│ ra3.16xl   │ 128TB       │ Managed      │ 128      │
└────────────┴─────────────┴──────────────┴──────────┘

Sizing Example:
- Data: 1TB
- Replication: 3x (Redshift standard)
- Usable: 1TB / 3 = 333GB
- Nodes: ceil(333GB / 160GB) = 3 dc2.large
```

```sql
-- Check cluster configuration
SELECT * FROM stv_nodes;

-- Monitor query performance
SELECT
  query,
  starttime,
  endtime,
  datediff(second, starttime, endtime) as duration_sec
FROM stl_query
WHERE userid > 1
ORDER BY starttime DESC
LIMIT 10;

-- Node health check
SELECT
  node,
  status,
  node_type,
  total_capacity_gb,
  used_capacity_gb
FROM stv_node_storage_info;
```

## Concurrency Scaling

Scale queries automatically during peak times:

```sql
-- Enable concurrency scaling
ALTER CLUSTER my_cluster MODIFY CONCURRENCY 1;

-- Monitor cache hits
SELECT COUNT(*) FROM stl_query_metrics
WHERE datediff(day, starttime, CURRENT_DATE) = 0
  AND queueing_time > 1000;
```

## Spectrum: Query S3 Directly

Query external data without loading:

```sql
-- Create external schema
CREATE EXTERNAL SCHEMA spectrum_schema
FROM DATA CATALOG
DATABASE 'spectrum_db'
IAM_ROLE 'arn:aws:iam::account:role/redshift-spectrum';

-- Create external table (schema inference)
CREATE EXTERNAL TABLE spectrum_schema.sales_archive (
  sale_id BIGINT,
  customer_id INT,
  sale_amount DECIMAL(10,2),
  sale_date DATE
)
STORED AS PARQUET
LOCATION 's3://my-bucket/sales-archive/2020-2023/';

-- Query as regular table
SELECT
  DATE_TRUNC('year', sale_date) as year,
  COUNT(*) as transactions,
  SUM(sale_amount) as revenue
FROM spectrum_schema.sales_archive
GROUP BY year;

-- Join with local Redshift table
SELECT
  l.customer_id,
  l.current_lifetime_value,
  s.archive_transactions
FROM local_customers l
JOIN spectrum_schema.sales_archive s ON l.customer_id = s.customer_id
WHERE s.sale_date >= '2020-01-01';
```

## Manual Vacuum and Maintenance

```sql
-- VACUUM: Reclaim space and re-sort
VACUUM;

-- VACUUM specific table
VACUUM FULL SORT ONLY sales_table;

-- Monitor vacuum progress
SELECT * FROM stl_vacuum;

-- ANALYZE: Update statistics for query planner
ANALYZE;

-- ANALYZE specific column
ANALYZE customers (customer_id, email);
```

## Monitoring and Alerts

```sql
-- Query workload analysis
SELECT
  query_type,
  COUNT(*) as query_count,
  AVG(total_time) as avg_time_ms
FROM stl_query
WHERE starttime > CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY query_type
ORDER BY query_count DESC;

-- Long-running queries
SELECT
  query,
  starttime,
  datediff(second, starttime, CURRENT_TIMESTAMP) as elapsed_sec
FROM stl_query
WHERE starttime > CURRENT_TIMESTAMP - INTERVAL '1 hour'
  AND query_type = 'SELECT'
ORDER BY elapsed_sec DESC
LIMIT 20;

-- Slot usage and contention
SELECT
  slotnum,
  query_cpu_time,
  query_blocks_read
FROM stl_query
WHERE starttime > CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY query_cpu_time DESC
LIMIT 10;
```

## Disaster Recovery

```sql
-- Create automated snapshots
CREATE SNAPSHOT my_snapshot FROM CLUSTER my_cluster;

-- Restore from snapshot
CREATE CLUSTER my_cluster_restored
FROM SNAPSHOT s3://my-bucket/snapshots/my_snapshot;

-- Cross-region backup
COPY DATABASE my_db TO 's3://backup-bucket/redshift/db.backup'
AUTHORIZATION 'arn:aws:iam::account:user/redshift-user';
```

## Key Concepts

- **Node Types:** dc2 (fast), ra3 (flexible), DS2 (compute-optimized)
- **Concurrency Scaling:** Auto-scale during traffic spikes
- **Spectrum:** Query S3 data without loading
- **Vacuum:** Maintenance for space reclamation
- **Snapshots:** Point-in-time backups

## Hands-On Lab

### Part 1: Cluster Setup
1. Choose appropriate node type
2. Create cluster (3+ nodes)
3. Configure security groups
4. Monitor cluster metrics

### Part 2: Spectrum Setup
1. Create S3 bucket for external data
2. Create external schema
3. Create external table
4. Query and measure performance

### Part 3: Maintenance
1. Run VACUUM on large table
2. Measure space reclaimed
3. Run ANALYZE
4. Compare query performance

*See Part 2 of course for complete lab*

*Last Updated: March 2026*
