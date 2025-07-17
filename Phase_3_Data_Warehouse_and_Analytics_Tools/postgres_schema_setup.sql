-- =============================================================================
-- PostgreSQL Analytics Database Schema Setup
-- =============================================================================
-- This script creates the complete analytics database schema in PostgreSQL
-- that mirrors the Snowflake ANALYTICS schema from Phase 3.
--
-- Usage: psql -d ecommerce_analytics -f postgres_schema_setup.sql
-- =============================================================================

-- Create database (run this separately as superuser if needed)
-- CREATE DATABASE ecommerce_analytics;

-- Connect to the database and set up schema
\c ecommerce_analytics;

-- Create analytics schema
CREATE SCHEMA IF NOT EXISTS analytics;
SET search_path TO analytics;

-- =============================================================================
-- 1. STAGING TABLES (from TMP_ASTRO equivalent)
-- =============================================================================

-- Staging Events Cart Table
DROP TABLE IF EXISTS stg_events_cart CASCADE;
CREATE TABLE stg_events_cart (
    user_id VARCHAR(50) NOT NULL,
    event_time TIMESTAMP NOT NULL,
    event_type VARCHAR(20) NOT NULL DEFAULT 'cart',
    product_id VARCHAR(50),
    price DECIMAL(10,2),
    brand VARCHAR(100),
    category_code VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Staging Events Purchase Table
DROP TABLE IF EXISTS stg_events_purchase CASCADE;
CREATE TABLE stg_events_purchase (
    user_id VARCHAR(50) NOT NULL,
    event_time TIMESTAMP NOT NULL,
    event_type VARCHAR(20) NOT NULL DEFAULT 'purchase',
    product_id VARCHAR(50),
    price DECIMAL(10,2),
    brand VARCHAR(100),
    category_code VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Staging Events View Table
DROP TABLE IF EXISTS stg_events_view CASCADE;
CREATE TABLE stg_events_view (
    user_id VARCHAR(50) NOT NULL,
    event_time TIMESTAMP NOT NULL,
    event_type VARCHAR(20) NOT NULL DEFAULT 'view',
    product_id VARCHAR(50),
    price DECIMAL(10,2),
    brand VARCHAR(100),
    category_code VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 2. CUSTOMER 360 PROFILE TABLE
-- =============================================================================

DROP TABLE IF EXISTS customer_360_profile CASCADE;
CREATE TABLE customer_360_profile (
    user_id VARCHAR(50) PRIMARY KEY,
    favorite_brand VARCHAR(100),
    most_viewed_category VARCHAR(200),
    total_purchases INTEGER DEFAULT 0,
    total_spend DECIMAL(12,2) DEFAULT 0.00,
    last_seen_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 3. USER SEGMENTS TABLE
-- =============================================================================

DROP TABLE IF EXISTS user_segments CASCADE;
CREATE TABLE user_segments (
    user_id VARCHAR(50) PRIMARY KEY,
    segment VARCHAR(20) NOT NULL,
    total_purchases INTEGER DEFAULT 0,
    total_spend DECIMAL(12,2) DEFAULT 0.00,
    last_purchase_date TIMESTAMP,
    days_since_last_purchase INTEGER,
    segment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_segment CHECK (segment IN ('Regular Customer', 'New Customer'))
);

-- =============================================================================
-- 4. USER PRODUCT RECOMMENDATIONS TABLE
-- =============================================================================

DROP TABLE IF EXISTS user_product_recommendations CASCADE;
CREATE TABLE user_product_recommendations (
    recommendation_id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    recommendation_score DECIMAL(5,3) DEFAULT 0.000,
    rank INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id)
);

-- =============================================================================
-- 5. PRODUCT ANALYTICS TABLE
-- =============================================================================

DROP TABLE IF EXISTS product_analytics CASCADE;
CREATE TABLE product_analytics (
    product_id VARCHAR(50) PRIMARY KEY,
    brand VARCHAR(100),
    category_code VARCHAR(200),
    total_views INTEGER DEFAULT 0,
    total_cart_adds INTEGER DEFAULT 0,
    total_purchases INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0.00,
    unique_viewers INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5,4) DEFAULT 0.0000,
    avg_price DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 6. BRAND ANALYTICS TABLE
-- =============================================================================

DROP TABLE IF EXISTS brand_analytics CASCADE;
CREATE TABLE brand_analytics (
    brand VARCHAR(100) PRIMARY KEY,
    total_products INTEGER DEFAULT 0,
    total_views INTEGER DEFAULT 0,
    total_cart_adds INTEGER DEFAULT 0,
    total_purchases INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0.00,
    unique_customers INTEGER DEFAULT 0,
    avg_product_price DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 7. CATEGORY ANALYTICS TABLE
-- =============================================================================

DROP TABLE IF EXISTS category_analytics CASCADE;
CREATE TABLE category_analytics (
    category_code VARCHAR(200) PRIMARY KEY,
    total_products INTEGER DEFAULT 0,
    total_views INTEGER DEFAULT 0,
    total_cart_adds INTEGER DEFAULT 0,
    total_purchases INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0.00,
    unique_customers INTEGER DEFAULT 0,
    avg_product_price DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 8. DAILY ANALYTICS SUMMARY TABLE
-- =============================================================================

DROP TABLE IF EXISTS daily_analytics_summary CASCADE;
CREATE TABLE daily_analytics_summary (
    summary_date DATE PRIMARY KEY,
    total_views INTEGER DEFAULT 0,
    total_cart_adds INTEGER DEFAULT 0,
    total_purchases INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0.00,
    unique_users INTEGER DEFAULT 0,
    new_customers INTEGER DEFAULT 0,
    returning_customers INTEGER DEFAULT 0,
    avg_order_value DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 9. CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

-- Staging tables indexes
CREATE INDEX IF NOT EXISTS idx_stg_cart_user_time ON stg_events_cart(user_id, event_time);
CREATE INDEX IF NOT EXISTS idx_stg_cart_product ON stg_events_cart(product_id);
CREATE INDEX IF NOT EXISTS idx_stg_cart_brand ON stg_events_cart(brand);

CREATE INDEX IF NOT EXISTS idx_stg_purchase_user_time ON stg_events_purchase(user_id, event_time);
CREATE INDEX IF NOT EXISTS idx_stg_purchase_product ON stg_events_purchase(product_id);
CREATE INDEX IF NOT EXISTS idx_stg_purchase_brand ON stg_events_purchase(brand);

CREATE INDEX IF NOT EXISTS idx_stg_view_user_time ON stg_events_view(user_id, event_time);
CREATE INDEX IF NOT EXISTS idx_stg_view_product ON stg_events_view(product_id);
CREATE INDEX IF NOT EXISTS idx_stg_view_brand ON stg_events_view(brand);

-- Analytics tables indexes
CREATE INDEX IF NOT EXISTS idx_user_segments_segment ON user_segments(segment);
CREATE INDEX IF NOT EXISTS idx_user_segments_last_purchase ON user_segments(last_purchase_date);

CREATE INDEX IF NOT EXISTS idx_recommendations_user ON user_product_recommendations(user_id);
CREATE INDEX IF NOT EXISTS idx_recommendations_product ON user_product_recommendations(product_id);
CREATE INDEX IF NOT EXISTS idx_recommendations_score ON user_product_recommendations(recommendation_score DESC);

CREATE INDEX IF NOT EXISTS idx_product_analytics_brand ON product_analytics(brand);
CREATE INDEX IF NOT EXISTS idx_product_analytics_category ON product_analytics(category_code);

-- =============================================================================
-- 10. CREATE VIEWS FOR REPORTING
-- =============================================================================

-- Customer Summary View
CREATE OR REPLACE VIEW customer_summary AS
SELECT 
    c.user_id,
    c.favorite_brand,
    c.most_viewed_category,
    c.total_purchases,
    c.total_spend,
    c.last_seen_date,
    s.segment,
    s.days_since_last_purchase,
    CASE 
        WHEN s.total_purchases >= 5 THEN 'High Value'
        WHEN s.total_purchases >= 2 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS value_tier
FROM customer_360_profile c
LEFT JOIN user_segments s ON c.user_id = s.user_id;

-- Product Performance View
CREATE OR REPLACE VIEW product_performance AS
SELECT 
    p.product_id,
    p.brand,
    p.category_code,
    p.total_views,
    p.total_cart_adds,
    p.total_purchases,
    p.total_revenue,
    p.conversion_rate,
    p.avg_price,
    CASE 
        WHEN p.conversion_rate >= 0.05 THEN 'High Converting'
        WHEN p.conversion_rate >= 0.02 THEN 'Medium Converting'
        ELSE 'Low Converting'
    END AS conversion_tier,
    RANK() OVER (ORDER BY p.total_revenue DESC) as revenue_rank,
    RANK() OVER (ORDER BY p.total_purchases DESC) as sales_rank
FROM product_analytics p;

-- Brand Performance View
CREATE OR REPLACE VIEW brand_performance AS
SELECT 
    b.brand,
    b.total_products,
    b.total_views,
    b.total_cart_adds,
    b.total_purchases,
    b.total_revenue,
    b.unique_customers,
    b.avg_product_price,
    ROUND(b.total_purchases::DECIMAL / NULLIF(b.total_views, 0) * 100, 2) as conversion_percentage,
    RANK() OVER (ORDER BY b.total_revenue DESC) as brand_rank
FROM brand_analytics b;

-- =============================================================================
-- 11. CREATE UPDATE FUNCTIONS
-- =============================================================================

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at columns
CREATE TRIGGER update_customer_360_profile_updated_at 
    BEFORE UPDATE ON customer_360_profile 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_segments_updated_at 
    BEFORE UPDATE ON user_segments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_product_recommendations_updated_at 
    BEFORE UPDATE ON user_product_recommendations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_product_analytics_updated_at 
    BEFORE UPDATE ON product_analytics 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_brand_analytics_updated_at 
    BEFORE UPDATE ON brand_analytics 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_category_analytics_updated_at 
    BEFORE UPDATE ON category_analytics 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 12. GRANT PERMISSIONS
-- =============================================================================

-- Create application user (adjust as needed)
-- CREATE USER ecommerce_app WITH PASSWORD 'your_secure_password';

-- Grant permissions to application user
-- GRANT USAGE ON SCHEMA analytics TO ecommerce_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA analytics TO ecommerce_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA analytics TO ecommerce_app;

-- =============================================================================
-- SCHEMA SETUP COMPLETE
-- =============================================================================

-- Display table information
\dt analytics.*

-- Display view information
\dv analytics.*

COMMENT ON SCHEMA analytics IS 'Analytics schema for ecommerce data warehouse - mirrors Snowflake ANALYTICS schema';

-- Success message
SELECT 'PostgreSQL Analytics Schema Setup Complete!' as status,
       COUNT(*) as tables_created
FROM information_schema.tables 
WHERE table_schema = 'analytics'; 