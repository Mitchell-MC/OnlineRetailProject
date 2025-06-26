#!/bin/bash
set -e

# ==============================================================================
# Airflow Startup Script
# ==============================================================================
echo "Starting Airflow setup process..."

# --- 1. Navigate to Project Directory ---
echo "Navigating to project directory..."
cd ~/OnlineRetailProject/airflow-project

# --- 2. Check if Docker is Running ---
echo "Checking Docker status..."
if ! snap services docker | grep -q "active"; then
    echo "Docker is not running. Starting Docker..."
    sudo snap start docker
fi

# --- 3. Ensure User is in Docker Group ---
echo "Ensuring user is in docker group..."
if ! groups | grep -q docker; then
    echo "Adding user to docker group..."
    sudo usermod -aG docker $USER
    echo "Please log out and log back in for group changes to take effect."
    echo "Then run this script again."
    exit 1
fi

# --- 4. Check for Environment File ---
if [ ! -f "airflow.env" ]; then
    echo "❌ ERROR: airflow.env file not found!"
    echo "Please create the airflow.env file with your configuration."
    exit 1
fi

# --- 5. Stop Any Existing Containers ---
echo "Stopping any existing containers..."
docker compose down 2>/dev/null || true

# --- 6. Start Airflow Services ---
echo "Starting Airflow services..."
docker compose up -d

# --- 7. Wait for Services to Start ---
echo "Waiting for services to start..."
sleep 30

# --- 8. Check Service Status ---
echo "Checking service status..."
docker ps

# --- 9. Display Access Information ---
echo "------------------------------------------------------------------"
echo "✅ Airflow is starting up!"
echo
echo "   Airflow UI: http://100.27.202.165:8080"
echo "   Spark Master UI: http://100.27.202.165:9090"
echo
echo "   Default credentials:"
echo "   Username: airflow"
echo "   Password: airflow"
echo
echo "   To check logs: docker compose logs -f"
echo "   To stop services: docker compose down"
echo "------------------------------------------------------------------"

# --- 10. Show Recent Logs ---
echo "Recent Airflow logs:"
docker compose logs --tail=20 airflow-webserver
