
-- -- 0. Analysis previous_application -- --

/*
After checking DE_Application_Train and DE_bureau, we shift focus to the previous_application table,
which contains Home Credit's internal application history. Given the level of aggregation we aim to achieve per client, only the previous_application level will be considered without deeper joins to underlying tables such as POS_CASH_balance,  installments_payments, and credit_card_balance, as repayment outcomes are already captured in bureau.
*/

-- 1. Column profiling 

DECLARE dynamic_sql STRING;

SET dynamic_sql = (
  SELECT 
    STRING_AGG(
      CONCAT(
        'SELECT "', column_name, '" as column_name, ',
        '"', data_type, '" as data_type, ',
        'COUNT(DISTINCT ', column_name, ') as distinct_count, ',
        IF(data_type IN ('INT64', 'FLOAT64', 'NUMERIC', 'BIGNUMERIC'),
           CONCAT('SAFE_CAST(MIN(', column_name, ') AS STRING) as min_value, ',
                  'SAFE_CAST(MAX(', column_name, ') AS STRING) as max_value, '),
           'NULL as min_value, NULL as max_value, '),
        'COUNTIF(', column_name, ' IS NULL) as null_count, ',
        'COUNT(*) as total_rows, ',
        'ROUND(100.0 * COUNTIF(', column_name, ' IS NULL) / COUNT(*), 2) as pct_missing ',
        'FROM `fresh-edge-485011-c3.Home_Credit_data.previous_application`'
      ),
      ' UNION ALL '
      ORDER BY ordinal_position
    ) ||
    ' ORDER BY data_type, column_name'
    
  FROM `fresh-edge-485011-c3.Home_Credit_data.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'previous_application'
);

EXECUTE IMMEDIATE dynamic_sql;

/*
Comment:
As relevant columns for aggregation, the following variables will be handled:

- NAME_CONTRACT_STATUS captures Home Credit's previous decisions (approved, refused, canceled, 
  unused offers), defining the client's application history with the institution.

- NAME_CONTRACT_TYPE indicates whether clients applied for cash loans versus revolving credit,or 
  other instrument, potentially revealing behavioral patterns useful for segmentation.

Given the limited signal from contract type alone, we create COUNT(contract_type × status) combinations to capture interpretable patterns like refused cash loans or unused revolving offers.

*/

-- 2. Single column inspection

--2.1  NAME_CONTRACT_STATUS--

SELECT 
  prev.NAME_CONTRACT_STATUS,
  COUNT(*) AS count,
  ROUND(COUNT(*)*100 / SUM(COUNT(*)) OVER(),2) AS pct_total,
  COUNTIF(prev.NAME_CONTRACT_STATUS IS NULL) AS null_count,
  ROUND(AVG(main.TARGET) * 100,2) AS pct_default 
FROM `fresh-edge-485011-c3.Home_Credit_data.previous_application` AS prev
JOIN `fresh-edge-485011-c3.Home_Credit_data.application_train` AS main
  USING(SK_ID_CURR)
GROUP BY prev.NAME_CONTRACT_STATUS;

/*
Comment:
The column holds no nulls and contains 4 distinct categories. Refused applications show 
notably higher default rates (12%), while canceled applications show moderate elevation (9.17%) 
compared to approved application and respectively unused offer (7.59%- 8.25%).
*/



--2.2  NAME_CONTRACT_TYPE--

SELECT 
  prev.NAME_CONTRACT_TYPE,
  COUNT(*) AS count,
  ROUND(COUNT(*)*100 / SUM(COUNT(*)) OVER(),2) AS pct_total,
  COUNTIF(prev.NAME_CONTRACT_TYPE IS NULL) AS null_count,
  ROUND(AVG(main.TARGET) * 100,2) AS pct_default 
FROM `fresh-edge-485011-c3.Home_Credit_data.previous_application` AS prev
JOIN `fresh-edge-485011-c3.Home_Credit_data.application_train` AS main
  USING(SK_ID_CURR)
GROUP BY prev.NAME_CONTRACT_TYPE;


/*
This column contains a small 'XNA' category (0.02% of records) in addition to the three main 
loan types. Given XNA's elevated default rate (20.13%) compared to standard loan types 
(7.71-10.47%), it is retained as a distinct category in the expansion.
*/




-- 3. Contract type × status combinations

SELECT
  prev.SK_ID_CURR,
  -- Cash Loans
  COUNTIF(NAME_CONTRACT_TYPE = 'Cash loans' 
    AND NAME_CONTRACT_STATUS = 'Approved') AS cnt_prev_cash_approved,
  COUNTIF(NAME_CONTRACT_TYPE = 'Cash loans' 
    AND NAME_CONTRACT_STATUS = 'Refused') AS cnt_prev_cash_refused,
  COUNTIF(NAME_CONTRACT_TYPE = 'Cash loans' 
    AND NAME_CONTRACT_STATUS = 'Canceled') AS cnt_prev_cash_canceled,
  COUNTIF(NAME_CONTRACT_TYPE = 'Cash loans' 
    AND NAME_CONTRACT_STATUS = 'Unused offer') AS cnt_prev_cash_unused,
  -- Revolving loans
  COUNTIF(NAME_CONTRACT_TYPE = 'Revolving loans' 
    AND NAME_CONTRACT_STATUS = 'Approved') AS cnt_prev_revolving_approved,
  COUNTIF(NAME_CONTRACT_TYPE = 'Revolving loans' 
    AND NAME_CONTRACT_STATUS = 'Refused') AS cnt_prev_revolving_refused,
  COUNTIF(NAME_CONTRACT_TYPE = 'Revolving loans' 
    AND NAME_CONTRACT_STATUS = 'Canceled') AS cnt_prev_revolving_canceled,
  COUNTIF(NAME_CONTRACT_TYPE = 'Revolving loans' 
    AND NAME_CONTRACT_STATUS = 'Unused offer') AS cnt_prev_revolving_unused,
  -- Consumer loans
  COUNTIF(NAME_CONTRACT_TYPE = 'Consumer loans' 
    AND NAME_CONTRACT_STATUS = 'Approved') AS cnt_prev_consumer_approved,
  COUNTIF(NAME_CONTRACT_TYPE = 'Consumer loans' 
    AND NAME_CONTRACT_STATUS = 'Refused') AS cnt_prev_consumer_refused,
  COUNTIF(NAME_CONTRACT_TYPE = 'Consumer loans' 
    AND NAME_CONTRACT_STATUS = 'Canceled') AS cnt_prev_consumer_canceled,
  COUNTIF(NAME_CONTRACT_TYPE = 'Consumer loans' 
    AND NAME_CONTRACT_STATUS = 'Unused offer') AS cnt_prev_consumer_unused,
  -- XNA (other type)
  COUNTIF(NAME_CONTRACT_TYPE = 'XNA' 
    AND NAME_CONTRACT_STATUS = 'Approved') AS cnt_prev_xna_approved,
  COUNTIF(NAME_CONTRACT_TYPE = 'XNA' 
    AND NAME_CONTRACT_STATUS = 'Refused') AS cnt_prev_xna_refused,
  COUNTIF(NAME_CONTRACT_TYPE = 'XNA' 
    AND NAME_CONTRACT_STATUS = 'Canceled') AS cnt_prev_xna_canceled,
  COUNTIF(NAME_CONTRACT_TYPE = 'XNA' 
    AND NAME_CONTRACT_STATUS = 'Unused offer') AS cnt_prev_xna_unused

FROM `fresh-edge-485011-c3.Home_Credit_data.previous_application` AS prev
WHERE MOD(prev.SK_ID_CURR, 1000) = 0
GROUP BY prev.SK_ID_CURR


/*
Comment:
Given the resulting sparsity from the expansion (16 features with many zero counts),
we will evaluate during EDA which combinations show meaningful signal for modeling 
versus which can be aggregated or dropped.
*/

