# BigQuery Module Overview

This module contains 5 detailed lessons on Google BigQuery serverless analytics platform.

## Contents

1. **[Architecture](01-architecture.md)** - Columnar storage, Dremel engine, slots vs on-demand
2. **[Data Loading](02-data-loading.md)** - Nested fields (STRUCT, ARRAY), loading methods, schema evolution
3. **[Querying & Optimization](03-querying-optimization.md)** - Partitioning, clustering, materialized views
4. **[BigQuery ML](04-bigquery-ml.md)** - BQML models, predictions, feature engineering
5. **[Hands-On Labs](05-hands-on-labs.md)** - Real-world exercises and capstone

## Quick Start

If you have 8 hours:
1. Start with [Architecture](01-architecture.md) (1.5 hours) - Understand pricing model
2. Jump to [Hands-On Labs](05-hands-on-labs.md) (2.5 hours)
3. Study [Querying & Optimization](03-querying-optimization.md) (2 hours)
4. Explore [Data Loading](02-data-loading.md) (1.5 hours)

## Key Concepts

- **Columnar Storage:** Optimized for analytical queries
- **Dremel Engine:** Google's massive-scale query processor
- **Nested Fields:** STRUCT and ARRAY for JSON-like data
- **Slots:** Reserved compute vs on-demand pricing
- **Partitioning & Clustering:** Query cost optimization
- **BQML:** Build ML models directly in SQL
- **BI Engine:** In-memory cache for BI workloads

## Prerequisites

- Modules 1-4 from Fundamentals
- Google Cloud account with free credits ($300 trial)
- Familiarity with JSON/nested data helpful

## Learning Outcomes

After completing BigQuery modules, you will:
- Understand columnar storage architecture
- Choose between on-demand and slot pricing models
- Load and query nested/semi-structured data (STRUCT, ARRAY)
- Optimize BigQuery costs through partitioning and clustering
- Build ML models directly in SQL with BQML
- Compare BigQuery with Snowflake, Databricks, and Redshift

## Time Estimates

| Module | Duration | Difficulty |
|--------|----------|------------|
| Architecture | 1.5-2 hrs | Easy |
| Data Loading | 1.5-2 hrs | Medium |
| Querying & Optimization | 2-2.5 hrs | Medium |
| BigQuery ML | 1.5-2 hrs | Medium |
| Hands-On Labs | 2-3 hrs | Medium |
| **Total** | **8-11 hrs** | - |

## Common Questions

**Q: Is BigQuery only for Google Cloud users?**  
A: No. You can use it standalone. GCP integration is optional.

**Q: What's the difference between on-demand and slots?**  
A: On-demand = pay per query ($7.50/TB); Slots = reserve compute ($2K+/month). See Architecture.

**Q: Do nested STRUCT/ARRAY fields complicate queries?**  
A: Initially, but they're powerful for semi-structured data. See examples in Data Loading.

**Q: Can I really build ML models just using SQL?**  
A: Yes! BQML makes it simple. See BigQuery ML module for full guide.

---

*Last Updated: March 2026*
