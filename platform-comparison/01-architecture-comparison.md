# Platform Comparison: Architecture

**Duration:** 3 hours  
**Prerequisites:** At least 2 platform-specific modules (recommended: Snowflake + one other)

---

## Part 1: What Problem Does Each Platform Solve?

All four platforms solve the same root problem — analytics at scale — but each makes fundamentally different trade-offs. Understanding *why* before *how* is critical to making the right decision.

### The Shared Root Problem

Transactional databases (MySQL, PostgreSQL) can't handle analytical workloads:
- Too slow for aggregating billions of rows
- Crush production performance when analytics queries run
- Can't join data from multiple source systems
- Don't scale horizontally for read-heavy analytics

These four platforms each solve this in a distinct way.

---

### How Each Platform Solves It

#### Snowflake
| | |
|---|---|
| **Core problem solved** | Analytics is bottlenecked by coupled compute and storage; teams waste time on infrastructure |
| **How** | Separates compute (virtual warehouses) from storage completely. Scale query power up or down instantly without touching data. SQL-first, minimal ops. |
| **Key insight** | When compute and storage are decoupled, you can run 10 warehouses against the same data simultaneously, or scale up just for one big query |
| **Breaks down when** | You need ML/AI tight integration, or real-time streaming is a primary requirement |

#### Databricks
| | |
|---|---|
| **Core problem solved** | Data teams use 5 separate tools (ETL tool, data lake, warehouse, ML platform, monitoring), creating silos and duplication |
| **How** | **Lakehouse model** — Delta Lake adds ACID transactions and schema enforcement to open files on cloud storage. One platform for pipelines, SQL analytics, and ML training |
| **Key insight** | The fundamental division between "data lake" (cheap, raw) and "data warehouse" (reliable, structured) is artificial. Delta Lake collapses both |
| **Breaks down when** | You only need SQL BI, not engineering/ML. The platform has more complexity than is needed for pure analytics teams |

#### BigQuery
| | |
|---|---|
| **Core problem solved** | Provisioning and managing clusters is itself a blocker to getting analytics value |
| **How** | Fully **serverless** — no cluster, no nodes, no scaling config. Pay per bytes scanned. Google's Dremel engine fans out queries across thousands of nodes automatically |
| **Key insight** | The bottleneck to analytics isn't compute power — it's the operational overhead before you can query anything. Remove the infrastructure entirely |
| **Breaks down when** | Costs get unpredictable at high query volume without reserved slots; GCP lock-in is a concern; you need very complex ETL |

#### Amazon Redshift
| | |
|---|---|
| **Core problem solved** | Analytical queries require joining vast amounts of data distributed across many tables; single-node systems can't do this fast enough |
| **How** | **MPP (Massively Parallel Processing)** — data is physically distributed across nodes by distribution key. Rows that will be joined live on the same node, minimizing data movement |
| **Key insight** | Performance at scale is fundamentally a data placement problem. Co-locate related rows, and parallel computation becomes extremely efficient |
| **Breaks down when** | You don't invest in schema design (distribution keys, sort keys). Without tuning, it performs no better than other databases |

---

### Side-by-Side Problem/Solution Comparison

| Dimension | Snowflake | Databricks | BigQuery | Redshift |
|---|---|---|---|---|
| **Primary identity** | Cloud data warehouse | Unified lakehouse platform | Serverless cloud warehouse | AWS MPP data warehouse |
| **Core problem focus** | Easy, scalable SQL analytics | Unified data engineering + analytics + ML | Zero-ops analytics at scale | High-performance AWS-native warehousing |
| **Design philosophy** | Decouple compute from storage | Collapse data lake + warehouse into one | Remove infrastructure entirely | Co-locate data for parallel joins |
| **Ops burden** | Low | Medium | Very low | Medium–high |
| **Best for SQL BI** | ✅ Excellent | ✅ Good | ✅ Excellent | ✅ Excellent |
| **Best for ML** | ⚠️ Limited | ✅ Excellent | ✅ Good (BQML) | ⚠️ Limited |
| **Best for data engineering** | ✅ Good | ✅ Excellent | ✅ Good | ✅ Good |
| **Best for streaming** | ✅ Good (via ecosystem) | ✅ Excellent | ✅ Good | ⚠️ Moderate |
| **Tuning required** | Low | Medium | Low–medium | High |
| **Cloud-agnostic?** | ✅ Multi-cloud | ✅ Multi-cloud | ❌ GCP only | ❌ AWS only |
| **Vendor lock-in risk** | Medium | Medium | Medium–high | Medium–high |
| **Cost model** | Credits (compute) + storage | DBUs + cloud storage | Per TB scanned or slots | Node-based (hourly) |
| **Cost predictability** | Medium | Medium | Variable (on-demand) | High |
| **Learning curve** | Easy | Medium–hard | Easy | Medium–hard |
| **Schema flexibility** | High (VARIANT for JSON) | Very high (Delta + semi-structured) | High (STRUCT/ARRAY) | Medium (structured-first) |

---

### Mental Model: One Sentence Each

> **Snowflake** — Warehouse-first simplicity; scale compute independently.
>
> **Databricks** — Engineering/ML-first unification; one platform for everything.
>
> **BigQuery** — Serverless analytics-first; Google manages the rest.
>
> **Redshift** — AWS-native control-first; performance through intentional design.

---

### When to Choose Which

```
Need ML/AI + data engineering in one platform?     → Databricks
Already in GCP, want minimal ops?                  → BigQuery
Already in AWS, want deep performance control?     → Redshift
SQL-first, multi-cloud, want easiest warehouse?    → Snowflake
All four options viable?                           → Snowflake (easiest start)
```

---

## Part 2: Technical Architecture Deep Dive

## The Four Platforms at a Glance

| Aspect | Snowflake | Databricks | BigQuery | Redshift |
|--------|-----------|-----------|----------|----------|
| **Architecture** | Compute/storage separation | Lakehouse (lake + warehouse) | Columnar, serverless | MPP (distributed) |
| **Underlying Storage** | S3/Azure/GCS (managed) | S3/ADLS (managed) | Google Cloud Storage | S3 (external) |
| **Query Engine** | Custom | Apache Spark | Dremel (Google) | Postgres-based |
| **Data Format** | Tables (+ VARIANT) | Delta Lake (ACID) | Tables (+ nested) | Tables (columnar) |
| **Scaling** | Automatic (warehouse size) | Cluster scaling manual | Automatic (slots/on-demand) | Manual (nodes) |
| **Pricing Model** | Compute credits + storage | DBUs per cluster hour | Per-query or slots | Nodes + storage |
| **Setup Time** | Minutes | Minutes | Minutes | 5-10 minutes |
| **Learning Curve** | Easy (SQL-first) | Medium (Spark knowledge) | Easy (SQL-first) | Medium-hard (MPP concepts) |
| **Best For** | Ad-hoc BI, ease-of-use | ML/AI, complex transforms | Large-scale analytics | Enterprise warehouse |

---

## Architecture Deep Dive

### Snowflake: Compute/Storage Separation

**Design Pattern:**
```
┌─────────────────┐
│                 │
│  Virtual        │  Storage Layer
│  Warehouses     │  (Shared Data)
│  (Query         │
│   Processing)   │
│                 │
└─────────────────┘
```

**Key Points:**
- Storage and compute are completely separate
- Multiple warehouses can query same data simultaneously
- Scale compute up/down independently of storage
- Pay for credits (compute) + storage separately
- Time Travel built-in

**Best Practice:**
- Small warehouse (XS) for development
- Scale up for production queries (for that query only)
- Share dimensions across teams (via shares)

---

### Databricks: Lakehouse Architecture

**Design Pattern:**
```
RAW DATA (Bronze Layer)
    ↓ Transform
VALIDATED DATA (Silver Layer)
    ↓ Transform
ANALYTICS DATA (Gold Layer)
    ↓ Query / BI / ML
INSIGHTS
```

**Key Points:**
- Raw data in cost-effective storage
- Delta Lake metadata layer adds schemas and ACID
- Users see warehouse-like query interface
- Can access raw data for exploration
- ACID guarantees across all layers

**Best Practice:**
- Keep data as Delta (not Parquet)
- Implement Bronze/Silver/Gold architecture
- Use Unity Catalog for governance across clouds
- Leverage Spark for complex transforms

---

### BigQuery: Columnar, Serverless

**Design Pattern:**
```
┌──────────────────────┐
│  User Query          │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  BigQuery Engine     │
│  (Dremel)            │
│  - Columnar          │
│  - Multithread       │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  Results             │
└──────────────────────┘
```

**Key Points:**
- Queries scan only columns you select (very efficient)
- Massive parallelism across Google's infrastructure
- Price depends on data scanned: $7.50/TB on-demand
- Or reserve compute with Annual Slots: $204K/year
- No cluster to manage - truly serverless

**Best Practice:**
- Partition tables by date
- Cluster on common filters
- Use Annual Slots for stable workloads ($4K+/month)
- Use on-demand for ad-hoc queries

---

### Redshift: MPP

**Design Pattern:**
```
┌──────────────────────┐
│  Leader Node         │
│  (Query planning)    │
└──────────┬───────────┘
           ↓
┌──────────┼──────────────┐
│          │              │
↓          ↓              ↓
Slice 1    Slice 2    Slice N
(Node 1)   (Node 2)   (Node N)
(Data)     (Data)     (Data)
```

**Key Points:**
- Data distributed across nodes (slices)
- Each node processes its data in parallel
- Leader node coordinates and assembles results
- Distribution key determines data splits
- Query efficiency depends critically on distribution

**Best Practice:**
- Choose distribution key carefully (major performance impact!)
- Use EVEN distribution if no clear key
- Monitor query plans to detect data skew
- Scale cluster size for query volume
- Use Spectrum to query S3 directly

---

## Performance Comparison: Same Query on All Platforms

**Sample Query:** Aggregate 1 year of sales data (1GB table)

```sql
SELECT 
    EXTRACT(MONTH FROM order_date) as month,
    product_category,
    SUM(sales_amount) as total_sales,
    COUNT(DISTINCT customer_id) as unique_customers
FROM orders
WHERE order_date >= '2024-01-01'
GROUP BY EXTRACT(MONTH FROM order_date), product_category
ORDER BY month, total_sales DESC;
```

| Platform | Time | Cost | Notes |
|----------|------|------|-------|
| **Snowflake (XS)** | 2-3 sec | $0.012 | 1 credit ≈ $4 for compute |
| **Databricks** | 5-10 sec | ~$0.05 | 1 DBU ≈ $0.40-$0.52 |
| **BigQuery** | 0.5-1 sec | $0.0075 | $7.50/TB scanned |
| **Redshift (1x RA3)** | 2-4 sec | ~$0.02 | ~$4/hour cluster |

**Observations:**
- BigQuery fastest (optimized for columnar reads)
- Snowflake easy to use, competitive cost
- Databricks good for complex transforms
- Redshift slower for single queries, strong at scale

---

## Pricing Model Comparison

### Snowflake: Per-Second Billing
```
Cost = Warehouse_Size × Credits × $4 (per credit)
      = XSMALL (1 credit/sec) × 10 sec × $4
      = $0.04 per query
```

**Pros:** Fair metering, pays for what you use  
**Cons:** Can be expensive for frequent small queries

### Databricks: Per-DBU Billing
```
Cost = DBUs × Duration × Rate
     = 1 DBU × 0.15 hours × $0.40/DBU
     = $0.06
```

**Pros:** Predictable per-cluster-hour  
**Cons:** Pays even if cluster is idle

### BigQuery: Per-Bytes Scanned
```
Cost = Bytes_Scanned / 1TB × $7.50
     = 1GB / 1024B × $7.50
     = $0.0073 per query
```

**Pros:** Encourages efficient queries  
**Cons:** Can be shocking if scanning unnecessary columns

### Redshift: Per-Hour Nodes
```
Cost = Nodes × Hour × Rate
     = 1 RA3 node × 1 hour × $3.26/hour
     = $3.26 per hour (minimum)
```

**Pros:** Predictable scaling  
**Cons:** Minimum cost even for small queries

---

## Feature Comparison Matrix

| Feature | Snowflake | Databricks | BigQuery | Redshift |
|---------|-----------|-----------|----------|----------|
| **Time Travel** | ✅ 90 days free | ✅ Delta logs | ✅ Table snapshots | ❌ No |
| **ACID Transactions** | ✅ Native | ✅ Delta Lake | ✅ Native | ❌ No |
| **Zero-Copy Clone** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Semi-structured (JSON)** | ✅ VARIANT | ✅ JSON | ✅ STRUCT/ARRAY | ❌ Limited |
| **ML Built-in** | ⚠️ Cortex AI | ✅ MLflow | ✅ BQML | ❌ No |
| **External Table Query** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Spectrum |
| **Multi-Cloud** | ✅ AWS/Azure/GCP | ✅ AWS/Azure/GCP | ❌ GCP-only | ❌ AWS-only |
| **Row-Level Security** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Federated Queries** | ❌ No | ✅ Limited | ✅ To BigTable | ✅ To RDS |
| **Data Sharing** | ✅ Snowflake Shares | ❌ No | ✅ Dataset sharing | ❌ No |

---

## When to Use Each Platform

### Use Snowflake When...
- ✅ You want ease-of-use and SQL-first approach
- ✅ You need zero-copy clones for testing
- ✅ You want time travel built-in
- ✅ You work across multiple clouds
- ✅ Team has strong SQL skills

### Use Databricks When...
- ✅ You're doing ML/AI on structured + unstructured data
- ✅ You need cost-effective data lake + warehouse combo
- ✅ Your data volumes are massive (TB+)
- ✅ You want to process raw files (JSON, images, logs)
- ✅ You prefer Python/Scala for transforms

### Use BigQuery When...
- ✅ You're already in Google Cloud ecosystem
- ✅ You have massive queries (100GB+ scans)
- ✅ You want pure serverless (no cluster management)
- ✅ You value fast query times over cost
- ✅ You want to build ML models in SQL (BQML)

### Use Redshift When...
- ✅ You're already in AWS ecosystem
- ✅ You have stable, predictable workloads
- ✅ You need (true) data warehouse (not lake)
- ✅ You have strong database administration team
- ✅ You need fine-grained query cost control

---

## Migration Between Platforms

**Most Common Path:** Single platform choice (most organizations stick with their choice)

**If you must migrate:**

**Snowflake → BigQuery:**
- Export Snowflake data to CSV/Parquet
- Create BigQuery tables
- Update partition/clustering (different columns)
- Most SQL syntax compatible
- Estimated: 2-4 weeks

**Any Platform → Snowflake:**
- Load data to S3/Azure/GCS
- Use Snowflake COPY command
- Easiest migration target
- Estimated: 1-3 weeks

---

## Summary: When to Choose

| Scenario | Best Choice | Why |
|----------|-------------|-----|
| "I'm new to warehouses" | Snowflake | Easiest to learn |
| "I do lots of ML + queries" | Databricks | Built for both |
| "I have massive Google projects" | BigQuery | Tight GCP integration |
| "I'm enterprise AWS" | Redshift | Proven, stable |
| "I want cheapest cost" | BigQuery | Per-query pricing |
| "I want ease of use" | Snowflake | Least config |
| "I want multi-cloud" | Snowflake/Databricks | AWS/Azure/GCP all supported |
| "I want zero-copy testing" | Snowflake | Only platform with this |

---

## Next Steps

After understanding architecture:
- 👉 See [Platform Selection Guide](02-platform-selection-guide.md) for decision framework
- 👉 Review [Optimization Comparison](../optimization/) to see tuning differences
- 👉 Complete capstone project on chosen platform

---

*Last Updated: March 2026*
