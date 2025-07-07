#!/bin/bash
echo "📊 Airflow Service Status:"
echo "=========================="
sudo systemctl status airflow-webserver --no-pager -l
echo ""
echo "=========================="
sudo systemctl status airflow-scheduler --no-pager -l
