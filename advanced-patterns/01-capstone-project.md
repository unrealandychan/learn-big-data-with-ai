# Capstone Project: Multi-Platform Retail Analytics

## Learning Outcomes
- Design complete end-to-end data warehouse
- Implement across multiple platforms (Snowflake, Databricks, BigQuery, Redshift)
- Build production-grade pipelines with dbt and Airflow
- Create business intelligence applications
- Optimize for cost and performance

**Estimated Time:** 20-25 hours  
**Prerequisites:** All fundamentals and at least 2 platform modules

## Project Scenario

You're building a real-time analytics platform for a multi-region retail company with $100M annual revenue. Requirements:

```
┌─────────────────────────────────────────────────────────┐
│           Retail Analytics Platform                     │
├────────────────────┬────────────────────┬───────────────┤
│ BI/Analytics       │ Real-time Dashboards   │ ML Models   │
│ ├─Revenue trends   │ ├─Inventory levels │ ├─Forecasting│
│ ├─Customer cohorts │ ├─Sales velocity   │ ├─Churn risk │
│ └─Operational KPIs │ └─Customer flow    │ └─Recom.    │
└────────────────────┴────────────────────┴───────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
     ┌───┴────┬───────────┬───┴────────┬──────────┴───┐
     │        │           │            │              │
   dbt   Spark SQL    Streaming      MLflow      Orchestration
     │        │           │            │              │
  Business   Data      Real-time    Feature       Airflow
  Logic     Modeling    Ingestion     Store        DAGs
     │        │           │            │              │
     └────────┴───────────┴────────────┴──────────────┘
              ▼
      ┌──────────────────────┐
      │  Data Lake/Warehouse │
      │  (Platform-specific) │
      └──────────────────────┘
              ▼
      ┌──────────────────────────────┐
      │  Data Sources                │
      ├──────────────────────────────┤
      │ ├─ POS Systems (5000 stores) │
      │ ├─ E-commerce platform       │
      │ ├─ Customer CRM              │
      │ ├─ Inventory system          │
      │ └─ Supply chain system       │
      └──────────────────────────────┘
```

## Deliverables by Platform

### Deliverable 1: Dimensional Data Model

```sql
-- Fact table: Daily transactions
CREATE TABLE fact_transactions (
  transaction_id BIGINT PRIMARY KEY,
  sk_customer INT,
  sk_store INT,
  sk_product INT,
  sk_date INT,
  quantity INT,
  transaction_amount DECIMAL(10,2),
  cost_amount DECIMAL(10,2),
  revenue_amount DECIMAL(10,2),
  transaction_timestamp TIMESTAMP,
  payment_method STRING,
  online_flag BOOL
);

-- Dimension tables with SCD Type 2
CREATE TABLE dim_customer_scd2 (
  sk_customer INT PRIMARY KEY,
  customer_id INT,
  name STRING,
  email STRING,
  tier STRING,
  lifetime_value DECIMAL(12,2),
  start_date DATE,
  end_date DATE,
  is_current BOOL
);

CREATE TABLE dim_store (
  sk_store INT PRIMARY KEY,
  store_id INT,
  region STRING,
  country STRING,
  store_manager STRING
);

CREATE TABLE dim_product (
  sk_product INT PRIMARY KEY,
  product_id INT,
  product_name STRING,
  category STRING,
  subcategory STRING,
  cost DECIMAL(8,2)
);

CREATE TABLE dim_date (
  sk_date INT PRIMARY KEY,
  calendar_date DATE,
  year INT,
  quarter INT,
  month INT,
  week INT,
  day_of_week INT
);
```

### Deliverable 2: Data Warehouse Implementation

Choose one platform and implement:

**Option A: Snowflake**
- Bronze layer: Load raw JSON from S3 via Snowpipe
- Silver layer: Cleansed and validated parquet data
- Gold layer: Dimensional model with slowly changing dimensions
- Time Travel: Recover accidentally deleted customer records
- Zero-Copy Clones: Create development/test copies instantly

**Option B: Databricks**
- Bronze layer: Raw data in Delta format
- Silver layer: Deduplicated with quality checks
- Gold layer: Aggregated metrics by customer/store
- Unity Catalog: Govern access to sensitive customer data
- MLflow: Track model versions and performance

**Option C: BigQuery**
- Nested STRUCT/ARRAY for customer purchase history
- Materialized views for common aggregations
- Scheduled queries for incremental loads
- BigQuery ML: Churn prediction and forecasting models

**Option D: Amazon Redshift**
- Distribution key by customer_id for join performance
- Sort keys on transaction_date for time-range queries
- Spectrum: Query 10 years of archived data in S3
- Concurrency scaling for peak demand periods

### Deliverable 3: Data Pipeline (dbt + Airflow)

```yaml
# dbt project structure
models/
├─ staging/
│  ├─ stg_raw_transactions.sql      # Clean & deduplicate
│  ├─ stg_raw_customers.sql
│  └─ stg_raw_products.sql
├─ intermediate/
│  ├─ int_customer_transactions.sql # Aggregate metrics
│  └─ int_store_performance.sql
└─ marts/
   ├─ fct_transactions.sql
   ├─ dim_customer_scd2.sql
   ├─ dim_store.sql
   └─ dim_product.sql

# Airflow DAG
daily_pipeline:
  ├─ [08:00] Extract from POS systems
  ├─ [08:15] Extract from e-commerce
  ├─ [08:30] dbt run (staging + intermediate + marts)
  ├─ [08:45] Data quality tests
  ├─ [09:00] Materialized view refresh
  ├─ [09:15] Update customer lifetime value
  └─ [10:00] Feature engineering for ML
```

### Deliverable 4: Business Intelligence Layer

Interactive dashboards showing:

1. **Executive Dashboard**
   - Total revenue YTD vs last year
   - Customer count by tier
   - Top 10 products by revenue
   - Regional performance heat map

2. **Operational Dashboard**
   - Real-time transaction activity by store
   - Inventory levels by product
   - Payment method mix
   - Staff scheduling optimization

3. **Customer Analytics Dashboard**
   - Customer lifetime value distribution
   - Churn risk segment analysis
   - Product affinity by customer demographic
   - Repeat purchase rates

### Deliverable 5: Advanced Analytics

```python
# ML Model: Customer Churn Prediction
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from mlflow import log_model, log_metric

# Feature engineering
features = {
    'days_since_last_purchase': compute_days_since_purchase(),
    'purchase_frequency_6m': count_purchases_last_6_months(),
    'avg_order_value_6m': compute_avg_order_value(),
    'email_engagement_score': compute_engagement_score(),
    'promotional_sensitivity': compute_promo_response(),
}

# Train model
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(features, target_churn)

# Log to MLflow
log_model(model, 'churn_predictor')
log_metric('auc_score', model_auc)

# Generate predictions for batch scoring
predictions = model.predict_proba(new_customers)
```

### Deliverable 6: Cost Optimization Report

Analyze spending across platforms:

```
Snowflake ($50K/month):
├─ Compute credits: $30K (~60% scanning text)
├─ Storage: $15K (1.2TB)
├─ Data sharing: $5K
└─ Optimization: Cluster on customer_id, reduce data scanning

Databricks ($35K/month):
├─ DBU compute: $25K
├─ Storage: $8K (shared with S3)
└─ Optimization: Use Z-order indexing, cache hot tables

BigQuery ($25K/month):
├─ Slots reservation: $20K (100 slots)
├─ Storage: $5K
└─ Optimization: Partition all tables by date

Redshift ($40K/month):
├─ Node costs: $30K (dc2.8xlarge x 4)
├─ Storage: $10K
└─ Optimization: DISTKEY tuning, row-level compression
```

## Grading Rubric

| Component | Excellent | Good | Satisfactory | Needs Work |
|-----------|-----------|------|--------------|-----------|
| **Data Model** (20%) | 3NF properly, SCD2 implemented | Well-normalized, conformed dimensions | Basic star schema | Denormalized or missing |
| **Data Pipeline** (25%) | Automated, dbt tests, Airflow scheduling | dbt with tests, manual scheduling | dbt models only | No pipeline |
| **Documentation** (15%) | Complete lineage, data dictionary, runbooks | Schema documented, basic lineage | Inline comments | None |
| **Query Performance** (15%) | <1s for key reports, optimized | <5s for key reports | <30s response time | >1min queries |
| **Data Quality** (15%) | SLAs defined, 99.95% completeness | Tests defined, >99% completeness | Basic validation | Ad-hoc checks |
| **Deployment** (10%) | Prod-ready, monitoring, alerting | Staging environment, docs | Local development | Incomplete |

## Project Timeline

**Week 1-2:** Data modeling and platform setup
- Design fact/dimension tables
- Create datasets/schemas
- Set up development sandbox

**Week 3-4:** ETL pipeline development
- Load raw data (Bronze)
- Create staging layer (Silver)
- Build dimensional model (Gold)

**Week 5-6:** Data quality & testing
- Implement dbt tests
- Create Great Expectations suite
- Define SLAs

**Week 7-8:** BI and ML layer
- Build dashboards
- Feature engineering for models
- Train initial ML models

**Week 9-10:** Optimization & deployment
- Query performance tuning
- Cost analysis by platform
- Production deployment

## Key Success Metrics

```
Data Quality:
  └─ Completeness: >99.95%
  └─ Freshness: <2 hours lag
  └─ Accuracy: 99.99% on key metrics

Performance:
  └─ Query response time: <5 seconds for dashboards
  └─ Pipeline duration: <60 minutes
  └─ Data availability: 99.9% uptime

Cost Efficiency:
  └─ Cost per GB stored: <$5
  └─ Cost per query: <$0.50
  └─ Utilization: >70% of provisioned capacity
```

## Resources & References

- Course modules for each platform
- Data transformation patterns in dbt docs
- Cloud provider documentation
- Great Expectations library guide
- Apache Airflow best practices

*Last Updated: March 2026*
