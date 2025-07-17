-- ===================================================================
-- SNOWFLAKE DATA WAREHOUSE SETUP FOR PHASE 3
-- E-commerce Analytics Platform
-- ===================================================================

-- Use the correct database and schema
USE ECOMMERCE_DB.ANALYTICS;

-- ===================================================================
-- PART 1: ENSURE EXISTING TABLES ARE PROPERLY STRUCTURED
-- ===================================================================

-- Verify and update staging tables if needed
CREATE OR REPLACE TABLE STG_EVENTS_CART (
    USER_ID VARCHAR(16777216),
    EVENT_TIME TIMESTAMP_NTZ(9),
    EVENT_TYPE VARCHAR(16777216),
    PRODUCT_ID VARCHAR(16777216),
    PRICE NUMBER(10,2),
    BRAND VARCHAR(16777216),
    CATEGORY_CODE VARCHAR(16777216)
);

CREATE OR REPLACE TABLE STG_EVENTS_PURCHASE (
    USER_ID VARCHAR(16777216),
    EVENT_TIME TIMESTAMP_NTZ(9),
    EVENT_TYPE VARCHAR(16777216),
    PRODUCT_ID VARCHAR(16777216),
    PRICE NUMBER(10,2),
    BRAND VARCHAR(16777216),
    CATEGORY_CODE VARCHAR(16777216)
);

CREATE OR REPLACE TABLE STG_EVENTS_VIEW (
    USER_ID VARCHAR(16777216),
    EVENT_TIME TIMESTAMP_NTZ(9),
    EVENT_TYPE VARCHAR(16777216),
    PRODUCT_ID VARCHAR(16777216),
    PRICE NUMBER(10,2),
    BRAND VARCHAR(16777216),
    CATEGORY_CODE VARCHAR(16777216)
);

-- Ensure CUSTOMER_360_PROFILE table exists with proper structure
CREATE OR REPLACE TABLE CUSTOMER_360_PROFILE (
    USER_ID NUMBER(38,0) NOT NULL,
    FAVORITE_BRAND VARCHAR(16777216),
    MOST_VIEWED_CATEGORY VARCHAR(16777216),
    TOTAL_PURCHASES NUMBER(38,0),
    TOTAL_SPEND FLOAT,
    LAST_SEEN_DATE TIMESTAMP_NTZ(9),
    PRIMARY KEY (USER_ID)
);

-- ===================================================================
-- PART 2: CREATE COMBINED EVENTS TABLE
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
-- PART 3: CREATE PRODUCT RECOMMENDATIONS TABLE
-- ===================================================================

-- Create table to store product recommendations
CREATE OR REPLACE TABLE USER_PRODUCT_RECOMMENDATIONS (
    USER_ID NUMBER(38,0) NOT NULL,
    RECOMMENDED_PRODUCTS ARRAY,
    RECOMMENDATION_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (USER_ID)
);

-- ===================================================================
-- PART 4: CREATE ANALYTICAL VIEWS
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
-- PART 5: POPULATE RECOMMENDATIONS
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
-- PART 6: CREATE OPERATIONAL DASHBOARD TABLES
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
-- PART 7: CREATE STORED PROCEDURES FOR AUTOMATION
-- ===================================================================

-- Procedure to refresh daily metrics
CREATE OR REPLACE PROCEDURE REFRESH_DAILY_METRICS()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    today_date DATE := CURRENT_DATE();
    total_users NUMBER;
    total_purchases NUMBER;
    total_revenue FLOAT;
    avg_order_value FLOAT;
    conversion_rate FLOAT;
BEGIN
    -- Calculate daily metrics
    SELECT 
        COUNT(DISTINCT USER_ID),
        COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END),
        SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END),
        AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END),
        COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) * 100.0 / COUNT(*)
    INTO :total_users, :total_purchases, :total_revenue, :avg_order_value, :conversion_rate
    FROM STG_EVENTS_COMBINED
    WHERE DATE(EVENT_TIME) = :today_date;
    
    -- Insert or update daily metrics
    MERGE INTO DAILY_METRICS AS target
    USING (SELECT :today_date as METRIC_DATE) AS source
    ON target.METRIC_DATE = source.METRIC_DATE
    WHEN MATCHED THEN
        UPDATE SET
            TOTAL_USERS = :total_users,
            TOTAL_PURCHASES = :total_purchases,
            TOTAL_REVENUE = :total_revenue,
            AVG_ORDER_VALUE = :avg_order_value,
            CONVERSION_RATE = :conversion_rate
    WHEN NOT MATCHED THEN
        INSERT (METRIC_DATE, TOTAL_USERS, TOTAL_PURCHASES, TOTAL_REVENUE, AVG_ORDER_VALUE, CONVERSION_RATE)
        VALUES (:today_date, :total_users, :total_purchases, :total_revenue, :avg_order_value, :conversion_rate);
    
    RETURN 'Daily metrics refreshed successfully for ' || :today_date;
END;
$$;

-- Procedure to refresh recommendations
CREATE OR REPLACE PROCEDURE REFRESH_RECOMMENDATIONS()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Clear existing recommendations
    DELETE FROM USER_PRODUCT_RECOMMENDATIONS;
    
    -- Re-populate recommendations using the same logic as above
    INSERT INTO USER_PRODUCT_RECOMMENDATIONS
    WITH
    ProductPurchases AS (
        SELECT PRODUCT_ID, CATEGORY_CODE
        FROM STG_EVENTS_COMBINED
        WHERE EVENT_TYPE = 'purchase'
          AND CATEGORY_CODE IS NOT NULL
          AND PRODUCT_ID IS NOT NULL
    ),
    TopProductsPerCategory AS (
        SELECT
            CATEGORY_CODE,
            PRODUCT_ID,
            COUNT(*) as purchase_count,
            ROW_NUMBER() OVER (PARTITION BY CATEGORY_CODE ORDER BY purchase_count DESC) as rnk
        FROM ProductPurchases
        GROUP BY 1, 2
        QUALIFY rnk <= 5
    ),
    CategoryRecommendations AS (
        SELECT
            CATEGORY_CODE,
            ARRAY_AGG(PRODUCT_ID) WITHIN GROUP (ORDER BY rnk) as recommended_products
        FROM TopProductsPerCategory
        GROUP BY 1
    )
    SELECT
        CAST(prof.USER_ID AS NUMBER(38,0)) as USER_ID,
        rec.recommended_products
    FROM CUSTOMER_360_PROFILE prof
    JOIN CategoryRecommendations rec
      ON prof.MOST_VIEWED_CATEGORY = rec.CATEGORY_CODE
    WHERE prof.MOST_VIEWED_CATEGORY IS NOT NULL;
    
    RETURN 'Recommendations refreshed successfully';
END;
$$;

-- ===================================================================
-- PART 8: VERIFICATION QUERIES
-- ===================================================================

-- Verify table structures
SELECT 'Tables created successfully' as STATUS;

-- Show sample data from key tables
SELECT 'CUSTOMER_360_PROFILE sample:' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM CUSTOMER_360_PROFILE
UNION ALL
SELECT 'USER_PRODUCT_RECOMMENDATIONS sample:' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM USER_PRODUCT_RECOMMENDATIONS
UNION ALL
SELECT 'STG_EVENTS_COMBINED sample:' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM STG_EVENTS_COMBINED;

-- Show available views
SELECT 'Available Views:' as INFO;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'ANALYTICS';

-- ===================================================================
-- PART 9: USAGE EXAMPLES
-- ===================================================================

-- Example: Get recommendations for a specific user
-- SELECT * FROM USER_PRODUCT_RECOMMENDATIONS WHERE USER_ID = 1234;

-- Example: Get top products by category
-- SELECT * FROM VW_PRODUCT_POPULARITY WHERE CATEGORY_CODE = 'electronics' LIMIT 10;

-- Example: Get user behavior analytics
-- SELECT * FROM VW_USER_BEHAVIOR ORDER BY TOTAL_SPEND DESC LIMIT 10;

-- Example: Get category performance
-- SELECT * FROM VW_CATEGORY_PERFORMANCE;

-- Example: Refresh metrics (run daily)
-- CALL REFRESH_DAILY_METRICS();

-- Example: Refresh recommendations (run weekly)
-- CALL REFRESH_RECOMMENDATIONS();

-- ===================================================================
-- COMPLETION MESSAGE
-- ===================================================================

SELECT '✅ Snowflake Data Warehouse Setup Complete!' as STATUS;
SELECT '📊 Tables created: STG_EVENTS_COMBINED, USER_PRODUCT_RECOMMENDATIONS, DAILY_METRICS, PRODUCT_CATALOG' as INFO;
SELECT '👁️ Views created: VW_PRODUCT_POPULARITY, VW_USER_BEHAVIOR, VW_CATEGORY_PERFORMANCE' as INFO;
SELECT '⚙️ Procedures created: REFRESH_DAILY_METRICS(), REFRESH_RECOMMENDATIONS()' as INFO; 