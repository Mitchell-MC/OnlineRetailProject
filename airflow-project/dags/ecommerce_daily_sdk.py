# dags/ecommerce_daily_sdk.py

import pendulum
from airflow.decorators import dag

# Import Astro SDK functions and classes
from astro.files import File
from astro.sql import Table
from astro.sql.operators.load_file import LoadFileOperator
from astro.snowpark.transforms import snowpark_transform
from snowflake.snowpark.functions import col, count, sum, max, row_number
from snowflake.snowpark import Window

# Define connections and parameters using your specific paths
S3_CONN_ID = "aws_default"
SNOWFLAKE_CONN_ID = "snowflake_default"
# --- UPDATED S3 Path ---
S3_INPUT_PATH = "s3://kafka-cust-transactions/checkpoints/user_events/commits/"
# --- UPDATED Snowflake Database, Schema, and Table ---
SNOWFLAKE_TABLE = "ECOMMERCE_DB.ANALYTICS.CUSTOMER_360_PROFILES"

# Define the output table for our transformation
output_table = Table(name=SNOWFLAKE_TABLE, conn_id=SNOWFLAKE_CONN_ID)

# The @snowpark_transform decorator tells the Astro SDK to run this Python
# function's logic as a Snowpark dataframe operation within Snowflake.
@snowpark_transform
def transform_events(raw_df):
    """
    Main ETL logic for processing daily e-commerce events using Snowpark.
    This function replicates the logic from your original process_daily_events.py script.
    """
    print("Transforming data using Snowpark...")
    cleaned_df = raw_df.filter(col("user_id").isNotNull()) \
                       .with_column("price", col("price").cast("double")) \
                       .dropna(subset=["user_id", "price"])

    # Find the favorite brand for each user
    brand_window = Window.partition_by("user_id").order_by(col("brand_count").desc())
    favorite_brand_df = cleaned_df \
        .filter((col("event_type") == "purchase") & (col("brand").isNotNull())) \
        .group_by("user_id", "brand") \
        .agg(count("*").alias("brand_count")) \
        .with_column("rank", row_number().over(brand_window)) \
        .filter(col("rank") == 1) \
        .select(col("user_id"), col("brand").alias("FAVORITE_BRAND"))

    # Find the most viewed category for each user
    category_window = Window.partition_by("user_id").order_by(col("category_count").desc())
    most_viewed_category_df = cleaned_df \
        .filter((col("event_type") == "view") & (col("category_code").isNotNull())) \
        .group_by("user_id", "category_code") \
        .agg(count("*").alias("category_count")) \
        .with_column("rank", row_number().over(category_window)) \
        .filter(col("rank") == 1) \
        .select(col("user_id"), col("category_code").alias("MOST_VIEWED_CATEGORY"))

    # Calculate purchase metrics
    purchase_metrics_df = cleaned_df \
        .filter(col("event_type") == "purchase") \
        .group_by("user_id") \
        .agg(
            count("*").alias("TOTAL_PURCHASES"),
            sum("price").alias("TOTAL_SPEND")
        )

    # Find the last seen date for each user
    last_seen_df = cleaned_df.group_by("user_id").agg(
        max("event_time").alias("LAST_SEEN_DATE")
    )

    # Join all the metrics together to create the final customer 360 view
    customer_360_df = last_seen_df \
        .join(favorite_brand_df, "user_id", "left") \
        .join(most_viewed_category_df, "user_id", "left") \
        .join(purchase_metrics_df, "user_id", "left") \
        .select(
            col("user_id").alias("USER_ID"),
            col("FAVORITE_BRAND"),
            col("MOST_VIEWED_CATEGORY"),
            col("TOTAL_PURCHASES"),
            col("TOTAL_SPEND"),
            col("LAST_SEEN_DATE")
        )
    
    return customer_360_df

@dag(
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 1 * * *",
    catchup=False,
    tags=["ecommerce", "sdk", "etl", "snowpark"],
)
def ecommerce_daily_etl_sdk():
    # 1. READ (Extract)
    # The SDK's LoadFileOperator handles loading data from S3 into a temporary table in Snowflake.
    raw_events_table = LoadFileOperator(
        task_id="load_events_from_s3",
        input_file=File(path=S3_INPUT_PATH, conn_id=S3_CONN_ID),
        output_table=Table(conn_id=SNOWFLAKE_CONN_ID) # Let Astro create a temporary table
    )

    # 2. TRANSFORM and 3. LOAD
    # The Astro SDK automatically passes the output of the 'load' step as a Snowpark
    # dataframe to the 'transform' function. The result is then saved to the final table.
    transform_events(
        raw_df=raw_events_table.output,
        output_table=output_table,
    )

ecommerce_daily_etl_sdk()