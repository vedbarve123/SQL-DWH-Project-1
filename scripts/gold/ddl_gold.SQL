/*
================================================================================================================
DDL Script : Create Golden Layer
================================================================================================================

Script Purpose:
This script creates golden layer for our Data warehouse. We create two dimension tables and one fact table.
We follow Star Schema in making our golden layer.

Each view performs transformations and combines data from various silver layer tables to finally create 
clean business ready gold layer.

Usage:
These views can be queried directly.

=================================================================================================================
*/

======================================================================================================
--Create dimension : gold.dim_customers
======================================================================================================
CREATE VIEW gold.dim_customers AS
SELECT 
ROW_NUMBER() OVER(ORDER BY ci.cst_id) AS customer_key,
ci.cst_id AS customer_id,
ci.cst_key AS customer_number,
ci.cst_firstname AS first_name,
ci.cst_lastname AS last_name,
la.CNTRY AS country,
ci.cst_marital_status AS marital_status,
CASE WHEN ci.cst_gndr!='n/a' THEN ci.cst_gndr
	 ELSE COALESCE(ca.GEN,'n/a') END AS gender,
ca.BDATE AS birthdate,
ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_CUST_AZ12 ca
ON ci.cst_key=ca.CID
LEFT JOIN silver.erp_LOC_A101 la
ON ci.cst_key=la.CID

======================================================================================================
--Create dimension : gold.dim_products
======================================================================================================

CREATE VIEW gold.dim_products AS
SELECT 
ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt,pn.prd_key) AS product_key,
pn.prd_id AS product_id,
pn.prd_key AS product_number,
pn.prd_nm AS product_name,
pn.cat_id AS category_id,
pc.CAT AS category,
pc.SUBCAT AS subcategory,
pc.MAINTENANCE AS maintenance,
pn.prd_cost AS cost,
pn.prd_line AS product_line,
pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_PX_CAT_G1V2 pc
ON pc.ID=pn.cat_id
WHERE pn.prd_end_dt IS NULL							--Filter out all historical data

======================================================================================================
--Create fact : gold.fact_sales
======================================================================================================

CREATE VIEW gold.fact_sales AS
SELECT  
sd.sls_ord_num AS order_number,
pr.product_key,
cu.customer_key,
sd.sls_order_dt AS order_date,
sd.sls_ship_dt AS shipping_date,
sd.sls_due_dt AS due_date,
sd.sls_sales AS sales_amount,
sd.sls_quantity AS quantity,
sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr 
ON sd.sls_prd_key=pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id=cu.customer_id
