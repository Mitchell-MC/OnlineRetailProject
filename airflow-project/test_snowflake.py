import snowflake.connector
from airflow.hooks.base import BaseHook

# Get connection details
conn = BaseHook.get_connection('snowflake_default')
print(f'Connecting to Snowflake...')

try:
    sf_conn = snowflake.connector.connect(
        user=conn.login,
        password=conn.password,
        account=conn.extra_dejson.get('account'),
        warehouse=conn.extra_dejson.get('warehouse'),
        database=conn.extra_dejson.get('database'),
        schema=conn.extra_dejson.get('schema', 'ANALYTICS')
    )
    print('✅ Successfully connected to Snowflake!')
    
    # List available warehouses with more details
    cursor = sf_conn.cursor()
    cursor.execute('SHOW WAREHOUSES')
    warehouses = cursor.fetchall()
    print('\n🏭 Available warehouses:')
    for wh in warehouses:
        print(f'  - Name: {wh[1]}, State: {wh[2]}, Type: {wh[3]}')
    
    # Check current schema
    cursor.execute('SELECT CURRENT_SCHEMA()')
    current_schema = cursor.fetchone()[0]
    print(f'\n📋 Current schema: {current_schema}')
    
    # List schemas in ECOMMERCE_DB
    cursor.execute('SHOW SCHEMAS IN ECOMMERCE_DB')
    schemas = cursor.fetchall()
    print('\n📚 Available schemas in ECOMMERCE_DB:')
    for schema in schemas:
        print(f'  - {schema[1]}')
    
    sf_conn.close()
    
except Exception as e:
    print(f'❌ Error connecting to Snowflake: {e}') 