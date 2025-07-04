#!/bin/bash
set -e

echo "🚀 Starting Airflow services..."

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    echo "Please run ./setup_airflow.sh first to install Docker"
    exit 1
fi

# Ensure Docker is running
if ! sudo systemctl is-active --quiet docker; then
    echo "🐳 Starting Docker service..."
    sudo systemctl start docker
    sleep 5
fi

# Verify Docker is working
if ! sudo docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running properly"
    echo "Please check Docker installation and try again"
    exit 1
fi

echo "✅ Docker is running properly"

# Check if docker-compose.yaml exists
if [ ! -f "docker-compose.yaml" ]; then
    echo "❌ Error: docker-compose.yaml not found"
    echo "Please ensure you're in the airflow-project directory"
    exit 1
fi

# Stop any existing containers first
echo "🛑 Stopping any existing containers..."
sudo docker compose down

# Start Docker services
echo "🐳 Starting Airflow containers..."
sudo docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

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
