# Databricks: ML Integration & Feature Stores

## Learning Outcomes
- Build ML pipelines with Spark ML
- Implement feature stores for ML
- Use MLflow for model tracking
- Deploy models in production
- Monitor model performance

**Estimated Time:** 2 hours  
**Prerequisites:** Module 01-03

## Spark ML Pipelines

```python
from pyspark.ml import Pipeline
from pyspark.ml.feature import VectorAssembler, StandardScaler
from pyspark.ml.classification import LogisticRegression

# Feature engineering
feature_cols = ['customer_age', 'purchase_frequency', 'recency_days']
vectorizer = VectorAssembler(inputCols=feature_cols, outputCol='features')
scaler = StandardScaler(inputCol='features', outputCol='scaled_features')

# Model
lr = LogisticRegression(featuresCol='scaled_features', labelCol='churn')

# Pipeline
pipeline = Pipeline(stages=[vectorizer, scaler, lr])
model = pipeline.fit(train_data)

# Make predictions
predictions = model.transform(test_data)
```

## MLflow Tracking

```python
import mlflow
from sklearn.metrics import accuracy_score, roc_auc_score

with mlflow.start_run():
    mlflow.log_param('max_depth', 5)
    mlflow.log_param('learning_rate', 0.01)
    
    model = train_model(data)
    
    mlflow.log_metric('accuracy', 0.95)
    mlflow.log_metric('auc', 0.92)
    mlflow.sklearn.log_model(model, 'churn_model')
    
    # Register model
    mlflow.register_model("runs:/{}/churn_model".format(run_id), "ChurnPredictor")
```

## Feature Stores

Centralized feature management with Databricks Feature Store:

```python
from databricks.feature_engineering import FeatureEngineeringClient

fe = FeatureEngineeringClient()

# Create feature table
features_df = spark.sql("""
  SELECT
    customer_id,
    COUNT(*) as purchase_count,
    SUM(amount) as lifetime_value,
    DATEDIFF(CURRENT_DATE(), MAX(order_date)) as days_since_purchase
  FROM orders
  GROUP BY customer_id
""")

# Write to feature store
fe.write_table(
    name='customer_features',
    df=features_df,
    mode='merge',
    primary_keys=['customer_id']
)

# Read features for training
training_set = fe.create_training_set(
    label_rows=labeled_data,
    feature_table_name='customer_features',
    feature_lookups=[
        FeatureLookup(
            table_name='customer_features',
            lookup_key=['customer_id']
        )
    ]
)
```

## Model Serving

```python
# Register and serve model
from mlflow.models import cli

# Register for production
mlflow.register_model(
    "runs:/abc123/model",
    "customer_churn"
)

# Transition to production
client = mlflow.tracking.MlflowClient()
client.transition_model_version_stage(
    name="customer_churn",
    version=1,
    stage="Production"
)

# Serve predictions via API
# Endpoint: /invocations
```

## Key Concepts

- **Spark ML:** Built-in ML library for distributed training
- **MLflow:** Experiment tracking and model registry
- **Feature Stores:** Centralized feature management
- **Model Registry:** Version control for models
- **A/B Testing:** Compare model versions in production

## Hands-On Lab

### Part 1: Build ML Pipeline
1. Create feature pipeline
2. Train logistic regression
3. Track metrics in MLflow
4. Register model

### Part 2: Feature Store
1. Create feature table
2. Join features with labels
3. Create training set
4. Version feature definitions

### Part 3: Model Serving
1. Deploy model endpoint
2. Make batch predictions
3. Monitor model performance
4. Implement retraining schedule

*See Part 2 of course for complete lab walkthrough*

*Last Updated: March 2026*
