--Checking for duplicate values in Primary Key column
--Expectation:No Duplicates and no null values

SELECT prd_id,count(*) FROM silver.crm_prd_info
GROUP BY prd_id
HAVING count(*)>1 OR prd_id IS NULL

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
