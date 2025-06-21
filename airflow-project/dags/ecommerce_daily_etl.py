# dags/ecommerce_daily_etl.py
from __future__ import annotations
import pendulum

from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

# Define constants for paths and connection IDs
SPARK_CONN_ID = "my_spark_con"
S3_INPUT_PATH = "s3a://kafka-cust-transactions/raw/user_events/"
SNOWFLAKE_TABLE = "ECOMMERCE_DB.ANALYTICS.CUSTOMER_360_PROFILE"

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': pendulum.datetime(2025, 6, 19, tz="UTC"),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': pendulum.duration(minutes=5),
}

dag = DAG(
    'ecommerce_daily_etl_spark_submit',
    default_args=default_args,
    description='E-commerce Daily ETL Pipeline using SparkSubmitOperator',
    schedule="0 1 * * *",  # Run daily at 1:00 AM UTC
    catchup=False,
    tags=["ecommerce", "spark", "etl", "spark-submit"],
    doc_md="""
    ### E-commerce Daily ETL Pipeline (SparkSubmitOperator Method)

    This DAG uses the SparkSubmitOperator to orchestrate a Spark job.
    1. **Extract**: Reads raw user event data from an S3 data lake.
    2. **Transform**: Processes the data into a Customer 360 profile.
    3. **Load**: Writes the final aggregated table into Snowflake.

    **Connections Used**:
    - `my_spark_con`: For Airflow to connect to the Spark cluster.
    - `aws_default`: Used implicitly by Spark's Hadoop library to authenticate with S3.
    - `snowflake_default`: Used to template credentials into the Spark configuration.
    """,
)

# Define the Spark job task
process_events_task = SparkSubmitOperator(
    task_id='process_events_on_spark',
    application='/opt/airflow/jobs/ecommerce_etl_job.py',
    conn_id=SPARK_CONN_ID,
    conf={
        'spark.jars': '/opt/airflow/jobs/spark-snowflake_2.12-2.11.2-spark_3.3.jar',
        'spark.sql.adaptive.enabled': 'true',
        'spark.sql.adaptive.coalescePartitions.enabled': 'true'
    },
    dag=dag
)

# Set task dependencies (if you add more tasks later)
process_events_task