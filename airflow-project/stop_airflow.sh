#!/bin/bash
echo "🛑 Stopping Airflow services..."
sudo systemctl stop airflow-webserver
sudo systemctl stop airflow-scheduler
echo "✅ Airflow services stopped"
