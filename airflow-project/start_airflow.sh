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
