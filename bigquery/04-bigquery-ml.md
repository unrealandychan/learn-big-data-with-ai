# BigQuery: BigQuery ML & Advanced Analytics

## Learning Outcomes
- Build ML models with BQML
- Create time series forecasts
- Make predictions at scale
- Deploy models for production
- Monitor model drift

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01-03

## BQML Model Types

```sql
-- 1. Linear Regression for continuous targets
CREATE OR REPLACE MODEL `project`.dataset.sales_forecast AS
SELECT
  EXTRACT(YEAR FROM order_date) as year,
  EXTRACT(MONTH FROM order_date) as month,
  SUM(amount) as sales,
  COUNT(*) as transactions,
  AVG(amount) as avg_order
FROM `project`.dataset.orders
WHERE order_date >= '2020-01-01'
GROUP BY year, month;

-- 2. Logistic Regression for binary classification
CREATE OR REPLACE MODEL `project`.dataset.churn_predictor AS
SELECT
  customer_id,
  DATEDIFF(CURRENT_DATE(), MAX(order_date)) as days_since_order,
  COUNT(*) as purchase_count,
  SUM(amount) as lifetime_value,
  CASE WHEN MAX(order_date) < CURRENT_DATE() - 90 THEN 1 ELSE 0 END as churned
FROM `project`.dataset.customers c
LEFT JOIN `project`.dataset.orders o ON c.customer_id = o.customer_id
GROUP BY customer_id;

-- 3. Time Series (ARIMA+)
CREATE OR REPLACE MODEL `project`.dataset.daily_revenue_forecast
OPTIONS(
  model_type='LINEAR_REG',
  time_series_timestamp_col='order_date',
  time_series_data_col='daily_revenue'
) AS
SELECT
  DATE(order_date) as order_date,
  SUM(amount) as daily_revenue
FROM `project`.dataset.orders
WHERE order_date >= CURRENT_DATE() - 365
GROUP BY order_date;
```

## Making Predictions

```sql
-- Batch predictions
SELECT * FROM ML.PREDICT(MODEL `project`.dataset.sales_forecast,
  (SELECT
    2024 as year,
    4 as month,
    NULL as sales,
    NULL as transactions,
    NULL as avg_order
  )
);

-- Score all customers for churn
SELECT
  customer_id,
  predicted_churned as churn_probability
FROM ML.PREDICT(MODEL `project`.dataset.churn_predictor,
  (SELECT * FROM `project`.dataset.customers)
)
ORDER BY predicted_churned DESC
LIMIT 100;
```

## Model Evaluation

```sql
-- Evaluate model performance
SELECT * FROM ML.EVALUATE(
  MODEL `project`.dataset.churn_predictor,
  (
    SELECT
      customer_id,
      DATEDIFF(CURRENT_DATE(), MAX(order_date)) as days_since_order,
      COUNT(*) as purchase_count,
      SUM(amount) as lifetime_value,
      CASE WHEN MAX(order_date) < CURRENT_DATE() - 90 THEN 1 ELSE 0 END as churned
    FROM `project`.dataset.customers c
    LEFT JOIN `project`.dataset.orders o ON c.customer_id = o.customer_id
    GROUP BY customer_id
  )
);
-- Returns: precision, recall, accuracy, AUC-ROC
```

## Model Registry

```sql
-- Save model version for production
CREATE OR REPLACE MODEL `project`.dataset.churn_predictor_v2 AS
(MODEL COPY `project`.dataset.churn_predictor);

-- Compare model versions
WITH model_v1 AS (
  SELECT predicted_churned as v1_prediction
  FROM ML.PREDICT(MODEL `project`.dataset.churn_predictor, table)
),
model_v2 AS (
  SELECT predicted_churned as v2_prediction
  FROM ML.PREDICT(MODEL `project`.dataset.churn_predictor_v2, table)
)
SELECT
  COUNT(*) as agreement_count,
  ROUND(COUNT(*) / COUNT(DISTINCT customer_id), 4) as agreement_pct
FROM model_v1
JOIN model_v2 ON TRUE;
```

## Key Concepts

- **BQML:** Train models using SQL without ML expertise
- **Feature Engineering:** Aggregations and calculations
- **Time Series:** Forecasting with temporal patterns
- **Evaluation Metrics:** Precision, recall, AUC-ROC
- **Model Versioning:** Track and compare model versions

## Hands-On Lab

### Part 1: Regression Model
1. Create linear regression model
2. Evaluate performance metrics
3. Make predictions on new data
4. Visualize forecasts

### Part 2: Classification Model
1. Create churn prediction model
2. Identify high-risk customers
3. Generate batch predictions
4. Implement action rules

### Part 3: Model Management
1. Create model versions
2. Compare performance
3. Set model registry
4. Document assumptions

*See Part 2 of course for complete lab*

*Last Updated: March 2026*
