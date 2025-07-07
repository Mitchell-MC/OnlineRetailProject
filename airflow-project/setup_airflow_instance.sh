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
    
    # Check if there are any malformed Docker entries in sources.list
    if grep -q "docker.com/linux/ubuntu.*\\" /etc/apt/sources.list; then
        echo "⚠️  Found malformed Docker repository in sources.list, fixing..."
        sudo sed -i '/docker.com\/linux\/ubuntu.*\\/d' /etc/apt/sources.list
    fi
    
    # Remove any Docker-related GPG keys that might be corrupted
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    sudo rm -f /etc/apt/trusted.gpg.d/docker.gpg
    
    echo "✅ Docker repository cleanup completed"
}

cleanup_docker_repo

# Add Docker's official GPG key
echo "🔑 Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository (correct format)
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
EOF

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

# Initialize Airflow database
airflow db init

# Create Airflow user
airflow users create \
    --username "$AIRFLOW_USER" \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email "$AIRFLOW_EMAIL" \
    --password "$AIRFLOW_PASSWORD"

# ==============================================================================
# Set Up Airflow Configuration
# ==============================================================================
echo "🔧 Setting up Airflow configuration..."

# Create custom airflow.cfg
cat > "$AIRFLOW_HOME/airflow.cfg" << EOF
[core]
dags_folder = $PROJECT_DIR/airflow-project/dags
plugins_folder = $PROJECT_DIR/airflow-project/plugins
executor = LocalExecutor
sql_alchemy_conn = sqlite:///$AIRFLOW_HOME/airflow.db
load_examples = False
fernet_key = $(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

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

[celery]
broker_url = redis://localhost:6379/0
result_backend = db+postgresql://airflow:airflow@localhost/airflow

[secrets]
backend = airflow.providers.hashicorp.secrets.vault.VaultBackend
backend_kwargs = {"connections_path": "connections", "variables_path": "variables", "config_path": "config", "url": "http://127.0.0.1:8200", "mount_point": "airflow"}
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