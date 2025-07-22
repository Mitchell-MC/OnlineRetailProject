# dags/ecommerce_phase3_pipeline.py

import pendulum
from airflow.decorators import dag
from astro import sql as aql
from astro.sql import Table
from airflow.operators.python import PythonOperator
import snowflake.connector
from airflow.hooks.base import BaseHook

SNOWFLAKE_CONN_ID = "snowflake_default"

# Define table references for ANALYTICS schema
ANALYTICS_CART = Table(name="STG_EVENTS_CART", conn_id=SNOWFLAKE_CONN_ID)
ANALYTICS_PURCHASE = Table(name="STG_EVENTS_PURCHASE", conn_id=SNOWFLAKE_CONN_ID)
ANALYTICS_VIEW = Table(name="STG_EVENTS_VIEW", conn_id=SNOWFLAKE_CONN_ID)
ANALYTICS_COMBINED = Table(name="STG_EVENTS_COMBINED", conn_id=SNOWFLAKE_CONN_ID)
ANALYTICS_CUSTOMER_360 = Table(name="CUSTOMER_360_PROFILE", conn_id=SNOWFLAKE_CONN_ID)
ANALYTICS_RECOMMENDATIONS = Table(name="USER_PRODUCT_RECOMMENDATIONS", conn_id=SNOWFLAKE_CONN_ID)
ANALYTICS_DAILY_METRICS = Table(name="DAILY_METRICS", conn_id=SNOWFLAKE_CONN_ID)

def migrate_from_tmp_astro(**context):
    """Migrate data from TMP_ASTRO to ANALYTICS schema"""
    print("🔄 Starting migration from TMP_ASTRO to ANALYTICS...")
    
    try:
        # Get Snowflake connection
        conn = BaseHook.get_connection(SNOWFLAKE_CONN_ID)
        sf_conn = snowflake.connector.connect(
            user=conn.login,
            password=conn.password,
            account=conn.extra_dejson.get('account'),
            warehouse=conn.extra_dejson.get('warehouse'),
            database=conn.extra_dejson.get('database'),
            schema=conn.extra_dejson.get('schema', 'ANALYTICS')
        )
        
        cursor = sf_conn.cursor()
        
        # Check if data exists in TMP_ASTRO
        cursor.execute("SELECT COUNT(*) FROM TMP_ASTRO.STG_EVENTS_CART")
        cart_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM TMP_ASTRO.STG_EVENTS_PURCHASE")
        purchase_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM TMP_ASTRO.STG_EVENTS_VIEW")
        view_count = cursor.fetchone()[0]
        
        print(f"📊 Found in TMP_ASTRO: Cart={cart_count}, Purchase={purchase_count}, View={view_count}")
        
        if cart_count > 0 or purchase_count > 0 or view_count > 0:
            # Migrate cart events
            cursor.execute("""
                INSERT INTO STG_EVENTS_CART
                SELECT USER_ID, EVENT_TIME, EVENT_TYPE, PRODUCT_ID, PRICE, BRAND, CATEGORY_CODE
                FROM TMP_ASTRO.STG_EVENTS_CART
                WHERE USER_ID IS NOT NULL
            """)
            
            # Migrate purchase events
            cursor.execute("""
                INSERT INTO STG_EVENTS_PURCHASE
                SELECT USER_ID, EVENT_TIME, EVENT_TYPE, PRODUCT_ID, PRICE, BRAND, CATEGORY_CODE
                FROM TMP_ASTRO.STG_EVENTS_PURCHASE
                WHERE USER_ID IS NOT NULL
            """)
            
            # Migrate view events
            cursor.execute("""
                INSERT INTO STG_EVENTS_VIEW
                SELECT USER_ID, EVENT_TIME, EVENT_TYPE, PRODUCT_ID, PRICE, BRAND, CATEGORY_CODE
                FROM TMP_ASTRO.STG_EVENTS_VIEW
                WHERE USER_ID IS NOT NULL
            """)
            
            print("✅ Data migrated successfully from TMP_ASTRO to ANALYTICS")
        else:
            print("⚠️  No data found in TMP_ASTRO, skipping migration")
        
        sf_conn.commit()
        sf_conn.close()
        
    except Exception as e:
        print(f"❌ Error during migration: {e}")
        raise

def create_combined_events_table(**context):
    """Create the combined events table in ANALYTICS schema"""
    print("🔗 Creating combined events table...")
    
    try:
        conn = BaseHook.get_connection(SNOWFLAKE_CONN_ID)
        sf_conn = snowflake.connector.connect(
            user=conn.login,
            password=conn.password,
            account=conn.extra_dejson.get('account'),
            warehouse=conn.extra_dejson.get('warehouse'),
            database=conn.extra_dejson.get('database'),
            schema=conn.extra_dejson.get('schema', 'ANALYTICS')
        )
        
        cursor = sf_conn.cursor()
        
        # Create combined events table
        cursor.execute("""
            CREATE OR REPLACE TABLE STG_EVENTS_COMBINED AS
            SELECT 
                CAST(USER_ID AS STRING) AS USER_ID,
                CAST(EVENT_TIME AS TIMESTAMP) AS EVENT_TIME,
                CAST(EVENT_TYPE AS STRING) AS EVENT_TYPE,
                CAST(PRODUCT_ID AS STRING) AS PRODUCT_ID,
                CAST(PRICE AS DOUBLE) AS PRICE,
                CAST(BRAND AS STRING) AS BRAND,
                CAST(CATEGORY_CODE AS STRING) AS CATEGORY_CODE
            FROM STG_EVENTS_CART
            UNION ALL
            SELECT 
                CAST(USER_ID AS STRING),
                CAST(EVENT_TIME AS TIMESTAMP),
                CAST(EVENT_TYPE AS STRING),
                CAST(PRODUCT_ID AS STRING),
                CAST(PRICE AS DOUBLE),
                CAST(BRAND AS STRING),
                CAST(CATEGORY_CODE AS STRING)
            FROM STG_EVENTS_PURCHASE
            UNION ALL
            SELECT 
                CAST(USER_ID AS STRING),
                CAST(EVENT_TIME AS TIMESTAMP),
                CAST(EVENT_TYPE AS STRING),
                CAST(PRODUCT_ID AS STRING),
                CAST(PRICE AS DOUBLE),
                CAST(BRAND AS STRING),
                CAST(CATEGORY_CODE AS STRING)
            FROM STG_EVENTS_VIEW
        """)
        
        # Get row count
        cursor.execute("SELECT COUNT(*) FROM STG_EVENTS_COMBINED")
        row_count = cursor.fetchone()[0]
        print(f"✅ Combined events table created with {row_count} rows")
        
        sf_conn.commit()
        sf_conn.close()
        
    except Exception as e:
        print(f"❌ Error creating combined events table: {e}")
        raise

def create_analytical_views(**context):
    """Create analytical views for business intelligence"""
    print("👁️  Creating analytical views...")
    
    try:
        conn = BaseHook.get_connection(SNOWFLAKE_CONN_ID)
        sf_conn = snowflake.connector.connect(
            user=conn.login,
            password=conn.password,
            account=conn.extra_dejson.get('account'),
            warehouse=conn.extra_dejson.get('warehouse'),
            database=conn.extra_dejson.get('database'),
            schema=conn.extra_dejson.get('schema', 'ANALYTICS')
        )
        
        cursor = sf_conn.cursor()
        
        # Create product popularity view
        cursor.execute("""
            CREATE OR REPLACE VIEW VW_PRODUCT_POPULARITY AS
            SELECT 
                PRODUCT_ID,
                CATEGORY_CODE,
                COUNT(*) as PURCHASE_COUNT,
                AVG(PRICE) as AVG_PRICE,
                SUM(PRICE) as TOTAL_REVENUE
            FROM STG_EVENTS_COMBINED
            WHERE EVENT_TYPE = 'purchase' 
                AND CATEGORY_CODE IS NOT NULL
                AND PRODUCT_ID IS NOT NULL
            GROUP BY PRODUCT_ID, CATEGORY_CODE
            ORDER BY PURCHASE_COUNT DESC
        """)
        
        # Create user behavior view
        cursor.execute("""
            CREATE OR REPLACE VIEW VW_USER_BEHAVIOR AS
            SELECT 
                USER_ID,
                COUNT(*) as TOTAL_EVENTS,
                COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) as PURCHASE_COUNT,
                COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) as VIEW_COUNT,
                COUNT(CASE WHEN EVENT_TYPE = 'cart' THEN 1 END) as CART_COUNT,
                SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) as TOTAL_SPEND,
                AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) as AVG_PURCHASE_VALUE,
                MIN(EVENT_TIME) as FIRST_SEEN,
                MAX(EVENT_TIME) as LAST_SEEN
            FROM STG_EVENTS_COMBINED
            WHERE USER_ID IS NOT NULL
            GROUP BY USER_ID
        """)
        
        # Create category performance view
        cursor.execute("""
            CREATE OR REPLACE VIEW VW_CATEGORY_PERFORMANCE AS
            SELECT 
                CATEGORY_CODE,
                COUNT(*) as TOTAL_EVENTS,
                COUNT(CASE WHEN EVENT_TYPE = 'purchase' THEN 1 END) as PURCHASE_COUNT,
                COUNT(CASE WHEN EVENT_TYPE = 'view' THEN 1 END) as VIEW_COUNT,
                SUM(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE ELSE 0 END) as TOTAL_REVENUE,
                AVG(CASE WHEN EVENT_TYPE = 'purchase' THEN PRICE END) as AVG_PURCHASE_VALUE
            FROM STG_EVENTS_COMBINED
            WHERE CATEGORY_CODE IS NOT NULL
            GROUP BY CATEGORY_CODE
            ORDER BY TOTAL_REVENUE DESC
        """)
        
        print("✅ Analytical views created successfully")
        
        sf_conn.commit()
        sf_conn.close()
        
    except Exception as e:
        print(f"❌ Error creating analytical views: {e}")
        raise

def generate_product_recommendations(**context):
    """Generate product recommendations for users"""
    print("🎯 Generating product recommendations...")
    
    try:
        conn = BaseHook.get_connection(SNOWFLAKE_CONN_ID)
        sf_conn = snowflake.connector.connect(
            user=conn.login,
            password=conn.password,
            account=conn.extra_dejson.get('account'),
            warehouse=conn.extra_dejson.get('warehouse'),
            database=conn.extra_dejson.get('database'),
            schema=conn.extra_dejson.get('schema', 'ANALYTICS')
        )
        
        cursor = sf_conn.cursor()
        
        # Create recommendations table if not exists
        cursor.execute("""
            CREATE OR REPLACE TABLE USER_PRODUCT_RECOMMENDATIONS (
                USER_ID NUMBER(38,0) NOT NULL,
                RECOMMENDED_PRODUCTS ARRAY,
                RECOMMENDATION_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
                PRIMARY KEY (USER_ID)
            )
        """)
        
        # Generate recommendations
        cursor.execute("""
            INSERT OVERWRITE INTO USER_PRODUCT_RECOMMENDATIONS
            WITH
            ProductPurchases AS (
                SELECT PRODUCT_ID, CATEGORY_CODE
                FROM STG_EVENTS_COMBINED
                WHERE EVENT_TYPE = 'purchase'
                  AND CATEGORY_CODE IS NOT NULL
                  AND PRODUCT_ID IS NOT NULL
            ),
            TopProductsPerCategory AS (
                SELECT
                    CATEGORY_CODE,
                    PRODUCT_ID,
                    COUNT(*) as purchase_count,
                    ROW_NUMBER() OVER (PARTITION BY CATEGORY_CODE ORDER BY purchase_count DESC) as rnk
                FROM ProductPurchases
                GROUP BY 1, 2
                QUALIFY rnk <= 5
            ),
            CategoryRecommendations AS (
                SELECT
                    CATEGORY_CODE,
                    ARRAY_AGG(PRODUCT_ID) WITHIN GROUP (ORDER BY rnk) as recommended_products
                FROM TopProductsPerCategory
                GROUP BY 1
            )
            SELECT
                CAST(prof.USER_ID AS NUMBER(38,0)) as USER_ID,
                rec.recommended_products
            FROM CUSTOMER_360_PROFILE prof
            JOIN CategoryRecommendations rec
              ON prof.MOST_VIEWED_CATEGORY = rec.CATEGORY_CODE
            WHERE prof.MOST_VIEWED_CATEGORY IS NOT NULL
        """)
        
        # Get recommendation count
        cursor.execute("SELECT COUNT(*) FROM USER_PRODUCT_RECOMMENDATIONS")
        rec_count = cursor.fetchone()[0]
        print(f"✅ Generated {rec_count} product recommendations")
        
        sf_conn.commit()
        sf_conn.close()
        
    except Exception as e:
        print(f"❌ Error generating recommendations: {e}")
        raise

def create_operational_tables(**context):
    """Create operational dashboard tables"""
    print("📊 Creating operational dashboard tables...")
    
    try:
        conn = BaseHook.get_connection(SNOWFLAKE_CONN_ID)
        sf_conn = snowflake.connector.connect(
            user=conn.login,
            password=conn.password,
            account=conn.extra_dejson.get('account'),
            warehouse=conn.extra_dejson.get('warehouse'),
            database=conn.extra_dejson.get('database'),
            schema=conn.extra_dejson.get('schema', 'ANALYTICS')
        )
        
        cursor = sf_conn.cursor()
        
        # Create daily metrics table
        cursor.execute("""
            CREATE OR REPLACE TABLE DAILY_METRICS (
                METRIC_DATE DATE NOT NULL,
                TOTAL_USERS NUMBER(38,0),
                TOTAL_PURCHASES NUMBER(38,0),
                TOTAL_REVENUE FLOAT,
                AVG_ORDER_VALUE FLOAT,
                CONVERSION_RATE FLOAT,
                PRIMARY KEY (METRIC_DATE)
            )
        """)
        
        # Create product catalog table
        cursor.execute("""
            CREATE OR REPLACE TABLE PRODUCT_CATALOG (
                PRODUCT_ID VARCHAR(16777216) NOT NULL,
                PRODUCT_NAME VARCHAR(16777216),
                CATEGORY_CODE VARCHAR(16777216),
                BRAND VARCHAR(16777216),
                PRICE NUMBER(10,2),
                IS_ACTIVE BOOLEAN DEFAULT TRUE,
                CREATED_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
                PRIMARY KEY (PRODUCT_ID)
            )
        """)
        
        print("✅ Operational tables created successfully")
        
        sf_conn.commit()
        sf_conn.close()
        
    except Exception as e:
        print(f"❌ Error creating operational tables: {e}")
        raise

def verify_pipeline_completion(**context):
    """Verify that the Phase 3 pipeline completed successfully"""
    print("✅ Verifying Phase 3 pipeline completion...")
    
    try:
        conn = BaseHook.get_connection(SNOWFLAKE_CONN_ID)
        sf_conn = snowflake.connector.connect(
            user=conn.login,
            password=conn.password,
            account=conn.extra_dejson.get('account'),
            warehouse=conn.extra_dejson.get('warehouse'),
            database=conn.extra_dejson.get('database'),
            schema=conn.extra_dejson.get('schema', 'ANALYTICS')
        )
        
        cursor = sf_conn.cursor()
        
        # Check table row counts
        tables_to_check = [
            "STG_EVENTS_COMBINED",
            "CUSTOMER_360_PROFILE", 
            "USER_PRODUCT_RECOMMENDATIONS"
        ]
        
        print("📊 Final data counts:")
        for table in tables_to_check:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            count = cursor.fetchone()[0]
            print(f"  - {table}: {count:,} rows")
        
        # Check views
        cursor.execute("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'ANALYTICS'")
        views = cursor.fetchall()
        print(f"👁️  Created {len(views)} analytical views")
        
        sf_conn.close()
        print("🎉 Phase 3 pipeline completed successfully!")
        
    except Exception as e:
        print(f"❌ Error during verification: {e}")
        raise

@dag(
    start_date=pendulum.datetime(2025, 6, 21, tz="UTC"),
    schedule="0 2 * * *",  # Run daily at 2 AM, after the main ETL
    catchup=False,
    tags=["ecommerce", "phase3", "datawarehouse", "analytics"],
)
def ecommerce_phase3_pipeline():
    """
    Phase 3 Data Pipeline: Build complete data warehouse in ANALYTICS schema
    This DAG runs after the main ETL pipeline to:
    1. Migrate data from TMP_ASTRO to ANALYTICS
    2. Create combined events table
    3. Build analytical views
    4. Generate product recommendations
    5. Create operational dashboard tables
    """
    
    # Task 1: Migrate data from TMP_ASTRO to ANALYTICS
    migrate_task = PythonOperator(
        task_id='migrate_from_tmp_astro',
        python_callable=migrate_from_tmp_astro,
        dag=ecommerce_phase3_pipeline
    )
    
    # Task 2: Create combined events table
    combine_task = PythonOperator(
        task_id='create_combined_events',
        python_callable=create_combined_events_table,
        dag=ecommerce_phase3_pipeline
    )
    
    # Task 3: Create analytical views
    views_task = PythonOperator(
        task_id='create_analytical_views',
        python_callable=create_analytical_views,
        dag=ecommerce_phase3_pipeline
    )
    
    # Task 4: Generate product recommendations
    recommendations_task = PythonOperator(
        task_id='generate_recommendations',
        python_callable=generate_product_recommendations,
        dag=ecommerce_phase3_pipeline
    )
    
    # Task 5: Create operational tables
    operational_task = PythonOperator(
        task_id='create_operational_tables',
        python_callable=create_operational_tables,
        dag=ecommerce_phase3_pipeline
    )
    
    # Task 6: Verify completion
    verify_task = PythonOperator(
        task_id='verify_pipeline_completion',
        python_callable=verify_pipeline_completion,
        dag=ecommerce_phase3_pipeline
    )
    
    # Set task dependencies
    migrate_task >> combine_task >> views_task >> recommendations_task >> operational_task >> verify_task

ecommerce_phase3_pipeline() 