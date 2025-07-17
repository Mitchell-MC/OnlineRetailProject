#!/usr/bin/env python3
"""
Enhanced DynamoDB Export Script for Ecommerce Data Warehouse

This script exports user segments and product recommendations from Snowflake
to DynamoDB tables for real-time application access.

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

def fetch_user_segments():
    """Fetch user segments from Snowflake."""
    logger.info("Fetching user segments from Snowflake...")
    
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
    
    with snowflake.connector.connect(
        user=SNOWFLAKE_USER,
        password=SNOWFLAKE_PASSWORD,
        account=SNOWFLAKE_ACCOUNT,
        warehouse=SNOWFLAKE_WAREHOUSE,
        database=SNOWFLAKE_DATABASE,
        schema=SNOWFLAKE_SCHEMA
    ) as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        results = cursor.fetchall()
        logger.info(f"Fetched {len(results)} user segments from Snowflake")
        return results

def fetch_product_recommendations():
    """Fetch product recommendations from Snowflake."""
    logger.info("Fetching product recommendations from Snowflake...")
    
    query = """
    SELECT 
        USER_ID,
        RECOMMENDED_PRODUCTS,
        RECOMMENDATION_REASON,
        RECOMMENDATION_DATE
    FROM USER_PRODUCT_RECOMMENDATIONS
    """
    
    with snowflake.connector.connect(
        user=SNOWFLAKE_USER,
        password=SNOWFLAKE_PASSWORD,
        account=SNOWFLAKE_ACCOUNT,
        warehouse=SNOWFLAKE_WAREHOUSE,
        database=SNOWFLAKE_DATABASE,
        schema=SNOWFLAKE_SCHEMA
    ) as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        results = cursor.fetchall()
        logger.info(f"Fetched {len(results)} product recommendations from Snowflake")
        return results

def write_user_segments_to_dynamodb(data):
    """Write user segments to DynamoDB."""
    logger.info(f"Writing {len(data)} user segments to DynamoDB...")
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(USER_SEGMENTS_TABLE)
    
    with table.batch_writer() as batch:
        for row in data:
            user_id, segment, total_spend, total_purchases, favorite_brand, most_viewed_category, last_seen_date = row
            
            # Convert None values and handle data types
            item = {
                'user_id': str(user_id),
                'segment': str(segment) if segment else 'Unknown',
                'total_spend': float(total_spend) if total_spend else 0.0,
                'total_purchases': int(total_purchases) if total_purchases else 0,
                'favorite_brand': str(favorite_brand) if favorite_brand else 'None',
                'most_viewed_category': str(most_viewed_category) if most_viewed_category else 'None',
                'last_seen_date': str(last_seen_date) if last_seen_date else '',
                'updated_at': datetime.utcnow().isoformat()
            }
            
            batch.put_item(Item=item)
    
    logger.info("User segments written to DynamoDB successfully")

def write_recommendations_to_dynamodb(data):
    """Write product recommendations to DynamoDB."""
    logger.info(f"Writing {len(data)} product recommendations to DynamoDB...")
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(PRODUCT_RECOMMENDATIONS_TABLE)
    
    with table.batch_writer() as batch:
        for row in data:
            user_id, recommended_products, recommendation_reason, recommendation_date = row
            
            # Parse the recommended products array from Snowflake
            try:
                if isinstance(recommended_products, str):
                    products = json.loads(recommended_products)
                else:
                    products = recommended_products
                
                # Convert to list of strings
                products = [str(p) for p in products] if products else []
                
            except (json.JSONDecodeError, TypeError):
                logger.warning(f"Failed to parse recommendations for user {user_id}: {recommended_products}")
                products = []
            
            item = {
                'user_id': str(user_id),
                'recommended_products': products,
                'recommendation_reason': str(recommendation_reason) if recommendation_reason else 'Unknown',
                'recommendation_date': str(recommendation_date) if recommendation_date else '',
                'updated_at': datetime.utcnow().isoformat()
            }
            
            batch.put_item(Item=item)
    
    logger.info("Product recommendations written to DynamoDB successfully")

def main():
    """Main execution function."""
    logger.info("Starting DynamoDB export process...")
    
    # Check credentials
    if not check_credentials():
        return
    
    try:
        # Create DynamoDB tables if needed
        create_dynamodb_tables()
        
        # Export user segments
        user_segments = fetch_user_segments()
        if user_segments:
            write_user_segments_to_dynamodb(user_segments)
        else:
            logger.warning("No user segments found to export")
        
        # Export product recommendations
        recommendations = fetch_product_recommendations()
        if recommendations:
            write_recommendations_to_dynamodb(recommendations)
        else:
            logger.warning("No product recommendations found to export")
        
        logger.info("🎉 DynamoDB export completed successfully!")
        logger.info(f"Data exported to tables: {USER_SEGMENTS_TABLE}, {PRODUCT_RECOMMENDATIONS_TABLE}")
        
    except Exception as e:
        logger.error(f"Export failed: {str(e)}")
        raise

if __name__ == "__main__":
    main() 