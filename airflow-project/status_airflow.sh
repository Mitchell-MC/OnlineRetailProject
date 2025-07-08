#!/bin/bash

echo "📊 Airflow Service Status"
echo "=========================="

# Check service status
WEBSERVER_STATUS=$(sudo systemctl is-active airflow-webserver)
SCHEDULER_STATUS=$(sudo systemctl is-active airflow-scheduler)

echo "🌐 Webserver: $WEBSERVER_STATUS"
echo "⏰ Scheduler: $SCHEDULER_STATUS"

echo ""
echo "🔧 Detailed Status:"
echo "==================="

# Webserver status
echo "📋 Webserver Service:"
sudo systemctl status airflow-webserver --no-pager -l | head -10

echo ""
echo "📋 Scheduler Service:"
sudo systemctl status airflow-scheduler --no-pager -l | head -10

# If services are running, show access info
if [ "$WEBSERVER_STATUS" = "active" ]; then
    echo ""
    echo "🌐 Access Information:"
    echo "====================="
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo "🔗 Web UI: http://${PUBLIC_IP}:8080"
    echo "👤 Username: airflow"
    echo "🔑 Password: airflow"
fi

echo ""
echo "📋 Quick Commands:"
echo "=================="
echo "🚀 Start: ./start_airflow.sh"
echo "🛑 Stop: ./stop_airflow.sh"
echo "📊 Status: ./status_airflow.sh"
echo "📜 Logs: sudo journalctl -u airflow-webserver -f"
echo "📜 Scheduler Logs: sudo journalctl -u airflow-scheduler -f"
