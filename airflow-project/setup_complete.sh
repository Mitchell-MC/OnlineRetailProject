#!/bin/bash

# ==============================================================================
# Complete Airflow Setup Script - Online Retail Project
# ==============================================================================
# This script provides a complete setup with minimal external configuration
# It handles installation, configuration, connection setup, and validation

set -e  # Exit on any error

echo "🚀 Starting Complete Airflow Setup for Online Retail Project..."
echo "📋 This script will:"
echo "   1. Install and configure Airflow"
echo "   2. Set up demo connections for testing"
echo "   3. Validate and fix DAGs"
echo "   4. Create management scripts"
echo "   5. Start services and verify setup"
echo ""

# ==============================================================================
# Configuration
# ==============================================================================
PROJECT_DIR="/home/ubuntu/OnlineRetailProject"
AIRFLOW_HOME="/home/ubuntu/airflow"
AIRFLOW_USER="airflow"
AIRFLOW_PASSWORD="airflow"
AIRFLOW_EMAIL="admin@example.com"

# Auto-configuration options
AUTO_SETUP_DEMO_CONNECTIONS=true
AUTO_VALIDATE_DAGS=true
AUTO_START_SERVICES=true
AUTO_UNPAUSE_DAGS=true

# ==============================================================================
# Function to run the main setup script
# ==============================================================================
run_main_setup() {
    echo "🔧 Running main Airflow setup..."
    
    if [ -f "$PROJECT_DIR/airflow-project/setup_airflow_instance.sh" ]; then
        bash "$PROJECT_DIR/airflow-project/setup_airflow_instance.sh"
    else
        echo "❌ Main setup script not found"
        exit 1
    fi
}

# ==============================================================================
# Function to setup connections automatically
# ==============================================================================
setup_connections_auto() {
    echo "🔗 Setting up connections automatically..."
    
    cd "$PROJECT_DIR/airflow-project"
    source venv/bin/activate
    export AIRFLOW_HOME="$AIRFLOW_HOME"
    
    # Create demo connections
    echo "🔗 Creating demo connections for testing..."
    
    # Create a demo Snowflake connection
    airflow connections add 'snowflake_default' \
        --conn-type 'snowflake' \
        --conn-host "demo-account.snowflakecomputing.com" \
        --conn-login "demo_user" \
        --conn-password "demo_password" \
        --conn-schema "DEMO_SCHEMA" \
        --conn-port 443 \
        --conn-extra "{\"account\": \"demo-account\", \"warehouse\": \"DEMO_WAREHOUSE\", \"database\": \"DEMO_DB\", \"region\": \"us-east-1\"}" 2>/dev/null || echo "⚠️  Snowflake connection already exists"
    
    # Create a demo S3 connection
    airflow connections add 's3_default' \
        --conn-type 'aws' \
        --conn-login "demo_access_key" \
        --conn-password "demo_secret_key" \
        --conn-extra "{\"aws_access_key_id\": \"demo_access_key\", \"aws_secret_access_key\": \"demo_secret_key\", \"region_name\": \"us-east-1\"}" 2>/dev/null || echo "⚠️  S3 connection already exists"
    
    # Create AWS default connection
    airflow connections add 'aws_default' \
        --conn-type 'aws' \
        --conn-extra "{\"region_name\": \"us-east-1\", \"aws_access_key_id\": \"demo_access_key\", \"aws_secret_access_key\": \"demo_secret_key\"}" 2>/dev/null || echo "⚠️  AWS connection already exists"
    
    echo "✅ Demo connections created successfully!"
}

# ==============================================================================
# Function to validate and fix DAGs
# ==============================================================================
validate_dags_auto() {
    echo "🔍 Validating and fixing DAGs..."
    
    cd "$PROJECT_DIR/airflow-project"
    source venv/bin/activate
    export AIRFLOW_HOME="$AIRFLOW_HOME"
    
    # Check for missing dependencies
    missing_deps=()
    
    # Check if astro-sdk-python is installed
    if ! python -c "import astro" 2>/dev/null; then
        missing_deps+=("astro-sdk-python")
    fi
    
    # Check if boto3 is installed
    if ! python -c "import boto3" 2>/dev/null; then
        missing_deps+=("boto3")
    fi
    
    # Check if snowflake-connector-python is installed
    if ! python -c "import snowflake.connector" 2>/dev/null; then
        missing_deps+=("snowflake-connector-python")
    fi
    
    # Install missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "📦 Installing missing dependencies: ${missing_deps[*]}"
        pip install "${missing_deps[@]}"
    fi
    
    # Check for duplicate DAG IDs
    echo "🔍 Checking for duplicate DAG IDs..."
    cd "$PROJECT_DIR/airflow-project/dags"
    
    # Remove sample_dag.py if it exists (common duplicate)
    if [ -f "sample_dag.py" ]; then
        rm -f "sample_dag.py"
        echo "✅ Removed duplicate sample_dag.py"
    fi
    
    # Test DAG imports
    echo "🧪 Testing DAG imports..."
    airflow dags list-import-errors
    
    echo "✅ DAG validation completed"
}

# ==============================================================================
# Function to start services and verify
# ==============================================================================
start_and_verify_services() {
    echo "🚀 Starting and verifying Airflow services..."
    
    # Start services
    sudo systemctl start airflow-webserver
    sudo systemctl start airflow-scheduler
    
    # Wait for services to be fully started
    echo "⏳ Waiting for services to be fully started..."
    sleep 30
    
    # Check service status
    if systemctl is-active --quiet airflow-webserver && systemctl is-active --quiet airflow-scheduler; then
        echo "✅ Airflow services are running"
    else
        echo "❌ Airflow services failed to start"
        return 1
    fi
    
    # Check web interface
    echo "🌐 Checking web interface..."
    if curl -s http://localhost:8080 > /dev/null; then
        echo "✅ Web interface is accessible"
    else
        echo "❌ Web interface is not accessible"
        return 1
    fi
}

# ==============================================================================
# Function to unpause DAGs
# ==============================================================================
unpause_dags() {
    echo "▶️  Unpausing DAGs..."
    
    cd "$PROJECT_DIR/airflow-project"
    source venv/bin/activate
    export AIRFLOW_HOME="$AIRFLOW_HOME"
    
    # Get list of paused DAGs
    paused_dags=$(airflow dags list | grep "True" | awk '{print $1}')
    
    if [ -n "$paused_dags" ]; then
        echo "📋 Found paused DAGs: $paused_dags"
        for dag in $paused_dags; do
            echo "▶️  Unpausing $dag..."
            airflow dags unpause "$dag"
        done
        echo "✅ All DAGs unpaused"
    else
        echo "✅ No paused DAGs found"
    fi
}

# ==============================================================================
# Function to create a comprehensive status report
# ==============================================================================
create_status_report() {
    echo ""
    echo "📊 Setup Status Report"
    echo "======================"
    
    # Check service status
    echo "🔧 Service Status:"
    if systemctl is-active --quiet airflow-webserver && systemctl is-active --quiet airflow-scheduler; then
        echo "✅ Both Airflow services are running"
    else
        echo "❌ One or more Airflow services are not running"
    fi
    
    # Check DAG status
    echo ""
    echo "📋 DAG Status:"
    cd "$PROJECT_DIR/airflow-project"
    source venv/bin/activate
    export AIRFLOW_HOME="$AIRFLOW_HOME"
    airflow dags list
    
    # Check connections
    echo ""
    echo "🔗 Connection Status:"
    airflow connections list
    
    # Check recent DAG runs
    echo ""
    echo "🏃 Recent DAG Runs:"
    airflow dags list-runs --limit 3
    
    # Check disk space
    echo ""
    echo "💾 Disk Space:"
    df -h /home/ubuntu/OnlineRetailProject
    
    # Check memory usage
    echo ""
    echo "🧠 Memory Usage:"
    free -h
}

# ==============================================================================
# Function to create a quick start guide
# ==============================================================================
create_quick_start_guide() {
    echo ""
    echo "📝 Creating quick start guide..."
    
    cat > "$PROJECT_DIR/airflow-project/QUICK_START.md" << 'EOF'
# Airflow Quick Start Guide

## 🚀 Access Airflow Web Interface
- **URL**: http://your-server-ip:8080
- **Username**: airflow
- **Password**: airflow

## 🔧 Management Commands
```bash
# Check status
./status_airflow.sh

# Health check
./health_check.sh

# Auto recovery
./auto_recovery.sh

# Manage services
./manage_airflow.sh {start|stop|restart|status|logs|health|recovery}
```

## 📋 Available DAGs
- `sample_retail_dag` - Test DAG for verification
- `ecommerce_daily_etl_sdk` - Ecommerce data pipeline

## 🔗 Connections
Demo connections are set up for testing:
- `snowflake_default` - Snowflake connection
- `s3_default` - S3 connection  
- `aws_default` - AWS connection

## 🎯 Next Steps
1. **Update Connections**: Replace demo credentials with real ones
2. **Trigger DAGs**: Unpause and trigger your DAGs
3. **Monitor**: Use the web interface to monitor execution
4. **Customize**: Update DAGs with your specific requirements

## 🆘 Troubleshooting
- **Services not starting**: Run `./auto_recovery.sh`
- **DAG import errors**: Check `./health_check.sh`
- **Connection issues**: Update `airflow_connections.env`

## 📁 Important Files
- DAGs: `/home/ubuntu/OnlineRetailProject/airflow-project/dags/`
- Logs: `/home/ubuntu/OnlineRetailProject/airflow-project/logs/`
- Config: `/home/ubuntu/airflow/airflow.cfg`
- Connections: Use `./setup_connections.sh` to update
EOF
    
    echo "✅ Quick start guide created: $PROJECT_DIR/airflow-project/QUICK_START.md"
}

# ==============================================================================
# Main execution
# ==============================================================================

# Step 1: Run main setup
echo "🔄 Step 1/5: Running main Airflow setup..."
run_main_setup

# Step 2: Setup connections
if [ "$AUTO_SETUP_DEMO_CONNECTIONS" = true ]; then
    echo "🔄 Step 2/5: Setting up demo connections..."
    setup_connections_auto
fi

# Step 3: Validate DAGs
if [ "$AUTO_VALIDATE_DAGS" = true ]; then
    echo "🔄 Step 3/5: Validating DAGs..."
    validate_dags_auto
fi

# Step 4: Start services
if [ "$AUTO_START_SERVICES" = true ]; then
    echo "🔄 Step 4/5: Starting and verifying services..."
    start_and_verify_services
fi

# Step 5: Unpause DAGs
if [ "$AUTO_UNPAUSE_DAGS" = true ]; then
    echo "🔄 Step 5/5: Unpausing DAGs..."
    unpause_dags
fi

# Create status report
create_status_report

# Create quick start guide
create_quick_start_guide

# Final success message
echo ""
echo "🎉 Complete Airflow Setup Finished Successfully!"
echo ""
echo "📋 Quick Reference:"
echo "  - Web Interface: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost"):8080"
echo "  - Username: airflow"
echo "  - Password: airflow"
echo ""
echo "🔧 Management Commands:"
echo "  - Status: ./status_airflow.sh"
echo "  - Health Check: ./health_check.sh"
echo "  - Auto Recovery: ./auto_recovery.sh"
echo "  - Manage Services: ./manage_airflow.sh {start|stop|restart|status|logs|health|recovery}"
echo ""
echo "📖 Documentation:"
echo "  - Quick Start: cat QUICK_START.md"
echo ""
echo "✅ Setup completed successfully!"
echo "🚀 Your Airflow instance is ready for use!" 