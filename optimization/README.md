# Optimization & Performance

**Duration:** 6 hours total (16 hours with full labs)  
**Level:** Advanced  
**Prerequisites:** All Fundamentals modules + at least 2 Platform modules (Snowflake, Databricks, BigQuery, or Redshift)

---

## Overview: Why Optimization Matters

After learning each platform, the next step is squeezing real performance and cost efficiency out of them. This level answers:

- Why is this query slow — and how do I prove it?
- How should I organize data for the queries I actually run?
- How do I keep my cloud bill from spiraling?
- How do I compare performance across platforms fairly?

---

## Contents

| # | File | Topic | Time |
|---|------|-------|------|
| 1 | [01-query-execution-plans.md](01-query-execution-plans.md) | Reading & tuning execution plans | 4 hrs |
| 2 | [02-data-organization.md](02-data-organization.md) | Partitioning, clustering, materialized views | 5 hrs |
| 3 | [03-cost-optimization.md](03-cost-optimization.md) | Cost models, TCO, right-sizing | 4 hrs |
| 4 | [04-performance-benchmarks.md](04-performance-benchmarks.md) | Benchmarking methodology & cross-platform comparison | 3 hrs |

---

## The Optimization Mindset

```
Measure first → Hypothesize → Change one thing → Measure again
```

The most common mistake is changing multiple things at once. Always:
1. Capture the baseline (execution time, bytes scanned, cost)
2. Identify the single biggest bottleneck
3. Apply one fix
4. Re-measure and compare

---

## Optimization Levers by Platform

| Lever | Snowflake | Databricks | BigQuery | Redshift |
|-------|-----------|------------|----------|----------|
| **Avoid full scans** | Clustering keys | Partitioning + Z-order | Partition + cluster | Sort keys + zone maps |
| **Pre-aggregation** | Materialized views | Delta caching | Materialized views | Materialized views |
| **Result reuse** | Result cache (24h) | Delta cache | Slot-level cache | Result cache |
| **Join efficiency** | Auto broadcast | Broadcast hints | Automatic | Distribution keys |
| **Concurrency** | Multi-cluster warehouse | Auto-scaling pools | Slot reservations | WLM queues |

---

## Quick Navigation

- **New to execution plans?** → Start with [Module 4.1](01-query-execution-plans.md)
- **Data scans too slow?** → Jump to [Module 4.2](02-data-organization.md)
- **Bill too high?** → Jump to [Module 4.3](03-cost-optimization.md)
- **Evaluating platforms?** → Start with [Module 4.4](04-performance-benchmarks.md)

---

*Part of the [Big Data Warehouse Learning Course](../README.md) — Level 4 of 6*

