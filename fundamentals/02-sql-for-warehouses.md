# SQL for Data Warehouses

## Learning Outcomes

By completing this module, you should be able to:
- Write efficient SELECT queries using proper filtering and joins
- Use advanced JOINs appropriately for warehouse scenarios
- Master window functions for ranking, running totals, and time-series analysis
- Build complex queries using Common Table Expressions (CTEs)
- Understand query execution basics and identify performance issues
- Write queries that scale to billions of rows

**Estimated Time:** 4 hours (2 hours reading + 2 hours hands-on labs)  
**Prerequisites:** Module 1  
**Knowledge Assumed:** Basic SQL (SELECT, WHERE, JOIN, GROUP BY)

---

## 1. Foundations: SELECT, WHERE, and Basic Joins

### The SELECT Anatomy

Every SQL query follows this basic structure:

```sql
SELECT     ← Which columns?
FROM       ← Which table?
WHERE      ← Which rows?
GROUP BY   ← How to aggregate?
HAVING     ← Filter after grouping?
ORDER BY   ← Sort results?
LIMIT      ← How many rows?
```

**Warehouse Rule:** Always include `LIMIT` or `LIMIT 1000` while testing to avoid scanning billions of rows!

### JOINs in Warehouse Context

Joining is critical in warehouses since we store data in normalized dimensions.

**INNER JOIN** - Most common in analytics

```sql
-- Get orders with customer details
SELECT 
    o.order_id,
    o.order_date,
    c.customer_name,
    c.customer_segment,
    o.sales_amount
FROM fact_orders o
INNER JOIN dim_customers c ON o.customer_id = c.customer_id
WHERE o.order_date >= '2025-01-01'
LIMIT 1000;

-- Result: Only orders that have matching customers
-- (99.9% of rows match - this is normal in warehouses)
```

**LEFT JOIN** - When you want all rows from left table

```sql
-- Get all customers whether or not they made orders
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(o.order_id) as order_count,
    SUM(o.sales_amount) as total_spent
FROM dim_customers c
LEFT JOIN fact_orders o ON c.customer_id = o.customer_id
  AND o.order_date >= '2025-01-01'
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spent DESC NULLS LAST
LIMIT 1000;

-- Result: All customers, with NULL order counts if no orders
```

**When to Use:**
- INNER JOIN: Fact table to dimension (matches expected)
- LEFT JOIN: Dimension to fact (preserves all dimension rows)

### Query Performance Rule #1: Filter Early

❌ **Slow Query** (scans all 100M orders):
```sql
SELECT 
    YEAR(order_date) as year,
    SUM(sales_amount) as total_sales
FROM fact_orders
WHERE YEAR(order_date) = 2024
GROUP BY YEAR(order_date);

-- Why slow? Calculates YEAR() for every row before filtering
```

✅ **Fast Query** (scans only 2024 orders):
```sql
SELECT 
    YEAR(order_date) as year,
    SUM(sales_amount) as total_sales
FROM fact_orders
WHERE order_date >= '2024-01-01' 
  AND order_date < '2025-01-01'
GROUP BY YEAR(order_date);

-- Why fast? Filters before calculation (predicate pushdown)
```

---

## 2. Advanced JOINs and Multi-Table Logic

### Handling Multiple Facts with Same Dimension

**Scenario:** Get orders with customer AND store AND product info

```sql
SELECT 
    o.order_id,
    o.order_date,
    c.customer_name,
    c.customer_segment,
    s.store_name,
    s.region,
    p.product_name,
    p.category,
    o.quantity,
    o.sales_amount,
    o.profit_amount
FROM fact_orders o
INNER JOIN dim_customers c ON o.customer_id = c.customer_id
INNER JOIN dim_stores s ON o.store_id = s.store_id
INNER JOIN dim_products p ON o.product_id = p.product_id
WHERE o.order_date >= '2025-01-01'
  AND s.region = 'Northeast'
ORDER BY o.order_date DESC
LIMIT 1000;
```

**Key optimization:** Filter by region (s.region = 'Northeast') AFTER join but implicit in WHERE clause, letting optimizer push this filter down.

### Self-Joins: Comparing Within Same Table

**Scenario:** Find products that are in the same category but have different prices

```sql
SELECT 
    p1.product_id,
    p1.product_name,
    p2.product_id,
    p2.product_name,
    p1.price,
    p2.price,
    ABS(p1.price - p2.price) as price_difference
FROM dim_products p1
INNER JOIN dim_products p2 
    ON p1.category = p2.category 
    AND p1.product_id < p2.product_id  -- Avoid duplicates
WHERE p1.price != p2.price
  AND ABS(p1.price - p2.price) > 50
ORDER BY price_difference DESC
LIMIT 100;
```

**Why p1.product_id < p2.product_id?** To avoid getting the same pair twice: (123, 456) and (456, 123).

---

## 3. Window Functions: The Analytics Superpower

Window functions are **the most important** SQL pattern for warehouse analytics. They let you calculate rankings, running totals, and comparisons without GROUP BY.

### Core Window Functions

**Pattern:** `FUNCTION() OVER (PARTITION BY ... ORDER BY ...)`

#### ROW_NUMBER(): Unique ranking with ties broken

```sql
SELECT 
    order_date,
    customer_id,
    sales_amount,
    ROW_NUMBER() OVER (
        PARTITION BY DATE(order_date)  -- Restart for each day
        ORDER BY sales_amount DESC      -- Order by amount (highest first)
    ) as rank_by_sales
FROM fact_orders
WHERE order_date >= '2025-01-01'
ORDER BY order_date, rank_by_sales
LIMIT 100;

-- Output:
-- 2025-01-01, customer_5, $599, rank=1  (highest sale today)
-- 2025-01-01, customer_8, $399, rank=2
-- 2025-01-01, customer_3, $299, rank=3
-- 2025-01-02, customer_1, $499, rank=1  (resets for new day!)
```

#### RANK(): Ranking with ties getting same rank

```sql
SELECT 
    customer_id,
    order_date,
    sales_amount,
    RANK() OVER (
        PARTITION BY customer_id
        ORDER BY sales_amount DESC
    ) as sales_rank
FROM fact_orders
WHERE order_date >= '2024-01-01'
ORDER BY customer_id, sales_rank
LIMIT 100;

-- Output:
-- customer_1, 2025-01-15, $500, rank=1
-- customer_1, 2025-01-10, $500, rank=1  (Same amount, ties get same rank!)
-- customer_1, 2025-01-05, $300, rank=3  (Next rank is 3, not 2)
```

#### LAG() / LEAD(): Previous/next row value

```sql
SELECT 
    customer_id,
    order_date,
    sales_amount,
    LAG(sales_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) as previous_order_amount,
    LEAD(sales_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) as next_order_amount,
    sales_amount - LAG(sales_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) as amount_change_from_previous
FROM fact_orders
WHERE order_date >= '2024-01-01'
ORDER BY customer_id, order_date
LIMIT 100;

-- Output:
-- customer_1, 2024-01-05, $100, NULL, $200, NULL
-- customer_1, 2024-02-05, $200, $100, $250, +$100  (grew from $100)
-- customer_1, 2024-03-05, $250, $200, $150, +$50
-- customer_1, 2024-04-05, $150, $250, NULL, -$100
```

#### SUM()/AVG() OVER: Running totals

```sql
SELECT 
    order_id,
    order_date,
    customer_id,
    sales_amount,
    SUM(sales_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as cumulative_sales,
    SUM(sales_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as sum_last_3_orders,
    AVG(sales_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
        ROWS BETWEEN 364 PRECEDING AND CURRENT ROW
    ) as avg_last_year
FROM fact_orders
WHERE order_date >= '2024-01-01'
ORDER BY customer_id, order_date
LIMIT 100;

-- Output:
-- customer_1, 2024-01-05, $100, cumulative=$100, last_3=$100, avg_year=$100
-- customer_1, 2024-02-05, $200, cumulative=$300, last_3=$300, avg_year=$150
-- customer_1, 2024-03-05, $150, cumulative=$450, last_3=$450, avg_year=$150
```

**Window Frame Syntax:**
- `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` = All rows up to this one
- `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` = Last 3 rows (2 before + current)
- `ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING` = All rows from here on

---

## 4. Common Table Expressions (CTEs)

CTEs let you write **readable, modular queries** by breaking them into named steps.

### Simple CTE

```sql
-- Step 1: Filter to 2024 orders
WITH orders_2024 AS (
    SELECT 
        order_id,
        customer_id,
        order_date,
        sales_amount
    FROM fact_orders
    WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
),

-- Step 2: Calculate customer totals
customer_totals AS (
    SELECT 
        customer_id,
        COUNT(*) as order_count,
        SUM(sales_amount) as total_sales,
        AVG(sales_amount) as avg_order_size,
        MAX(order_date) as most_recent_order
    FROM orders_2024
    GROUP BY customer_id
)

-- Step 3: Get results
SELECT 
    c.customer_id,
    c.customer_name,
    ct.order_count,
    ct.total_sales,
    ct.avg_order_size,
    CASE 
        WHEN ct.total_sales > 10000 THEN 'VIP'
        WHEN ct.total_sales > 1000 THEN 'Regular'
        ELSE 'New'
    END as customer_tier,
    DATEDIFF(day, ct.most_recent_order, CURRENT_DATE) as days_since_order
FROM customer_totals ct
INNER JOIN dim_customers c ON ct.customer_id = c.customer_id
ORDER BY total_sales DESC
LIMIT 100;
```

**Why use CTEs?**
1. **Readable:** Each step is named and clear
2. **Debuggable:** Test each CTE separately
3. **Reusable:** Reference same CTE twice if needed
4. **Modular:** Easy to add/remove steps

### Recursive CTE: Hierarchies

```sql
-- Find all products in hierarchy under category "Electronics"
WITH RECURSIVE product_hierarchy AS (
    -- Base case: Start with Electronics
    SELECT 
        category_id,
        category_name,
        parent_category_id,
        1 as depth
    FROM dim_product_categories
    WHERE category_name = 'Electronics'
    
    UNION ALL
    
    -- Recursive case: Find children of each category
    SELECT 
        dpc.category_id,
        dpc.category_name,
        dpc.parent_category_id,
        ph.depth + 1
    FROM dim_product_categories dpc
    INNER JOIN product_hierarchy ph 
        ON dpc.parent_category_id = ph.category_id
    WHERE ph.depth < 5  -- Prevent infinite loops
)

SELECT 
    REPEAT('  ', depth - 1) || category_name as category_tree,
    depth,
    category_id
FROM product_hierarchy
ORDER BY depth, category_name;

-- Output:
-- Electronics, depth=1
--   Computers, depth=2
--     Laptops, depth=3
--     Tablets, depth=3
--   Audio, depth=2
--     Headphones, depth=3
```

---

## 5. Query Execution and Performance

### Understanding Query Execution Plans

Every database executor creates a **query plan** showing:
1. What tables it will scan
2. What filters it will apply
3. What joins it will perform
4. In what order

Most important metrics:
- **Rows scanned:** How many input rows? (goal: minimize)
- **Rows filtered:** How many removed by WHERE? (goal: maximize)
- **Operations:** What are the expensive ones?

### EXPLAIN Command

```sql
-- View the execution plan (syntax varies by platform)
EXPLAIN
SELECT 
    o.order_id,
    c.customer_name,
    SUM(o.sales_amount) as total
FROM fact_orders o
INNER JOIN dim_customers c ON o.customer_id = c.customer_id
WHERE o.order_date >= '2025-01-01'
GROUP BY o.order_id, c.customer_name;

-- Output (varies by platform):
-- Aggregate [cost: 1500]
--   HashJoin [cost: 1200]  ← This is expensive!
--     TableScan fact_orders [cost: 500]
--       Filter: order_date >= '2025-01-01' [cost: 200]
--     TableScan dim_customers [cost: 200]
```

### Common Performance Pitfalls

**1. Filtering on calculated columns ❌**
```sql
-- BAD: Calculates YEAR() for every row before filtering
SELECT * FROM fact_orders 
WHERE YEAR(order_date) = 2024;

-- GOOD: Filters on raw column
SELECT * FROM fact_orders 
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';
```

**2. Joining on calculated columns ❌**
```sql
-- BAD: Recalculates customer segment for every join
SELECT * FROM fact_orders o
INNER JOIN (
    SELECT customer_id, 
        CASE WHEN annual_sales > 10000 THEN 'VIP' ELSE 'Standard' END as segment
    FROM dim_customers
) c ON o.customer_id = c.customer_id
WHERE c.segment = 'VIP';

-- GOOD: Segment already in dimension table
SELECT * FROM fact_orders o
INNER JOIN dim_customers c ON o.customer_id = c.customer_id
WHERE c.customer_segment = 'VIP';
```

**3. Selecting all columns ❌**
```sql
-- BAD with 500 columns
SELECT * FROM fact_orders;

-- GOOD: Only needed columns
SELECT order_id, customer_id, order_date, sales_amount 
FROM fact_orders;
```

---

## Hands-On Labs

### Lab 1: Master Window Functions (45 minutes)

**Dataset:** fact_sales table with columns:
- sale_id, sale_date, customer_id, product_id, quantity, amount

**Exercise 1:** For each day, rank products by revenue (highest first)
```sql
SELECT 
    sale_date,
    product_id,
    amount,
    -- YOUR WINDOW FUNCTION HERE
FROM fact_sales
WHERE sale_date >= '2025-01-01'
LIMIT 50;

-- Expected Output:
-- 2025-01-01, product_5, $5000, rank=1
-- 2025-01-01, product_8, $3000, rank=2
```

**Exercise 2:** Calculate running total sales per customer
```sql
SELECT 
    customer_id,
    sale_date,
    amount,
    -- YOUR RUNNING TOTAL HERE
FROM fact_sales
WHERE customer_id = 1001
ORDER BY sale_date;

-- Expected Output:
-- customer_1001, 2024-01-05, $100, cumulative=$100
-- customer_1001, 2024-02-05, $200, cumulative=$300
```

**Solution Key:**
Exercise 1:
```sql
SELECT 
    sale_date,
    product_id,
    amount,
    RANK() OVER (PARTITION BY sale_date ORDER BY amount DESC) as daily_rank
FROM fact_sales
```

Exercise 2:
```sql
SELECT 
    customer_id,
    sale_date,
    amount,
    SUM(amount) OVER (PARTITION BY customer_id ORDER BY sale_date) as cumulative_sales
FROM fact_sales
```

---

### Lab 2: Build Complex Multi-Step Query (60 minutes)

**Scenario:** Analyze customer purchase patterns

**Requirements:**
1. Get all orders from 2024
2. Calculate each customer's total and average order
3. Rank customers by total sales
4. Find when each customer's highest sale occurred
5. Calculate days since last purchase

**Starter Code:**
```sql
WITH orders_2024 AS (
    -- Step 1: Filter to 2024 orders
),

customer_stats AS (
    -- Step 2: Calculate customer totals and averages
),

customer_rank AS (
    -- Step 3: Rank customers by total sales
)

SELECT 
    -- Step 4-5: Final results with last purchase and days since
FROM ...;
```

**Expected Output Schema:**
- customer_name, total_sales, avg_order_size, sales_rank, largest_order_date, days_since_last_purchase

**Solution:** See [example solution](#lab-2-solution) at end of module

---

## Summary: Key SQL Patterns for Warehouses

✅ **SELECT-WHERE-GROUP-ORDER** structure with explicit LIMIT  
✅ **INNER JOIN** for fact-to-dimension (expected matches)  
✅ **LEFT JOIN** for dimension-to-fact (preserve all dimensions)  
✅ **Window Functions** (ROW_NUMBER, RANK, LAG/LEAD, SUM OVER) for analytics  
✅ **CTEs** to write readable, modular queries  
✅ **Filter early & often** for query performance  
✅ **Use EXPLAIN** to understand slow queries  

---

## Next Steps

- 👉 **Next Module:** [Dimensional Modeling](./03-dimensional-modeling.md)
  - Apply these SQL patterns to warehouse-optimized schemas
  - Design fact and dimension tables
  - Implement slowly changing dimensions

- 📖 **Further Reading:**
  - SQL Window Functions documentation for your platform
  - "SQL Performance Explained" by Markus Winand

---

## Lab 2 Solution

```sql
WITH orders_2024 AS (
    SELECT 
        customer_id,
        order_id,
        order_date,
        sales_amount
    FROM fact_orders
    WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
),

customer_stats AS (
    SELECT 
        customer_id,
        COUNT(*) as order_count,
        SUM(sales_amount) as total_sales,
        AVG(sales_amount) as avg_order_size,
        MAX(order_date) as last_order_date,
        MAX(sales_amount) as largest_order_amount
    FROM orders_2024
    GROUP BY customer_id
),

customer_rank AS (
    SELECT 
        cs.customer_id,
        cs.order_count,
        cs.total_sales,
        cs.avg_order_size,
        cs.last_order_date,
        cs.largest_order_amount,
        RANK() OVER (ORDER BY cs.total_sales DESC) as sales_rank
    FROM customer_stats cs
),

largest_order_dates AS (
    SELECT 
        customer_id,
        order_date as largest_order_date
    FROM orders_2024
    WHERE sales_amount = (
        SELECT MAX(sales_amount) 
        FROM orders_2024 o2 
        WHERE o2.customer_id = orders_2024.customer_id
    )
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) = 1
)

SELECT 
    c.customer_name,
    cr.total_sales,
    ROUND(cr.avg_order_size, 2) as avg_order_size,
    cr.sales_rank,
    cr.order_count,
    lod.largest_order_date,
    DATEDIFF(day, cr.last_order_date, CURRENT_DATE) as days_since_last_purchase
FROM customer_rank cr
INNER JOIN dim_customers c ON cr.customer_id = c.customer_id
LEFT JOIN largest_order_dates lod ON cr.customer_id = lod.customer_id
ORDER BY sales_rank
LIMIT 100;
```

*Last Updated: March 2026*
