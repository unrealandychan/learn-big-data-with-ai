# Platform Selection Guide

**Duration:** 2 hours (reference document)  
**Prerequisites:** Completed at least 2 platform modules

## Quick Decision Framework

**Start here with 5 questions:**

### 1. Where is your data?
- ❓ **In AWS?** → Consider Redshift or Snowflake
- ❓ **In Google Cloud?** → Prefer BigQuery, else Snowflake
- ❓ **In Azure?** → Snowflake or Databricks
- ❓ **Multi-cloud?** → Snowflake or Databricks only

### 2. What's your primary use case?
- ❓ **BI/Reporting:** Snowflake (easiest) or BigQuery (cheapest at scale)
- ❓ **ML/Data Science:** Databricks (built for this)
- ❓ **Enterprise Data Warehouse:** Redshift (proven) or Snowflake (easier)
- ❓ **Data Lake + Analytics:** Databricks (lakehouse) or Snowflake

### 3. What's your query volume?
- ❓ **Small (< 1GB/month):** BigQuery (free tier) or Snowflake (trial)
- ❓ **Medium (1-10TB/month):** Snowflake (sweet spot)
- ❓ **Large (10-100TB/month):** BigQuery slots or Databricks or Redshift
- ❓ **Massive (>100TB/month):** Redshift (or BigQuery with annual slots)

### 4. How much SQL do you have?
- ❓ **Lots (heavy transformation):** Snowflake or Redshift (SQL-optimized)
- ❓ **Medium (some dbt/ELT):** Any platform (all support dbt)
- ❓ **Light (mostly loading data):** Databricks (Spark-optimized)

### 5. What's your team profile?
- ❓ **SQL experts:** Snowflake, BigQuery, or Redshift
- ❓ **Data scientists & engineers:** Databricks
- ❓ **Business analysts:** Snowflake (easiest UI)
- ❓ **AWS DBAs:** Redshift
- ❓ **Google Cloud team:** BigQuery

---

## Decision Matrix: Choose Your Platform

| Use Case | Snowflake | Databricks | BigQuery | Redshift |
|----------|-----------|-----------|----------|----------|
| **Basic BI Reporting** | ✅✅✅ | ✅✅ | ✅✅✅ | ✅✅ |
| **Ad-hoc Exploration** | ✅✅✅ | ✅✅ | ✅✅✅ | ⚠️ |
| **ETL/Data Integration** | ✅✅ | ✅✅✅ | ✅ | ✅✅ |
| **ML Model Building** | ⚠️ | ✅✅✅ | ✅✅ | ⚠️ |
| **High-Volume Analytics (>100GB)** | ✅✅ | ✅✅ | ✅✅✅ | ✅✅✅ |
| **Real-Time Streaming** | ⚠️ | ✅✅✅ | ✅✅ | ⚠️ |
| **Semi-Structured Data** | ✅✅ | ✅✅✅ | ✅✅ | ⚠️ |
| **Cost-Sensitive (small)** | ⚠️ | ✅✅ | ✅✅✅ | ✅ |
| **Cost-Sensitive (large)** | ✅✅ | ✅✅ | ✅✅✅ | ✅✅ |
| **Enterprise Security** | ✅✅✅ | ✅✅ | ✅✅ | ✅✅✅ |
| **Multi-Cloud Support** | ✅✅✅ | ✅✅✅ | ❌ | ❌ |
| **Zero Downtime Migration** | ✅✅✅ | ⚠️ | ⚠️ | ⚠️ |

**Key:** ✅✅✅ = Excellent, ✅✅ = Good, ✅ = Acceptable, ⚠️ = Suboptimal, ❌ = Poor

---

## Scenario-Based Recommendations

### Scenario 1: "I'm a BI Analyst, want to start analyzing data ASAP"

**Recommendation: Snowflake**

**Why:**
- SQL-first interface (skill transfers immediately)
- Minimal setup (web UI, create warehouse, done)
- No cluster management
- Time Travel helps with mistakes
- Free trial = $400 for learning

**Alternative:** BigQuery (if Google Cloud preferred)

**Setup Time:** 15 minutes  
**Learning Curve:** Shallow  
**Cost for 3 months:** $50-100

---

### Scenario 2: "I need to build ML models and run analytics on same data"

**Recommendation: Databricks**

**Why:**
- Lakehouse design handles both raw data (ML) and analytics
- MLflow for model governance
- Feature stores for reproducibility
- Community Edition = free forever
- Supports Python, R, SQL all together

**Alternative:** BigQuery (if already in Google Cloud)

**Setup Time:** 20 minutes  
**Learning Curve:** Medium  
**Cost for 3 months:** $0 (community) to $50 (notebooks)

---

### Scenario 3: "Our company runs everything on AWS"

**Recommendation: Redshift OR Snowflake**

**Why:**
- Both work excellently with AWS
- Redshift = AWS-native (tightest integration)
- Snowflake = easier to use, similar cost
- Start with Snowflake (easier), migrate to Redshift if needed

**Setup Time:** 20 minutes (Redshift needs cluster provisioning)  
**Learning Curve:** Medium-Hard (Redshift MPP is different)  
**Cost for 3 months:** $50-150

---

### Scenario 4: "We have massive analytics workloads with strict budgets"

**Recommendation: BigQuery with Annual Slots**

**Why:**
- On-demand: $7.50/TB = very efficient cost for huge volumes
- Annual Slots: $204K/year = $17K/month for massive workloads (competitive)
- Automatic scaling (no cluster management)
- Fastest query times

**Alternative:** Databricks (if you prefer multiple workload types)

**Setup Time:** 20 minutes  
**Learning Curve:** Shallow (SQL-first)  
**Cost for 3 months:** $0-$100 (free tier) or project-based

---

### Scenario 5: "We're evaluating all platforms to make a strategic decision"

**Recommendation: All 4! (That's this course!)**

**Why:**
- Can't make good decisions without understanding all options
- Each platform excels in different dimensions
- Your use case may favor different platforms
- Multi-cloud strategy may want multiple

**After Taking Course:**
- See [Architecture Comparison](01-architecture-comparison.md) for side-by-side
- Run capstone project on each platform
- Time the same queries and compare costs
- Present findings to stakeholders

**Estimated ROI:** $1K-2K workshop investment prevents $100K+ wrong choice

---

## Implementation Roadmap

### If You Choose Snowflake:

**Step 1 (Week 1):** Orient yourself
- Complete Snowflake module (8 hours)
- Load sample data
- Write 10 sample queries

**Step 2 (Week 2-3):** Build production schema
- Design dimensional model (from Fundamentals Module 3)
- Create fact and dimension tables
- Load real company data (or sample)

**Step 3 (Week 4):** Optimize and scale
- Study query performance
- Cluster high-traffic dimensions
- Document best practices

### If You Choose Databricks:

**Step 1 (Week 1):** Set up lakehouse
- Complete Databricks module (8-10 hours)
- Create Bronze/Silver/Gold layers
- Set up first ETL pipeline

**Step 2 (Week 2-3):** Build data quality
- Add data validation with dbt
- Create quality metrics dashboard
- Implement data contracts

**Step 3 (Week 4):** Integrate ML
- Build feature store
- Train first models
- Set up monitoring

### If You Choose BigQuery:

**Step 1 (Week 1):** Get comfortable with pricing
- Complete BigQuery module (8-10 hours)
- Understand partitioning deeply
- Practice cost estimation

**Step 2 (Week 2-3):** Load real data
- Set up data transfers from sources
- Optimize partitions and clusters
- Validate cost estimates

**Step 3 (Week 4):** Build ML models
- Create BQML models
- Set up predictions
- Monitor model performance

### If You Choose Redshift:

**Step 1 (Week 1):** Understand MPP deeply
- Complete Redshift module (10-12 hours)
- Design optimal distribution keys
- Understand query plans

**Step 2 (Week 2-3):** Load data efficiently
- Use COPY command optimization
- Test different compression options
- Monitor cluster performance

**Step 3 (Week 4):** Scale and optimize
- Identify slow queries
- Tune distribution strategies
- Plan cluster scaling

---

## Avoiding Common Mistakes

### Mistake 1: "I'll just start with the cheapest option"
**Reality:** Wrong platform choice costs $10K-100K+ in wasted effort and migration  
**Fix:** Evaluate properly on your actual workload, not spreadsheet

### Mistake 2: "Snowflake is too expensive"
**Reality:** Snowflake's $4 per credit is actually very efficient at scale  
**Fix:** Calculate your actual cost, not rumor-based estimates

### Mistake 3: "BigQuery is serverless so it's automatically cheaper"
**Reality:** Unoptimized queries are expensive; slots cost $204K/year  
**Fix:** Understand pricing model before choosing

### Mistake 4: "Redshift is old technology"
**Reality:** Redshift is actively maintained with modern features (Spectrum, RA3)  
**Fix:** Evaluate current capabilities, not history

### Mistake 5: "I should choose the platform my competitors use"
**Reality:** Your workload is likely different; choose for your needs  
**Fix:** Evaluate based on YOUR use case

---

## Migration Strategy (If You Need to Change)

### Easiest Migrations:

1. **Any → Snowflake**
   - Export to Parquet/CSV
   - Use Snowflake COPY command
   - SQL is compatible
   - **Time:** 1-3 weeks
   - **Difficulty:** Low

2. **Snowflake → BigQuery**
   - Export Snowflake tables to GCS
   - Import into BigQuery
   - Adjust partitioning/clustering
   - **Time:** 2-4 weeks
   - **Difficulty:** Medium

3. **Databricks → Snowflake**
   - Export Delta tables to Parquet
   - Load into Snowflake
   - **Time:** 1-2 weeks
   - **Difficulty:** Low

### Hardest Migrations:

1. **Any → Redshift**
   - Requires understanding MPP concepts
   - Distribution key redesign critical
   - Query rewrites likely
   - **Time:** 4-8 weeks
   - **Difficulty:** Hard

2. **Redshift → Anything**
   - Must redesign schema (MPP-specific)
   - Query logic changes
   - **Time:** 4-8 weeks
   - **Difficulty:** Hard

**Best Practice:** Choose right platform initially (avoid migration!)

---

## Summary: Decision Checklist

Before you choose, verify:

- [ ] I understand my annual data volume (GB/month)
- [ ] I know my primary use case (BI/ML/ELT/etc)
- [ ] I've considered cloud provider lock-in
- [ ] I've estimated 3-year total cost (not just month 1)
- [ ] I've verified my team's skills match platform
- [ ] I've checked if external integrations exist
- [ ] I've understood pricing model deeply
- [ ] I've reviewed security/compliance requirements
- [ ] I've talked to current users of each platform
- [ ] I've done a small POC if stakes are high

---

## Next Steps

- 👉 **Chosen a platform?** Go to that platform's module
- 👉 **Still evaluating?** Complete 2-3 platform modules and capstone project
- 👉 **Want deeper comparison?** See [Architecture Comparison](01-architecture-comparison.md)

---

*Last Updated: March 2026*
