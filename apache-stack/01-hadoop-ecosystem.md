# Apache Hadoop Ecosystem

## Overview

Apache Hadoop is the foundational open-source framework for distributed storage and processing of large datasets. Released in 2006, it pioneered the idea of bringing computation to data rather than moving data to computation — a principle still central to modern data engineering.

Understanding Hadoop gives you the mental model for how all distributed data systems work.

---

## 1. Core Architecture

Hadoop consists of four core components:

```
┌─────────────────────────────────────────────────┐
│                 Apache Hadoop                    │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │   HDFS   │  │   YARN   │  │  MapReduce    │  │
│  │(Storage) │  │(Resource │  │ (Processing)  │  │
│  │          │  │  Mgmt)   │  │               │  │
│  └──────────┘  └──────────┘  └───────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │           Hadoop Common (Utilities)        │  │
│  └────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## 2. HDFS — Hadoop Distributed File System

HDFS is designed to store very large files reliably across a cluster of commodity hardware.

### Key Concepts

**Block-based storage**
- Files are split into fixed-size blocks (default: 128 MB)
- Each block is stored on separate DataNodes
- A 1 GB file = 8 blocks distributed across the cluster

**Replication factor**
- Each block is replicated across multiple DataNodes (default: 3)
- Provides fault tolerance: one node can fail with no data loss

```
File: /data/sales.csv (500 MB)
             │
    ┌────────┼────────┐
    ▼        ▼        ▼
 Block 1   Block 2   Block 3   Block 4  (128 MB each, last block partial)
    │        │        │        │
 Replicated 3x across DataNodes
```

### NameNode vs DataNode

| Component | Role | Count |
|-----------|------|-------|
| **NameNode** | Stores file system metadata (where blocks live). The "directory" of HDFS. | 1 (active) + 1 standby |
| **DataNode** | Stores actual data blocks. Reports health to NameNode. | Many (10 to 10,000+) |

**NameNode is the single point of coordination** — it holds the entire namespace in memory. This is why HDFS has high latency for small files but excellent throughput for large sequential reads.

### HDFS Shell Commands

```bash
# List files in HDFS
hdfs dfs -ls /data/

# Upload a local file to HDFS
hdfs dfs -put local_file.csv /data/

# Download from HDFS
hdfs dfs -get /data/output/ ./local_output/

# Show disk usage
hdfs dfs -du -h /data/

# Check replication and block locations
hdfs fsck /data/sales.csv -files -blocks -locations

# Create a directory
hdfs dfs -mkdir -p /data/warehouse/sales

# Delete with -skipTrash flag
hdfs dfs -rm -r /data/temp/
```

### HDFS vs Cloud Object Storage

| Aspect | HDFS | S3 / GCS / ADLS |
|--------|------|-----------------|
| Latency | Low (co-located with compute) | Higher (network hop) |
| Scalability | Limited by hardware | Virtually unlimited |
| Cost | High (hardware + ops) | Low (pay per GB) |
| Fault tolerance | Replication factor | Built-in (11 nines durability) |
| Best for | On-premise Hadoop clusters | Cloud-native data lakes |

**Modern trend:** Replace HDFS with cloud object storage and keep YARN/Spark on top. This is the "decoupled storage" model that Snowflake and Databricks use.

---

## 3. MapReduce — The Programming Model

MapReduce is a programming model for processing large datasets in parallel across a cluster. It has two phases:

```
Input Data (HDFS blocks)
      │
      ▼
  ┌────────┐
  │  MAP   │  → Transform each record independently
  └────────┘
      │
  (Sort & Shuffle — the framework handles this)
      │
      ▼
  ┌─────────┐
  │ REDUCE  │  → Aggregate grouped results
  └─────────┘
      │
      ▼
  Output (HDFS)
```

### Word Count Example (the "Hello World" of MapReduce)

**Python (Hadoop Streaming):**

```python
# mapper.py — runs on each input line
import sys

for line in sys.stdin:
    words = line.strip().split()
    for word in words:
        print(f"{word}\t1")  # key=word, value=1

# reducer.py — runs on sorted key-value pairs from mapper
import sys

current_word = None
current_count = 0

for line in sys.stdin:
    word, count = line.strip().split('\t')
    count = int(count)

    if word == current_word:
        current_count += count
    else:
        if current_word:
            print(f"{current_word}\t{current_count}")
        current_word = word
        current_count = count

if current_word:
    print(f"{current_word}\t{current_count}")
```

**Running via Hadoop Streaming:**
```bash
hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
  -input /data/text/ \
  -output /data/wordcount_output \
  -mapper mapper.py \
  -reducer reducer.py \
  -file mapper.py \
  -file reducer.py
```

### Java MapReduce (Traditional API)

```java
public class WordCount {

    public static class TokenizerMapper
        extends Mapper<Object, Text, Text, IntWritable> {

        private final static IntWritable one = new IntWritable(1);
        private Text word = new Text();

        public void map(Object key, Text value, Context context)
            throws IOException, InterruptedException {
            StringTokenizer itr = new StringTokenizer(value.toString());
            while (itr.hasMoreTokens()) {
                word.set(itr.nextToken());
                context.write(word, one);  // emit (word, 1)
            }
        }
    }

    public static class IntSumReducer
        extends Reducer<Text, IntWritable, Text, IntWritable> {

        public void reduce(Text key, Iterable<IntWritable> values, Context context)
            throws IOException, InterruptedException {
            int sum = 0;
            for (IntWritable val : values) {
                sum += val.get();
            }
            context.write(key, new IntWritable(sum));  // emit (word, total)
        }
    }
}
```

### Why MapReduce Is Mostly Obsolete for New Code

- **Disk-based**: intermediate results written to HDFS between map and reduce phases — extremely slow for iterative algorithms (ML)
- **Verbose**: even simple operations require many lines of Java
- **No real-time**: batch only, high latency (minutes to hours)
- **Replaced by Apache Spark**, which keeps data in memory and is 10–100x faster

Understanding MapReduce is still valuable because it explains **why Spark was invented** and how distributed shuffles work at a conceptual level.

---

## 4. YARN — Yet Another Resource Negotiator

YARN separates resource management from processing logic, allowing multiple frameworks (Spark, Flink, MapReduce) to share the same cluster.

```
┌─────────────────────────────────────────┐
│           YARN Resource Manager         │  ← Global cluster scheduler
│   (tracks available CPU/memory)         │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
 Node 1      Node 2     Node 3
(Node Mgr)  (Node Mgr)  (Node Mgr)   ← Per-node agents
    │
    └── Application Master (Spark Driver, Flink JM, etc.)
           └── Containers (Spark Executors, Flink TMs, etc.)
```

### Key Components

| Component | Responsibility |
|-----------|---------------|
| **ResourceManager** | Allocates resources cluster-wide |
| **NodeManager** | Manages resources on a single node, launches containers |
| **ApplicationMaster** | Per-application resource negotiator (one per job) |
| **Container** | Unit of resource allocation (CPU + memory) |

### Submitting a Job to YARN

```bash
# Submit a Spark job to YARN cluster
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --num-executors 10 \
  --executor-memory 4g \
  --executor-cores 2 \
  my_spark_job.py

# Check running applications
yarn application -list

# Kill an application
yarn application -kill application_1683000000_0001

# Check application logs
yarn logs -applicationId application_1683000000_0001
```

---

## 5. The Hadoop Ecosystem

Hadoop has a rich ecosystem of projects built around HDFS and YARN:

```
Query/SQL Layer:    Hive      Impala    Presto/Trino   Spark SQL
                      │
Processing Layer:   Spark     Flink     MapReduce        Tez
                      │
Ingestion Layer:    Sqoop     Flume     Kafka (external)
                      │
Coordination:       ZooKeeper  Oozie  
                      │
Storage Layer:      HDFS      HBase    Kudu
```

### Apache Hive

SQL-on-Hadoop. Translates HiveQL queries into MapReduce or Tez jobs.

```sql
-- Create an external Hive table pointing to HDFS data
CREATE EXTERNAL TABLE sales (
    order_id    BIGINT,
    customer_id BIGINT,
    amount      DOUBLE,
    order_date  DATE
)
STORED AS PARQUET
LOCATION '/data/warehouse/sales/';

-- Query with partitioning
SELECT
    DATE_FORMAT(order_date, 'yyyy-MM') AS month,
    SUM(amount) AS total_revenue,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM sales
WHERE order_date >= '2024-01-01'
GROUP BY DATE_FORMAT(order_date, 'yyyy-MM')
ORDER BY month;

-- Create a partitioned table for performance
CREATE TABLE sales_partitioned (
    order_id    BIGINT,
    customer_id BIGINT,
    amount      DOUBLE
)
PARTITIONED BY (year INT, month INT)
STORED AS ORC;

-- Insert with dynamic partitioning
SET hive.exec.dynamic.partition.mode=nonstrict;
INSERT INTO sales_partitioned PARTITION(year, month)
SELECT order_id, customer_id, amount,
       YEAR(order_date), MONTH(order_date)
FROM sales;
```

### Apache HBase

Wide-column NoSQL store on top of HDFS. Used for low-latency random reads/writes at massive scale (billions of rows).

```java
// HBase Java API — put a row
Configuration config = HBaseConfiguration.create();
Connection connection = ConnectionFactory.createConnection(config);
Table table = connection.getTable(TableName.valueOf("user_events"));

Put put = new Put(Bytes.toBytes("user123_20240101_event456"));
put.addColumn(
    Bytes.toBytes("cf"),        // column family
    Bytes.toBytes("event_type"),// column qualifier
    Bytes.toBytes("purchase")   // value
);
put.addColumn(Bytes.toBytes("cf"), Bytes.toBytes("amount"), Bytes.toBytes("49.99"));
table.put(put);

// Get a row
Get get = new Get(Bytes.toBytes("user123_20240101_event456"));
Result result = table.get(get);
String eventType = Bytes.toString(result.getValue(
    Bytes.toBytes("cf"), Bytes.toBytes("event_type")
));
```

**Row key design is critical** — HBase rows are sorted lexicographically, so your row key determines scan performance.

### Apache Sqoop

Bulk transfers between relational databases and HDFS/Hive.

```bash
# Import entire table from MySQL to HDFS
sqoop import \
  --connect jdbc:mysql://db-host:3306/sales_db \
  --username analyst \
  --password-file /secure/db-password \
  --table orders \
  --target-dir /data/staging/orders \
  --as-parquetfile \
  --num-mappers 8

# Incremental import (new rows since last run)
sqoop import \
  --connect jdbc:mysql://db-host:3306/sales_db \
  --table orders \
  --incremental append \
  --check-column order_id \
  --last-value 1000000 \
  --target-dir /data/staging/orders_inc

# Export from HDFS back to a relational database
sqoop export \
  --connect jdbc:mysql://db-host:3306/reporting_db \
  --table monthly_summary \
  --export-dir /data/output/monthly_summary
```

### Apache Oozie

Workflow scheduler for Hadoop jobs. Define DAGs (directed acyclic graphs) of Hive, Spark, MapReduce, and shell jobs.

```xml
<!-- workflow.xml — a simple two-step pipeline -->
<workflow-app name="daily-pipeline" xmlns="uri:oozie:workflow:0.5">
  <start to="stage-raw-data"/>

  <action name="stage-raw-data">
    <hive xmlns="uri:oozie:hive-action:0.5">
      <job-tracker>${jobTracker}</job-tracker>
      <name-node>${nameNode}</name-node>
      <script>hive/stage_raw.hql</script>
    </hive>
    <ok to="run-spark-transform"/>
    <error to="fail"/>
  </action>

  <action name="run-spark-transform">
    <spark xmlns="uri:oozie:spark-action:0.2">
      <master>yarn</master>
      <mode>cluster</mode>
      <name>Transform Job</name>
      <class>com.example.TransformJob</class>
      <jar>transform-job.jar</jar>
    </spark>
    <ok to="end"/>
    <error to="fail"/>
  </action>

  <kill name="fail">
    <message>Job failed: ${wf:errorMessage(wf:lastErrorNode())}</message>
  </kill>
  <end name="end"/>
</workflow-app>
```

---

## 6. Hadoop vs Modern Cloud Architecture

| Concern | Traditional Hadoop | Modern Cloud (Spark + S3/GCS) |
|---------|-------------------|-------------------------------|
| Storage | HDFS (on cluster) | S3 / GCS / ADLS |
| Processing | MapReduce / Spark on YARN | Spark / Flink on Kubernetes |
| SQL | Hive / Impala | Spark SQL / BigQuery / Trino |
| Ingestion | Sqoop / Flume | Kafka / Airbyte / dbt |
| Orchestration | Oozie | Apache Airflow / Prefect |
| Cost model | Fixed cluster cost | Pay-per-use |
| Scalability | Manual cluster resizing | Auto-scale |

**Key takeaway:** The open-source ecosystem has largely migrated from on-premise HDFS clusters to cloud-native architectures. However, understanding Hadoop helps you:
1. Work with legacy on-premise systems that still run it
2. Understand the conceptual model that Spark and Flink are built on
3. Debug Spark issues that relate to YARN resource allocation
4. Appreciate why Databricks, EMR, and Dataproc were built

---

## 7. Local Setup

### Docker-based Hadoop Cluster (Recommended for Learning)

```bash
# Clone a ready-made Docker Compose setup
git clone https://github.com/big-data-europe/docker-hadoop.git
cd docker-hadoop
docker-compose up -d

# Check that all services are running
docker-compose ps

# Access HDFS via the NameNode web UI
open http://localhost:9870

# Access YARN ResourceManager web UI
open http://localhost:8088

# Open a shell inside the namenode container
docker exec -it namenode bash

# Run a MapReduce example inside the container
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  pi 4 100
```

---

## Knowledge Check

1. Explain the difference between NameNode and DataNode. What happens if the NameNode fails?
2. Why is MapReduce slow for iterative algorithms like machine learning? Which component causes this?
3. A 10 GB file with 128 MB block size and replication factor 3 — how many blocks and block copies exist in HDFS?
4. How does YARN allow multiple frameworks (Spark AND Flink) to run on the same cluster simultaneously?
5. When would you choose HBase over a traditional relational database?
6. What replaced Oozie as the dominant workflow scheduler? (hint: covered in `governance-integration/03-orchestration.md`)

---

## Next Module

→ [`02-apache-spark.md`](./02-apache-spark.md) — Spark replaces MapReduce with in-memory distributed processing, 10–100x faster, with a modern DataFrame API and unified engine for batch, streaming, and ML.
