# dags/ecommerce_daily_sdk_test.py

import pendulum
from airflow.decorators import dag
from astro import sql as aql

# Import Astro SDK functions and classes
from astro.files import File
from astro.sql import Table
from astro.sql.operators.load_file import LoadFileOperator

# Define connections and parameters using your specific paths
S3_CONN_ID = "aws_default"
SNOWFLAKE_CONN_ID = "snowflake_default"
# --- UPDATED S3 Path for partitioned structure ---
S3_INPUT_PATH = "s3://kafka-cust-transactions/raw/user_events/event_type=*/"
# --- UPDATED Snowflake Database, Schema, and Table ---
SNOWFLAKE_TABLE = "ECOMMERCE_DB.ANALYTICS.CUSTOMER_360_PROFILES"

# Define the output table for our transformation
output_table = Table(name=SNOWFLAKE_TABLE, conn_id=SNOWFLAKE_CONN_ID)

@dag(
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 1 * * *",
    catchup=False,
    tags=["ecommerce", "sdk", "etl", "test"],
)
def ecommerce_daily_etl_sdk_test():
    # 1. READ (Extract)
    raw_events_table = LoadFileOperator(
        task_id="load_events_from_s3",
        input_file=File(path=S3_INPUT_PATH, conn_id=S3_CONN_ID, filetype="parquet"),
        output_table=Table(conn_id=SNOWFLAKE_CONN_ID) # Let Astro create a temporary table
    )

    # 2. TRANSFORM and 3. LOAD
    @aql.transform()
    def transform_events(input_table):
        return f"""
        SELECT 
            user_id as USER_ID,
            MAX(CASE WHEN event_type = 'purchase' AND brand IS NOT NULL 
                THEN brand END) as FAVORITE_BRAND,
            MAX(CASE WHEN event_type = 'view' AND category_code IS NOT NULL 
                THEN category_code END) as MOST_VIEWED_CATEGORY,
            COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) as TOTAL_PURCHASES,
            SUM(CASE WHEN event_type = 'purchase' THEN CAST(price AS DOUBLE) ELSE 0 END) as TOTAL_SPEND,
            MAX(event_time) as LAST_SEEN_DATE
        FROM {{ input_table }}
        WHERE user_id IS NOT NULL
        GROUP BY user_id
        """

    # Execute the transform and return the result
    transformed_table = transform_events(input_table=raw_events_table.output)

    # Set dependencies
    raw_events_table

ecommerce_daily_etl_sdk_test() 