# Amazon Redshift Module Overview

This module contains 5 detailed lessons on Amazon Redshift MPP data warehouse.

## Contents

1. **[Architecture](01-architecture.md)** - MPP design, distribution keys, node types (DC2, RA3)
2. **[Data Loading](02-data-loading.md)** - COPY command, compression, incremental loads
3. **[Querying & Optimization](03-querying-optimization.md)** - Distribution strategies, sort keys, query tuning
4. **[Cluster Management](04-cluster-management.md)** - Spectrum (S3 querying), concurrency scaling, WLM
5. **[Hands-On Labs](05-hands-on-labs.md)** - Real-world exercises and capstone

## Quick Start

If you have 8 hours:
1. Start with [Architecture](01-architecture.md) (1.5 hours) - MPP is different!
2. Jump to [Hands-On Labs](05-hands-on-labs.md) (2.5 hours)
3. Study [Querying & Optimization](03-querying-optimization.md) (2 hours)
4. Explore [Data Loading](02-data-loading.md) (1.5 hours)

## Key Concepts

- **MPP (Massively Parallel Processing):** Distribute work across nodes
- **Distribution Keys:** How data splits across nodes (critical!)
- **Sort Keys:** Row ordering within nodes
- **Zones Maps:** Metadata for query optimization
- **Spectrum:** Query data directly in S3
- **Concurrency Scaling:** Handle burst workloads
- **Workload Management (WLM):** Query prioritization

## Prerequisites

- Modules 1-4 from Fundamentals
- AWS account with free trial ($200-300 credits) or using existing account
- Familiarity with distributed systems helpful

## Learning Outcomes

After completing Redshift modules, you will:
- Understand MPP architecture and data distribution
- Choose appropriate distribution keys for table design
- Optimize queries for parallel execution
- Query S3 data via Spectrum
- Manage query performance with WLM
- Compare Redshift with Snowflake, Databricks, and BigQuery

## Time Estimates

| Module | Duration | Difficulty |
|--------|----------|------------|
| Architecture | 1.5-2 hrs | Medium |
| Data Loading | 1.5-2 hrs | Easy |
| Querying & Optimization | 2-3 hrs | Hard |
| Cluster Management | 1.5-2 hrs | Medium |
| Hands-On Labs | 2-3 hrs | Medium |
| **Total** | **8-12 hrs** | - |

## Common Questions

**Q: Is Redshift harder to set up than Snowflake?**  
A: Yes, slightly. Cluster provisioning takes time. But easier than on-premise systems.

**Q: What's a distribution key and why is it so important?**  
A: It determines how data splits across cluster nodes. Wrong choice = slow queries.

**Q: Can I use Redshift without owning AWS infrastructure?**  
A: Yes! Redshift is fully managed. AWS handles all infrastructure.

**Q: Is this the "old-school" warehouse?**  
A: Redshift is enterprise-proven (since 2012) with modern features (Spectrum, RA3). Not outdated!

**Q: How many nodes do I need?**  
A: Start with 1-2 nodes for learning. Production = depends on data volume and query complexity.

---

*Last Updated: March 2026*
