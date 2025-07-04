# dags/ecommerce_daily_sdk.py

import pendulum
from airflow.decorators import dag
from astro import sql as aql
from astro.sql import Table
from airflow.operators.python import PythonOperator
import pandas as pd
import boto3
import io
import snowflake.connector

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

def load_parquet_from_s3(bucket, prefix, table_name, **context):
    """Load Parquet files from S3 into Snowflake using pandas"""
    
    # Connect to S3
    s3_client = boto3.client('s3')
    
    # List objects in the S3 prefix
    response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
    
    if 'Contents' not in response:
        print(f"No files found in s3://{bucket}/{prefix}")
        return
    
    # Read all Parquet files
    dfs = []
    for obj in response['Contents']:
        if obj['Key'].endswith('.parquet'):
            print(f"Reading {obj['Key']}")
            obj_response = s3_client.get_object(Bucket=bucket, Key=obj['Key'])
            df = pd.read_parquet(io.BytesIO(obj_response['Body'].read()))
            dfs.append(df)
    
    if not dfs:
        print("No Parquet files found")
        return
    
    # Combine all dataframes
    combined_df = pd.concat(dfs, ignore_index=True)
    print(f"Loaded {len(combined_df)} rows from {len(dfs)} files")
    
    # Load into Snowflake directly using snowflake-connector
    # Get Snowflake connection details from Airflow
    from airflow.hooks.base import BaseHook
    conn = BaseHook.get_connection(SNOWFLAKE_CONN_ID)
    
    # Connect to Snowflake
    sf_conn = snowflake.connector.connect(
        user=conn.login,
        password=conn.password,
        account=conn.extra_dejson.get('account'),
        warehouse=conn.extra_dejson.get('warehouse'),
        database=conn.extra_dejson.get('database'),
        schema=conn.extra_dejson.get('schema', 'ANALYTICS')
    )
    
    # Create table if not exists
    create_table_sql = f"""
    CREATE TABLE IF NOT EXISTS {table_name} (
        user_id STRING,
        event_time TIMESTAMP,
        event_type STRING,
        product_id STRING,
        price DECIMAL(10,2),
        brand STRING,
        category_code STRING
    )
    """
    sf_conn.cursor().execute(create_table_sql)
    
    # Convert dataframe to list of tuples for insertion
    records = combined_df.to_dict('records')
    insert_sql = f"INSERT INTO {table_name} (user_id, event_time, event_type, product_id, price, brand, category_code) VALUES (%s, %s, %s, %s, %s, %s, %s)"
    
    cursor = sf_conn.cursor()
    for record in records:
        cursor.execute(insert_sql, (
            record.get('user_id'),
            record.get('event_time'),
            record.get('event_type'),
            record.get('product_id'),
            record.get('price'),
            record.get('brand'),
            record.get('category_code')
        ))
    
    sf_conn.commit()
    sf_conn.close()
    print(f"Successfully loaded {len(records)} rows into {table_name}")

@dag(
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 1 * * *",
    catchup=False,
    tags=["ecommerce", "sdk", "etl", "analytics"],
)
def ecommerce_daily_etl_sdk():
    # Load each event type from S3 into its own staging table
    load_cart = PythonOperator(
        task_id="load_cart_events",
        python_callable=load_parquet_from_s3,
        op_kwargs={
            'bucket': 'kafka-cust-transactions',
            'prefix': 'raw/user_events/event_type=cart/',
            'table_name': 'STG_EVENTS_CART'
        }
    )
    
    load_purchase = PythonOperator(
        task_id="load_purchase_events",
        python_callable=load_parquet_from_s3,
        op_kwargs={
            'bucket': 'kafka-cust-transactions',
            'prefix': 'raw/user_events/event_type=purchase/',
            'table_name': 'STG_EVENTS_PURCHASE'
        }
    )
    
    load_view = PythonOperator(
        task_id="load_view_events",
        python_callable=load_parquet_from_s3,
        op_kwargs={
            'bucket': 'kafka-cust-transactions',
            'prefix': 'raw/user_events/event_type=view/',
            'table_name': 'STG_EVENTS_VIEW'
        }
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