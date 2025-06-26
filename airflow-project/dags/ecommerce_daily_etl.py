# dags/ecommerce_daily_etl.py
from __future__ import annotations
import pendulum

from airflow.decorators import dag
from airflow.models import Variable
from airflow.utils.dates import days_ago
from astro import sql as aql
from astro.files import File
from astro.sql.table import Table

# Get configuration from Airflow Variables
S3_INPUT_PATH = Variable.get("S3_INPUT_PATH", "s3a://your-default-bucket/raw/user_events/")
SNOWFLAKE_TABLE = Variable.get("SNOWFLAKE_TABLE", "YOUR_DB.YOUR_SCHEMA.YOUR_TABLE")

@dag(
    dag_id='ecommerce_daily_etl_astro_sdk',
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 1 * * *",  # Run daily at 1:00 AM UTC
    catchup=False,
    tags=["ecommerce", "astro-sdk", "etl", "s3", "snowflake"],
    doc_md="""
    ### E-commerce Daily ETL Pipeline (Astro SDK)

    This DAG uses the Astro SDK to:
    1. **Extract** raw user event data from an S3 data lake.
    2. **Transform** the data using SQL.
    3. **Load** the final aggregated table into Snowflake.
    """
)
def ecommerce_daily_etl_astro_sdk():
    # 1. Load data from S3 to a temporary table
    s3_data = aql.load_file(
        task_id="load_s3_data",
        input_file=File(S3_INPUT_PATH, conn_id="aws_default"),
        output_table=Table(conn_id="snowflake_default"),  # temp table in Snowflake
    )

    # 2. Transform data (example: select all columns, you can customize this SQL)
    transformed_data = aql.transform(
        task_id="transform_data",
        sql="""
            SELECT * FROM {{ s3_data }}
            -- Add your transformation logic here
        """,
        parameters={"s3_data": s3_data},
        conn_id="snowflake_default"
    )

    # 3. Load transformed data to target Snowflake table
    aql.append(
        task_id="load_to_snowflake",
        source_table=transformed_data,
        target_table=Table(SNOWFLAKE_TABLE, conn_id="snowflake_default")
    )

dag = ecommerce_daily_etl_astro_sdk()