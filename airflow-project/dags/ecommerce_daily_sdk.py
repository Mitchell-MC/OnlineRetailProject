# dags/ecommerce_daily_sdk.py

import pendulum
from airflow.decorators import dag
from astro import sql as aql
from astro.files import File
from astro.sql import Table

S3_CONN_ID = "aws_default"
SNOWFLAKE_CONN_ID = "snowflake_default"

# S3 paths for each event type
S3_CART_PATH = "s3://kafka-cust-transactions/raw/user_events/event_type=cart/"
S3_PURCHASE_PATH = "s3://kafka-cust-transactions/raw/user_events/event_type=purchase/"
S3_VIEW_PATH = "s3://kafka-cust-transactions/raw/user_events/event_type=view/"

SNOWFLAKE_STG_CART = Table(name="STG_EVENTS_CART", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_STG_PURCHASE = Table(name="STG_EVENTS_PURCHASE", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_STG_VIEW = Table(name="STG_EVENTS_VIEW", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_COMBINED_STG = Table(name="STG_EVENTS_COMBINED", conn_id=SNOWFLAKE_CONN_ID)

@dag(
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 1 * * *",
    catchup=False,
    tags=["ecommerce", "sdk", "etl", "analytics"],
)
def ecommerce_daily_etl_sdk():
    # Load each event type from S3 into its own staging table
    load_cart = aql.load_file(
        task_id="load_cart_events",
        input_file=File(path=S3_CART_PATH, conn_id=S3_CONN_ID, filetype="parquet"),
        output_table=SNOWFLAKE_STG_CART,
        use_native_support=True,
    )
    load_purchase = aql.load_file(
        task_id="load_purchase_events",
        input_file=File(path=S3_PURCHASE_PATH, conn_id=S3_CONN_ID, filetype="parquet"),
        output_table=SNOWFLAKE_STG_PURCHASE,
        use_native_support=True,
    )
    load_view = aql.load_file(
        task_id="load_view_events",
        input_file=File(path=S3_VIEW_PATH, conn_id=S3_CONN_ID, filetype="parquet"),
        output_table=SNOWFLAKE_STG_VIEW,
        use_native_support=True,
    )

    # Combine all event types into a single staging table
    @aql.transform()
    def combine_events(cart, purchase, view):
        return """
        SELECT * FROM {{ cart }}
        UNION ALL
        SELECT * FROM {{ purchase }}
        UNION ALL
        SELECT * FROM {{ view }}
        """

    combined_events = combine_events(cart=load_cart, purchase=load_purchase, view=load_view, output_table=SNOWFLAKE_COMBINED_STG)

    # Downstream transformation (example: customer 360)
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

    transformed_table = transform_events(input_table=combined_events)

    # Set dependencies
    load_cart >> load_purchase >> load_view >> combined_events >> transformed_table

ecommerce_daily_etl_sdk()