#!/usr/bin/env python3
"""
Script to execute the final warehouse build SQL file
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

def read_sql_file(file_path):
    """Read the SQL file and return its contents"""
    try:
        with open(file_path, 'r') as file:
            return file.read()
    except Exception as e:
        print(f"❌ Error reading SQL file: {e}")
        return None

def execute_sql_statements(conn, sql_content):
    """Execute SQL statements from the file"""
    cursor = conn.cursor()
    
    # Split SQL into individual statements
    statements = sql_content.split(';')
    
    print("🚀 Starting Final Data Warehouse Build...")
    print("=" * 60)
    
    for i, statement in enumerate(statements, 1):
        statement = statement.strip()
        if not statement or statement.startswith('--'):
            continue
            
        try:
            print(f"📝 Executing statement {i}...")
            cursor.execute(statement)
            
            # If it's a SELECT statement, show results
            if statement.strip().upper().startswith('SELECT'):
                results = cursor.fetchall()
                if results:
                    print(f"✅ Query returned {len(results)} rows")
                    for row in results[:3]:  # Show first 3 rows
                        print(f"   {row}")
                    if len(results) > 3:
                        print(f"   ... and {len(results) - 3} more rows")
                else:
                    print("✅ Query executed successfully (no results)")
            else:
                print("✅ Statement executed successfully")
                
        except Exception as e:
            print(f"❌ Error executing statement {i}: {e}")
            print(f"Statement: {statement[:100]}...")
            # Continue with next statement instead of failing completely
            continue
    
    print("=" * 60)
    print("🎉 Final Data Warehouse Build Complete!")
    
    # Show final verification
    try:
        print("\n📊 Final Verification:")
        cursor.execute("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'ANALYTICS'")
        table_count = cursor.fetchone()[0]
        print(f"   Tables created: {table_count}")
        
        cursor.execute("SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'ANALYTICS'")
        view_count = cursor.fetchone()[0]
        print(f"   Views created: {view_count}")
        
        # Check key tables
        key_tables = ['STG_EVENTS_COMBINED', 'CUSTOMER_360_PROFILE', 'USER_PRODUCT_RECOMMENDATIONS', 'DAILY_METRICS', 'PRODUCT_CATALOG', 'USER_SEGMENTS']
        for table in key_tables:
            try:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                print(f"   {table}: {count:,} rows")
            except:
                print(f"   {table}: Not found or error")
                
    except Exception as e:
        print(f"❌ Error during verification: {e}")

def main():
    """Main function to execute the final warehouse build"""
    print("🔍 Final Data Warehouse Build")
    print("=" * 50)
    
    # Read the SQL file
    sql_file_path = "build_warehouse_final.sql"
    sql_content = read_sql_file(sql_file_path)
    
    if not sql_content:
        print("❌ Could not read SQL file")
        return
    
    # Connect to Snowflake
    conn = connect_to_snowflake()
    if not conn:
        return
    
    try:
        # Execute the SQL statements
        execute_sql_statements(conn, sql_content)
        
    except Exception as e:
        print(f"❌ Error during execution: {e}")
    
    finally:
        conn.close()
        print("🔌 Connection closed")

if __name__ == "__main__":
    main() 