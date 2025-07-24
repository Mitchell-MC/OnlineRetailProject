#!/usr/bin/env python3
"""
PostgreSQL Recommender System Setup - Fully Idempotent Version
This script sets up a complete PostgreSQL recommender system that can be run multiple times safely.
"""

import os
import sys
import psycopg2
import psycopg2.extras
import logging
import random
import subprocess
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PostgreSQLRecommenderSetupIdempotent:
    def __init__(self):
        self.db_config = {
            'host': os.getenv('POSTGRES_HOST', 'localhost'),
            'port': int(os.getenv('POSTGRES_PORT', '5432')),
            'database': os.getenv('POSTGRES_DATABASE', 'ecommerce_analytics'),
            'user': os.getenv('POSTGRES_USER', 'postgres'),
            'password': os.getenv('POSTGRES_PASSWORD', 'postgres')
        }
        self.sample_data_config = {
            'num_users': 100,
            'num_products': 50,
            'num_interactions': 1000,
            'categories': ['electronics', 'clothing', 'books', 'home', 'sports'],
            'brands': ['Apple', 'Samsung', 'Nike', 'Adidas', 'Sony', 'LG', 'Dell', 'HP']
        }

    def check_postgresql_installation(self):
        """Check if PostgreSQL is installed"""
        logger.info("🔍 Checking PostgreSQL installation...")
        
        try:
            result = subprocess.run(['psql', '--version'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version = result.stdout.strip()
                logger.info(f"✅ PostgreSQL found: {version}")
                return True
            else:
                logger.error("❌ PostgreSQL not found")
                return False
        except Exception as e:
            logger.error(f"❌ PostgreSQL check failed: {e}")
            return False

    def setup_database(self):
        """Setup the database and user - idempotent"""
        logger.info("🏗️ Setting up database...")
        
        try:
            # Connect using password authentication
            conn = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                user=self.db_config['user'],
                password=self.db_config['password'],
                database='postgres'
            )
            conn.autocommit = True
            cursor = conn.cursor()
            
            # Check if database exists
            cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", 
                         (self.db_config['database'],))
            
            if cursor.fetchone():
                logger.info(f"✅ Database already exists: {self.db_config['database']}")
            else:
                cursor.execute(f"CREATE DATABASE {self.db_config['database']}")
                logger.info(f"✅ Database created: {self.db_config['database']}")
            
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to setup database: {e}")
            return False

    def create_recommender_schema(self):
        """Create the recommender system schema - idempotent"""
        logger.info("📊 Creating recommender system schema...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            conn.autocommit = True
            cursor = conn.cursor()
            
            # Create analytics schema if it doesn't exist
            cursor.execute("CREATE SCHEMA IF NOT EXISTS analytics")
            
            # Create tables with proper idempotent SQL
            tables_sql = [
                """
                -- Recommendation Models Table
                DROP TABLE IF EXISTS analytics.recommendation_models CASCADE;
                CREATE TABLE analytics.recommendation_models (
                    model_id SERIAL PRIMARY KEY,
                    model_name VARCHAR(100) NOT NULL UNIQUE,
                    model_type VARCHAR(50) NOT NULL,
                    algorithm VARCHAR(100) NOT NULL,
                    accuracy_score DECIMAL(5,4),
                    is_active BOOLEAN DEFAULT true,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """,
                """
                -- User Behavior Features Table
                DROP TABLE IF EXISTS analytics.user_behavior_features CASCADE;
                CREATE TABLE analytics.user_behavior_features (
                    user_id VARCHAR(50) PRIMARY KEY,
                    total_views INTEGER DEFAULT 0,
                    total_purchases INTEGER DEFAULT 0,
                    total_spend DECIMAL(12,2) DEFAULT 0.00,
                    favorite_category VARCHAR(200),
                    favorite_brand VARCHAR(100),
                    purchase_frequency DECIMAL(5,2) DEFAULT 0.00,
                    avg_order_value DECIMAL(10,2) DEFAULT 0.00,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """,
                """
                -- Product Features Table
                DROP TABLE IF EXISTS analytics.product_features CASCADE;
                CREATE TABLE analytics.product_features (
                    product_id VARCHAR(50) PRIMARY KEY,
                    brand VARCHAR(100),
                    category_code VARCHAR(200),
                    price DECIMAL(10,2),
                    avg_rating DECIMAL(3,2),
                    total_reviews INTEGER DEFAULT 0,
                    popularity_score DECIMAL(5,4) DEFAULT 0.0000,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """,
                """
                -- User-Product Interactions Table
                DROP TABLE IF EXISTS analytics.user_product_interactions CASCADE;
                CREATE TABLE analytics.user_product_interactions (
                    interaction_id SERIAL PRIMARY KEY,
                    user_id VARCHAR(50) NOT NULL,
                    product_id VARCHAR(50) NOT NULL,
                    interaction_type VARCHAR(20) NOT NULL,
                    interaction_strength INTEGER DEFAULT 1,
                    interaction_time TIMESTAMP NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(user_id, product_id, interaction_type, interaction_time)
                );
                """,
                """
                -- Enhanced Recommendations Table
                DROP TABLE IF EXISTS analytics.enhanced_recommendations CASCADE;
                CREATE TABLE analytics.enhanced_recommendations (
                    recommendation_id SERIAL PRIMARY KEY,
                    user_id VARCHAR(50) NOT NULL,
                    product_id VARCHAR(50) NOT NULL,
                    model_id INTEGER REFERENCES analytics.recommendation_models(model_id),
                    recommendation_score DECIMAL(5,4) DEFAULT 0.0000,
                    confidence_score DECIMAL(5,4) DEFAULT 0.0000,
                    recommendation_reason VARCHAR(200),
                    rank_position INTEGER,
                    is_clicked BOOLEAN DEFAULT false,
                    is_purchased BOOLEAN DEFAULT false,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(user_id, product_id, model_id)
                );
                """
            ]
            
            # Execute each table creation with error handling
            for i, sql in enumerate(tables_sql):
                try:
                    cursor.execute(sql)
                    logger.info(f"✅ Table {i+1}/5 created successfully")
                except Exception as e:
                    logger.warning(f"⚠️ Table creation warning (continuing): {e}")
            
            # Create indexes with idempotent approach
            indexes_sql = [
                "DROP INDEX IF EXISTS idx_recommendation_models_active; CREATE INDEX idx_recommendation_models_active ON analytics.recommendation_models(is_active);",
                "DROP INDEX IF EXISTS idx_user_behavior_user; CREATE INDEX idx_user_behavior_user ON analytics.user_behavior_features(user_id);",
                "DROP INDEX IF EXISTS idx_product_features_brand; CREATE INDEX idx_product_features_brand ON analytics.product_features(brand);",
                "DROP INDEX IF EXISTS idx_user_product_interactions_user; CREATE INDEX idx_user_product_interactions_user ON analytics.user_product_interactions(user_id);",
                "DROP INDEX IF EXISTS idx_user_product_interactions_product; CREATE INDEX idx_user_product_interactions_product ON analytics.user_product_interactions(product_id);"
            ]
            
            for sql in indexes_sql:
                try:
                    cursor.execute(sql)
                except Exception as e:
                    logger.warning(f"⚠️ Index creation warning (continuing): {e}")
            
            logger.info("✅ Recommender system schema created")
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to create schema: {e}")
            return False

    def clear_existing_data(self):
        """Clear existing data to ensure clean state - idempotent"""
        logger.info("🧹 Clearing existing data for clean setup...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            conn.autocommit = True
            cursor = conn.cursor()
            
            # Clear data in reverse dependency order
            clear_queries = [
                "DELETE FROM analytics.enhanced_recommendations;",
                "DELETE FROM analytics.user_product_interactions;",
                "DELETE FROM analytics.user_behavior_features;",
                "DELETE FROM analytics.product_features;",
                "DELETE FROM analytics.recommendation_models;"
            ]
            
            for query in clear_queries:
                try:
                    cursor.execute(query)
                except Exception as e:
                    logger.warning(f"⚠️ Clear data warning (continuing): {e}")
            
            logger.info("✅ Existing data cleared")
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to clear data: {e}")
            return False

    def generate_sample_data(self):
        """Generate sample data for the recommender system - idempotent"""
        logger.info("🎲 Generating sample data...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            conn.autocommit = True
            cursor = conn.cursor()
            
            # Generate sample users
            logger.info("Creating sample users...")
            for i in range(self.sample_data_config['num_users']):
                user_id = f"user_{i:04d}"
                total_views = random.randint(10, 200)
                total_purchases = random.randint(0, 20)
                total_spend = round(random.uniform(0, 1000), 2)
                favorite_category = random.choice(self.sample_data_config['categories'])
                favorite_brand = random.choice(self.sample_data_config['brands'])
                
                cursor.execute("""
                    INSERT INTO analytics.user_behavior_features 
                    (user_id, total_views, total_purchases, total_spend, 
                     favorite_category, favorite_brand, purchase_frequency, avg_order_value)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (user_id) DO UPDATE SET
                    total_views = EXCLUDED.total_views,
                    total_purchases = EXCLUDED.total_purchases,
                    total_spend = EXCLUDED.total_spend,
                    favorite_category = EXCLUDED.favorite_category,
                    favorite_brand = EXCLUDED.favorite_brand,
                    purchase_frequency = EXCLUDED.purchase_frequency,
                    avg_order_value = EXCLUDED.avg_order_value
                """, (user_id, total_views, total_purchases, total_spend,
                      favorite_category, favorite_brand,
                      round(random.uniform(0.1, 5.0), 2),
                      round(random.uniform(10, 100), 2)))
            
            # Generate sample products
            logger.info("Creating sample products...")
            for i in range(self.sample_data_config['num_products']):
                product_id = f"product_{i:04d}"
                brand = random.choice(self.sample_data_config['brands'])
                category = random.choice(self.sample_data_config['categories'])
                price = round(random.uniform(10, 500), 2)
                avg_rating = round(random.uniform(1.0, 5.0), 2)
                popularity_score = round(random.uniform(0.0, 1.0), 4)
                
                cursor.execute("""
                    INSERT INTO analytics.product_features 
                    (product_id, brand, category_code, price, avg_rating, 
                     total_reviews, popularity_score)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (product_id) DO UPDATE SET
                    brand = EXCLUDED.brand,
                    category_code = EXCLUDED.category_code,
                    price = EXCLUDED.price,
                    avg_rating = EXCLUDED.avg_rating,
                    total_reviews = EXCLUDED.total_reviews,
                    popularity_score = EXCLUDED.popularity_score
                """, (product_id, brand, category, price, avg_rating,
                      random.randint(0, 100), popularity_score))
            
            # Generate sample interactions
            logger.info("Creating sample interactions...")
            interaction_types = ['view', 'cart', 'purchase']
            interaction_strengths = {'view': 1, 'cart': 2, 'purchase': 3}
            
            for i in range(self.sample_data_config['num_interactions']):
                user_id = f"user_{random.randint(0, self.sample_data_config['num_users']-1):04d}"
                product_id = f"product_{random.randint(0, self.sample_data_config['num_products']-1):04d}"
                interaction_type = random.choice(interaction_types)
                interaction_strength = interaction_strengths[interaction_type]
                
                # Generate random timestamp within last 30 days
                days_ago = random.randint(0, 30)
                hours_ago = random.randint(0, 24)
                minutes_ago = random.randint(0, 60)
                interaction_time = datetime.now() - timedelta(days=days_ago, hours=hours_ago, minutes=minutes_ago)
                
                cursor.execute("""
                    INSERT INTO analytics.user_product_interactions 
                    (user_id, product_id, interaction_type, interaction_strength, interaction_time)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (user_id, product_id, interaction_type, interaction_time) DO NOTHING
                """, (user_id, product_id, interaction_type, interaction_strength, interaction_time))
            
            # Create sample recommendation models
            logger.info("Creating recommendation models...")
            models = [
                ('Collaborative Filtering', 'collaborative', 'user_based', 0.85),
                ('Content Based', 'content_based', 'category_similarity', 0.78),
                ('Hybrid Model', 'hybrid', 'ensemble', 0.92)
            ]
            
            for model_name, model_type, algorithm, accuracy in models:
                cursor.execute("""
                    INSERT INTO analytics.recommendation_models 
                    (model_name, model_type, algorithm, accuracy_score, is_active)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (model_name) DO UPDATE SET
                    model_type = EXCLUDED.model_type,
                    algorithm = EXCLUDED.algorithm,
                    accuracy_score = EXCLUDED.accuracy_score
                """, (model_name, model_type, algorithm, accuracy, True))
            
            conn.close()
            logger.info("✅ Sample data generated successfully")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to generate sample data: {e}")
            return False

    def run_recommendations(self):
        """Run the recommendation engine and generate recommendations - idempotent"""
        logger.info("🚀 Running recommendation engine...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            conn.autocommit = True
            cursor = conn.cursor()
            
            # Clear existing recommendations first
            cursor.execute("DELETE FROM analytics.enhanced_recommendations")
            
            # Get active models
            cursor.execute("SELECT model_id, model_name FROM analytics.recommendation_models WHERE is_active = true")
            active_models = cursor.fetchall()
            
            # Get sample users
            cursor.execute("SELECT user_id FROM analytics.user_behavior_features LIMIT 10")
            users = cursor.fetchall()
            
            # Generate simple recommendations for each user
            for user in users:
                user_id = user[0]
                
                # Get products the user hasn't interacted with
                cursor.execute("""
                    SELECT p.product_id, p.brand, p.category_code, p.price, p.popularity_score
                    FROM analytics.product_features p
                    WHERE p.product_id NOT IN (
                        SELECT DISTINCT product_id 
                        FROM analytics.user_product_interactions 
                        WHERE user_id = %s
                    )
                    ORDER BY p.popularity_score DESC
                    LIMIT 5
                """, (user_id,))
                
                products = cursor.fetchall()
                
                # Create recommendations
                for i, product in enumerate(products):
                    product_id = product[0]
                    # Convert decimal to float for multiplication
                    popularity_score = float(product[4]) if product[4] is not None else 0.0
                    score = round(popularity_score * random.uniform(0.8, 1.2), 4)  # popularity-based score
                    
                    cursor.execute("""
                        INSERT INTO analytics.enhanced_recommendations 
                        (user_id, product_id, model_id, recommendation_score, 
                         confidence_score, recommendation_reason, rank_position)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (user_id, product_id, model_id) DO UPDATE SET
                        recommendation_score = EXCLUDED.recommendation_score,
                        confidence_score = EXCLUDED.confidence_score,
                        rank_position = EXCLUDED.rank_position
                    """, (user_id, product_id, 1, score, 
                          round(score * 0.9, 4), 'Popularity-based recommendation', i + 1))
            
            conn.close()
            logger.info("✅ Recommendations generated successfully")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to generate recommendations: {e}")
            return False

    def display_results(self):
        """Display the results of the setup"""
        logger.info("📊 Displaying setup results...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Count records in each table
            tables = [
                'analytics.user_behavior_features',
                'analytics.product_features', 
                'analytics.user_product_interactions',
                'analytics.recommendation_models',
                'analytics.enhanced_recommendations'
            ]
            
            print("\n" + "="*60)
            print("🎯 POSTGRESQL RECOMMENDER SYSTEM SETUP RESULTS")
            print("="*60)
            
            for table in tables:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                table_name = table.split('.')[-1]
                print(f"📋 {table_name}: {count:,} records")
            
            # Show sample recommendations
            cursor.execute("""
                SELECT user_id, product_id, recommendation_score, recommendation_reason
                FROM analytics.enhanced_recommendations
                ORDER BY recommendation_score DESC
                LIMIT 5
            """)
            
            recommendations = cursor.fetchall()
            if recommendations:
                print(f"\n🎯 Sample Recommendations (Top 5):")
                for i, rec in enumerate(recommendations, 1):
                    print(f"  {i}. User {rec[0]} → Product {rec[1]} (Score: {rec[2]})")
                    print(f"     Reason: {rec[3]}")
            
            conn.close()
            
        except Exception as e:
            logger.error(f"❌ Failed to display results: {e}")

    def run_complete_setup(self):
        """Run the complete setup process - fully idempotent"""
        logger.info("🚀 Starting complete PostgreSQL recommender system setup (idempotent)...")
        
        steps = [
            ("PostgreSQL Installation Check", self.check_postgresql_installation),
            ("Database Setup", self.setup_database),
            ("Schema Creation", self.create_recommender_schema),
            ("Data Cleanup", self.clear_existing_data),
            ("Sample Data Generation", self.generate_sample_data),
            ("Recommendation Generation", self.run_recommendations)
        ]
        
        failed_steps = []
        
        for step_name, step_func in steps:
            logger.info(f"\n📋 Running: {step_name}")
            if not step_func():
                logger.error(f"❌ {step_name} failed")
                failed_steps.append(step_name)
                # Continue with other steps instead of stopping
        
        if failed_steps:
            logger.warning(f"⚠️ Some steps failed: {', '.join(failed_steps)}")
            logger.warning("Continuing with available functionality...")
        
        self.display_results()
        
        if not failed_steps:
            logger.info("\n🎉 PostgreSQL recommender system setup completed successfully!")
        else:
            logger.info(f"\n⚠️ Setup completed with {len(failed_steps)} failed steps")
        
        return len(failed_steps) == 0

def main():
    """Main function"""
    print("🎯 PostgreSQL Recommender System Setup - Fully Idempotent Version")
    print("="*70)
    
    setup = PostgreSQLRecommenderSetupIdempotent()
    
    try:
        success = setup.run_complete_setup()
        if success:
            print("\n🎉 Setup completed successfully!")
        else:
            print("\n⚠️ Setup completed with some issues.")
        
        print("\n💡 Next steps:")
        print("1. Test the setup: python3 test_postgres_recommender.py")
        print("2. Connect to database: psql -h localhost -p 5432 -U postgres -d ecommerce_analytics")
        print("3. View recommendations: SELECT * FROM analytics.enhanced_recommendations LIMIT 10;")
        print("4. Re-run anytime: python3 setup_postgres_recommender_idempotent.py")
            
    except KeyboardInterrupt:
        print("\n⚠️ Setup interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")

if __name__ == "__main__":
    main() 