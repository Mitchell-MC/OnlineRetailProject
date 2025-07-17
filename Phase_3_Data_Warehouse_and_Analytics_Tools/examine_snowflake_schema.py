#!/usr/bin/env python3
"""
Script to examine Snowflake schema and current data structures
"""

import snowflake.connector
import os
import json
from typing import Dict, List, Any

# Snowflake connection details from your configuration
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

def examine_database_structure(conn):
    """Examine the current database structure"""
    cursor = conn.cursor()
    
    print("\n" + "="*60)
    print("🔍 EXAMINING SNOWFLAKE DATABASE STRUCTURE")
    print("="*60)
    
    # Check current database and schema
    cursor.execute("SELECT CURRENT_DATABASE(), CURRENT_SCHEMA()")
    current_db, current_schema = cursor.fetchone()
    print(f"📍 Current Database: {current_db}")
    print(f"📍 Current Schema: {current_schema}")
    
    # List all schemas in the database
    print("\n📚 Available Schemas:")
    cursor.execute("SHOW SCHEMAS IN ECOMMERCE_DB")
    schemas = cursor.fetchall()
    for schema in schemas:
        print(f"  - {schema[1]} (Owner: {schema[2]})")
    
    # List all tables in current schema
    print(f"\n📋 Tables in {current_schema} schema:")
    cursor.execute("SHOW TABLES")
    tables = cursor.fetchall()
    
    if not tables:
        print("  ⚠️  No tables found in current schema")
    else:
        for table in tables:
            print(f"  - {table[1]} (Type: {table[2]})")
    
    # List all views in current schema
    print(f"\n👁️  Views in {current_schema} schema:")
    cursor.execute("SHOW VIEWS")
    views = cursor.fetchall()
    
    if not views:
        print("  ⚠️  No views found in current schema")
    else:
        for view in views:
            print(f"  - {view[1]}")
    
    return tables, views

def examine_table_structure(conn, table_name):
    """Examine the structure of a specific table"""
    cursor = conn.cursor()
    
    print(f"\n🔍 Table Structure: {table_name}")
    print("-" * 40)
    
    try:
        # Get table description
        cursor.execute(f"DESCRIBE TABLE {table_name}")
        columns = cursor.fetchall()
        
        print("Columns:")
        for col in columns:
            col_name, data_type, nullable, default, primary_key, unique_key, check, expression, comment, policy_name = col
            print(f"  - {col_name}: {data_type} ({'NULL' if nullable == 'Y' else 'NOT NULL'})")
        
        # Get row count
        cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
        row_count = cursor.fetchone()[0]
        print(f"\n📊 Row count: {row_count:,}")
        
        # Get sample data
        if row_count > 0:
            cursor.execute(f"SELECT * FROM {table_name} LIMIT 5")
            sample_data = cursor.fetchall()
            print(f"\n📝 Sample data (first 5 rows):")
            for i, row in enumerate(sample_data, 1):
                print(f"  Row {i}: {row}")
        
    except Exception as e:
        print(f"❌ Error examining table {table_name}: {e}")

def check_warehouse_status(conn):
    """Check warehouse status and configuration"""
    cursor = conn.cursor()
    
    print("\n🏭 Warehouse Status:")
    print("-" * 30)
    
    cursor.execute("SHOW WAREHOUSES")
    warehouses = cursor.fetchall()
    
    for wh in warehouses:
        # Handle variable number of columns in warehouse status
        if len(wh) >= 3:
            name = wh[1] if len(wh) > 1 else "Unknown"
            state = wh[2] if len(wh) > 2 else "Unknown"
            size = wh[3] if len(wh) > 3 else "Unknown"
            running = wh[4] if len(wh) > 4 else "Unknown"
            print(f"  - {name}: {state} (Size: {size}, Running: {running})")
        else:
            print(f"  - Warehouse info: {wh}")

def main():
    """Main function to examine Snowflake schema"""
    print("🔍 Snowflake Schema Examination Tool")
    print("=" * 50)
    
    # Connect to Snowflake
    conn = connect_to_snowflake()
    if not conn:
        return
    
    try:
        # Check warehouse status
        check_warehouse_status(conn)
        
        # Examine database structure
        tables, views = examine_database_structure(conn)
        
        # Examine each table in detail
        cursor = conn.cursor()
        cursor.execute("SHOW TABLES")
        all_tables = cursor.fetchall()
        
        for table in all_tables:
            table_name = table[1]
            examine_table_structure(conn, table_name)
        
        # Examine each view in detail
        cursor.execute("SHOW VIEWS")
        all_views = cursor.fetchall()
        
        for view in all_views:
            view_name = view[1]
            print(f"\n👁️  View: {view_name}")
            print("-" * 30)
            try:
                cursor.execute(f"SELECT * FROM {view_name} LIMIT 3")
                sample_data = cursor.fetchall()
                print(f"Sample data from view:")
                for i, row in enumerate(sample_data, 1):
                    print(f"  Row {i}: {row}")
            except Exception as e:
                print(f"❌ Error examining view {view_name}: {e}")
        
        print("\n" + "="*60)
        print("✅ Schema examination complete!")
        print("="*60)
        
    except Exception as e:
        print(f"❌ Error during examination: {e}")
    
    finally:
        conn.close()
        print("🔌 Connection closed")

if __name__ == "__main__":
    main() 