# SQL Data Warehouse Project (`Datawarehouse`)

An end-to-end **Medallion Architecture** (`bronze`, `silver`, `gold`) data warehouse built in **SQL Server** for CRM and ERP datasets.

---

## Architecture Overview

```text
+-----------------------------------------------------------------------+
|                           Raw CSV Sources                             |
|         CRM (customers, interactions, support_tickets)                |
|         ERP (orders, order_items, products)                           |
+-----------------------------------+-----------------------------------+
                                    |
                                    v
+-----------------------------------------------------------------------+
|                       BRONZE LAYER (bronze.*)                         |
|  - Fast, resilient staging layer using NVARCHAR(50) to prevent bulk-  |
|    load type, decimal, and date conversion errors                     |
+-----------------------------------+-----------------------------------+
                                    |
                                    v  silver.load_silver
+-----------------------------------------------------------------------+
|                       SILVER LAYER (silver.*)                         |
|  - Trimmed, standardized strings, statuses, and categories            |
|  - Decimal-to-INT & DATETIME2 casting (TRY_CAST / TRY_CONVERT)        |
|  - Customer deduplication via ROW_NUMBER()                            |
|  - Audit metadata column (dwh_create_date)                            |
+-----------------------------------+-----------------------------------+
                                    |
                                    v  ddl_gold.sql
+-----------------------------------------------------------------------+
|                        GOLD LAYER (gold.*)                            |
|  - Star-schema analytical views ready for BI & reporting:             |
|    * Dimensions: gold.dim_customers, gold.dim_products                |
|    * Facts:      gold.fact_sales, gold.fact_interactions,             |
|                  gold.fact_support_tickets                            |
+-----------------------------------------------------------------------+
