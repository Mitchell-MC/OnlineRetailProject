#!/bin/bash

echo "🚀 Starting Airflow services..."

# Start the services
sudo systemctl start airflow-webserver
sudo systemctl start airflow-scheduler

# Wait a moment for services to start
sleep 3

# Check if services started successfully
if sudo systemctl is-active --quiet airflow-webserver && sudo systemctl is-active --quiet airflow-scheduler; then
    echo "✅ Airflow services started successfully!"
    
    # Get the public IP address
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    
    echo ""
    echo "🌐 Airflow Web UI Information:"
    echo "================================"
    echo "🔗 URL: http://${PUBLIC_IP}:8080"
    echo "👤 Username: airflow"
    echo "🔑 Password: airflow"
    echo ""
    echo "📊 Service Status:"
    echo "- Webserver: $(sudo systemctl is-active airflow-webserver)"
    echo "- Scheduler: $(sudo systemctl is-active airflow-scheduler)"
    echo ""
    echo "📋 To check logs:"
    echo "- Webserver logs: sudo journalctl -u airflow-webserver -f"
    echo "- Scheduler logs: sudo journalctl -u airflow-scheduler -f"
    
else
    echo "❌ Failed to start one or more Airflow services"
    echo "📊 Current status:"
    echo "- Webserver: $(sudo systemctl is-active airflow-webserver)"
    echo "- Scheduler: $(sudo systemctl is-active airflow-scheduler)"
    echo ""
    echo "🔍 Check logs for details:"
    echo "- sudo journalctl -u airflow-webserver"
    echo "- sudo journalctl -u airflow-scheduler"
fi 