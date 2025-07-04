#!/bin/bash
set -e

echo "🐳 Setting up Docker environment for Airflow..."

# Navigate to the airflow-project directory
cd /home/ubuntu/OnlineRetailProject/airflow-project

# Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    echo "Starting Docker..."
    sudo systemctl start docker
fi

# Verify Docker permissions for ubuntu user
if ! groups ubuntu | grep -q docker; then
    echo "Adding ubuntu user to docker group..."
    sudo usermod -a -G docker ubuntu
    echo "Please log out and log back in for group changes to take effect, or run: newgrp docker"
fi

# Create necessary directories with proper permissions
echo "Creating Airflow directories..."
mkdir -p dags logs plugins jobs
sudo chown -R 50000:0 dags logs plugins jobs

# Set up environment files if they don't exist
if [ ! -f "airflow.env" ]; then
    echo "Creating airflow.env file..."
    cat > airflow.env << 'AIRFLOW_ENV'
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
fi

# Create start/stop scripts
echo "Creating Airflow management scripts..."

# Start script
cat > start_airflow.sh << 'START_SCRIPT'
#!/bin/bash
echo "🚀 Starting Airflow services..."

cd "."
sudo docker compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 30

if sudo docker compose ps | grep -q "Up"; then
    echo "✅ Airflow services started successfully!"
    echo "🌐 Airflow UI: http://localhost:8080"
    echo "📊 Spark Master UI: http://localhost:9090"
    echo "🔑 Default credentials: airflow/airflow"
else
    echo "❌ Some services failed to start. Check logs with: sudo docker compose logs"
fi
START_SCRIPT

# Stop script
cat > stop_airflow.sh << 'STOP_SCRIPT'
#!/bin/bash
echo "🛑 Stopping Airflow services..."

cd "."
sudo docker compose down

echo "✅ Airflow services stopped"
STOP_SCRIPT

# Restart script
cat > restart_airflow.sh << 'RESTART_SCRIPT'
#!/bin/bash
echo "🔄 Restarting Airflow services..."

cd "."
./stop_airflow.sh
sleep 5
./start_airflow.sh
RESTART_SCRIPT

# Logs script
cat > view_logs.sh << 'LOGS_SCRIPT'
#!/bin/bash
echo "📋 Viewing Airflow logs..."

cd "."
sudo docker compose logs -f
LOGS_SCRIPT

# Make scripts executable
chmod +x start_airflow.sh stop_airflow.sh restart_airflow.sh view_logs.sh

echo "✅ Docker setup complete!"
echo ""
echo "🚀 To start Airflow, run:"
echo "   cd /home/ubuntu/OnlineRetailProject/airflow-project"
echo "   ./start_airflow.sh"
echo ""
echo "📋 Available commands:"
echo "   ./start_airflow.sh   - Start all services"
echo "   ./stop_airflow.sh    - Stop all services"
echo "   ./restart_airflow.sh - Restart all services"
echo "   ./view_logs.sh       - View service logs"
echo "   sudo docker compose ps - Check service status"
