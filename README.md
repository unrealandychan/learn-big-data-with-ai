# Big Data Warehouse Learning Course

A comprehensive, self-paced learning course covering the four major cloud data warehouse platforms: **Snowflake**, **Databricks**, **BigQuery**, and **Amazon Redshift**.

## 🎯 The Big Picture: What Problem Are We Solving?

Before diving into any product, it helps to understand the **single core business problem** they all exist to solve — and how each approaches it differently.

### The Root Problem

Every organization collects operational data: orders, events, user actions, sensor readings. That data lives in transactional databases optimized for **writing fast** (OLTP). But analysts need to **read and aggregate millions of rows to answer business questions** — and regular databases fall apart at that scale.

```
Typical Company Pain Points:
├─ "Our analytics query crashed the production database"
├─ "It takes 2 hours to run the weekly revenue report"
├─ "We have data in 6 different apps and can't join it"
├─ "Our data warehouse is too expensive / too slow / too complex"
└─ "We need the data team AND data scientists to work on the same data"
```

These four platforms exist to solve these problems — just with different trade-offs.

---

### What Problem Does Each Platform Solve — and How?

| | Snowflake | Databricks | BigQuery | Redshift |
|---|---|---|---|---|
| **Primary problem it solves** | Making SQL analytics easy and scalable, without infrastructure ops | Unifying data engineering, analytics, and ML on one platform | Getting to insights fast without managing any servers | High-performance analytics deeply integrated with AWS |
| **How it solves it** | Separates compute from storage; SQL-first; auto-scales virtual warehouses | Lakehouse model: Delta Lake adds ACID + schema to open files; Spark engine for scale | Serverless columnar engine; pay per byte scanned; Google manages everything | MPP distributed processing; distribution/sort keys for high-performance joins |
| **The key insight** | You should scale compute separately from how much data you store | Data lakes and warehouses should be one thing, not two | Analytics should feel like a Google search — instant, no setup | Parallel compute across many nodes makes massive joins practical |
| **What breaks without it** | Analytics queries slow down databases; no cross-app data joins | Separate ETL, BI, and ML tools = data silos and duplication | Teams spend weeks on infra before any analysis happens | Single nodes can't aggregate billions of rows in seconds |

---

### Plain-Language Summary

- **Snowflake** = *"Managed warehouse with strong performance and minimal ops — ideal for BI and analytics teams."*
- **Databricks** = *"Best when you need heavy data pipelines, streaming, and ML on the same data — a true lakehouse."*
- **BigQuery** = *"Fastest way to start analytics at scale — serverless, pay-per-query, minimal setup."*
- **Redshift** = *"High-performance AWS-native warehouse — powerful when you invest in tuning and are AWS-first."*

---

### How to Think About Choosing One

```
Do you need ML/AI + data engineering in one place?        → Databricks
Are you already deep in GCP and want minimal ops?         → BigQuery
Are you deep in AWS and want deep performance control?    → Redshift
Do you want ease-of-use, SQL-first, multi-cloud?          → Snowflake
```

All four are covered in depth in this course. You'll understand not just *how* to use them, but *why* each design choice was made.

---

## 📚 Course Overview

This course is designed for data professionals with **basic SQL knowledge** who want to master modern cloud data warehousing. Through a structured, 26-week curriculum, you'll progress from fundamental concepts to advanced optimization techniques, learning each platform deeply before comparing them all.

### What You'll Learn

- **Foundational Concepts:** OLAP vs OLTP, dimensional modeling, ETL/ELT patterns
- **SQL for Analytics:** Window functions, CTEs, query optimization, dimensional queries
- **Dimensional Modeling:** Star schemas, Slowly Changing Dimensions (SCD), fact table design
- **Platform-Specific Deep Dives:** Architecture, data loading, query optimization, semi-structured data handling
- **Apache Open-Source Stack:** Hadoop (HDFS, YARN, Hive), Apache Spark (batch + streaming + MLlib), Apache Flink (real-time stateful streaming), Apache Kafka (distributed event streaming + CDC)
- **Performance Tuning:** Query execution plans, cost optimization, partitioning strategies
- **Data Governance:** dbt, data quality frameworks, access control, metadata management
- **Real-World Integration:** Orchestration with Airflow, streaming analytics, ML integration

### Who Should Take This Course

- Data Analysts transitioning to warehousing
- Data Engineers building warehouse solutions
- Analytics Engineers optimizing data pipelines
- Data Architects evaluating platform options

### Prerequisites

- **Required:** Comfortable with SQL (SELECT, JOIN, GROUP BY)
- **Recommended:** Basic understanding of databases and ETL concepts
- **Helpful:** Access to free tier accounts on one or more cloud platforms

### What You'll Need

- Free accounts (or trial access) to: Snowflake, Databricks, BigQuery, Redshift
- A code editor (VS Code recommended)
- Basic command-line familiarity
- Time: 3-5 hours per week for 26 weeks

## 🗂️ Course Structure

The course is divided into **7 progressive levels** organized by topic:

### Level 1-2: Fundamentals (Weeks 1-8)
[`/fundamentals/`](./fundamentals/) - Data warehouse concepts, SQL essentials, dimensional modeling

### Level 3: Platform-Specific Deep Dives (Weeks 9-14)
- [`/snowflake/`](./snowflake/) - Compute/storage separation architecture
- [`/databricks/`](./databricks/) - Lakehouse and Delta Lake
- [`/bigquery/`](./bigquery/) - Columnar storage and serverless analytics
- [`/redshift/`](./redshift/) - Massively Parallel Processing (MPP)

### Level 3.5: Apache Open-Source Stack (Weeks 15-22)
[`/apache-stack/`](./apache-stack/) - The open-source foundation powering the modern data world
- [`01-hadoop-ecosystem.md`](./apache-stack/01-hadoop-ecosystem.md) - HDFS, MapReduce, YARN, Hive, HBase, Sqoop
- [`02-apache-spark.md`](./apache-stack/02-apache-spark.md) - DataFrames, Spark SQL, Structured Streaming, MLlib, Delta Lake
- [`03-apache-flink.md`](./apache-stack/03-apache-flink.md) - Event-time streaming, stateful processing, exactly-once
- [`04-apache-kafka.md`](./apache-stack/04-apache-kafka.md) - Distributed event streaming, CDC, Schema Registry
- [`05-hands-on-labs.md`](./apache-stack/05-hands-on-labs.md) - End-to-end Kafka → Flink + Spark pipeline labs

### Level 3.6: Data File Formats
[`/file-formats/`](./file-formats/) - The storage formats that underpin every pipeline
- [`01-parquet.md`](./file-formats/01-parquet.md) - Columnar storage, predicate pushdown, compression, schema evolution
- [`02-avro.md`](./file-formats/02-avro.md) - Row-based streaming format, Kafka + Schema Registry integration
- [`03-orc-and-others.md`](./file-formats/03-orc-and-others.md) - ORC, JSON Lines, CSV, Delta Lake as a format layer
- [`04-format-comparison.md`](./file-formats/04-format-comparison.md) - Decision guide, benchmarks, architecture patterns

### Level 4: Optimization & Performance (Weeks 23-26)
[`/optimization/`](./optimization/) - Query tuning, cost optimization, benchmarking

### Level 5: Governance & Integration (Weeks 27-30)
[`/governance-integration/`](./governance-integration/) - dbt, data quality, orchestration

### Level 6: Advanced Patterns (Weeks 31-34)
[`/advanced-patterns/`](./advanced-patterns/) - Streaming, ML integration, capstone project

### Cross-Platform Learning (Weeks 23-28)
[`/platform-comparison/`](./platform-comparison/) - Platform selection guide, architecture comparison

## 📖 Study Plan

Choose the track that matches your goal and available time. Every track builds on the same material — the difference is depth and focus.

---

### Step 0: Which Track Are You?

```
Are you purely analyzing data (Excel → SQL → BI tools)?      → Track A: Data Analyst
Do you build pipelines & transform data for a living?         → Track B: Data Engineer
Do you write SQL models and work with dbt/BI?                 → Track C: Analytics Engineer
Do you design systems and evaluate platforms for orgs?        → Track D: Data Architect
Just want a quick overview of all 4 platforms to compare?     → Track E: Express Overview
```

---

### Track A — Data Analyst (12 weeks, ~3 hrs/week)

**Goal:** Understand warehouses deeply enough to query them well, model data, and recommend the right platform.

| Week | Module | Goal |
|------|--------|------|
| 1 | [Concepts](./fundamentals/01-data-warehouse-concepts.md) | Understand why warehouses exist and what each platform solves |
| 2 | [SQL for Warehouses](./fundamentals/02-sql-for-warehouses.md) | Window functions, CTEs, analytical SQL patterns |
| 3 | [Dimensional Modeling](./fundamentals/03-dimensional-modeling.md) | Star schema, facts, dimensions — how analysts query data |
| 4 | [Setup](./fundamentals/04-hands-on-setup.md) | Create free accounts, load sample data on Snowflake |
| 5–6 | [Snowflake](./snowflake/) | Architecture + querying + optimization (skip data loading internals) |
| 7–8 | [BigQuery](./bigquery/) | Architecture + querying + BQML |
| 9–10 | [Platform Comparison](./platform-comparison/) | Understand trade-offs and when to use what |
| 11 | [Governance](./governance-integration/01-dbt-fundamentals.md) | dbt basics — how analysts use it |
| 12 | [Capstone](./advanced-patterns/01-capstone-project.md) | Complete Option A or C of the capstone project |

**Skip:** Databricks ML integration, Redshift cluster management, Airflow DAGs.

**Milestone check (end of week 4):** Can you write a window function query and explain star schema to a colleague?

---

### Track B — Data Engineer (26 weeks, ~4 hrs/week)

**Goal:** Build production-grade pipelines on all 4 platforms with testing, orchestration, and governance.

| Weeks | Module | Goal |
|-------|--------|------|
| 1–2 | [Concepts](./fundamentals/01-data-warehouse-concepts.md) + [SQL](./fundamentals/02-sql-for-warehouses.md) | Solid fundamentals |
| 3–4 | [Modeling](./fundamentals/03-dimensional-modeling.md) + [Setup](./fundamentals/04-hands-on-setup.md) | Model design + environment ready |
| 5–7 | [Snowflake](./snowflake/) | All 5 modules: architecture, loading, optimization, semi-structured, labs |
| 8–10 | [Databricks](./databricks/) | All 5 modules: Delta Lake, Auto Loader, Z-order, ML, labs |
| 11–13 | [BigQuery](./bigquery/) | All 5 modules: architecture, partitioning, BQML, labs |
| 14–16 | [Redshift](./redshift/) | All 5 modules: MPP, COPY, distribution keys, cluster management, labs |
| 17–18 | [Platform Comparison](./platform-comparison/) | Architecture comparison + selection guide |
| 19–20 | [dbt + Data Quality](./governance-integration/) | Modules 1–2: dbt fundamentals + Great Expectations |
| 21–22 | [Governance + Orchestration](./governance-integration/) | Modules 3–4: Airflow DAGs + RBAC patterns |
| 23–26 | [Capstone](./advanced-patterns/01-capstone-project.md) | Full retail analytics project on your chosen platform |

**Milestone check (end of week 10):** Have you successfully loaded data, run a dbt model, and written an incremental MERGE on at least 2 platforms?

---

### Track C — Analytics Engineer (18 weeks, ~4 hrs/week)

**Goal:** Master SQL modeling, dbt, data quality, and platform-specific transformation patterns.

| Weeks | Module | Goal |
|-------|--------|------|
| 1–2 | [Concepts](./fundamentals/01-data-warehouse-concepts.md) + [SQL](./fundamentals/02-sql-for-warehouses.md) | Strong SQL foundation |
| 3–4 | [Modeling](./fundamentals/03-dimensional-modeling.md) + [Setup](./fundamentals/04-hands-on-setup.md) | Kimball methodology + environment |
| 5–7 | [Snowflake](./snowflake/) | Architecture, querying, semi-structured data |
| 8–9 | [BigQuery](./bigquery/) | Partitioning, clustering, BQML |
| 10–11 | [Databricks](./databricks/) | Medallion architecture, Delta Lake loading |
| 12–13 | [dbt Fundamentals](./governance-integration/01-dbt-fundamentals.md) + [Data Quality](./governance-integration/02-data-quality.md) | Core tooling |
| 14 | [Governance Patterns](./governance-integration/04-governance-patterns.md) | RBAC, lineage, compliance |
| 15–16 | [Platform Comparison](./platform-comparison/) | Understand trade-offs for your stack |
| 17–18 | [Capstone](./advanced-patterns/01-capstone-project.md) | Deliver Deliverables 1–3 (model + pipeline + docs) |

**Skip:** Redshift cluster internals, Airflow infrastructure, Databricks ML.

**Milestone check (end of week 12):** Do you have a dbt project with models, tests, and documentation deployed on at least one platform?

---

### Track D — Data Architect (26+ weeks, ~5 hrs/week)

**Goal:** Enable you to evaluate, recommend, and design multi-platform warehouse strategies.

Complete the full 26-week curriculum in order, with these additions:

- **After each platform:** Write a 1-page pros/cons decision note
- **After platform comparison:** Build your own decision matrix for a real scenario
- **Throughout:** Pay attention to pricing models, lock-in risk, and governance options
- **Capstone:** Complete all 6 deliverables across at least 2 platforms, then write a platform recommendation report

**Key questions to answer by end:**
1. For a fintech startup with 5 engineers on GCP — which platform and why?
2. For an enterprise healthcare company on AWS with strict HIPAA requirements — which platform?
3. For an e-commerce company that needs real-time ML recommendations — which platform?

---

### Track E — Express Overview (2 weeks, ~2 hrs/day)

**Goal:** Quickly understand what each platform does, how they're different, and which fits your situation.

| Day | Content |
|-----|---------|
| 1 | Read Section 0 of [Concepts](./fundamentals/01-data-warehouse-concepts.md) — the "Why does this exist?" section |
| 2 | Read [Platform Comparison Part 1](./platform-comparison/01-architecture-comparison.md) — problem/solution overview |
| 3 | Skim each platform's `README.md`: [Snowflake](./snowflake/README.md), [Databricks](./databricks/README.md), [BigQuery](./bigquery/README.md), [Redshift](./redshift/README.md) |
| 4 | Read [Platform Comparison Part 2](./platform-comparison/01-architecture-comparison.md) — technical deep dive |
| 5 | Read [Platform Selection Guide](./platform-comparison/02-platform-selection-guide.md) — decision framework |
| 6–7 | Try hands-on setup on the one platform most relevant to you |
| 8–10 | Read the architecture module (01-architecture.md) for your chosen platform |
| 11–14 | Complete the hands-on lab for your chosen platform |

---

### Universal Study Tips

| Tip | Why It Matters |
|-----|---------------|
| **Do every lab, even partial** | Reading alone doesn't build intuition — running queries does |
| **Set up accounts in Week 1** | Free tier limits are generous; start the clock early |
| **Keep a weekly notes file** | Write 3 things you learned + 1 question each week |
| **Use the comparison table constantly** | After each platform, revisit [the comparison](./platform-comparison/01-architecture-comparison.md) with fresh eyes |
| **Don't skip Fundamentals** | Students who skip to platforms consistently struggle with the "why" of every design decision |
| **Budget your time by difficulty** | Redshift and Databricks need more time than BigQuery and Snowflake; plan for it |

---

### Progress Milestones

Use these checkpoints to gauge if you're on track:

| Milestone | Should be able to... |
|-----------|----------------------|
| **End of Fundamentals** | Explain OLAP vs OLTP, draw a star schema, write a window function |
| **After first platform** | Load data, write analytical queries, explain the architecture in your own words |
| **After all 4 platforms** | Name 3 scenarios where each platform wins; estimate monthly cost for each |
| **After governance modules** | Run a full dbt project with tests; build an Airflow DAG |
| **After capstone** | Deliver a working warehouse pipeline end-to-end on at least one platform |

---

### Self-Assessment After Each Module

Before moving to the next module, ask yourself:

1. Can I explain *why* this platform/feature was designed this way?
2. Can I write the key SQL patterns from memory?
3. Did I complete the hands-on lab, or just read it?
4. Can I explain one trade-off this platform makes vs. others?

If the answer to any of these is no — re-read the relevant section before progressing.

## 🛠️ Setting Up Your Environment

### Quick Start

1. **Create free tier accounts:**
   - [Snowflake](https://signup.snowflake.com/) - 30-day trial, $400 credits
   - [Databricks](https://databricks.com/try-databricks) - Community Edition available
   - [BigQuery](https://cloud.google.com/bigquery/docs/quickstarts) - $300 free credits
   - [Amazon Redshift](https://aws.amazon.com/redshift/free-trial/) - Free RA3 trial available

2. **Load sample datasets:**
   - TPC-H 100GB dataset (available on all platforms)
   - Retail transaction dataset (for exercises)
   - Healthcare analytics dataset (dimensional modeling examples)

3. **Set up local environment:**
   ```bash
   # Install dbt (optional but recommended)
   pip install dbt-snowflake dbt-databricks dbt-bigquery

   # Install other utilities
   pip install pandas sqlalchemy
   ```

See [`fundamentals/04-hands-on-setup.md`](./fundamentals/04-hands-on-setup.md) for detailed setup instructions.

## 💰 Cost Estimates

This course will cost approximately:

| Platform | Estimated Cost | Notes |
|----------|------------------|-------|
| Snowflake | $20-50 | Free trial covers most exercises |
| Databricks | $10-30 | Community Edition is free |
| BigQuery | $30-60 | Free tier covers many queries |
| Redshift | $25-75 | RA3 trial is free for short term |
| **Total** | **$85-215** | Manageable for education; use free tiers wisely |

**Cost-Saving Tips:**
- Use free tier credits first
- Focus expensive exercises on one platform initially
- Use smaller datasets for initial learning
- Clean up resources after each session

## 📚 Learning Outcomes

By completing this course, you will be able to:

### Foundational Knowledge
- ✅ Explain OLAP vs OLTP workloads and choose appropriate solutions
- ✅ Design dimensional models using star schemas and Kimball principles
- ✅ Implement Slowly Changing Dimensions (SCD Types 1, 2, 3)
- ✅ Write optimized analytical SQL with window functions and CTEs

### Platform Expertise
- ✅ Set up and configure each of the 4 cloud warehouses
- ✅ Load structured and semi-structured data
- ✅ Write platform-specific SQL optimized for each architecture
- ✅ Understand unique features of each platform (Time Travel, Delta Lake, Nested Fields, Spectrum)

### Performance & Optimization
- ✅ Read and interpret query execution plans
- ✅ Optimize queries using partitioning, clustering, and indexing
- ✅ Estimate and reduce query costs
- ✅ Benchmark performance across platforms

### Engineering & Governance
- ✅ Build data transformation pipelines with dbt
- ✅ Implement data quality frameworks
- ✅ Design access control and governance structures
- ✅ Orchestrate complex workflows with Airflow

### Decision Making
- ✅ Evaluate platforms for specific business use cases
- ✅ Plan migration strategies between platforms
- ✅ Design multi-cloud data strategies
- ✅ Present technical trade-offs to stakeholders

## 📋 Detailed Curriculum

See [CURRICULUM.md](./CURRICULUM.md) for the complete learning path with time estimates, dependencies, and detailed learning outcomes for each module.

## 🔗 Quick Navigation

| Module | Topics | Duration | Level |
|--------|--------|----------|-------|
| [Concepts](./fundamentals/01-data-warehouse-concepts.md) | OLAP/OLTP, schemas, grain | 3 hours | Beginner |
| [SQL](./fundamentals/02-sql-for-warehouses.md) | Joins, window functions, CTEs | 4 hours | Beginner |
| [Modeling](./fundamentals/03-dimensional-modeling.md) | Star schema, SCD, dimensions | 5 hours | Beginner |
| [Setup](./fundamentals/04-hands-on-setup.md) | Account setup, sample data | 2 hours | Beginner |
| [Snowflake](./snowflake/) | Platform-specific deep dive | 8 hours | Intermediate |
| [Databricks](./databricks/) | Lakehouse architecture | 8 hours | Intermediate |
| [BigQuery](./bigquery/) | Serverless analytics | 8 hours | Intermediate |
| [Redshift](./redshift/) | MPP architecture | 8 hours | Intermediate |
| [File Formats](./file-formats/) | Parquet, Avro, ORC, Delta | 5 hours | Intermediate |
| [Optimization](./optimization/) | Tuning & cost reduction | 6 hours | Advanced |
| [Governance](./governance-integration/) | dbt, quality, orchestration | 8 hours | Advanced |
| [Advanced](./advanced-patterns/) | Real-world scenarios | 8 hours | Advanced |
| [Comparison](./platform-comparison/) | Platform evaluation | 4 hours | Advanced |

## 🎯 Choosing Your Path

### For Data Analysts
- Focus: Fundamentals → SQL + Modeling → Pick favorite platform
- Skip: Deep cluster management, distributed computing
- Time: 12-14 weeks

### For Data Engineers
- Focus: Complete curriculum including optimization, governance, orchestration
- Deep dive: All platforms and integration tools
- Time: Full 26 weeks

### For Analytics Engineers
- Focus: SQL + Modeling → dbt + Data Quality → Platform integration
- Skip: Infrastructure and cluster management
- Time: 18-20 weeks

### For Data Architects
- Focus: Complete curriculum + platform selection framework
- Deep dive: Architecture decisions and trade-offs
- Time: 26+ weeks (with additional research)

## 📝 Hands-On Practice

Each module includes practical exercises:

- **Beginner Labs:** 5-10 guided exercises with solutions
- **Intermediate Labs:** Design and implementation challenges
- **Advanced Labs:** Real-world scenarios and optimization tasks
- **Capstone Project:** End-to-end retail analytics implementation across all 4 platforms

Expected time commitment: **3-5 hours per week** for practical work.

## 🤔 Common Questions

### Do I need to learn all 4 platforms?
No. After fundamentals and one platform deep-dive, you'll understand the concepts. Learning additional platforms becomes much faster. However, comparing all 4 helps you make informed decisions.

### Can I take this course part-time?
Yes! Adjust the pace to 2 hours per week and expect 52 weeks to complete. Each module stands alone.

### What if I get stuck?
- Each module has links to official documentation
- Check the practice exercise solutions
- Revisit prerequisite fundamentals modules
- Set up test queries on actual platform free tiers

### How much does this course actually cost?
With free tier credits and careful resource management: **$0-50 total**. Most exercises fit within free tier limits.

### Will this prepare me for certifications?
This course covers topics tested in:
- Snowflake University Certification
- Google Cloud Associate Cloud Engineer (GCP track)
- AWS Data Analytics Specialty Certification
- Databricks Lakehouse Fundamentals

However, dedicated certification courses may be needed for exam-specific content.

## 🚀 What's Next After This Course

- **Specialization:** Deep-dive into one platform's advanced features
- **Certification:** Official certification programs
- **Real Projects:** Apply skills to production data systems
- **Advanced Topics:** Data mesh, federated analytics, advanced ML integration
- **Community:** Join data warehouse communities and conferences

## 📞 Feedback & Contributions

This course is a living document. If you find:
- Errors or outdated information
- Missing topics or examples
- Unclear explanations
- Better ways to explain concepts

Please document your feedback for future improvements.

## 📄 License

This course content is provided as-is for educational purposes.

---

## 🎉 Ready to Start?

Begin with [**Fundamentals Module 1: Data Warehouse Concepts**](./fundamentals/01-data-warehouse-concepts.md)

**Estimated total time:** 26 weeks at 3-5 hours per week  
**Difficulty:** Beginner → Advanced  
**Prerequisites:** Basic SQL knowledge

Good luck on your data warehouse learning journey! 🚀

---

*Last Updated: March 2026*
