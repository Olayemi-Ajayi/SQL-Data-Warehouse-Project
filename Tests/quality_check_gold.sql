--------------------------------------------------------------------------------
-- 3. GOLD LAYER: RECONCILIATION & VALUE HYGIENE CHECKS
--------------------------------------------------------------------------------
-- Compare silver.erp_order_items count vs gold.fact_sales count
SELECT
    (SELECT COUNT(*) FROM silver.erp_order_items) AS silver_order_item_rows,
    (SELECT COUNT(*) FROM gold.fact_sales) AS gold_fact_sales_rows,
    (SELECT SUM(line_total_amount) FROM gold.fact_sales) AS gold_total_revenue;

-- Check dimension key uniqueness in Gold views
SELECT
    COUNT(*) AS dim_customers_rows,
    COUNT(DISTINCT customer_key) AS distinct_customer_keys,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids
FROM gold.dim_customers;

SELECT
    COUNT(*) AS dim_products_rows,
    COUNT(DISTINCT product_key) AS distinct_product_keys,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM gold.dim_products;

-- Inspect distinct categories & priorities for casing/typos (e.g., 'Biling')
SELECT DISTINCT
    'gold.dim_products.product_category' AS column_ref,
    product_category AS val,
    COUNT(*) AS row_count
FROM gold.dim_products
GROUP BY product_category

UNION ALL

SELECT DISTINCT
    'gold.fact_support_tickets.issue_category' AS column_ref,
    issue_category AS val,
    COUNT(*) AS row_count
FROM gold.fact_support_tickets
GROUP BY issue_category

UNION ALL

SELECT DISTINCT
    'gold.fact_support_tickets.priority' AS column_ref,
    priority AS val,
    COUNT(*) AS row_count
FROM gold.fact_support_tickets
GROUP BY priority
ORDER BY column_ref, row_count DESC;
