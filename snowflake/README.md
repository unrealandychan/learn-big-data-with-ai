# Snowflake Module Overview

This module contains 5 detailed lessons on Snowflake architecture and capabilities.

## Contents

1. **[Architecture](01-architecture.md)** - Compute/storage separation, warehouses, Time Travel
2. **[Data Loading](02-data-loading.md)** - COPY, Snowpipe, data transformation
3. **[Querying & Optimization](03-querying-optimization.md)** - SQL patterns, clustering, performance tuning
4. **[Semi-Structured Data](04-semi-structured-data.md)** - VARIANT type, JSON, Parquet handling
5. **[Hands-On Labs](05-hands-on-labs.md)** - Real-world exercises and capstone

## Quick Start

If you have 8 hours:
1. Start with [Architecture](01-architecture.md) (1.5 hours)
2. Jump to [Hands-On Labs](05-hands-on-labs.md) (3 hours)
3. Study [Querying & Optimization](03-querying-optimization.md) (2 hours)
4. Deep-dive remaining modules as interest directs

## Key Concepts

- **Compute/Storage Separation:** Independent scaling
- **Virtual Warehouses:** Elastic clusters for queries
- **Time Travel:** Access historical data versions
- **Semi-Structured Data:** Native VARIANT type for JSON/Parquet
- **Snowpipe:** Continuous ingestion from cloud storage
- **Zero-Copy Clones:** Instant table/schema copies for testing

## Prerequisites

- Modules 1-4 from Fundamentals (Concepts, SQL, Modeling, Setup)
- Active Snowflake trial account
- Basic familiarity with cloud storage (S3, Azure Blob, GCS)

## Learning Outcomes

After completing Snowflake modules, you will:
- Explain Snowflake's unique compute/storage architecture
- Choose appropriate warehouse sizes and configurations
- Load data using COPY, Snowpipe, and external stages
- Optimize queries using clustering keys and search optimization
- Query JSON and semi-structured data using VARIANT type
- Implement Time Travel for data recovery
- Compare Snowflake with Databricks, BigQuery, and Redshift

## Time Estimates

| Module | Duration | Difficulty |
|--------|----------|------------|
| Architecture | 1-1.5 hrs | Easy |
| Data Loading | 1.5-2 hrs | Easy |
| Querying & Optimization | 2-2.5 hrs | Medium |
| Semi-Structured Data | 1-1.5 hrs | Easy |
| Hands-On Labs | 2-3 hrs | Medium |
| **Total** | **8-10 hrs** | - |

## Common Questions

**Q: I've never used Snowflake. Where do I start?**  
A: Start with Architecture (conceptual foundation), then go through Hands-On Labs. The labs have step-by-step walkthrough.

**Q: Will I need SQL skills?**  
A: Yes. All examples use SQL. If you need SQL basics, review [Fundamentals Module 2](../fundamentals/02-sql-for-warehouses.md).

**Q: Can I skip the theory and go straight to labs?**  
A: Somewhat. Labs have embedded explanations, but you'll need to understand compute vs storage separation (covered in Architecture).

**Q: How does Snowflake compare to other platforms?**  
A: See the platform comparison module after completing this and at least one other platform.

---

*Last Updated: March 2026*
