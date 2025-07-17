-- ===================================================================
-- MIGRATE DATA FROM TMP_ASTRO TO ANALYTICS SCHEMA
-- Build out proper data warehouse in ANALYTICS schema
-- ===================================================================

-- Use the correct database and schema
USE ECOMMERCE_DB.ANALYTICS;

-- ===================================================================
-- STEP 1: MIGRATE EXISTING DATA FROM TMP_ASTRO TO ANALYTICS
-- ===================================================================

-- Migrate cart events
INSERT INTO STG_EVENTS_CART
SELECT 
    USER_ID,
    EVENT_TIME,
    EVENT_TYPE,
    PRODUCT_ID,
    PRICE,
    BRAND,
    CATEGORY_CODE
FROM TMP_ASTRO.STG_EVENTS_CART
WHERE USER_ID IS NOT NULL;

-- Migrate purchase events
INSERT INTO STG_EVENTS_PURCHASE
SELECT 
    USER_ID,
    EVENT_TIME,
    EVENT_TYPE,
    PRODUCT_ID,
    PRICE,
    BRAND,
    CATEGORY_CODE
FROM TMP_ASTRO.STG_EVENTS_PURCHASE
WHERE USER_ID IS NOT NULL;

-- Migrate view events
INSERT INTO STG_EVENTS_VIEW
SELECT 
    USER_ID,
    EVENT_TIME,
    EVENT_TYPE,
    PRODUCT_ID,
    PRICE,
    BRAND,
    CATEGORY_CODE
FROM TMP_ASTRO.STG_EVENTS_VIEW
WHERE USER_ID IS NOT NULL;

-- Migrate customer 360 profiles
INSERT INTO CUSTOMER_360_PROFILE
SELECT 
    CAST(USER_ID AS NUMBER(38,0)) as USER_ID,
    FAVORITE_BRAND,
    MOST_VIEWED_CATEGORY,
    TOTAL_PURCHASES,
    TOTAL_SPEND,
    LAST_SEEN_DATE
FROM TMP_ASTRO.CUSTOMER_360_PROFILE
WHERE USER_ID IS NOT NULL;

-- ===================================================================
-- STEP 2: CREATE COMBINED EVENTS TABLE IN ANALYTICS
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
-- STEP 3: CREATE PRODUCT RECOMMENDATIONS TABLE
-- ===================================================================

-- Create table to store product recommendations
CREATE OR REPLACE TABLE USER_PRODUCT_RECOMMENDATIONS (
    USER_ID NUMBER(38,0) NOT NULL,
    RECOMMENDED_PRODUCTS ARRAY,
    RECOMMENDATION_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (USER_ID)
);

-- ===================================================================
-- STEP 4: POPULATE RECOMMENDATIONS
-- ===================================================================

-- Generate product recommendations based on user's favorite category
INSERT OVERWRITE INTO USER_PRODUCT_RECOMMENDATIONS
WITH
-- Step 1: Get the raw purchase data, cleaning it up
ProductPurchases AS (
    SELECT
        PRODUCT_ID,
        CATEGORY_CODE
    FROM STG_EVENTS_COMBINED
    WHERE EVENT_TYPE = 'purchase'
      AND CATEGORY_CODE IS NOT NULL
      AND PRODUCT_ID IS NOT NULL
),
-- Step 2: Calculate the top 5 most purchased products in each category
TopProductsPerCategory AS (
    SELECT
        CATEGORY_CODE,
        PRODUCT_ID,
        COUNT(*) as purchase_count,
        -- Rank products by purchase count within each category
        ROW_NUMBER() OVER (PARTITION BY CATEGORY_CODE ORDER BY purchase_count DESC) as rnk
    FROM ProductPurchases
    GROUP BY 1, 2
    QUALIFY rnk <= 5 -- Keep only the top 5
),
-- Step 3: Aggregate the top 5 product IDs into a single array for each category
CategoryRecommendations AS (
    SELECT
        CATEGORY_CODE,
        -- Group the product IDs into a list
        ARRAY_AGG(PRODUCT_ID) WITHIN GROUP (ORDER BY rnk) as recommended_products
    FROM TopProductsPerCategory
    GROUP BY 1
)
-- Step 4: Join the recommendations back to our Customer 360 profiles
-- This assigns a list of recommended products to each user based on their favorite category
SELECT
    CAST(prof.USER_ID AS NUMBER(38,0)) as USER_ID,
    rec.recommended_products
FROM CUSTOMER_360_PROFILE prof
JOIN CategoryRecommendations rec
  ON prof.MOST_VIEWED_CATEGORY = rec.CATEGORY_CODE
WHERE prof.MOST_VIEWED_CATEGORY IS NOT NULL;

-- ===================================================================
-- STEP 5: CREATE ANALYTICAL VIEWS
-- ===================================================================

-- View for product popularity by category
CREATE OR REPLACE VIEW VW_PRODUCT_POPULARITY AS
SELECT 
    PRODUCT_ID,
    CATEGORY_CODE,
    COUNT(*) as PURCHASE_COUNT,
    AVG(PRICE) as AVG_PRICE,
    SUM(PRICE) as TOTAL_REVENUE
FROM STG_EVENTS_COMBINED
WHERE EVENT_TYPE = 'purchase' 
    AND CATEGORY_CODE IS NOT NULL
    AND PRODUCT_ID IS NOT NULL
GROUP BY PRODUCT_ID, CATEGORY_CODE
ORDER BY PURCHASE_COUNT DESC;

-- View for user behavior analytics
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
    MAX(EVENT_TIME) as LAST_SEEN
FROM STG_EVENTS_COMBINED
WHERE USER_ID IS NOT NULL
GROUP BY USER_ID;

-- View for category performance
CREATE OR REPLACE VIEW VW_CATEGORY_PERFORMANCE AS
SELECT 
    CATEGORY_CODE,
    COUNT(*) as TOTAL_EVENTS,
    COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) as PURCHASE_COUNT,
    COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) as VIEW_COUNT,
    SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) as TOTAL_REVENUE,
    AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) as AVG_PURCHASE_VALUE
FROM STG_EVENTS_COMBINED
WHERE CATEGORY_CODE IS NOT NULL
GROUP BY CATEGORY_CODE
ORDER BY TOTAL_REVENUE DESC;

-- ===================================================================
-- STEP 6: CREATE OPERATIONAL DASHBOARD TABLES
-- ===================================================================

-- Table for daily metrics
CREATE OR REPLACE TABLE DAILY_METRICS (
    METRIC_DATE DATE NOT NULL,
    TOTAL_USERS NUMBER(38,0),
    TOTAL_PURCHASES NUMBER(38,0),
    TOTAL_REVENUE FLOAT,
    AVG_ORDER_VALUE FLOAT,
    CONVERSION_RATE FLOAT,
    PRIMARY KEY (METRIC_DATE)
);

-- Table for product catalog (for reference)
CREATE OR REPLACE TABLE PRODUCT_CATALOG (
    PRODUCT_ID VARCHAR(16777216) NOT NULL,
    PRODUCT_NAME VARCHAR(16777216),
    CATEGORY_CODE VARCHAR(16777216),
    BRAND VARCHAR(16777216),
    PRICE NUMBER(10,2),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (PRODUCT_ID)
);

-- ===================================================================
-- STEP 7: VERIFICATION QUERIES
-- ===================================================================

-- Show data counts in ANALYTICS schema
SELECT 'ANALYTICS SCHEMA DATA COUNTS:' as INFO;
SELECT 'STG_EVENTS_CART' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_CART
UNION ALL
SELECT 'STG_EVENTS_PURCHASE' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_PURCHASE
UNION ALL
SELECT 'STG_EVENTS_VIEW' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_VIEW
UNION ALL
SELECT 'STG_EVENTS_COMBINED' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_COMBINED
UNION ALL
SELECT 'CUSTOMER_360_PROFILE' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM CUSTOMER_360_PROFILE
UNION ALL
SELECT 'USER_PRODUCT_RECOMMENDATIONS' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM USER_PRODUCT_RECOMMENDATIONS;

-- Show available views
SELECT 'Available Views in ANALYTICS:' as INFO;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'ANALYTICS';

-- ===================================================================
-- STEP 8: CLEANUP TMP_ASTRO (OPTIONAL)
-- ===================================================================

-- Uncomment the following lines if you want to clean up the temporary schema
-- DROP TABLE IF EXISTS TMP_ASTRO.STG_EVENTS_CART;
-- DROP TABLE IF EXISTS TMP_ASTRO.STG_EVENTS_PURCHASE;
-- DROP TABLE IF EXISTS TMP_ASTRO.STG_EVENTS_VIEW;
-- DROP TABLE IF EXISTS TMP_ASTRO.CUSTOMER_360_PROFILE;

-- ===================================================================
-- COMPLETION MESSAGE
-- ===================================================================

SELECT '✅ Migration to ANALYTICS schema complete!' as STATUS;
SELECT '📊 All data now resides in ECOMMERCE_DB.ANALYTICS' as INFO;
SELECT '🎯 Ready for Phase 3 implementation' as INFO; 