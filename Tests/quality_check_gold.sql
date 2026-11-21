3. GOLD LAYER: RECONCILIATION & VALUE HYGIENE CHECKS
Script Purpose:
    Validates the integrity, consistency, and accuracy of the Silver and Gold
    layers. The checks cover:
    - Null and duplicate keys in the Silver tables.
    - Orphan foreign keys between Silver tables.
    - Row reconciliation between Silver and Gold.
    - Uniqueness and completeness of the Gold dimensions (surrogate keys).
    - Referential integrity between Gold facts and dimensions.
    - Impact of missing or invalid prices on revenue.
    - Casing and typo problems in categorical columns.

Run order:
    1. ddl_gold.sql,   then EXEC gold.load_gold;
    2. This script.
-- Silver vs gold row counts (the two counts should be equal)
SELECT
    (SELECT COUNT(*) FROM silver.erp_order_items)        AS silver_order_item_rows,
    (SELECT COUNT(*) FROM gold.fact_sales)               AS gold_fact_sales_rows,
    (SELECT SUM(line_total_amount) FROM gold.fact_sales) AS gold_total_revenue;

-- Dimension key uniqueness (total rows should equal distinct keys and distinct ids).
-- Each dimension also holds one "Unknown" member (key -1), so rows = silver rows + 1.
SELECT
    COUNT(*) AS dim_customers_rows,
    COUNT(DISTINCT customer_key) AS distinct_customer_keys,
    COUNT(DISTINCT customer_id)  AS distinct_customer_ids,
    SUM(CASE WHEN customer_key = -1 THEN 1 ELSE 0 END) AS unknown_members,  -- expect 1
    (SELECT COUNT(*) FROM silver.crm_customers WHERE customer_id IS NOT NULL) + 1 AS expected_rows
FROM gold.dim_customers;

SELECT
    COUNT(*) AS dim_products_rows,
    COUNT(DISTINCT product_key) AS distinct_product_keys,
    COUNT(DISTINCT product_id)  AS distinct_product_ids,
    SUM(CASE WHEN product_key = -1 THEN 1 ELSE 0 END) AS unknown_members,  -- expect 1
    (SELECT COUNT(DISTINCT product_id) FROM silver.erp_products WHERE product_id IS NOT NULL) + 1 AS expected_rows
FROM gold.dim_products;

-- Silver rows missing from the dimensions (expect 0).
-- A value above 0 means EXEC gold.load_gold; has not been run since the last silver load.
SELECT
    (SELECT COUNT(*) FROM silver.crm_customers c
     WHERE c.customer_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM gold.dim_customers d WHERE d.customer_id = c.customer_id)) AS customers_missing_from_dim,
    (SELECT COUNT(DISTINCT p.product_id) FROM silver.erp_products p
     WHERE p.product_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM gold.dim_products d WHERE d.product_id = p.product_id))     AS products_missing_from_dim;

-- Facts pointing at the "Unknown" member (key -1), meaning the business id
-- had no dimension row (expect 0 for every row)
SELECT 'fact_sales -> dim_customers' AS check_name, COUNT(*) AS unknown_member_rows
FROM gold.fact_sales
WHERE customer_key = -1

UNION ALL

SELECT 'fact_sales -> dim_products', COUNT(*)
FROM gold.fact_sales
WHERE product_key = -1

UNION ALL

SELECT 'fact_interactions -> dim_customers', COUNT(*)
FROM gold.fact_interactions
WHERE customer_key = -1

UNION ALL

SELECT 'fact_support_tickets -> dim_customers', COUNT(*)
FROM gold.fact_support_tickets
WHERE customer_key = -1;

-- Revenue impact of missing or invalid prices (informational)
SELECT
    COUNT(*) AS total_order_lines,
    SUM(CASE WHEN is_price_valid = 0 THEN 1 ELSE 0 END) AS lines_without_valid_price,
    CAST(100.0 * SUM(CASE WHEN is_price_valid = 0 THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*), 0) AS DECIMAL(5, 2)) AS pct_lines_excluded_from_revenue
FROM gold.fact_sales;

-- Distinct values per categorical column, to spot casing issues and typos
-- (e.g. 'Biling'; 'Cancelled' and 'Canceled' should now appear as one value)
SELECT
    'gold.dim_products.product_category' AS column_ref,
    product_category AS val,
    COUNT(*) AS row_count
FROM gold.dim_products
GROUP BY product_category

UNION ALL

SELECT
    'gold.fact_support_tickets.issue_category',
    issue_category,
    COUNT(*)
FROM gold.fact_support_tickets
GROUP BY issue_category

UNION ALL

SELECT
    'gold.fact_support_tickets.priority',
    priority,
    COUNT(*)
FROM gold.fact_support_tickets
GROUP BY priority

UNION ALL

SELECT
    'gold.fact_sales.order_status',
    order_status,
    COUNT(*)
FROM gold.fact_sales
GROUP BY order_status

UNION ALL

SELECT
    'gold.fact_interactions.channel',
    channel,
    COUNT(*)
FROM gold.fact_interactions
GROUP BY channel

UNION ALL

SELECT
    'gold.fact_interactions.status',
    status,
    COUNT(*)
FROM gold.fact_interactions
GROUP BY status

ORDER BY column_ref, row_count DESC;
GO
