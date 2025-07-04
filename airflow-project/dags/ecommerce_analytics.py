import pendulum
from airflow.decorators import dag
from astro import sql as aql
from astro.files import File
from astro.sql import Table
from astro.sql.operators.load_file import LoadFileOperator

# --- 1. Configuration & Constants ---
S3_CONN_ID = "aws_default"
SNOWFLAKE_CONN_ID = "snowflake_default"
# Handle partitioned S3 structure with multiple event types
S3_INPUT_PATH = "s3://kafka-cust-transactions/raw/user_events/event_type=*/"

# Define the tables in our layered data model
SNOWFLAKE_STG_TABLE = Table(name="STG_EVENTS", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_PRODUCTS_DIM_TABLE = Table(name="DIM_PRODUCTS", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_SESSIONS_FACT_TABLE = Table(name="FCT_USER_SESSIONS", conn_id=SNOWFLAKE_CONN_ID)
SNOWFLAKE_USERS_DIM_TABLE = Table(name="DIM_USERS", conn_id=SNOWFLAKE_CONN_ID)


@dag(
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 3 * * *",  # Run daily at 3:00 AM UTC
    catchup=False,
    tags=["ecommerce", "analytics", "production"],
)
def ecommerce_analytics_pipeline():
    # --- 2. EXTRACT & LOAD ---
    # Load raw data from S3 into a staging table in Snowflake.
    # This ELT pattern leverages Snowflake's compute for all transformations.
    load_raw_events = aql.load_file(
        task_id="load_events_from_s3_to_staging",
        input_file=File(path=S3_INPUT_PATH, conn_id=S3_CONN_ID, filetype="parquet"),
        output_table=SNOWFLAKE_STG_TABLE,
        use_native_support=True,
    ) 