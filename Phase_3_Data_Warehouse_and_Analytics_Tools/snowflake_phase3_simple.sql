-- ===================================================================
-- SNOWFLAKE PHASE 3 SIMPLIFIED DATA WAREHOUSE SETUP
-- Build complete data warehouse from existing ANALYTICS data
-- ===================================================================

-- Use the correct database and schema
USE ECOMMERCE_DB.ANALYTICS;

-- ===================================================================
-- STEP 1: CHECK EXISTING DATA
-- ===================================================================

-- Check what data we have in ANALYTICS schema
SELECT 'EXISTING DATA IN ANALYTICS SCHEMA:' as INFO;
SELECT 'STG_EVENTS_CART' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_CART
UNION ALL
SELECT 'STG_EVENTS_PURCHASE' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_PURCHASE
UNION ALL
SELECT 'STG_EVENTS_VIEW' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_VIEW
UNION ALL
SELECT 'CUSTOMER_360_PROFILE' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM CUSTOMER_360_PROFILE;

-- ===================================================================
-- STEP 2: CREATE COMBINED EVENTS TABLE
-- ===================================================================

-- Create a combined staging table for all events
CREATE OR REPLACE TABLE STG_EVENTS_COMBINED AS
SELECT 
    CAST(USER_ID AS STRING) AS USER_ID,
    CAST(EVENT_TIME AS TIMESTAMP) AS EVENT_TIME,
    CAST(EVENT_TYPE AS STRING) AS EVENT_TYPE,
    CAST(PRODUCT_ID AS STRING) AS PRODUCT_ID,
    CAST(PRICE AS DOUBLE) AS PRICE,
    CAST(BRAND AS STRING) AS BRAND,
    CAST(CATEGORY_CODE AS STRING) AS CATEGORY_CODE
FROM STG_EVENTS_CART
UNION ALL
SELECT 
    CAST(USER_ID AS STRING),
    CAST(EVENT_TIME AS TIMESTAMP),
    CAST(EVENT_TYPE AS STRING),
    CAST(PRODUCT_ID AS STRING),
    CAST(PRICE AS DOUBLE),
    CAST(BRAND AS STRING),
    CAST(CATEGORY_CODE AS STRING)
FROM STG_EVENTS_PURCHASE
UNION ALL
SELECT 
    CAST(USER_ID AS STRING),
    CAST(EVENT_TIME AS TIMESTAMP),
    CAST(EVENT_TYPE AS STRING),
    CAST(PRODUCT_ID AS STRING),
    CAST(PRICE AS DOUBLE),
    CAST(BRAND AS STRING),
    CAST(CATEGORY_CODE AS STRING)
FROM STG_EVENTS_VIEW;

-- ===================================================================
-- STEP 3: CREATE ANALYTICAL VIEWS
-- ===================================================================

-- View 1: Product Popularity by Category
CREATE OR REPLACE VIEW VW_PRODUCT_POPULARITY AS
SELECT 
    PRODUCT_ID,
    CATEGORY_CODE,
    COUNT(*) as PURCHASE_COUNT,
    AVG(PRICE) as AVG_PRICE,
    SUM(PRICE) as TOTAL_REVENUE,
    COUNT(DISTINCT USER_ID) as UNIQUE_BUYERS
FROM STG_EVENTS_COMBINED
WHERE EVENT_TYPE = 'purchase' 
    AND CATEGORY_CODE IS NOT NULL
    AND PRODUCT_ID IS NOT NULL
GROUP BY PRODUCT_ID, CATEGORY_CODE
ORDER BY PURCHASE_COUNT DESC;

-- View 2: User Behavior Analytics
CREATE OR REPLACE VIEW VW_USER_BEHAVIOR AS
SELECT 
    USER_ID,
    COUNT(*) as TOTAL_EVENTS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) as PURCHASE_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) as VIEW_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'cart' THEN 1 END) as CART_COUNT,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) as TOTAL_SPEND,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) as AVG_PURCHASE_VALUE,
    MIN(EVENT_TIME) as FIRST_SEEN,
    MAX(EVENT_TIME) as LAST_SEEN,
    DATEDIFF('day', MIN(EVENT_TIME), MAX(EVENT_TIME)) as DAYS_ACTIVE,
    CASE 
        WHEN COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) * 100.0 / COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END)
        ELSE 0 
    END as VIEW_TO_PURCHASE_RATIO
FROM STG_EVENTS_COMBINED
WHERE USER_ID IS NOT NULL
GROUP BY USER_ID;

-- View 3: Category Performance
CREATE OR REPLACE VIEW VW_CATEGORY_PERFORMANCE AS
SELECT 
    CATEGORY_CODE,
    COUNT(*) as TOTAL_EVENTS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) as PURCHASE_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) as VIEW_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'cart' THEN 1 END) as CART_COUNT,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) as TOTAL_REVENUE,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) as AVG_PURCHASE_VALUE,
    COUNT(DISTINCT USER_ID) as UNIQUE_USERS,
    COUNT(DISTINCT PRODUCT_ID) as UNIQUE_PRODUCTS,
    CASE 
        WHEN COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) * 100.0 / COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END)
        ELSE 0 
    END as CONVERSION_RATE
FROM STG_EVENTS_COMBINED
WHERE CATEGORY_CODE IS NOT NULL
GROUP BY CATEGORY_CODE
ORDER BY TOTAL_REVENUE DESC;

-- View 4: Daily Performance Metrics
CREATE OR REPLACE VIEW VW_DAILY_PERFORMANCE AS
SELECT 
    DATE(EVENT_TIME) as EVENT_DATE,
    COUNT(DISTINCT USER_ID) as DAILY_ACTIVE_USERS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) as DAILY_PURCHASES,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) as DAILY_REVENUE,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) as AVG_ORDER_VALUE,
    COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) as DAILY_VIEWS,
    COUNT(CASE WHEN EVENT_TYPE = 'cart' THEN 1 END) as DAILY_CART_ADDITIONS,
    CASE 
        WHEN COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) * 100.0 / COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END)
        ELSE 0 
    END as DAILY_CONVERSION_RATE
FROM STG_EVENTS_COMBINED
WHERE EVENT_TIME IS NOT NULL
GROUP BY DATE(EVENT_TIME)
ORDER BY EVENT_DATE DESC;

-- ===================================================================
-- STEP 4: CREATE PRODUCT RECOMMENDATIONS
-- ===================================================================

-- Create recommendations table
CREATE OR REPLACE TABLE USER_PRODUCT_RECOMMENDATIONS (
    USER_ID NUMBER(38,0) NOT NULL,
    RECOMMENDED_PRODUCTS ARRAY,
    RECOMMENDATION_SCORE FLOAT,
    RECOMMENDATION_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (USER_ID)
);

-- Generate product recommendations
INSERT OVERWRITE INTO USER_PRODUCT_RECOMMENDATIONS
WITH
-- Step 1: Get purchase patterns
ProductPurchases AS (
    SELECT 
        PRODUCT_ID, 
        CATEGORY_CODE,
        COUNT(*) as purchase_count,
        AVG(PRICE) as avg_price
    FROM STG_EVENTS_COMBINED
    WHERE EVENT_TYPE = 'purchase'
      AND CATEGORY_CODE IS NOT NULL
      AND PRODUCT_ID IS NOT NULL
    GROUP BY PRODUCT_ID, CATEGORY_CODE
),
-- Step 2: Calculate top products per category
TopProductsPerCategory AS (
    SELECT
        CATEGORY_CODE,
        PRODUCT_ID,
        purchase_count,
        avg_price,
        ROW_NUMBER() OVER (PARTITION BY CATEGORY_CODE ORDER BY purchase_count DESC, avg_price DESC) as rnk
    FROM ProductPurchases
    QUALIFY rnk <= 5  -- Top 5 products per category
),
-- Step 3: Aggregate recommendations
CategoryRecommendations AS (
    SELECT
        CATEGORY_CODE,
        ARRAY_AGG(PRODUCT_ID) WITHIN GROUP (ORDER BY rnk) as recommended_products,
        AVG(purchase_count) as avg_popularity
    FROM TopProductsPerCategory
    GROUP BY 1
)
-- Step 4: Match users to recommendations
SELECT
    CAST(prof.USER_ID AS NUMBER(38,0)) as USER_ID,
    rec.recommended_products,
    rec.avg_popularity as RECOMMENDATION_SCORE
FROM CUSTOMER_360_PROFILE prof
JOIN CategoryRecommendations rec
  ON prof.MOST_VIEWED_CATEGORY = rec.CATEGORY_CODE
WHERE prof.MOST_VIEWED_CATEGORY IS NOT NULL;

-- ===================================================================
-- STEP 5: CREATE OPERATIONAL DASHBOARD TABLES
-- ===================================================================

-- Table 1: Daily Metrics for Executive Dashboards
CREATE OR REPLACE TABLE DAILY_METRICS AS
SELECT 
    DATE(EVENT_TIME) as METRIC_DATE,
    COUNT(DISTINCT USER_ID) as TOTAL_USERS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) as TOTAL_PURCHASES,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) as TOTAL_REVENUE,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) as AVG_ORDER_VALUE,
    CASE 
        WHEN COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) * 100.0 / COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END)
        ELSE 0 
    END as CONVERSION_RATE,
    COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) as TOTAL_VIEWS,
    COUNT(CASE WHEN EVENT_TYPE = 'cart' THEN 1 END) as TOTAL_CART_ADDITIONS
FROM STG_EVENTS_COMBINED
WHERE EVENT_TIME IS NOT NULL
GROUP BY DATE(EVENT_TIME)
ORDER BY METRIC_DATE DESC;

-- Table 2: Product Catalog (Reference Data)
CREATE OR REPLACE TABLE PRODUCT_CATALOG AS
SELECT 
    PRODUCT_ID,
    'Product_' || PRODUCT_ID as PRODUCT_NAME,
    CATEGORY_CODE,
    BRAND,
    AVG(PRICE) as AVG_PRICE,
    COUNT(*) as TOTAL_PURCHASES,
    COUNT(DISTINCT USER_ID) as UNIQUE_BUYERS,
    TRUE as IS_ACTIVE,
    CURRENT_TIMESTAMP() as CREATED_DATE
FROM STG_EVENTS_COMBINED
WHERE PRODUCT_ID IS NOT NULL
GROUP BY PRODUCT_ID, CATEGORY_CODE, BRAND;

-- Table 3: User Segments for Marketing
CREATE OR REPLACE TABLE USER_SEGMENTS AS
SELECT 
    USER_ID,
    CASE 
        WHEN TOTAL_SPEND >= 1000 THEN 'VIP'
        WHEN TOTAL_SPEND >= 500 THEN 'Premium'
        WHEN TOTAL_SPEND >= 100 THEN 'Regular'
        ELSE 'New'
    END as SEGMENT,
    TOTAL_SPEND,
    TOTAL_PURCHASES,
    DAYS_ACTIVE,
    FAVORITE_BRAND,
    MOST_VIEWED_CATEGORY,
    LAST_SEEN_DATE
FROM VW_USER_BEHAVIOR ub
LEFT JOIN CUSTOMER_360_PROFILE c360 ON ub.USER_ID = c360.USER_ID;

-- ===================================================================
-- STEP 6: CREATE ADDITIONAL ANALYTICAL VIEWS
-- ===================================================================

-- View 5: Brand Performance
CREATE OR REPLACE VIEW VW_BRAND_PERFORMANCE AS
SELECT 
    BRAND,
    COUNT(*) as TOTAL_EVENTS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) as PURCHASE_COUNT,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) as TOTAL_REVENUE,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) as AVG_PURCHASE_VALUE,
    COUNT(DISTINCT USER_ID) as UNIQUE_CUSTOMERS,
    COUNT(DISTINCT PRODUCT_ID) as UNIQUE_PRODUCTS
FROM STG_EVENTS_COMBINED
WHERE BRAND IS NOT NULL
GROUP BY BRAND
ORDER BY TOTAL_REVENUE DESC;

-- View 6: User Journey Analysis
CREATE OR REPLACE VIEW VW_USER_JOURNEY AS
SELECT 
    USER_ID,
    EVENT_TYPE,
    COUNT(*) as EVENT_COUNT,
    MIN(EVENT_TIME) as FIRST_EVENT,
    MAX(EVENT_TIME) as LAST_EVENT,
    DATEDIFF('minute', MIN(EVENT_TIME), MAX(EVENT_TIME)) as SESSION_DURATION_MINUTES
FROM STG_EVENTS_COMBINED
WHERE USER_ID IS NOT NULL
GROUP BY USER_ID, EVENT_TYPE
ORDER BY USER_ID, EVENT_TYPE;

-- ===================================================================
-- STEP 7: VERIFICATION AND REPORTING
-- ===================================================================

-- Show data warehouse summary
SELECT 'PHASE 3 DATA WAREHOUSE SUMMARY' as INFO;
SELECT 'Tables created:' as ITEM, COUNT(*) as COUNT FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'ANALYTICS'
UNION ALL
SELECT 'Views created:' as ITEM, COUNT(*) as COUNT FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'ANALYTICS';

-- Show data counts
SELECT 'DATA COUNTS IN ANALYTICS SCHEMA:' as INFO;
SELECT 'STG_EVENTS_COMBINED' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_COMBINED
UNION ALL
SELECT 'CUSTOMER_360_PROFILE' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM CUSTOMER_360_PROFILE
UNION ALL
SELECT 'USER_PRODUCT_RECOMMENDATIONS' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM USER_PRODUCT_RECOMMENDATIONS
UNION ALL
SELECT 'DAILY_METRICS' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM DAILY_METRICS
UNION ALL
SELECT 'PRODUCT_CATALOG' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM PRODUCT_CATALOG
UNION ALL
SELECT 'USER_SEGMENTS' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM USER_SEGMENTS;

-- Show top performing categories
SELECT 'TOP PERFORMING CATEGORIES:' as INFO;
SELECT CATEGORY_CODE, TOTAL_REVENUE, PURCHASE_COUNT, CONVERSION_RATE 
FROM VW_CATEGORY_PERFORMANCE 
ORDER BY TOTAL_REVENUE DESC 
LIMIT 5;

-- Show user segments distribution
SELECT 'USER SEGMENTS DISTRIBUTION:' as INFO;
SELECT SEGMENT, COUNT(*) as USER_COUNT, AVG(TOTAL_SPEND) as AVG_SPEND
FROM USER_SEGMENTS 
GROUP BY SEGMENT 
ORDER BY AVG_SPEND DESC;

-- ===================================================================
-- COMPLETION MESSAGE
-- ===================================================================

SELECT '✅ PHASE 3 DATA WAREHOUSE COMPLETE!' as STATUS;
SELECT '📊 All tables and views created in ECOMMERCE_DB.ANALYTICS' as INFO;
SELECT '🎯 Ready for DynamoDB export and PostgreSQL setup' as INFO;
SELECT '📈 Business intelligence layer ready for dashboards' as INFO; 