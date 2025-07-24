#!/usr/bin/env python3
"""
Test Script for PostgreSQL Recommender System
This script tests the recommender system setup and functionality.
"""

import psycopg2
import psycopg2.extras
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PostgreSQLRecommenderTest:
    def __init__(self):
        self.db_config = {
            'host': 'localhost',
            'port': 5432,
            'database': 'ecommerce_analytics',
            'user': 'postgres',
            'password': 'postgres123'
        }

    def test_connection(self):
        """Test database connection"""
        logger.info("🔍 Testing database connection...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Test basic query
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
            logger.info(f"✅ Database connection successful")
            logger.info(f"   PostgreSQL version: {version.split(',')[0]}")
            
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"❌ Database connection failed: {e}")
            return False

    def test_schema_exists(self):
        """Test if analytics schema exists"""
        logger.info("🔍 Testing analytics schema...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Check if analytics schema exists
            cursor.execute("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name = 'analytics'
            """)
            
            if cursor.fetchone():
                logger.info("✅ Analytics schema exists")
                
                # List tables in analytics schema
                cursor.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = 'analytics'
                    ORDER BY table_name
                """)
                
                tables = [row[0] for row in cursor.fetchall()]
                logger.info(f"   Tables found: {', '.join(tables)}")
                
                conn.close()
                return True
            else:
                logger.error("❌ Analytics schema not found")
                conn.close()
                return False
                
        except Exception as e:
            logger.error(f"❌ Schema test failed: {e}")
            return False

    def test_data_exists(self):
        """Test if sample data exists"""
        logger.info("🔍 Testing sample data...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Check user behavior features
            cursor.execute("SELECT COUNT(*) FROM analytics.user_behavior_features")
            user_count = cursor.fetchone()[0]
            logger.info(f"   Users: {user_count:,}")
            
            # Check product features
            cursor.execute("SELECT COUNT(*) FROM analytics.product_features")
            product_count = cursor.fetchone()[0]
            logger.info(f"   Products: {product_count:,}")
            
            # Check interactions
            cursor.execute("SELECT COUNT(*) FROM analytics.user_product_interactions")
            interaction_count = cursor.fetchone()[0]
            logger.info(f"   Interactions: {interaction_count:,}")
            
            # Check recommendations
            cursor.execute("SELECT COUNT(*) FROM analytics.enhanced_recommendations")
            recommendation_count = cursor.fetchone()[0]
            logger.info(f"   Recommendations: {recommendation_count:,}")
            
            # Check models
            cursor.execute("SELECT COUNT(*) FROM analytics.recommendation_models")
            model_count = cursor.fetchone()[0]
            logger.info(f"   Models: {model_count}")
            
            conn.close()
            
            if user_count > 0 and product_count > 0:
                logger.info("✅ Sample data exists")
                return True
            else:
                logger.error("❌ No sample data found")
                return False
                
        except Exception as e:
            logger.error(f"❌ Data test failed: {e}")
            return False

    def test_recommendations(self):
        """Test recommendation functionality"""
        logger.info("🔍 Testing recommendation functionality...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Get a sample user
            cursor.execute("""
                SELECT user_id, favorite_category, total_purchases
                FROM analytics.user_behavior_features
                LIMIT 1
            """)
            
            user_data = cursor.fetchone()
            if not user_data:
                logger.error("❌ No users found for testing")
                return False
            
            user_id, favorite_category, total_purchases = user_data
            logger.info(f"   Testing with user: {user_id}")
            logger.info(f"   Favorite category: {favorite_category}")
            logger.info(f"   Total purchases: {total_purchases}")
            
            # Get recommendations for this user
            cursor.execute("""
                SELECT product_id, recommendation_score, confidence_score, rank_position
                FROM analytics.enhanced_recommendations
                WHERE user_id = %s
                ORDER BY recommendation_score DESC
                LIMIT 5
            """, (user_id,))
            
            recommendations = cursor.fetchall()
            
            if recommendations:
                logger.info("✅ Recommendations found:")
                for i, (product_id, score, confidence, rank) in enumerate(recommendations, 1):
                    logger.info(f"   {i}. Product: {product_id}")
                    logger.info(f"      Score: {score:.4f} | Confidence: {confidence:.4f} | Rank: {rank}")
            else:
                logger.warning("⚠️ No recommendations found for this user")
            
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"❌ Recommendation test failed: {e}")
            return False

    def test_performance_views(self):
        """Test performance views"""
        logger.info("🔍 Testing performance views...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Test user recommendation summary view
            cursor.execute("""
                SELECT COUNT(*) FROM analytics.user_recommendation_summary
            """)
            summary_count = cursor.fetchone()[0]
            logger.info(f"   User recommendation summaries: {summary_count}")
            
            # Test product recommendation performance view
            cursor.execute("""
                SELECT COUNT(*) FROM analytics.product_recommendation_performance
            """)
            performance_count = cursor.fetchone()[0]
            logger.info(f"   Product performance records: {performance_count}")
            
            conn.close()
            logger.info("✅ Performance views working")
            return True
            
        except Exception as e:
            logger.error(f"❌ Performance view test failed: {e}")
            return False

    def run_complete_test(self):
        """Run all tests"""
        logger.info("🚀 Starting PostgreSQL recommender system tests...")
        
        tests = [
            ("Database Connection", self.test_connection),
            ("Schema Existence", self.test_schema_exists),
            ("Sample Data", self.test_data_exists),
            ("Recommendations", self.test_recommendations),
            ("Performance Views", self.test_performance_views)
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            logger.info(f"\n📋 Running test: {test_name}")
            if test_func():
                passed += 1
                logger.info(f"✅ {test_name} PASSED")
            else:
                logger.error(f"❌ {test_name} FAILED")
        
        logger.info(f"\n📊 Test Results: {passed}/{total} tests passed")
        
        if passed == total:
            logger.info("🎉 All tests passed! Recommender system is working correctly.")
            return True
        else:
            logger.error(f"❌ {total - passed} test(s) failed. Please check the setup.")
            return False

def main():
    """Main function to run tests"""
    print("🧪 PostgreSQL Recommender System Test Suite")
    print("=" * 50)
    
    tester = PostgreSQLRecommenderTest()
    
    try:
        success = tester.run_complete_test()
        if success:
            print("\n🎉 All tests passed! Your recommender system is ready.")
            print("\n📋 Next steps:")
            print("1. Connect to database: psql -d ecommerce_analytics -U postgres")
            print("2. Query recommendations: SELECT * FROM analytics.enhanced_recommendations LIMIT 10;")
            print("3. Check performance: SELECT * FROM analytics.user_recommendation_summary;")
            print("4. Run the setup script again to regenerate data: python setup_postgres_recommender_complete.py")
        else:
            print("\n❌ Some tests failed. Please check the logs above.")
            print("\n💡 Troubleshooting:")
            print("1. Make sure PostgreSQL is running")
            print("2. Check database credentials")
            print("3. Run the setup script: python setup_postgres_recommender_complete.py")
            
    except KeyboardInterrupt:
        print("\n⚠️ Tests interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")

if __name__ == "__main__":
    main() 