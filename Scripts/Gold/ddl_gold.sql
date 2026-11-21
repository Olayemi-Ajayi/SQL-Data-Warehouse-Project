/*==============================================================================
DDL Script: Create Gold Layer (Star Schema)
Database:   Datawarehouse
Schema:     gold
Purpose:    Dimensions are stored TABLES with stable surrogate keys (IDENTITY).
            Facts are VIEWS that look up those keys from the dimensions.

Run order:  1. ddl_gold.sql           (this script)
            2. EXEC gold.load_gold;   (fills and updates the dimensions)
            3. quality_checks.sql

Notes:
  - Dimension tables are created only if they do not already exist, so
    re-running this script KEEPS existing data and surrogate keys.
    To rebuild from scratch, drop the dimension tables manually first.
  - Each dimension has an "Unknown" member with key -1. Facts that cannot be
    matched to a dimension row point at -1 instead of holding NULL keys.
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
-- 1. gold.dim_customers (table)
--------------------------------------------------------------------------------
-- Replace the old view version if it still exists
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

IF OBJECT_ID('gold.dim_customers', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_customers (
        customer_key    INT IDENTITY(1, 1) NOT NULL
                        CONSTRAINT PK_dim_customers PRIMARY KEY,
        customer_id     INT NOT NULL
                        CONSTRAINT UQ_dim_customers_customer_id UNIQUE,
        first_name      NVARCHAR(100),
        last_name       NVARCHAR(100),
        full_name       NVARCHAR(201),
        email           NVARCHAR(255),
        signup_date     DATE,
        signup_year     INT,
        signup_month    INT,
        dwh_create_date DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        dwh_update_date DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END;
GO

-- Unknown member (key -1)
IF NOT EXISTS (SELECT 1 FROM gold.dim_customers WHERE customer_key = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_customers ON;

    INSERT INTO gold.dim_customers (customer_key, customer_id, first_name, last_name, full_name)
    VALUES (-1, -1, 'Unknown', 'Unknown', 'Unknown');

    SET IDENTITY_INSERT gold.dim_customers OFF;
END;
GO

--------------------------------------------------------------------------------
-- 2. gold.dim_products (table)
--------------------------------------------------------------------------------
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

IF OBJECT_ID('gold.dim_products', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_products (
        product_key      INT IDENTITY(1, 1) NOT NULL
                         CONSTRAINT PK_dim_products PRIMARY KEY,
        product_id       INT NOT NULL
                         CONSTRAINT UQ_dim_products_product_id UNIQUE,
        product_name     NVARCHAR(150),
        product_category NVARCHAR(100),
        unit_price       DECIMAL(18, 2),   -- NULL when the source price is missing or invalid
        is_price_valid   BIT,
        dwh_create_date  DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        dwh_update_date  DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END;
GO

-- Unknown member (key -1)
IF NOT EXISTS (SELECT 1 FROM gold.dim_products WHERE product_key = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_products ON;

    INSERT INTO gold.dim_products (product_key, product_id, product_name, product_category, unit_price, is_price_valid)
    VALUES (-1, -1, 'Unknown', 'uncategorized', NULL, 0);

    SET IDENTITY_INSERT gold.dim_products OFF;
END;
GO

--------------------------------------------------------------------------------
-- 3. gold.fact_sales (view, order line grain)
--------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.fact_sales AS
SELECT
    oi.order_item_id,
    oi.order_id,
    COALESCE(dc.customer_key, -1)  AS customer_key,
    COALESCE(dp.product_key, -1)   AS product_key,
    CAST(o.order_date AS DATE)     AS order_date,
    o.order_date                   AS order_datetime,
    o.order_status,
    oi.quantity,
    dp.unit_price,
    COALESCE(dp.is_price_valid, 0) AS is_price_valid,
    CAST(oi.quantity * dp.unit_price AS DECIMAL(18, 2)) AS line_total_amount
FROM silver.erp_order_items oi
LEFT JOIN silver.erp_orders o
    ON oi.order_id = o.order_id
LEFT JOIN gold.dim_customers dc
    ON o.customer_id = dc.customer_id
LEFT JOIN gold.dim_products dp
    ON oi.product_id = dp.product_id;
GO

--------------------------------------------------------------------------------
-- 4. gold.fact_interactions (view)
--------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.fact_interactions AS
SELECT
    i.interaction_id,
    COALESCE(dc.customer_key, -1) AS customer_key,
    i.channel,
    i.status
FROM silver.crm_interactions i
LEFT JOIN gold.dim_customers dc
    ON i.customer_id = dc.customer_id;
GO

--------------------------------------------------------------------------------
-- 5. gold.fact_support_tickets (view)
--------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.fact_support_tickets AS
SELECT
    t.tickets_id AS ticket_id,
    COALESCE(dc.customer_key, -1) AS customer_key,
    t.issue_category,
    t.priority
FROM silver.crm_support_tickets t
LEFT JOIN gold.dim_customers dc
    ON t.customer_id = dc.customer_id;
GO
