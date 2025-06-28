# dags/ecommerce_daily_sdk.py

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
S3_INPUT_PATH = "s3://kafka-cust-transactions/raw/user_events/event_type=*/**/*.parquet"
# --- UPDATED Snowflake Database, Schema, and Table ---
SNOWFLAKE_TABLE = "ECOMMERCE_DB.ANALYTICS.CUSTOMER_360_PROFILES"

# Define the output table for our transformation
output_table = Table(name=SNOWFLAKE_TABLE, conn_id=SNOWFLAKE_CONN_ID)

# Define the tables in our layered data model for analytics
SNOWFLAKE_STG_TABLE = Table(name="STG_EVENTS", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_PRODUCTS_DIM_TABLE = Table(name="DIM_PRODUCTS", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_SESSIONS_FACT_TABLE = Table(name="FCT_USER_SESSIONS", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_USERS_DIM_TABLE = Table(name="DIM_USERS", conn_id=SNOWFLAKE_CONN_ID)

@dag(
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 1 * * *",
    catchup=False,
    tags=["ecommerce", "sdk", "etl", "analytics"],
)
def ecommerce_daily_etl_sdk():
    # 1. READ (Extract) - Load raw data from S3 into a staging table in Snowflake
    load_raw_events = aql.load_file(
        task_id="load_events_from_s3_to_staging",
        input_file=File(path=S3_INPUT_PATH, conn_id=S3_CONN_ID, filetype="parquet"),
        output_table=SNOWFLAKE_STG_TABLE,
        use_native_support=True,
    )

    # 2. TRANSFORM and 3. LOAD - Customer 360 Profiles
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
    transformed_table = transform_events(input_table=load_raw_events.output)

    # Set dependencies
    load_raw_events >> transformed_table

ecommerce_daily_etl_sdk()