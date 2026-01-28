-- -- 0. Analysis application_train -- --

/*

Before proceeding with cleaning and feature engineering, a quick exploration of the main table and the related tables was performed. This allows a first check of the data, including value distributions, potential issues, standardization and formatting, which will be addressed via SQL prior to exporting the data to Python and Power BI.

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
        'FROM `fresh-edge-485011-c3.Home_Credit_data.application_train`'
      ),
      ' UNION ALL '
      ORDER BY ordinal_position
    ) ||
    ' ORDER BY data_type, column_name' 
    
  FROM `fresh-edge-485011-c3.Home_Credit_data.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'application_train'
);

EXECUTE IMMEDIATE dynamic_sql;


/* 
Comment: 
  
  - Categorical data always contain at least 2 categories, so no constant field to drop. 
  
  - Overall decent distribution of nulls value across the main key feature 

  - FLAG_OWN_CAR and FLAG_OWN_REALTY are encoded as BOOLEAN type. For consistency 
    with other binary features (which use INT64 0/1), we convert them to INT64. 
  
  - High cardinality that reqire some adjsutemnt for reduction before variable selection by the
    model.
  
  - Most housing related building features contain a high proportion of missing values and introduce
    sparsity due to their separate mean, median, and mode representations. Since these versions are
    typically missing together along with being highly correlated, they provide redundant 
    information.
    To simplify the model and assess the impact of housing characteristics on default risk, they are
    replaced with a single feature representing the percentage of available housing information. As 
    follow
    a list of all the 47 variables for later DROP:
    
    APARTMENTS_AVG, APARTMENTS_MEDI, APARTMENTS_MODE, BASEMENTAREA_AVG, BASEMENTAREA_MEDI, 
    BASEMENTAREA_MODE, YEARS_BEGINEXPLUATATION_AVG, YEARS_BEGINEXPLUATATION_MEDI,
    YEARS_BEGINEXPLUATATION_MODE, YEARS_BUILD_AVG, YEARS_BUILD_MEDI, YEARS_BUILD_MODE,COMMONAREA_AVG,
    COMMONAREA_MEDI, COMMONAREA_MODE, ELEVATORS_AVG, ELEVATORS_MEDI, ELEVATORS_MODE, ENTRANCES_AVG,
    ENTRANCES_MEDI, ENTRANCES_MODE, FLOORSMAX_AVG, FLOORSMAX_MEDI, FLOORSMAX_MODE, FLOORSMIN_AVG,
    FLOORSMIN_MEDI, FLOORSMIN_MODE, LANDAREA_AVG, LANDAREA_MEDI, LANDAREA_MODE, LIVINGAPARTMENTS_AVG,
    LIVINGAPARTMENTS_MEDI, LIVINGAPARTMENTS_MODE, LIVINGAREA_AVG, LIVINGAREA_MEDI, LIVINGAREA_MODE,
    NONLIVINGAPARTMENTS_AVG, NONLIVINGAPARTMENTS_MEDI, NONLIVINGAPARTMENTS_MODE, NONLIVINGAREA_AVG,
    NONLIVINGAREA_MEDI, NONLIVINGAREA_MODE, FONDKAPREMONT_MODE, HOUSETYPE_MODE, TOTALAREA_MODE,
    WALLSMATERIAL_MODE, EMERGENCYSTATE_MODE
   */




-- 2. Single column inspection

-- 2.0 Target Response

SELECT TARGET,
  ROUND(100* (SAFE_DIVIDE(COUNT(TARGET), SUM(COUNT(*))) OVER()),2) AS pct_total,
  ROUND(100*(SAFE_DIVIDE((COUNT(*) - COUNT(TARGET)), SUM(COUNT(*)) OVER())),2) AS pct_null
FROM `fresh-edge-485011-c3.Home_Credit_data.application_train`
GROUP BY TARGET;

SELECT 
CASE WHEN TARGET = 0 THEN 'non-default'
     WHEN TARGET = 1 THEN 'default'
     ELSE NULL END AS Response_Variable,

ROUND( 100 * SAFE_DIVIDE(COUNT(TARGET), SUM(COUNT(*)) OVER() ),2) AS pct_total,
ROUND( 100 * SAFE_DIVIDE((COUNT(*)- COUNT(TARGET)), SUM(COUNT(*)) OVER() ),2) AS pct_null,
COUNT(*)-COUNT(TARGET) AS count_null
FROM `fresh-edge-485011-c3.Home_Credit_data.application_train`
GROUP BY TARGET;

/*
Comment:
- The response variable is highly imbalanced, with defaults around 8%, 
  which should be considered in later modeling and train-val-eval splitting. 
*/


-- 2.1 Housing information (retrieve percentage of information regarding housing variables)

SELECT
  ROUND(
    100 * SAFE_DIVIDE(
      (
        -- 14 triplet families (MODE)
        IF(APARTMENTS_MODE IS NOT NULL, 1, 0) +
        IF(BASEMENTAREA_MODE IS NOT NULL, 1, 0) +
        IF(YEARS_BEGINEXPLUATATION_MODE IS NOT NULL, 1, 0) +
        IF(YEARS_BUILD_MODE IS NOT NULL, 1, 0) +
        IF(COMMONAREA_MODE IS NOT NULL, 1, 0) +
        IF(ELEVATORS_MODE IS NOT NULL, 1, 0) +
        IF(ENTRANCES_MODE IS NOT NULL, 1, 0) +
        IF(FLOORSMAX_MODE IS NOT NULL, 1, 0) +
        IF(FLOORSMIN_MODE IS NOT NULL, 1, 0) +
        IF(LANDAREA_MODE IS NOT NULL, 1, 0) +
        IF(LIVINGAPARTMENTS_MODE IS NOT NULL, 1, 0) +
        IF(LIVINGAREA_MODE IS NOT NULL, 1, 0) +
        IF(NONLIVINGAPARTMENTS_MODE IS NOT NULL, 1, 0) +
        IF(NONLIVINGAREA_MODE IS NOT NULL, 1, 0) +

        -- 5 single MODE features
        IF(FONDKAPREMONT_MODE IS NOT NULL, 1, 0) +
        IF(HOUSETYPE_MODE IS NOT NULL, 1, 0) +
        IF(TOTALAREA_MODE IS NOT NULL, 1, 0) +
        IF(WALLSMATERIAL_MODE IS NOT NULL, 1, 0) +
        IF(EMERGENCYSTATE_MODE IS NOT NULL, 1, 0)
      ),
      19 -- / Total number of features
    ),
    1
  ) AS HOUSING_INFO_PCT

FROM `fresh-edge-485011-c3.Home_Credit_data.application_train`;


-- 2.2 Days variables inspection

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
        'FROM `fresh-edge-485011-c3.Home_Credit_data.application_train`'
      ),
      ' UNION ALL '
      ORDER BY ordinal_position
    ) ||
    ' ORDER BY data_type, column_name'  -- Order by data type first, then column name
    
  FROM `fresh-edge-485011-c3.Home_Credit_data.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'application_train' 
  AND STARTS_WITH(column_name, 'DAYS') 
);

EXECUTE IMMEDIATE dynamic_sql;


/* 
Comment:
- The feature DAYS_EMPLOYED contains a special sentinel value 365243, which 
  indicates that the client has never been employed.

- The other variables are fine. Overall, it is better to treat DAYS_EMPLOYED 
  as years for better pattern recognition by the model and for possible 
  creation of bins if later data exploration shows any relationship with the response variable.
*/


  
