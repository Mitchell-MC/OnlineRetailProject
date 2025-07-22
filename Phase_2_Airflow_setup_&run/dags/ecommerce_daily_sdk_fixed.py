# dags/ecommerce_daily_sdk_fixed.py

import pendulum
from airflow.decorators import dag
from astro import sql as aql
from astro.sql import Table
from airflow.operators.python import PythonOperator
import pandas as pd
import random
from datetime import datetime, timedelta

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
def ecommerce_daily_etl_sdk_fixed():
    
    # Create tables with correct structure first
    @aql.transform(conn_id=SNOWFLAKE_CONN_ID)
    def create_staging_tables():
        return """
        -- Create STG_EVENTS_CART table
        CREATE TABLE IF NOT EXISTS ANALYTICS.STG_EVENTS_CART (
            user_id STRING,
            event_time TIMESTAMP,
            event_type STRING,
            product_id STRING,
            price DECIMAL(10,2),
            brand STRING,
            category_code STRING
        );
        
        -- Create STG_EVENTS_PURCHASE table
        CREATE TABLE IF NOT EXISTS ANALYTICS.STG_EVENTS_PURCHASE (
            user_id STRING,
            event_time TIMESTAMP,
            event_type STRING,
            product_id STRING,
            price DECIMAL(10,2),
            brand STRING,
            category_code STRING
        );
        
        -- Create STG_EVENTS_VIEW table
        CREATE TABLE IF NOT EXISTS ANALYTICS.STG_EVENTS_VIEW (
            user_id STRING,
            event_time TIMESTAMP,
            event_type STRING,
            product_id STRING,
            price DECIMAL(10,2),
            brand STRING,
            category_code STRING
        );
        
        -- Create STG_EVENTS_COMBINED table
        CREATE TABLE IF NOT EXISTS ANALYTICS.STG_EVENTS_COMBINED (
            user_id STRING,
            event_time TIMESTAMP,
            event_type STRING,
            product_id STRING,
            price DECIMAL(10,2),
            brand STRING,
            category_code STRING
        );
        
        SELECT 'Tables created successfully' as status;
        """

    # Create demo data using direct SQL instead of Astro SDK dataframe
    @aql.transform(conn_id=SNOWFLAKE_CONN_ID)
    def create_demo_cart_data():
        return """
        INSERT INTO ANALYTICS.STG_EVENTS_CART (user_id, event_time, event_type, product_id, price, brand, category_code)
        SELECT 
            'user_' || SEQ4() as user_id,
            DATEADD(day, -RANDOM() % 30, CURRENT_TIMESTAMP()) as event_time,
            'cart' as event_type,
            'prod_' || (RANDOM() % 90000 + 10000) as product_id,
            NULL as price,
            CASE WHEN RANDOM() % 2 = 0 THEN 
                CASE RANDOM() % 5 
                    WHEN 0 THEN 'Nike'
                    WHEN 1 THEN 'Adidas'
                    WHEN 2 THEN 'Apple'
                    WHEN 3 THEN 'Samsung'
                    WHEN 4 THEN 'Sony'
                END
            ELSE NULL END as brand,
            NULL as category_code
        FROM TABLE(GENERATOR(ROWCOUNT => 50))
        """

    @aql.transform(conn_id=SNOWFLAKE_CONN_ID)
    def create_demo_purchase_data():
        return """
        INSERT INTO ANALYTICS.STG_EVENTS_PURCHASE (user_id, event_time, event_type, product_id, price, brand, category_code)
        SELECT 
            'user_' || SEQ4() as user_id,
            DATEADD(day, -RANDOM() % 30, CURRENT_TIMESTAMP()) as event_time,
            'purchase' as event_type,
            'prod_' || (RANDOM() % 90000 + 10000) as product_id,
            ROUND(RANDOM() * 490 + 10, 2) as price,
            CASE WHEN RANDOM() % 2 = 0 THEN 
                CASE RANDOM() % 5 
                    WHEN 0 THEN 'Nike'
                    WHEN 1 THEN 'Adidas'
                    WHEN 2 THEN 'Apple'
                    WHEN 3 THEN 'Samsung'
                    WHEN 4 THEN 'Sony'
                END
            ELSE NULL END as brand,
            NULL as category_code
        FROM TABLE(GENERATOR(ROWCOUNT => 30))
        """

    @aql.transform(conn_id=SNOWFLAKE_CONN_ID)
    def create_demo_view_data():
        return """
        INSERT INTO ANALYTICS.STG_EVENTS_VIEW (user_id, event_time, event_type, product_id, price, brand, category_code)
        SELECT 
            'user_' || SEQ4() as user_id,
            DATEADD(day, -RANDOM() % 30, CURRENT_TIMESTAMP()) as event_time,
            'view' as event_type,
            'prod_' || (RANDOM() % 90000 + 10000) as product_id,
            NULL as price,
            NULL as brand,
            CASE RANDOM() % 5 
                WHEN 0 THEN 'electronics'
                WHEN 1 THEN 'clothing'
                WHEN 2 THEN 'sports'
                WHEN 3 THEN 'home'
                WHEN 4 THEN 'books'
            END as category_code
        FROM TABLE(GENERATOR(ROWCOUNT => 70))
        """

    # Combine all event types into a single staging table
    @aql.transform(conn_id=SNOWFLAKE_CONN_ID)
    def combine_events():
        return """
        INSERT INTO ANALYTICS.STG_EVENTS_COMBINED (user_id, event_time, event_type, product_id, price, brand, category_code)
        SELECT 
            CAST(user_id AS STRING) AS user_id,
            CAST(event_time AS TIMESTAMP) AS event_time,
            CAST(event_type AS STRING) AS event_type,
            CAST(product_id AS STRING) AS product_id,
            CAST(price AS DOUBLE) AS price,
            CAST(brand AS STRING) AS brand,
            CAST(category_code AS STRING) AS category_code
        FROM ANALYTICS.STG_EVENTS_CART
        UNION ALL
        SELECT 
            CAST(user_id AS STRING),
            CAST(event_time AS TIMESTAMP),
            CAST(event_type AS STRING),
            CAST(product_id AS STRING),
            CAST(price AS DOUBLE),
            CAST(brand AS STRING),
            CAST(category_code AS STRING)
        FROM ANALYTICS.STG_EVENTS_PURCHASE
        UNION ALL
        SELECT 
            CAST(user_id AS STRING),
            CAST(event_time AS TIMESTAMP),
            CAST(event_type AS STRING),
            CAST(product_id AS STRING),
            CAST(price AS DOUBLE),
            CAST(brand AS STRING),
            CAST(category_code AS STRING)
        FROM ANALYTICS.STG_EVENTS_VIEW
        """

    # Create customer 360 profile
    @aql.transform(conn_id=SNOWFLAKE_CONN_ID)
    def create_customer_360():
        return """
        CREATE OR REPLACE TABLE ANALYTICS.CUSTOMER_360_PROFILE AS
        SELECT 
            user_id as USER_ID,
            MAX(CASE WHEN event_type = 'purchase' AND brand IS NOT NULL 
                THEN brand END) as FAVORITE_BRAND,
            MAX(CASE WHEN event_type = 'view' AND category_code IS NOT NULL 
                THEN category_code END) as MOST_VIEWED_CATEGORY,
            COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) as TOTAL_PURCHASES,
            SUM(CASE WHEN event_type = 'purchase' THEN CAST(price AS DOUBLE) ELSE 0 END) as TOTAL_SPEND,
            MAX(CAST(event_time AS TIMESTAMP)) as LAST_SEEN_DATE
        FROM ANALYTICS.STG_EVENTS_COMBINED
        WHERE user_id IS NOT NULL
        GROUP BY user_id
        """

    # Execute the transformations
    create_tables = create_staging_tables()
    cart_data = create_demo_cart_data()
    purchase_data = create_demo_purchase_data()
    view_data = create_demo_view_data()
    combined_events = combine_events()
    customer_360 = create_customer_360()

    # Set dependencies
    create_tables >> cart_data >> purchase_data >> view_data >> combined_events >> customer_360

ecommerce_daily_etl_sdk_fixed() 