#!/bin/bash

echo "🛑 Stopping Airflow services..."

# Stop the services
sudo systemctl stop airflow-webserver
sudo systemctl stop airflow-scheduler

# Wait a moment for services to stop
sleep 2

# Check if services stopped successfully
if ! sudo systemctl is-active --quiet airflow-webserver && ! sudo systemctl is-active --quiet airflow-scheduler; then
    echo "✅ Airflow services stopped successfully!"
else
    echo "⚠️  Some services may still be running:"
    echo "- Webserver: $(sudo systemctl is-active airflow-webserver)"
    echo "- Scheduler: $(sudo systemctl is-active airflow-scheduler)"
fi

echo ""
echo "📊 Final status:"
echo "- Webserver: $(sudo systemctl is-active airflow-webserver)"
echo "- Scheduler: $(sudo systemctl is-active airflow-scheduler)" 