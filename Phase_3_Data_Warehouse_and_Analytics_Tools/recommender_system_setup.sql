-- =============================================================================
-- PostgreSQL Recommender System Setup
-- =============================================================================
-- This script enhances the existing analytics schema with recommender-specific
-- tables, functions, and sample data for a production-ready recommendation system.
--
-- Usage: psql -d ecommerce_analytics -f recommender_system_setup.sql
-- =============================================================================

-- Connect to the database and set up schema
\c ecommerce_analytics;
SET search_path TO analytics;

-- =============================================================================
-- 1. ENHANCED RECOMMENDATION TABLES
-- =============================================================================

-- Recommendation Models Table (to track different algorithms)
DROP TABLE IF EXISTS recommendation_models CASCADE;
CREATE TABLE recommendation_models (
    model_id SERIAL PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    model_type VARCHAR(50) NOT NULL, -- 'collaborative', 'content_based', 'hybrid'
    algorithm VARCHAR(100) NOT NULL, -- 'user_based', 'item_based', 'matrix_factorization'
    parameters JSONB,
    accuracy_score DECIMAL(5,4),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Behavior Features Table (for ML features)
DROP TABLE IF EXISTS user_behavior_features CASCADE;
CREATE TABLE user_behavior_features (
    user_id VARCHAR(50) PRIMARY KEY,
    total_views INTEGER DEFAULT 0,
    total_purchases INTEGER DEFAULT 0,
    total_spend DECIMAL(12,2) DEFAULT 0.00,
    avg_session_duration INTEGER DEFAULT 0, -- in seconds
    favorite_category VARCHAR(200),
    favorite_brand VARCHAR(100),
    purchase_frequency DECIMAL(5,2) DEFAULT 0.00, -- purchases per month
    avg_order_value DECIMAL(10,2) DEFAULT 0.00,
    last_activity_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product Features Table (for content-based recommendations)
DROP TABLE IF EXISTS product_features CASCADE;
CREATE TABLE product_features (
    product_id VARCHAR(50) PRIMARY KEY,
    brand VARCHAR(100),
    category_code VARCHAR(200),
    price DECIMAL(10,2),
    avg_rating DECIMAL(3,2),
    total_reviews INTEGER DEFAULT 0,
    popularity_score DECIMAL(5,4) DEFAULT 0.0000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User-Product Interactions Table (for collaborative filtering)
DROP TABLE IF EXISTS user_product_interactions CASCADE;
CREATE TABLE user_product_interactions (
    interaction_id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    interaction_type VARCHAR(20) NOT NULL, -- 'view', 'cart', 'purchase', 'like'
    interaction_strength INTEGER DEFAULT 1, -- 1=view, 2=cart, 3=purchase, 4=like
    interaction_time TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id, interaction_type, interaction_time)
);

-- Enhanced Recommendations Table (with more metadata)
DROP TABLE IF EXISTS enhanced_recommendations CASCADE;
CREATE TABLE enhanced_recommendations (
    recommendation_id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    model_id INTEGER REFERENCES recommendation_models(model_id),
    recommendation_score DECIMAL(5,4) DEFAULT 0.0000,
    confidence_score DECIMAL(5,4) DEFAULT 0.0000,
    recommendation_reason VARCHAR(200),
    rank_position INTEGER,
    is_clicked BOOLEAN DEFAULT false,
    is_purchased BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    UNIQUE(user_id, product_id, model_id)
);

-- =============================================================================
-- 2. RECOMMENDATION FUNCTIONS
-- =============================================================================

-- Function to calculate user similarity (for collaborative filtering)
CREATE OR REPLACE FUNCTION calculate_user_similarity(
    user1_id VARCHAR(50),
    user2_id VARCHAR(50)
) RETURNS DECIMAL(5,4) AS $$
DECLARE
    similarity_score DECIMAL(5,4);
BEGIN
    -- Calculate cosine similarity between user behavior vectors
    SELECT COALESCE(
        (
            SELECT SUM(upi1.interaction_strength * upi2.interaction_strength)::DECIMAL
            FROM user_product_interactions upi1
            JOIN user_product_interactions upi2 ON upi1.product_id = upi2.product_id
            WHERE upi1.user_id = user1_id AND upi2.user_id = user2_id
        ) / (
            SQRT(
                (SELECT SUM(interaction_strength * interaction_strength)::DECIMAL
                 FROM user_product_interactions WHERE user_id = user1_id)
            ) * 
            SQRT(
                (SELECT SUM(interaction_strength * interaction_strength)::DECIMAL
                 FROM user_product_interactions WHERE user_id = user2_id)
            )
        ), 0.0
    ) INTO similarity_score;
    
    RETURN COALESCE(similarity_score, 0.0);
END;
$$ LANGUAGE plpgsql;

-- Function to get top similar users
CREATE OR REPLACE FUNCTION get_similar_users(
    target_user_id VARCHAR(50),
    limit_count INTEGER DEFAULT 10
) RETURNS TABLE(
    similar_user_id VARCHAR(50),
    similarity_score DECIMAL(5,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT upi.user_id, calculate_user_similarity(target_user_id, upi.user_id) as similarity_score
    FROM user_product_interactions upi
    WHERE upi.user_id != target_user_id
    ORDER BY similarity_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function to generate content-based recommendations
CREATE OR REPLACE FUNCTION generate_content_based_recommendations(
    target_user_id VARCHAR(50),
    limit_count INTEGER DEFAULT 10
) RETURNS TABLE(
    product_id VARCHAR(50),
    recommendation_score DECIMAL(5,4),
    reason VARCHAR(200)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pf.product_id,
        (pf.avg_rating * 0.4 + pf.popularity_score * 0.6)::DECIMAL(5,4) as recommendation_score,
        'Content-based: High rating and popularity'::VARCHAR(200) as reason
    FROM product_features pf
    JOIN user_behavior_features ubf ON ubf.user_id = target_user_id
    WHERE pf.category_code = ubf.favorite_category
        OR pf.brand = ubf.favorite_brand
    ORDER BY recommendation_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function to generate collaborative filtering recommendations
CREATE OR REPLACE FUNCTION generate_collaborative_recommendations(
    target_user_id VARCHAR(50),
    limit_count INTEGER DEFAULT 10
) RETURNS TABLE(
    product_id VARCHAR(50),
    recommendation_score DECIMAL(5,4),
    reason VARCHAR(200)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        upi.product_id,
        AVG(gs.similarity_score * upi.interaction_strength)::DECIMAL(5,4) as recommendation_score,
        'Collaborative: Similar users liked this'::VARCHAR(200) as reason
    FROM get_similar_users(target_user_id, 20) gs
    JOIN user_product_interactions upi ON gs.similar_user_id = upi.user_id
    WHERE upi.user_id NOT IN (
        SELECT user_id FROM user_product_interactions 
        WHERE user_id = target_user_id
    )
    GROUP BY upi.product_id
    ORDER BY recommendation_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function to generate hybrid recommendations
CREATE OR REPLACE FUNCTION generate_hybrid_recommendations(
    target_user_id VARCHAR(50),
    limit_count INTEGER DEFAULT 10
) RETURNS TABLE(
    product_id VARCHAR(50),
    recommendation_score DECIMAL(5,4),
    reason VARCHAR(200)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        combined.product_id,
        (content_score * 0.3 + collab_score * 0.7)::DECIMAL(5,4) as recommendation_score,
        'Hybrid: Combined content and collaborative filtering'::VARCHAR(200) as reason
    FROM (
        SELECT 
            cb.product_id,
            cb.recommendation_score as content_score,
            COALESCE(cf.recommendation_score, 0) as collab_score
        FROM generate_content_based_recommendations(target_user_id, limit_count) cb
        LEFT JOIN generate_collaborative_recommendations(target_user_id, limit_count) cf 
            ON cb.product_id = cf.product_id
    ) combined
    ORDER BY recommendation_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 3. SAMPLE DATA INSERTION
-- =============================================================================

-- Insert sample recommendation models
INSERT INTO recommendation_models (model_name, model_type, algorithm, parameters, accuracy_score) VALUES
('User-Based CF', 'collaborative', 'user_based', '{"k_neighbors": 20, "min_similarity": 0.1}', 0.7500),
('Item-Based CF', 'collaborative', 'item_based', '{"min_common_users": 5, "similarity_threshold": 0.3}', 0.7200),
('Content-Based', 'content_based', 'content_filtering', '{"feature_weights": {"category": 0.4, "brand": 0.3, "price": 0.3}}', 0.6800),
('Hybrid Model', 'hybrid', 'hybrid', '{"content_weight": 0.3, "collaborative_weight": 0.7}', 0.8200);

-- Insert sample user behavior features
INSERT INTO user_behavior_features (user_id, total_views, total_purchases, total_spend, favorite_category, favorite_brand, purchase_frequency, avg_order_value) VALUES
('user_001', 45, 8, 1250.50, 'electronics', 'Apple', 2.5, 156.31),
('user_002', 32, 12, 890.25, 'clothing', 'Nike', 3.0, 74.19),
('user_003', 67, 5, 2100.75, 'home', 'IKEA', 1.8, 420.15),
('user_004', 23, 15, 3450.00, 'sports', 'Adidas', 4.2, 230.00),
('user_005', 89, 3, 450.80, 'books', 'Amazon', 1.2, 150.27);

-- Insert sample product features
INSERT INTO product_features (product_id, brand, category_code, price, avg_rating, total_reviews, popularity_score) VALUES
('prod_001', 'Apple', 'electronics', 999.99, 4.5, 1250, 0.8500),
('prod_002', 'Nike', 'clothing', 89.99, 4.2, 890, 0.7200),
('prod_003', 'IKEA', 'home', 299.99, 4.1, 567, 0.6800),
('prod_004', 'Adidas', 'sports', 129.99, 4.3, 1234, 0.7800),
('prod_005', 'Samsung', 'electronics', 799.99, 4.4, 987, 0.8200),
('prod_006', 'Apple', 'electronics', 1299.99, 4.6, 2100, 0.9200),
('prod_007', 'Nike', 'sports', 159.99, 4.1, 456, 0.6500),
('prod_008', 'IKEA', 'home', 199.99, 4.0, 789, 0.7000);

-- Insert sample user-product interactions
INSERT INTO user_product_interactions (user_id, product_id, interaction_type, interaction_strength, interaction_time) VALUES
('user_001', 'prod_001', 'view', 1, NOW() - INTERVAL '1 day'),
('user_001', 'prod_001', 'purchase', 3, NOW() - INTERVAL '1 day'),
('user_001', 'prod_006', 'view', 1, NOW() - INTERVAL '2 days'),
('user_002', 'prod_002', 'view', 1, NOW() - INTERVAL '3 hours'),
('user_002', 'prod_002', 'purchase', 3, NOW() - INTERVAL '3 hours'),
('user_002', 'prod_007', 'view', 1, NOW() - INTERVAL '1 day'),
('user_003', 'prod_003', 'view', 1, NOW() - INTERVAL '5 hours'),
('user_003', 'prod_003', 'purchase', 3, NOW() - INTERVAL '5 hours'),
('user_003', 'prod_008', 'view', 1, NOW() - INTERVAL '2 days'),
('user_004', 'prod_004', 'view', 1, NOW() - INTERVAL '1 hour'),
('user_004', 'prod_004', 'purchase', 3, NOW() - INTERVAL '1 hour'),
('user_005', 'prod_005', 'view', 1, NOW() - INTERVAL '4 hours');

-- =============================================================================
-- 4. INDEXES FOR PERFORMANCE
-- =============================================================================

-- Indexes for recommendation tables
CREATE INDEX IF NOT EXISTS idx_recommendation_models_active ON recommendation_models(is_active);
CREATE INDEX IF NOT EXISTS idx_recommendation_models_type ON recommendation_models(model_type);

CREATE INDEX IF NOT EXISTS idx_user_behavior_user ON user_behavior_features(user_id);
CREATE INDEX IF NOT EXISTS idx_user_behavior_category ON user_behavior_features(favorite_category);
CREATE INDEX IF NOT EXISTS idx_user_behavior_brand ON user_behavior_features(favorite_brand);

CREATE INDEX IF NOT EXISTS idx_product_features_brand ON product_features(brand);
CREATE INDEX IF NOT EXISTS idx_product_features_category ON product_features(category_code);
CREATE INDEX IF NOT EXISTS idx_product_features_popularity ON product_features(popularity_score DESC);

CREATE INDEX IF NOT EXISTS idx_user_product_interactions_user ON user_product_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_product_interactions_product ON user_product_interactions(product_id);
CREATE INDEX IF NOT EXISTS idx_user_product_interactions_type ON user_product_interactions(interaction_type);
CREATE INDEX IF NOT EXISTS idx_user_product_interactions_time ON user_product_interactions(interaction_time);

CREATE INDEX IF NOT EXISTS idx_enhanced_recommendations_user ON enhanced_recommendations(user_id);
CREATE INDEX IF NOT EXISTS idx_enhanced_recommendations_product ON enhanced_recommendations(product_id);
CREATE INDEX IF NOT EXISTS idx_enhanced_recommendations_score ON enhanced_recommendations(recommendation_score DESC);
CREATE INDEX IF NOT EXISTS idx_enhanced_recommendations_model ON enhanced_recommendations(model_id);

-- =============================================================================
-- 5. VIEWS FOR EASY QUERYING
-- =============================================================================

-- View for user recommendation summary
CREATE OR REPLACE VIEW user_recommendation_summary AS
SELECT 
    ubf.user_id,
    ubf.favorite_category,
    ubf.favorite_brand,
    COUNT(er.recommendation_id) as total_recommendations,
    AVG(er.recommendation_score) as avg_recommendation_score,
    COUNT(CASE WHEN er.is_clicked = true THEN 1 END) as clicked_recommendations,
    COUNT(CASE WHEN er.is_purchased = true THEN 1 END) as purchased_recommendations
FROM user_behavior_features ubf
LEFT JOIN enhanced_recommendations er ON ubf.user_id = er.user_id
GROUP BY ubf.user_id, ubf.favorite_category, ubf.favorite_brand;

-- View for product recommendation performance
CREATE OR REPLACE VIEW product_recommendation_performance AS
SELECT 
    pf.product_id,
    pf.brand,
    pf.category_code,
    pf.avg_rating,
    pf.popularity_score,
    COUNT(er.recommendation_id) as times_recommended,
    AVG(er.recommendation_score) as avg_recommendation_score,
    COUNT(CASE WHEN er.is_clicked = true THEN 1 END) as times_clicked,
    COUNT(CASE WHEN er.is_purchased = true THEN 1 END) as times_purchased,
    CASE 
        WHEN COUNT(er.recommendation_id) > 0 
        THEN (COUNT(CASE WHEN er.is_purchased = true THEN 1 END)::DECIMAL / COUNT(er.recommendation_id)::DECIMAL) * 100
        ELSE 0 
    END as conversion_rate
FROM product_features pf
LEFT JOIN enhanced_recommendations er ON pf.product_id = er.product_id
GROUP BY pf.product_id, pf.brand, pf.category_code, pf.avg_rating, pf.popularity_score;

-- =============================================================================
-- 6. TRIGGERS FOR AUTOMATIC UPDATES
-- =============================================================================

-- Trigger to update user behavior features when interactions change
CREATE OR REPLACE FUNCTION update_user_behavior_features()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user behavior features based on new interactions
    INSERT INTO user_behavior_features (user_id, total_views, total_purchases, total_spend, last_activity_date)
    SELECT 
        NEW.user_id,
        COUNT(CASE WHEN interaction_type = 'view' THEN 1 END),
        COUNT(CASE WHEN interaction_type = 'purchase' THEN 1 END),
        SUM(CASE WHEN interaction_type = 'purchase' THEN 1 ELSE 0 END), -- Simplified for demo
        MAX(interaction_time)
    FROM user_product_interactions
    WHERE user_id = NEW.user_id
    ON CONFLICT (user_id) DO UPDATE SET
        total_views = EXCLUDED.total_views,
        total_purchases = EXCLUDED.total_purchases,
        total_spend = EXCLUDED.total_spend,
        last_activity_date = EXCLUDED.last_activity_date,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_behavior
    AFTER INSERT OR UPDATE ON user_product_interactions
    FOR EACH ROW EXECUTE FUNCTION update_user_behavior_features();

-- =============================================================================
-- 7. SAMPLE QUERIES FOR TESTING
-- =============================================================================

-- Example: Get recommendations for a specific user
-- SELECT * FROM generate_hybrid_recommendations('user_001', 5);

-- Example: Get similar users
-- SELECT * FROM get_similar_users('user_001', 5);

-- Example: Get user recommendation summary
-- SELECT * FROM user_recommendation_summary WHERE user_id = 'user_001';

-- Example: Get top performing recommended products
-- SELECT * FROM product_recommendation_performance ORDER BY conversion_rate DESC LIMIT 10;

-- =============================================================================
-- COMPLETION MESSAGE
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Recommender system setup completed successfully!';
    RAISE NOTICE 'Sample data has been inserted.';
    RAISE NOTICE 'You can now test the recommendation functions.';
END $$; 