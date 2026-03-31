# Module: Apache Parquet

**Duration:** 2 hours  
**Prerequisites:** Basic data warehouse concepts  
**Level:** Intermediate

---

## Learning Outcomes

- Explain how Parquet physically stores data and why it's fast for analytics
- Understand row groups, column chunks, and page encoding
- Configure compression codecs for different trade-offs
- Use predicate pushdown and column pruning in practice
- Manage schema evolution safely

---

## 1. What is Parquet?

Apache Parquet is an **open-source columnar storage format** designed for analytical workloads. It was created in 2013 by Twitter and Cloudera and is now the default format for:

- Apache Spark (`.parquet` is the default `df.write` format)
- Delta Lake (Delta files ARE Parquet + a transaction log)
- Apache Hive, Presto, Trino, Athena
- Databricks, BigQuery (internally uses Capacitor, which is Parquet-inspired), Redshift Spectrum

---

## 2. Row vs. Columnar Storage — The Core Idea

Imagine a table with 4 columns: `order_id`, `customer_id`, `amount`, `status`.

### Row storage (CSV, Avro):
```
[order_id=1, customer_id=101, amount=50.00, status='SHIPPED']
[order_id=2, customer_id=102, amount=25.00, status='PENDING']
[order_id=3, customer_id=101, amount=75.00, status='SHIPPED']
```
To answer `SELECT SUM(amount) FROM orders`, you must read every field of every row — even `order_id`, `customer_id`, `status` which you don't need.

### Columnar storage (Parquet):
```
order_id column:    [1, 2, 3, ...]
customer_id column: [101, 102, 101, ...]
amount column:      [50.00, 25.00, 75.00, ...]
status column:      ['SHIPPED', 'PENDING', 'SHIPPED', ...]
```
To answer the same query, the engine reads **only the `amount` column chunk** — everything else is physically skipped on disk.

For a table with 100 columns and a query touching 5, Parquet reads **5%** of the data that a row format would.

---

## 3. Physical File Structure

```
Parquet File
├── Header (magic bytes: PAR1)
│
├── Row Group 1  (default ~128 MB)
│   ├── Column Chunk: order_id
│   │   ├── Page 1 (data page, ~1 MB)
│   │   ├── Page 2
│   │   └── ...
│   ├── Column Chunk: customer_id
│   ├── Column Chunk: amount
│   └── Column Chunk: status
│
├── Row Group 2
│   └── (same structure)
│
├── File Footer (Metadata)
│   ├── Schema definition
│   ├── Row group offsets
│   ├── Column statistics per row group:
│   │     min/max/null_count per column chunk
│   └── Encoding info per column
│
└── Footer length + magic bytes (PAR1)
```

### Key concepts:

| Concept | Description |
|---------|-------------|
| **Row Group** | Horizontal slice of rows (~128 MB default). The unit of parallelism in Spark. |
| **Column Chunk** | All values of one column within a row group. The unit of I/O skipping. |
| **Page** | Sub-division of a column chunk (~1 MB). The unit of compression/encoding. |
| **Footer** | Metadata for the whole file — read first to locate data without scanning. |
| **Column Statistics** | `min`, `max`, `null_count` stored per column chunk in the footer — enables predicate pushdown. |

---

## 4. Predicate Pushdown (Row Group Skipping)

The footer stores **min/max statistics** for every column in every row group. The query engine reads the footer, evaluates your `WHERE` clause against the statistics, and **skips entire row groups** that can't possibly contain matching rows.

```python
# Example: query with a date filter
df = spark.read.parquet("/data/orders/")
result = df.filter(df.order_date == "2024-03-15").select("amount").agg({"amount": "sum"})

# What happens under the hood:
# 1. Spark reads the Parquet footer (tiny — usually < 1 MB)
# 2. For each row group, checks: does order_date min/max range include 2024-03-15?
# 3. Row groups where max(order_date) < 2024-03-15 → SKIPPED (never read from disk)
# 4. Only matching row groups are read — plus only the 'amount' column (column pruning)
```

**For this to work well, data must be sorted/written in order of the filter column.**  
This is why Delta Lake's `OPTIMIZE ... ZORDER BY (order_date)` is so powerful — it clusters rows with the same date into the same row groups.

```python
# Check how many row groups were skipped in Spark
# Look in Spark UI → Stages → Task Metrics → "number of files pruned"

# Or check via PySpark plan
df.filter(df.order_date == "2024-03-15").explain("formatted")
# Look for: PartitionFilters, PushedFilters in the FileScan node
```

---

## 5. Column Encoding

Within a page, Parquet uses smart encodings to reduce size before compression:

| Encoding | How It Works | Best For |
|----------|-------------|---------|
| **Plain** | Raw values, no transformation | Unique values (e.g., UUIDs) |
| **Dictionary** | Replace repeated values with an integer index; store dictionary separately | Low-cardinality columns (status, country) |
| **RLE (Run-Length Encoding)** | Store repeated values as (value, count) pairs | Sorted or banded data |
| **Delta encoding** | Store differences between consecutive values | Monotonically increasing integers (IDs, timestamps) |
| **Bit packing** | Pack small integers into fewer bits | Integer columns with small range |

Dictionary encoding is the biggest win in practice:

```
# Column: status = ['SHIPPED', 'PENDING', 'SHIPPED', 'SHIPPED', 'DELIVERED', 'PENDING']
# Dictionary: {0: 'SHIPPED', 1: 'PENDING', 2: 'DELIVERED'}
# Encoded:    [0, 1, 0, 0, 2, 1]  ← integers instead of strings = much smaller
```

---

## 6. Compression Codecs

After encoding, Parquet applies compression at the page level. Choose based on your priority:

| Codec | Compression Ratio | Speed | CPU Cost | Best For |
|-------|------------------|-------|----------|---------|
| **Snappy** | Moderate | Very fast | Low | Default for most workloads (Spark default) |
| **GZIP** | High | Slow | High | Archival storage where read speed matters less |
| **ZSTD** | High | Fast | Moderate | Best overall balance — recommended for new pipelines |
| **LZO** | Moderate | Very fast | Low | Legacy; Snappy is generally preferred now |
| **Brotli** | Very high | Slow | Very high | Maximum compression, rarely used in practice |
| **Uncompressed** | None | Fastest | None | Local dev/testing only |

```python
# Set compression codec in PySpark
df.write \
  .format("parquet") \
  .option("compression", "zstd") \
  .save("/data/orders/")

# Or set globally
spark.conf.set("spark.sql.parquet.compression.codec", "zstd")

# In Pandas
df.to_parquet("orders.parquet", compression="snappy")
```

**Rule of thumb:** Use `snappy` for hot data (read often), `zstd` for cold/archival data.

---

## 7. Schema Evolution

Parquet supports limited schema evolution — you can **add columns** safely, but other changes need care.

| Change | Supported? | Notes |
|--------|-----------|-------|
| Add new column | ✅ Yes | Old files return `null` for the new column |
| Remove a column | ⚠️ Partial | Old files still have the column; new readers ignore it if schema specifies removal |
| Rename a column | ❌ No | Treated as a delete + add; old data for that column is lost |
| Change data type | ❌ Generally no | `int32 → int64` is ok; `string → int` will break |
| Reorder columns | ✅ Yes | Parquet uses column names, not positions |

```python
# Spark: merge schemas from files with different columns
df = spark.read \
  .option("mergeSchema", "true") \
  .parquet("/data/orders/")

# Delta Lake: schema evolution
df.write \
  .format("delta") \
  .option("mergeSchema", "true") \
  .mode("append") \
  .save("/delta/orders/")
```

---

## 8. Reading and Writing Parquet — Practical Examples

### PySpark

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

spark = SparkSession.builder.appName("parquet-demo").getOrCreate()

# Write
orders_df.write \
  .format("parquet") \
  .partitionBy("order_date")          \  # creates directory-level partitions
  .option("compression", "snappy")    \
  .mode("overwrite") \
  .save("/data/orders/")

# Read (Spark auto-discovers schema from footer)
df = spark.read.parquet("/data/orders/")
df.printSchema()

# Filter with predicate pushdown (happens automatically)
daily = df.filter(col("order_date") == "2024-03-15") \
          .select("customer_id", "amount")

# Inspect what Spark is actually doing
daily.explain("formatted")
# Look for PushedFilters and PartitionFilters in FileScan
```

### Pandas

```python
import pandas as pd

# Write
df.to_parquet("orders.parquet", engine="pyarrow", compression="snappy", index=False)

# Read entire file
df = pd.read_parquet("orders.parquet", engine="pyarrow")

# Read only specific columns (column pruning)
df = pd.read_parquet("orders.parquet", columns=["customer_id", "amount"])

# Read with row filter (predicate pushdown via PyArrow)
import pyarrow.parquet as pq
table = pq.read_table(
    "orders.parquet",
    columns=["customer_id", "amount"],
    filters=[("order_date", "=", "2024-03-15")]  # row group skipping applied
)
df = table.to_pandas()
```

### Inspecting a Parquet File

```python
import pyarrow.parquet as pq

# Read file metadata (footer only — fast)
meta = pq.read_metadata("orders.parquet")
print(f"Row groups: {meta.num_row_groups}")
print(f"Total rows: {meta.num_rows}")
print(f"Serialized size: {meta.serialized_size}")

# Inspect row group statistics
for i in range(meta.num_row_groups):
    rg = meta.row_group(i)
    print(f"\nRow group {i}: {rg.num_rows} rows")
    for j in range(rg.num_columns):
        col = rg.column(j)
        print(f"  {col.path_in_schema}: "
              f"min={col.statistics.min}, "
              f"max={col.statistics.max}, "
              f"nulls={col.statistics.null_count}")
```

---

## 9. Parquet in Cloud Warehouses

| Platform | How Parquet Is Used |
|----------|---------------------|
| **Databricks / Delta Lake** | Delta files ARE Parquet + `_delta_log/` JSON transaction log |
| **Redshift Spectrum** | Queries external Parquet files on S3 directly |
| **BigQuery** | Accepts Parquet for `LOAD DATA`; internal format is Capacitor (Parquet-inspired) |
| **Snowflake** | Accepts Parquet as external stage format; internal is custom columnar |
| **Athena / Presto** | Reads Parquet natively from S3 — columnar pushdown fully supported |

```sql
-- BigQuery: load Parquet from GCS
LOAD DATA INTO `project.dataset.orders`
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://my-bucket/orders/*.parquet']
);

-- Redshift Spectrum: query Parquet on S3
CREATE EXTERNAL TABLE spectrum.orders (
  order_id   BIGINT,
  customer_id INTEGER,
  amount     DECIMAL(10,2),
  order_date DATE
)
STORED AS PARQUET
LOCATION 's3://my-bucket/orders/';

SELECT order_date, SUM(amount)
FROM spectrum.orders
WHERE order_date = '2024-03-15'
GROUP BY order_date;
-- Spectrum pushes the date filter to the Parquet reader → only matching row groups read
```

---

## 10. Hands-On Labs

### Lab 1 — Write and Inspect (20 min)
```python
import pandas as pd
import pyarrow.parquet as pq
import numpy as np

# Generate sample data
df = pd.DataFrame({
    "order_id":    range(1, 100001),
    "customer_id": np.random.randint(1, 1000, 100000),
    "amount":      np.random.uniform(10, 500, 100000).round(2),
    "status":      np.random.choice(["SHIPPED","PENDING","DELIVERED","CANCELLED"], 100000),
    "order_date":  pd.date_range("2024-01-01", periods=100000, freq="1min").date
})

# Write with different codecs and compare file sizes
for codec in ["snappy", "gzip", "zstd", "brotli"]:
    df.to_parquet(f"orders_{codec}.parquet", compression=codec, index=False)

import os
for codec in ["snappy", "gzip", "zstd", "brotli"]:
    size = os.path.getsize(f"orders_{codec}.parquet") / 1024
    print(f"{codec:10s}: {size:.1f} KB")
```

### Lab 2 — Predicate Pushdown Measurement (20 min)
1. Write the DataFrame above partitioned by `order_date`
2. In PySpark, filter to a single date and run `.explain("formatted")`
3. Note `PartitionFilters` and `PushedFilters` in the output
4. Compare bytes read with and without the filter using Spark UI

### Lab 3 — Schema Evolution (20 min)
1. Write a Parquet file with 3 columns
2. Add a 4th column to new data, write a second file
3. Read both files with `mergeSchema=True` and verify the 4th column shows `null` for old rows
4. Try renaming a column — observe what happens

### Lab 4 — Column Pruning Impact (15 min)
1. Write a wide Parquet file (20 columns, 1M rows)
2. Time `pd.read_parquet("file.parquet")` vs `pd.read_parquet("file.parquet", columns=["col1","col2"])`
3. Record the difference in time and memory

---

## Summary

| Concept | Key Point |
|---------|-----------|
| Columnar storage | Only read the columns you need — 5-column query on 100-column table = 5% I/O |
| Row groups | Horizontal slices; min/max stats in footer enable entire row group skipping |
| Dictionary encoding | Replace repeated string values with integers = major size reduction |
| Compression | ZSTD for best ratio+speed; Snappy for lowest CPU; GZIP for archival |
| Schema evolution | Adding columns is safe; renaming breaks things |
| Predicate pushdown | Filter on sorted/ordered columns for maximum row group skipping |

---

*Next: [Module — Apache Avro](02-avro.md)*  
*Back to: [File Formats README](README.md)*

