/*
============================================================================================================
QUALITY CHECK DOCUMENT (SILVER LAYER)
============================================================================================================

Script Purpose:
This script is used to check the quality of tables created in the silver schema. We want to see
if the transformations have worked and there is no improper data. The basic codes are given 
we can change the table names , column names for using a code with various tables.
A newer more organised version is coming in next commits.

*/


--Checking for duplicate values in Primary Key column
--Expectation:No Duplicates and no null values

SELECT cst_id,count(*) as dups FROM silver.crm_cust_info
GROUP BY cst_id
HAVING count(*)>1 OR cst_id IS NULL

--Check for unwanted spaces

SELECT prd_nm FROM silver.crm_prd_info
WHERE prd_nm!=TRIM(prd_nm)

SELECT cst_lastname FROM silver.crm_cust_info
WHERE cst_lastname!=TRIM(cst_lastname)

--Data Standardization and Consistency

SELECT DISTINCT cst_gndr FROM silver.crm_cust_info

SELECT DISTINCT cst_marital_status FROM silver.crm_cust_info

SELECT DISTINCT prd_line FROM silver.crm_prd_info

--Check for Invalid Date Orders

SELECT * FROM silver.crm_prd_info
WHERE prd_start_dt>prd_end_dt


--Check for NULLs or negative numbers

SELECT * FROM silver.crm_prd_info
WHERE prd_cost<0 OR prd_cost IS NULL


--Check for Invalid Dates 
SELECT sls_order_dt FROM silver.crm_sales_details
WHERE
len(sls_order_dt)!=8

SELECT * FROM silver.crm_sales_details
WHERE sls_order_dt>sls_ship_dt OR sls_order_dt>sls_due_dt 

--Sales should be equal to Quantity multiplied by Price
--Cannot be NULL,zero and (-)ve
SELECT * FROM silver.crm_sales_details
WHERE sls_sales!=sls_quantity*sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <=0 OR sls_quantity <=0 OR sls_price <=0


--Checking values for Low Cardinality Columns
SELECT  GEN,COUNT(*) FROM silver.erp_CUST_AZ12
GROUP BY GEN


--Checking for weird dates
SELECT * FROM silver.erp_CUST_AZ12
WHERE BDATE>GETDATE()

--Checking for messy locations
SELECT DISTINCT CNTRY FROM silver.erp_LOC_A101
SELECT * FROM silver.erp_LOC_A101
