# BigQuery: Hands-On Labs & Capstone

## Learning Outcomes
- Load and analyze real-world datasets
- Optimize queries for cost and speed
- Build end-to-end ML pipelines
- Create business intelligence dashboards

**Estimated Time:** 3 hours  
**Prerequisites:** Module 01-04

## Lab 1: Loading & Querying

### Part 1: Load from Cloud Storage
```sql
-- Create dataset
CREATE SCHEMA IF NOT EXISTS `project`.retail_analytics;

-- Load orders CSV
CREATE OR REPLACE TABLE `project`.retail_analytics.orders AS
SELECT 
  CAST(order_id AS INT64) as order_id,
  CAST(customer_id AS INT64) as customer_id,
  CAST(order_date AS DATE) as order_date,
  CAST(amount AS NUMERIC) as amount
FROM `project.region-us.EXTERNAL_QUERY_FUNCTION`(
  'SELECT * FROM opencsv.load(\'gs://my-bucket/orders.csv\')'
);

-- Verify data
SELECT COUNT(*) as row_count, MIN(order_date), MAX(order_date)
FROM `project`.retail_analytics.orders;
```

### Part 2: Exploratory Queries
```sql
-- Revenue trend
SELECT
  DATE_TRUNC(order_date, MONTH) as month,
  COUNT(*) as transactions,
  SUM(amount) as revenue,
  AVG(amount) as avg_order
FROM `project`.retail_analytics.orders
GROUP BY month
ORDER BY month DESC;

-- Top customers
SELECT
  customer_id,
  COUNT(*) as order_count,
  SUM(amount) as lifetime_value,
  MAX(order_date) as last_order_date
FROM `project`.retail_analytics.orders
GROUP BY customer_id
ORDER BY lifetime_value DESC
LIMIT 100;
```

## Lab 2: Optimization

### Compare Query Costs

```sql
-- Before optimization (full table scan)
SELECT * FROM `project`.retail_analytics.orders
WHERE DATE(order_date) = '2024-03-15';
-- Cost: ~$0.50 (36TB scanned)

-- After optimization (partition filter)
SELECT * FROM `project`.retail_analytics.orders_partitioned
WHERE DATE(order_date) = '2024-03-15';
-- Cost: ~$0.001 (100MB scanned)
```

### Add Partitioning and Clustering

```sql
-- Create optimized table
CREATE OR REPLACE TABLE `project`.retail_analytics.orders_optimized
PARTITION BY DATE(order_date)
CLUSTER BY customer_id, product_category AS
SELECT * FROM `project`.retail_analytics.orders;
```

## Lab 3: BQML Pipeline

### Build Churn Model
```sql
-- Create training data
CREATE OR REPLACE TABLE `project`.retail_analytics.churn_training AS
WITH customer_stats AS (
  SELECT
    c.customer_id,
    COUNT(*) as order_count,
    SUM(o.amount) as lifetime_value,
    MAX(o.order_date) as last_order,
    DATEDIFF(CURRENT_DATE(), MAX(o.order_date)) as days_since_order,
    CASE 
      WHEN MAX(o.order_date) < CURRENT_DATE() - 180 THEN 1 
      ELSE 0 
    END as churned
  FROM `project`.retail_analytics.customers c
  LEFT JOIN `project`.retail_analytics.orders o ON c.customer_id = o.customer_id
  GROUP BY c.customer_id
)
SELECT * FROM customer_stats;

-- Train model
CREATE OR REPLACE MODEL `project`.retail_analytics.churn_model
OPTIONS(
  model_type='LINEAR_REG'
) AS
SELECT * EXCEPT(customer_id)
FROM `project`.retail_analytics.churn_training;

-- Predict churn for all customers
SELECT
  customer_id,
  churned as actual_churn,
  predicted_churned as predicted_churn,
  ABS(churned - predicted_churned) as prediction_error
FROM ML.PREDICT(
  MODEL `project`.retail_analytics.churn_model,
  (SELECT * FROM `project`.retail_analytics.churn_training)
)
ORDER BY predicted_churned DESC;
```

## Lab 4: Dashboard Creation

### Key Metrics Table
```sql
CREATE OR REPLACE TABLE `project`.retail_analytics.dashboard_metrics AS
SELECT
  CURRENT_TIMESTAMP() as refresh_time,
  (SELECT COUNT(*) FROM `project`.retail_analytics.orders`) as total_orders,
  (SELECT SUM(amount) FROM `project`.retail_analytics.orders`) as total_revenue,
  (SELECT COUNT(DISTINCT customer_id) FROM `project`.retail_analytics.orders`) as unique_customers,
  (SELECT AVG(daily_revenue) FROM (
    SELECT SUM(amount) as daily_revenue
    FROM `project`.retail_analytics.orders
    GROUP BY DATE(order_date)
  )) as avg_daily_revenue;
```

## Submission Checklist

- [ ] All tables created in BigQuery dataset
- [ ] Partitioning and clustering applied
- [ ] Query costs documented and optimized
- [ ] BQML models trained and evaluated
- [ ] Predictions generated and validated
- [ ] Dashboard queries created
- [ ] Documentation completed

*Last Updated: March 2026*
