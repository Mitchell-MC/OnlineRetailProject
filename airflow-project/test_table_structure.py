#!/usr/bin/env python3
"""
Test script to check table structure and identify column mismatch issues
"""

import snowflake.connector
from airflow.hooks.base import BaseHook
import pandas as pd

def test_table_structure():
    """Test the structure of staging tables"""
    
    try:
        # Get Snowflake connection details from Airflow
        conn = BaseHook.get_connection("snowflake_default")
        
        # Connect to Snowflake
        sf_conn = snowflake.connector.connect(
            user=conn.login,
            password=conn.password,
            account=conn.extra_dejson.get('account'),
            warehouse=conn.extra_dejson.get('warehouse'),
            database=conn.extra_dejson.get('database'),
            schema=conn.extra_dejson.get('schema', 'ANALYTICS')
        )
        
        cursor = sf_conn.cursor()
        
        # Check if tables exist and their structure
        tables_to_check = [
            'STG_EVENTS_CART',
            'STG_EVENTS_PURCHASE', 
            'STG_EVENTS_VIEW',
            'STG_EVENTS_COMBINED',
            'CUSTOMER_360_PROFILE'
        ]
        
        for table_name in tables_to_check:
            print(f"\n🔍 Checking table: {table_name}")
            
            # Check if table exists
            cursor.execute(f"SHOW TABLES LIKE '{table_name}' IN SCHEMA ANALYTICS")
            result = cursor.fetchall()
            
            if result:
                print(f"✅ Table {table_name} exists")
                
                # Get table structure
                cursor.execute(f"DESCRIBE TABLE ANALYTICS.{table_name}")
                columns = cursor.fetchall()
                
                print(f"📋 Columns in {table_name}:")
                for col in columns:
                    print(f"  - {col[0]}: {col[1]}")
                    
                # Check row count
                cursor.execute(f"SELECT COUNT(*) FROM ANALYTICS.{table_name}")
                count = cursor.fetchone()[0]
                print(f"📊 Row count: {count}")
                
            else:
                print(f"❌ Table {table_name} does not exist")
        
        # Test creating a simple table with correct structure
        print(f"\n🧪 Testing table creation...")
        
        test_table_name = "TEST_TABLE_STRUCTURE"
        
        # Drop if exists
        cursor.execute(f"DROP TABLE IF EXISTS ANALYTICS.{test_table_name}")
        
        # Create table with correct structure
        create_sql = f"""
        CREATE TABLE ANALYTICS.{test_table_name} (
            user_id STRING,
            event_time TIMESTAMP,
            event_type STRING,
            product_id STRING,
            price DECIMAL(10,2),
            brand STRING,
            category_code STRING
        )
        """
        cursor.execute(create_sql)
        print(f"✅ Created test table: {test_table_name}")
        
        # Test insert with correct number of columns
        test_data = {
            'user_id': 'test_user',
            'event_time': '2025-01-01 10:00:00',
            'event_type': 'test',
            'product_id': 'test_prod',
            'price': 100.00,
            'brand': 'test_brand',
            'category_code': 'test_category'
        }
        
        insert_sql = f"""
        INSERT INTO ANALYTICS.{test_table_name} 
        (user_id, event_time, event_type, product_id, price, brand, category_code) 
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        
        cursor.execute(insert_sql, (
            test_data['user_id'],
            test_data['event_time'],
            test_data['event_type'],
            test_data['product_id'],
            test_data['price'],
            test_data['brand'],
            test_data['category_code']
        ))
        
        print(f"✅ Successfully inserted test data")
        
        # Clean up
        cursor.execute(f"DROP TABLE ANALYTICS.{test_table_name}")
        print(f"🧹 Cleaned up test table")
        
        sf_conn.commit()
        sf_conn.close()
        
        print(f"\n✅ All tests completed successfully!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_table_structure() 