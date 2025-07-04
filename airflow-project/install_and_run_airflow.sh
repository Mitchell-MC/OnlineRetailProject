#!/bin/bash
set -e

# ==============================================================================
# Complete Airflow Installation and Setup Script
# ==============================================================================
# This script installs Docker, sets up Airflow, and starts the services
# Run this script on your EC2 instance to get Airflow running

echo "🚀 Complete Airflow Installation and Setup"
echo "=========================================="

# ==============================================================================
# Configuration Variables
# ==============================================================================
PROJECT_DIR="/home/ubuntu/OnlineRetailProject"
AIRFLOW_PROJECT_DIR="$PROJECT_DIR/airflow-project"

# ==============================================================================
# Step 1: Install and Configure Docker
# ==============================================================================
echo ""
echo "🐳 Step 1: Installing and configuring Docker..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "📦 Docker not found. Installing Docker..."
    
    # Update package list
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list again
    sudo apt-get update
    
    # Install Docker
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker is already installed"
fi

# Start Docker service
echo "🔧 Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group if not already added
if ! groups $USER | grep -q docker; then
    echo "👤 Adding user to docker group..."
    sudo usermod -aG docker $USER
    echo "⚠️  Please log out and log back in for group changes to take effect, or run: newgrp docker"
fi

# Verify Docker is running
echo "🔍 Verifying Docker is running..."
if ! sudo docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running properly"
    echo "Please check Docker installation and try again"
    exit 1
fi

echo "✅ Docker is running properly"

# ==============================================================================
# Step 2: Set Up Airflow Environment
# ==============================================================================
echo ""
echo "🌍 Step 2: Setting up Airflow environment..."

# Check if we're in the right directory
if [ ! -f "$AIRFLOW_PROJECT_DIR/docker-compose.yaml" ]; then
    echo "❌ Error: docker-compose.yaml not found in $AIRFLOW_PROJECT_DIR"
    echo "Please ensure you're in the correct directory"
    exit 1
fi

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

echo "✅ airflow.env file created"

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
    echo "✅ .env file created"
else
    echo "✅ .env file already exists"
fi

# ==============================================================================
# Step 3: Set Up Directory Structure
# ==============================================================================
echo ""
echo "📁 Step 3: Setting up directory structure..."

# Create necessary directories
mkdir -p "$AIRFLOW_PROJECT_DIR/dags"
mkdir -p "$AIRFLOW_PROJECT_DIR/plugins"
mkdir -p "$AIRFLOW_PROJECT_DIR/logs"
mkdir -p "$AIRFLOW_PROJECT_DIR/jobs"
mkdir -p "$AIRFLOW_PROJECT_DIR/connections"
mkdir -p "$AIRFLOW_PROJECT_DIR/variables"

# Create __init__.py files
touch "$AIRFLOW_PROJECT_DIR/dags/__init__.py"
touch "$AIRFLOW_PROJECT_DIR/plugins/__init__.py"

# Set proper permissions for Docker
echo "🔐 Setting Docker permissions..."
sudo chown -R 50000:0 "$AIRFLOW_PROJECT_DIR/logs"
sudo chown -R 50000:0 "$AIRFLOW_PROJECT_DIR/plugins"
sudo chown -R 50000:0 "$AIRFLOW_PROJECT_DIR/dags"

echo "✅ Directory structure created"

# ==============================================================================
# Step 4: Start Airflow Services
# ==============================================================================
echo ""
echo "🐳 Step 4: Starting Airflow services..."

# Change to Airflow project directory
cd "$AIRFLOW_PROJECT_DIR"

# Stop any existing containers first
echo "🛑 Stopping any existing containers..."
sudo docker compose down

# Start Docker services
echo "🚀 Starting Airflow containers..."
sudo docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 45

# Check if services are running
if sudo docker compose ps | grep -q "Up"; then
    echo "✅ Airflow services started successfully!"
    echo ""
    echo "🌐 Access Points:"
    echo "   Airflow UI: http://localhost:8080"
    echo "   Spark Master UI: http://localhost:9090"
    echo ""
    echo "🔑 Default credentials: airflow/airflow"
    echo ""
    echo "📊 Check service status with: ./status_airflow.sh"
    echo "📋 View logs with: ./view_logs.sh"
else
    echo "❌ Some services failed to start."
    echo "📋 Check logs with: ./view_logs.sh"
    echo "🔍 Check status with: ./status_airflow.sh"
    exit 1
fi

# ==============================================================================
# Final Instructions
# ==============================================================================
echo ""
echo "==============================================================================="
echo "🎉 Airflow Installation and Setup Complete!"
echo "==============================================================================="
echo ""
echo "📋 What was installed and configured:"
echo "   ✅ Docker Engine and Docker Compose"
echo "   ✅ Airflow environment variables"
echo "   ✅ Directory structure and permissions"
echo "   ✅ Airflow services (Web UI, Scheduler, Worker)"
echo "   ✅ PostgreSQL database"
echo "   ✅ Redis for task queue"
echo ""
echo "🔧 Useful Commands:"
echo "   Start services:  ./start_airflow.sh"
echo "   Stop services:   ./stop_airflow.sh"
echo "   Restart:         ./restart_airflow.sh"
echo "   View logs:       ./view_logs.sh"
echo "   Check status:    ./status_airflow.sh"
echo ""
echo "📚 Next Steps:"
echo "   1. Upload your DAGs to: $AIRFLOW_PROJECT_DIR/dags/"
echo "   2. Configure connections in Airflow UI"
echo "   3. Monitor your data pipelines"
echo ""
echo "===============================================================================" 