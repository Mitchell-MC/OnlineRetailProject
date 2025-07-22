#!/usr/bin/env python3
"""
Simple test script to check Snowflake connection and table structure
"""

import os
import snowflake.connector
import pandas as pd

def test_snowflake_connection():
    """Test direct Snowflake connection"""
    
    try:
        # Get connection details from environment variables
        # You can set these in your environment or modify the values below
        user = os.getenv('SNOWFLAKE_USER', 'your_username')
        password = os.getenv('SNOWFLAKE_PASSWORD', 'your_password')
        account = os.getenv('SNOWFLAKE_ACCOUNT', 'your_account')
        warehouse = os.getenv('SNOWFLAKE_WAREHOUSE', 'your_warehouse')
        database = os.getenv('SNOWFLAKE_DATABASE', 'your_database')
        schema = os.getenv('SNOWFLAKE_SCHEMA', 'ANALYTICS')
        
        print(f"🔗 Attempting to connect to Snowflake...")
        print(f"   Account: {account}")
        print(f"   Database: {database}")
        print(f"   Schema: {schema}")
        
        # Connect to Snowflake
        sf_conn = snowflake.connector.connect(
            user=user,
            password=password,
            account=account,
            warehouse=warehouse,
            database=database,
            schema=schema
        )
        
        cursor = sf_conn.cursor()
        print(f"✅ Successfully connected to Snowflake!")
        
        # Test basic query
        cursor.execute("SELECT CURRENT_VERSION()")
        version = cursor.fetchone()[0]
        print(f"📊 Snowflake version: {version}")
        
        # Check if ANALYTICS schema exists
        cursor.execute("SHOW SCHEMAS LIKE 'ANALYTICS'")
        schemas = cursor.fetchall()
        
        if schemas:
            print(f"✅ ANALYTICS schema exists")
        else:
            print(f"❌ ANALYTICS schema does not exist")
            print(f"📝 Creating ANALYTICS schema...")
            cursor.execute("CREATE SCHEMA IF NOT EXISTS ANALYTICS")
            print(f"✅ Created ANALYTICS schema")
        
        # Check existing tables
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
        print(f"\n💡 To fix this, please:")
        print(f"   1. Set your Snowflake credentials as environment variables:")
        print(f"      export SNOWFLAKE_USER=your_username")
        print(f"      export SNOWFLAKE_PASSWORD=your_password")
        print(f"      export SNOWFLAKE_ACCOUNT=your_account")
        print(f"      export SNOWFLAKE_WAREHOUSE=your_warehouse")
        print(f"      export SNOWFLAKE_DATABASE=your_database")
        print(f"   2. Or modify the default values in this script")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_snowflake_connection() 