#!/bin/bash
echo "🛑 Stopping Airflow services..."

cd "$(dirname "$0")"
sudo docker compose down

echo "✅ Airflow services stopped"
