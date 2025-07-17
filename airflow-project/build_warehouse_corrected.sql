-- ===================================================================
-- CORRECTED DATA WAREHOUSE BUILD - PHASE 3 COMPLETE
-- Build all remaining components using populated ANALYTICS tables
-- ===================================================================

USE ECOMMERCE_DB.ANALYTICS;

-- ===================================================================
-- STEP 1: CREATE COMBINED EVENTS TABLE (if not exists)
-- ===================================================================

-- Create a combined staging table for all events
CREATE OR REPLACE TABLE STG_EVENTS_COMBINED AS
SELECT 
    CAST(user_id AS STRING) AS user_id,
    CAST(event_time AS TIMESTAMP) AS event_time,
    CAST(event_type AS STRING) AS event_type,
    CAST(product_id AS STRING) AS product_id,
    CAST(price AS DOUBLE) AS price,
    CAST(brand AS STRING) AS brand,
    CAST(category_code AS STRING) AS category_code
FROM STG_EVENTS_CART
UNION ALL
SELECT 
    CAST(user_id AS STRING),
    CAST(event_time AS TIMESTAMP),
    CAST(event_type AS STRING),
    CAST(product_id AS STRING),
    CAST(price AS DOUBLE),
    CAST(brand AS STRING),
    CAST(category_code AS STRING)
FROM STG_EVENTS_PURCHASE
UNION ALL
SELECT 
    CAST(user_id AS STRING),
    CAST(event_time AS TIMESTAMP),
    CAST(event_type AS STRING),
    CAST(product_id AS STRING),
    CAST(price AS DOUBLE),
    CAST(brand AS STRING),
    CAST(category_code AS STRING)
FROM STG_EVENTS_VIEW;

-- ===================================================================
-- STEP 2: CREATE ANALYTICAL VIEWS
-- ===================================================================

-- View 1: Product Popularity by Category
CREATE OR REPLACE VIEW VW_PRODUCT_POPULARITY AS
SELECT 
    product_id,
    category_code,
    COUNT(*) as purchase_count,
    AVG(price) as avg_price,
    SUM(price) as total_revenue,
    COUNT(DISTINCT user_id) as unique_buyers
FROM STG_EVENTS_COMBINED
WHERE event_type = 'purchase' 
    AND category_code IS NOT NULL
    AND product_id IS NOT NULL
GROUP BY product_id, category_code
ORDER BY purchase_count DESC;

-- View 2: User Behavior Analytics
CREATE OR REPLACE VIEW VW_USER_BEHAVIOR AS
SELECT 
    user_id,
    COUNT(*) as total_events,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) as purchase_count,
    COUNT(CASE WHEN event_type = 'view' THEN 1 END) as view_count,
    COUNT(CASE WHEN event_type = 'cart' THEN 1 END) as cart_count,
    SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) as total_spend,
    AVG(CASE WHEN event_type = 'purchase' THEN price END) as avg_purchase_value,
    MIN(event_time) as first_seen,
    MAX(event_time) as last_seen,
    DATEDIFF('day', MIN(event_time), MAX(event_time)) as days_active,
    CASE 
        WHEN COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN event_type = 'view' THEN 1 END) * 100.0 / COUNT(CASE WHEN event_type = 'purchase' THEN 1 END)
        ELSE 0 
    END as view_to_purchase_ratio
FROM STG_EVENTS_COMBINED
WHERE user_id IS NOT NULL
GROUP BY user_id;

-- View 3: Category Performance
CREATE OR REPLACE VIEW VW_CATEGORY_PERFORMANCE AS
SELECT 
    category_code,
    COUNT(*) as total_events,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) as purchase_count,
    COUNT(CASE WHEN event_type = 'view' THEN 1 END) as view_count,
    COUNT(CASE WHEN event_type = 'cart' THEN 1 END) as cart_count,
    SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) as total_revenue,
    AVG(CASE WHEN event_type = 'purchase' THEN price END) as avg_purchase_value,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT product_id) as unique_products,
    CASE 
        WHEN COUNT(CASE WHEN event_type = 'view' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) * 100.0 / COUNT(CASE WHEN event_type = 'view' THEN 1 END)
        ELSE 0 
    END as conversion_rate
FROM STG_EVENTS_COMBINED
WHERE category_code IS NOT NULL
GROUP BY category_code
ORDER BY total_revenue DESC;

-- View 4: Daily Performance Metrics
CREATE OR REPLACE VIEW VW_DAILY_PERFORMANCE AS
SELECT 
    DATE(event_time) as event_date,
    COUNT(DISTINCT user_id) as daily_active_users,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) as daily_purchases,
    SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) as daily_revenue,
    AVG(CASE WHEN event_type = 'purchase' THEN price END) as avg_order_value,
    COUNT(CASE WHEN event_type = 'view' THEN 1 END) as daily_views,
    COUNT(CASE WHEN event_type = 'cart' THEN 1 END) as daily_cart_additions,
    CASE 
        WHEN COUNT(CASE WHEN event_type = 'view' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) * 100.0 / COUNT(CASE WHEN event_type = 'view' THEN 1 END)
        ELSE 0 
    END as daily_conversion_rate
FROM STG_EVENTS_COMBINED
WHERE event_time IS NOT NULL
GROUP BY DATE(event_time)
ORDER BY event_date DESC;

-- View 5: Brand Performance
CREATE OR REPLACE VIEW VW_BRAND_PERFORMANCE AS
SELECT 
    brand,
    COUNT(*) as total_events,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) as purchase_count,
    SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) as total_revenue,
    AVG(CASE WHEN event_type = 'purchase' THEN price END) as avg_purchase_value,
    COUNT(DISTINCT user_id) as unique_customers,
    COUNT(DISTINCT product_id) as unique_products
FROM STG_EVENTS_COMBINED
WHERE brand IS NOT NULL
GROUP BY brand
ORDER BY total_revenue DESC;

-- View 6: User Journey Analysis
CREATE OR REPLACE VIEW VW_USER_JOURNEY AS
SELECT 
    user_id,
    event_type,
    COUNT(*) as event_count,
    MIN(event_time) as first_event,
    MAX(event_time) as last_event,
    DATEDIFF('minute', MIN(event_time), MAX(event_time)) as session_duration_minutes
FROM STG_EVENTS_COMBINED
WHERE user_id IS NOT NULL
GROUP BY user_id, event_type
ORDER BY user_id, event_type;

-- ===================================================================
-- STEP 3: CREATE PRODUCT RECOMMENDATIONS
-- ===================================================================

-- Create recommendations table
CREATE OR REPLACE TABLE USER_PRODUCT_RECOMMENDATIONS (
    user_id STRING NOT NULL,
    recommended_products ARRAY,
    recommendation_score FLOAT,
    recommendation_date TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP()
);

-- Generate product recommendations
INSERT OVERWRITE INTO USER_PRODUCT_RECOMMENDATIONS
WITH
-- Step 1: Get purchase patterns
ProductPurchases AS (
    SELECT 
        product_id, 
        category_code,
        COUNT(*) as purchase_count,
        AVG(price) as avg_price
    FROM STG_EVENTS_COMBINED
    WHERE event_type = 'purchase'
      AND category_code IS NOT NULL
      AND product_id IS NOT NULL
    GROUP BY product_id, category_code
),
-- Step 2: Calculate top products per category
TopProductsPerCategory AS (
    SELECT
        category_code,
        product_id,
        purchase_count,
        avg_price,
        ROW_NUMBER() OVER (PARTITION BY category_code ORDER BY purchase_count DESC, avg_price DESC) as rnk
    FROM ProductPurchases
    QUALIFY rnk <= 5  -- Top 5 products per category
),
-- Step 3: Aggregate recommendations
CategoryRecommendations AS (
    SELECT
        category_code,
        ARRAY_AGG(product_id) WITHIN GROUP (ORDER BY rnk) as recommended_products,
        AVG(purchase_count) as avg_popularity
    FROM TopProductsPerCategory
    GROUP BY 1
)
-- Step 4: Match users to recommendations
SELECT
    CAST(prof.USER_ID AS STRING) as user_id,
    rec.recommended_products,
    rec.avg_popularity as recommendation_score
FROM CUSTOMER_360_PROFILE prof
JOIN CategoryRecommendations rec
  ON prof.MOST_VIEWED_CATEGORY = rec.category_code
WHERE prof.MOST_VIEWED_CATEGORY IS NOT NULL;

-- ===================================================================
-- STEP 4: CREATE OPERATIONAL DASHBOARD TABLES
-- ===================================================================

-- Table 1: Daily Metrics for Executive Dashboards
CREATE OR REPLACE TABLE DAILY_METRICS AS
SELECT 
    DATE(event_time) as metric_date,
    COUNT(DISTINCT user_id) as total_users,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) as total_purchases,
    SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) as total_revenue,
    AVG(CASE WHEN event_type = 'purchase' THEN price END) as avg_order_value,
    CASE 
        WHEN COUNT(CASE WHEN event_type = 'view' THEN 1 END) > 0 
        THEN COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) * 100.0 / COUNT(CASE WHEN event_type = 'view' THEN 1 END)
        ELSE 0 
    END as conversion_rate,
    COUNT(CASE WHEN event_type = 'view' THEN 1 END) as total_views,
    COUNT(CASE WHEN event_type = 'cart' THEN 1 END) as total_cart_additions
FROM STG_EVENTS_COMBINED
WHERE event_time IS NOT NULL
GROUP BY DATE(event_time)
ORDER BY metric_date DESC;

-- Table 2: Product Catalog (Reference Data)
CREATE OR REPLACE TABLE PRODUCT_CATALOG AS
SELECT 
    product_id,
    'Product_' || product_id as product_name,
    category_code,
    brand,
    AVG(price) as avg_price,
    COUNT(*) as total_purchases,
    COUNT(DISTINCT user_id) as unique_buyers,
    TRUE as is_active,
    CURRENT_TIMESTAMP() as created_date
FROM STG_EVENTS_COMBINED
WHERE product_id IS NOT NULL
GROUP BY product_id, category_code, brand;

-- Table 3: User Segments for Marketing
CREATE OR REPLACE TABLE USER_SEGMENTS AS
SELECT 
    ub.user_id,
    CASE 
        WHEN ub.total_spend >= 1000 THEN 'VIP'
        WHEN ub.total_spend >= 500 THEN 'Premium'
        WHEN ub.total_spend >= 100 THEN 'Regular'
        ELSE 'New'
    END as segment,
    ub.total_spend,
    ub.purchase_count as total_purchases,
    ub.days_active,
    c360.FAVORITE_BRAND as favorite_brand,
    c360.MOST_VIEWED_CATEGORY as most_viewed_category,
    c360.LAST_SEEN_DATE as last_seen_date
FROM VW_USER_BEHAVIOR ub
LEFT JOIN CUSTOMER_360_PROFILE c360 ON ub.user_id = c360.USER_ID;

-- ===================================================================
-- STEP 5: VERIFICATION AND REPORTING
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
SELECT category_code, total_revenue, purchase_count, conversion_rate 
FROM VW_CATEGORY_PERFORMANCE 
ORDER BY total_revenue DESC 
LIMIT 5;

-- Show user segments distribution
SELECT 'USER SEGMENTS DISTRIBUTION:' as INFO;
SELECT segment, COUNT(*) as user_count, AVG(total_spend) as avg_spend
FROM USER_SEGMENTS 
GROUP BY segment 
ORDER BY avg_spend DESC;

-- Show sample recommendations
SELECT 'SAMPLE RECOMMENDATIONS:' as INFO;
SELECT user_id, recommended_products, recommendation_score
FROM USER_PRODUCT_RECOMMENDATIONS
LIMIT 5;

-- ===================================================================
-- COMPLETION MESSAGE
-- ===================================================================

SELECT '✅ PHASE 3 DATA WAREHOUSE COMPLETE!' as STATUS;
SELECT '📊 All tables and views created in ECOMMERCE_DB.ANALYTICS' as INFO;
SELECT '🎯 Ready for DynamoDB export and PostgreSQL setup' as INFO;
SELECT '📈 Business intelligence layer ready for dashboards' as INFO;
SELECT '🚀 Your data warehouse is now production-ready!' as INFO; 