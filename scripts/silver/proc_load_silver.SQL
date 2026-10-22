/*
============================================================================================================
STORED PROCEDURE : LOADING SILVER LAYER(bronze -> silver)
============================================================================================================

Script Purpose:
This script truncates the tables in the 'silver' schema and inserts data from the bronze tables.
It does not take any parameters and it does not return any values.


*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	 DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME,@batch_end_time DATETIME;
	 BEGIN TRY
		SET @batch_start_time=GETDATE();
		PRINT '====================================================';
		PRINT 'Loading Silver Layer';
		PRINT '====================================================';

		PRINT '-----------------------------------------------------';
		PRINT 'Loading CRM tables';
		PRINT '-----------------------------------------------------';

		
		SET @start_time=GETDATE();

		PRINT '>> Truncating table silver.crm_cust_info'
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting data into table silver.crm_cust_info'
		INSERT INTO silver.crm_cust_info(
		cst_id,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gndr,
		cst_create_date
		)
		SELECT 
		cst_id,
		cst_key,
		TRIM(cst_firstname) as cst_firstname,
		TRIM(cst_lastname) as cst_lastname,
		CASE WHEN UPPER(TRIM(cst_marital_status))='S' THEN 'Single'			--Short form -> Full form
			 WHEN UPPER(TRIM(cst_marital_status))='M' THEN 'Married'
			 ELSE 'n/a' 
		END as cst_marital_status,
		CASE WHEN UPPER(TRIM(cst_gndr))='F' THEN 'Female'					--Short form -> Full form
			 WHEN UPPER(TRIM(cst_gndr))='M' THEN 'Male'
			 ELSE 'n/a' 
		END as cst_gndr,
		cst_create_date 
		FROM
		(SELECT *, 
		ROW_NUMBER() OVER(partition by cst_id ORDER BY cst_create_date DESC) as flag_last	--Deduping and taking latest cust enrollment date
		FROM bronze.crm_cust_info)t
		WHERE flag_last=1 and cst_id IS NOT NULL

		SET @end_time=GETDATE();

		PRINT '>>Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '-------------------------------------------------------------------------';

		
		-----------------------------------------------------------------------------------------------------------

		SET @start_time=GETDATE();

		PRINT '>> Truncating table silver.crm_prd_info'
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting data into table silver.crm_prd_info'
		INSERT INTO silver.crm_prd_info(
		prd_id,
		prd_key,
		cat_id,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
		)
		SELECT 
		prd_id,
		SUBSTRING(prd_key,7,LEN(prd_key)) AS prd_key,						--Making columns suitable for join operations
		REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id,
		prd_nm,
		ISNULL(prd_cost,0) AS prd_cost,
		CASE UPPER(TRIM(prd_line))
			 WHEN 'M' THEN 'Mountain'
			 WHEN 'R' THEN 'Road'
			 WHEN 'S' THEN 'Other Sales'
			 WHEN 'T' THEN 'Touring'
			 ELSE 'n/a'
		END AS prd_line,
		CAST(prd_start_dt AS DATE) AS prd_start_dt,									--Applying business rules to clean messy dates
		CAST(LEAD(prd_start_dt)OVER(PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info

		SET @end_time=GETDATE();

		PRINT '>>Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '-------------------------------------------------------------------------';
		
		----------------------------------------------------------------------------------------------------------------

		SET @start_time=GETDATE();

		PRINT '>> Truncating table silver.crm_sales_details'
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting data into table silver.crm_sales_details'
		;with cleaned_sales AS(SELECT 
		TRIM(sls_ord_num) AS sls_ord_num,
		TRIM(sls_prd_key) AS sls_prd_key,
		sls_cust_id,
		CASE WHEN len(sls_order_dt)!=8 OR sls_order_dt=0 THEN NULL
			 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
		END AS sls_order_dt,
		CASE WHEN len(sls_ship_dt)!=8 OR sls_ship_dt=0 THEN NULL
			 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
		END AS sls_ship_dt,
		CASE WHEN len(sls_due_dt)!=8 OR sls_due_dt=0 THEN NULL
			 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
		END AS sls_due_dt,
		CASE WHEN sls_sales IS NULL OR sls_sales<=0 OR sls_sales!=sls_quantity*sls_price
			 THEN sls_quantity*ABS(sls_price)
			 ELSE sls_sales
		END AS sls_sales,
		sls_quantity,
		sls_price
		FROM bronze.crm_sales_details)
		INSERT INTO silver.crm_sales_details(
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price
		)
		SELECT 
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		CASE WHEN sls_price IS NULL OR sls_price<=0
			 THEN sls_sales/NULLIF(sls_quantity,0)
			 ELSE sls_price
		END AS sls_price
		FROM cleaned_sales;

		SET @end_time=GETDATE();

		PRINT '>>Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '-------------------------------------------------------------------------';


		------------------------------------------------------------------------------------------------------------------

		SET @start_time=GETDATE();

		PRINT '-----------------------------------------------------';
		PRINT 'Loading ERP tables';
		PRINT '-----------------------------------------------------';

		PRINT '>> Truncating table silver.erp_CUST_AZ12'
		TRUNCATE TABLE silver.erp_CUST_AZ12;
		PRINT '>> Inserting data into table silver.erp_CUST_AZ12'
		INSERT INTO silver.erp_CUST_AZ12(
		CID,
		BDATE,
		GEN
		)
		SELECT
		CASE WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID,4,LEN(CID))
			 ELSE CID
		END AS CID,														--Remove 'NAS' prefix if present
		CASE WHEN BDATE > GETDATE() THEN NULL
			 ELSE CAST(BDATE AS DATE)
		END AS BDATE,													--Setting Birthdays in the future as NULL
		CASE WHEN UPPER(TRIM(GEN)) IN ('M','MALE') THEN 'Male'
			 WHEN UPPER(TRIM(GEN)) IN ('F','FEMALE') THEN 'Female'
			 ELSE 'n/a'
		END AS GEN														--Normalising Gender Values and handling unknown data 
		FROM bronze.erp_CUST_AZ12

		SET @end_time=GETDATE();

		PRINT '>>Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '-------------------------------------------------------------------------';


		---------------------------------------------------------------------------------------------------------------------

		SET @start_time=GETDATE();

		PRINT '>> Truncating table silver.erp_LOC_A101'
		TRUNCATE TABLE silver.erp_LOC_A101;
		PRINT '>> Inserting data into table silver.erp_LOC_A101'
		INSERT INTO silver.erp_LOC_A101(
		CID,
		CNTRY
		)
		SELECT 
		REPLACE(CID,'-','') AS CID,											--Removing '-' from CID column
		CASE WHEN TRIM(CNTRY)='DE' THEN 'Germany'
			 WHEN UPPER(TRIM(CNTRY)) IN ('US','USA','United States') THEN 'United States'
			 WHEN TRIM(CNTRY)='' OR CNTRY IS NULL THEN 'n/a'
			 ELSE TRIM(CNTRY)
		END AS CNTRY
		FROM bronze.erp_LOC_A101

		SET @end_time=GETDATE();

		PRINT '>>Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '-------------------------------------------------------------------------';


		-----------------------------------------------------------------------------------------------------------------

		SET @start_time=GETDATE();

		PRINT '>> Truncating table silver.erp_PX_CAT_G1V2'
		TRUNCATE TABLE silver.erp_PX_CAT_G1V2;
		PRINT '>> Inserting data into table silver.erp_PX_CAT_G1V2'
		INSERT INTO silver.erp_PX_CAT_G1V2(
		ID,
		CAT,
		SUBCAT,
		MAINTENANCE
		)
		SELECT 
		ID,
		TRIM(CAT) AS CAT,
		TRIM(SUBCAT) AS SUBCAT,
		TRIM(MAINTENANCE) AS MAINTENANCE
		FROM bronze.erp_PX_CAT_G1V2

		SET @end_time=GETDATE();

		PRINT '>>Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '-------------------------------------------------------------------------';

		SET @batch_end_time=GETDATE();
		PRINT '===========================================================================';
		PRINT 'Silver Layer Loading Completed Succesfully'
		PRINT '>>Total Load Duration: '+ CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS NVARCHAR) + 'seconds';
		PRINT '===========================================================================';
	 END TRY
	 BEGIN CATCH
		 PRINT '=====================================================================';
		 PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		 PRINT 'Error Message:'+ ERROR_MESSAGE();
		 PRINT 'Error Number:'+ CAST(ERROR_NUMBER() AS NVARCHAR);
		 PRINT 'Error State:'+ CAST(ERROR_STATE() AS NVARCHAR);
		 PRINT '=====================================================================';
	 END CATCH

END

