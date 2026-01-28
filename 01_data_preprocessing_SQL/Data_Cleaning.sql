-- -- 0. DATA CLEANING -- --

/*
This query contains all procedures for creating the final feature table with aggregations 
computed across the dataset tables. The resulting table will be then used for visualization 
in Power BI and modeling in Python.


Note: Multiple CREATE OR REPLACE steps are used for clarity and intermediate validation, while a single consolidated query would be preferred for production to reduce repeated table scans over large dataframe.

*/

-- 1. Clone Main Table without unwanted columns

CREATE OR REPLACE TABLE `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned` AS (
SELECT * EXCEPT(
    APARTMENTS_AVG, APARTMENTS_MEDI, APARTMENTS_MODE,
    BASEMENTAREA_AVG, BASEMENTAREA_MEDI, BASEMENTAREA_MODE,
    YEARS_BEGINEXPLUATATION_AVG, YEARS_BEGINEXPLUATATION_MEDI, YEARS_BEGINEXPLUATATION_MODE,
    YEARS_BUILD_AVG, YEARS_BUILD_MEDI, YEARS_BUILD_MODE,
    COMMONAREA_AVG, COMMONAREA_MEDI, COMMONAREA_MODE,
    ELEVATORS_AVG, ELEVATORS_MEDI, ELEVATORS_MODE,
    ENTRANCES_AVG, ENTRANCES_MEDI, ENTRANCES_MODE,
    FLOORSMAX_AVG, FLOORSMAX_MEDI, FLOORSMAX_MODE,
    FLOORSMIN_AVG, FLOORSMIN_MEDI, FLOORSMIN_MODE,
    LANDAREA_AVG, LANDAREA_MEDI, LANDAREA_MODE,
    LIVINGAPARTMENTS_AVG, LIVINGAPARTMENTS_MEDI, LIVINGAPARTMENTS_MODE,
    LIVINGAREA_AVG, LIVINGAREA_MEDI, LIVINGAREA_MODE,
    NONLIVINGAPARTMENTS_AVG, NONLIVINGAPARTMENTS_MEDI, NONLIVINGAPARTMENTS_MODE,
    NONLIVINGAREA_AVG, NONLIVINGAREA_MEDI, NONLIVINGAREA_MODE,
    FONDKAPREMONT_MODE, HOUSETYPE_MODE, TOTALAREA_MODE,
    WALLSMATERIAL_MODE, EMERGENCYSTATE_MODE
)
FROM `fresh-edge-485011-c3.Home_Credit_data.application_train`);



-- 2.Data adjustment for days columns into years

CREATE OR REPLACE TABLE `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned` AS(
  SELECT * EXCEPT (DAYS_ID_PUBLISH, DAYS_EMPLOYED, DAYS_BIRTH,
                   DAYS_REGISTRATION, DAYS_LAST_PHONE_CHANGE),
    ROUND(DAYS_ID_PUBLISH/-365,1) AS YEARS_ID_PUBLISH,
    ROUND(DAYS_BIRTH/-365,1) AS YEARS_BIRTH,
    ROUND(DAYS_REGISTRATION/-365,1) AS YEARS_REGISTRATION,
    ROUND(DAYS_LAST_PHONE_CHANGE/-365,1) AS YEARS_LAST_PHONE_CHANGE,
    CASE WHEN (DAYS_EMPLOYED = 365243) THEN NULL
      ELSE ROUND(DAYS_EMPLOYED/-365,1) END AS YEARS_EMPLOYED

  FROM `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned`);


-- 3. Merging Information from bureau and previous_application

CREATE OR REPLACE TABLE `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned` AS (
    
  -- 3.1 Create Bureau aggreagation features

  WITH agg_bureau AS(
    SELECT 
      SK_ID_CURR,
      COUNTIF(CREDIT_ACTIVE = 'Closed') AS bur_cnt_closed,
      COUNTIF(CREDIT_ACTIVE = 'Active') AS bur_cnt_active,
      COUNTIF(CREDIT_ACTIVE = 'Sold') AS bur_cnt_sold,
      COUNTIF(CREDIT_ACTIVE = 'Bad debt') AS bur_bad_debt_count,
      IFNULL(SUM(AMT_CREDIT_MAX_OVERDUE),0) AS bur_sum_max_overdue,
      IFNULL(MAX(AMT_CREDIT_MAX_OVERDUE),0) AS bur_max_single_overdue,
      IFNULL(SUM(AMT_CREDIT_SUM_DEBT),0) AS bur_sum_debt
    FROM `fresh-edge-485011-c3.Home_Credit_data.bureau`
    GROUP BY SK_ID_CURR
    ),

  -- 3.2 Create previous_application aggreagation features

  agg_prev AS (
    SELECT
      SK_ID_CURR,

    -- Cash Loans
    COUNTIF(NAME_CONTRACT_TYPE = 'Cash loans' 
      AND NAME_CONTRACT_STATUS = 'Approved') AS prev_cnt_cash_approved,
    COUNTIF(NAME_CONTRACT_TYPE = 'Cash loans' 
      AND NAME_CONTRACT_STATUS = 'Refused') AS prev_cnt_cash_refused,
    COUNTIF(NAME_CONTRACT_TYPE = 'Cash loans' 
      AND NAME_CONTRACT_STATUS = 'Canceled') AS prev_cnt_cash_canceled,
    COUNTIF(NAME_CONTRACT_TYPE = 'Cash loans' 
      AND NAME_CONTRACT_STATUS = 'Unused offer') AS prev_cnt_cash_unused,

    -- Revolving loans
    COUNTIF(NAME_CONTRACT_TYPE = 'Revolving loans' 
      AND NAME_CONTRACT_STATUS = 'Approved') AS prev_cnt_revolving_approved,
    COUNTIF(NAME_CONTRACT_TYPE = 'Revolving loans' 
      AND NAME_CONTRACT_STATUS = 'Refused') AS prev_cnt_revolving_refused,
    COUNTIF(NAME_CONTRACT_TYPE = 'Revolving loans' 
      AND NAME_CONTRACT_STATUS = 'Canceled') AS prev_cnt_revolving_canceled,
    COUNTIF(NAME_CONTRACT_TYPE = 'Revolving loans' 
      AND NAME_CONTRACT_STATUS = 'Unused offer') AS prev_cnt_revolving_unused,

    -- Consumer loans
    COUNTIF(NAME_CONTRACT_TYPE = 'Consumer loans' 
      AND NAME_CONTRACT_STATUS = 'Approved') AS prev_cnt_consumer_approved,
    COUNTIF(NAME_CONTRACT_TYPE = 'Consumer loans' 
      AND NAME_CONTRACT_STATUS = 'Refused') AS prev_cnt_consumer_refused,
    COUNTIF(NAME_CONTRACT_TYPE = 'Consumer loans' 
      AND NAME_CONTRACT_STATUS = 'Canceled') AS prev_cnt_consumer_canceled,
    COUNTIF(NAME_CONTRACT_TYPE = 'Consumer loans' 
      AND NAME_CONTRACT_STATUS = 'Unused offer') AS prev_cnt_consumer_unused,

    -- XNA (other type)
    COUNTIF(NAME_CONTRACT_TYPE = 'XNA' 
      AND NAME_CONTRACT_STATUS = 'Approved') AS prev_cnt_xna_approved,
    COUNTIF(NAME_CONTRACT_TYPE = 'XNA' 
      AND NAME_CONTRACT_STATUS = 'Refused') AS prev_cnt_xna_refused,
    COUNTIF(NAME_CONTRACT_TYPE = 'XNA' 
      AND NAME_CONTRACT_STATUS = 'Canceled') AS prev_cnt_xna_canceled,
    COUNTIF(NAME_CONTRACT_TYPE = 'XNA' 
      AND NAME_CONTRACT_STATUS = 'Unused offer') AS prev_cnt_xna_unused

    FROM `fresh-edge-485011-c3.Home_Credit_data.previous_application`
    GROUP BY SK_ID_CURR
    )
    

  SELECT *
  FROM `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned`
  LEFT JOIN agg_bureau USING(SK_ID_CURR)
  LEFT JOIN agg_prev USING(SK_ID_CURR)
  );


  -- 3.3 Adjustment BOLEAN type into INTEGER

CREATE OR REPLACE TABLE `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned` AS (
  SELECT *  EXCEPT(FLAG_OWN_CAR, FLAG_OWN_REALTY),
    CAST(FLAG_OWN_CAR AS INT64) AS FLAG_OWN_CAR,
    CAST(FLAG_OWN_REALTY AS INT64) AS FLAG_OWN_REALTY
  FROM `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned`);


 -- 3.4 Include binary variables for data availability
CREATE OR REPLACE TABLE `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned` AS (
  SELECT *,
    CASE WHEN bur_cnt_closed IS NULL THEN 0 ELSE 1 END AS bur_has_history,
    CASE WHEN prev_cnt_xna_unused IS NULL THEN 0 ELSE 1 END AS prev_has_history

  FROM `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned`);


  -- 3.5 Convert NULLs to 0 for all prev_ and bur_ aggregation metrics (from LEFT JOIN)

CREATE OR REPLACE TABLE `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned` AS (
  SELECT * EXCEPT(
           bur_cnt_closed, bur_cnt_active, bur_cnt_sold, bur_bad_debt_count,
           bur_sum_max_overdue, bur_max_single_overdue, bur_sum_debt,
           prev_cnt_cash_approved, prev_cnt_cash_refused, prev_cnt_cash_canceled, 
           prev_cnt_cash_unused, prev_cnt_revolving_approved, prev_cnt_revolving_refused,
           prev_cnt_revolving_canceled, prev_cnt_revolving_unused,
           prev_cnt_consumer_approved, prev_cnt_consumer_refused, prev_cnt_consumer_canceled,
           prev_cnt_consumer_unused, prev_cnt_xna_approved, prev_cnt_xna_refused,  
           prev_cnt_xna_canceled, prev_cnt_xna_unused),
  
    -- Bureau features: NULL → 0
    COALESCE(bur_cnt_closed, 0) AS bur_cnt_closed,
    COALESCE(bur_cnt_active, 0) AS bur_cnt_active,
    COALESCE(bur_cnt_sold, 0) AS bur_cnt_sold,
    COALESCE(bur_bad_debt_count, 0) AS bur_bad_debt_count,
    COALESCE(bur_sum_max_overdue, 0) AS bur_sum_max_overdue,
    COALESCE(bur_max_single_overdue, 0) AS bur_max_single_overdue,
    COALESCE(bur_sum_debt, 0) AS bur_sum_debt,
  
    -- Previous application features: NULL → 0
    COALESCE(prev_cnt_cash_approved, 0) AS prev_cnt_cash_approved,
    COALESCE(prev_cnt_cash_refused, 0) AS prev_cnt_cash_refused,
    COALESCE(prev_cnt_cash_canceled, 0) AS prev_cnt_cash_canceled,
    COALESCE(prev_cnt_cash_unused, 0) AS prev_cnt_cash_unused,
    COALESCE(prev_cnt_revolving_approved, 0) AS prev_cnt_revolving_approved,
    COALESCE(prev_cnt_revolving_refused, 0) AS prev_cnt_revolving_refused,
    COALESCE(prev_cnt_revolving_canceled, 0) AS prev_cnt_revolving_canceled,
    COALESCE(prev_cnt_revolving_unused, 0) AS prev_cnt_revolving_unused,
    COALESCE(prev_cnt_consumer_approved, 0) AS prev_cnt_consumer_approved,
    COALESCE(prev_cnt_consumer_refused, 0) AS prev_cnt_consumer_refused,
    COALESCE(prev_cnt_consumer_canceled, 0) AS prev_cnt_consumer_canceled,
    COALESCE(prev_cnt_consumer_unused, 0) AS prev_cnt_consumer_unused,
    COALESCE(prev_cnt_xna_approved, 0) AS prev_cnt_xna_approved,
    COALESCE(prev_cnt_xna_refused, 0) AS prev_cnt_xna_refused,
    COALESCE(prev_cnt_xna_canceled, 0) AS prev_cnt_xna_canceled,
    COALESCE(prev_cnt_xna_unused, 0) AS prev_cnt_xna_unused


  FROM `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned`
);


  -- 3.6 Adjust NULL values (AMT_REQ_CREDIT_BUREAU and OCCUPATION_TYPE, OWN_CAR_AGE)
CREATE OR REPLACE TABLE `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned` AS (
  SELECT * EXCEPT(
            AMT_REQ_CREDIT_BUREAU_HOUR,AMT_REQ_CREDIT_BUREAU_DAY, AMT_REQ_CREDIT_BUREAU_WEEK,
            AMT_REQ_CREDIT_BUREAU_MON, AMT_REQ_CREDIT_BUREAU_QRT, AMT_REQ_CREDIT_BUREAU_YEAR,
            OCCUPATION_TYPE, OWN_CAR_AGE),

  -- Flag on missing values
  CASE WHEN AMT_REQ_CREDIT_BUREAU_YEAR IS NULL THEN 1 ELSE 0 END AS AMT_REQ_CREDIT_BUREAU_flag_na,

  -- Then convert to 0
  COALESCE(AMT_REQ_CREDIT_BUREAU_HOUR, 0) AS AMT_REQ_CREDIT_BUREAU_HOUR,
  COALESCE(AMT_REQ_CREDIT_BUREAU_DAY, 0) AS AMT_REQ_CREDIT_BUREAU_DAY,
  COALESCE(AMT_REQ_CREDIT_BUREAU_WEEK, 0) AS AMT_REQ_CREDIT_BUREAU_WEEK,
  COALESCE(AMT_REQ_CREDIT_BUREAU_MON, 0) AS AMT_REQ_CREDIT_BUREAU_MON,
  COALESCE(AMT_REQ_CREDIT_BUREAU_QRT, 0) AS AMT_REQ_CREDIT_BUREAU_QRT,
  COALESCE(AMT_REQ_CREDIT_BUREAU_YEAR, 0) AS AMT_REQ_CREDIT_BUREAU_YEAR,

  -- Convert OCCUPATION_TYPE NULLs to Not Provided
  IFNULL(OCCUPATION_TYPE, 'Not Provided') AS OCCUPATION_TYPE ,

  -- Set car age to NULL if no car owned
  CASE WHEN FLAG_OWN_CAR = 0 THEN NULL ELSE OWN_CAR_AGE END AS OWN_CAR_AGE

  FROM `fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned`
) 
