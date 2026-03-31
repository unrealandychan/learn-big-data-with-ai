# Governance, Integration & Operation

**Duration:** 8-10 hours total  
**Prerequisites:** All Fundamentals modules + at least 2 Platform modules

## Overview: Production Readiness

A warehouse isn't production-ready until you have:
- ✅ Reliable data pipelines
- ✅ Data quality monitoring
- ✅ Access controls
- ✅ Documentation
- ✅ Cost monitoring
- ✅ Incident response

**This module covers all of the above.**

---

## Contents

1. **[dbt Fundamentals](01-dbt-fundamentals.md)** - Data transformation and documentation tool
2. **[Data Quality](02-data-quality.md)** - Testing, monitoring, and SLAs
3. **[Governance](03-governance-patterns.md)** - Access control, compliance, lineage
4. **[Orchestration](04-orchestration.md)** - Airflow, scheduling, monitoring

---

## The Big Picture: Data Pipeline

```
┌─────────────────────────────────────────┐
│ Source Systems (Databases, APIs, Files) │
└──────────────────┬──────────────────────┘
                   ↓
         ┌─────────────────────┐
         │  EXTRACT (Fivetran, │
         │  Stitch, Connectors)│
         └──────────┬──────────┘
                    ↓
      ┌──────────────────────────┐
      │ RAW DATA LAYER (Staging) │
      │ - Minimal transformation │
      │ - 1:1 with source        │
      └──────────┬───────────────┘
                 ↓
       ┌─────────────────────────┐
       │ dbt TRANSFORMATION LAYER│
       │ - Data quality tests    │
       │ - Business logic        │
       │ - Documentation         │
       └──────────┬──────────────┘
                  ↓
    ┌──────────────────────────────┐
    │ ANALYTICS LAYER (Star Schema)│
    │ - Fact tables               │
    │ - Dimension tables          │
    │ - Governed by governance   │
    └──────────┬───────────────────┘
               ↓
         ┌──────────────────┐
         │  BI TOOLS / ML   │
         │  Dashboards, ML  │
         │  Models, Queries │
         └──────────────────┘
```

**Each layer has quality gates and monitoring.**

---

## dbt: The Modern Data Transformation Tool

### What is dbt?

**dbt** (data build tool) = SQL-based transformation framework

**Features:**
- Version control for data logic
- Automated testing and documentation
- Modular, reusable SQL models
- Lineage tracking (what depends on what?)
- CI/CD for data pipelines

### dbt Key Concepts

**Models:** SQL files that transform data
```sql
-- models/core/dim_customers.sql
SELECT 
    customer_id,
    customer_name,
    state,
    CASE WHEN annual_sales > 10000 THEN 'VIP' ELSE 'Standard' END as segment
FROM {{ ref('stg_customers') }}  -- Reference another model
```

**Materializations:** How to store the result
- Table (full rebuild each time)
- View (query executed each time)
- Incremental (only new/changed rows)

**Tests:** Validate data
- Unique: No duplicates
- Not null: No missing values
- Accepted values: Only allowed values
- Relationships: Foreign keys

**Macros:** Reusable SQL logic
```sql
{% macro generate_schema_name(schema_name, node) %}
  {% if execute %}
    {% if schema_name is none %}
      {{ node.database }}_{{ node.schema }}
    {% else %}
      {{ schema_name }}
    {% endif %}
  {% endif %}
{% endmacro %}
```

---

## Data Quality: Beyond Testing

### Quality Dimensions

| Dimension | Definition | Example |
|-----------|-----------|---------|
| **Completeness** | No missing values | Customer has email |
| **Accuracy** | Values are correct | Order date is real |
| **Consistency** | Uniform format/definitions | Customer_id = 5 digits |
| **Timeliness** | Data is recent enough | Yesterday's sales loaded |
| **Uniqueness** | No unexpected duplicates | Order ID is unique |

### Data Quality Framework

**1. Expectations:** Define what "good" data looks like
```sql
-- dbt test_customer_email_not_null.sql
SELECT COUNT(*) FROM dim_customers 
WHERE customer_email IS NULL 
HAVING COUNT(*) > 0  -- Fail if any NULLs
```

**2. Monitoring:** Track quality metrics over time
```
Customer completeness: 99.8%
Order timeliness: 100% (all loaded by 8am)
Duplicate rate: 0.02%
```

**3. Alerts:** Notice when quality drops
```
Alert: Customer completeness < 95%
Action: Investigate source data
```

**4. Resolution:** Fix and understand root cause
```
Root cause: API returning NULL for email
Fix: Backfill from alternative source
Prevention: Update ETL to validate
```

---

## Governance: Who Can Access What?

### Three Levels of Access Control

**Role-Based Access (RBAC):**
```
analyst_role: SELECT from analytics layer (not raw)
engineer_role: SELECT/INSERT from all layers
admin_role: Full permissions
```

**Column-Level Security:**
```
sensitive_salary_column: Only HR and payroll teams
customer_email: Only marketing team
```

**Row-Level Security:**
```
Sales_rep_1: Can only see Region_1 data
Sales_rep_2: Can only see Region_2 data
```

### Data Cataloging & Lineage

**Data Catalog** = searchable inventory of all datasets
- What tables exist?
- Who owns each?
- What is it used for?
- What quality SLA?

**Lineage** = dependencies and data flow
```
source.db.customer_source
  ↓ (dbt: source_customers)
raw.staging.stg_customers
  ↓ (dbt: dim_customers)
analytics.public.dim_customers
  ↓ (Tableau)
sales_executive_dashboard
```

---

## Orchestration: Scheduling and Monitoring

### Why Orchestration?

Without orchestration:
- ❌ Manual trigger required daily (error-prone)
- ❌ No dependency management (run in wrong order)
- ❌ No retry logic (one failure stops pipeline)
- ❌ No monitoring (discover failures late)

With orchestration:
- ✅ Automatic scheduling (run each morning)
- ✅ Dependency management (task B only after A succeeds)
- ✅ Retry logic (auto-retry 3x on failure)
- ✅ Monitoring (alert if SLA missed)

### Apache Airflow: Orchestration Example

```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.dependencies import set_downstream

default_args = {
    'owner': 'data_team',
    'retries': 2,
    'email_on_failure': True
}

dag = DAG('daily_analytics', default_args=default_args, schedule_interval='0 8 * * *')

# Task 1: Extract data
extract_task = BashOperator(
    task_id='extract_data',
    bash_command='python extract.py'
)

# Task 2: Run dbt
dbt_task = BashOperator(
    task_id='run_dbt',
    bash_command='dbt run --profiles-dir ~/.dbt'
)

# Task 3: Run quality checks
quality_task = BashOperator(
    task_id='run_tests',
    bash_command='dbt test'
)

# Dependencies: Extract → dbt → quality
extract_task >> dbt_task >> quality_task
```

**This DAG:**
- Runs daily at 8 AM
- Extracts data
- Transforms with dbt
- Tests data quality
- Alerts if any step fails
- Auto-retries twice on failure

---

## Production Readiness Checklist

Before going live with any warehouse:

### Data Pipeline
- [ ] Automated data extraction (no manual steps)
- [ ] Transformation logic in version control (dbt or equivalent)
- [ ] Idempotent loads (can re-run without duplicates)
- [ ] Error handling and recovery
- [ ] Data lineage documented

### Quality & Monitoring
- [ ] Data quality tests for all critical tables
- [ ] SLAs defined (data must load by X time)
- [ ] Alerts configured (notify on failures)
- [ ] Dashboards to monitor pipeline health
- [ ] Root cause analysis process documented

### Security & Governance
- [ ] Role-based access control configured
- [ ] Sensitive columns masked/encrypted
- [ ] Data catalog with ownership
- [ ] Audit logging enabled
- [ ] Compliance requirements met

### Operations
- [ ] Runbook for common failure scenarios
- [ ] Backup and recovery procedures tested
- [ ] Change management process
- [ ] On-call rotation for alerts
- [ ] Regular review of costs and usage

### Documentation
- [ ] All tables documented (purpose, owner, SLA)
- [ ] All transformations explained
- [ ] Troubleshooting guide
- [ ] Escalation contacts listed
- [ ] Known issues and limitations documented

---

## Modules Included

1. **[dbt Fundamentals](01-dbt-fundamentals.md)** (5 hours)
   - Learn dbt structure
   - Build dimensional models
   - Add testing and documentation

2. **[Data Quality](02-data-quality.md)** (5 hours)
   - Design quality frameworks
   - Implement dbt tests
   - Set up monitoring dashboards

3. **[Governance](03-governance-patterns.md)** (4 hours)
   - Configure RBAC
   - Build data catalogs
   - Track lineage

4. **[Orchestration](04-orchestration.md)** (6 hours)
   - Design pipelines with Airflow
   - Set up scheduling
   - Monitor and alert

---

## Integration with Platforms

These modules apply to **all platforms**, but have platform-specific:
- **dbt packages** (dbt-snowflake, dbt-databricks, etc.)
- **Quality tools** (Great Expectations, dbt tests)
- **Orchestration** (dbt Cloud, Airflow, native scheduling)

---

## Next Steps

Start with:
1. **[dbt Fundamentals](01-dbt-fundamentals.md)** - Establish transformation foundation
2. **[Data Quality](02-data-quality.md)** - Ensure reliability
3. **[Orchestration](04-orchestration.md)** - Automate operations
4. **[Governance](03-governance-patterns.md)** - Secure and organize

---

*Last Updated: March 2026*
