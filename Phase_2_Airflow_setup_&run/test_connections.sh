#!/bin/bash

echo "🔗 Testing Airflow Connections..."

# Source environment variables
if [ -f "airflow_connections.env" ]; then
    source airflow_connections.env
    echo "✅ Loaded connection environment variables"
else
    echo "❌ airflow_connections.env not found"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Set Airflow home
export AIRFLOW_HOME="/home/ubuntu/airflow"

echo "🔧 Setting up connections..."

# Create Snowflake connection
echo "❄️  Creating Snowflake connection..."
airflow connections add 'snowflake_default' \
    --conn-type 'snowflake' \
    --conn-host "${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com" \
    --conn-login "${SNOWFLAKE_USER}" \
    --conn-password "${SNOWFLAKE_PASSWORD}" \
    --conn-schema "${SNOWFLAKE_SCHEMA}" \
    --conn-port 443 \
    --conn-extra "{\"account\": \"${SNOWFLAKE_ACCOUNT}\", \"warehouse\": \"${SNOWFLAKE_WAREHOUSE}\", \"database\": \"${SNOWFLAKE_DATABASE}\", \"region\": \"us-east-1\"}"

# Create S3 connection
echo "☁️  Creating S3 connection..."
airflow connections add 's3_default' \
    --conn-type 's3' \
    --conn-login "${AWS_ACCESS_KEY_ID}" \
    --conn-password "${AWS_SECRET_ACCESS_KEY}" \
    --conn-extra "{\"aws_access_key_id\": \"${AWS_ACCESS_KEY_ID}\", \"aws_secret_access_key\": \"${AWS_SECRET_ACCESS_KEY}\", \"region_name\": \"us-east-1\"}"

# Create AWS connection
echo "🔄 Creating AWS connection..."
airflow connections add 'aws_default' \
    --conn-type 'aws' \
    --conn-extra "{\"region_name\": \"us-east-1\", \"aws_access_key_id\": \"${AWS_ACCESS_KEY_ID}\", \"aws_secret_access_key\": \"${AWS_SECRET_ACCESS_KEY}\"}"

echo "✅ All connections created successfully!"

# List connections
echo "📋 Available connections:"
airflow connections list

echo ""
echo "🧪 Testing connections..."

# Test Snowflake connection
echo "❄️  Testing Snowflake connection..."
python3 -c "
from airflow.hooks.base import BaseHook
import snowflake.connector

try:
    conn = BaseHook.get_connection('snowflake_default')
    print(f'✅ Snowflake connection test:')
    print(f'   Host: {conn.host}')
    print(f'   Login: {conn.login}')
    print(f'   Schema: {conn.schema}')
    print(f'   Extra: {conn.extra}')
    
    # Test actual connection
    snowflake_conn = snowflake.connector.connect(
        user=conn.login,
        password=conn.password,
        account=conn.extra_dejson.get('account'),
        warehouse=conn.extra_dejson.get('warehouse'),
        database=conn.extra_dejson.get('database'),
        schema=conn.schema
    )
    print('✅ Snowflake connection successful!')
    snowflake_conn.close()
except Exception as e:
    print(f'❌ Snowflake connection failed: {e}')
"

# Test AWS connection
echo ""
echo "☁️  Testing AWS connection..."
python3 -c "
from airflow.hooks.base import BaseHook
import boto3

try:
    conn = BaseHook.get_connection('aws_default')
    print(f'✅ AWS connection test:')
    print(f'   Extra: {conn.extra}')
    
    # Test actual connection
    session = boto3.Session(
        aws_access_key_id=conn.extra_dejson.get('aws_access_key_id'),
        aws_secret_access_key=conn.extra_dejson.get('aws_secret_access_key'),
        region_name=conn.extra_dejson.get('region_name')
    )
    s3 = session.client('s3')
    response = s3.list_buckets()
    print('✅ AWS connection successful!')
    print(f'   Found {len(response[\"Buckets\"])} S3 buckets')
except Exception as e:
    print(f'❌ AWS connection failed: {e}')
"

# Test S3 connection
echo ""
echo "📦 Testing S3 connection..."
python3 -c "
from airflow.hooks.base import BaseHook
import boto3

try:
    conn = BaseHook.get_connection('s3_default')
    print(f'✅ S3 connection test:')
    print(f'   Login: {conn.login}')
    print(f'   Extra: {conn.extra}')
    
    # Test actual connection
    session = boto3.Session(
        aws_access_key_id=conn.login,
        aws_secret_access_key=conn.password,
        region_name=conn.extra_dejson.get('region_name')
    )
    s3 = session.client('s3')
    response = s3.list_buckets()
    print('✅ S3 connection successful!')
    print(f'   Found {len(response[\"Buckets\"])} S3 buckets')
except Exception as e:
    print(f'❌ S3 connection failed: {e}')
"

echo ""
echo "🎉 Connection testing completed!"
echo ""
echo "📋 Next steps:"
echo "1. Start Airflow: ./start_airflow.sh"
echo "2. Access Web UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "3. Login with: airflow / airflow"
echo "4. Check connections in Airflow UI under Admin > Connections" 