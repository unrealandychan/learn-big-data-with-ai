# Data Warehouse Concepts: Fundamentals

## Learning Outcomes

By completing this module, you should be able to:
- Explain the difference between OLAP and OLTP systems with concrete examples
- Describe dimensional model architecture (facts, dimensions, grain)
- Compare star schema vs snowflake schema design patterns  
- Understand the ETL/ELT execution model and when to use each
- Identify when you need a data warehouse vs data lake vs lakehouse
- Design basic dimensional models for simple business scenarios

**Estimated Time:** 3 hours (2 hours reading + 1 hour labs)  
**Prerequisites:** None (this is the foundational module)

---

## 0. Why Do These Products Exist?

Before learning *how* each platform works, it's worth understanding *what real problem* drove someone to build them. The answer is always the same root cause, approached differently.

### The Universal Problem

Most companies store their operational data in **transactional databases** (MySQL, PostgreSQL, Oracle). These are fast at processing individual rows — inserting an order, updating an account balance. But they are *terrible* at analytics:

```sql
-- This query on a 500GB PostgreSQL production DB...
SELECT
    region,
    DATE_TRUNC('month', order_date) as month,
    SUM(revenue) as total_revenue
FROM orders
WHERE order_date >= '2020-01-01'
GROUP BY region, month
ORDER BY month, total_revenue DESC;

-- ...will likely take 45+ minutes and probably kill your production app.
```

A data warehouse solves exactly this — but the four platforms solve it in different ways, because each makes different assumptions about what matters most.

---

### What Each Platform Was Built to Solve

#### Snowflake — "Analytics shouldn't require a DBA or infrastructure team"
- **The problem:** Running analytics required expensive, hard-to-scale hardware. Scaling up for a big query meant expensive downtime. Teams were bottlenecked on infrastructure.
- **The solution:** Completely separate compute (query power) from storage (data). You spin up a virtual warehouse in seconds, run your query, then turn it off. You only pay for what you use.
- **The key insight:** The reason analytics was slow and expensive was that compute and storage were coupled. Decouple them, and you can scale each independently.

#### Databricks — "Data teams shouldn't need 5 separate tools"
- **The problem:** A typical data team used: a data lake (S3/GCS) for raw storage, a separate ETL tool, a separate data warehouse, a separate ML platform, and separate monitoring. Data moved between all of them — creating delays, duplication, and bugs.
- **The solution:** The **Lakehouse** — store data once (in Delta Lake format on cheap cloud storage), and get warehouse-quality ACID transactions, schema enforcement, and ML features *on top of that same data*.
- **The key insight:** Data lakes are cheap but unreliable. Data warehouses are reliable but expensive. The lakehouse gives you both in one place.

#### BigQuery — "What if analytics felt like a Google search?"
- **The problem:** Even cloud-based warehouses required you to provision a cluster, pick node types, manage scaling, and pay for idle time. This was a barrier to getting value quickly.
- **The solution:** Fully **serverless** — there is no cluster. Google manages all infrastructure. You write SQL, it executes across Google's massive infrastructure, and you pay only for the bytes your query scans.
- **The key insight:** The biggest bottleneck isn't compute — it's the time data teams spend on infrastructure. Remove infrastructure, and time-to-insight collapses from weeks to days.

#### Amazon Redshift — "Fast analytics on AWS, your way"
- **The problem:** Amazon AWS customers needed a warehouse tightly integrated with their existing AWS data (S3, Kinesis, Glue) with **predictable, high-throughput performance** for heavy SQL workloads.
- **The solution:** **MPP (Massively Parallel Processing)** — distribute both the data and the computation across many nodes. With careful design (distribution keys, sort keys), queries fan out in parallel and complete in seconds.
- **The key insight:** Performance at scale requires intentional data placement. Put rows that are frequently joined together on the same node, and joins become lightning fast.

---

### How Each Platform's Design Reflects Its Problem

```
Problem: Compute/storage are coupled → Snowflake separates them
Problem: Too many tools → Databricks unifies them
Problem: Infra is a bottleneck → BigQuery removes it
Problem: Joins are slow at scale → Redshift co-locates related data
```

This table summarizes the design philosophy at a glance:

| | Snowflake | Databricks | BigQuery | Redshift |
|---|---|---|---|---|
| **Core design choice** | Separate compute + storage | Unified lakehouse | Serverless compute | MPP distributed nodes |
| **Ops burden** | Low | Medium | Very low | Medium–high |
| **Best for SQL BI** | ✅ Excellent | ✅ Good | ✅ Excellent | ✅ Excellent |
| **Best for ML pipelines** | ⚠️ Limited | ✅ Excellent | ✅ Good (BQML) | ⚠️ Limited |
| **Best for data engineering** | ✅ Good | ✅ Excellent | ✅ Good | ✅ Good |
| **Tuning required** | Low | Medium | Low–medium | High |
| **Cloud-agnostic?** | Yes (multi-cloud) | Yes (multi-cloud) | No (GCP only) | No (AWS only) |
| **Pricing transparency** | Medium | Medium | High (per TB) | Low (node-based) |

Keep this framing in mind throughout the course. Every technical decision — Virtual Warehouses, Delta Lake, partitioning, distribution keys — traces back to the core problem each platform was designed to solve.

---

## 1. OLAP vs OLTP: Understanding the Workload Difference

### What is OLAP?

**OLAP** (OnLine Analytical Processing) systems are optimized for **reading and analyzing large volumes of historical data**.

**Characteristics:**
- **Query Pattern:** Few complex queries touching many rows
- **Data Volume:** Often billions of rows (GB → TB scale)
- **Update Pattern:** Bulk loads, historical data (write-once, read-many)
- **Latency:** Minutes to hours acceptable (not real-time)
- **Users:** Analysts, executives, data scientists (non-technical queries)
- **Goal:** Understand trends, patterns, and business insights

**Example Queries:**
```sql
-- Query 1: "What were sales trends by region over the last 3 years?"
SELECT 
    DATE_TRUNC('month', order_date) as month,
    r.region_name,
    SUM(f.sales_amount) as total_sales,
    COUNT(DISTINCT f.customer_id) as unique_customers
FROM fact_orders f
JOIN dim_customers c ON f.customer_id = c.customer_id
JOIN dim_regions r ON c.region_id = r.region_id
WHERE order_date >= '2021-01-01'
GROUP BY DATE_TRUNC('month', order_date), r.region_name
ORDER BY month, region_name;

-- Query 2: "Identify top 100 products by profit margin"
SELECT 
    p.product_name,
    SUM(f.quantity) as total_quantity,
    AVG(f.profit_margin_pct) as avg_margin,
    SUM(f.sales_amount) as total_sales
FROM fact_sales f
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING AVG(f.profit_margin_pct) > 0.15
ORDER BY avg_margin DESC
LIMIT 100;
```

### What is OLTP?

**OLTP** (OnLine Transaction Processing) systems are optimized for **fast, reliable insertion and updates of small amounts of data**.

**Characteristics:**
- **Query Pattern:** Many simple queries, typically affecting few rows
- **Data Volume:** Usually millions of rows (MB → GB scale)
- **Update Pattern:** Constant real-time inserts/updates
- **Latency:** Sub-second response required (real-time)
- **Users:** End applications, operational systems
- **Goal:** Support business transactions (orders, payments, inventory)

**Example Queries:**
```sql
-- Query 1: "Process a new customer order"
BEGIN TRANSACTION;
INSERT INTO orders (customer_id, order_date, total_amount) 
VALUES (12345, CURRENT_TIMESTAMP, 599.99);

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (LAST_INSERT_ID(), 456, 2, 299.99);

UPDATE inventory SET quantity_on_hand = quantity_on_hand - 2 
WHERE product_id = 456;

COMMIT;

-- Query 2: "Retrieve current account balance"
SELECT account_balance FROM customer_accounts 
WHERE customer_id = 12345;
```

### OLAP vs OLTP Comparison Table

| Factor | OLAP | OLTP |
|--------|------|------|
| **Purpose** | Analysis & reporting | Transactional processing |
| **Data Volume** | GB - TB | MB - GB |
| **Query Complexity** | Complex, multi-table joins | Simple, single table queries |
| **Latency Requirement** | Minutes - hours | < 1 second |
| **Write Pattern** | Bulk loads, append-only | Constant small inserts/updates |
| **Data Recency** | Historical (hours/days old OK) | Current (real-time) |
| **Users** | Analysts, executives, data scientists | Applications, end users |
| **Query Frequency** | Few queries, high resource use | Many queries, low resource use |
| **Schema** | Denormalized (star schema) | Normalized (3NF) |
| **Hardware Optimization** | Columnar storage, compression | Row-based, transaction log |
| **Examples** | Snowflake, Databricks, BigQuery, Redshift | PostgreSQL, Oracle, MySQL |

---

## 2. Dimensional Model Architecture

### The Three-Tier Warehouse Architecture

Modern data warehouses organize data into logical layers:

```
┌─────────────────────────────────────────┐
│    PRESENTATION LAYER                   │
│  (Dimensional Models for BI Tools)      │
│  • Fact tables                          │
│  • Dimension tables                     │
│  • Conformed dimensions                 │
└──────────────────────────────────────────┘
                    ↑
┌──────────────────────────────────────────┐
│    INTEGRATION LAYER                    │
│  (Consolidated Data - Platform Specific)│
│  • Cleaned, integrated data             │
│  • Business rules applied               │
│  • Slowly changing dimensions tracked   │
└──────────────────────────────────────────┘
                    ↑
┌──────────────────────────────────────────┐
│    STAGING LAYER                        │
│  (Raw Data - As Close to Source Copy)   │
│  • Raw extracts from systems            │
│  • Minimal transformation               │
│  • Retained for audit trail             │
└──────────────────────────────────────────┘
```

### What are Fact Tables?

**Fact tables** contain **measurable events** or **facts** about your business. They store the metrics you measure.

**Characteristics:**
- Many rows (one per transaction/event)
- Few columns (mostly keys and metrics)
- Grain: clearly defined level of detail
- Primarily numeric columns (amounts, counts, durations)
- Foreign keys linking to dimensions

**Example - Order Fact Table:**
```
ORDER_ID | DATE_ID | CUSTOMER_ID | PRODUCT_ID | STORE_ID | SALES_AMOUNT | QUANTITY | PROFIT_AMOUNT
---------|---------|-------------|------------|----------|--------------|----------|---------------
   1001  |   20250 |     5       |     123    |    2     |    299.99    |    1     |     89.99
   1002  |   20250 |     8       |     456    |    1     |    599.98    |    2     |    179.98
   1003  |   20251 |     5       |     789    |    3     |    149.99    |    1     |     44.99
```

**Key Point:** The DATE_ID, CUSTOMER_ID, PRODUCT_ID, STORE_ID are **foreign keys** that link to dimension tables. We'll see why below.

### What are Dimension Tables?

**Dimension tables** contain the **context** or **description** of events in fact tables. They store the "who, what, when, where, why" of your business.

**Characteristics:**
- Fewer rows (hundreds to millions)
- Many columns (text descriptions, attributes, hierarchies)
- For each key in fact table, there's a row in dimension table
- Usually less frequently updated than facts
- Often slowly changing (changes tracked over time)

**Example - Product Dimension Table:**
```
PRODUCT_ID | PRODUCT_NAME          | BRAND      | CATEGORY      | SUBCATEGORY      | COLOR   | SIZE
-----------|----------------------|------------|---------------|------------------|---------|-------
   123     | Athletic Running Shoe | Nike       | Sports        | Footwear         | Black   | 10
   456     | Casual T-Shirt        | Polo       | Apparel       | Shirts           | Blue    | L
   789     | Wool Coat             | Burberry   | Apparel       | Outerwear        | Tan     | M
```

**Example - Store Dimension Table:**
```
STORE_ID | STORE_NAME      | CITY         | STATE | REGION     | STORE_TYPE | MANAGER_NAME
---------|-----------------|--------------|-------|------------|------------|---------------
    1    | Downtown Store  | New York     | NY    | Northeast  | Flagship   | John Smith
    2    | Mall Location   | Boston       | MA    | Northeast  | Standard   | Sarah Jones
    3    | Outlet          | Las Vegas    | NV    | Southwest  | Outlet     | Mike Chen
```

### Understanding Grain

**Grain** = the level of detail in a fact table = **exactly what one row represents**.

For the Order Fact Table above, the grain is: **"One row per line item (product) in one order"**

Importance of clear grain:
- Ensures correct aggregations
- Prevents double-counting
- Enables proper joins
- Clarifies what each metric means

**Example Invalid Grain Definition:** ❌ "One row per order"
- Why invalid? An order can have 5 line items. Which product do you store?

**Example Valid Grain Definition:** ✅ "One row per line item in an order"
- Why valid? Clear: 1 row = 1 product purchased in 1 order

---

## 3. Schema Design Patterns

### Star Schema (Recommended)

The **star schema** is the most common data warehouse design. Named because the diagram looks like a star:

```
                    ┌─────────────────┐
                    │  DIM_PRODUCTS   │
                    │─────────────────│
                    │ Product_ID (PK) │
                    │ Product_Name    │
                    │ Category        │
                    │ Price           │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────┴────────┐  ┌────────┴────────┐  ┌──────┴──────────┐
│  DIM_CUSTOMER  │  │  FACT_ORDERS    │  │   DIM_STORE     │
│────────────────│  │─────────────────│  │──────────────────│
│ Customer_ID(PK)├──→ Customer_ID(FK) │  │ Store_ID(PK)    │
│ Name           │  │ Date_ID(FK)    ├──→Product_ID(FK)   │
│ Segment        │  │ Product_ID(FK)  │  │ Store_Name      │
└────────────────┘  │ Store_ID(FK)    │  │ City            │
                    │ Sales_Amount    │  │ Region          │
        ┌───────────┤ Quantity        │  └──────────────────┘
        │           │ Profit_Amount   │
        │           └─────────────────┘
        │
┌───────┴──────────┐
│   DIM_DATE       │
│──────────────────│
│ Date_ID (PK)     │
│ Calendar_Date    │
│ Month            │
│ Quarter          │
│ Year             │
└──────────────────┘
```

**Advantages:**
- Simple: easy to understand and query
- Fast: few joins needed for most queries
- Optimized: designed specifically for analysis
- Best for typical BI workloads

**Disadvantages:**
- Requires denormalization (data redundancy)
- Updates to dimensions affect space

**When to use:** 95% of analytical use cases!

### Snowflake Schema

The **snowflake schema** further normalizes dimensions into related tables.

```
                    ┌──────────────────┐
                    │  DIM_CATEGORY    │
                    │──────────────────│
                    │ Category_ID (PK) │
                    │ Category_Name    │
                    └────────┬─────────┘
                             │
                    ┌────────┴──────────┐
                    │  DIM_SUBCATEGORY  │
                    │────────────────────│
                    │ Sub_Category_ID(PK)│
                    │ Category_ID(FK)   │
                    │ Sub_Category_Name │
                    └────────┬──────────┘
                             │
┌────────────────────────────┼────────────────────────────┐
│                            │                           │
│                   ┌────────┴────────┐                  │
│                   │  DIM_PRODUCTS   │                  │
│                   │─────────────────│                  │
│                   │ Product_ID (PK) │                  │
│                   │ Sub_Ctgy_ID(FK) │                  │
│                   │ Product_Name    │                  │
│                   │ Price           │                  │
│                   └────────┬────────┘                  │
│                            │                          │
│        ┌───────────────────┼──────────────────┐       │
│        │                   │                  │       │
│ ┌──────┴─────────┐ ┌──────┴────────┐ ┌──────┴─────┐ │
│ │DIM_CUSTOMER    │ │ FACT_ORDERS   │ │ DIM_STORE  │ │
│ │────────────────│ │───────────────│ │────────────│ │
│ │Customer_ID(PK) │ │Customer_ID(FK)│ │Store_ID(PK)│ │
└─→Name            │ │Date_ID(FK)    │ │Store_Name  │ │
  │Segment         │ │Product_ID(FK) │ │City        │ │
  └────────────────┘ │Store_ID(FK)   │ │Region      │ │
                     │Sales_Amount   │ │────────────│ │
                     │Quantity       │ └────────────┘ │
                     │Profit_Amount  │                │
                     └───────────────┘                │
                                                     │
                     ┌──────────────┐                 │
                     │  DIM_DATE    │                 │
                     │──────────────│                 │
                     │Date_ID (PK)  │                 │
                     │Calendar_Date │                 │
                     │Month/Quarter │                 │
                     │Year          │                 │
                     └──────────────┘                 │
```

**Advantages:**
- Less data redundancy (more normalized)
- SQL is similar (just more joins)
- Dimension changes easier to manage

**Disadvantages:**
- More complex queries (more joins = slower)
- Dimension attributes spread across tables
- Harder to understand

**When to use:** When dimension data is very large or frequently updated. Otherwise use Star Schema!

### Star vs Snowflake Comparison

| Aspect | Star Schema | Snowflake Schema |
|--------|-------------|------------------|
| **Normalization** | Denormalized dimensions | Normalized hierarchy |
| **Dimension Tables** | One table per dimension | Multiple related tables |
| **Query Joins** | Few (simple) | More (complex) |
| **Query Performance** | Faster (fewer joins) | Slower (more joins) |
| **Storage** | More (redundancy) | Less (normalized) |
| **Maintainability** | Easy to understand | More complex |
| **Typical Use** | Business BI | Complex hierarchies |
| **Recommendation** | Use this 90% of the time | Special cases only |

---

## 4. ETL vs ELT Paradigm

### Extract-Transform-Load (ETL)

TL;DR: Get data → Clean/Transform it → Load to warehouse

**Traditional approach (10 years old but still common):**

```
SOURCE SYSTEMS → ETL SERVER → DATA WAREHOUSE
    ↓               ↓                ↓
   Data      Transform &     Clean, modeled
   (raw)     aggregate       analytics data
```

**Steps:**
1. **Extract:** Pull data from source system (database, API, file)
2. **Transform:** Clean, validate, aggregate using ETL tool:
   - Convert data types
   - Handle nulls and duplicates
   - Aggregate and denormalize
   - Implement business logic
   - Join with reference tables
3. **Load:** Insert organized data into data warehouse

**Tools:** Informatica, Talend, SSIS, custom scripts

**Example ETL Process:**
```
RAW CUSTOMER DATA (CSV):
customer_id, name, birth_date, address
1001, John Smith, 1990-05-15, 123 Main St
1002, Jane Doe, 1985-03-22, 456 Oak Ave

↓ (TRANSFORM)

Validate dates, format phone, remove duplicates, 
look up state from address, create age group, 
aggregate into yearly customer value

↓

WAREHOUSE TABLE:
customer_id_sk, customer_name, birth_year, state, value_segment, load_date
1, John Smith, 1990, NY, High Value, 2025-03-27
2, Jane Doe, 1985, CA, Medium Value, 2025-03-27
```

**Advantages:**
- Data validated before loading (quality control)
- Can handle complex transformations
- Good for legacy systems without SQL

**Disadvantages:**
- Slower (extra transformation step)
- Requires special tools (cost)
- Less flexible (schema defined upfront)

---

### Extract-Load-Transform (ELT)

**Modern approach (last 5 years):**

```
SOURCE SYSTEMS → DATA WAREHOUSE → SQL TRANSFORMS
    ↓                  ↓                ↓
   Data           Raw data         Clean modeled
   (raw)          staging          analytics data
```

**Steps:**
1. **Extract:** Pull data from source as-is (no transformation)
2. **Load:** Dump raw data into warehouse staging layer quickly
3. **Transform:** Use warehouse's SQL to clean and organize

**Tools:** dbt, SQL in warehouse, Apache Spark

**Same Example with ELT:**
```
RAW CUSTOMER DATA (CSV):
customer_id, name, birth_date, address
1001, John Smith, 1990-05-15, 123 Main St
1002, Jane Doe, 1985-03-22, 456 Oak Ave

↓ (LOAD AS-IS)

STAGING TABLE (raw copy):
customer_id, name, birth_date, address, load_date
1001, John Smith, 1990-05-15, 123 Main St, 2025-03-27
1002, Jane Doe, 1985-03-22, 456 Oak Ave, 2025-03-27

↓ (TRANSFORM in SQL/dbt)

CREATE TABLE dim_customer AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY customer_id) as customer_id_sk,
    TRIM(name) as customer_name,
    YEAR(birth_date) as birth_year,
    state,
    CASE WHEN annual_sales > 10000 THEN 'High Value'
         WHEN annual_sales > 1000 THEN 'Medium Value'
         ELSE 'Low Value' END as value_segment,
    CURRENT_DATE as load_date
FROM stg_customer_raw

↓

WAREHOUSE TABLE (same result as ETL):
customer_id_sk, customer_name, birth_year, state, value_segment, load_date
1, John Smith, 1990, NY, High Value, 2025-03-27
2, Jane Doe, 1985, CA, Medium Value, 2025-03-27
```

**Advantages:**
- Faster (transformations run in warehouse)
- Cheaper (no external tools needed)
- More flexible (transform logic in SQL/code)
- Better for cloud data warehouses

**Disadvantages:**
- Raw data validation happens later
- Can use more warehouse compute
- Requires strong SQL skills

---

### ETL vs ELT: When to Use Which?

| Factor | ETL | ELT |
|--------|-----|-----|
| **Speed** | Slower | Faster |
| **Cost** | Higher (tools needed) | Lower |
| **Flexibility** | Less | More |
| **Data Quality** | Checked early | Checked later |
| **Cloud Native** | No | Yes |
| **Best For** | Legacy systems | Modern cloud warehouses |
| **Current Trend** | 📉 Declining | 📈 Growing |

**Recommendation:** Use **ELT** for modern cloud data warehouses (Snowflake, Databricks, BigQuery, Redshift). Use **ETL** only if forced by legacy system constraints or extremely complex transformation logic.

---

## 5. Data Warehouse vs Data Lake vs Lakehouse

### Data Warehouse (Traditional)

**Purpose:** Optimized for fast, reliable analytics on organized data

**Characteristics:**
- Structured, modeled data (schema enforced)
- Organized directory (tables, schemas)
- High data quality and governance
- Fast queries on known data
- SQL-first interface

**Timeline:** 1990s - present

**Best For:**
- BI and reporting
- Executive dashboards
- Known queries
- Structured business data

**Cost:** Moderate to high

---

### Data Lake (Modern but messy)

**Purpose:** Store vast amounts of raw data in its original format

**Characteristics:**
- All data types (structured, semi-structured, unstructured)
- Minimal enforcement of structure
- "Write first, question later" mentality
- Low upfront cost
- Flexible exploration

**Timeline:** 2010s - early adoption

**Best For:**
- Exploratory analysis
- Machine learning (raw data)
- Compliance archival
- Data science flexibility

**Cost:** Low (cheap storage)

**Problem:** Data lakes often become "data swamps" (like a literal swamp - you can't find anything!):
- No metadata
- Unknown data quality
- Difficult governance
- Slow analysis on messy data

---

### Lakehouse (Best of both worlds)

**Purpose:** Combine data lake storage cost with warehouse features

**Characteristics:**
- Raw data stored in cost-effective object storage
- Metadata layer enforces structure (Delta Lake, Apache Iceberg)
- ACID transactions and data quality
- SQL interface with warehouse features
- Combines flexibility and reliability

**Timeline:** 2020s - Modern approach

**Architecture:**
```
Physical Path: 
Raw CSV/JSON/Parquet files in S3 → Metadata layer provides schema → SQL query interface

Result: Looks like warehouse to users, costs like lake underneath!
```

**Example (Databricks):**
```
Files in S3: data/customers/2025-03-27.parquet
           data/customers/2025-03-28.parquet
           ...

Delta Lake Metadata: Tracks which files belong to "customers" table, schema, ACID guarantees

User Query: SELECT * FROM customers (just like warehouse!)

Result: Fast, reliable, cost-effective
```

**Best For:**
- Most modern workloads
- ML + analytics mix
- Cost without sacrificing quality
- Flexibility with reliability

**Cost:** Low-moderate (cheap storage + warehouse features)

---

### Comparison Table

| Aspect | Data Lake | Data Warehouse | Lakehouse |
|--------|-----------|-----------------|-----------|
| **Storage** | Raw files | Organized tables | Raw files + metadata |
| **Schema** | None (schema-on-read) | Enforced | Enforced via metadata |
| **Data Quality** | Low (no validation) | High (validated) | High |
| **Governance** | Weak | Strong | Strong |
| **SQL Query Speed** | Slow (raw data) | Fast (optimized) | Fast |
| **Cost** | Very low | Moderate-High | Low |
| **Flexibility** | Very high | Lower | High |
| **ML Readiness** | High (raw data) | Lower (cleaned) | High |
| **Maturity** | Newer | Established | Newest |
| **Recommendation** | Data science only | Traditional BI | ✅ Use this! |

---

## Hands-On Labs

### Lab 1: Identify OLAP vs OLTP (30 minutes)

**Scenario:** You receive these queries from different teams

**Query A:**  
```sql
SELECT customer_id, current_order_status, current_balance 
FROM customer_account 
WHERE account_id = '12345678';
```

**Query B:**  
```sql
SELECT 
    DATE_TRUNC('month', order_date),
    product_category,
    SUM(sales_amount) as monthly_sales,
    COUNT(DISTINCT customer_id) as unique_customers
FROM fact_orders
WHERE order_date >= '2023-01-01'
GROUP BY DATE_TRUNC('month', order_date), product_category;
```

**Your Task:**
1. Which query is OLAP? Which is OLTP? How do you know?
2. What system should run each query? Why?

**Answer Key:**
- Query A = OLTP (looks up one account, needs real-time response)
- Query B = OLAP (aggregates across 2+ years, rolling up by month and category)

---

### Lab 2: Design a Basic Star Schema (45 minutes)

**Scenario:** You're designing a data warehouse for a movie theater chain.

**Business Events to Measure:**
- Ticket sales (date, customer, movie, theater, price paid, seat location)
- Concessions sales (date, customer, theater, item, quantity, price)
- Movie inventory (changes to available showings)

**Your Task:**
1. Identify at least 3 fact tables (what rows do they have?)
2. Identify 4-5 dimension tables (what attributes describe each fact?)
3. Draw a simple star schema (by describing which tables connect)
4. Define the grain for each fact table clearly

**Answer Key Example:**

**Fact Tables:**
1. `fact_ticket_sales`: One row per ticket sold (grain: "one row per movie ticket sold")
2. `fact_concessions_sales`: One row per item sold (grain: "one row per concession sold")
3. `fact_movie_showings`: One row per showing per day (grain: "one row per distinct movie showing")

**Dimension Tables:**
1. `dim_date`: Date attributes
2. `dim_movies`: Movie information
3. `dim_theaters`: Theater location and capacity
4. `dim_customers`: Customer demographics
5. `dim_concessions`: Snack items and categories

**Grain Examples:**
- `fact_ticket_sales`: "One row per ticket sold (includes seat number, customer, movie, showtime)"
- `fact_concessions_sales`: "One row per concession item sold (one row if customer buys 1 popcorn, different row if they buy drink too)"

---

## Summary

✅ **OLAP** = Many complex queries on historical data (data warehouse)  
✅ **OLTP** = Few fast queries on current data (transactional systems)  
✅ **Fact Tables** = What happened (measurements, events)  
✅ **Dimension Tables** = Context (who, what, when, where, why)  
✅ **Grain** = Exactly what one row represents  
✅ **Star Schema** = 1 fact table surrounded by dimensions (use this!)  
✅ **Snowflake Schema** = Normalized hierarchies (rare)  
✅ **ETL** = Old way (transform then load)  
✅ **ELT** = New way (load then transform in warehouse)  
✅ **Lakehouse** = Modern best practice (reliability + cost)  

---

## Next Steps

- 👉 **Next Module:** [SQL for Warehouses](./02-sql-for-warehouses.md)
  - Learn the SQL patterns that power warehouse queries
  - Master window functions and CTEs
  - Write real analytical queries

- 📖 **Further Reading:**
  - Ralph Kimball's "The Data Warehouse Toolkit" (Chapter 1)
  - "Fundamentals of Data Warehouse" by Reeves & Thornton

---

*Last Updated: March 2026*
