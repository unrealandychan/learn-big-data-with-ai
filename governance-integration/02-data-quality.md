# Data Quality and Testing Framework

## Learning Outcomes
- Implement data quality testing strategies
- Master Great Expectations for automated validation
- Design SLAs and quality metrics
- Debug data issues and root causes
- Build self-healing data pipelines

**Estimated Time:** 2 hours  
**Prerequisites:** Governance Module 1 (dbt fundamentals)

## Data Quality Dimensions

```
                    DATA QUALITY
                         │
        ┌────────────────┬┴─────────────┬──────────────┐
        │                │              │              │
    ACCURACY         COMPLETENESS   CONSISTENCY    TIMELINESS
    │                │              │              │
    ├─Correct        ├─No nulls     ├─Referential  ├─Fresh
    ├─Valid          ├─No gaps      ├─Duplicates   ├─Available
    └─Consistent     └─Full coverage└─Schema       └─Reliable
```

## dbt Testing Framework

Built-in tests in dbt:

```yaml
# models/marts/schema.yml
models:
  - name: dim_customers
    tests:
      - dbt.relations_equal:
          compare_model: ref('dim_customers_expected')

    columns:
      - name: customer_id
        tests:
          - unique:
              config:
                warn_if: ">1000"
                error_if: ">10000"
          - not_null

      - name: email
        tests:
          - unique
          - not_null
          - dbt_utils.accepted_values:
              values: ['personal', 'business']

      - name: created_date
        tests:
          - dbt.not_null
          - dbt_utils.less_than_or_equal_to:
              column_name: updated_date
          - dbt_utils.relationships:
              to: ref('fact_orders')
              field: order_date
```

## Great Expectations for Advanced Testing

```python
# setup_expectations.py
import great_expectations as ge
from great_expectations.core.batch import RuntimeBatchRequest

# Create data context
context = ge.get_context()

# Validate DataFrame directly
df = pd.read_sql("SELECT * FROM customers", connection)
validator = context.get_validator(
    batch_request=RuntimeBatchRequest(
        datasource_name='my_datasource',
        data_connector_name='default_runtime_data_connector',
        data_asset_name='customers'
    )
)

# Expect at least 100k customers
validator.expect_table_row_count_to_be_between(10000, 1000000)

# No nulls in critical columns
validator.expect_column_values_to_not_be_null('customer_id')
validator.expect_column_values_to_not_be_null('email')

# Email format validation
validator.expect_column_values_to_match_regex(
    'email',
    regex=r'^[^@]+@[^@]+\.[^@]+$'
)

# Uniqueness check
validator.expect_column_values_to_be_unique('email')

# Value range validation
validator.expect_column_values_to_be_between(
    'age',
    min_value=0,
    max_value=150
)

# Run validation suite
results = validator.validate()

# Create checkpoint
checkpoint = context.add_or_update_checkpoint(
    name='customers_checkpoint',
    config_version=1,
    template_name=None,
    validations=[
        {
            'batch_request': RuntimeBatchRequest(...),
            'expectation_suite_name': 'customers.critical'
        }
    ]
)

checkpoint.run()
```

## SQL Testing Patterns

```sql
-- dbt macro: test_row_count_change
{% macro test_row_count_change(model, warn_threshold=0.1, error_threshold=0.2) %}

WITH current AS (
    SELECT COUNT(*) as current_count FROM {{ model }}
),

previous AS (
    SELECT MAX(row_count) as previous_count
    FROM _table_row_counts
    WHERE table_name = '{{ this.name }}'
      AND created_date >= CURRENT_DATE - 7
)

SELECT
    current_count,
    previous_count,
    ROUND(ABS(current_count - previous_count) / NULLIF(previous_count, 0), 2) as change_pct
FROM current, previous
WHERE ROUND(ABS(current_count - previous_count) / NULLIF(previous_count, 0), 2) > {{ error_threshold }}

{% endmacro %}

-- Usage in schema.yml
tests:
  - dbt_utils.test_row_count_change:
      model: ref('fact_orders')
      warn_threshold: 0.1
      error_threshold: 0.5
```

## Data Quality SLAs

Define and monitor quality targets:

```yaml
# quality_slas.yml
tables:
  customers:
    freshness_sla: 24 hours
    completeness_sla:
      email: 99.9%
      phone: 95%
    accuracy_sla: 99.95%
    timeliness_sla: data available within 2 hours

  orders:
    freshness_sla: 12 hours
    completeness_sla:
      order_id: 100%
      customer_id: 100%
      order_amount: 99.99%
    accuracy_sla: 99.99%
    timeliness_sla: data available within 1 hour
```

## Monitoring and Alerting

```python
# monitor_quality.py
import airflow
from airflow import DAG
from airflow.operators.python import PythonOperator

def check_data_quality():
    """Run Great Expectations checkpoint and alert if issues"""
    checkpoint = context.get_checkpoint('customers_checkpoint')
    results = checkpoint.run()
    
    if not results['success']:
        for result in results['run_results']:
            for check_result in result['validation_result']['results']:
                if check_result['result']['unexpected_count'] > 0:
                    # Send alert
                    send_slack_alert({
                        'table': 'customers',
                        'check': check_result['expectation_config']['expectation_type'],
                        'unexpected_count': check_result['result']['unexpected_count'],
                        'severity': 'HIGH'
                    })

dag = DAG('quality_monitoring', schedule='@daily')

quality_check = PythonOperator(
    task_id='check_quality',
    python_callable=check_data_quality,
    dag=dag
)

quality_check
```

## Root Cause Analysis

Debug data quality issues:

```sql
-- Find unexpected nulls
SELECT
    column_name,
    COUNT(*) as null_count,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2) as null_pct
FROM orders
WHERE order_amount IS NULL
  OR customer_id IS NULL
  OR order_date IS NULL
GROUP BY column_name
HAVING COUNT(*) > 0;

-- Find duplicate keys
SELECT
    customer_id,
    order_date,
    COUNT(*) as duplicate_count
FROM orders
GROUP BY customer_id, order_date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Find schema mismatches
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'orders'
  AND DATA_TYPE NOT IN ('integer', 'decimal', 'date', 'timestamp')
ORDER BY ORDINAL_POSITION;
```

## Key Concepts

- **SLA:** Service Level Agreement for data quality
- **Great Expectations:** Python framework for automated validation
- **Expectation Suites:** Collections of data quality rules
- **Checkpoints:** Validation jobs that run on schedule
- **Root Cause:** Systematic debugging of quality failures

## Hands-On Lab

### Part 1: dbt Testing
1. Add comprehensive tests to your models
2. Run test suite and debug failures
3. Create custom test macro
4. Set up test thresholds with warn/error

### Part 2: Great Expectations
1. Create expectation suite
2. Run checkpoint against sample data
3. Modify expectations based on failures
4. Generate data docs

### Part 3: Quality SLAs
1. Define SLAs for critical tables
2. Create monitoring queries
3. Set up alerting for SLA violations
4. Implement remediation playbook

*See Part 2 of course for complete lab walkthrough*

*Last Updated: March 2026*
