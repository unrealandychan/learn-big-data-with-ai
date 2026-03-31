# Databricks Module Overview

This module contains 5 detailed lessons on Databricks lakehouse platform and Delta Lake.

## Contents

1. **[Architecture](01-architecture.md)** - Lakehouse model, Delta Lake, ACID transactions, Unity Catalog
2. **[Data Loading](02-data-loading.md)** - COPY INTO, MERGE, CDC patterns, Auto Loader
3. **[Querying & Optimization](03-querying-optimization.md)** - Spark SQL, Z-order indexing, AQE
4. **[ML Integration](04-ml-integration.md)** - MLflow, Feature Store, model training
5. **[Hands-On Labs](05-hands-on-labs.md)** - Real-world exercises and capstone

## Quick Start

If you have 8 hours:
1. Start with [Architecture](01-architecture.md) (1.5 hours) - Understand lakehouse concept
2. Jump to [Hands-On Labs](05-hands-on-labs.md) (3 hours)
3. Study [Querying & Optimization](03-querying-optimization.md) (2 hours)
4. Explore [Data Loading](02-data-loading.md) (1 hour)

## Key Concepts

- **Lakehouse:** Data lake reliability + warehouse features
- **Delta Lake:** Open format with ACID, time travel, schema enforcement
- **Spark SQL:** Distributed SQL query engine
- **Z-Order Indexing:** Multi-dimensional clustering
- **Unity Catalog:** Unified governance across clouds
- **Auto Loader:** Schema inference and continuous ingestion
- **MLflow:** Model tracking and registry

## Prerequisites

- Modules 1-4 from Fundamentals
- Active Databricks Community Edition (free!)
- Familiarity with Python helpful (but not required for SQL-focused path)

## Learning Outcomes

After completing Databricks modules, you will:
- Explain lakehouse architecture and advantages over lakes or warehouses
- Use Delta Lake format for ACID transactions
- Design Bronze/Silver/Gold data architecture
- Implement CDC (Change Data Capture) patterns
- Optimize Spark SQL queries using Z-order indexing
- Build feature stores for ML workflows
- Compare Databricks with Snowflake, BigQuery, and Redshift

## Time Estimates

| Module | Duration | Difficulty |
|--------|----------|------------|
| Architecture | 1.5-2 hrs | Easy |
| Data Loading | 1.5-2 hrs | Easy |
| Querying & Optimization | 2-2.5 hrs | Medium |
| ML Integration | 1.5-2 hrs | Medium |
| Hands-On Labs | 2-3 hrs | Medium |
| **Total** | **8-11 hrs** | - |

## Common Questions

**Q: Is Databricks only for data scientists?**  
A: No! Databricks is excellent for warehouse workloads. You can focus purely on SQL.

**Q: Do I need to know Python?**  
A: For this course, no. All labs include Python, but SQL examples work standalone.

**Q: Is Community Edition sufficient for the labs?**  
A: Yes! Community Edition has everything needed for learning.

**Q: How does this compare to Snowflake?**  
A: Snowflake = purpose-built warehouse; Databricks = flexible ML + warehouse. See comparisons after Module 2+.

---

*Last Updated: March 2026*
