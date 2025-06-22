# dags/ecommerce_daily_etl.py
from __future__ import annotations
import pendulum

from airflow.models.dag import DAG
from airflow.models import Variable
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

# Get configuration from Airflow Variables
S3_INPUT_PATH = Variable.get("S3_INPUT_PATH", "s3a://your-default-bucket/raw/user_events/")
SNOWFLAKE_TABLE = Variable.get("SNOWFLAKE_TABLE", "YOUR_DB.YOUR_SCHEMA.YOUR_TABLE")
SNOWFLAKE_CONN_ID = "snowflake_default"

with DAG(
    dag_id='ecommerce_daily_etl_spark_submit',
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 1 * * *",  # Run daily at 1:00 AM UTC
    catchup=False,
    tags=["ecommerce", "spark", "etl", "spark-submit"],
    doc_md="""
    ### E-commerce Daily ETL Pipeline

    This DAG uses the SparkSubmitOperator to orchestrate a Spark job that:
    1. **Extracts** raw user event data from an S3 data lake.
    2. **Transforms** the data into a Customer 360 profile.
    3. **Loads** the final aggregated table into Snowflake.
    """
) as dag:
    process_events_task = SparkSubmitOperator(
        task_id='process_events_on_spark',
        application='/opt/airflow/jobs/process_daily_events.py',  # Path inside the container
        conn_id='spark_default',  # Connection to the Spark Master
        # --- Jars for Spark to Connect to Snowflake and S3 ---
        jars=(
            "https://repo1.maven.org/maven2/net/snowflake/snowflake-jdbc/3.14.4/snowflake-jdbc-3.14.4.jar,"
            "https://repo1.maven.org/maven2/net/snowflake/spark-snowflake_2.12/2.12.0-spark_3.5/spark-snowflake_2.12-2.12.0-spark_3.5.jar,"
            "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar"
        ),
        # --- Pass credentials and arguments to the Spark job ---
        application_args=[
            "--s3_input_path", S3_INPUT_PATH,
            "--snowflake_table", SNOWFLAKE_TABLE,
        ],
        # --- Securely configure Spark to connect to Snowflake using Airflow connection ---
        conf={
            "spark.hadoop.fs.s3a.aws.credentials.provider": "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider",
            "spark.hadoop.fs.s3a.access.key": "{{ conn.aws_default.login }}",
            "spark.hadoop.fs.s3a.secret.key": "{{ conn.aws_default.password }}",
            "spark.snowflake.auth": "user-password",
            "spark.snowflake.user": "{{ conn.snowflake_default.login }}",
            "spark.snowflake.password": "{{ conn.snowflake_default.password }}",
            "spark.snowflake.url": "{{ conn.snowflake_default.host }}",
            "spark.snowflake.sfDatabase": "{{ conn.snowflake_default.extra_dejson.database }}",
            "spark.snowflake.sfSchema": "{{ conn.snowflake_default.extra_dejson.schema }}",
            "spark.snowflake.sfWarehouse": "{{ conn.snowflake_default.extra_dejson.warehouse }}"
        },
    )