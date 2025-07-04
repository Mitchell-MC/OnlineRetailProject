#!/bin/bash
set -e

echo "🛑 Stopping Airflow services..."

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    exit 1
fi

# Check if docker-compose.yaml exists
if [ ! -f "docker-compose.yaml" ]; then
    echo "❌ Error: docker-compose.yaml not found"
    echo "Please ensure you're in the airflow-project directory"
    exit 1
fi

# Stop Docker services
echo "🐳 Stopping Airflow containers..."
sudo docker compose down

echo "✅ Airflow services stopped"

# Optional: Remove containers and volumes (uncomment if needed)
# echo "🧹 Cleaning up containers and volumes..."
# sudo docker compose down -v --remove-orphans
# echo "✅ Cleanup complete"
