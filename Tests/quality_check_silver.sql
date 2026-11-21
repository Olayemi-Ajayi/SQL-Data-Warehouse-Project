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
    1. ddl_silver.sql, then EXEC silver.load_silver;
    2. This script.

Usage Notes:
    - Checks marked "expect 0" should return 0. Investigate any other value.
    - Checks marked "informational" report data quality, not failures.
===============================================================================
*/

USE Datawarehouse;
GO

--------------------------------------------------------------------------------
-- 1. SILVER LAYER: ROW COUNTS & KEY NULL / DUPLICATE CHECKS
--    Duplicates are counted as COUNT(col) - COUNT(DISTINCT col), so NULL ids
--    are reported in their own column and not counted as duplicates.
--------------------------------------------------------------------------------
-- Customers (expect 0 for null ids and duplicates)
SELECT
    'silver.crm_customers' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_ids,
    COUNT(customer_id) - COUNT(DISTINCT customer_id) AS duplicate_customer_ids,
    SUM(CASE WHEN email IS NULL OR LTRIM(RTRIM(email)) = '' THEN 1 ELSE 0 END) AS blank_or_null_emails  -- informational
FROM silver.crm_customers;

-- Products (expect 0 for null ids, duplicates, non-positive prices, flag mismatches)
-- A NULL flag also counts as a mismatch: it means silver was loaded with an old procedure.
SELECT
    'silver.erp_products' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_ids,
    COUNT(product_id) - COUNT(DISTINCT product_id) AS duplicate_product_ids,
    SUM(CASE WHEN price IS NOT NULL AND price <= 0 THEN 1 ELSE 0 END) AS non_positive_prices,
    SUM(CASE WHEN is_price_valid IS NULL
               OR (price IS NULL     AND is_price_valid = 1)
               OR (price IS NOT NULL AND is_price_valid = 0) THEN 1 ELSE 0 END) AS price_flag_mismatches,
    SUM(CASE WHEN is_price_valid = 0 THEN 1 ELSE 0 END) AS products_flagged_invalid_price  -- informational
FROM silver.erp_products;

-- Orders (expect 0 for null ids and duplicates)
SELECT
    'silver.erp_orders' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_ids,
    COUNT(order_id) - COUNT(DISTINCT order_id) AS duplicate_order_ids,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_ids,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_dates  -- informational
FROM silver.erp_orders;

-- Order items (expect 0 for null ids, duplicates, and zero or negative quantities)
SELECT
    'silver.erp_order_items' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS null_order_item_ids,
    COUNT(order_item_id) - COUNT(DISTINCT order_item_id) AS duplicate_order_item_ids,
    SUM(CASE WHEN quantity IS NULL OR quantity <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_qty
FROM silver.erp_order_items;

-- CRM interactions (expect 0 for null ids and duplicates)
SELECT
    'silver.crm_interactions' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN interaction_id IS NULL THEN 1 ELSE 0 END) AS null_interaction_ids,
    COUNT(interaction_id) - COUNT(DISTINCT interaction_id) AS duplicate_interaction_ids
FROM silver.crm_interactions;

-- CRM support tickets (expect 0 for null ids and duplicates)
SELECT
    'silver.crm_support_tickets' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN tickets_id IS NULL THEN 1 ELSE 0 END) AS null_ticket_ids,
    COUNT(tickets_id) - COUNT(DISTINCT tickets_id) AS duplicate_ticket_ids
FROM silver.crm_support_tickets;

--------------------------------------------------------------------------------
-- 2. SILVER REFERENTIAL INTEGRITY (ORPHAN FOREIGN KEYS)
--    Expect 0 everywhere. Orphans point at the "Unknown" member (key -1)
--    in the gold facts.
--------------------------------------------------------------------------------
-- Order items with missing order header or missing product master
SELECT
    SUM(CASE WHEN o.order_id IS NULL THEN 1 ELSE 0 END)   AS orphan_order_items_no_order,
    SUM(CASE WHEN p.product_id IS NULL THEN 1 ELSE 0 END) AS orphan_order_items_no_product
FROM silver.erp_order_items oi
LEFT JOIN silver.erp_orders o
    ON oi.order_id = o.order_id
LEFT JOIN silver.erp_products p
    ON oi.product_id = p.product_id;

-- Orders referencing customers not in silver.crm_customers
SELECT
    COUNT(*) AS orders_with_missing_customer
FROM silver.erp_orders o
LEFT JOIN silver.crm_customers c
    ON o.customer_id = c.customer_id
WHERE o.customer_id IS NOT NULL
  AND c.customer_id IS NULL;

-- Interactions and tickets referencing customers not in silver.crm_customers
SELECT
    (SELECT COUNT(*)
     FROM silver.crm_interactions i
     LEFT JOIN silver.crm_customers c ON i.customer_id = c.customer_id
     WHERE i.customer_id IS NOT NULL AND c.customer_id IS NULL) AS interactions_with_missing_customer,
    (SELECT COUNT(*)
     FROM silver.crm_support_tickets t
     LEFT JOIN silver.crm_customers c ON t.customer_id = c.customer_id
     WHERE t.customer_id IS NOT NULL AND c.customer_id IS NULL) AS tickets_with_missing_customer;
