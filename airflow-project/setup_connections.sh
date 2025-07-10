#!/bin/bash

echo "🔗 Setting up Airflow connections..."

# Get the project directory
PROJECT_DIR="/home/ubuntu/OnlineRetailProject"

# Source environment variables
if [ -f "$PROJECT_DIR/airflow-project/airflow_connections.env" ]; then
    source "$PROJECT_DIR/airflow-project/airflow_connections.env"
    echo "✅ Loaded connection environment variables"
else
    echo "❌ airflow_connections.env not found. Please create it with your credentials."
    exit 1
fi

# Activate virtual environment
cd "$PROJECT_DIR/airflow-project"
source venv/bin/activate

# Set Airflow home
export AIRFLOW_HOME="/home/ubuntu/airflow"

echo "❄️  Creating Snowflake connection..."
airflow connections add 'snowflake_default' \
    --conn-type 'snowflake' \
    --conn-host "${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com" \
    --conn-login "${SNOWFLAKE_USER}" \
    --conn-password "${SNOWFLAKE_PASSWORD}" \
    --conn-schema "${SNOWFLAKE_SCHEMA}" \
    --conn-port 443 \
    --conn-extra "{\"account\": \"${SNOWFLAKE_ACCOUNT}\", \"warehouse\": \"${SNOWFLAKE_WAREHOUSE}\", \"database\": \"${SNOWFLAKE_DATABASE}\", \"region\": \"us-east-1\"}" \
    2>/dev/null || echo "⚠️  Snowflake connection may already exist"

echo "☁️  Creating S3 connection..."
airflow connections add 's3_default' \
    --conn-type 's3' \
    --conn-login "${AWS_ACCESS_KEY_ID}" \
    --conn-password "${AWS_SECRET_ACCESS_KEY}" \
    --conn-extra "{\"aws_access_key_id\": \"${AWS_ACCESS_KEY_ID}\", \"aws_secret_access_key\": \"${AWS_SECRET_ACCESS_KEY}\", \"region_name\": \"us-east-1\"}" \
    2>/dev/null || echo "⚠️  S3 connection may already exist"

echo "🔄 Creating AWS connection..."
airflow connections add 'aws_default' \
    --conn-type 'aws' \
    --conn-extra "{\"region_name\": \"us-east-1\", \"aws_access_key_id\": \"${AWS_ACCESS_KEY_ID}\", \"aws_secret_access_key\": \"${AWS_SECRET_ACCESS_KEY}\"}" \
    2>/dev/null || echo "⚠️  AWS connection may already exist"

echo ""
echo "✅ Connection setup completed!"
echo ""
echo "📋 Available connections:"
airflow connections list | grep -E "(snowflake_default|s3_default|aws_default)" || echo "Checking all connections..."
airflow connections list

echo ""
echo "🎉 Airflow connections are ready for use!"
echo "🌐 Access the web UI to verify: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
