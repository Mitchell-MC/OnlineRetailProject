#!/bin/bash
set -e

# ==============================================================================
# Airflow Setup Script for S3 → Snowflake DAGs
# ==============================================================================
# This script sets up Apache Airflow on your EC2 instance for running
# S3 to Snowflake data pipeline DAGs
# Run this script on your EC2 instance after SSH'ing into it

echo "🚀 Starting Airflow setup for S3 → Snowflake DAGs..."

# ==============================================================================
# Configuration Variables
# ==============================================================================
PROJECT_DIR="/home/ubuntu/OnlineRetailProject"
AIRFLOW_PROJECT_DIR="$PROJECT_DIR/airflow-project"
AIRFLOW_HOME="$AIRFLOW_PROJECT_DIR"
AIRFLOW_USER="airflow"
AIRFLOW_PASSWORD="airflow"
AIRFLOW_EMAIL="admin@example.com"

# ==============================================================================
# Verify Prerequisites
# ==============================================================================
echo "🔍 Checking prerequisites..."

# Check if we're in the right directory
if [ ! -f "$AIRFLOW_PROJECT_DIR/docker-compose.yaml" ]; then
    echo "❌ Error: docker-compose.yaml not found in $AIRFLOW_PROJECT_DIR"
    echo "Please run this script from the airflow-project directory"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker first:"
    echo "sudo systemctl start docker"
    exit 1
fi

echo "✅ Prerequisites check passed"

# ==============================================================================
# Set Up Environment Variables
# ==============================================================================
echo "🌍 Setting up environment variables..."

# Create airflow.env file for Docker Compose
echo "Creating airflow.env file..."
cat > "$AIRFLOW_PROJECT_DIR/airflow.env" << 'AIRFLOW_ENV'
# Core Airflow Configuration
AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres/airflow
AIRFLOW__CORE__EXECUTOR=LocalExecutor
AIRFLOW__CORE__FERNET_KEY=OnfNZiO4pfvIuVIt4EMMGx_bJasFN53hlZMBKYi-PgU=
AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True
AIRFLOW__CORE__LOAD_EXAMPLES=False

# Java Configuration (required for Spark)
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Astro SDK Connection for Snowflake
AIRFLOW_CONN_SNOWFLAKE_DEFAULT='{
    "conn_type": "snowflake",
    "login": "MITCHELLMCC",
    "password": "jme9EPKxPwm8ewX",
    "schema": "ANALYTICS",
    "extra": {
        "account": "KLRPPBG-NEC57960",
        "database": "ECOMMERCE_DB",
        "warehouse": "COMPUTE_WH"
    }
}'

# AWS Connection (for S3 access)
AIRFLOW_CONN_AWS_DEFAULT='{
    "conn_type": "aws",
    "login": "AKIAYVHNVD2T6SVKVBFZ",
    "password": "vjPrHEPgrjuUIYX1BYP0kL+uTTIKjP8P+R80xBF",
    "extra": {
        "region_name": "us-east-1"
    }
}'

# Set the user and group for files created in mounted volumes
AIRFLOW_UID=50000
AIRFLOW_GID=0
AIRFLOW_ENV

echo "✅ airflow.env file created with pre-configured connections"

# Create .env file for additional environment variables
if [ ! -f "$AIRFLOW_PROJECT_DIR/.env" ]; then
    echo "Creating .env file..."
    cat > "$AIRFLOW_PROJECT_DIR/.env" << 'ENV_FILE'
# Additional Environment Variables
AWS_ACCESS_KEY_ID=AKIAYVHNVD2T6SVKVBFZ
AWS_SECRET_ACCESS_KEY=vjPrHEPgrjuUIYX1BYP0kL+uTTIKjP8P+R80xBF
AWS_DEFAULT_REGION=us-east-1

# Snowflake Configuration
SNOWFLAKE_ACCOUNT=KLRPPBG-NEC57960
SNOWFLAKE_USER=MITCHELLMCC
SNOWFLAKE_PASSWORD=jme9EPKxPwm8ewX
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_DATABASE=ECOMMERCE_DB
SNOWFLAKE_SCHEMA=ANALYTICS

# S3 Configuration
S3_BUCKET_NAME=kafka-cust-transactions
S3_DATA_PATH=raw/user_events/event_type=*/

# Spark Configuration
SPARK_MASTER_URL=spark://localhost:7077
SPARK_DRIVER_MEMORY=1g
SPARK_EXECUTOR_MEMORY=1g

# Logging Configuration
LOG_LEVEL=INFO
ENV_FILE
    echo "✅ .env file created with actual credentials."
else
    echo "✅ .env file already exists"
fi

# ==============================================================================
# Set Up Airflow Connections
# ==============================================================================
echo "🔗 Setting up Airflow connections..."

# Create connections directory
mkdir -p "$AIRFLOW_PROJECT_DIR/connections"

# Create AWS connection configuration
cat > "$AIRFLOW_PROJECT_DIR/connections/aws_default.json" << 'AWS_CONN'
{
    "conn_type": "aws",
    "description": "AWS Default Connection",
    "host": "",
    "schema": "",
    "login": "",
    "password": "",
    "port": null,
    "extra": {
        "region_name": "us-east-1",
        "aws_access_key_id": "${AWS_ACCESS_KEY_ID}",
        "aws_secret_access_key": "${AWS_SECRET_ACCESS_KEY}"
    }
}
AWS_CONN

# Create Snowflake connection configuration
cat > "$AIRFLOW_PROJECT_DIR/connections/snowflake_default.json" << 'SNOWFLAKE_CONN'
{
    "conn_type": "snowflake",
    "description": "Snowflake Default Connection",
    "host": "${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com",
    "schema": "${SNOWFLAKE_SCHEMA}",
    "login": "${SNOWFLAKE_USER}",
    "password": "${SNOWFLAKE_PASSWORD}",
    "port": 443,
    "extra": {
        "account": "${SNOWFLAKE_ACCOUNT}",
        "warehouse": "${SNOWFLAKE_WAREHOUSE}",
        "database": "${SNOWFLAKE_DATABASE}",
        "region": "us-east-1"
    }
}
SNOWFLAKE_CONN

# Create S3 connection configuration
cat > "$AIRFLOW_PROJECT_DIR/connections/s3_default.json" << 'S3_CONN'
{
    "conn_type": "s3",
    "description": "S3 Default Connection",
    "host": "",
    "schema": "",
    "login": "${AWS_ACCESS_KEY_ID}",
    "password": "${AWS_SECRET_ACCESS_KEY}",
    "port": null,
    "extra": {
        "aws_access_key_id": "${AWS_ACCESS_KEY_ID}",
        "aws_secret_access_key": "${AWS_SECRET_ACCESS_KEY}",
        "region_name": "us-east-1"
    }
}
S3_CONN

echo "✅ Airflow connections configured"

# ==============================================================================
# Set Up Airflow Variables
# ==============================================================================
echo "📊 Setting up Airflow variables..."

# Create variables directory
mkdir -p "$AIRFLOW_PROJECT_DIR/variables"

# Create S3 configuration variables
cat > "$AIRFLOW_PROJECT_DIR/variables/s3_config.json" << 'S3_VARS'
{
    "s3_bucket_name": "${S3_BUCKET_NAME}",
    "s3_data_path": "${S3_DATA_PATH}",
    "s3_region": "us-east-1"
}
S3_VARS

# Create Snowflake configuration variables
cat > "$AIRFLOW_PROJECT_DIR/variables/snowflake_config.json" << 'SNOWFLAKE_VARS'
{
    "snowflake_account": "${SNOWFLAKE_ACCOUNT}",
    "snowflake_warehouse": "${SNOWFLAKE_WAREHOUSE}",
    "snowflake_database": "${SNOWFLAKE_DATABASE}",
    "snowflake_schema": "${SNOWFLAKE_SCHEMA}",
    "snowflake_region": "us-east-1"
}
SNOWFLAKE_VARS

# Create Spark configuration variables
cat > "$AIRFLOW_PROJECT_DIR/variables/spark_config.json" << 'SPARK_VARS'
{
    "spark_master_url": "${SPARK_MASTER_URL}",
    "spark_driver_memory": "${SPARK_DRIVER_MEMORY}",
    "spark_executor_memory": "${SPARK_EXECUTOR_MEMORY}",
    "spark_app_name": "EcommerceETL"
}
SPARK_VARS

echo "✅ Airflow variables configured"

# ==============================================================================
# Set Up DAGs Directory Structure
# ==============================================================================
echo "📁 Setting up DAGs directory structure..."

# Create DAGs directory if it doesn't exist
mkdir -p "$AIRFLOW_PROJECT_DIR/dags"

# Create __init__.py file for DAGs package
if [ ! -f "$AIRFLOW_PROJECT_DIR/dags/__init__.py" ]; then
    touch "$AIRFLOW_PROJECT_DIR/dags/__init__.py"
fi

# Create plugins directory if it doesn't exist
mkdir -p "$AIRFLOW_PROJECT_DIR/plugins"

# Create __init__.py file for plugins package
if [ ! -f "$AIRFLOW_PROJECT_DIR/plugins/__init__.py" ]; then
    touch "$AIRFLOW_PROJECT_DIR/plugins/__init__.py"
fi

# Create include directory if it doesn't exist
mkdir -p "$AIRFLOW_PROJECT_DIR/include"

# Create logs directory if it doesn't exist
mkdir -p "$AIRFLOW_PROJECT_DIR/logs"

echo "✅ Directory structure created"

# ==============================================================================
# Set Up Docker Compose Services
# ==============================================================================
echo "🐳 Setting up Docker Compose services..."

# Check if docker-compose.yaml exists
if [ ! -f "$AIRFLOW_PROJECT_DIR/docker-compose.yaml" ]; then
    echo "❌ Error: docker-compose.yaml not found in $AIRFLOW_PROJECT_DIR"
    echo "Please ensure the docker-compose.yaml file exists"
    exit 1
fi

# Create necessary directories for Docker volumes
mkdir -p "$AIRFLOW_PROJECT_DIR/logs"
mkdir -p "$AIRFLOW_PROJECT_DIR/plugins"
mkdir -p "$AIRFLOW_PROJECT_DIR/jobs"

# Set proper permissions for Docker
echo "🔐 Setting Docker permissions..."
sudo chown -R 50000:0 "$AIRFLOW_PROJECT_DIR/logs"
sudo chown -R 50000:0 "$AIRFLOW_PROJECT_DIR/plugins"
sudo chown -R 50000:0 "$AIRFLOW_PROJECT_DIR/dags"

echo "✅ Docker Compose setup ready"

# ==============================================================================
# Set Up Airflow Configuration
# ==============================================================================
echo "⚙️ Airflow configuration will be handled by Docker Compose"
echo "✅ Configuration setup complete"

# ==============================================================================
# Systemd Services (Not needed with Docker Compose)
# ==============================================================================
echo "🔧 Docker Compose handles service management - no systemd services needed"
echo "✅ Service management setup complete"

# ==============================================================================
# Create Start/Stop Scripts
# ==============================================================================
echo "📜 Creating start/stop scripts..."

# Create start script
cat > "$AIRFLOW_PROJECT_DIR/start_airflow.sh" << 'START_SCRIPT'
#!/bin/bash
echo "🚀 Starting Airflow services..."

# Start Docker services
cd "$(dirname "$0")"
sudo docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check if services are running
if sudo docker compose ps | grep -q "Up"; then
    echo "✅ Airflow services started successfully!"
    echo "🌐 Airflow UI: http://localhost:8080"
    echo "📊 Spark Master UI: http://localhost:9090"
    echo "🔑 Default credentials: airflow/airflow"
else
    echo "❌ Some services failed to start. Check logs with: sudo docker compose logs"
fi
START_SCRIPT

# Create stop script
cat > "$AIRFLOW_PROJECT_DIR/stop_airflow.sh" << 'STOP_SCRIPT'
#!/bin/bash
echo "🛑 Stopping Airflow services..."

cd "$(dirname "$0")"
sudo docker compose down

echo "✅ Airflow services stopped"
STOP_SCRIPT

# Create restart script
cat > "$AIRFLOW_PROJECT_DIR/restart_airflow.sh" << 'RESTART_SCRIPT'
#!/bin/bash
echo "🔄 Restarting Airflow services..."

cd "$(dirname "$0")"
./stop_airflow.sh
sleep 5
./start_airflow.sh
RESTART_SCRIPT

# Create logs script
cat > "$AIRFLOW_PROJECT_DIR/view_logs.sh" << 'LOGS_SCRIPT'
#!/bin/bash
echo "📋 Viewing Airflow logs..."

cd "$(dirname "$0")"
sudo docker compose logs -f
LOGS_SCRIPT

# Make scripts executable
chmod +x "$AIRFLOW_PROJECT_DIR/start_airflow.sh"
chmod +x "$AIRFLOW_PROJECT_DIR/stop_airflow.sh"
chmod +x "$AIRFLOW_PROJECT_DIR/restart_airflow.sh"
chmod +x "$AIRFLOW_PROJECT_DIR/view_logs.sh"

echo "✅ Start/stop scripts created"

# ==============================================================================
# Set Proper Permissions
# ==============================================================================
echo "🔐 Setting proper permissions..."

# Set ownership of all project files to ubuntu user
sudo chown -R ubuntu:ubuntu "$PROJECT_DIR"

# Set proper permissions for Airflow directories
chmod -R 755 "$AIRFLOW_PROJECT_DIR/dags"
chmod -R 755 "$AIRFLOW_PROJECT_DIR/plugins"
chmod -R 755 "$AIRFLOW_PROJECT_DIR/logs"

echo "✅ Permissions set"

# ==============================================================================
# Final Setup Instructions
# ==============================================================================
echo ""
echo "==============================================================================="
echo "🎉 Airflow Setup Complete!"
echo "==============================================================================="
echo ""
echo "📋 What was configured:"
echo "   ✅ Environment variables (airflow.env and .env files)"
echo "   ✅ Airflow connections (AWS, Snowflake, S3) - pre-configured"
echo "   ✅ Airflow variables (S3, Snowflake, Spark config)"
echo "   ✅ Directory structure (dags, plugins, logs, jobs)"
echo "   ✅ Docker Compose setup"
echo "   ✅ Start/stop scripts"
echo ""
echo "🚀 NEXT STEPS:"
echo "   1. Start Airflow services:"
echo "      cd $AIRFLOW_PROJECT_DIR"
echo "      ./start_airflow.sh"
echo ""
echo "   2. Wait for services to be ready (about 2-3 minutes)"
echo ""
echo "   3. Access Airflow UI:"
echo "      http://localhost:8080"
echo "      Username: airflow"
echo "      Password: airflow"
echo ""
echo "   4. Upload your S3 → Snowflake DAGs to:"
echo "      $AIRFLOW_PROJECT_DIR/dags/"
echo ""
echo "🔧 Useful Commands:"
echo "   Start services: ./start_airflow.sh"
echo "   Stop services:  ./stop_airflow.sh"
echo "   Restart:        ./restart_airflow.sh"
echo "   View logs:      ./view_logs.sh"
echo "   Check status:   sudo docker compose ps"
echo ""
echo "📚 Documentation:"
echo "   - Airflow docs: https://airflow.apache.org/docs/"
echo "   - S3 operator: https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/operators/s3.html"
echo "   - Snowflake operator: https://airflow.apache.org/docs/apache-airflow-providers-snowflake/stable/operators/index.html"
echo ""
echo "===============================================================================" 