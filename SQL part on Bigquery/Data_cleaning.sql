CREATE OR REPLACE TABLE `finance-ad-hoc.payment_analytics.merchants_clean` AS

-- STEP 1: Fix inconsistent merchant_id format (should always be "M" + 6 digits)
WITH step1_fix_id_format AS (
  SELECT
    *,
    CASE
      WHEN REGEXP_CONTAINS(merchant_id, r'^M\d{6}$') THEN merchant_id             
      WHEN REGEXP_CONTAINS(merchant_id, r'^\d{6}$') THEN CONCAT('M', merchant_id)  
      ELSE merchant_id                                                           
    END AS merchant_id_fixed
  FROM `finance-ad-hoc.payment_analytics.raw_merchants`
),

-- STEP 2: Standardize text fields (trim stray spaces)
step2_standardize_text AS (
  SELECT
    merchant_id_fixed AS merchant_id,
    TRIM(merchant_name) AS merchant_name,
    TRIM(merchant_category) AS merchant_category,
    TRIM(city) AS city
  FROM step1_fix_id_format
),

-- STEP 3: Handle NULLs / still-broken IDs
step3_handle_nulls AS (
  SELECT
    merchant_id,
    COALESCE(merchant_name, 'UNKNOWN_MERCHANT') AS merchant_name,
    COALESCE(merchant_category, 'UNCATEGORIZED') AS merchant_category,
    COALESCE(city, 'UNKNOWN') AS city
  FROM step2_standardize_text
  WHERE REGEXP_CONTAINS(merchant_id, r'^M\d{6}$')   -- drop anything that still isn't a valid ID after step 1
),

-- STEP 4: Remove duplicate merchant_ids, keep the first
step4_remove_duplicates AS (
  SELECT *
  FROM step3_handle_nulls
  QUALIFY ROW_NUMBER() OVER (PARTITION BY merchant_id ORDER BY merchant_id) = 1
)

SELECT * FROM step4_remove_duplicates;


-------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE TABLE `finance-ad-hoc.payment_analytics.transactions_clean` AS

-- STEP 1: Fix data types (timestamp and amount must be real TIMESTAMP/NUMERIC, not text)
WITH step1_fix_types AS (
  SELECT
    transaction_id,
    user_id,
    merchant_id,
    gateway,
    payment_method,
    SAFE_CAST(transaction_timestamp AS TIMESTAMP) AS transaction_timestamp,
    SAFE_CAST(amount AS NUMERIC) AS amount,
    response_time_ms,
    status,
    failure_reason
  FROM `finance-ad-hoc.payment_analytics.raw_transactions`
),

-- STEP 2: Standardize text fields (casing + stray spaces)
step2_standardize_text AS (
  SELECT
    transaction_id,
    TRIM(user_id) AS user_id,
    TRIM(merchant_id) AS merchant_id,
    TRIM(gateway) AS gateway,
    TRIM(payment_method) AS payment_method,
    transaction_timestamp,
    amount,
    response_time_ms,
    UPPER(TRIM(status)) AS status,
    failure_reason
  FROM step1_fix_types
),

-- STEP 3: Handle NULLs (failure_reason is only meant to be empty for non-failed transactions)
step3_handle_nulls AS (
  SELECT
    transaction_id,
    user_id,
    merchant_id,
    gateway,
    payment_method,
    transaction_timestamp,
    amount,
    response_time_ms,
    status,
    COALESCE(failure_reason, 'NOT_APPLICABLE') AS failure_reason
  FROM step2_standardize_text
),

-- STEP 4: Drop structurally invalid rows (no ID, no valid amount/timestamp)
step4_filter_invalid AS (
  SELECT *
  FROM step3_handle_nulls
  WHERE transaction_id IS NOT NULL
    AND amount > 0
    AND transaction_timestamp IS NOT NULL
),

-- STEP 5: Remove duplicate transaction_ids, keep the earliest
step5_remove_duplicates AS (
  SELECT *
  FROM step4_filter_invalid
  QUALIFY ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY transaction_timestamp) = 1
)

SELECT * FROM step5_remove_duplicates;

--------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE TABLE `finance-ad-hoc.payment_analytics.users_clean` AS

-- STEP 1: Standardize text fields
WITH step1_standardize_text AS (
  SELECT
    TRIM(user_id) AS user_id,
    TRIM(age_group) AS age_group,
    TRIM(city) AS city
  FROM `finance-ad-hoc.payment_analytics.raw_users`
),

-- STEP 2: Handle NULLs
step2_handle_nulls AS (
  SELECT
    user_id,
    COALESCE(age_group, 'UNKNOWN') AS age_group,
    COALESCE(city, 'UNKNOWN') AS city
  FROM step1_standardize_text
  WHERE user_id IS NOT NULL
),

-- STEP 3: Remove duplicates
step3_remove_duplicates AS (
  SELECT *
  FROM step2_handle_nulls
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY user_id) = 1
)

SELECT * FROM step3_remove_duplicates;

----------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE TABLE `finance-ad-hoc.payment_analytics.settlements_clean` AS

-- STEP 1: Fix data types (date and amount)
WITH step1_fix_types AS (
  SELECT
    settlement_id,
    transaction_id,
    SAFE_CAST(date AS DATE) AS settlement_date,
    SAFE_CAST(amount AS NUMERIC) AS settlement_amount,
    status
  FROM `finance-ad-hoc.payment_analytics.raw_settlements`
),

-- STEP 2: Standardize status text
step2_standardize_text AS (
  SELECT
    settlement_id,
    transaction_id,
    settlement_date,
    settlement_amount,
    UPPER(TRIM(status)) AS settlement_status
  FROM step1_fix_types
),

-- STEP 3: Handle NULLs / structurally invalid rows
step3_filter_invalid AS (
  SELECT *
  FROM step2_standardize_text
  WHERE settlement_id IS NOT NULL
    AND transaction_id IS NOT NULL
),

-- STEP 4: Remove duplicate settlement records
step4_remove_duplicates AS (
  SELECT *
  FROM step3_filter_invalid
  QUALIFY ROW_NUMBER() OVER (PARTITION BY settlement_id ORDER BY settlement_id) = 1
)

SELECT * FROM step4_remove_duplicates;



