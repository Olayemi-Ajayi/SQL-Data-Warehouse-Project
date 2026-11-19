/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency,
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

--------------------------------------------------------------------------------
-- 1. SILVER LAYER: ROW COUNTS & KEY NULL / DUPLICATE CHECKS
--------------------------------------------------------------------------------
-- Customers
SELECT
    'silver.crm_customers' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_ids,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_customer_ids,
    SUM(CASE WHEN email IS NULL OR LTRIM(RTRIM(email)) = '' THEN 1 ELSE 0 END) AS blank_or_null_emails
FROM silver.crm_customers;

-- Products
SELECT
    'silver.erp_products' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_ids,
    COUNT(*) - COUNT(DISTINCT product_id) AS duplicate_product_ids,
    SUM(CASE WHEN price IS NULL OR price < 0 THEN 1 ELSE 0 END) AS null_or_negative_prices
FROM silver.erp_products;

-- Orders
SELECT
    'silver.erp_orders' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_ids,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_ids
FROM silver.erp_orders;

-- Order Items
SELECT
    'silver.erp_order_items' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS null_order_item_ids,
    COUNT(*) - COUNT(DISTINCT order_item_id) AS duplicate_order_item_ids,
    SUM(CASE WHEN quantity IS NULL OR quantity <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_qty
FROM silver.erp_order_items;

-- CRM Interactions & Support Tickets
SELECT
    'silver.crm_interactions' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN interaction_id IS NULL THEN 1 ELSE 0 END) AS null_interaction_ids,
    COUNT(*) - COUNT(DISTINCT interaction_id) AS duplicate_interaction_ids
FROM silver.crm_interactions;

SELECT
    'silver.crm_support_tickets' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN tickets_id IS NULL THEN 1 ELSE 0 END) AS null_ticket_ids,
    COUNT(*) - COUNT(DISTINCT tickets_id) AS duplicate_ticket_ids
FROM silver.crm_support_tickets;

--------------------------------------------------------------------------------
-- 2. SILVER REFERENTIAL INTEGRITY (ORPHAN FOREIGN KEYS)
--------------------------------------------------------------------------------
-- Order items with missing order header or missing product master
SELECT
    SUM(CASE WHEN o.order_id IS NULL THEN 1 ELSE 0 END) AS orphan_order_items_no_order,
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

