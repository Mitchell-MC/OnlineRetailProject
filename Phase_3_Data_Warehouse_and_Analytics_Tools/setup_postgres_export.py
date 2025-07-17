#!/usr/bin/env python3
"""
PostgreSQL Setup Verification Script for Phase 3 Analytics
Tests all connections and validates the PostgreSQL analytics setup
"""

import os
import sys
import psycopg2
import snowflake.connector
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

def test_snowflake_connection():
    """Test Snowflake connection"""
    try:
        config = {
            'account': os.getenv('SNOWFLAKE_ACCOUNT'),
            'user': os.getenv('SNOWFLAKE_USER'),
            'password': os.getenv('SNOWFLAKE_PASSWORD'),
            'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'ECOMMERCE_WH'),
            'database': os.getenv('SNOWFLAKE_DATABASE', 'ECOMMERCE_DB'),
            'schema': os.getenv('SNOWFLAKE_SCHEMA', 'ANALYTICS')
        }
        
        conn = snowflake.connector.connect(**config)
        cursor = conn.cursor()
        cursor.execute("SELECT CURRENT_TIMESTAMP()")
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        
        print("✓ Snowflake connection successful")
        return True
    except Exception as e:
        print(f"✗ Snowflake connection failed: {e}")
        return False

def test_postgres_connection():
    """Test PostgreSQL connection"""
    try:
        config = {
            'host': os.getenv('POSTGRES_HOST', 'localhost'),
            'database': os.getenv('POSTGRES_DATABASE', 'ecommerce_analytics'),
            'user': os.getenv('POSTGRES_USER', 'postgres'),
            'password': os.getenv('POSTGRES_PASSWORD'),
            'port': int(os.getenv('POSTGRES_PORT', '5432'))
        }
        
        conn = psycopg2.connect(**config)
        cursor = conn.cursor()
        cursor.execute("SELECT NOW()")
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        
        print("✓ PostgreSQL connection successful")
        return True
    except Exception as e:
        print(f"✗ PostgreSQL connection failed: {e}")
        return False

def test_postgres_schema():
    """Test PostgreSQL schema exists"""
    try:
        config = {
            'host': os.getenv('POSTGRES_HOST', 'localhost'),
            'database': os.getenv('POSTGRES_DATABASE', 'ecommerce_analytics'),
            'user': os.getenv('POSTGRES_USER', 'postgres'),
            'password': os.getenv('POSTGRES_PASSWORD'),
            'port': int(os.getenv('POSTGRES_PORT', '5432'))
        }
        
        conn = psycopg2.connect(**config)
        cursor = conn.cursor()
        
        # Check if analytics schema exists
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name = 'analytics'
        """)
        
        if cursor.fetchone():
            print("✓ Analytics schema exists")
            
            # Check tables
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'analytics'
                ORDER BY table_name
            """)
            
            tables = cursor.fetchall()
            table_count = len(tables)
            
            print(f"✓ Found {table_count} tables in analytics schema:")
            for table in tables:
                print(f"  - {table[0]}")
            
            cursor.close()
            conn.close()
            return True
        else:
            print("✗ Analytics schema not found")
            cursor.close()
            conn.close()
            return False
            
    except Exception as e:
        print(f"✗ PostgreSQL schema check failed: {e}")
        return False

def test_snowflake_data():
    """Test if Snowflake has data to export"""
    try:
        config = {
            'account': os.getenv('SNOWFLAKE_ACCOUNT'),
            'user': os.getenv('SNOWFLAKE_USER'),
            'password': os.getenv('SNOWFLAKE_PASSWORD'),
            'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'ECOMMERCE_WH'),
            'database': os.getenv('SNOWFLAKE_DATABASE', 'ECOMMERCE_DB'),
            'schema': os.getenv('SNOWFLAKE_SCHEMA', 'ANALYTICS')
        }
        
        conn = snowflake.connector.connect(**config)
        cursor = conn.cursor()
        
        # Check key tables
        tables = [
            'CUSTOMER_360_PROFILE',
            'USER_SEGMENTS', 
            'USER_PRODUCT_RECOMMENDATIONS',
            'STG_EVENTS_CART',
            'STG_EVENTS_PURCHASE',
            'STG_EVENTS_VIEW'
        ]
        
        data_found = False
        for table in tables:
            try:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                if count > 0:
                    print(f"✓ {table}: {count} rows")
                    data_found = True
                else:
                    print(f"⚠ {table}: No data")
            except Exception as e:
                print(f"⚠ {table}: Table not found or error - {e}")
        
        cursor.close()
        conn.close()
        
        if data_found:
            print("✓ Snowflake data available for export")
        else:
            print("⚠ No data found in Snowflake tables")
        
        return data_found
        
    except Exception as e:
        print(f"✗ Snowflake data check failed: {e}")
        return False

def verify_environment_variables():
    """Verify required environment variables are set"""
    required_vars = [
        'SNOWFLAKE_ACCOUNT',
        'SNOWFLAKE_USER',
        'SNOWFLAKE_PASSWORD',
        'POSTGRES_PASSWORD'
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print("✗ Missing required environment variables:")
        for var in missing_vars:
            print(f"  - {var}")
        return False
    else:
        print("✓ All required environment variables are set")
        return True

def main():
    """Main verification function"""
    print("Verifying PostgreSQL Analytics Setup...")
    print("=" * 50)
    
    all_tests_passed = True
    
    # Test environment variables
    all_tests_passed &= verify_environment_variables()
    
    # Test connections
    all_tests_passed &= test_postgres_connection()
    all_tests_passed &= test_postgres_schema()
    all_tests_passed &= test_snowflake_connection()
    all_tests_passed &= test_snowflake_data()
    
    print("=" * 50)
    if all_tests_passed:
        print("✓ All tests passed - PostgreSQL setup is ready!")
        print("\nNext steps:")
        print("1. Run the export: python export_to_postgres_enhanced.py")
        print("2. Enable automatic exports: sudo systemctl enable postgres-export.timer")
        print("3. Start automatic exports: sudo systemctl start postgres-export.timer")
        sys.exit(0)
    else:
        print("✗ Some tests failed - Please check configuration")
        print("\nCommon solutions:")
        print("1. Update .env file with correct credentials")
        print("2. Ensure PostgreSQL service is running: sudo systemctl status postgresql")
        print("3. Check Snowflake warehouse is active")
        sys.exit(1)

if __name__ == "__main__":
    main() 