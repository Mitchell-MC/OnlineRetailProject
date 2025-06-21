import os
import json
import boto3
import snowflake.connector
from decimal import Decimal

# --- Configuration ---
# Assumes AWS credentials are set as environment variables
# Snowflake credentials should be securely stored, e.g., in environment variables
SNOWFLAKE_USER = os.getenv("SNOWFLAKE_USER")
SNOWFLAKE_PASSWORD = os.getenv("SNOWFLAKE_PASSWORD")
SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
SNOWFLAKE_DATABASE = "ECOMMERCE_DB"
SNOWFLAKE_SCHEMA = "ANALYTICS"

DYNAMODB_TABLE_NAME = 'product_recommendations'

def fetch_snowflake_data():
    """Fetches product recommendations from Snowflake."""
    print("Connecting to Snowflake...")
    with snowflake.connector.connect(
        user=SNOWFLAKE_USER,
        password=SNOWFLAKE_PASSWORD,
        account=SNOWFLAKE_ACCOUNT,
        warehouse=SNOWFLAKE_WAREHOUSE,
        database=SNOWFLAKE_DATABASE,
        schema=SNOWFLAKE_SCHEMA
    ) as conn:
        print("Successfully connected. Fetching data...")
        cursor = conn.cursor()
        cursor.execute("SELECT USER_ID, RECOMMENDED_PRODUCTS FROM USER_PRODUCT_RECOMMENDATIONS")
        # Fetch all results
        results = cursor.fetchall()
        print(f"Fetched {len(results)} rows from Snowflake.")
        return results

def write_to_dynamodb(data):
    """Writes data in batches to DynamoDB."""
    print("Connecting to DynamoDB...")
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(DYNAMODB_TABLE_NAME)

    print(f"Starting batch write to {DYNAMODB_TABLE_NAME}...")
    with table.batch_writer() as batch:
        for row in data:
            user_id, recommended_products = row
            # The recommended_products from Snowflake is a string representation of a list
            # We need to parse it. It may look like '[\n  123,\n  456\n]'
            product_list = json.loads(recommended_products)

            batch.put_item(
                Item={
                    'user_id': int(user_id),
                    'recommended_products': [int(p) for p in product_list]
                }
            )
    print("Batch write to DynamoDB complete.")

if __name__ == "__main__":
    snowflake_data = fetch_snowflake_data()
    if snowflake_data:
        write_to_dynamodb(snowflake_data)