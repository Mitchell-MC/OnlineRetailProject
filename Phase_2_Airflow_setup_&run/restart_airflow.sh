#!/bin/bash
echo "🔄 Restarting Airflow services..."

cd "$(dirname "$0")"
./stop_airflow.sh
sleep 5
./start_airflow.sh
