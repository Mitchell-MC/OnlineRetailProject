#!/bin/bash
echo "📋 Viewing Airflow logs..."

cd "$(dirname "$0")"
sudo docker compose logs -f
