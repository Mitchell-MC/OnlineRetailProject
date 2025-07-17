#!/usr/bin/env python3
"""
Script to check where data currently resides and what data exists
"""

import snowflake.connector
import os

# Snowflake connection details
SNOWFLAKE_CONFIG = {
    "user": "MITCHELLMCC",
    "password": "jme9EPKxPwm8ewX",
    "account": "KLRPPBG-NEC57960",
    "warehouse": "COMPUTE_WH",
    "database": "ECOMMERCE_DB",
    "schema": "ANALYTICS"
}

def connect_to_snowflake():
    """Connect to Snowflake and return connection object"""
    try:
        conn = snowflake.connector.connect(
            user=SNOWFLAKE_CONFIG["user"],
            password=SNOWFLAKE_CONFIG["password"],
            account=SNOWFLAKE_CONFIG["account"],
            warehouse=SNOWFLAKE_CONFIG["warehouse"],
            database=SNOWFLAKE_CONFIG["database"],
            schema=SNOWFLAKE_CONFIG["schema"]
        )
        print("✅ Successfully connected to Snowflake!")
        return conn
    except Exception as e:
        print(f"❌ Error connecting to Snowflake: {e}")
        return None

def check_table_data(conn, table_name):
    """Check data in a specific table"""
    cursor = conn.cursor()
    
    try:
        # Get row count
        cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
        row_count = cursor.fetchone()[0]
        
        print(f"\n📊 {table_name}: {row_count:,} rows")
        
        # Get sample data if table has data
        if row_count > 0:
            cursor.execute(f"SELECT * FROM {table_name} LIMIT 3")
            sample_data = cursor.fetchall()
            print(f"📝 Sample data:")
            for i, row in enumerate(sample_data, 1):
                print(f"  Row {i}: {row}")
        else:
            print("  ⚠️  Table is empty")
            
    except Exception as e:
        print(f"❌ Error checking {table_name}: {e}")

def check_s3_data():
    """Check if there's data in S3"""
    import boto3
    
    print("\n🔍 Checking S3 for data...")
    
    try:
        s3_client = boto3.client('s3')
        
        # Check the S3 bucket mentioned in your DAG
        bucket_name = "kafka-cust-transactions"
        
        # Check for cart events
        cart_prefix = "raw/user_events/event_type=cart/"
        cart_response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=cart_prefix)
        cart_files = len(cart_response.get('Contents', []))
        
        # Check for purchase events
        purchase_prefix = "raw/user_events/event_type=purchase/"
        purchase_response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=purchase_prefix)
        purchase_files = len(purchase_response.get('Contents', []))
        
        # Check for view events
        view_prefix = "raw/user_events/event_type=view/"
        view_response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=view_prefix)
        view_files = len(view_response.get('Contents', []))
        
        print(f"📦 S3 Bucket: {bucket_name}")
        print(f"  - Cart files: {cart_files}")
        print(f"  - Purchase files: {purchase_files}")
        print(f"  - View files: {view_files}")
        
        total_files = cart_files + purchase_files + view_files
        if total_files > 0:
            print(f"✅ Found {total_files} files in S3")
        else:
            print("⚠️  No data files found in S3")
            
    except Exception as e:
        print(f"❌ Error checking S3: {e}")

def check_airflow_dag_status():
    """Check if Airflow DAG has been running"""
    print("\n🔄 Checking Airflow DAG status...")
    
    # Check if the DAG file exists and has been modified recently
    dag_file = "airflow-project/dags/ecommerce_daily_sdk.py"
    
    if os.path.exists(dag_file):
        import time
        mod_time = os.path.getmtime(dag_file)
        mod_date = time.ctime(mod_time)
        print(f"📋 DAG file exists, last modified: {mod_date}")
        
        # Check if there are any log files
        log_dir = "airflow-project/logs"
        if os.path.exists(log_dir):
            log_files = [f for f in os.listdir(log_dir) if f.endswith('.log')]
            print(f"📝 Found {len(log_files)} log files")
        else:
            print("⚠️  No logs directory found")
    else:
        print("❌ DAG file not found")

def main():
    """Main function to check data locations"""
    print("🔍 Data Location Check")
    print("=" * 50)
    
    # Check S3 data
    check_s3_data()
    
    # Check Airflow DAG status
    check_airflow_dag_status()
    
    # Connect to Snowflake and check table data
    conn = connect_to_snowflake()
    if not conn:
        return
    
    try:
        print("\n❄️  Checking Snowflake tables...")
        
        # Check each table
        tables = [
            "STG_EVENTS_CART",
            "STG_EVENTS_PURCHASE", 
            "STG_EVENTS_VIEW",
            "CUSTOMER_360_PROFILE"
        ]
        
        for table in tables:
            check_table_data(conn, table)
        
        print("\n" + "="*60)
        print("📋 DATA LOCATION SUMMARY")
        print("="*60)
        print("Your data is currently in:")
        print("1. ❄️  Snowflake tables (if populated)")
        print("2. ☁️  S3 bucket: kafka-cust-transactions")
        print("3. 🔄 Generated by Airflow DAG: ecommerce_daily_sdk")
        print("="*60)
        
    except Exception as e:
        print(f"❌ Error during data check: {e}")
    
    finally:
        conn.close()
        print("🔌 Connection closed")

if __name__ == "__main__":
    main() 