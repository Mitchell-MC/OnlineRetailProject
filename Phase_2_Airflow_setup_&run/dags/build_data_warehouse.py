"""
# build_data_warehouse.py
An Airflow DAG to build the final reporting tables for the ecommerce data warehouse.

This DAG orchestrates the creation of the final aggregated tables and views
in the ANALYTICS schema, making them ready for BI tools and operational exports.
"""

import pendulum
from airflow.decorators import dag
from astro import sql as aql
from astro.sql import Table

SNOWFLAKE_CONN_ID = "snowflake_default"
ANALYTICS_SCHEMA = "ANALYTICS"

@dag(
    dag_id="ecommerce_build_data_warehouse",
    start_date=pendulum.datetime(2025, 7, 17, tz="UTC"),
    schedule=None,  # This DAG is meant for manual runs
    catchup=False,
    tags=["ecommerce", "reporting", "warehouse"],
    doc_md=__doc__
)
def build_data_warehouse_dag():
    """
    ### Ecommerce Data Warehouse Build

    This DAG runs the final SQL transformations to build the core reporting
    tables for the ecommerce platform. It assumes that the staging tables
    (STG_EVENTS_*) and the CUSTOMER_360_PROFILE table already exist and
    are populated in the ANALYTICS schema.

    **Sequence of Operations:**
    1.  **Combine Staging Tables**: Merges cart, purchase, and view events into a single, consistently-typed table (`STG_EVENTS_COMBINED`).
    2.  **Create Analytical Views**: Builds several views (`VW_*`) for slicing and dicing the data.
    3.  **Generate User Segments**: Creates the final `USER_SEGMENTS` table based on customer spending habits.
    4.  **Generate Product Recommendations**: Creates the final `USER_PRODUCT_RECOMMENDATIONS` table.
    """

    @aql.transform(conn_id=SNOWFLAKE_CONN_ID)
    def create_combined_events_table():
        """
        Combines raw event data from the various staging tables into a single,
        unified and cleaned table for easier analytics.
        """
        return """
        CREATE OR REPLACE TABLE STG_EVENTS_COMBINED AS
        SELECT 
            CAST(USER_ID AS VARCHAR) AS USER_ID,
            CAST(EVENT_TIME AS TIMESTAMP) AS EVENT_TIME,
            CAST(EVENT_TYPE AS VARCHAR) AS EVENT_TYPE,
            CAST(PRODUCT_ID AS VARCHAR) AS PRODUCT_ID,
            CAST(PRICE AS FLOAT) AS PRICE,
            CAST(BRAND AS VARCHAR) AS BRAND,
            CAST(CATEGORY_CODE AS VARCHAR) AS CATEGORY_CODE
        FROM STG_EVENTS_CART
        UNION ALL
        SELECT 
            CAST(USER_ID AS VARCHAR),
            CAST(EVENT_TIME AS TIMESTAMP),
            CAST(EVENT_TYPE AS VARCHAR),
            CAST(PRODUCT_ID AS VARCHAR),
            CAST(PRICE AS FLOAT),
            CAST(BRAND AS VARCHAR),
            CAST(CATEGORY_CODE AS VARCHAR)
        FROM STG_EVENTS_PURCHASE
        UNION ALL
        SELECT 
            CAST(USER_ID AS VARCHAR),
            CAST(EVENT_TIME AS TIMESTAMP),
            CAST(EVENT_TYPE AS VARCHAR),
            CAST(PRODUCT_ID AS VARCHAR),
            CAST(PRICE AS FLOAT),
            CAST(BRAND AS VARCHAR),
            CAST(CATEGORY_CODE AS VARCHAR)
        FROM STG_EVENTS_VIEW;
        """

    @aql.transform(conn_id=SNOWFLAKE_CONN_ID)
    def create_analytical_views(combined_events_table: Table):
        """
        Creates a set of analytical views on top of the combined events table
        to power BI dashboards and ad-hoc queries.
        """
        return """
        -- View 1: Product Popularity
        CREATE OR REPLACE VIEW VW_PRODUCT_POPULARITY AS
        SELECT 
            PRODUCT_ID,
            CATEGORY_CODE,
            COUNT(*) AS PURCHASE_COUNT,
            AVG(PRICE) AS AVG_PRICE,
            SUM(PRICE) AS TOTAL_REVENUE,
            COUNT(DISTINCT USER_ID) AS UNIQUE_BUYERS
        FROM {{combined_events_table}}
        WHERE EVENT_TYPE = 'purchase' 
            AND CATEGORY_CODE IS NOT NULL
            AND PRODUCT_ID IS NOT NULL
        GROUP BY PRODUCT_ID, CATEGORY_CODE;

        -- View 2: User Behavior
        CREATE OR REPLACE VIEW VW_USER_BEHAVIOR AS
        SELECT 
            USER_ID,
            COUNT(*) AS TOTAL_EVENTS,
            COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) AS PURCHASE_COUNT,
            SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) AS TOTAL_SPEND,
            MIN(EVENT_TIME) AS FIRST_SEEN,
            MAX(EVENT_TIME) AS LAST_SEEN,
            DATEDIFF('day', MIN(EVENT_TIME), MAX(EVENT_TIME)) AS DAYS_ACTIVE
        FROM {{combined_events_table}}
        WHERE USER_ID IS NOT NULL
        GROUP BY USER_ID;
        """

    @aql.run_raw_sql(conn_id=SNOWFLAKE_CONN_ID)
    def create_reporting_tables(combined_events_table: Table):
        """
        Creates the final, aggregated reporting tables for user segments
        and product recommendations. These are the primary outputs of the warehouse.
        """
        return """
        -- Table 1: User Segments
        CREATE OR REPLACE TABLE USER_SEGMENTS AS
        SELECT 
            USER_ID,
            TOTAL_SPEND,
            TOTAL_PURCHASES,
            FAVORITE_BRAND,
            MOST_VIEWED_CATEGORY,
            LAST_SEEN_DATE,
            CASE 
                WHEN TOTAL_SPEND >= 1000 THEN 'VIP'
                WHEN TOTAL_SPEND >= 500 THEN 'Premium'
                WHEN TOTAL_SPEND >= 100 THEN 'Regular'
                ELSE 'New'
            END AS SEGMENT
        FROM CUSTOMER_360_PROFILE;

        -- Table 2: Product Recommendations
        CREATE OR REPLACE TABLE USER_PRODUCT_RECOMMENDATIONS AS
        WITH ProductPurchases AS (
            SELECT 
                PRODUCT_ID, 
                CATEGORY_CODE,
                COUNT(*) AS PURCHASE_COUNT
            FROM {{combined_events_table}}
            WHERE EVENT_TYPE = 'purchase'
              AND CATEGORY_CODE IS NOT NULL
              AND PRODUCT_ID IS NOT NULL
            GROUP BY PRODUCT_ID, CATEGORY_CODE
        ),
        TopProducts AS (
            SELECT
                CATEGORY_CODE,
                PRODUCT_ID,
                ROW_NUMBER() OVER (PARTITION BY CATEGORY_CODE ORDER BY PURCHASE_COUNT DESC) AS RN
            FROM ProductPurchases
        ),
        CategoryRecs AS (
            SELECT
                CATEGORY_CODE,
                ARRAY_AGG(PRODUCT_ID) WITHIN GROUP (ORDER BY RN) AS RECOMMENDED_PRODUCTS
            FROM TopProducts
            WHERE RN <= 5 -- Top 5 products
            GROUP BY CATEGORY_CODE
        )
        SELECT
            prof.USER_ID,
            recs.RECOMMENDED_PRODUCTS,
            'Top products in favorite category' AS RECOMMENDATION_REASON,
            CURRENT_TIMESTAMP() AS RECOMMENDATION_DATE
        FROM CUSTOMER_360_PROFILE prof
        JOIN CategoryRecs recs
          ON prof.MOST_VIEWED_CATEGORY = recs.CATEGORY_CODE;
        """

    # Define the data flow
    combined_events = create_combined_events_table()
    views = create_analytical_views(combined_events_table)
    reporting_tables = create_reporting_tables(combined_events_table)

    # Set dependencies
    combined_events >> views
    combined_events >> reporting_tables

build_data_warehouse_dag() 