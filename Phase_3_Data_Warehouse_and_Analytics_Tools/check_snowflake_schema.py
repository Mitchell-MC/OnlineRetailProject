#!/usr/bin/env python3
"""
Check Snowflake Schema Script

This script checks the actual column names and structure of tables in Snowflake.
"""

import os
import snowflake.connector
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Snowflake credentials
SNOWFLAKE_USER = os.getenv("SNOWFLAKE_USER")
SNOWFLAKE_PASSWORD = os.getenv("SNOWFLAKE_PASSWORD")
SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")

def check_table_schema(table_name):
    """Check the schema of a specific table."""
    try:
        with snowflake.connector.connect(
            user=SNOWFLAKE_USER,
            password=SNOWFLAKE_PASSWORD,
            account=SNOWFLAKE_ACCOUNT,
            warehouse="COMPUTE_WH",
            database="ECOMMERCE_DB",
            schema="ANALYTICS"
        ) as conn:
            cursor = conn.cursor()
            
            # Get table schema
            cursor.execute(f"DESCRIBE TABLE {table_name}")
            columns = cursor.fetchall()
            
            logger.info(f"📋 Schema for table {table_name}:")
            for col in columns:
                logger.info(f"   {col[0]} - {col[1]} - {col[2]}")
            
            # Get sample data
            cursor.execute(f"SELECT * FROM {table_name} LIMIT 1")
            sample = cursor.fetchone()
            if sample:
                logger.info(f"✅ Sample data from {table_name}: {sample}")
            else:
                logger.info(f"⚠️  No data found in {table_name}")
                
    except Exception as e:
        logger.error(f"❌ Error checking schema for {table_name}: {e}")

def main():
    """Check schemas for both tables."""
    logger.info("🔍 Checking Snowflake table schemas")
    logger.info("=" * 50)
    
    # Check USER_SEGMENTS table
    check_table_schema("USER_SEGMENTS")
    
    logger.info("")
    
    # Check USER_PRODUCT_RECOMMENDATIONS table
    check_table_schema("USER_PRODUCT_RECOMMENDATIONS")
    
    logger.info("🎉 Schema check complete!")

if __name__ == "__main__":
    main() 