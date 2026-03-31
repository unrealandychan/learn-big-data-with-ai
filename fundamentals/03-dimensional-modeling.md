# Dimensional Modeling: Building Warehouse Schemas

## Learning Outcomes

By completing this module, you should be able to:
- Apply Kimball's dimensional modeling methodology
- Design star schemas following best practices
- Implement Slowly Changing Dimensions (SCD Types 1, 2, 3)
- Create conformed dimensions for enterprise warehouses
- Distinguish between different fact table types (transactional, snapshot, accumulating)
- Design appropriate grain for fact tables
- Build role-playing dimensions

**Estimated Time:** 5 hours (2.5 hours reading + 2.5 hours design labs)  
**Prerequisites:** Modules 1-2  
**Knowledge Assumed:** SQL basics, star schema familiarity

---

## 1. Kimball Methodology: Core Principles

Ralph Kimball's approach (since the 1990s) is the most practical, widely-used warehouse design methodology.

### Four Key Principles

**1. Start with Business Processes**
Don't start with tables. Start with: "What measurable business events do we track?"

Examples:
- Retail: Customer purchases items
- Hospital: Patient has medical procedure
- Bank: Account transfer occurs
- Hotel: Guest reserves room

**2. Identify Grain Carefully**
Grain = What exactly does one row represent?

Bad grain: "One row per day" (ambiguous - per day FOR WHAT?)
Good grain: "One row per order line item" (clear and specific)

**3. Choose Conformed Dimensions**
Share dimension tables across fact tables when possible.
- Limits redundancy
- Easier updates
- Cleaner queries
- Enterprise consistency

**4. Build Atomic Facts**
Store fact tables at transaction level (most detailed), then aggregate upward.

---

## 2. Dimensions: The "Who, What, When, Where, Why"

### Anatomy of a Dimension Table

```sql
CREATE TABLE dim_products (
    product_sk INT PRIMARY KEY,              -- Surrogate key (warehouse-generated)
    product_id VARCHAR PRIMARY KEY,          -- Natural key (from source system)
    product_name VARCHAR,                    -- Business-friendly name
    category VARCHAR,                        -- Hierarchy level 1
    sub_category VARCHAR,                    -- Hierarchy level 2
    brand VARCHAR,                           -- Attribute
    price_point VARCHAR,                     -- Attribute
    color VARCHAR,                           -- Attribute
    size VARCHAR,                            -- Attribute
    supplier_id INT,                         -- FK if shared dimension
    product_active_flag BOOLEAN,             -- Current status
    scd_effective_date DATE,                 -- When this version started
    scd_end_date DATE,                       -- When this version ended (NULL = current)
    scd_version INT,                         -- Version number for SCD Type 2
    load_date TIMESTAMP,                     -- Metadata: when loaded
    row_expiration_flag BOOLEAN              -- Metadata: is this current?
);
```

### Surrogate Keys vs Natural Keys

| Aspect | Surrogate Key | Natural Key |
|--------|---------------|-------------|
| **Definition** | Warehouse-generated unique ID | Unique ID from source system |
| **Example** | product_sk = 12345 | product_id = 'NIKE-AIR-123' |
| **Stability** | Always changes (1, 2, 3...) | Can change (if source changes) |
| **Storage** | Small (INT = 4 bytes) | Larger (VARCHAR = 20+ bytes) |
| **Dimension Grows** | +1 row | +1 row (or SCD Type 2) |
| **Join Performance** | Fast (small keys) | Slower (large keys) |
| **Best For** | Fact table foreign keys | Metadata/tracking |
| **Recommendation** | Use this | Use for reference only |

**Best Practice:** Use surrogate keys in fact tables, keep natural keys in dimensions for tracking.

### Dimension Attributes: Denormalization

Dimensions are **intentionally denormalized** for ease of use:

```sql
-- BAD: Normalized (too many tables to join)
SELECT c.customer_name, s.state_name, r.region_name 
FROM fact_orders f
JOIN customer c ON f.customer_sk = c.customer_sk
JOIN state s ON c.state_sk = s.state_sk
JOIN region r ON s.region_sk = r.region_sk;

-- GOOD: Denormalized (query one dimension table)
SELECT c.customer_name, c.state, c.region 
FROM fact_orders f
JOIN dim_customers c ON f.customer_sk = c.customer_sk;
```

---

## 3. Slowly Changing Dimensions (SCD)

**Problem:** Dimension attributes change over time. How do you track changes?

Example: Product price changes, customer moves to new state, employee gets promoted.

### SCD Type 1: Overwrite (History Lost)

**Rule:** When an attribute changes, overwrite the old value. Previous value is gone.

**Use When:** Change is correction or doesn't matter historically (e.g., fixing typo)

```sql
-- BEFORE:
-- product_sk=1, product_id='P123', product_name='Widget A', price=29.99

-- Product renamed: Widget A → Premium Widget
UPDATE dim_products 
SET product_name = 'Premium Widget'
WHERE product_id = 'P123';

-- AFTER:
-- product_sk=1, product_id='P123', product_name='Premium Widget', price=29.99

-- Result: Old name is lost. Historical queries show product was always "Premium Widget"
```

**When to use:** Unlikely - most dimensions need history!

---

### SCD Type 2: Add Row with Dates (Full History)

**Rule:** When attribute changes, add a NEW row with effective dates. Keep old row marked as expired.

**Use When:** You want to preserve history (most common!)

```sql
-- BEFORE:
-- product_sk=1, product_id='P123', product_name='Widget', price=29.99, 
--   scd_effective_date='2023-01-01', scd_end_date=NULL (current)

-- Product renamed: Widget → Premium Widget
-- Add new row:
INSERT INTO dim_products (product_sk, product_id, product_name, price, 
    scd_effective_date, scd_end_date, scd_version)
VALUES (2, 'P123', 'Premium Widget', 29.99, '2025-03-27', NULL, 2);

-- Update old row:
UPDATE dim_products 
SET scd_end_date = '2025-03-26'
WHERE product_sk = 1;

-- AFTER:
-- product_sk=1, product_id='P123', product_name='Widget', price=29.99, 
--   scd_effective_date='2023-01-01', scd_end_date='2025-03-26', scd_version=1
-- 
-- product_sk=2, product_id='P123', product_name='Premium Widget', price=29.99,
--   scd_effective_date='2025-03-27', scd_end_date=NULL (current), scd_version=2

-- RESULT: 
-- Historical query (Jan 2024): Product was "Widget" (joins to sk=1)
-- Current query (March 2025): Product is "Premium Widget" (joins to sk=2)
```

**Advantages:**
- Full history preserved
- Queries naturally show correct names for their time period
- Standard approach across industry

**Implementation:** Fact table stores the sk (1 or 2) at time of order, so queries naturally get the correct name.

**Query Example:**
```sql
-- Orders with correct product name at time of order
SELECT 
    o.order_date,
    p.product_name,          -- Gets "Widget" if order was 2024
    o.sales_amount           -- Gets "Premium Widget" if order was 2025
FROM fact_orders o
JOIN dim_products p ON o.product_sk = p.product_sk;
-- ^ No WHERE or date filter needed! SCD Type 2 handles it automatically
```

---

### SCD Type 3: Add Column (Limited History)

**Rule:** Add new column for new value, keep old column for previous value.

**Use When:** You want to compare current vs previous value easily

```sql
-- BEFORE:
-- product_sk=1, product_name='Widget'

-- Add new columns:
ALTER TABLE dim_products ADD COLUMN previous_product_name VARCHAR;
ALTER TABLE dim_products ADD COLUMN product_name_change_date DATE;

-- Update when product is renamed:
UPDATE dim_products 
SET previous_product_name = product_name,
    product_name = 'Premium Widget',
    product_name_change_date = CURRENT_DATE
WHERE product_sk = 1;

-- AFTER:
-- product_sk=1, product_name='Premium Widget', 
--   previous_product_name='Widget', product_name_change_date='2025-03-27'

-- Query: See BOTH names
SELECT product_name, previous_product_name, product_name_change_date 
FROM dim_products WHERE product_sk = 1;
```

**Advantages:**
- Easy side-by-side comparison
- Single row
- Works for 2-3 versions only

**Disadvantages:**
- Only tracks 2-3 versions (current + previous)
- Once you get 4th version, you lose even older history
- Not standard practice

---

### SCD Type 1 vs 2 vs 3 Comparison

| Scenario | Type 1 | Type 2 | Type 3 |
|----------|--------|--------|--------|
| **Product changes name** | Overwrite name | Add new row | Add column |
| **Historical accuracy** | ❌ Lost | ✅ Perfect | ⚠️ Limited |
| **Storage** | Minimal | Large (more rows) | Medium (more columns) |
| **Query complexity** | Simple | Simple (SCD 2 handles it) | Moderate |
| **Use case** | Rare corrections | **Most common** | Analysis/comparison |
| **Recommendation** | Avoid | **Use this!** | Edge cases only |

**Best Practice:** Use SCD Type 2 for 99% of dimension changes.

---

## 4. Fact Table Types

### Transactional Fact Tables (Most Common)

**Grain:** One row per transaction at the lowest level of detail

```sql
-- Retail: One row per item purchased
SELECT * FROM fact_orders LIMIT 5;
-- order_id | line_item | order_date | customer_sk | product_sk | quantity | sales_amount
-- 1001     | 1         | 2025-03-27 | 5          | 123        | 1        | 29.99
-- 1001     | 2         | 2025-03-27 | 5          | 456        | 2        | 59.98
-- 1002     | 1         | 2025-03-27 | 8          | 789        | 1        | 14.99

-- Hospital: One row per procedure
SELECT * FROM fact_procedures LIMIT 5;
-- admission_id | procedure_id | admit_date | patient_sk | doctor_sk | procedure_cost
-- ADM001       | 1           | 2025-03-27 | 100       | 5        | 5000
-- ADM001       | 2           | 2025-03-27 | 100       | 6        | 3000
```

**Why detail level?**
- Aggregates naturally go up
- Can't go down without raw data
- SCD Type 2 works perfectly (join gets correct name at transaction time)

**Advantages:**
- Atomic and flexible
- Supports any analysis
- Queries aggregate upward efficiently

---

### Periodic Snapshot Fact Tables (Tracking State Over Time)

**Grain:** One row per dimension combination per period (daily, monthly, etc.)

**Use:** Tracking inventory, account balances, headcount, accumulating metrics

```sql
-- Daily inventory snapshot: One row per product per store per day
SELECT * FROM fact_daily_inventory LIMIT 5;
-- date_sk | product_sk | store_sk | quantity_on_hand | quantity_reserved | reorder_point
-- 20250327| 123        | 1        | 45              | 10               | 20
-- 20250327| 123        | 2        | 30              | 5                | 20
-- 20250327| 456        | 1        | 100             | 25               | 50

-- Monthly account balance: One row per account per month-end
SELECT * FROM fact_monthly_balances LIMIT 5;
-- date_sk | account_sk | balance | ytd_interest | ytd_fees
-- 20250308| 1000       | 25000  | 150         | 25
-- 20250308| 1001       | 50000  | 300         | 50
```

**Advantages:**
- Tracks state at specific times
- Good for trending and comparison
- More compact than storing all transactions

**Disadvantages:**
- Must regenerate each period
- Only know state at period boundaries

---

### Accumulating Snapshot Fact Tables (Multi-Stage Processes)

**Grain:** One row per business process instance (persists as process progresses)

**Use:** Orders going through fulfillment, claims being processed, projects being completed

```sql
-- Order lifecycle: One row per order, updated as it progresses
SELECT * FROM fact_order_accumulating LIMIT 3;
-- order_sk | order_date_sk | shipped_date_sk | delivered_date_sk | returned_date_sk
-- 1001     | 20250327     | 20250328        | 20250330          | NULL
-- 1002     | 20250327     | 20250329        | 20250401          | 20250410
-- 1003     | 20250327     | 20250328        | NULL              | NULL

-- UPDATE as order progresses:
UPDATE fact_order_accumulating 
SET delivered_date_sk = 20250330 
WHERE order_sk = 1003;

-- Query: How long between order and delivery?
SELECT 
    order_sk,
    delivered_date_sk - order_date_sk as days_to_delivery
FROM fact_order_accumulating
WHERE delivered_date_sk IS NOT NULL;
```

**Advantages:**
- Tracks entire workflow
- Can measure cycle time per stage
- One row per business event

---

## 5. Building an Enterprise Dimensional Model

### Step-by-Step Design Process

**1. Identify Business Processes** - What measurable events occur?

```
Retail Company:
- Customers purchase items (Orders)
- Customers return items (Returns)
- Inventory levels change (Inventory)
- Staff works shifts (Labor)
```

**2. Define Grains** - What exactly is one row?

```
Orders: One row per line item in order
Returns: One row per returned item
Inventory: One row per product-store combination per day
Labor: One row per employee-store-day shift
```

**3. Identify Dimensions** - What context matters?

```
Orders dimensions:
- Who? (dim_customers)
- What? (dim_products)
- Where? (dim_stores)
- When? (dim_date)
- How much? (measures: quantity, sales_amount)
```

**4. Choose Conformed Dimensions** - Reuse across processes

```
Shared:
- dim_date (used in all processes)
- dim_stores (used in Orders, Returns, Inventory, Labor)
- dim_products (used in Orders, Returns, Inventory)

Specific:
- dim_customers (Orders, Returns)
- dim_employees (Labor)
```

**5. Build the Bus Matrix** - Document all processes and shared dimensions

```
                    | Orders | Returns | Inventory | Labor |
dim_date            |   ✓    |    ✓    |     ✓     |   ✓   |
dim_stores          |   ✓    |    ✓    |     ✓     |   ✓   |
dim_products        |   ✓    |    ✓    |     ✓     |   ✗   |
dim_customers       |   ✓    |    ✓    |     ✗     |   ✗   |
dim_employees       |   ✗    |    ✗    |     ✗     |   ✓   |
```

---

## 6. Practical Example: Retail Data Warehouse

### Complete Schema Design

**FACT_ORDERS** (Transactional)
- Grain: One row per line item purchase
- Primary Key: order_sk, line_item_sk
- Foreign Keys: order_date_sk, customer_sk, product_sk, store_sk
- Measures: quantity, sales_amount, discount_amount, profit_amount

```sql
CREATE TABLE fact_orders (
    order_sk INT,
    line_item_sk INT,
    order_date_sk INT,
    customer_sk INT,
    product_sk INT,
    store_sk INT,
    PRIMARY KEY (order_sk, line_item_sk),
    quantity INT,
    sales_amount DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    profit_amount DECIMAL(10,2)
);
```

**DIM_CUSTOMERS** (SCD Type 2)
- Grain: One row per unique customer version
- Surrogate Key: customer_sk (changes with SCD Type 2)
- Natural Key: customer_id (stable across versions)

```sql
CREATE TABLE dim_customers (
    customer_sk INT PRIMARY KEY,
    customer_id VARCHAR(20),
    customer_name VARCHAR(100),
    customer_segment VARCHAR(50),
    state VARCHAR(2),
    region VARCHAR(20),
    scd_effective_date DATE,
    scd_end_date DATE,
    scd_version INT
);
```

**DIM_PRODUCTS** (SCD Type 2)
```sql
CREATE TABLE dim_products (
    product_sk INT PRIMARY KEY,
    product_id VARCHAR(20),
    product_name VARCHAR(100),
    category VARCHAR(50),
    subcategory VARCHAR(50),
    brand VARCHAR(50),
    price DECIMAL(8,2),
    scd_effective_date DATE,
    scd_end_date DATE,
    scd_version INT
);
```

**DIM_STORES** (SCD Type 1)
```sql
CREATE TABLE dim_stores (
    store_sk INT PRIMARY KEY,
    store_id VARCHAR(20),
    store_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(2),
    region VARCHAR(20),
    store_type VARCHAR(20),
    manager_name VARCHAR(100)
);
```

**DIM_DATE** (Conformed dimension)
```sql
CREATE TABLE dim_date (
    date_sk INT PRIMARY KEY,
    calendar_date DATE UNIQUE,
    day_of_week INT,
    day_name VARCHAR(10),
    month INT,
    month_name VARCHAR(10),
    quarter INT,
    year INT,
    fiscal_year INT,
    is_holiday BOOLEAN
);
```

### Example Query

```sql
-- "What are sales trends by region and product category?"
SELECT 
    dd.year,
    dd.month_name,
    ds.region,
    dp.category,
    COUNT(DISTINCT fo.order_sk) as order_count,
    SUM(fo.quantity) as total_quantity,
    SUM(fo.sales_amount) as total_sales,
    ROUND(SUM(fo.profit_amount) / SUM(fo.sales_amount), 4) as profit_margin
FROM fact_orders fo
INNER JOIN dim_date dd ON fo.order_date_sk = dd.date_sk
INNER JOIN dim_stores ds ON fo.store_sk = ds.store_sk
INNER JOIN dim_products dp ON fo.product_sk = dp.product_sk
WHERE dd.year = 2024
  AND ds.region IN ('Northeast', 'Midwest')
GROUP BY dd.year, dd.month_name, ds.region, dp.category
ORDER BY year, month, region, category;
```

---

## Hands-On Design Labs

### Lab 1: Design Hospital Dimensional Model (60 minutes)

**Scenario:** Hospital wants to analyze patient admissions and procedures

**Business Events:**
- Patient admitted to hospital
- Patient undergoes medical procedures
- Patient receives medications

**Your Tasks:**
1. Define grain for each fact table
2. Identify all necessary dimensions
3. Create the bus matrix
4. Design 3 dimension tables with appropriate SCD strategy
5. List measures to store in each fact table

**Expected Deliverable:**

**Fact_Admissions Grain:** "One row per patient admission"
**Fact_Procedures Grain:** "One row per procedure performed during admission"
**Dimensions:** dim_patients (SCD Type 2), dim_doctors (SCD Type 1), dim_procedures_catalog (SCD Type 1), dim_hospitals (SCD Type 1), dim_date

---

### Lab 2: Implement SCD Type 2 (90 minutes)

**Scenario:** Product dimension needs SCD Type 2 implementation

**Starting Data:**
```
Current dim_products:
product_sk | product_id | name       | category  | price
1          | P001       | Widget A   | Tools     | 29.99
2          | P002       | Gadget B   | Gadgets   | 49.99
```

**Changes to Process:**
1. Widget A price changes from $29.99 to $34.99 (effective 2025-03-27)
2. Gadget B is recategorized from "Gadgets" to "Accessories"

**Tasks:**
1. Add SCD columns to dimension table
2. Write SQL to implement both changes with SCD Type 2
3. Write query showing product name at date of order (March 20, 2025)
4. Write query showing product name at current date
5. Show how fact table naturally gets correct names

---

## Summary

✅ **Kimball Methodology:** Business process → Grain → Dimensions → Facts  
✅ **Star Schema:** One fact, multiple dimensions (most common)  
✅ **Surrogate Keys:** Use in fact tables for performance  
✅ **Conformed Dimensions:** Share dimensions across facts  
✅ **SCD Type 1:** Overwrite (rare)  
✅ **SCD Type 2:** Add row with dates (most common!)  
✅ **SCD Type 3:** Add column (edge cases)  
✅ **Fact Types:** Transactional (detail), Snapshot (state), Accumulating (process)  
✅ **Bus Matrix:** Plan your enterprise architecture  

---

## Next Steps

- 👉 **Next Module:** [Hands-On Setup](./04-hands-on-setup.md)
  - Set up free tier accounts on all platforms
  - Load sample data
  - Run first dimensional queries

- 📖 **Further Reading:**
  - Ralph Kimball, "The Data Warehouse Toolkit" (Chapters 2-5)
  - "Mastering Data Warehouse Design" by Claudia Imhoff

---

*Last Updated: March 2026*
