# Complete Learning Curriculum

## Overview

This document provides a detailed breakdown of the entire 26-week course with specific learning outcomes, time estimates, prerequisites, and recommended sequencing.

**Total Time Investment:** 110-162 hours (3-5 hours per week for 34 weeks, including Apache Stack)

---

## LEVEL 1-2: FUNDAMENTALS (Weeks 1-8)

### Module 1: Data Warehouse Concepts
**File:** [`fundamentals/01-data-warehouse-concepts.md`](./fundamentals/01-data-warehouse-concepts.md)  
**Duration:** 3 hours (2 hours reading + 1 hour labs)  
**Prerequisites:** None

**Learning Outcomes:**
- Distinguish OLAP vs OLTP workloads with real examples
- Explain dimensional model architecture (facts, dimensions, grain)
- Compare star schema vs snowflake schema design patterns
- Understand ETL/ELT execution models
- Identify when to use data warehouse vs data lake vs lakehouse

**Topics Covered:**
- Transaction Processing (OLTP) vs Analytical Processing (OLAP)
- Data warehouse organizational layers (staging, integration, presentation)
- Fact tables and grain definition
- Dimension tables and attributes
- Conformed dimensions vs local dimensions
- Schema design patterns (star, snowflake, normalized)
- ETL process flows
- ELT paradigm and its advantages
- Real-world examples across retail, healthcare, finance domains

**Hands-On Labs:**
1. Identify OLTP vs OLAP characteristics in sample business scenarios
2. Design basic star schema for a given business problem
3. Define grain for different fact table scenarios
4. Compare dimension designs for SCD handling

**Knowledge Check:**
- 10 multiple-choice questions
- 3 short-answer design problems
- Solution key provided

**Prerequisites for Next Module:** None

---

### Module 2: SQL for Warehouses
**File:** [`fundamentals/02-sql-for-warehouses.md`](./fundamentals/02-sql-for-warehouses.md)  
**Duration:** 4 hours (2 hours reading + 2 hours labs)  
**Prerequisites:** Module 1

**Learning Outcomes:**
- Write efficient analytical SQL queries using advanced constructs
- Optimize joins for large dimensional tables
- Use window functions for ranking and time-series analysis
- Construct CTEs for readable and modular queries
- Understand query execution basics and common bottlenecks

**Topics Covered:**
- SELECT foundations and WHERE filtering
- INNER, LEFT, RIGHT, FULL joins in warehouse context
- Join optimization strategies (broadcast vs shuffle)
- GROUP BY and HAVING with aggregations
- Window functions (ROW_NUMBER, RANK, LAG, LEAD, SUM OVER, AVG OVER)
- Common Table Expressions (WITH clauses)
- Recursive CTEs
- Set operations (UNION, INTERSECT, EXCEPT)
- Subqueries vs CTEs
- Query execution basics
- Identifying slow queries

**Hands-On Labs:**
1. Write 5 analytical queries of increasing complexity (sample dataset provided)
2. Optimize a given slow query using joins and partitioning
3. Implement a window function solution for ranking/running totals
4. Build multi-level CTE solution for hierarchical analysis
5. Compare query plans for different JOIN approaches

**Code Examples:** 25+ real SQL queries with explanations

**Knowledge Check:**
- 15 SQL-writing exercises (with solutions)
- Query optimization challenge
- Performance comparison analysis

**Prerequisites for Next Module:** Comfortable with SELECT, JOIN, GROUP BY

---

### Module 3: Dimensional Modeling
**File:** [`fundamentals/03-dimensional-modeling.md`](./fundamentals/03-dimensional-modeling.md)  
**Duration:** 5 hours (2.5 hours reading + 2.5 hours design labs)  
**Prerequisites:** Modules 1-2

**Learning Outcomes:**
- Design star schemas following Kimball methodology
- Implement Slowly Changing Dimensions (SCD Types 1, 2, 3, Hybrid)
- Create conformed dimensions for enterprise data warehouses
- Design appropriate role-playing dimensions
- Build fact table specifications with proper grain

**Topics Covered:**
- Kimball dimensional modeling methodology
- Star schema architecture and benefits
- Fact table types:
  - Transactional (one row per transaction)
  - Periodic snapshot (one row per dimension combination per period)
  - Accumulating snapshot (updates over transaction lifecycle)
- Dimension table design:
  - Natural vs surrogate keys
  - Dimension attributes and hierarchies
  - Junk dimensions
  - Bridge tables for many-to-many relationships
- Slowly Changing Dimensions (SCD):
  - Type 0: No change
  - Type 1: Overwrite
  - Type 2: Add new row with effective dates
  - Type 3: Add new attribute columns
  - Type 4: Separate history table
  - Hybrid approaches combining multiple types
- Conformed dimensions (shared across multiple subject areas)
- Role-playing dimensions (single dimension used multiple times)
- Degenerate dimensions (transaction attributes)
- Bus Matrix for enterprise architecture
- Data mart planning

**Hands-On Design Labs:**
1. **Retail Analytics:** Design star schema for order, returns, and inventory analysis
   - Identify fact tables and grain
   - Design 6+ dimensions with SCD approach
   - Handle product hierarchies (category → subcategory → product)

2. **Healthcare Analytics:** Design star schema for patient encounters
   - Multiple fact tables (admissions, procedures, medications)
   - Handling patient dimension SCD Type 2 changes
   - Role-playing dimensions for provider hierarchies

3. **Financial Analytics:** Design star schema for transaction analysis
   - Account dimension with SCD Type 2 for status changes
   - Time dimensions with fiscal calendar
   - GL account hierarchies

4. **Bus Matrix Design:** Enterprise warehouse for multi-subject area

**Deliverables:**
- 3 complete dimensional models (ER diagrams or descriptive specs)
- Grain statements for each fact table
- SCD specifications for each dimension
- Sample ETL logic for SCD implementation

**Knowledge Check:**
- Design review questions (peer or self-review)
- Identify design issues in provided schema
- Compare normalization vs dimension design

**Prerequisites for Next Module:** All previous modules

---

### Module 4: Hands-On Setup & First Queries
**File:** [`fundamentals/04-hands-on-setup.md`](./fundamentals/04-hands-on-setup.md)  
**Duration:** 2 hours (1 hour setup + 1 hour labs)  
**Prerequisites:** Modules 1-3

**Learning Outcomes:**
- Successfully create accounts on all 4 cloud warehouses
- Load sample datasets (TPC-H)
- Execute first analytical queries on each platform
- Compare ease of use and initial observations
- Set up cost tracking and alerts

**Topics Covered:**
- Snowflake account creation and configuration
- Databricks workspace setup
- BigQuery project and dataset creation
- Redshift cluster provisioning
- Loading sample data:
  - TPC-H 100GB benchmark dataset setup
  - Public datasets on each platform
  - CSV/Parquet loading examples
- Running first queries:
  - "Hello World" queries
  - Simple aggregations
  - Join queries across tables
- Cost monitoring:
  - Credit tracking (Snowflake)
  - Compute cost tracking (Databricks)
  - Query pricing (BigQuery)
  - Node costs (Redshift)
- Common setup pitfalls and solutions

**Hands-On Activities:**
1. Create account on each platform (30 minutes)
2. Load TPC-H CUSTOMER table (10 minutes per platform)
3. Execute 5 standard queries on each platform
4. Compare results and query execution time
5. Set up cost alerts/budgets

**Deliverables:**
- All 4 accounts successfully created
- Sample data loaded
- 5 queries executed and documented
- Setup costs documented

**Troubleshooting Guide:** Common issues and solutions

**Prerequisites for Next Module:** Successfully completed setup on at least 2 platforms

---

## LEVEL 3: PLATFORM-SPECIFIC DEEP DIVES (Weeks 9-14)

### Snowflake (5 modules, ~40 hours total)

#### Module 3.1: Snowflake Architecture
**File:** [`snowflake/01-architecture.md`](./snowflake/01-architecture.md)  
**Duration:** 6 hours  
**Prerequisites:** Fundamentals 1-4

**Learning Outcomes:**
- Explain Snowflake's compute/storage separation architecture
- Understand warehouse scaling and sizing decisions
- Compare Snowflake editions and deployment options
- Leverage Time Travel and Zero-Copy Clone features
- Evaluate Snowflake's unique architecture vs competitors

**Topics Covered:**
- Cloud infrastructure (multi-cluster shared data architecture)
- Compute layer (virtual warehouses, scaling)
- Storage layer (S3-based, data compaction)
- Metadata management and query optimization
- Warehouse sizing and performance impact
- Dynamic scaling and auto-suspend settings
- Snowflake editions (Standard, Business Critical, Enterprise)
- Deployment options (Single region, Multi-region, Federated)
- Time Travel functionality and use cases
- Zero-Copy Clone for testing and recovery
- Data sharing and secure data exchange
- Query result caching

**Hands-On Labs:**
1. Create warehouses of different sizes and benchmark performance
2. Compare costs between X-Large and Large warehouses on identical workload
3. Test Time Travel: rollback accidental deletions
4. Create clones of tables and schemas for testing
5. Implement and test query result caching

**Code Examples:** 20+ Snowflake SQL examples

**Prerequisites for Next Module:** Fundamentals 1-4, working Snowflake account

---

#### Module 3.2: Data Loading in Snowflake
**File:** [`snowflake/02-data-loading.md`](./snowflake/02-data-loading.md)  
**Duration:** 6 hours  
**Prerequisites:** Snowflake 01-architecture

**Learning Outcomes:**
- Load structured data (CSV, Parquet, JSON) into Snowflake
- Implement continuous data loading with Snowpipe
- Handle data transformations during loading
- Use COPY command with various options
- Design sustainable data loading patterns

**Topics Covered:**
- COPY command fundamentals and options
- File staging (internal vs external stages)
- Snowpipe for continuous ingestion
- Data transformations with COPY (SELECT transformation)
- Handling semi-structured data (VARIANT type)
- Compression and encryption options
- Performance tuning for bulk loads
- Error handling and validation
- Incremental loading strategies
- MERGE for upserts

**Hands-On Labs:**
1. Load sample dataset (1GB CSV) using COPY command
2. Set up Snowpipe to continuously load S3 objects
3. Transform data during load (type conversion, filtering)
4. Load semi-structured JSON data into VARIANT column
5. Implement MERGE logic for incremental updates

**Code Examples:** COPY, Snowpipe configuration, transformation logic

**Prerequisites for Next Module:** Snowflake 01-architecture

---

#### Module 3.3: Querying and Optimization in Snowflake
**File:** [`snowflake/03-querying-optimization.md`](./snowflake/03-querying-optimization.md)  
**Duration:** 8 hours  
**Prerequisites:** Snowflake 02-data-loading

**Learning Outcomes:**
- Write optimized SQL queries for Snowflake
- Use clustering keys for query performance
- Interpret Snowflake query execution plans
- Implement query result caching
- Design statistics and metadata optimization

**Topics Covered:**
- Snowflake query execution overview
- Query plans and understanding bottlenecks
- Clustering keys and clustering depth
- Designing for optimal pruning
- Statistics and data profiles
- Query result caching strategies
- Materialized views for pre-aggregation
- Searching with search optimization
- Common table optimization patterns
- Cost optimization techniques

**Hands-On Labs:**
1. Create clustering keys for common filters and measure impact
2. Read 10 query plans and identify optimization opportunities
3. Benchmark: unoptimized query vs optimized with clustering
4. Implement search optimization for multi-column searches
5. Design materialized view for common aggregation
6. Calculate cost savings from optimization

**Query Examples:** 15+ optimization examples

**Performance Benchmarks:** Before/after metrics

**Prerequisites for Next Module:** Snowflake 02-data-loading

---

#### Module 3.4: Semi-Structured Data in Snowflake
**File:** [`snowflake/04-semi-structured-data.md`](./snowflake/04-semi-structured-data.md)  
**Duration:** 6 hours  
**Prerequisites:** Snowflake 03-querying-optimization

**Learning Outcomes:**
- Work with Snowflake's VARIANT data type
- Query JSON and Parquet data
- Parse semi-structured data in SQL
- Design schemas for JSON data
- Handle nested and recursive structures

**Topics Covered:**
- VARIANT data type fundamentals
- JSON loading and storage
- JSON parsing with dot notation
- JSON functions (JSON_EXTRACT, JSON_EXTRACT_ARRAY, etc.)
- Flattening nested JSON structures
- Parquet file handling
- Avro and ORC support
- Schema inference
- Performance considerations for semi-structured data
- Converting semi-structured to structured formats

**Hands-On Labs:**
1. Load nested JSON API responses into VARIANT
2. Parse multi-level JSON structure with dot notation
3. Flatten JSON arrays into tabular format
4. Compare query performance: JSON parsing vs pre-flattened
5. Build transformation logic to structure raw JSON
6. Query Parquet files directly from S3

**Code Examples:** 20+ JSON/semi-structured queries

**Sample Datasets:** API responses, log data, web events

**Prerequisites for Next Module:** Snowflake 03-querying-optimization

---

#### Module 3.5: Snowflake Hands-On Labs & Capstone
**File:** [`snowflake/05-hands-on-labs.md`](./snowflake/05-hands-on-labs.md)  
**Duration:** 8 hours  
**Prerequisites:** Snowflake 01-04

**Learning Outcomes:**
- Integrate all Snowflake concepts in realistic scenario
- Build end-to-end data pipeline in Snowflake
- Perform data analysis and optimization
- Compare Snowflake performance with other platforms

**Labs:**
1. **End-to-End Lab (3 hours):** Load retail dataset → dimensional model → analysis
   - Load 5 tables from CSV
   - Create star schema with 1 fact table, 4 dimensions
   - Implement SCD Type 2 for product dimension
   - Run 10 analytical queries
   - Measure performance and costs

2. **Performance Tuning Lab (2 hours):**
   - Receive 10 slow queries
   - Optimize using clustering, caching, query rewriting
   - Document before/after metrics
   - Present optimization strategy

3. **Semi-Structured Data Lab (2 hours):**
   - Load JSON event data and Parquet files
   - Parse and flatten structure
   - Create conformed analytics schema from raw data

4. **Comparative Benchmark (1 hour):**
   - Run TPC-H queries on Snowflake
   - Record time and cost
   - Compare with baseline

**Deliverables:**
- Complete star schema model
- 10 optimized queries with execution times
- Cost analysis and optimization recommendations
- Benchmark results document

---

### Databricks (5 modules, ~40 hours total)

#### Module 3.6: Databricks Lakehouse Architecture
**File:** [`databricks/01-architecture.md`](./databricks/01-architecture.md)  
**Duration:** 6 hours  
**Prerequisites:** Fundamentals 1-4

**Learning Outcomes:**
- Understand lakehouse architecture and benefits
- Explain Delta Lake format and ACID transactions
- Design data organization with Delta Lake
- Leverage unity catalog for governance
- Compare lakehouse vs traditional warehouse vs data lake

**Topics Covered:**
- Data lake limitations and lakehouse benefits
- Delta Lake format specifications
- ACID transactions in Delta Lake
- Multiversion concurrency control (MVCC)
- Time travel in Delta Lake
- Spark SQL and distributed computing basics
- Databricks workspace architecture
- Cluster types and sizing
- Jobs and workflows
- Unity Catalog for data governance
- Data lineage and impact analysis
- Compute optimization and caching

**Hands-On Labs:**
1. Create Delta table and verify ACID properties
2. Write 2 concurrent transactions and verify consistency
3. Use Time Travel to access previous versions
4. Compare Delta Lake performance vs Parquet formats
5. Set up Unity Catalog and test access control

**Code Examples:** Delta Lake SQL and Spark SQL examples

**Prerequisites for Next Module:** Fundamentals 1-4, Databricks account

---

#### Module 3.7: Data Loading and Delta Lake Operations
**File:** [`databricks/02-data-loading.md`](./databricks/02-data-loading.md)  
**Duration:** 6 hours  
**Prerequisites:** Databricks 01-architecture

**Learning Outcomes:**
- Load data into Delta Lake tables
- Implement MERGE operations for upserts
- Handle Change Data Capture (CDC) patterns
- Optimize incremental loads
- Design idempotent data loading pipelines

**Topics Covered:**
- Creating Delta tables from various sources
- COPY INTO command
- Streaming writes to Delta Lake
- MERGE operation (INSERT, UPDATE, DELETE in one statement)
- Change Data Capture patterns (CDC logs, staging tables)
- Auto Loader for schema inference
- Constraint enforcement (NOT NULL, CHECK)
- Generated columns
- Schema evolution and handling
- Incremental loading best practices

**Hands-On Labs:**
1. Load CSV, Parquet, JSON data into Delta tables
2. Implement MERGE for customer dimension SCD Type 2
3. Build CDC pipeline: capture changes and apply to target
4. Use Auto Loader with schema inference
5. Implement incremental load detecting new files
6. Handle schema changes and evolution

**Code Examples:** MERGE, CDC patterns, incremental loads

**Architecture Diagrams:** CDC patterns and data flow

**Prerequisites for Next Module:** Databricks 01-architecture

---

#### Module 3.8: Querying, Optimization, and Spark SQL
**File:** [`databricks/03-querying-optimization.md`](./databricks/03-querying-optimization.md)  
**Duration:** 8 hours  
**Prerequisites:** Databricks 02-data-loading

**Learning Outcomes:**
- Write optimized Spark SQL queries
- Understand distributed query execution
- Use Z-order clustering for performance
- Optimize Spark job execution
- Implement query optimization patterns

**Topics Covered:**
- Spark SQL fundamentals
- Distributed query execution and Spark tasks
- Partition pruning and predicate pushdown
- Broadcast joins vs shuffle joins
- Z-order indexing for multi-column pruning
- Adaptive Query Execution (AQE)
- Data skew handling
- Caching and persistence strategies
- Spark UI for performance analysis
- Common optimization patterns
- Query cost estimation and monitoring

**Hands-On Labs:**
1. Write Spark SQL queries exploring different JOIN approaches
2. Apply Z-order clustering and measure improvement
3. Identify data skew in sample dataset and optimize
4. Use Spark UI to analyze query execution
5. Cache intermediate results and measure performance gains
6. Implement broadcast join optimization

**Code Examples:** 20+ Spark SQL optimization examples

**Spark UI Analysis:** Real execution plans and bottlenecks

**Prerequisites for Next Module:** Databricks 02-data-loading

---

#### Module 3.9: Machine Learning and Advanced Features
**File:** [`databricks/04-ml-integration.md`](./databricks/04-ml-integration.md)  
**Duration:** 6 hours  
**Prerequisites:** Databricks 03-querying-optimization

**Learning Outcomes:**
- Integrate ML workflows with Databricks
- Use MLflow for experiment tracking
- Build feature stores for ML
- Write feature engineering queries
- Deploy and serve ML models

**Topics Covered:**
- MLflow for experiment tracking
- Model registry and versioning
- Feature store fundamentals
- Feature engineering in SQL
- ML pipelines in Databricks
- Model serving options
- Monitoring and retraining patterns
- Integration with popular ML frameworks
- Model governance and lineage

**Hands-On Labs:**
1. Track ML experiment with MLflow
2. Build feature store for retail prediction
3. Engineer features using Spark SQL
4. Register and version model in MLflow
5. Compare model versions and select best

**Code Examples:** MLflow, feature engineering SQL

**Prerequisites for Next Module:** Databricks 03-querying-optimization

---

#### Module 3.10: Databricks Hands-On Labs & Capstone
**File:** [`databricks/05-hands-on-labs.md`](./databricks/05-hands-on-labs.md)  
**Duration:** 8 hours  
**Prerequisites:** Databricks 01-04

**Learning Outcomes:**
- Implement complete lakehouse solution
- Build complex transformation pipelines
- Integrate multiple data sources
- Perform advanced analytics on Databricks

**Labs:**
1. **End-to-End Lakehouse Lab (3 hours):**
   - Load raw data into Bronze/Silver/Data Quality layers
   - Transform into Gold dimension and fact tables
   - Implement SCD types in Delta Lake
   - Run complex analytical queries

2. **Incremental Pipeline Lab (2 hours):**
   - Build daily incremental load processes
   - Use Auto Loader with schema inference
   - Implement MERGE for upserts
   - Monitor pipeline health

3. **Data Quality Lab (2 hours):**
   - Add constraints and quality checks
   - Monitor data quality KPIs
   - Set up alerts for anomalies

4. **Comparative Benchmark (1 hour):**
   - Compare Delta Lake performance with Parquet
   - Run TPC-H queries on Databricks

**Deliverables:**
- Complete Bronze/Silver/Gold architecture
- Quality monitoring dashboard
- 10 analytical queries with performance metrics
- Benchmark comparison report

---

### BigQuery (5 modules, ~40 hours total)

#### Module 3.11: BigQuery Architecture and Capabilities
**File:** [`bigquery/01-architecture.md`](./bigquery/01-architecture.md)  
**Duration:** 6 hours  
**Prerequisites:** Fundamentals 1-4

**Learning Outcomes:**
- Understand BigQuery's columnar architecture
- Explain serverless analytics model
- Compare query and slot pricing models
- Leverage BigQuery unique features
- Design for BigQuery's architecture

**Topics Covered:**
- Columnar storage and Dremel engine
- Query execution architecture (Leaf and Mixer)
- Serverless vs provisioned slots
- Pricing models: on-demand vs annual slots
- Data warehouse hierarchy (project, dataset, table)
- Table types (standard, snapshot, clone)
- Query complexity and resource usage
- Machine types and worker efficiency
- BI Engine for caching and acceleration
- DataS transfer and replication
- Query result caching
- Object constraints and best practices

**Hands-On Labs:**
1. Analyze query execution with slots vs on-demand
2. Estimate costs for different workloads
3. Configure and use BI Engine cache
4. Compare query costs with/without clustering
5. Explore query plan diagrams

**Code Examples:** BigQuery SQL with performance considerations

**Prerequisites for Next Module:** Fundamentals 1-4, GCP account with BigQuery access

---

#### Module 3.12: Data Loading and Management in BigQuery
**File:** [`bigquery/02-data-loading.md`](./bigquery/02-data-loading.md)  
**Duration:** 6 hours  
**Prerequisites:** BigQuery 01-architecture

**Learning Outcomes:**
- Load structured and semi-structured data
- Use various loading methods (UI, CLI, API)
- Handle nested and repeated fields (STRUCT, ARRAY)
- Implement schema updates and evolution
- Design sustainable data loading patterns

**Topics Covered:**
- Dataset and table creation
- Nested data types (STRUCT, ARRAY)
- RECORD data type and nested queries
- Loading from Cloud Storage, databases, APIs
- Batch loading with bq load
- Streaming inserts and best practices
- MERGE operations for upserts
- Partitioning and clustering setup
- Schema updates and adding columns
- Table snapshots and recovery
- Cost optimization for loads

**Hands-On Labs:**
1. Load CSV and Parquet data from Cloud Storage
2. Load nested JSON data with STRUCT and ARRAY types
3. Parse complex RECORD structures
4. Implement MERGE for incremental updates
5. Add columns and handle schema evolution
6. Set up partitioning and clustering during load

**Code Examples:** 20+ loading examples, nested data handling

**Sample Data:** Nested JSON structures, real API responses

**Prerequisites for Next Module:** BigQuery 01-architecture

---

#### Module 3.13: Querying, Optimization, and Analytics in BigQuery
**File:** [`bigquery/03-querying-optimization.md`](./bigquery/03-querying-optimization.md)  
**Duration:** 8 hours  
**Prerequisites:** BigQuery 02-data-loading

**Learning Outcomes:**
- Write performant BigQuery SQL
- Use clustering for query optimization
- Understand query execution plans
- Implement materialized views
- Optimize for slot efficiency

**Topics Covered:**
- Standard SQL in BigQuery
- Query execution plans and understanding bottlenecks
- Partitioning strategies (date, timestamp, integer range)
- Clustering for multi-column filtering
- Materialized views vs views
- Query result caching
- Approximate aggregation functions
- Window functions and analytics
- Unnesting and flattening repeated/nested data
- Cost optimization techniques
- Query monitoring and performance insights

**Hands-On Labs:**
1. Add clustering to tables and measure query improvement
2. Read and interpret 10 query plans
3. Optimize slow queries using partitioning and clustering
4. Create materialized views for common aggregations
5. Compare approximation vs exact query costs
6. Analyze query performance with job history

**Query Examples:** 20+ optimization cases

**Performance Metrics:** Scanned data reduction percentage

**Prerequisites for Next Module:** BigQuery 02-data-loading

---

#### Module 3.14: BigQuery ML and Advanced Analytics
**File:** [`bigquery/04-bigquery-ml.md`](./bigquery/04-bigquery-ml.md)  
**Duration:** 6 hours  
**Prerequisites:** BigQuery 03-querying-optimization

**Learning Outcomes:**
- Build ML models directly in BigQuery SQL
- Create predictive models without Python
- Use BigQuery ML for classification and regression
- Evaluate and predict with BQML models
- Leverage built-in functions for analytics

**Topics Covered:**
- BigQuery ML (BQML) fundamentals
- Supported model types (linear/logistic regression, time series, clustering)
- CREATE MODEL syntax and options
- Feature engineering in BQML
- Training/evaluation data split
- Hyperparameter tuning
- Model evaluation with ML.EVALUATE
- Making predictions with ML.PREDICT
- Model explanation and feature importance
- Integration with Vertex AI
- Advanced analytics functions

**Hands-On Labs:**
1. Build linear regression model for demand forecasting
2. Create logistic regression for customer churn prediction
3. Build K-means clustering model
4. Evaluate model performance with confusion matrix
5. Make predictions on new data
6. Compare BQML model with baseline

**Code Examples:** 15+ BQML examples

**Datasets:** Real prediction scenarios

**Prerequisites for Next Module:** BigQuery 03-querying-optimization

---

#### Module 3.15: BigQuery Hands-On Labs & Capstone
**File:** [`bigquery/05-hands-on-labs.md`](./bigquery/05-hands-on-labs.md)  
**Duration:** 8 hours  
**Prerequisites:** BigQuery 01-04

**Learning Outcomes:**
- Implement complete BigQuery analytics solution
- Optimize costs and performance
- Build predictive analytics applications
- Integrate with BI tools

**Labs:**
1. **Data Warehouse Lab (3 hours):**
   - Create datasets with proper organization
   - Load retail data with nested structures
   - Build dimensional schema
   - Implement SCD with time-based partitioning

2. **Query Optimization Lab (2 hours):**
   - Optimize 10 slow queries
   - Add clustering and partitioning
   - Reduce scanned data by 80%+
   - Measure cost savings

3. **BQML Prediction Lab (2 hours):**
   - Build demand forecasting model
   - Evaluate and refine model
   - Make predictions on future periods
   - Compare against baseline

4. **Comparative Benchmark (1 hour):**
   - Run benchmark queries on BigQuery
   - Compare costs and speed vs other platforms

**Deliverables:**
- Complete data warehouse with nested data handling
- Optimized queries with performance metrics
- BQML model with evaluation results
- Cost and performance comparison report

---

### Redshift (5 modules, ~40 hours total)

#### Module 3.16: Redshift Architecture and MPP Design
**File:** [`redshift/01-architecture.md`](./redshift/01-architecture.md)  
**Duration:** 6 hours  
**Prerequisites:** Fundamentals 1-4

**Learning Outcomes:**
- Understand Massively Parallel Processing (MPP) architecture
- Design distribution strategies for performance
- Choose appropriate cluster node types
- Leverage Redshift advanced features
- Plan cluster sizing and scaling

**Topics Covered:**
- MPP architecture and distributed query execution
- Leader and compute nodes
- Data distribution (EVEN, KEY, ALL)
- Slices and process distribution
- Sort keys and zone maps
- Compression and storage optimization
- Node types (DC2, RA3) and costs
- Cluster scaling strategies
- Concurrency scaling for burst workloads
- Redshift Spectrum for querying S3
- Federated queries to other databases
- Query execution plans
- Monitoring and alerting

**Hands-On Labs:**
1. Create Redshift cluster and explore topology
2. Understand data distribution with sample dataset
3. Compare EVEN vs KEY distribution performance
4. Size cluster for specific workload
5. Set up monitoring dashboards

**Code Examples:** Redshift SQL and configuration

**Architecture Diagrams:** MPP data flow

**Prerequisites for Next Module:** Fundamentals 1-4, Redshift cluster available

---

#### Module 3.17: Data Loading and Design in Redshift
**File:** [`redshift/02-data-loading.md`](./redshift/02-data-loading.md)  
**Duration:** 6 hours  
**Prerequisites:** Redshift 01-architecture

**Learning Outcomes:**
- Load data efficiently into Redshift
- Implement compression appropriate to workload
- Design tables for Redshift performance
- Implement incremental loads
- Optimize loading performance

**Topics Covered:**
- COPY command and best practices
- S3, DynamoDB, and other source loading
- Data formatting and encoding
- Compression strategies (ZSTD, LZ4, RAW)
- Encoding per column selection
- Primary keys and unique constraints
- Foreign keys (informational only)
- Distkey and sortkey column selection
- Table design patterns
- MERGE/upsert patterns
- Incremental loading with manifests
- Performance tuning for loads
- Parallel loading techniques

**Hands-On Labs:**
1. Load sample dataset from S3 with COPY
2. Compare compression options for data reduction
3. Design tables with optimal distkey/sortkey
4. Implement incremental load with metadata tracking
5. Profile load performance and optimize

**Code Examples:** COPY variations, table design SQL

**Configuration Examples:** Redshift table DDL

**Prerequisites for Next Module:** Redshift 01-architecture

---

#### Module 3.18: Query Optimization and Performance Tuning
**File:** [`redshift/03-querying-optimization.md`](./redshift/03-querying-optimization.md)  
**Duration:** 8 hours  
**Prerequisites:** Redshift 02-data-loading

**Learning Outcomes:**
- Write optimized queries for MPP execution
- Use distribution keys for query efficiency
- Interpret query execution plans
- Implement query optimization techniques
- Manage query performance at scale

**Topics Covered:**
- Query execution in MPP architecture
- Distribution key impact on performance
- Sort key usage and effectiveness
- Query plan analysis
- JOIN optimization and distribution
- Broad tables vs deep tables
- Vacuum and analyze commands
- Statistics and query planning
- Table design impact on query performance
- Caching and result reuse
- Workload management and query priorities
- Monitoring query performance

**Hands-On Labs:**
1. Analyze query plans for distribution inefficiencies
2. Redesign distribution keys to reduce shuffling
3. Use sort keys to optimize filtering
4. Compare query performance before/after optimization
5. Set up query monitoring and analysis
6. Create workload management rules

**Query Examples:** 20+ optimization cases

**Real Query Plans:** Analysis and optimization paths

**Prerequisites for Next Module:** Redshift 02-data-loading

---

#### Module 3.19: Advanced Redshift Features
**File:** [`redshift/04-cluster-management.md`](./redshift/04-cluster-management.md)  
**Duration:** 6 hours  
**Prerequisites:** Redshift 03-querying-optimization

**Learning Outcomes:**
- Use Redshift Spectrum for data lake queries
- Implement federated queries
- Manage concurrency and workload
- Monitor and optimize cluster health
- Plan disaster recovery

**Topics Covered:**
- Redshift Spectrum architecture and querying
- Querying S3 Parquet and ORC files
- Federated queries to PostgreSQL, RDS
- Concurrency scaling configuration
- Workload management queues and priorities
- WLM parameter tuning
- Advisor recommendations
- Cluster health monitoring
- Performance insights
- Backup and recovery strategies
- Node failure handling
- Cost optimization strategies

**Hands-On Labs:**
1. Query Parquet files in S3 via Spectrum
2. Set up federated query to RDS
3. Configure workload management queues
4. Monitor concurrency and query delays
5. Fine-tune cluster for mixed workloads

**Configuration Examples:** WLM, Spectrum setup

**Prerequisites for Next Module:** Redshift 03-querying-optimization

---

#### Module 3.20: Redshift Hands-On Labs & Capstone
**File:** [`redshift/05-hands-on-labs.md`](./redshift/05-hands-on-labs.md)  
**Duration:** 8 hours  
**Prerequisites:** Redshift 01-04

**Learning Outcomes:**
- Build complete Redshift data warehouse
- Optimize for MPP performance
- Manage complex workloads
- Compare Redshift with other platforms

**Labs:**
1. **Data Warehouse Lab (3 hours):**
   - Design star schema with optimal distribution keys
   - Load data using parallel load patterns
   - Implement compression
   - Run analytical queries

2. **Performance Tuning Lab (2 hours):**
   - Identify and optimize 10 slow queries
   - Tune distribution keys and sort keys
   - Run VACUUM and ANALYZE
   - Measure performance improvements

3. **Advanced Features Lab (2 hours):**
   - Query S3 data via Spectrum
   - Set up workload management
   - Implement federated queries

4. **Comparative Benchmark (1 hour):**
   - Run benchmark queries on Redshift
   - Compare performance and costs

**Deliverables:**
- Complete data warehouse design
- Optimized queries showing performance gains
- Configuration documentation
- Benchmark comparison report

---

## LEVEL 3.5: APACHE OPEN-SOURCE STACK (Weeks 15-22)

> **Why This Level Exists:** The cloud platforms covered in Level 3 were built on, or directly inspired by, open-source Apache technologies. Databricks runs on Apache Spark. Kafka powers real-time pipelines feeding every platform. Flink is the industry standard for low-latency streaming. Understanding this layer makes you a deeper, more effective data expert — not just a platform user.

### Module A1: Hadoop Ecosystem
**File:** [`apache-stack/01-hadoop-ecosystem.md`](./apache-stack/01-hadoop-ecosystem.md)  
**Duration:** 5 hours  
**Prerequisites:** Fundamentals 1-4

**Learning Outcomes:**
- Explain HDFS distributed storage architecture (NameNode, DataNode, blocks, replication)
- Describe the MapReduce programming model and why Spark replaced it
- Navigate HDFS using shell commands
- Understand YARN resource management
- Use key ecosystem tools: Hive, HBase, Sqoop, Oozie
- Compare traditional Hadoop to modern cloud-native architectures

**Topics Covered:**
- HDFS: block storage, NameNode/DataNode roles, replication factor
- HDFS shell commands
- MapReduce: map phase, shuffle, reduce phase (Java and Python streaming)
- Why MapReduce is obsolete for new code
- YARN: ResourceManager, NodeManager, ApplicationMaster, containers
- Apache Hive: HiveQL, partitioned tables, ORC format
- Apache HBase: wide-column NoSQL, row key design
- Apache Sqoop: bulk data transfer from RDBMS
- Apache Oozie: job scheduling and DAGs
- Hadoop vs cloud object storage (S3, GCS, ADLS)

**Hands-On Labs:**
1. Deploy Docker-based Hadoop cluster (HDFS + YARN)
2. Upload files, check block layout, verify replication
3. Run a MapReduce WordCount example
4. Write Python MapReduce via Hadoop Streaming
5. Create a Hive table on HDFS and query it

**Knowledge Check:** 6 conceptual and design questions

**Prerequisites for Next Module:** Fundamentals 1-4

---

### Module A2: Apache Spark
**File:** [`apache-stack/02-apache-spark.md`](./apache-stack/02-apache-spark.md)  
**Duration:** 8 hours  
**Prerequisites:** Module A1, basic Python

**Learning Outcomes:**
- Explain Spark's architecture (Driver, Executors, Cluster Manager, DAG Scheduler)
- Write production-quality data pipelines with the DataFrame API
- Query data with Spark SQL
- Build streaming pipelines with Structured Streaming
- Train ML models at scale with MLlib
- Profile and tune Spark jobs (partitioning, caching, broadcast joins)
- Work with Delta Lake for ACID transactions on data lakes

**Topics Covered:**
- Spark architecture: driver, executors, jobs, stages, tasks, partitions
- Spark vs MapReduce — why Spark is 10–100x faster
- RDD API (conceptual; avoid for new code)
- DataFrame API: read, select, filter, join, aggregate, window functions, write
- Spark SQL and temporary views
- Structured Streaming: Kafka source, windowed aggregation, output modes, checkpointing
- MLlib: Pipeline, VectorAssembler, RandomForest, cross-validation
- Performance tuning: partitioning, coalesce vs repartition, caching, broadcast joins
- Execution plan analysis with `explain()`
- Delta Lake: MERGE, time travel, OPTIMIZE, VACUUM

**Hands-On Labs:**
1. Load sales CSV, run DataFrame transformations and aggregations
2. Write and execute multi-step Spark SQL queries
3. Read from a Kafka topic with Structured Streaming
4. Train a churn prediction model with MLlib Pipeline
5. Use `explain()` to identify and fix a shuffle bottleneck
6. MERGE data into a Delta Lake table; read a historical version with time travel

**Code Examples:** 40+ PySpark examples with explanations

**Knowledge Check:** 6 technical questions on architecture and optimization

**Prerequisites for Next Module:** Module A1, Python basics

---

### Module A3: Apache Flink
**File:** [`apache-stack/03-apache-flink.md`](./apache-stack/03-apache-flink.md)  
**Duration:** 7 hours  
**Prerequisites:** Module A2

**Learning Outcomes:**
- Explain Flink's architecture (JobManager, TaskManager, slots)
- Distinguish processing time vs event time vs ingestion time
- Use watermarks to handle late or out-of-order events correctly
- Build stateful stream processing with `KeyedProcessFunction`
- Implement tumbling, sliding, and session windows
- Write Flink SQL queries against streaming data
- Configure state backends (HashMapStateBackend vs RocksDB) and checkpointing
- Understand Flink's exactly-once fault tolerance model
- Decide when to use Flink vs Spark Streaming

**Topics Covered:**
- Flink architecture: JobManager, TaskManager, slots, parallelism
- Time semantics: event time, processing time, ingestion time
- Watermarks and handling late data
- DataStream API: MapFunction, FilterFunction, FlatMapFunction
- Kafka source with event-time watermarks
- KeyedStream and stateful processing with ValueState, ListState
- Timers in KeyedProcessFunction
- Window types: tumbling, sliding, session windows
- WindowFunction and ProcessWindowFunction
- Table API and Flink SQL (DDL, INSERT INTO, TUMBLE windows)
- State backends: HashMapStateBackend vs EmbeddedRocksDBStateBackend
- Checkpointing for fault tolerance and exactly-once guarantees
- Exactly-once Kafka sink with transactions

**Hands-On Labs:**
1. Start local Flink cluster and open Web UI
2. Parse a Kafka event stream and filter in real time
3. Implement a `KeyedProcessFunction` that accumulates per-user state
4. Compute windowed revenue per region using tumbling event-time windows
5. Write a Flink SQL job reading from Kafka and writing to a file sink

**Knowledge Check:** 6 questions on event time, windowing, state, and fault tolerance

**Prerequisites for Next Module:** Module A2

---

### Module A4: Apache Kafka
**File:** [`apache-stack/04-apache-kafka.md`](./apache-stack/04-apache-kafka.md)  
**Duration:** 6 hours  
**Prerequisites:** Fundamentals 1-4

**Learning Outcomes:**
- Explain Kafka's distributed log model (topics, partitions, offsets, replicas)
- Produce and consume messages with the Python Kafka client
- Design effective partition keys for ordering and parallelism
- Manage consumer groups and understand rebalancing
- Use Kafka Connect for no-code integrations (Debezium CDC, S3 Sink)
- Use Schema Registry to enforce and evolve Avro schemas
- Understand when to use Kafka Streams vs Flink/Spark for stream processing
- Deploy a local Kafka cluster with Docker Compose

**Topics Covered:**
- Topics, partitions, offsets, brokers, replication
- Kafka vs traditional message queues
- Producer API: acks, retries, compression, partition keys
- Consumer API: consumer groups, partition assignment, manual offset commit, seek
- Topic configuration: retention, compaction, replication factor, min.insync.replicas
- Kafka Connect: Debezium CDC, S3 Sink connector, REST management API
- Schema Registry: Avro schemas, compatibility levels
- Kafka Streams DSL: KStream, KTable, windowing (lightweight option)
- Full production pipeline architecture diagram

**Hands-On Labs:**
1. Deploy Kafka + Kafka UI with Docker Compose
2. Write a Python producer that sends order events with customer_id as the key
3. Write a Python consumer with manual offset commits
4. Inspect consumer group lag via CLI and Kafka UI
5. Deploy a Debezium CDC connector for a Postgres table

**Knowledge Check:** 6 questions on partitioning, consumer groups, CDC, and exactly-once

**Prerequisites for Next Module:** Fundamentals 1-4

---

### Module A5: Apache Stack — Hands-On Labs
**File:** [`apache-stack/05-hands-on-labs.md`](./apache-stack/05-hands-on-labs.md)  
**Duration:** 6 hours  
**Prerequisites:** Modules A1–A4

**Learning Outcomes:**
- Build a complete end-to-end streaming + batch pipeline using the Apache stack
- Connect Kafka → Flink (real-time) and Kafka → Spark (hourly batch rollup)
- Write Parquet output suitable for loading into a cloud data warehouse
- Debug common issues in each layer of the pipeline
- Answer architectural design questions about scale, fault tolerance, and tool selection

**Labs:**
1. **Lab 1 — HDFS Basics (45 min):** Upload CSV data, explore block layout, run WordCount MapReduce
2. **Lab 2 — Spark Batch Pipeline (90 min):** Load sales data, transformations, window functions, write Parquet
3. **Lab 3 — Kafka Setup and Producers (45 min):** Docker Compose cluster, Python producer, CLI consumer, monitor lag
4. **Lab 4 — Flink Real-Time Pipeline (90 min):** Parse Kafka orders, 1-min windowed revenue, stateful VIP detection
5. **Lab 5 — End-to-End Integration (60 min):** Flink (real-time alerts) + Spark (hourly batch rollup) running simultaneously against the same Kafka topic

**Final Design Challenge:** 5 open-ended architecture questions covering scaling, tool selection, Hadoop migration, exactly-once guarantees, and partitioning strategy

---

## LEVEL 4: OPTIMIZATION & PERFORMANCE (Weeks 23-26)

### Module 4.1: Query Execution Plans Across Platforms
**File:** [`optimization/01-query-execution-plans.md`](./optimization/01-query-execution-plans.md)  
**Duration:** 4 hours  
**Prerequisites:** All platform modules OR any 2 platform modules + fundamentals

**Learning Outcomes:**
- Read and interpret execution plans on each platform
- Identify bottlenecks (shuffles, joins, scans)
- Optimize queries based on plan analysis
- Compare plan efficiency across platforms

**Topics Covered:**
- Snowflake execution plans (EXPLAIN PLAN)
- Databricks Spark UI and plan visualization
- BigQuery execution plans and job details
- Redshift execution plans and session information
- Common bottleneck patterns
- Optimization techniques per platform
- Plan comparison case studies

**Hands-On Labs:**
1. Read 10 complex query plans per platform
2. Identify 3 bottlenecks and suggest fixes
3. Run optimized version and verify improvement
4. Document before/after plan comparisons

**Analysis Templates:** Plan interpretation guides

**Prerequisites for Next Module:** At least 2 platform modules

---

### Module 4.2: Data Organization and Indexing Strategies
**File:** [`optimization/02-data-organization.md`](./optimization/02-data-organization.md)  
**Duration:** 5 hours  
**Prerequisites:** Module 4.1

**Learning Outcomes:**
- Design partitioning strategies
- Choose clustering approaches
- Implement materialized views
- Optimize data order and organization

**Topics Covered:**
- Partitioning by date, domain, or other dimensions
- Partition elimination and pruning efficiency
- Clustering keys and depth management
- Sort keys and zone maps
- Materialized views for pre-aggregation
- Incremental materialization patterns
- Data organization for different query patterns
- Index types and usage across platforms
- Storage footprint optimization
- Statistics management

**Hands-On Labs:**
1. Design partition strategy for retail dataset
2. Implement clustering and measure scan reduction
3. Create 5 materialized views for common queries
4. Compare full scan vs materialized view performance
5. Calculate storage impact of optimization

**Optimization Case Studies:** Real-world examples

**Prerequisites for Next Module:** Module 4.1

---

### Module 4.3: Cost Optimization Framework
**File:** [`optimization/03-cost-optimization.md`](./optimization/03-cost-optimization.md)  
**Duration:** 4 hours  
**Prerequisites:** Module 4.2

**Learning Outcomes:**
- Understand cost drivers for each platform
- Calculate total cost of ownership (TCO)
- Design cost-aware architectures
- Identify cost optimization opportunities

**Topics Covered:**
- Snowflake cost model (compute credits + storage)
- Databricks cost model (DBUs)
- BigQuery cost model (analysis pricing + storage)
- Redshift cost model (nodes + storage)
- Hidden costs (data transfer, backups)
- Resource allocation and right-sizing
- Query result caching economics
- Data tiering strategies
- Cleanup and maintenance costs
- Cost monitoring tools
- Financial impact of optimization

**Hands-On Labs:**
1. Calculate monthly costs for each platform
2. Identify top 10 cost drivers
3. Propose optimization with ROI calculation
4. Implement cost monitoring dashboards
5. Track savings over 3 months

**Cost Calculators:** Platform-specific cost models

**Benchmark Case Studies:** Real optimization ROI

**Prerequisites for Next Module:** Module 4.2

---

### Module 4.4: Performance Benchmarking and Comparison
**File:** [`optimization/04-performance-benchmarks.md`](./optimization/04-performance-benchmarks.md)  
**Duration:** 3 hours  
**Prerequisites:** Module 4.3

**Learning Outcomes:**
- Run standardized benchmark tests
- Compare platform performance fairly
- Interpret benchmark results
- Present findings to stakeholders

**Topics Covered:**
- TPC-H benchmark (modified)
- Query selection for representation
- Benchmark methodology
- Performance metrics (latency, throughput, cost)
- Running benchmarks across platforms
- Result interpretation and variance
- Presentation of findings

**Hands-On Labs:**
1. Run 20-query benchmark on each platform
2. Document execution times and costs
3. Create comparison table and charts
4. Analyze variance and anomalies
5. Present findings with recommendations

**Benchmark Suite:** 20 representative queries

**Result Templates:** Comparison spreadsheets

**Prerequisites for Next Module:** Module 4.3

---

## LEVEL 5: GOVERNANCE & INTEGRATION (Weeks 19-22)

### Module 5.1: dbt Fundamentals and Data Modeling
**File:** [`governance-integration/01-dbt-fundamentals.md`](./governance-integration/01-dbt-fundamentals.md)  
**Duration:** 5 hours  
**Prerequisites:** Fundamentals 1-3

**Learning Outcomes:**
- Use dbt for data transformation and documentation
- Build modular, version-controlled data models
- Implement testing in dbt
- Leverage dbt macros and packages

**Topics Covered:**
- dbt fundamentals and philosophy
- dbt project structure
- Models (staging, intermediate, mart)
- Materialization options (table, view, incremental)
- dbt selectors and model dependencies
- dbt tests and validation
- Macros for reusable logic
- Packages and community contributions
- Documentation and artifacts
- dbt Cloud for orchestration
- dbt CLI usage patterns
- Version control integration

**Hands-On Labs:**
1. Initialize dbt project
2. Create staging models for raw data
3. Build intermediate models
4. Create mart (fact/dimension) models
5. Add comprehensive testing
6. Generate documentation

**Sample Project:** Retail dimensional model in dbt

**Code Templates:** dbt project structure

**Prerequisites for Next Module:** Fundamentals 1-3

---

### Module 5.2: Data Quality and Testing Frameworks
**File:** [`governance-integration/02-data-quality.md`](./governance-integration/02-data-quality.md)  
**Duration:** 5 hours  
**Prerequisites:** Module 5.1

**Learning Outcomes:**
- Implement comprehensive data quality checks
- Use dbt tests and custom expectations
- Monitor data quality over time
- Define and track SLAs
- Detect anomalies

**Topics Covered:**
- Data quality dimensions
- dbt testing framework:
  - Unique, not null, accepted values
  - Relationships, custom SQL tests
- Great Expectations for complex validation
- Data contracts and specifications
- Anomaly detection patterns
- SLA definition and monitoring
- Quality metrics and dashboards
- Incident response workflows
- Documentation of quality requirements

**Hands-On Labs:**
1. Add dbt tests to dimensional models
2. Create custom dbt tests for business rules
3. Build Great Expectations suite
4. Detect and investigate anomalies
5. Create quality monitoring dashboard
6. Document data contracts

**Testing Guidelines:** Best practices and patterns

**Sample Quality Rules:** Retail data quality definitions

**Prerequisites for Next Module:** Module 5.1

---

### Module 5.3: Data Governance and Access Control
**File:** [`governance-integration/03-governance-patterns.md`](./governance-integration/03-governance-patterns.md)  
**Duration:** 4 hours  
**Prerequisites:** Module 5.2

**Learning Outcomes:**
- Design access control (RBAC) structures
- Implement data cataloging and lineage
- Track data: compliance and audit
- Manage sensitive data
- Govern schema evolution

**Topics Covered:**
- Role-Based Access Control (RBAC)
- Column-level and row-level security
- Data cataloging and metadata management
- Data lineage and impact analysis
- Lineage tracking at query level
- Sensitive data identification and masking
- Compliance requirements (GDPR, HIPAA, etc.)
- Audit logging and monitoring
- Schema governance
- API management for data access
- Data sharing policies

**Hands-On Labs:**
1. Design RBAC hierarchy for organization
2. Set up access controls on each platform
3. Build data catalog and lineage
4. Implement column masking for PII
5. Document governance policies
6. Set up audit logging

**Policy Templates:** RBAC and governance structures

**Lineage Diagrams:** Sample lineage graphs

**Prerequisites for Next Module:** Module 5.2

---

### Module 5.4: Orchestration and Workflow Management
**File:** [`governance-integration/04-orchestration.md`](./governance-integration/04-orchestration.md)  
**Duration:** 6 hours  
**Prerequisites:** Module 5.3

**Learning Outcomes:**
- Design complex data pipelines
- Use Airflow for orchestration
- Implement error handling and alerts
- Monitor pipeline health
- Scale pipelines for production

**Topics Covered:**
- Data pipeline design patterns
- Apache Airflow fundamentals
- DAGs (Directed Acyclic Graphs)
- Operators and sensors
- dbt Cloud scheduling
- Dependency management
- Error handling and retries
- Alerting and notifications
- Dynamic DAG generation
- Scaling and concurrency
- Monitoring and debugging
- CI/CD for data pipelines

**Hands-On Labs:**
1. Build Airflow DAG with 5 tasks
2. Add dependencies and error handling
3. Implement retry logic
4. Set up alerting for failures
5. Monitor and debug DAG execution
6. Create monitoring dashboards

**Sample DAGs:** Examples across platforms

**Configuration Files:** Airflow setup

**Prerequisites for Next Module:** Module 5.3

---

## LEVEL 6: ADVANCED PATTERNS & CAPSTONE (Weeks 23-26)

### Module 6.1: Streaming Analytics and Real-Time Data
**File:** [`advanced-patterns/01-streaming-analytics.md`](./advanced-patterns/01-streaming-analytics.md)  
**Duration:** 4 hours  
**Prerequisites:** Any 2 platform modules

**Learning Outcomes:**
- Implement real-time data ingestion
- Build stream processing applications
- Handle late and out-of-order data
- Integrate streaming with warehouse

**Topics Covered:**
- Streaming data sources (Kafka, Kinesis, Pub/Sub)
- Stream processing frameworks (Spark Streaming, Beam)
- Stream tables in Databricks
- Processing guarantees (exactly-once)
- Late and out-of-order data handling
- Windowing and aggregations over time
- Stateful computations
- Sink options (warehouse, storage, cache)
- Monitoring stream pipelines
- Stream-batch consistency

**Hands-On Labs:**
1. Set up Kafka producer/consumer pair
2. Process stream with window aggregations
3. Handle late arrivals
4. Sink stream to warehouse
5. Monitor stream pipeline health

**Code Examples:** Streaming implementations

**Architecture Diagrams:** Stream integration patterns

**Prerequisites for Next Module:** Platform modules

---

### Module 6.2: Machine Learning and Analytics Integration
**File:** [`advanced-patterns/02-ml-analytics-integration.md`](./advanced-patterns/02-ml-analytics-integration.md)  
**Duration:** 4 hours  
**Prerequisites:** Modules 6.1, any platform module

**Learning Outcomes:**
- Build end-to-end ML pipelines
- Feature engineering in warehouse
- Model serving patterns
- Monitor ML models in production
- Integrate ML with business workflows

**Topics Covered:**
- Feature engineering best practices
- Feature stores for ML
- Model training pipelines
- Model evaluation and validation
- Model deployment and serving
- Online vs batch predictions
- Model monitoring and drift detection
- Retraining strategies
- Explainability and interpretability
- ML governance and compliance

**Hands-On Labs:**
1. Build feature store from warehouse data
2. Engineer features for ML model
3. Train and evaluate prediction model
4. Deploy model for inference
5. Monitor model performance
6. Detect model drift

**Code Examples:** Feature engineering SQL, ML pipelines

**Sample Models:** Real prediction scenarios

**Prerequisites for Next Module:** Modules 6.1, platform modules

---

### Module 6.3: Unified Capstone Project
**File:** [`advanced-patterns/03-capstone-project.md`](./advanced-patterns/03-capstone-project.md)  
**Duration:** 20-30 hours (self-paced over Weeks 23-26)  
**Prerequisites:** All previous modules recommended

**Learning Outcomes:**
- Integrate all course concepts in realistic project
- Build production-like data warehouse solutions
- Compare platform choices based on requirements
- Present technical solutions to stakeholders
- Document architecture decisions

**Project Specification:**

**Scenario:** Build retail analytics data warehouse for a multi-channel retailer

**Requirements:**
- Source data: customers, products, orders, returns, inventory (5 source systems)
- Data volume: 2 years history, daily updates (500M transactions)
- Access patterns: Executive dashboards, operational reports, ML model serving
- Constraints: $10,000/month budget, 24-hour SLA for daily refresh

**Deliverables (per platform):**
1. Data architecture diagram
2. Dimensional schema design document
3. dbt project with all models and tests
4. Airflow DAG for daily refresh pipeline
5. Query optimization analysis (3 complex queries)
6. Data quality monitoring dashboard
7. Access control design and implementation
8. Performance benchmark (query times, costs)
9. Architecture trade-off analysis vs other platforms
10. Presentation to stakeholders (slide deck + live demo)

**Grading Rubric:**
- **Data Model (20%):** Appropriate schema, dimension handling, grain clarity
- **Implementation (30%):** dbt quality, testing completeness, pipeline robustness
- **Performance (20%):** Query optimization, cost efficiency, load times
- **Governance (15%):** Quality monitoring, access control, documentation
- **Presentation (15%):** Clarity, depth, comparison of platforms

**Expected Time:**
- Per platform: 6-8 hours
- Total for all 4 platforms: 24-32 hours

**Optional Extensions:**
- ML model integration (predict customer churn)
- Streaming event analytics layer
- Multi-cloud setup and comparison
- Data sharing and marketplace integration

---

## CROSS-PLATFORM LEARNING (Weeks 15-20)

### Module P1: Architecture Comparison
**File:** [`platform-comparison/01-architecture-comparison.md`](./platform-comparison/01-architecture-comparison.md)  
**Duration:** 3 hours  
**Prerequisites:** At least 2 platform modules

**Learning Outcomes:**
- Compare architectural approaches across platforms
- Understand design trade-offs
- Choose appropriate platform for use cases

**Topics Covered:**
- Compute/storage models (separation vs integration)
- Query execution architectures (columnar vs row-based)
- Scaling approaches (auto vs manual)
- Pricing models and cost drivers
- Feature comparison matrix
- Architecture impact on query performance
- Data model implications per architecture

**Analysis:**
- Side-by-side architecture explanations
- Feature availability comparison
- Cost per GB and per query
- Performance on standard workloads
- Maturity and stability assessment

**Deliverable:** Comparative analysis document

**Prerequisites for Next Module:** At least 2 platform modules

---

### Module P2: Platform Selection Guide
**File:** [`platform-comparison/02-platform-selection-guide.md`](./platform-comparison/02-platform-selection-guide.md)  
**Duration:** 2 hours  
**Prerequisites:** Module P1

**Learning Outcomes:**
- Evaluate platforms against business requirements
- Create platform recommendation
- Plan implementation strategy

**Topics Covered:**
- Selection framework and decision tree
- Use case categories with platform fit
- Organizational factors
- Migration and hybrid strategies
- Multi-cloud considerations
- Change management planning

**Deliverable:** Platform selection matrix and recommendation

---

## Summary by Audience

### Data Analyst Path (12-14 weeks)
Focus: Fundamentals → SQL + Modeling → 1-2 favorite platforms → Query optimization
Skip: Engineering complexity, infrastructure, governance deep-dives
**Modules:** 1-4, choose 2 platforms (5 modules each), optimization modules 1-2

### Data Engineer Path (Full 26 weeks)
**All modules** including deep infrastructure, governance, orchestration

### Analytics Engineer Path (18-20 weeks)
Focus: Fundamentals → SQL + Modeling → dbt + Quality → 2 platforms → Governance
**Modules:** 1-4, 2 platform modules each, governance modules, skip infrastructure-heavy topics

### Data Architect Path (26+ weeks plus research)
**All modules** with emphasis on architecture, platform selection, trade-off analysis

---

## Time Estimates and Scheduling

| Component | Hours | Weekly | Weeks |
|-----------|-------|--------|-------|
| Fundamentals | 14 | 3.5 | 4 |
| Platform Deep-Dive (1 platform) | 40 | 5 | 8 |
| Platform Deep-Dive (2 additional) | 80 | 5-10 | 8-16 |
| Optimization & Comparison | 16 | 4-8 | 2-4 |
| Governance & Integration | 19 | 4-5 | 4 |
| Advanced & Capstone | 28 | 7 | 4 |
| **Total** | **78-130** | **3-5** | **26** |

### Accelerated Path (13 weeks, high intensity)
- 6+ hours/week for 13-week sprint
- Focus: Fundamentals + 2 platforms + optimization + capstone
- Skip: Full governance deep-dive, streaming/ML unless relevant to role

### Extended Path (52 weeks, part-time)
- 1.5-2.5 hours/week
- Complete full curriculum at comfortable pace
- More time for practice and experimentation
- Better retention and mastery

---

*Complete curriculum with all learning paths, time estimates, and prerequisites updated March 2026*
