#!/bin/bash
echo "🚀 Starting Airflow services..."
sudo systemctl start airflow-webserver
sudo systemctl start airflow-scheduler
echo "✅ Airflow services started"
echo "🌐 Web UI available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "👤 Username: airflow"
echo "🔑 Password: airflow"
