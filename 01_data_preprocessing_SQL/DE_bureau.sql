
-- -- 0. Analysis bureau and bureau_balance -- --

/*
After checking DE_Application_Train, we shift focus to the two bureau tables,
which contain credit history across all institutions (including Home Credit).
Given the level of aggregation we aim to achieve per client, the monthly balances
in bureau_balance are not prioritized initially, though they could provide additional
signals about recent payment behavior for future model iterations.
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
        'FROM `fresh-edge-485011-c3.Home_Credit_data.bureau`'
      ),
      ' UNION ALL '
      ORDER BY ordinal_position
    ) ||
    ' ORDER BY data_type, column_name' 
    
  FROM `fresh-edge-485011-c3.Home_Credit_data.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'bureau'
);

EXECUTE IMMEDIATE dynamic_sql;

/*
Comment:
As relevant columns for aggregation, the following variables will be handled:
- COUNT(CREDIT_ACTIVE) summarizes the client’s historical credit exposure and the status of past
  obligations, by allowing a good profile construction.
- SUM(AMT_CREDIT_MAX_OVERDUE) measures cumulative past overdue amounts across credits, indicating 
  repeated repayment issues.
- MAX(AMT_CREDIT_MAX_OVERDUE) measures the worst single overdue event, indicating severe past behaviour.
- SUM(AMT_CREDIT_SUM_DEBT) captures the current remaining debt of the user, which may flag clients
  with high debt at elevated risk of default.

Other categories may be partially relevant at a deeper level, but this set of information provides
a solid foundation to assess and flag risky users.
*/

-- 2. Single column inspection

--2.1 Credit Active --

SELECT 
  bureau.CREDIT_ACTIVE,
  COUNT(*) AS count,
  ROUND(COUNT(*)*100 / SUM(COUNT(*)) OVER(),2) AS pct_total,
  COUNTIF(bureau.CREDIT_ACTIVE IS NULL) AS null_count,
  ROUND(AVG(main.TARGET) * 100,2) AS pct_default 
FROM `fresh-edge-485011-c3.Home_Credit_data.bureau` AS bureau
JOIN `fresh-edge-485011-c3.Home_Credit_data.application_train` AS main
  USING(SK_ID_CURR)
GROUP BY bureau.CREDIT_ACTIVE;

/*
Comment:
The column has no nulls and contains 4 distinct categories, each showing different default risk levels. 
This supports the decision to aggregate counts separately for each CREDIT_ACTIVE type, capturing the risk profile effectively.
*/



-- 3. Aggregation for later processing

SELECT 
  bu.SK_ID_CURR,
  COUNTIF(bu.CREDIT_ACTIVE = 'Closed') AS bu_cnt_closed,
  COUNTIF(bu.CREDIT_ACTIVE = 'Active') AS bu_cnt_active,
  COUNTIF(bu.CREDIT_ACTIVE = 'Sold') AS bu_cnt_sold,
  COUNTIF(bu.CREDIT_ACTIVE = 'Bad debt') AS bu_bad_debt_count,
  IFNULL(SUM(bu.AMT_CREDIT_MAX_OVERDUE),0) AS bu_sum_max_overdue,
  IFNULL(MAX(bu.AMT_CREDIT_MAX_OVERDUE),0) AS bu_max_single_overdue,
  IFNULL(SUM(bu.AMT_CREDIT_SUM_DEBT),0) AS bu_sum_debt
FROM `fresh-edge-485011-c3.Home_Credit_data.bureau` AS bu
WHERE MOD(bu.SK_ID_CURR, 1000) = 0 --> to see a small sample
GROUP BY 1

