#!/usr/bin/env python3
"""
Enhanced PostgreSQL Export Script for Phase 3 Analytics
Exports complete analytics data from Snowflake to PostgreSQL database
"""

import psycopg2
import psycopg2.extras
import snowflake.connector
import os
import sys
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/ecommerce-app/postgres_export.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class PostgreSQLExporter:
    def __init__(self):
        self.snowflake_config = {
            'account': os.getenv('SNOWFLAKE_ACCOUNT'),
            'user': os.getenv('SNOWFLAKE_USER'),
            'password': os.getenv('SNOWFLAKE_PASSWORD'),
            'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'ECOMMERCE_WH'),
            'database': os.getenv('SNOWFLAKE_DATABASE', 'ECOMMERCE_DB'),
            'schema': os.getenv('SNOWFLAKE_SCHEMA', 'ANALYTICS')
        }
        
        self.postgres_config = {
            'host': os.getenv('POSTGRES_HOST', 'localhost'),
            'database': os.getenv('POSTGRES_DATABASE', 'ecommerce_analytics'),
            'user': os.getenv('POSTGRES_USER', 'postgres'),
            'password': os.getenv('POSTGRES_PASSWORD'),
            'port': int(os.getenv('POSTGRES_PORT', '5432'))
        }

    def connect_snowflake(self):
        """Establish connection to Snowflake"""
        try:
            conn = snowflake.connector.connect(**self.snowflake_config)
            logger.info("Successfully connected to Snowflake")
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {e}")
            raise

    def connect_postgres(self):
        """Establish connection to PostgreSQL"""
        try:
            conn = psycopg2.connect(**self.postgres_config)
            conn.autocommit = True
            logger.info("Successfully connected to PostgreSQL")
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to PostgreSQL: {e}")
            raise

    def export_staging_events(self, sf_conn, pg_conn):
        """Export staging events from Snowflake to PostgreSQL"""
        sf_cursor = sf_conn.cursor()
        pg_cursor = pg_conn.cursor()
        
        tables = ['STG_EVENTS_CART', 'STG_EVENTS_PURCHASE', 'STG_EVENTS_VIEW']
        total_exported = 0
        
        for table in tables:
            logger.info(f"Exporting {table}...")
            
            # Clear existing data
            pg_table = table.lower()
            pg_cursor.execute(f"TRUNCATE TABLE analytics.{pg_table}")
            
            # Fetch data from Snowflake
            sf_cursor.execute(f"""
                SELECT USER_ID, EVENT_TIME, EVENT_TYPE, PRODUCT_ID, PRICE, BRAND, CATEGORY_CODE
                FROM {table}
            """)
            
            rows = sf_cursor.fetchall()
            
            if rows:
                # Prepare insert statement
                insert_sql = f"""
                    INSERT INTO analytics.{pg_table} 
                    (user_id, event_time, event_type, product_id, price, brand, category_code)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """
                
                # Batch insert
                psycopg2.extras.execute_batch(pg_cursor, insert_sql, rows, page_size=1000)
                logger.info(f"Exported {len(rows)} rows to {pg_table}")
                total_exported += len(rows)
            else:
                logger.warning(f"No data found in {table}")
        
        return total_exported

    def export_customer_360_profile(self, sf_conn, pg_conn):
        """Export customer 360 profile data"""
        sf_cursor = sf_conn.cursor()
        pg_cursor = pg_conn.cursor()
        
        logger.info("Exporting CUSTOMER_360_PROFILE...")
        
        # Clear existing data
        pg_cursor.execute("TRUNCATE TABLE analytics.customer_360_profile")
        
        # Fetch data from Snowflake
        sf_cursor.execute("""
            SELECT USER_ID, FAVORITE_BRAND, MOST_VIEWED_CATEGORY, 
                   TOTAL_PURCHASES, TOTAL_SPEND, LAST_SEEN_DATE
            FROM CUSTOMER_360_PROFILE
        """)
        
        rows = sf_cursor.fetchall()
        
        if rows:
            insert_sql = """
                INSERT INTO analytics.customer_360_profile 
                (user_id, favorite_brand, most_viewed_category, total_purchases, total_spend, last_seen_date)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            
            psycopg2.extras.execute_batch(pg_cursor, insert_sql, rows, page_size=1000)
            logger.info(f"Exported {len(rows)} customer profiles")
            return len(rows)
        else:
            logger.warning("No customer profile data found")
            return 0

    def export_user_segments(self, sf_conn, pg_conn):
        """Export user segments data"""
        sf_cursor = sf_conn.cursor()
        pg_cursor = pg_conn.cursor()
        
        logger.info("Exporting USER_SEGMENTS...")
        
        # Clear existing data
        pg_cursor.execute("TRUNCATE TABLE analytics.user_segments")
        
        # Fetch data from Snowflake
        sf_cursor.execute("""
            SELECT USER_ID, SEGMENT, TOTAL_PURCHASES, TOTAL_SPEND, 
                   LAST_PURCHASE_DATE, DAYS_SINCE_LAST_PURCHASE
            FROM USER_SEGMENTS
        """)
        
        rows = sf_cursor.fetchall()
        
        if rows:
            insert_sql = """
                INSERT INTO analytics.user_segments 
                (user_id, segment, total_purchases, total_spend, last_purchase_date, days_since_last_purchase)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            
            psycopg2.extras.execute_batch(pg_cursor, insert_sql, rows, page_size=1000)
            logger.info(f"Exported {len(rows)} user segments")
            return len(rows)
        else:
            logger.warning("No user segments data found")
            return 0

    def export_product_recommendations(self, sf_conn, pg_conn):
        """Export product recommendations data"""
        sf_cursor = sf_conn.cursor()
        pg_cursor = pg_conn.cursor()
        
        logger.info("Exporting USER_PRODUCT_RECOMMENDATIONS...")
        
        # Clear existing data
        pg_cursor.execute("TRUNCATE TABLE analytics.user_product_recommendations")
        
        # Fetch data from Snowflake
        sf_cursor.execute("""
            SELECT USER_ID, PRODUCT_ID, RECOMMENDATION_SCORE, RANK
            FROM USER_PRODUCT_RECOMMENDATIONS
        """)
        
        rows = sf_cursor.fetchall()
        
        if rows:
            insert_sql = """
                INSERT INTO analytics.user_product_recommendations 
                (user_id, product_id, recommendation_score, rank)
                VALUES (%s, %s, %s, %s)
            """
            
            psycopg2.extras.execute_batch(pg_cursor, insert_sql, rows, page_size=1000)
            logger.info(f"Exported {len(rows)} product recommendations")
            return len(rows)
        else:
            logger.warning("No product recommendations data found")
            return 0

    def build_analytics_tables(self, pg_conn):
        """Build derived analytics tables from staging data"""
        pg_cursor = pg_conn.cursor()
        
        logger.info("Building analytics tables from staging data...")
        
        # Build product analytics
        logger.info("Building product analytics...")
        pg_cursor.execute("""
            INSERT INTO analytics.product_analytics 
            (product_id, brand, category_code, total_views, total_cart_adds, total_purchases, 
             total_revenue, unique_viewers, avg_price)
            SELECT 
                p.product_id,
                p.brand,
                p.category_code,
                COALESCE(v.view_count, 0) as total_views,
                COALESCE(c.cart_count, 0) as total_cart_adds,
                COALESCE(pu.purchase_count, 0) as total_purchases,
                COALESCE(pu.total_revenue, 0) as total_revenue,
                COALESCE(v.unique_viewers, 0) as unique_viewers,
                COALESCE(pu.avg_price, 0) as avg_price
            FROM (
                SELECT DISTINCT product_id, brand, category_code 
                FROM (
                    SELECT product_id, brand, category_code FROM analytics.stg_events_view
                    UNION 
                    SELECT product_id, brand, category_code FROM analytics.stg_events_cart
                    UNION 
                    SELECT product_id, brand, category_code FROM analytics.stg_events_purchase
                ) all_products
                WHERE product_id IS NOT NULL
            ) p
            LEFT JOIN (
                SELECT product_id, COUNT(*) as view_count, COUNT(DISTINCT user_id) as unique_viewers
                FROM analytics.stg_events_view 
                WHERE product_id IS NOT NULL
                GROUP BY product_id
            ) v ON p.product_id = v.product_id
            LEFT JOIN (
                SELECT product_id, COUNT(*) as cart_count
                FROM analytics.stg_events_cart 
                WHERE product_id IS NOT NULL
                GROUP BY product_id
            ) c ON p.product_id = c.product_id
            LEFT JOIN (
                SELECT product_id, COUNT(*) as purchase_count, 
                       SUM(price) as total_revenue, AVG(price) as avg_price
                FROM analytics.stg_events_purchase 
                WHERE product_id IS NOT NULL
                GROUP BY product_id
            ) pu ON p.product_id = pu.product_id
            ON CONFLICT (product_id) DO UPDATE SET
                total_views = EXCLUDED.total_views,
                total_cart_adds = EXCLUDED.total_cart_adds,
                total_purchases = EXCLUDED.total_purchases,
                total_revenue = EXCLUDED.total_revenue,
                unique_viewers = EXCLUDED.unique_viewers,
                avg_price = EXCLUDED.avg_price,
                updated_at = CURRENT_TIMESTAMP
        """)
        
        # Update conversion rates
        pg_cursor.execute("""
            UPDATE analytics.product_analytics 
            SET conversion_rate = CASE 
                WHEN total_views > 0 THEN total_purchases::DECIMAL / total_views 
                ELSE 0 
            END
        """)
        
        # Build brand analytics
        logger.info("Building brand analytics...")
        pg_cursor.execute("""
            INSERT INTO analytics.brand_analytics 
            (brand, total_products, total_views, total_cart_adds, total_purchases, 
             total_revenue, unique_customers, avg_product_price)
            SELECT 
                brand,
                COUNT(DISTINCT product_id) as total_products,
                SUM(total_views) as total_views,
                SUM(total_cart_adds) as total_cart_adds,
                SUM(total_purchases) as total_purchases,
                SUM(total_revenue) as total_revenue,
                (SELECT COUNT(DISTINCT user_id) 
                 FROM analytics.stg_events_purchase p2 
                 WHERE p2.brand = p.brand) as unique_customers,
                AVG(avg_price) as avg_product_price
            FROM analytics.product_analytics p
            WHERE brand IS NOT NULL
            GROUP BY brand
            ON CONFLICT (brand) DO UPDATE SET
                total_products = EXCLUDED.total_products,
                total_views = EXCLUDED.total_views,
                total_cart_adds = EXCLUDED.total_cart_adds,
                total_purchases = EXCLUDED.total_purchases,
                total_revenue = EXCLUDED.total_revenue,
                unique_customers = EXCLUDED.unique_customers,
                avg_product_price = EXCLUDED.avg_product_price,
                updated_at = CURRENT_TIMESTAMP
        """)
        
        # Build category analytics
        logger.info("Building category analytics...")
        pg_cursor.execute("""
            INSERT INTO analytics.category_analytics 
            (category_code, total_products, total_views, total_cart_adds, total_purchases, 
             total_revenue, unique_customers, avg_product_price)
            SELECT 
                category_code,
                COUNT(DISTINCT product_id) as total_products,
                SUM(total_views) as total_views,
                SUM(total_cart_adds) as total_cart_adds,
                SUM(total_purchases) as total_purchases,
                SUM(total_revenue) as total_revenue,
                (SELECT COUNT(DISTINCT user_id) 
                 FROM analytics.stg_events_purchase p2 
                 WHERE p2.category_code = p.category_code) as unique_customers,
                AVG(avg_price) as avg_product_price
            FROM analytics.product_analytics p
            WHERE category_code IS NOT NULL
            GROUP BY category_code
            ON CONFLICT (category_code) DO UPDATE SET
                total_products = EXCLUDED.total_products,
                total_views = EXCLUDED.total_views,
                total_cart_adds = EXCLUDED.total_cart_adds,
                total_purchases = EXCLUDED.total_purchases,
                total_revenue = EXCLUDED.total_revenue,
                unique_customers = EXCLUDED.unique_customers,
                avg_product_price = EXCLUDED.avg_product_price,
                updated_at = CURRENT_TIMESTAMP
        """)
        
        logger.info("Analytics tables built successfully")

    def run_export(self):
        """Main export process"""
        logger.info("Starting PostgreSQL export process...")
        
        try:
            # Connect to both databases
            sf_conn = self.connect_snowflake()
            pg_conn = self.connect_postgres()
            
            # Export core data
            staging_count = self.export_staging_events(sf_conn, pg_conn)
            profile_count = self.export_customer_360_profile(sf_conn, pg_conn)
            segments_count = self.export_user_segments(sf_conn, pg_conn)
            recommendations_count = self.export_product_recommendations(sf_conn, pg_conn)
            
            # Build analytics tables
            self.build_analytics_tables(pg_conn)
            
            # Close connections
            sf_conn.close()
            pg_conn.close()
            
            logger.info("Export completed successfully!")
            logger.info(f"Staging events exported: {staging_count}")
            logger.info(f"Customer profiles exported: {profile_count}")
            logger.info(f"User segments exported: {segments_count}")
            logger.info(f"Product recommendations exported: {recommendations_count}")
            
            return {
                'success': True,
                'staging_events_count': staging_count,
                'customer_profiles_count': profile_count,
                'user_segments_count': segments_count,
                'recommendations_count': recommendations_count
            }
            
        except Exception as e:
            logger.error(f"Export failed: {e}")
            return {'success': False, 'error': str(e)}

def main():
    """Main function"""
    exporter = PostgreSQLExporter()
    result = exporter.run_export()
    
    if result['success']:
        print("PostgreSQL export completed successfully!")
        sys.exit(0)
    else:
        print(f"PostgreSQL export failed: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main() 