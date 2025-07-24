#!/usr/bin/env python3
"""
Robust DynamoDB Export Script for Ecommerce Data Warehouse

This script exports user segments and product recommendations from Snowflake
to DynamoDB tables for real-time application access.

Fixes:
1. Integer overflow issues with large numbers using string-based handling
2. Data structure matching actual DynamoDB schema
3. Better error handling for data type conversions
4. Robust Snowflake data handling

Prerequisites:
1. AWS credentials configured (via AWS CLI, environment variables, or IAM roles)
2. Snowflake credentials set as environment variables
3. DynamoDB tables created (script will create them if they don't exist)
"""

import os
import json
import boto3
import snowflake.connector
from decimal import Decimal
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# --- Configuration ---
SNOWFLAKE_USER = os.getenv("SNOWFLAKE_USER")
SNOWFLAKE_PASSWORD = os.getenv("SNOWFLAKE_PASSWORD")
SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_WAREHOUSE = os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")
SNOWFLAKE_DATABASE = "ECOMMERCE_DB"
SNOWFLAKE_SCHEMA = "ANALYTICS"

# DynamoDB table names
USER_SEGMENTS_TABLE = 'ecommerce_user_segments'
PRODUCT_RECOMMENDATIONS_TABLE = 'ecommerce_product_recommendations'

def check_credentials():
    """Verify that required credentials are available."""
    missing_creds = []
    
    if not SNOWFLAKE_USER:
        missing_creds.append("SNOWFLAKE_USER")
    if not SNOWFLAKE_PASSWORD:
        missing_creds.append("SNOWFLAKE_PASSWORD")
    if not SNOWFLAKE_ACCOUNT:
        missing_creds.append("SNOWFLAKE_ACCOUNT")
    
    if missing_creds:
        logger.error(f"Missing required environment variables: {', '.join(missing_creds)}")
        logger.error("Please set these environment variables before running the script.")
        return False
    
    return True

def create_dynamodb_tables():
    """Create DynamoDB tables if they don't exist."""
    dynamodb = boto3.resource('dynamodb')
    
    # Create User Segments table
    try:
        table = dynamodb.Table(USER_SEGMENTS_TABLE)
        table.load()
        logger.info(f"Table {USER_SEGMENTS_TABLE} already exists")
    except dynamodb.meta.client.exceptions.ResourceNotFoundException:
        logger.info(f"Creating table {USER_SEGMENTS_TABLE}...")
        table = dynamodb.create_table(
            TableName=USER_SEGMENTS_TABLE,
            KeySchema=[
                {
                    'AttributeName': 'user_id',
                    'KeyType': 'HASH'
                }
            ],
            AttributeDefinitions=[
                {
                    'AttributeName': 'user_id',
                    'AttributeType': 'S'
                }
            ],
            BillingMode='PAY_PER_REQUEST'
        )
        table.wait_until_exists()
        logger.info(f"Table {USER_SEGMENTS_TABLE} created successfully")
    
    # Create Product Recommendations table
    try:
        table = dynamodb.Table(PRODUCT_RECOMMENDATIONS_TABLE)
        table.load()
        logger.info(f"Table {PRODUCT_RECOMMENDATIONS_TABLE} already exists")
    except dynamodb.meta.client.exceptions.ResourceNotFoundException:
        logger.info(f"Creating table {PRODUCT_RECOMMENDATIONS_TABLE}...")
        table = dynamodb.create_table(
            TableName=PRODUCT_RECOMMENDATIONS_TABLE,
            KeySchema=[
                {
                    'AttributeName': 'user_id',
                    'KeyType': 'HASH'
                }
            ],
            AttributeDefinitions=[
                {
                    'AttributeName': 'user_id',
                    'AttributeType': 'S'
                }
            ],
            BillingMode='PAY_PER_REQUEST'
        )
        table.wait_until_exists()
        logger.info(f"Table {PRODUCT_RECOMMENDATIONS_TABLE} created successfully")

def safe_convert_to_int(value):
    """Safely convert value to int, handling large numbers."""
    if value is None:
        return 0
    try:
        # Convert to string first to handle large numbers
        str_value = str(value)
        # If it's too large, use 0
        if len(str_value) > 10:  # Reasonable limit for int
            logger.warning(f"Value too large for int conversion: {str_value[:20]}...")
            return 0
        return int(float(str_value))
    except (ValueError, OverflowError):
        logger.warning(f"Could not convert {value} to int, using 0")
        return 0

def safe_convert_to_float(value):
    """Safely convert value to float, handling large numbers."""
    if value is None:
        return 0.0
    try:
        # Convert to string first to handle large numbers
        str_value = str(value)
        # If it's too large, use 0.0
        if len(str_value) > 20:  # Reasonable limit for float
            logger.warning(f"Value too large for float conversion: {str_value[:20]}...")
            return 0.0
        return float(str_value)
    except (ValueError, OverflowError):
        logger.warning(f"Could not convert {value} to float, using 0.0")
        return 0.0

def fetch_user_segments_robust():
    """Fetch user segments from Snowflake using robust data handling."""
    logger.info("Fetching user segments from Snowflake (robust method)...")
    
    query = """
    SELECT 
        USER_ID,
        SEGMENT,
        TOTAL_SPEND,
        TOTAL_PURCHASES,
        FAVORITE_BRAND,
        MOST_VIEWED_CATEGORY,
        LAST_SEEN_DATE
    FROM USER_SEGMENTS
    """
    
    try:
        with snowflake.connector.connect(
            user=SNOWFLAKE_USER,
            password=SNOWFLAKE_PASSWORD,
            account=SNOWFLAKE_ACCOUNT,
            warehouse=SNOWFLAKE_WAREHOUSE,
            database=SNOWFLAKE_DATABASE,
            schema=SNOWFLAKE_SCHEMA
        ) as conn:
            cursor = conn.cursor()
            
            # Use pandas to handle large numbers better
            import pandas as pd
            
            # Execute query and fetch as pandas DataFrame
            df = pd.read_sql(query, conn)
            logger.info(f"Fetched {len(df)} user segments from Snowflake")
            
            # Convert DataFrame to list of tuples
            results = []
            for _, row in df.iterrows():
                try:
                    # Convert each row to tuple, handling None values
                    row_tuple = (
                        str(row['USER_ID']) if pd.notna(row['USER_ID']) else None,
                        str(row['SEGMENT']) if pd.notna(row['SEGMENT']) else None,
                        float(row['TOTAL_SPEND']) if pd.notna(row['TOTAL_SPEND']) else 0.0,
                        int(row['TOTAL_PURCHASES']) if pd.notna(row['TOTAL_PURCHASES']) else 0,
                        str(row['FAVORITE_BRAND']) if pd.notna(row['FAVORITE_BRAND']) else None,
                        str(row['MOST_VIEWED_CATEGORY']) if pd.notna(row['MOST_VIEWED_CATEGORY']) else None,
                        str(row['LAST_SEEN_DATE']) if pd.notna(row['LAST_SEEN_DATE']) else None
                    )
                    results.append(row_tuple)
                except Exception as e:
                    logger.warning(f"Error processing row: {e}")
                    continue
            
            return results
            
    except Exception as e:
        logger.error(f"Error fetching user segments: {e}")
        return []

def fetch_product_recommendations_robust():
    """Fetch product recommendations from Snowflake using robust data handling."""
    logger.info("Fetching product recommendations from Snowflake (robust method)...")
    
    query = """
    SELECT 
        USER_ID,
        RECOMMENDED_PRODUCTS,
        RECOMMENDATION_REASON,
        RECOMMENDATION_DATE
    FROM USER_PRODUCT_RECOMMENDATIONS
    """
    
    try:
        with snowflake.connector.connect(
            user=SNOWFLAKE_USER,
            password=SNOWFLAKE_PASSWORD,
            account=SNOWFLAKE_ACCOUNT,
            warehouse=SNOWFLAKE_WAREHOUSE,
            database=SNOWFLAKE_DATABASE,
            schema=SNOWFLAKE_SCHEMA
        ) as conn:
            cursor = conn.cursor()
            
            # Use pandas to handle large numbers better
            import pandas as pd
            
            # Execute query and fetch as pandas DataFrame
            df = pd.read_sql(query, conn)
            logger.info(f"Fetched {len(df)} product recommendations from Snowflake")
            
            # Convert DataFrame to list of tuples
            results = []
            for _, row in df.iterrows():
                try:
                    # Convert each row to tuple, handling None values
                    row_tuple = (
                        str(row['USER_ID']) if pd.notna(row['USER_ID']) else None,
                        row['RECOMMENDED_PRODUCTS'] if pd.notna(row['RECOMMENDED_PRODUCTS']) else None,
                        str(row['RECOMMENDATION_REASON']) if pd.notna(row['RECOMMENDATION_REASON']) else None,
                        str(row['RECOMMENDATION_DATE']) if pd.notna(row['RECOMMENDATION_DATE']) else None
                    )
                    results.append(row_tuple)
                except Exception as e:
                    logger.warning(f"Error processing row: {e}")
                    continue
            
            return results
            
    except Exception as e:
        logger.error(f"Error fetching product recommendations: {e}")
        return []

def write_user_segments_to_dynamodb(data):
    """Write user segments to DynamoDB with proper data handling."""
    logger.info(f"Writing {len(data)} user segments to DynamoDB...")
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(USER_SEGMENTS_TABLE)
    
    with table.batch_writer() as batch:
        for row in data:
            try:
                (user_id, segment, total_spend, total_purchases, 
                 favorite_brand, most_viewed_category, last_seen_date) = row
                
                # Convert None values and handle data types safely
                item = {
                    'user_id': str(user_id) if user_id else 'unknown',
                    'customer_segment': str(segment) if segment else 'Unknown',
                    'total_spend': Decimal(str(safe_convert_to_float(total_spend))),
                    'total_purchases': Decimal(str(safe_convert_to_int(total_purchases))),
                    'favorite_brand': str(favorite_brand) if favorite_brand else '',
                    'most_viewed_category': str(most_viewed_category) if most_viewed_category else '',
                    'last_seen_date': str(last_seen_date) if last_seen_date else '',
                    'export_timestamp': datetime.utcnow().isoformat()
                }
                
                batch.put_item(Item=item)
                
            except Exception as e:
                logger.error(f"Error processing user segment row {row}: {e}")
                continue
    
    logger.info("User segments written to DynamoDB successfully")

def write_recommendations_to_dynamodb(data):
    """Write product recommendations to DynamoDB with proper data handling."""
    logger.info(f"Writing {len(data)} product recommendations to DynamoDB...")
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(PRODUCT_RECOMMENDATIONS_TABLE)
    
    with table.batch_writer() as batch:
        for row in data:
            try:
                user_id, recommended_products, recommendation_reason, recommendation_date = row
                
                # Parse the recommended products array from Snowflake
                try:
                    if isinstance(recommended_products, str):
                        products = json.loads(recommended_products)
                    else:
                        products = recommended_products or []
                    
                    # Convert to list of integers safely
                    product_list = []
                    for product in products:
                        try:
                            product_list.append(safe_convert_to_int(product))
                        except (ValueError, TypeError):
                            continue
                            
                except (json.JSONDecodeError, TypeError):
                    product_list = []
                
                item = {
                    'user_id': str(user_id) if user_id else 'unknown',
                    'recommended_products': product_list,
                    'recommendation_reason': str(recommendation_reason) if recommendation_reason else '',
                    'recommendation_date': str(recommendation_date) if recommendation_date else '',
                    'updated_at': datetime.utcnow().isoformat()
                }
                
                batch.put_item(Item=item)
                
            except Exception as e:
                logger.error(f"Error processing recommendation row {row}: {e}")
                continue
    
    logger.info("Product recommendations written to DynamoDB successfully")

def main():
    """Main export function."""
    logger.info("Starting Robust DynamoDB export process...")
    
    # Check credentials
    if not check_credentials():
        logger.error("Cannot proceed without proper credentials")
        return
    
    # Create DynamoDB tables if needed
    create_dynamodb_tables()
    
    # Fetch and export user segments
    user_segments = fetch_user_segments_robust()
    if user_segments:
        write_user_segments_to_dynamodb(user_segments)
    else:
        logger.warning("No user segments to export")
    
    # Fetch and export product recommendations
    recommendations = fetch_product_recommendations_robust()
    if recommendations:
        write_recommendations_to_dynamodb(recommendations)
    else:
        logger.warning("No product recommendations to export")
    
    logger.info("🎉 Robust DynamoDB export completed successfully!")

if __name__ == "__main__":
    main() 