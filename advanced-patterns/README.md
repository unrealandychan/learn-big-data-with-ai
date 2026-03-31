# Advanced Patterns & Capstone Project

**Duration:** 12-16 hours total  
**Prerequisites:** Complete all previous modules (or at least 2 platforms + fundamentals)

## Overview: Beyond Basic Warehouses

Once you've mastered the basics, these advanced topics unlock powerful use cases:
- **Streaming:** Real-time data ingestion and analytics
- **ML Integration:** Building predictive models directly in warehouse
- **Capstone:** End-to-end project leveraging all concepts

---

## Contents

1. **[Streaming Analytics](01-streaming-analytics.md)** - Real-time data ingestion (4 hours)
2. **[ML & Analytics Integration](02-ml-analytics-integration.md)** - Prediction (4 hours)
3. **[Unified Capstone Project](03-capstone-project.md)** - Apply everything (8-20 hours)

---

## Module 1: Streaming Analytics (4 hours)

### What is Streaming?

Traditional (Batch) Analytics:
```
9 AM: Extract yesterday's data
10 AM: Transform data  
11 AM: Load to warehouse
11:15 AM: Users see yesterday's data
```

Streaming Analytics:
```
Transaction happens → Immediately in warehouse → Users see now
(Sub-second latency)
```

### Key Concepts

**Sources:** Kafka, AWS Kinesis, GCP Pub/Sub
- Message queues that buffer events
- Producers write events
- Consumers read and process

**Stream Processing:** Apache Spark, Kafka Streams
- Read events from source
- Apply transformations
- Sink results to warehouse

**Sinks:** Where processed data goes
- Data warehouse (Snowflake, BigQuery)
- Cache (Redis, Memcached)
- Data lake (S3, GCS)

### Example: Real-Time Website Events

```
User clicks → Event sent to Kafka → Stream processor reads event
         ↓
    Counts by page/user → Updated every 10 seconds → Dashboard shows live counts
         ↓
    Users see website traffic in real-time (no 24-hour delay!)
```

### Platform Support

| Platform | Streaming Support | Best Use |
|----------|------------------|----------|
| **Snowflake** | Limited (Snowpipe for files) | File-based streaming |
| **Databricks** | ✅ Excellent (Stream tables) | Event streams + ML |
| **BigQuery** | ✅ Good (Streaming inserts) | High-volume inserts |
| **Redshift** | Limited | Not recommended |

---

## Module 2: ML & Analytics Integration (4 hours)

### ML in the Warehouse

Traditional ML:
```
Export data from warehouse → Python/R environment → Train model → Move model to production
(3 separate systems, data movement, complexity)
```

Modern Warehouse ML:
```
SELECT features from warehouse → Build model → Predict → Results back in warehouse
(All in one place, simple, fast, auditable)
```

### Approaches

**BQML (BigQuery ML):** SQL-based ML
```sql
CREATE MODEL sales_forecast AS
SELECT date, revenue, product_id, amount as label
FROM historical_sales
WHERE date >= '2024-01-01';
```

**MLflow (Databricks):** Full ML lifecycle
```python
with mlflow.start_run():
    model = train_model(training_data)
    mlflow.log_model(model, "demand_forecast")
    pred = model.predict(new_data)
```

**Snowflake Cortex:** AI built-in
```sql
SELECT snowflake.cortex.complete('mistral-large', 
    'Predict churn for customer: ' || customer_data)
```

### Feature Store

**Problem:** Data scientists create features but engineers use different features (inconsistency)

**Solution:** Feature Store (single source of truth)

```
Data Warehouse → Feature Store → ML Models & BI Tools
(compute once, use everywhere)
```

Features stored:
- Customer lifetime value
- Product popularity
- User engagement score
- Seasonal patterns

---

## Module 3: Unified Capstone Project (20+ hours)

### Project Scenario: Multi-Channel Retail Analytics

You're building a warehouse for an online and brick-and-mortar retailer.

**Requirements:**
- 5 data sources (online orders, store transactions, customer CRM, inventory, marketing)
- 500M transactions over 2 years
- Daily refresh (freshness SLA: 24-hour)
- $10K/month budget
- Executive dashboards + operational reports + ML scoring

### Deliverables (Per Platform)

For each platform, implement and document:

1. **Architecture Design** (2-3 hours)
   - Data pipeline design
   - Schema design (dimensional model)
   - Infrastructure sizing

2. **Implementation** (6-8 hours)
   - Set up data extraction (Fivetran or scripts)
   - Build dbt models (staging, intermediate, marts)
   - Load sample data
   - Create dimensional schema

3. **Quality Assurance** (2-3 hours)
   - Data quality tests (dbt/Great Expectations)
   - Quality dashboards
   - SLA definition

4. **Optimization** (3-4 hours)
   - Run baseline queries
   - Optimize for cost
   - Benchmark vs other queries

5. **Governance** (2 hours)
   - Access control
   - Data catalog
   - Lineage documentation

6. **Orchestration** (2-3 hours)
   - Set up Airflow or scheduler
   - Automate daily refresh
   - Monitor and alert

7. **Capstone Analysis** (2-3 hours)
   - Compare platforms:
     - Time to implement
     - Cost per month
     - Query performance
     - Ease of use
   - Write recommendation

---

## Capstone Learning Outcomes

After completing capstone, you will be able to:

✅ Design warehouses from scratch based on business requirements  
✅ Implement production-quality pipelines  
✅ Optimize for cost and performance  
✅ Justify platform choices based on data  
✅ Present findings to technical and business stakeholders  
✅ Make informed decisions about warehouse platforms  

---

## How These Modules Relate

```
Fundamentals (1-4) - Business concepts, SQL, modeling, setup
        ↓
Platform Modules (Snowflake, Databricks, BigQuery, Redshift)
        ↓
Optimization - Make queries fast and cheap
        ↓
Governance - Make systems reliable and secure
        ↓
Advanced Patterns
    - Streaming → Real-time analytics
    - ML Integration → Predictions
        ↓
Capstone Project → Tie everything together
```

---

## Time Breakdown

### If You Have 4 Weeks

**Week 1-2:** Complete 2 platform modules + fundamentals  
**Week 3:** Optimization + Governance basics  
**Week 4:** Capstone project (simplified version)  
**Total:** ~60 hours

### If You Have 8 Weeks

**Week 1-2:** Fundamentals + 1st platform (deep)  
**Week 3:** 2nd platform + comparison  
**Week 4:** Optimization focus  
**Week 5:** Governance + Orchestration  
**Week 6:** Advanced patterns  
**Week 7-8:** Full capstone (all platforms)  
**Total:** ~100+ hours

### If You Have 1 Week (Crash Course!)

**Day 1:** Fundamentals (all 4)  
**Day 2:** Snowflake module + labs  
**Day 3:** BigQuery module + labs  
**Day 4:** Comparison + optimization highlights  
**Day 5:** Capstone (simplified on Snowflake)  
**Total:** ~40 hours

---

## Success Criteria for Capstone

### Satisfactory (B Grade)
- ✅ Dimensional model designed properly (fact/dimension identification correct)
- ✅ Data loading pipeline works (no manual steps)
- ✅ 5+ key queries work and return correct results
- ✅ Basic data quality tests present
- ✅ Documentation explains design choices

### Excellent (A Grade)
- ✅ All satisfactory criteria met
- ✅ Optimized queries (documented optimization steps)
- ✅ Comprehensive data quality (10+ tests, monitoring)
- ✅ Governance implemented (access control, catalog)
- ✅ Orchestration set up (automated pipeline)
- ✅ Clear platform comparison (cost, performance, ease)
- ✅ Recommendation presented with supporting analysis

---

## Capstone Presentation Structure

### Technical Presentation (30 minutes)

1. **Problem Statement** (2 min)
   - "We need a warehouse to support X analytics for Y users"

2. **Architecture** (5 min)
   - Data sources and volumes
   - Schema design (diagram)
   - Technology choices and why

3. **Implementation** (5 min)
   - Live demo of pipeline
   - Show data flowing through layers
   - Query performance examples

4. **Optimization & Costs** (5 min)
   - Before/after query performance
   - Cost breakdown
   - Optimization decisions

5. **Governance & Operations** (5 min)
   - Access control and security
   - Quality monitoring
   - Operational dashboards

6. **Platform Comparison** (5 min)
   - Comparison matrix (cost, performance, ease)
   - Recommendation (if comparing platforms)
   - Lessons learned

7. **Q&A** (3 min)

---

## Next Steps

Ready to tackle advanced topics?

1. **Start with streaming** if you need real-time analytics  
   → [Streaming Analytics](01-streaming-analytics.md)

2. **Jump to ML integration** if you need predictions  
   → [ML & Analytics Integration](02-ml-analytics-integration.md)

3. **Dive into capstone** to apply everything  
   → [Unified Capstone Project](03-capstone-project.md)

---

## Resources for Advanced Topics

### Streaming Resources
- Kafka documentation
- Apache Spark Structured Streaming guide
- Platform-specific streaming guides (Databricks, BigQuery Stream tables)

### ML Resources
- BigQuery ML documentation
- Databricks MLflow guide
- dbt macro library for ML feature engineering

### Project Management
- dbt project best practices
- Airflow DAG design patterns
- Data warehousing anti-patterns to avoid

---

*Last Updated: March 2026*
