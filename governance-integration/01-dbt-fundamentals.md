# dbt: Data Transformation Fundamentals

## Learning Outcomes
- Understand dbt project structure and conventions
- Master models, tests, and documentation
- Implement version control and CI/CD
- Build modular transformation layers
- Debug and validate data quality

**Estimated Time:** 2.5 hours  
**Prerequisites:** Fundamentals modules 1-3

## What is dbt?

dbt (data build tool) transforms data in your warehouse using SQL and YAML. It provides:
- **Version Control:** Track all transformations
- **Testing:** Automated data quality checks
- **Documentation:** Self-documenting data lineage
- **Modularity:** Reusable transformations
- **CI/CD:** Automated testing and deployment

## Project Structure

```
my_dbt_project/
├─ dbt_project.yml          # Project config
├─ profiles.yml             # Connection credentials
├─ models/
│  ├─ staging/              # Raw data cleaning
│  │  ├─ stg_customers.sql
│  │  └─ stg_orders.sql
│  ├─ intermediate/         # Business logic
│  │  └─ int_customer_orders.sql
│  └─ marts/                # Final analytics
│     ├─ customers.sql
│     └─ orders.sql
├─ tests/                   # Data tests
│  ├─ not_null_tests.sql
│  └─ unique_tests.sql
├─ macros/                  # Custom functions
├─ seeds/                   # Static data
├─ snapshots/               # SCD Type 2 tracking
└─ documentation/
   └─ models.yml
```

## Models and dbt_project.yml

```yaml
# dbt_project.yml
name: 'my_data_warehouse'
version: '1.0.0'
config-version: 2

profile: 'my_warehouse'

model-paths: ["models"]
test-paths: ["tests"]
data-paths: ["seeds"]
macro-paths: ["macros"]

models:
  my_data_warehouse:
    staging:
      materialized: view
      schema: staging
    intermediate:
      materialized: ephemeral
      schema: intermediate
    marts:
      materialized: table
      schema: marts
```

## Staging Models: Clean Raw Data

```sql
-- models/staging/stg_customers.sql
{{ config(
    materialized='view',
    tags=['staging', 'daily']
) }}

WITH source AS (
    SELECT
        customer_id,
        TRIM(name) as customer_name,
        LOWER(email) as email,
        created_at,
        updated_at
    FROM {{ source('raw', 'customers') }}
    WHERE created_at IS NOT NULL
),

renamed AS (
    SELECT
        customer_id,
        customer_name,
        email,
        created_at::date as created_date,
        updated_at::date as updated_date,
        CURRENT_TIMESTAMP() as _dbt_run_at
    FROM source
)

SELECT * FROM renamed
```

## Tests: Data Quality Validation

```yaml
# models/marts/schema.yml
models:
  - name: dim_customers
    description: "Dimension table of unique customers"
    columns:
      - name: customer_id
        description: "Primary key"
        tests:
          - unique
          - not_null
      - name: email
        description: "Customer email"
        tests:
          - unique
          - not_null

  - name: fact_orders
    description: "Order transactions fact table"
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_key_columns:
            - customer_id
            - order_date
            - order_id
    columns:
      - name: order_amount
        tests:
          - accepted_values:
              values: [1, 2, 3]
          - dbt_utils.at_least_one:
```

## Macros: Reusable SQL Functions

```sql
-- macros/generate_alias_name.sql
{% macro generate_alias_name(custom_alias_name=none, node=none) -%}
    {%- if custom_alias_name is none -%}
        {{ node.name }}
    {%- else -%}
        {{ custom_alias_name | replace("_", "") }}
    {%- endif -%}
{%- endmacro %}

-- Usage in model
{{ config(alias='fct_orders') }}

-- macros/cents_to_dollars.sql
{% macro cents_to_dollars(column_name) -%}
    CAST({{ column_name }} AS NUMERIC) / 100
{%- endmacro %}

-- In model
SELECT
    order_id,
    {{ cents_to_dollars('order_amount_cents') }} as order_amount
FROM raw_orders

-- macros/generate_surrogate_key.sql
{% macro generate_surrogate_key(column_names) -%}
    {% set col_str = "||".join(column_names) %}
    md5({{ col_str }})
{%- endmacro %}

-- In model
SELECT
    {{ generate_surrogate_key(['customer_id', 'order_date']) }} as sk_customer_order
FROM orders
```

## Snapshots: Track Historical Changes (SCD Type 2)

```sql
-- snapshots/snap_customers.sql
{% snapshot snap_customers %}
    {%
        config(
            target_schema='snapshots',
            unique_key='customer_id',
            strategy='timestamp',
            updated_at='updated_at'
        )
    %}

    SELECT
        customer_id,
        name,
        email,
        phone,
        tier,
        updated_at
    FROM {{ source('raw', 'customers') }}

{% endsnapshot %}

-- Query snapshot for dimension table Type 2
SELECT
    customer_id,
    name,
    email,
    phone,
    tier,
    dbt_valid_from,
    dbt_valid_to
FROM {{ snap('snap_customers') }}
WHERE dbt_valid_to IS NULL
```

## Documentation and Lineage

```yaml
# documentation/models.md
{% docs dim_customers %}
Dimension table with all unique customers.
- Updated daily via dbt job
- Includes historical tracking via snapshots
- Related tables: fact_orders
{% enddocs %}

# models/marts/schema.yml
models:
  - name: dim_customers
    description: "{{ doc('dim_customers') }}"
    columns:
      - name: customer_id
        description: "Surrogate key from staging layer"
```

## dbt Commands Workflow

```bash
# Install dependencies
dbt deps

# Parse project (validate syntax)
dbt parse

# Run models
dbt run

# Run specific model
dbt run --select stg_customers

# Run with tags
dbt run --select tag:daily

# Test data quality
dbt test

# Generate documentation
dbt docs generate

# Serve documentation locally
dbt docs serve

# Run and test
dbt build

# Dry run (show compiled SQL)
dbt run --dry-run
```

## Key Concepts

- **Models:** SQL transformations organized in layers
- **Tests:** Automated data quality validation
- **Macros:** Reusable SQL functions
- **Snapshots:** Track history and changes (SCD)
- **Documentation:** Self-documenting data lineage

## Hands-On Lab

### Part 1: dbt Setup
1. Initialize dbt project
2. Configure connection to your warehouse
3. Create staging models for customers and orders
4. Run models and verify in warehouse

### Part 2: Testing and Quality
1. Add unique and not_null tests
2. Create custom tests
3. Run test suite
4. Debug failed tests

### Part 3: Advanced Patterns
1. Create intermediate models with macros
2. Add snapshots for SCD Type 2
3. Generate and explore documentation
4. Set up dbt Cloud for CI/CD

*See Part 2 of course for complete lab walkthrough and starter project*

*Last Updated: March 2026*
