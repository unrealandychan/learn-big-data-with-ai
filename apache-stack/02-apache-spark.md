# Apache Spark

## Overview

Apache Spark is the most widely used distributed data processing engine in the world. It replaced MapReduce as the standard for big data processing by keeping intermediate results in memory instead of writing them to disk, making it 10–100x faster for iterative workloads.

Databricks is built on Apache Spark. If you use Databricks, you are using Spark.

---

## 1. Spark Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Spark Application                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Driver Program                       │   │
│  │                                                      │   │
│  │  SparkContext / SparkSession                         │   │
│  │  DAG Scheduler → Task Scheduler → Cluster Manager   │   │
│  └──────────────────────┬──────────────────────────────┘   │
│                         │ (submits tasks)                   │
│         ┌───────────────┼───────────────┐                  │
│         ▼               ▼               ▼                  │
│    ┌──────────┐   ┌──────────┐   ┌──────────┐             │
│    │ Executor │   │ Executor │   │ Executor │             │
│    │  (Node1) │   │  (Node2) │   │  (Node3) │             │
│    │ Task Task│   │ Task Task│   │ Task Task│             │
│    │ [Cache]  │   │ [Cache]  │   │ [Cache]  │             │
│    └──────────┘   └──────────┘   └──────────┘             │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Role |
|-----------|------|
| **Driver** | Runs the `main()` function, creates SparkSession, plans the job, and coordinates executors |
| **Executor** | JVM process on a worker node — executes tasks, caches data |
| **Task** | Smallest unit of work — processes one partition |
| **Stage** | Group of tasks that can run in parallel (separated by shuffles) |
| **Job** | Triggered by an action; broken into stages |
| **Cluster Manager** | YARN, Kubernetes, or Spark Standalone — allocates resources |

### Spark vs MapReduce

| Aspect | MapReduce | Spark |
|--------|-----------|-------|
| Intermediate storage | HDFS (disk) | Memory (RAM) |
| Speed for iterative ML | Very slow | 10–100x faster |
| API | Java (verbose) | Python, Scala, Java, R |
| Streaming | No | Yes (Structured Streaming) |
| SQL | Hive on top | Built-in Spark SQL |
| ML | Mahout (separate) | MLlib (built-in) |

---

## 2. SparkSession — The Entry Point

```python
from pyspark.sql import SparkSession

# Create a SparkSession (one per application)
spark = SparkSession.builder \
    .appName("SalesAnalysis") \
    .master("local[*]")  \          # local[*] = use all local CPU cores
    .config("spark.sql.shuffle.partitions", "200") \
    .config("spark.executor.memory", "4g") \
    .getOrCreate()

# On Databricks or YARN, omit .master() — it's set by the cluster
spark = SparkSession.builder \
    .appName("SalesAnalysis") \
    .getOrCreate()

# Access the underlying SparkContext
sc = spark.sparkContext
print(sc.version)    # Spark version
print(sc.master)     # Cluster manager being used
```

---

## 3. The Three APIs

Spark offers three abstractions for working with data, from low-level to high-level:

### 3.1 RDD — Resilient Distributed Dataset (low-level, avoid for new code)

```python
# Create an RDD from a list
rdd = sc.parallelize([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], numSlices=4)

# Transformation (lazy — doesn't execute yet)
squared = rdd.map(lambda x: x ** 2)
evens = rdd.filter(lambda x: x % 2 == 0)

# Action (triggers execution)
result = evens.collect()          # returns list to driver
print(result)  # [2, 4, 6, 8, 10]

total = rdd.reduce(lambda a, b: a + b)
print(total)   # 55

# Word count with RDD
text_rdd = sc.textFile("hdfs:///data/corpus/*.txt")
word_counts = (text_rdd
    .flatMap(lambda line: line.split(" "))
    .map(lambda word: (word.lower(), 1))
    .reduceByKey(lambda a, b: a + b)
    .sortBy(lambda x: x[1], ascending=False)
)

# Persist to avoid recomputation
word_counts.persist()

# Show top 10
for word, count in word_counts.take(10):
    print(f"{word}: {count}")
```

**When to use RDDs:** Custom partitioning logic, binary/unstructured data, or when you need fine-grained control. For structured/semi-structured data, always use DataFrames.

### 3.2 DataFrame API (recommended for analytics)

```python
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, DateType

# --- Reading Data ---

# From CSV
df_orders = spark.read.csv(
    "hdfs:///data/orders/*.csv",
    header=True,
    inferSchema=True
)

# With explicit schema (preferred — avoids costly schema inference)
schema = StructType([
    StructField("order_id",     StringType(),  nullable=False),
    StructField("customer_id",  StringType(),  nullable=True),
    StructField("amount",       DoubleType(),  nullable=True),
    StructField("order_date",   DateType(),    nullable=True),
    StructField("region",       StringType(),  nullable=True),
])

df_orders = spark.read.schema(schema).csv("hdfs:///data/orders/")

# From Parquet (columnar, best format for analytics)
df_customers = spark.read.parquet("s3a://my-bucket/customers/")

# From Delta Lake (Databricks-native format)
df_events = spark.read.format("delta").load("dbfs:/delta/events/")

# From JDBC (database)
df_db = spark.read.jdbc(
    url="jdbc:postgresql://host:5432/sales",
    table="orders",
    properties={"user": "analyst", "password": "secret", "driver": "org.postgresql.Driver"}
)

# --- Transformations ---

# Select and rename
result = df_orders.select(
    F.col("order_id"),
    F.col("customer_id"),
    F.col("amount").alias("order_amount"),
    F.to_date("order_date").alias("date")
)

# Filter
high_value = df_orders.filter(F.col("amount") > 1000)
recent = df_orders.filter(
    (F.col("order_date") >= "2024-01-01") &
    (F.col("region").isin("North", "East"))
)

# Add derived columns
enriched = df_orders.withColumn(
    "revenue_category",
    F.when(F.col("amount") >= 10000, "enterprise")
     .when(F.col("amount") >= 1000,  "mid-market")
     .otherwise("small")
).withColumn(
    "order_year",
    F.year(F.col("order_date"))
)

# Aggregations
monthly_summary = df_orders.groupBy(
    F.year("order_date").alias("year"),
    F.month("order_date").alias("month"),
    "region"
).agg(
    F.sum("amount").alias("total_revenue"),
    F.count("order_id").alias("order_count"),
    F.avg("amount").alias("avg_order_value"),
    F.countDistinct("customer_id").alias("unique_customers")
)

# Joins
df_enriched = df_orders.join(
    df_customers,
    on="customer_id",
    how="left"
)

# Window functions
from pyspark.sql.window import Window

window_spec = Window.partitionBy("region").orderBy(F.desc("amount"))

df_ranked = df_orders.withColumn(
    "rank_in_region",
    F.rank().over(window_spec)
).withColumn(
    "running_total",
    F.sum("amount").over(Window.partitionBy("region").orderBy("order_date")
        .rowsBetween(Window.unboundedPreceding, Window.currentRow))
)

# --- Writing Data ---

# Write as Parquet (partitioned)
monthly_summary.write \
    .partitionBy("year", "month") \
    .mode("overwrite") \
    .parquet("hdfs:///data/output/monthly_summary/")

# Write as Delta Lake
df_enriched.write \
    .format("delta") \
    .mode("append") \
    .save("dbfs:/delta/enriched_orders/")

# Write to JDBC
monthly_summary.write.jdbc(
    url="jdbc:postgresql://host:5432/reporting",
    table="monthly_summary",
    mode="overwrite",
    properties={"user": "writer", "password": "secret"}
)
```

### 3.3 Spark SQL

```python
# Register a DataFrame as a temporary view
df_orders.createOrReplaceTempView("orders")
df_customers.createOrReplaceTempView("customers")

# Run SQL directly
result = spark.sql("""
    SELECT
        c.region,
        DATE_FORMAT(o.order_date, 'yyyy-MM') AS month,
        SUM(o.amount)                          AS total_revenue,
        COUNT(DISTINCT o.customer_id)           AS unique_customers,
        RANK() OVER (
            PARTITION BY c.region
            ORDER BY SUM(o.amount) DESC
        ) AS revenue_rank
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_date >= '2024-01-01'
    GROUP BY c.region, DATE_FORMAT(o.order_date, 'yyyy-MM')
    ORDER BY c.region, month
""")

result.show(20, truncate=False)

# Create a persistent table in the Spark catalog
spark.sql("""
    CREATE TABLE IF NOT EXISTS monthly_revenue
    USING DELTA
    PARTITIONED BY (year, month)
    AS
    SELECT
        YEAR(order_date) AS year,
        MONTH(order_date) AS month,
        SUM(amount) AS total_revenue
    FROM orders
    GROUP BY YEAR(order_date), MONTH(order_date)
""")
```

---

## 4. Structured Streaming

Spark Structured Streaming lets you write batch-style queries that run continuously on incoming data.

```python
from pyspark.sql import functions as F

# --- Read from Kafka topic ---
df_stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka-broker:9092") \
    .option("subscribe", "user_events") \
    .option("startingOffsets", "latest") \
    .load()

# Parse the Kafka value (JSON payload)
from pyspark.sql.types import StructType, StringType, DoubleType, LongType

event_schema = StructType() \
    .add("user_id", StringType()) \
    .add("event_type", StringType()) \
    .add("amount", DoubleType()) \
    .add("timestamp", LongType())

parsed = df_stream.select(
    F.from_json(F.col("value").cast("string"), event_schema).alias("data"),
    F.col("timestamp").alias("kafka_timestamp")
).select("data.*", "kafka_timestamp")

# --- Windowed aggregation ---
windowed_counts = parsed \
    .withWatermark("kafka_timestamp", "10 minutes") \
    .groupBy(
        F.window(F.col("kafka_timestamp").cast("timestamp"), "5 minutes"),
        "event_type"
    ).agg(
        F.count("*").alias("event_count"),
        F.sum("amount").alias("total_amount")
    )

# --- Write stream to Delta Lake (with checkpointing) ---
query = windowed_counts.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "dbfs:/checkpoints/event_counts/") \
    .start("dbfs:/delta/event_counts/")

# Wait for termination, or run with a timeout for tests
query.awaitTermination()

# --- Write stream to console (for development) ---
debug_query = parsed.writeStream \
    .format("console") \
    .outputMode("append") \
    .option("truncate", False) \
    .start()
```

### Output Modes

| Mode | When to use |
|------|-------------|
| `append` | Add only new rows (immutable sinks like files, Kafka) |
| `complete` | Rewrite entire result table each trigger (aggregations to console/memory) |
| `update` | Only changed rows since last trigger (sinks that support upserts) |

---

## 5. MLlib — Machine Learning at Scale

```python
from pyspark.ml import Pipeline
from pyspark.ml.feature import (
    VectorAssembler, StringIndexer, StandardScaler, OneHotEncoder
)
from pyspark.ml.classification import RandomForestClassifier
from pyspark.ml.evaluation import BinaryClassificationEvaluator
from pyspark.ml.tuning import CrossValidator, ParamGridBuilder

# --- Load and prepare data ---
df = spark.read.parquet("hdfs:///data/churn_features/")

# Encode categorical features
indexer = StringIndexer(
    inputCols=["plan_type", "region"],
    outputCols=["plan_index", "region_index"]
)
encoder = OneHotEncoder(
    inputCols=["plan_index", "region_index"],
    outputCols=["plan_vec", "region_vec"]
)

# Assemble all features into a single vector column
assembler = VectorAssembler(
    inputCols=["tenure_months", "monthly_charge", "num_support_calls",
               "plan_vec", "region_vec"],
    outputCol="features_raw"
)

scaler = StandardScaler(
    inputCol="features_raw",
    outputCol="features",
    withMean=True,
    withStd=True
)

# Define the classifier
rf = RandomForestClassifier(
    labelCol="churned",
    featuresCol="features",
    numTrees=100,
    maxDepth=8,
    seed=42
)

# Build and fit the pipeline
pipeline = Pipeline(stages=[indexer, encoder, assembler, scaler, rf])

# Train/test split
train_df, test_df = df.randomSplit([0.8, 0.2], seed=42)
model = pipeline.fit(train_df)

# Evaluate
predictions = model.transform(test_df)
evaluator = BinaryClassificationEvaluator(labelCol="churned")
auc = evaluator.evaluate(predictions)
print(f"AUC: {auc:.4f}")

# Save the model
model.save("hdfs:///models/churn_rf_v1/")

# Hyperparameter tuning with cross-validation
param_grid = ParamGridBuilder() \
    .addGrid(rf.numTrees, [50, 100, 200]) \
    .addGrid(rf.maxDepth, [5, 8, 10]) \
    .build()

cv = CrossValidator(
    estimator=pipeline,
    estimatorParamMaps=param_grid,
    evaluator=evaluator,
    numFolds=3
)
cv_model = cv.fit(train_df)
best_model = cv_model.bestModel
```

---

## 6. Performance Tuning

### Partitioning

```python
# Check number of partitions
print(df.rdd.getNumPartitions())  # e.g., 200

# Repartition (triggers shuffle — use when redistributing unevenly)
df_balanced = df.repartition(100, "region")

# Coalesce (reduces partitions WITHOUT a shuffle — for writing to fewer files)
df_small = df.coalesce(10)

# Optimal partition size: aim for 128MB–256MB of data per partition
# Rule of thumb: 2–4 partitions per CPU core in your cluster
```

### Caching

```python
from pyspark import StorageLevel

# Cache frequently accessed DataFrames
df_customers.cache()                                   # in memory (default)
df_customers.persist(StorageLevel.MEMORY_AND_DISK)     # spill to disk if needed
df_customers.persist(StorageLevel.DISK_ONLY)           # disk only (large data)

# Force materialization
df_customers.count()  # triggers the action that fills the cache

# Unpersist when done
df_customers.unpersist()
```

### Avoiding Shuffles

```python
# BAD: groupBy causes a full shuffle across all partitions
df.groupBy("customer_id").agg(F.sum("amount"))

# BETTER: use reduceByKey on pre-aggregated data (RDD-level)
# Or: pre-partition your data by the join/group key when writing it

# If joining a small table (<= few hundred MB), broadcast it to avoid shuffle
from pyspark.sql.functions import broadcast

df_large.join(broadcast(df_small_lookup), "product_id", "left")

# Check the execution plan
df_result.explain(mode="formatted")  # 'simple', 'extended', 'cost', 'formatted'
```

### Key Configuration Parameters

```python
spark = SparkSession.builder \
    .config("spark.sql.shuffle.partitions", "200")   \  # Default 200; tune to data size
    .config("spark.executor.memory", "8g")           \  # Memory per executor
    .config("spark.executor.cores", "4")             \  # Cores per executor
    .config("spark.driver.memory", "4g")             \  # Driver memory
    .config("spark.sql.autoBroadcastJoinThreshold", "50mb") \  # Raise for bigger lookups
    .config("spark.speculation", "true")             \  # Retry straggler tasks
    .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
    .getOrCreate()
```

### Common Performance Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| `collect()` on large dataset | Brings all data to driver, OOM | Use `show()`, `take()`, or write to storage |
| `UDF` (Python) on DataFrames | Bypasses Spark optimizer, serialization overhead | Use built-in `pyspark.sql.functions` instead |
| Too few partitions | Under-utilizes cluster | Repartition or increase `spark.sql.shuffle.partitions` |
| Too many small files | Overhead per file, slow reads | Compact with `coalesce()` before writing |
| Joining without broadcast on small table | Unnecessary shuffle | Use `broadcast()` hint |
| Repeated reads of the same dataset | Re-reads from storage each time | `.cache()` the DataFrame |

---

## 7. Delta Lake (Spark + ACID Transactions)

Delta Lake adds reliability features to data lakes — the same technology behind Databricks.

```python
from delta.tables import DeltaTable

# Create a Delta table
df_orders.write \
    .format("delta") \
    .mode("overwrite") \
    .save("/delta/orders/")

# Read it back
df_delta = spark.read.format("delta").load("/delta/orders/")

# UPSERT (MERGE) — update existing rows, insert new ones
delta_table = DeltaTable.forPath(spark, "/delta/orders/")

delta_table.alias("target").merge(
    df_updates.alias("source"),
    "target.order_id = source.order_id"
).whenMatchedUpdate(set={
    "amount": "source.amount",
    "status": "source.status"
}).whenNotMatchedInsertAll().execute()

# Time travel — read a previous version
df_v1 = spark.read.format("delta") \
    .option("versionAsOf", 1) \
    .load("/delta/orders/")

df_yesterday = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-15") \
    .load("/delta/orders/")

# Optimize (compact small files, add Z-order index)
spark.sql("OPTIMIZE delta.`/delta/orders/` ZORDER BY (customer_id, order_date)")

# View history
delta_table.history().show(truncate=False)

# Vacuum (remove old file versions, default 7-day retention)
delta_table.vacuum(retentionHours=168)
```

---

## 8. Running Spark Locally (Setup)

```bash
# Install PySpark
pip install pyspark delta-spark

# Run PySpark shell interactively
pyspark --master local[4] \
        --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" \
        --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog"

# Submit a script to a cluster
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --executor-memory 4g \
  --num-executors 8 \
  --py-files dependencies.zip \
  my_pipeline.py

# Run on Databricks with the Databricks CLI
databricks runs submit --json '{
  "run_name": "Daily Pipeline",
  "new_cluster": {"spark_version": "14.3.x-scala2.12", "num_workers": 4},
  "spark_python_task": {"python_file": "dbfs:/jobs/daily_pipeline.py"}
}'
```

---

## Knowledge Check

1. What is the difference between a transformation and an action in Spark? Name 3 of each.
2. Why is broadcasting a small table in a join a performance optimization? What would happen without it?
3. A Spark job has 2 stages. What caused the stage boundary?
4. When would you use `.coalesce()` vs `.repartition()`?
5. Explain the difference between Spark Streaming's `append`, `complete`, and `update` output modes.
6. Delta Lake adds which 4 reliability features that plain Parquet files lack?

---

## Next Module

→ [`03-apache-flink.md`](./03-apache-flink.md) — Flink is the purpose-built stream processing engine. Where Spark Streaming excels at micro-batch, Flink is truly event-driven, offering lower latency and more powerful stateful stream processing primitives.
