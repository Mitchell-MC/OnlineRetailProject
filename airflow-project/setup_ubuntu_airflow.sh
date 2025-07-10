#!/bin/bash
set -e

echo "🚀 Starting Airflow and Docker setup on Ubuntu..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    print_warning "This script should be run with sudo privileges"
    print_status "Please run: sudo $0"
    exit 1
fi

# Update system packages
print_status "Updating system packages..."
apt-get update -y

# Install required packages
print_status "Installing required packages..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    unzip \
    software-properties-common \
    apt-transport-https

# Set up Docker's official GPG key
print_status "Setting up Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
apt-get update -y

# Install Docker Engine, CLI, Containerd, and Compose plugin
print_status "Installing Docker Engine..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
print_status "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
print_status "Adding ubuntu user to docker group..."
usermod -a -G docker ubuntu

# Verify Docker installation
print_status "Verifying Docker installation..."
if docker --version; then
    print_success "Docker installed successfully"
else
    print_error "Docker installation failed"
    exit 1
fi

# Verify Docker Compose installation
print_status "Verifying Docker Compose installation..."
if docker compose version; then
    print_success "Docker Compose installed successfully"
else
    print_error "Docker Compose installation failed"
    exit 1
fi

# Create project directory if it doesn't exist
PROJECT_DIR="/home/ubuntu/OnlineRetailProject"
if [ ! -d "$PROJECT_DIR" ]; then
    print_status "Creating project directory..."
    mkdir -p "$PROJECT_DIR"
    chown ubuntu:ubuntu "$PROJECT_DIR"
fi

# Navigate to project directory
cd "$PROJECT_DIR"

# Clone the repository if it doesn't exist
if [ ! -d "airflow-project" ]; then
    print_status "Cloning project repository..."
    sudo -u ubuntu git clone https://github.com/Mitchell-MC/OnlineRetailProject.git .
    chown -R ubuntu:ubuntu .
else
    print_status "Project directory already exists, pulling latest changes..."
    sudo -u ubuntu git pull origin main
fi

# Navigate to airflow-project directory
cd airflow-project

# Check if airflow.env exists, if not create it
if [ ! -f "airflow.env" ]; then
    print_warning "airflow.env file not found. Creating a template..."
    cat > airflow.env << 'EOF'
# Airflow Configuration
AIRFLOW__CORE__EXECUTOR=CeleryExecutor
AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres/airflow
AIRFLOW__CELERY__RESULT_BACKEND=db+postgresql://airflow:airflow@postgres/airflow
AIRFLOW__CELERY__BROKER_URL=redis://:@redis:6379/0
AIRFLOW__CORE__FERNET_KEY=your-fernet-key-here
AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True
AIRFLOW__CORE__LOAD_EXAMPLES=False

# AWS Configuration
AIRFLOW_CONN_AWS_DEFAULT=aws://AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY@

# Snowflake Configuration
AIRFLOW_CONN_SNOWFLAKE_DEFAULT=snowflake://username:password@account/database/schema?warehouse=warehouse&role=role

# Additional configurations
AIRFLOW__WEBSERVER__SECRET_KEY=your-secret-key-here
AIRFLOW__CORE__DEFAULT_TIMEZONE=UTC
EOF
    chown ubuntu:ubuntu airflow.env
    print_warning "Please edit airflow.env with your actual credentials before starting Airflow"
fi

# Create logs directory if it doesn't exist
mkdir -p logs
chown -R ubuntu:ubuntu logs

# Create plugins directory if it doesn't exist
mkdir -p plugins
chown -R ubuntu:ubuntu plugins

# Set proper permissions
print_status "Setting proper permissions..."
chown -R ubuntu:ubuntu .

# Switch to ubuntu user for Docker operations
print_status "Switching to ubuntu user for Docker operations..."
sudo -u ubuntu bash << 'EOF'
cd /home/ubuntu/OnlineRetailProject/airflow-project

# Build and start Airflow services
echo "🐳 Building and starting Airflow services..."
docker compose up -d --build

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check service status
echo "📊 Checking service status..."
docker compose ps
EOF

print_success "Setup completed successfully!"
echo ""
echo "🎉 Airflow is now running on your Ubuntu instance!"
echo ""
echo "📋 Next steps:"
echo "   1. Access Airflow UI: http://$(curl -s ifconfig.me):8080"
echo "   2. Default credentials: airflow / airflow"
echo "   3. Check service status: docker compose ps"
echo "   4. View logs: docker compose logs -f"
echo ""
echo "🔧 Useful commands:"
echo "   - Stop services: docker compose down"
echo "   - Restart services: docker compose restart"
echo "   - View logs: docker compose logs -f [service_name]"
echo "   - Access container: docker compose exec [service_name] bash"
echo ""
print_warning "Remember to update airflow.env with your actual AWS and Snowflake credentials!" 