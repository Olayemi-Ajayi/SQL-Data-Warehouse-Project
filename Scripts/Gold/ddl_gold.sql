/*==============================================================================
DDL Script: Create Gold Layer Views (Star Schema)
Database: Datawarehouse
Schema:   gold
Purpose:  Exposes business-ready dimension and fact views built on top of
          cleaned Silver CRM and ERP tables.
==============================================================================*/

USE Datawarehouse;
GO

-- Ensure gold schema exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END;
GO

--------------------------------------------------------------------------------
-- 1. gold.dim_customers
--------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
    customer_id,
    first_name,
    last_name,
    LTRIM(RTRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, '')))) AS full_name,
    email,
    CAST(signup_date AS DATE) AS signup_date,
    YEAR(signup_date) AS signup_year,
    MONTH(signup_date) AS signup_month
FROM silver.crm_customers;
GO

--------------------------------------------------------------------------------
-- 2. gold.dim_products
--------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id) AS product_key,
    product_id,
    product_name,
    COALESCE(NULLIF(category, ''), 'uncategorized') AS product_category,
    price AS unit_price
FROM silver.erp_products;
GO

--------------------------------------------------------------------------------
-- 3. gold.fact_sales (Order Line Grain)
--------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.fact_sales AS
SELECT
    oi.order_item_id,
    oi.order_id,
    o.customer_id,
    oi.product_id,
    CAST(o.order_date AS DATE) AS order_date,
    o.order_date AS order_datetime,
    o.order_status,
    oi.quantity,
    p.price AS unit_price,
    CAST(oi.quantity * COALESCE(p.price, 0) AS DECIMAL(18, 2)) AS line_total_amount
FROM silver.erp_order_items oi
LEFT JOIN silver.erp_orders o
    ON oi.order_id = o.order_id
LEFT JOIN silver.erp_products p
    ON oi.product_id = p.product_id;
GO

--------------------------------------------------------------------------------
-- 4. gold.fact_interactions
--------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.fact_interactions AS
SELECT
    interaction_id,
    customer_id,
    channel,
    status
FROM silver.crm_interactions;
GO

--------------------------------------------------------------------------------
-- 5. gold.fact_support_tickets
--------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.fact_support_tickets AS
SELECT
    tickets_id AS ticket_id,
    customer_id,
    issue_category,
    priority
FROM silver.crm_support_tickets;
GO
