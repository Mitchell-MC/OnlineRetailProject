-- ===================================================================
-- SNOWFLAKE DATA WAREHOUSE BUILD SCRIPT
-- Copy and paste this entire script into Snowflake to build your warehouse
-- ===================================================================

USE DATABASE ECOMMERCE_DB;
USE SCHEMA ANALYTICS;

-- ===================================================================
-- STEP 1: CREATE COMBINED EVENTS TABLE
-- ===================================================================

CREATE OR REPLACE TABLE STG_EVENTS_COMBINED AS
SELECT 
    CAST(USER_ID AS VARCHAR) AS USER_ID,
    CAST(EVENT_TIME AS TIMESTAMP) AS EVENT_TIME,
    CAST(EVENT_TYPE AS VARCHAR) AS EVENT_TYPE,
    CAST(PRODUCT_ID AS VARCHAR) AS PRODUCT_ID,
    CAST(PRICE AS FLOAT) AS PRICE,
    CAST(BRAND AS VARCHAR) AS BRAND,
    CAST(CATEGORY_CODE AS VARCHAR) AS CATEGORY_CODE
FROM STG_EVENTS_CART
UNION ALL
SELECT 
    CAST(USER_ID AS VARCHAR),
    CAST(EVENT_TIME AS TIMESTAMP),
    CAST(EVENT_TYPE AS VARCHAR),
    CAST(PRODUCT_ID AS VARCHAR),
    CAST(PRICE AS FLOAT),
    CAST(BRAND AS VARCHAR),
    CAST(CATEGORY_CODE AS VARCHAR)
FROM STG_EVENTS_PURCHASE
UNION ALL
SELECT 
    CAST(USER_ID AS VARCHAR),
    CAST(EVENT_TIME AS TIMESTAMP),
    CAST(EVENT_TYPE AS VARCHAR),
    CAST(PRODUCT_ID AS VARCHAR),
    CAST(PRICE AS FLOAT),
    CAST(BRAND AS VARCHAR),
    CAST(CATEGORY_CODE AS VARCHAR)
FROM STG_EVENTS_VIEW;

-- ===================================================================
-- STEP 2: CREATE ANALYTICAL VIEWS
-- ===================================================================

-- View 1: Product Popularity
CREATE OR REPLACE VIEW VW_PRODUCT_POPULARITY AS
SELECT 
    PRODUCT_ID,
    CATEGORY_CODE,
    COUNT(*) AS PURCHASE_COUNT,
    AVG(PRICE) AS AVG_PRICE,
    SUM(PRICE) AS TOTAL_REVENUE,
    COUNT(DISTINCT USER_ID) AS UNIQUE_BUYERS
FROM STG_EVENTS_COMBINED
WHERE EVENT_TYPE = 'purchase' 
    AND CATEGORY_CODE IS NOT NULL
    AND PRODUCT_ID IS NOT NULL
GROUP BY PRODUCT_ID, CATEGORY_CODE
ORDER BY PURCHASE_COUNT DESC;

-- View 2: User Behavior
CREATE OR REPLACE VIEW VW_USER_BEHAVIOR AS
SELECT 
    USER_ID,
    COUNT(*) AS TOTAL_EVENTS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) AS PURCHASE_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) AS VIEW_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'cart' THEN 1 END) AS CART_COUNT,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) AS TOTAL_SPEND,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) AS AVG_PURCHASE_VALUE,
    MIN(EVENT_TIME) AS FIRST_SEEN,
    MAX(EVENT_TIME) AS LAST_SEEN,
    DATEDIFF('day', MIN(EVENT_TIME), MAX(EVENT_TIME)) AS DAYS_ACTIVE
FROM STG_EVENTS_COMBINED
WHERE USER_ID IS NOT NULL
GROUP BY USER_ID;

-- View 3: Category Performance
CREATE OR REPLACE VIEW VW_CATEGORY_PERFORMANCE AS
SELECT 
    CATEGORY_CODE,
    COUNT(*) AS TOTAL_EVENTS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) AS PURCHASE_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) AS VIEW_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'cart' THEN 1 END) AS CART_COUNT,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) AS TOTAL_REVENUE,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) AS AVG_PURCHASE_VALUE,
    COUNT(DISTINCT USER_ID) AS UNIQUE_USERS,
    COUNT(DISTINCT PRODUCT_ID) AS UNIQUE_PRODUCTS,
    CASE 
        WHEN COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) * 100.0 / COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END)
        ELSE 0 
    END AS CONVERSION_RATE
FROM STG_EVENTS_COMBINED
WHERE CATEGORY_CODE IS NOT NULL
GROUP BY CATEGORY_CODE
ORDER BY TOTAL_REVENUE DESC;

-- View 4: Daily Performance
CREATE OR REPLACE VIEW VW_DAILY_PERFORMANCE AS
SELECT 
    DATE(EVENT_TIME) AS EVENT_DATE,
    COUNT(DISTINCT USER_ID) AS DAILY_ACTIVE_USERS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) AS DAILY_PURCHASES,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) AS DAILY_REVENUE,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) AS AVG_ORDER_VALUE,
    COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) AS DAILY_VIEWS,
    COUNT(CASE WHEN EVENT_TYPE = 'cart' THEN 1 END) AS DAILY_CART_ADDITIONS
FROM STG_EVENTS_COMBINED
WHERE EVENT_TIME IS NOT NULL
GROUP BY DATE(EVENT_TIME)
ORDER BY EVENT_DATE DESC;

-- ===================================================================
-- STEP 3: CREATE FINAL REPORTING TABLES
-- ===================================================================

-- Table 1: User Segments
CREATE OR REPLACE TABLE USER_SEGMENTS AS
SELECT 
    USER_ID,
    TOTAL_SPEND,
    TOTAL_PURCHASES,
    FAVORITE_BRAND,
    MOST_VIEWED_CATEGORY,
    LAST_SEEN_DATE,
    CASE 
        WHEN TOTAL_SPEND >= 1000 THEN 'VIP'
        WHEN TOTAL_SPEND >= 500 THEN 'Premium'
        WHEN TOTAL_SPEND >= 100 THEN 'Regular'
        ELSE 'New'
    END AS SEGMENT
FROM CUSTOMER_360_PROFILE;

-- Table 2: Product Recommendations
CREATE OR REPLACE TABLE USER_PRODUCT_RECOMMENDATIONS AS
WITH ProductPurchases AS (
    SELECT 
        PRODUCT_ID, 
        CATEGORY_CODE,
        COUNT(*) AS PURCHASE_COUNT
    FROM STG_EVENTS_COMBINED
    WHERE EVENT_TYPE = 'purchase'
      AND CATEGORY_CODE IS NOT NULL
      AND PRODUCT_ID IS NOT NULL
    GROUP BY PRODUCT_ID, CATEGORY_CODE
),
TopProducts AS (
    SELECT
        CATEGORY_CODE,
        PRODUCT_ID,
        ROW_NUMBER() OVER (PARTITION BY CATEGORY_CODE ORDER BY PURCHASE_COUNT DESC) AS RN
    FROM ProductPurchases
),
CategoryRecs AS (
    SELECT
        CATEGORY_CODE,
        ARRAY_AGG(PRODUCT_ID) WITHIN GROUP (ORDER BY RN) AS RECOMMENDED_PRODUCTS
    FROM TopProducts
    WHERE RN <= 5 -- Top 5 products per category
    GROUP BY CATEGORY_CODE
)
SELECT
    prof.USER_ID,
    recs.RECOMMENDED_PRODUCTS,
    'Top products in favorite category' AS RECOMMENDATION_REASON,
    CURRENT_TIMESTAMP() AS RECOMMENDATION_DATE
FROM CUSTOMER_360_PROFILE prof
JOIN CategoryRecs recs
  ON prof.MOST_VIEWED_CATEGORY = recs.CATEGORY_CODE
WHERE prof.MOST_VIEWED_CATEGORY IS NOT NULL;

-- ===================================================================
-- STEP 4: VERIFICATION
-- ===================================================================

-- Check what was created
SELECT 'DATA WAREHOUSE BUILD COMPLETE!' AS STATUS;

-- Show table counts
SELECT 'STG_EVENTS_COMBINED' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM STG_EVENTS_COMBINED
UNION ALL
SELECT 'USER_SEGMENTS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM USER_SEGMENTS
UNION ALL
SELECT 'USER_PRODUCT_RECOMMENDATIONS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM USER_PRODUCT_RECOMMENDATIONS;

-- Show user segments distribution
SELECT 'USER SEGMENTS:' AS INFO;
SELECT SEGMENT, COUNT(*) AS USER_COUNT, AVG(TOTAL_SPEND) AS AVG_SPEND
FROM USER_SEGMENTS 
GROUP BY SEGMENT 
ORDER BY AVG_SPEND DESC; 