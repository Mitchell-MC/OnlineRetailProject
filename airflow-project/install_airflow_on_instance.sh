#!/bin/bash

# ==============================================================================
# Airflow Installation Script for Ubuntu EC2 Instance (Airflow 2.9.2)
# ==============================================================================
# This script installs and configures Apache Airflow 2.9.2 on your Ubuntu EC2 instance
# Airflow 2.9.2 is a stable, production-ready version
# Run this script on your EC2 instance after SSH'ing into it

set -e  # Exit on any error

echo "🚀 Starting Airflow installation on Ubuntu EC2..."

# ==============================================================================
# Configuration Variables
# ==============================================================================
PROJECT_DIR="/home/ubuntu/OnlineRetailProject"
AIRFLOW_HOME="/home/ubuntu/airflow"
AIRFLOW_USER="airflow"
AIRFLOW_PASSWORD="airflow"
AIRFLOW_EMAIL="admin@example.com"

# ==============================================================================
# Update System and Install Dependencies
# ==============================================================================
echo "📦 Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "🔧 Installing system dependencies..."
sudo apt-get install -y \
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
    lsb-release

# ==============================================================================
# Install Docker and Docker Compose
# ==============================================================================
echo "🐳 Installing Docker..."

# Remove any old/broken Docker repo files
sudo rm -f /etc/apt/sources.list.d/docker.list

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository (correct format)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# ==============================================================================
# Clone Project Repository
# ==============================================================================
echo "📥 Cloning project repository..."
if [ ! -d "$PROJECT_DIR" ]; then
    git clone https://github.com/Mitchell-MC/OnlineRetailProject.git "$PROJECT_DIR"
else
    echo "Repository already exists, pulling latest changes..."
    cd "$PROJECT_DIR"
    git pull origin main
fi

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
# Create Required Directories
# ==============================================================================
echo "📁 Creating required directories..."
mkdir -p "$PROJECT_DIR/airflow-project/logs"
mkdir -p "$PROJECT_DIR/airflow-project/plugins"
mkdir -p "$PROJECT_DIR/airflow-project/include"

# Set proper permissions
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
# Create Systemd Service for Airflow
# ==============================================================================
echo "🔧 Creating systemd service for Airflow..."

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

# ==============================================================================
# Create Startup Script
# ==============================================================================
echo "📜 Creating startup script..."

cat > "$PROJECT_DIR/start_airflow.sh" << 'EOF'
#!/bin/bash

# Start Airflow services
echo "Starting Airflow services..."

# Change to the airflow-project directory
cd /home/ubuntu/OnlineRetailProject/airflow-project

# Activate virtual environment
source venv/bin/activate

# Set environment variables
export AIRFLOW_HOME=/home/ubuntu/airflow
export PYTHONPATH=/home/ubuntu/OnlineRetailProject/airflow-project:$PYTHONPATH

# Start webserver in background
nohup airflow webserver --port 8080 --host 0.0.0.0 > /home/ubuntu/airflow_webserver.log 2>&1 &

# Start scheduler in background
nohup airflow scheduler > /home/ubuntu/airflow_scheduler.log 2>&1 &

echo "Airflow services started!"
echo "Webserver: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Username: airflow"
echo "Password: airflow"
EOF

chmod +x "$PROJECT_DIR/start_airflow.sh"

# ==============================================================================
# Create Stop Script
# ==============================================================================
echo "📜 Creating stop script..."

cat > "$PROJECT_DIR/stop_airflow.sh" << 'EOF'
#!/bin/bash

echo "Stopping Airflow services..."

# Kill Airflow processes
pkill -f "airflow webserver" || true
pkill -f "airflow scheduler" || true

echo "Airflow services stopped!"
EOF

chmod +x "$PROJECT_DIR/stop_airflow.sh"

# ==============================================================================
# Final Setup and Instructions
# ==============================================================================
echo "✅ Airflow installation completed successfully!"

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")

echo ""
echo "🎉 ========================================="
echo "   AIRFLOW 2.9.2 INSTALLATION COMPLETED!"
echo "========================================="
echo ""
echo "📋 Next Steps:"
echo "1. Start Airflow services:"
echo "   cd $PROJECT_DIR && ./start_airflow.sh"
echo ""
echo "2. Access Airflow Web UI:"
echo "   http://$PUBLIC_IP:8080"
echo "   Username: $AIRFLOW_USER"
echo "   Password: $AIRFLOW_PASSWORD"
echo ""
echo "3. Stop Airflow services:"
echo "   cd $PROJECT_DIR && ./stop_airflow.sh"
echo ""
echo "4. View logs:"
echo "   tail -f /home/ubuntu/airflow_webserver.log"
echo "   tail -f /home/ubuntu/airflow_scheduler.log"
echo ""
echo "📁 Project Structure:"
echo "   Project: $PROJECT_DIR"
echo "   Airflow Home: $AIRFLOW_HOME"
echo "   DAGs: $PROJECT_DIR/airflow-project/dags"
echo "   Logs: $PROJECT_DIR/airflow-project/logs"
echo ""
echo "🔧 Manual Start (if needed):"
echo "   source $PROJECT_DIR/airflow-project/venv/bin/activate"
echo "   export AIRFLOW_HOME=$AIRFLOW_HOME"
echo "   airflow webserver --port 8080 --host 0.0.0.0 &"
echo "   airflow scheduler &"
echo ""
echo "========================================="
echo ""

# Make sure ubuntu user can access the project
sudo chown -R ubuntu:ubuntu "$PROJECT_DIR"
sudo chown -R ubuntu:ubuntu "$AIRFLOW_HOME"

echo "🚀 Ready to start Airflow! Run: cd $PROJECT_DIR && ./start_airflow.sh" 