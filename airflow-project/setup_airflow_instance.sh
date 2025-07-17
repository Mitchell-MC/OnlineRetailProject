#!/bin/bash

# ==============================================================================
# Airflow Instance Setup Script - Online Retail Project
# ==============================================================================
# This script sets up Apache Airflow 2.9.2 on Ubuntu EC2 instance
# Includes Docker, Python environment, and all necessary configurations
# Run this script on your EC2 instance after SSH'ing into it

set -e  # Exit on any error

echo "🚀 Starting Airflow setup for Online Retail Project..."

# ==============================================================================
# Configuration Variables
# ==============================================================================
PROJECT_DIR="/home/ubuntu/OnlineRetailProject"
AIRFLOW_HOME="/home/ubuntu/airflow"
AIRFLOW_USER="airflow"
AIRFLOW_PASSWORD="airflow"
AIRFLOW_EMAIL="admin@example.com"

# Auto-detect environment variables
AUTO_DETECT_CREDENTIALS=true
CREATE_DEMO_CONNECTIONS=true
VALIDATE_DAGS=true
INSTALL_ADDITIONAL_PROVIDERS=true

# ==============================================================================
# Function to auto-detect and create demo connections
# ==============================================================================
create_demo_connections() {
    echo "🔗 Creating demo connections for testing..."
    
    # Create a demo Snowflake connection (for testing)
    airflow connections add 'snowflake_default' \
        --conn-type 'snowflake' \
        --conn-host "demo-account.snowflakecomputing.com" \
        --conn-login "demo_user" \
        --conn-password "demo_password" \
        --conn-schema "DEMO_SCHEMA" \
        --conn-port 443 \
        --conn-extra "{\"account\": \"demo-account\", \"warehouse\": \"DEMO_WAREHOUSE\", \"database\": \"DEMO_DB\", \"region\": \"us-east-1\"}" 2>/dev/null || echo "⚠️  Snowflake connection already exists"
    
    # Create a demo S3 connection (for testing)
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
# Function to validate DAGs and install missing dependencies
# ==============================================================================
validate_and_fix_dags() {
    echo "🔍 Validating DAGs and dependencies..."
    
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
    
    # Find duplicate DAG IDs
    dag_ids=$(grep -r "dag_id.*=" . --include="*.py" | grep -v "__pycache__" | sed "s/.*dag_id.*=.*['\"]\([^'\"]*\)['\"].*/\1/" | sort | uniq -d)
    
    if [ -n "$dag_ids" ]; then
        echo "⚠️  Found duplicate DAG IDs: $dag_ids"
        echo "🧹 Cleaning up duplicate DAG files..."
        
        # Remove sample_dag.py if it exists (common duplicate)
        if [ -f "sample_dag.py" ]; then
            rm -f "sample_dag.py"
            echo "✅ Removed duplicate sample_dag.py"
        fi
    fi
    
    # Test DAG imports
    echo "🧪 Testing DAG imports..."
    airflow dags list-import-errors
    
    echo "✅ DAG validation completed"
}

# ==============================================================================
# Function to auto-configure Airflow settings
# ==============================================================================
auto_configure_airflow() {
    echo "⚙️  Auto-configuring Airflow settings..."
    
    # Create airflow.cfg if it doesn't exist
    if [ ! -f "$AIRFLOW_HOME/airflow.cfg" ]; then
        airflow version
    fi
    
    # Update airflow.cfg with optimized settings
    cat > "$AIRFLOW_HOME/airflow.cfg" << 'EOF'
[core]
dags_folder = /home/ubuntu/OnlineRetailProject/airflow-project/dags
base_log_folder = /home/ubuntu/OnlineRetailProject/airflow-project/logs
executor = SequentialExecutor
sql_alchemy_conn = sqlite:////home/ubuntu/airflow/airflow.db
load_examples = False
dag_file_processor_timeout = 600
dagbag_import_timeout = 600
dagbag_import_error_traceback_depth = 2

[database]
sql_alchemy_conn = sqlite:////home/ubuntu/airflow/airflow.db

[webserver]
web_server_host = 0.0.0.0
web_server_port = 8080
secret_key = your-secret-key-here
workers = 4
worker_timeout = 120
worker_refresh_batch_size = 1
worker_refresh_interval = 30

[scheduler]
job_heartbeat_sec = 5
scheduler_heartbeat_sec = 5
run_duration = -1
num_runs = -1
processor_poll_interval = 1
min_file_process_interval = 30
dag_dir_list_interval = 300
print_stats_interval = 30
pool_metrics_interval = 5.0
scheduler_health_check_threshold = 30
parsing_processes = 2
scheduler_zombie_task_threshold = 300
catchup_by_default = True
dagbag_import_timeout = 600

[celery]
worker_prefetch_multiplier = 1
worker_enable_remote_task_prefetch = True

[logging]
base_log_folder = /home/ubuntu/OnlineRetailProject/airflow-project/logs
dag_processor_manager_log_location = /home/ubuntu/OnlineRetailProject/airflow-project/logs/dag_processor_manager/dag_processor_manager.log
task_log_reader = task

[metrics]
statsd_on = False
statsd_host = localhost
statsd_port = 8125
statsd_prefix = airflow

[secrets]
backend = airflow.providers.hashicorp.secrets.vault.VaultBackend
backend_kwargs = {"connections_path": "connections", "variables_path": "variables", "url": "http://127.0.0.1:8200", "mount_point": "airflow"}

[cli]
api_client = airflow.api.client.local_client
endpoint_url = http://localhost:8080

[api]
auth_backend = airflow.api.auth.backend.session
maximum_page_limit = 100
fallback_page_limit = 100
EOF
    
    echo "✅ Airflow configuration updated"
}

# ==============================================================================
# Function to create a comprehensive status check
# ==============================================================================
create_status_script() {
    echo "📊 Creating enhanced status script..."
    
    cat > "$PROJECT_DIR/airflow-project/status_airflow.sh" << 'EOF'
#!/bin/bash

echo "📊 Airflow Service Status:"
echo "=========================="

# Check systemd services
echo "🔧 Systemd Services:"
systemctl status airflow-webserver --no-pager -l
echo ""
systemctl status airflow-scheduler --no-pager -l
echo ""

# Check if services are running
if systemctl is-active --quiet airflow-webserver && systemctl is-active --quiet airflow-scheduler; then
    echo "✅ Both Airflow services are running"
else
    echo "❌ One or more Airflow services are not running"
fi

# Check DAG status
echo ""
echo "📋 DAG Status:"
cd /home/ubuntu/OnlineRetailProject/airflow-project
source venv/bin/activate
airflow dags list

# Check connections
echo ""
echo "🔗 Connection Status:"
airflow connections list

# Check recent DAG runs
echo ""
echo "🏃 Recent DAG Runs:"
airflow dags list-runs --limit 5

# Check disk space
echo ""
echo "💾 Disk Space:"
df -h /home/ubuntu/OnlineRetailProject

# Check memory usage
echo ""
echo "🧠 Memory Usage:"
free -h

# Check Airflow logs for errors
echo ""
echo "📝 Recent Airflow Errors:"
tail -n 20 /home/ubuntu/OnlineRetailProject/airflow-project/logs/scheduler/latest/*.log 2>/dev/null | grep -i error || echo "No recent errors found"
EOF
    
    chmod +x "$PROJECT_DIR/airflow-project/status_airflow.sh"
    echo "✅ Enhanced status script created"
}

# ==============================================================================
# Function to create a comprehensive health check
# ==============================================================================
create_health_check() {
    echo "🏥 Creating health check script..."
    
    cat > "$PROJECT_DIR/airflow-project/health_check.sh" << 'EOF'
#!/bin/bash

echo "🏥 Airflow Health Check"
echo "======================"

# Check if virtual environment exists
if [ ! -d "/home/ubuntu/OnlineRetailProject/airflow-project/venv" ]; then
    echo "❌ Virtual environment not found"
    exit 1
fi

# Check if Airflow is installed
source /home/ubuntu/OnlineRetailProject/airflow-project/venv/bin/activate
if ! command -v airflow &> /dev/null; then
    echo "❌ Airflow not installed"
    exit 1
fi

# Check if DAGs are loading
echo "🔍 Checking DAG loading..."
dag_errors=$(airflow dags list-import-errors 2>/dev/null | wc -l)
if [ "$dag_errors" -gt 0 ]; then
    echo "⚠️  DAG import errors detected"
    airflow dags list-import-errors
else
    echo "✅ No DAG import errors"
fi

# Check if services are running
echo "🔧 Checking service status..."
if systemctl is-active --quiet airflow-webserver && systemctl is-active --quiet airflow-scheduler; then
    echo "✅ Airflow services are running"
else
    echo "❌ Airflow services are not running"
    exit 1
fi

# Check web interface
echo "🌐 Checking web interface..."
if curl -s http://localhost:8080 > /dev/null; then
    echo "✅ Web interface is accessible"
else
    echo "❌ Web interface is not accessible"
fi

# Check database
echo "🗄️  Checking database..."
if airflow db check; then
    echo "✅ Database is healthy"
else
    echo "❌ Database issues detected"
fi

echo "✅ Health check completed successfully"
EOF
    
    chmod +x "$PROJECT_DIR/airflow-project/health_check.sh"
    echo "✅ Health check script created"
}

# ==============================================================================
# Function to create an auto-recovery script
# ==============================================================================
create_auto_recovery() {
    echo "🔄 Creating auto-recovery script..."
    
    cat > "$PROJECT_DIR/airflow-project/auto_recovery.sh" << 'EOF'
#!/bin/bash

echo "🔄 Airflow Auto-Recovery"
echo "========================"

# Function to restart services
restart_services() {
    echo "🔄 Restarting Airflow services..."
    sudo systemctl restart airflow-webserver
    sudo systemctl restart airflow-scheduler
    sleep 10
    
    # Check if services are running
    if systemctl is-active --quiet airflow-webserver && systemctl is-active --quiet airflow-scheduler; then
        echo "✅ Services restarted successfully"
        return 0
    else
        echo "❌ Services failed to restart"
        return 1
    fi
}

# Function to reinitialize database
reinitialize_db() {
    echo "🗄️  Reinitializing database..."
    cd /home/ubuntu/OnlineRetailProject/airflow-project
    source venv/bin/activate
    airflow db init
    airflow users create --username airflow --password airflow --firstname Admin --lastname User --role Admin --email admin@example.com
    echo "✅ Database reinitialized"
}

# Function to clean up and restart
full_restart() {
    echo "🧹 Performing full restart..."
    
    # Stop services
    sudo systemctl stop airflow-webserver airflow-scheduler
    
    # Clean up processes
    pkill -f airflow || true
    sleep 5
    
    # Restart services
    restart_services
    
    if [ $? -eq 0 ]; then
        echo "✅ Full restart completed successfully"
    else
        echo "❌ Full restart failed"
        exit 1
    fi
}

# Check current status
if ! systemctl is-active --quiet airflow-webserver || ! systemctl is-active --quiet airflow-scheduler; then
    echo "⚠️  Services are not running, attempting restart..."
    restart_services
    
    if [ $? -ne 0 ]; then
        echo "🔄 Attempting full restart..."
        full_restart
    fi
else
    echo "✅ Services are running normally"
fi

echo "✅ Auto-recovery completed"
EOF
    
    chmod +x "$PROJECT_DIR/airflow-project/auto_recovery.sh"
    echo "✅ Auto-recovery script created"
}

# ==============================================================================
# Clean up existing files and directories
# ==============================================================================
echo "🧹 Cleaning up existing files..."

# Remove old setup scripts
rm -f "$PROJECT_DIR/setup_dev_env.sh"
rm -f "$PROJECT_DIR/setup_docker_airflow.sh"
rm -f "$PROJECT_DIR/airflow-project/setup_airflow.sh"
rm -f "$PROJECT_DIR/airflow-project/setup_airflow_on_ec2.sh"
rm -f "$PROJECT_DIR/airflow-project/setup_repo_on_ec2.sh"
rm -f "$PROJECT_DIR/airflow-project/install_airflow_on_instance.sh"
rm -f "$PROJECT_DIR/airflow-project/install_and_run_airflow.sh"
rm -f "$PROJECT_DIR/airflow-project/start_airflow.sh"
rm -f "$PROJECT_DIR/airflow-project/stop_airflow.sh"
rm -f "$PROJECT_DIR/airflow-project/restart_airflow.sh"
rm -f "$PROJECT_DIR/airflow-project/view_logs.sh"

# Remove backup directory if it exists
rm -rf "$PROJECT_DIR/airflow-project-backup"

# Function to clean up Python environments
cleanup_python_env() {
    echo "🐍 Cleaning up Python environments..."
    
    # Remove existing virtual environments
    rm -rf "$PROJECT_DIR/airflow-project/venv"
    rm -rf "$PROJECT_DIR/airflow-project/env"
    rm -rf "$PROJECT_DIR/airflow-project/.venv"
    
    # Clean pip cache
    pip cache purge 2>/dev/null || true
    
    # Remove any existing Airflow installations
    pip uninstall -y apache-airflow astro-sdk-python astronomer-cosmos 2>/dev/null || true
    
    echo "✅ Python environment cleanup completed"
}

# Function to clean up Airflow installations
cleanup_airflow() {
    echo "🪶 Cleaning up existing Airflow installations..."
    
    # Stop any running Airflow services
    sudo systemctl stop airflow-webserver 2>/dev/null || true
    sudo systemctl stop airflow-scheduler 2>/dev/null || true
    
    # Remove systemd services
    sudo systemctl disable airflow-webserver 2>/dev/null || true
    sudo systemctl disable airflow-scheduler 2>/dev/null || true
    sudo rm -f /etc/systemd/system/airflow-webserver.service
    sudo rm -f /etc/systemd/system/airflow-scheduler.service
    
    # Remove Airflow home directory
    rm -rf "$AIRFLOW_HOME"
    
    # Remove any existing Airflow databases
    rm -f "$AIRFLOW_HOME/airflow.db" 2>/dev/null || true
    rm -f "$AIRFLOW_HOME/unittests.cfg" 2>/dev/null || true
    
    # Clean up any existing Airflow logs
    rm -rf "$PROJECT_DIR/airflow-project/logs"
    
    echo "✅ Airflow cleanup completed"
}

# Function to clean up Docker artifacts
cleanup_docker_artifacts() {
    echo "🐳 Cleaning up Docker artifacts..."
    
    # Stop and remove any existing containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remove any existing Airflow Docker images
    docker rmi $(docker images | grep airflow | awk '{print $3}') 2>/dev/null || true
    
    # Clean up Docker system
    docker system prune -f 2>/dev/null || true
    
    echo "✅ Docker artifacts cleanup completed"
}

# Execute cleanup functions
cleanup_python_env
cleanup_airflow
cleanup_docker_artifacts

echo "✅ Cleanup completed"

# ==============================================================================
# Update System and Install Dependencies
# ==============================================================================
echo "📦 Updating system packages..."

# Function to handle package manager locks
handle_package_locks() {
    echo "🔧 Checking for package manager locks..."
    
    # Check if any apt processes are running
    if pgrep -f "apt-get\|apt\|dpkg" > /dev/null; then
        echo "⚠️  Package manager processes detected. Waiting for completion..."
        while pgrep -f "apt-get\|apt\|dpkg" > /dev/null; do
            sleep 5
        done
        echo "✅ Package manager processes completed"
    fi
    
    # Remove stale lock files
    sudo rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/cache/apt/archives/lock /var/lib/apt/lists/lock
    
    # Configure any pending packages
    sudo dpkg --configure -a
    
    # Wait a moment for any background processes
    sleep 2
}

# Function to clean up malformed package manager artifacts
cleanup_package_manager() {
    echo "🧹 Cleaning up package manager artifacts..."
    
    # Remove any malformed repository entries
    sudo rm -f /etc/apt/sources.list.d/*.list.save
    sudo rm -f /etc/apt/sources.list.d/*.list.dpkg-*
    
    # Clean up any corrupted GPG keys
    sudo rm -f /etc/apt/trusted.gpg.d/*.gpg~
    sudo rm -f /etc/apt/keyrings/*.gpg~
    
    # Remove any malformed entries from sources.list
    if [ -f /etc/apt/sources.list ]; then
        # Remove lines with backslashes or malformed URLs
        sudo sed -i '/.*\\/d' /etc/apt/sources.list
        sudo sed -i '/.*\\\\/d' /etc/apt/sources.list
        sudo sed -i '/.*https.*\\/d' /etc/apt/sources.list
    fi
    
    # Clean up apt cache
    sudo apt-get clean
    sudo apt-get autoclean
    
    echo "✅ Package manager cleanup completed"
}

# Function to kill any background package manager processes
kill_background_processes() {
    echo "🔧 Checking for background package manager processes..."
    
    # Kill any running apt processes
    if pgrep -f "apt-get\|apt\|dpkg" > /dev/null; then
        echo "⚠️  Killing background package manager processes..."
        sudo pkill -f "apt-get\|apt\|dpkg" || true
        sleep 3
    fi
    
    # Wait for processes to fully terminate
    while pgrep -f "apt-get\|apt\|dpkg" > /dev/null; do
        echo "⏳ Waiting for processes to terminate..."
        sleep 2
    done
    
    echo "✅ Background processes cleared"
}

# Kill any background processes first
kill_background_processes

# Clean up package manager artifacts
cleanup_package_manager

# Handle any existing locks before starting
handle_package_locks

# Update package lists with retry logic
update_packages() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "📦 Attempting to update packages (attempt $attempt/$max_attempts)..."
        
        if sudo apt-get update -y; then
            echo "✅ Package update successful"
            return 0
        else
            echo "❌ Package update failed (attempt $attempt)"
            handle_package_locks
            attempt=$((attempt + 1))
            sleep 5
        fi
    done
    
    echo "❌ Failed to update packages after $max_attempts attempts"
    exit 1
}

update_packages

# Upgrade packages with retry logic
upgrade_packages() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "📦 Attempting to upgrade packages (attempt $attempt/$max_attempts)..."
        
        if sudo apt-get upgrade -y; then
            echo "✅ Package upgrade successful"
            return 0
        else
            echo "❌ Package upgrade failed (attempt $attempt)"
            handle_package_locks
            attempt=$((attempt + 1))
            sleep 5
        fi
    done
    
    echo "❌ Failed to upgrade packages after $max_attempts attempts"
    exit 1
}

upgrade_packages

echo "🔧 Installing system dependencies..."

# Install dependencies with retry logic
install_dependencies() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "🔧 Attempting to install dependencies (attempt $attempt/$max_attempts)..."
        
        if sudo apt-get install -y \
            python3 \
            python3-pip \
            python3-venv \
            build-essential \
            libssl-dev \
            libffi-dev \
            python3-dev \
            git \
            curl \
            wget \
            unzip \
            software-properties-common \
            apt-transport-https \
            ca-certificates \
            gnupg \
            lsb-release; then
            echo "✅ Dependencies installed successfully"
            return 0
        else
            echo "❌ Dependency installation failed (attempt $attempt)"
            handle_package_locks
            attempt=$((attempt + 1))
            sleep 5
        fi
    done
    
    echo "❌ Failed to install dependencies after $max_attempts attempts"
    exit 1
}

install_dependencies

# ==============================================================================
# Fix and Install Docker
# ==============================================================================
echo "🐳 Installing Docker..."

# Function to clean up Docker repository issues
cleanup_docker_repo() {
    echo "🧹 Cleaning up Docker repository configuration..."
    
    # Remove any old/broken Docker repo files
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo rm -f /etc/apt/sources.list.d/docker-ce.list
    sudo rm -f /etc/apt/sources.list.d/docker.list.save
    sudo rm -f /etc/apt/sources.list.d/docker-ce.list.save
    
    # Check if there are any malformed Docker entries in sources.list
    if grep -q "docker.com/linux/ubuntu.*\\" /etc/apt/sources.list; then
        echo "⚠️  Found malformed Docker repository in sources.list, fixing..."
        sudo sed -i '/docker.com\/linux\/ubuntu.*\\/d' /etc/apt/sources.list
    fi
    
    # Remove any malformed entries with backslashes
    if grep -q "docker.com.*\\\\" /etc/apt/sources.list; then
        echo "⚠️  Found malformed Docker entries with backslashes, removing..."
        sudo sed -i '/docker.com.*\\\\/d' /etc/apt/sources.list
    fi
    
    # Remove any malformed Docker entries with spaces or special characters
    if grep -q "docker.com.*[[:space:]]" /etc/apt/sources.list; then
        echo "⚠️  Found malformed Docker entries with spaces, removing..."
        sudo sed -i '/docker.com.*[[:space:]]/d' /etc/apt/sources.list
    fi
    
    # Remove any Docker-related GPG keys that might be corrupted
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    sudo rm -f /etc/apt/trusted.gpg.d/docker.gpg
    sudo rm -f /etc/apt/keyrings/docker.asc
    sudo rm -f /etc/apt/keyrings/docker.gpg
    sudo rm -f /usr/share/keyrings/docker.gpg
    sudo rm -f /etc/apt/keyrings/docker*.gpg
    sudo rm -f /etc/apt/keyrings/docker*.asc
    
    # Clean up any corrupted Docker keyring directories
    sudo rm -rf /etc/apt/keyrings/docker*
    
    # Remove any malformed Docker repository files in sources.list.d
    find /etc/apt/sources.list.d/ -name "*docker*" -type f -exec grep -l "\\" {} \; | xargs -r sudo rm -f
    
    echo "✅ Docker repository cleanup completed"
}

# Immediately clean up any existing Docker repository issues
cleanup_docker_repo

# Verify apt update works after cleanup
echo "🔍 Verifying package manager is working after cleanup..."
if ! sudo apt-get update -y; then
    echo "❌ Package manager still has issues after cleanup. Attempting additional cleanup..."
    
    # Additional cleanup steps
    sudo rm -f /etc/apt/sources.list.d/*.list.save
    sudo rm -f /etc/apt/sources.list.d/*.list.dpkg-*
    sudo apt-get clean
    sudo apt-get autoclean
    
    # Try again
    if ! sudo apt-get update -y; then
        echo "❌ Package manager still has issues after additional cleanup. Exiting."
        exit 1
    fi
fi
echo "✅ Package manager verified working"

# Add Docker's official GPG key
echo "🔑 Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository (correct format)
echo "📦 Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists for Docker with retry logic
update_for_docker() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "📦 Attempting to update package lists for Docker (attempt $attempt/$max_attempts)..."
        
        if sudo apt-get update -y; then
            echo "✅ Package lists updated successfully"
            return 0
        else
            echo "❌ Package list update failed (attempt $attempt)"
            handle_package_locks
            attempt=$((attempt + 1))
            sleep 5
        fi
    done
    
    echo "❌ Failed to update package lists after $max_attempts attempts"
    exit 1
}

update_for_docker

# Install Docker with retry logic
install_docker() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "🐳 Attempting to install Docker (attempt $attempt/$max_attempts)..."
        
        if sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
            echo "✅ Docker installed successfully"
            return 0
        else
            echo "❌ Docker installation failed (attempt $attempt)"
            handle_package_locks
            attempt=$((attempt + 1))
            sleep 5
        fi
    done
    
    echo "❌ Failed to install Docker after $max_attempts attempts"
    exit 1
}

install_docker

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

echo "✅ Docker installed successfully"

# ==============================================================================
# Set Up Project Structure
# ==============================================================================
echo "📁 Setting up project structure..."

# Ensure project directory exists
mkdir -p "$PROJECT_DIR/airflow-project"

# Create necessary directories
mkdir -p "$PROJECT_DIR/airflow-project/dags"
mkdir -p "$PROJECT_DIR/airflow-project/plugins"
mkdir -p "$PROJECT_DIR/airflow-project/logs"
mkdir -p "$PROJECT_DIR/airflow-project/include"
mkdir -p "$PROJECT_DIR/airflow-project/connections"
mkdir -p "$PROJECT_DIR/airflow-project/variables"

# ==============================================================================
# Create Requirements File
# ==============================================================================
echo "📚 Creating requirements.txt..."
cat > "$PROJECT_DIR/airflow-project/requirements.txt" << 'EOF'
apache-airflow==2.9.2
apache-airflow-providers-docker==3.9.0
apache-airflow-providers-postgres==5.7.1
apache-airflow-providers-http==4.7.0
apache-airflow-providers-ssh==3.10.0
apache-airflow-providers-celery==3.4.0
apache-airflow-providers-redis==3.4.0
apache-airflow-providers-hashicorp==3.4.0
apache-airflow-providers-snowflake==5.4.0
apache-airflow-providers-amazon==8.12.0
pandas==2.1.4
numpy==1.24.3
scikit-learn==1.3.2
psycopg2-binary==2.9.9
boto3==1.34.0
requests==2.31.0
python-dotenv==1.0.0
cryptography==41.0.7
redis>=4.5.2,<5.0.0
celery==5.3.4
snowflake-connector-python==3.6.0
astro-sdk-python[snowflake,postgres]==1.8.1
astronomer-cosmos==1.10.1
pydantic==2.11.7
EOF

echo "✅ Requirements.txt created with Astro SDK dependencies"

# ==============================================================================
# Set Up Python Environment
# ==============================================================================
echo "🐍 Setting up Python virtual environment..."
cd "$PROJECT_DIR/airflow-project"

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install Airflow and dependencies
echo "📚 Installing Airflow 2.9.2 and dependencies..."
pip install -r requirements.txt

# Verify Airflow version
echo "🔍 Verifying Airflow installation..."
airflow version

# ==============================================================================
# Configure Airflow
# ==============================================================================
echo "⚙️ Configuring Airflow..."

# Set Airflow home
export AIRFLOW_HOME="$AIRFLOW_HOME"

# Create Airflow directory
mkdir -p "$AIRFLOW_HOME"

# Initialize Airflow database with error handling
init_airflow_db() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "🗄️  Attempting to initialize Airflow database (attempt $attempt/$max_attempts)..."
        
        if airflow db init; then
            echo "✅ Airflow database initialized successfully"
            return 0
        else
            echo "❌ Database initialization failed (attempt $attempt)"
            
            # Check if it's a Vault backend issue
            if grep -q "VaultError" /tmp/airflow_error.log 2>/dev/null || airflow db init 2>&1 | grep -q "VaultError"; then
                echo "🔧 Removing Vault backend configuration..."
                sed -i '/^\[secrets\]/,/^\[/d' "$AIRFLOW_HOME/airflow.cfg"
                echo "✅ Vault backend configuration removed"
            fi
            
            attempt=$((attempt + 1))
            sleep 2
        fi
    done
    
    echo "❌ Failed to initialize Airflow database after $max_attempts attempts"
    exit 1
}

init_airflow_db

# Create Airflow user with error handling
create_airflow_user() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "👤 Attempting to create Airflow user (attempt $attempt/$max_attempts)..."
        
        if airflow users create \
            --username "$AIRFLOW_USER" \
            --firstname Admin \
            --lastname User \
            --role Admin \
            --email "$AIRFLOW_EMAIL" \
            --password "$AIRFLOW_PASSWORD"; then
            echo "✅ Airflow user created successfully"
            return 0
        else
            echo "❌ User creation failed (attempt $attempt)"
            
            # Check if it's an executor compatibility issue
            if grep -q "cannot use SQLite with the LocalExecutor" /tmp/airflow_error.log 2>/dev/null; then
                echo "🔧 Fixing executor configuration..."
                sed -i 's/executor = LocalExecutor/executor = SequentialExecutor/' "$AIRFLOW_HOME/airflow.cfg"
                sed -i 's/sql_alchemy_conn = sqlite:\/\/\/.*airflow\.db/[database]\nsql_alchemy_conn = sqlite:\/\/\/'$AIRFLOW_HOME'\/airflow.db/' "$AIRFLOW_HOME/airflow.cfg"
                echo "✅ Executor configuration fixed"
            fi
            
            attempt=$((attempt + 1))
            sleep 2
        fi
    done
    
    echo "❌ Failed to create Airflow user after $max_attempts attempts"
    exit 1
}

create_airflow_user

# ==============================================================================
# Set Up Airflow Configuration
# ==============================================================================
echo "🔧 Setting up Airflow configuration..."

# Clean up any existing malformed configuration
cleanup_airflow_config() {
    echo "🧹 Cleaning up existing Airflow configuration..."
    
    # Remove any existing airflow.cfg that might have malformed settings
    if [ -f "$AIRFLOW_HOME/airflow.cfg" ]; then
        echo "📋 Backing up existing airflow.cfg..."
        cp "$AIRFLOW_HOME/airflow.cfg" "$AIRFLOW_HOME/airflow.cfg.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Remove malformed sql_alchemy_conn from [core] section
        sed -i '/^\[core\]/,/^\[/ { /sql_alchemy_conn/d; }' "$AIRFLOW_HOME/airflow.cfg"
        
        # Remove any Vault backend configuration
        sed -i '/^\[secrets\]/,/^\[/d' "$AIRFLOW_HOME/airflow.cfg"
        
        echo "✅ Existing configuration cleaned up"
    fi
}

cleanup_airflow_config

# Create custom airflow.cfg
cat > "$AIRFLOW_HOME/airflow.cfg" << EOF
[core]
dags_folder = $PROJECT_DIR/airflow-project/dags
plugins_folder = $PROJECT_DIR/airflow-project/plugins
executor = SequentialExecutor
load_examples = False
fernet_key = $(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

[database]
sql_alchemy_conn = sqlite:///$AIRFLOW_HOME/airflow.db

[webserver]
web_server_host = 0.0.0.0
web_server_port = 8080
secret_key = $(python3 -c "import secrets; print(secrets.token_hex(16))")

[scheduler]
job_heartbeat_sec = 5
scheduler_heartbeat_sec = 5

[logging]
base_log_folder = $PROJECT_DIR/airflow-project/logs
dag_processor_manager_log_location = $PROJECT_DIR/airflow-project/logs/dag_processor_manager/dag_processor_manager.log
EOF

# ==============================================================================
# Set Up Airflow Connections
# ==============================================================================
echo "🔗 Setting up Airflow connections..."

# Create connections directory if it doesn't exist
mkdir -p "$PROJECT_DIR/airflow-project/connections"

# Copy existing connection files
if [ -f "$PROJECT_DIR/airflow-project/connections/snowflake_default.json" ]; then
    echo "📋 Found existing Snowflake connection configuration"
fi

if [ -f "$PROJECT_DIR/airflow-project/connections/s3_default.json" ]; then
    echo "📋 Found existing S3 connection configuration"
fi

if [ -f "$PROJECT_DIR/airflow-project/connections/aws_default.json" ]; then
    echo "📋 Found existing AWS connection configuration"
fi

# Create environment variables file for connections
cat > "$PROJECT_DIR/airflow-project/airflow_connections.env" << 'EOF'
# Snowflake Connection Variables
# Update these with your actual Snowflake credentials
export SNOWFLAKE_ACCOUNT="your-snowflake-account"
export SNOWFLAKE_USER="your-snowflake-username"
export SNOWFLAKE_PASSWORD="your-snowflake-password"
export SNOWFLAKE_DATABASE="your-snowflake-database"
export SNOWFLAKE_SCHEMA="your-snowflake-schema"
export SNOWFLAKE_WAREHOUSE="your-snowflake-warehouse"

# AWS Connection Variables
# Update these with your actual AWS credentials
export AWS_ACCESS_KEY_ID="your-aws-access-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
EOF

echo "📝 Created airflow_connections.env file"
echo "⚠️  IMPORTANT: Update the credentials in $PROJECT_DIR/airflow-project/airflow_connections.env"
echo "   Then source the file: source $PROJECT_DIR/airflow-project/airflow_connections.env"

# ==============================================================================
# Set Proper Permissions
# ==============================================================================
echo "🔐 Setting proper permissions..."
sudo chown -R ubuntu:ubuntu "$PROJECT_DIR"
sudo chown -R ubuntu:ubuntu "$AIRFLOW_HOME"

# ==============================================================================
# Set Up Environment Variables
# ==============================================================================
echo "🌍 Setting up environment variables..."

# Add to .bashrc
cat >> /home/ubuntu/.bashrc << EOF

# Airflow Configuration
export AIRFLOW_HOME=$AIRFLOW_HOME
export PYTHONPATH=$PROJECT_DIR/airflow-project:\$PYTHONPATH
EOF

# Source the updated bashrc
source /home/ubuntu/.bashrc

# ==============================================================================
# Create Systemd Services
# ==============================================================================
echo "🔧 Creating systemd services for Airflow..."

sudo tee /etc/systemd/system/airflow-webserver.service > /dev/null << EOF
[Unit]
Description=Airflow webserver daemon
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
Environment=AIRFLOW_HOME=$AIRFLOW_HOME
Environment=PYTHONPATH=$PROJECT_DIR/airflow-project
WorkingDirectory=$PROJECT_DIR/airflow-project
ExecStart=$PROJECT_DIR/airflow-project/venv/bin/airflow webserver
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/airflow-scheduler.service > /dev/null << EOF
[Unit]
Description=Airflow scheduler daemon
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
Environment=AIRFLOW_HOME=$AIRFLOW_HOME
Environment=PYTHONPATH=$PROJECT_DIR/airflow-project
WorkingDirectory=$PROJECT_DIR/airflow-project
ExecStart=$PROJECT_DIR/airflow-project/venv/bin/airflow scheduler
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable airflow-webserver
sudo systemctl enable airflow-scheduler

# ==============================================================================
# Create Management Scripts
# ==============================================================================
echo "📝 Creating management scripts..."

# Start Airflow script
cat > "$PROJECT_DIR/airflow-project/start_airflow.sh" << 'EOF'
#!/bin/bash
echo "🚀 Starting Airflow services..."
sudo systemctl start airflow-webserver
sudo systemctl start airflow-scheduler
echo "✅ Airflow services started"
echo "🌐 Web UI available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "👤 Username: airflow"
echo "🔑 Password: airflow"
EOF

# Stop Airflow script
cat > "$PROJECT_DIR/airflow-project/stop_airflow.sh" << 'EOF'
#!/bin/bash
echo "🛑 Stopping Airflow services..."
sudo systemctl stop airflow-webserver
sudo systemctl stop airflow-scheduler
echo "✅ Airflow services stopped"
EOF

# Status script
cat > "$PROJECT_DIR/airflow-project/status_airflow.sh" << 'EOF'
#!/bin/bash
echo "📊 Airflow Service Status:"
echo "=========================="
sudo systemctl status airflow-webserver --no-pager -l
echo ""
echo "=========================="
sudo systemctl status airflow-scheduler --no-pager -l
EOF

# Make scripts executable
chmod +x "$PROJECT_DIR/airflow-project/start_airflow.sh"
chmod +x "$PROJECT_DIR/airflow-project/stop_airflow.sh"
chmod +x "$PROJECT_DIR/airflow-project/status_airflow.sh"

# ==============================================================================
# Create Connection Setup Script
# ==============================================================================
echo "🔗 Creating connection setup script..."

cat > "$PROJECT_DIR/airflow-project/setup_connections.sh" << 'EOF'
#!/bin/bash

echo "🔗 Setting up Airflow connections..."

# Source environment variables if file exists
if [ -f "$PROJECT_DIR/airflow-project/airflow_connections.env" ]; then
    source "$PROJECT_DIR/airflow-project/airflow_connections.env"
    echo "✅ Loaded connection environment variables"
else
    echo "⚠️  airflow_connections.env not found. Please create it with your credentials."
    exit 1
fi

# Activate virtual environment
source "$PROJECT_DIR/airflow-project/venv/bin/activate"

# Set Airflow home
export AIRFLOW_HOME="/home/ubuntu/airflow"

# Create Snowflake connection
echo "❄️  Creating Snowflake connection..."
airflow connections add 'snowflake_default' \
    --conn-type 'snowflake' \
    --conn-host "${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com" \
    --conn-login "${SNOWFLAKE_USER}" \
    --conn-password "${SNOWFLAKE_PASSWORD}" \
    --conn-schema "${SNOWFLAKE_SCHEMA}" \
    --conn-port 443 \
    --conn-extra "{\"account\": \"${SNOWFLAKE_ACCOUNT}\", \"warehouse\": \"${SNOWFLAKE_WAREHOUSE}\", \"database\": \"${SNOWFLAKE_DATABASE}\", \"region\": \"us-east-1\"}"

# Create S3 connection
echo "☁️  Creating S3 connection..."
airflow connections add 's3_default' \
    --conn-type 's3' \
    --conn-login "${AWS_ACCESS_KEY_ID}" \
    --conn-password "${AWS_SECRET_ACCESS_KEY}" \
    --conn-extra "{\"aws_access_key_id\": \"${AWS_ACCESS_KEY_ID}\", \"aws_secret_access_key\": \"${AWS_SECRET_ACCESS_KEY}\", \"region_name\": \"us-east-1\"}"

# Create AWS connection
echo "🔄 Creating AWS connection..."
airflow connections add 'aws_default' \
    --conn-type 'aws' \
    --conn-extra "{\"region_name\": \"us-east-1\", \"aws_access_key_id\": \"${AWS_ACCESS_KEY_ID}\", \"aws_secret_access_key\": \"${AWS_SECRET_ACCESS_KEY}\"}"

echo "✅ All connections created successfully!"
echo "📋 Available connections:"
airflow connections list
EOF

chmod +x "$PROJECT_DIR/airflow-project/setup_connections.sh"

# ==============================================================================
# Create Sample DAG
# ==============================================================================
echo "📋 Creating sample DAG..."

cat > "$PROJECT_DIR/airflow-project/dags/sample_dag.py" << 'EOF'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'sample_retail_dag',
    default_args=default_args,
    description='Sample DAG for Online Retail Project',
    schedule_interval=timedelta(days=1),
    catchup=False,
    tags=['retail', 'sample'],
)

def print_hello():
    return "Hello from Airflow!"

hello_task = PythonOperator(
    task_id='hello_task',
    python_callable=print_hello,
    dag=dag,
)

bash_task = BashOperator(
    task_id='bash_task',
    bash_command='echo "Hello from Bash!"',
    dag=dag,
)

hello_task >> bash_task
EOF

# ==============================================================================
# Final Setup
# ==============================================================================
echo "🎉 Airflow setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Update credentials: Edit $PROJECT_DIR/airflow-project/airflow_connections.env"
echo "2. Set up connections: cd $PROJECT_DIR/airflow-project && ./setup_connections.sh"
echo "3. Start Airflow: ./start_airflow.sh"
echo "4. Check status: ./status_airflow.sh"
echo "5. Access Web UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "6. Login with: airflow / airflow"
echo ""
echo "📁 Project structure:"
echo "   - DAGs: $PROJECT_DIR/airflow-project/dags/"
echo "   - Plugins: $PROJECT_DIR/airflow-project/plugins/"
echo "   - Logs: $PROJECT_DIR/airflow-project/logs/"
echo "   - Config: $AIRFLOW_HOME/airflow.cfg"
echo "   - Connections: $PROJECT_DIR/airflow-project/connections/"
echo ""
echo "🔧 Management commands:"
echo "   - Start: ./start_airflow.sh"
echo "   - Stop: ./stop_airflow.sh"
echo "   - Status: ./status_airflow.sh"
echo "   - Setup connections: ./setup_connections.sh"
echo ""
echo "🔗 Available connections:"
echo "   - snowflake_default (Snowflake database)"
echo "   - s3_default (AWS S3 storage)"
echo "   - aws_default (AWS services)"
echo ""
echo "✅ Setup complete! Your Airflow instance is ready." 