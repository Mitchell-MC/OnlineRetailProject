#!/bin/bash
set -e

# Define AWS CLI path
AWS_CLI="/c/Progra~1/Amazon/AWSCLIV2/aws.exe"

# ============================================================================== 
# Configuration Section
# ==============================================================================
AWS_REGION="us-east-1"
KEY_NAME="3A_Pipe_EC2"
INSTANCE_TYPE="t3.medium"
AMI_ID="ami-0a7d80731ae1b2435" # Ubuntu Server 22.04 LTS AMI for us-east-1
PROJECT_REPO_URL="https://github.com/Mitchell-MC/OnlineRetailProject.git"
SECURITY_GROUP_NAME="airflow-ec2-sg"
ROOT_VOLUME_SIZE=30 # NEW: Set the root EBS volume size in GiB

# ==============================================================================
# Script Execution
# ==============================================================================
echo "Starting setup process in region: $AWS_REGION"

# Test AWS CLI connectivity
echo "Testing AWS CLI connectivity..."
"$AWS_CLI" sts get-caller-identity || { echo "AWS CLI not configured properly"; exit 1; }

# --- 1. Check for and Create Security Group (Idempotent Logic) ---
echo "Checking for security group '$SECURITY_GROUP_NAME'..."
SECURITY_GROUP_ID=$("$AWS_CLI" ec2 describe-security-groups --group-names "$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Security Group '$SECURITY_GROUP_NAME' not found. Creating a new one..."
    SECURITY_GROUP_ID=$("$AWS_CLI" ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Security group for Airflow EC2" --output text --query 'GroupId' --region "$AWS_REGION")
    
    if [ -z "$SECURITY_GROUP_ID" ]; then
        echo "Failed to create security group"
        exit 1
    fi
    
    echo "Adding ingress rules..."
    "$AWS_CLI" ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    "$AWS_CLI" ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$AWS_REGION" # For Airflow UI
    "$AWS_CLI" ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 9090 --cidr 0.0.0.0/0 --region "$AWS_REGION" # For Spark Master UI
    
    echo "Security Group created with ID: $SECURITY_GROUP_ID"
else
    echo "Security Group '$SECURITY_GROUP_NAME' already exists. Using existing ID: $SECURITY_GROUP_ID"
fi


# --- 2. Define User Data Script for EC2 Instance ---
echo "Preparing setup script for the new Ubuntu instance..."
PROJECT_DIR_NAME=$(basename "$PROJECT_REPO_URL" .git)

USER_DATA=$(cat <<EOF
#!/bin/bash
# Update and install initial dependencies
apt-get update -y
apt-get install -y ca-certificates curl git

# Set up Docker's official repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=\\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \\$(. /etc/os-release && echo "\\$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y

# Install Docker Engine, CLI, Containerd, and Compose plugin
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker and enable it to start on boot
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu

# Clone the project repository
cd /home/ubuntu
git clone "$PROJECT_REPO_URL"
chown -R ubuntu:ubuntu "$PROJECT_DIR_NAME"

# Set up Cursor development environment
echo "Setting up Cursor development environment..."

# Install additional development tools
apt-get install -y python3-pip python3-venv nodejs npm

# Create .cursorrules file for project-specific AI assistance
cat > /home/ubuntu/$PROJECT_DIR_NAME/.cursorrules << 'CURSOR_RULES'
# Online Retail Project - Cursor AI Assistant Rules

## Project Overview
This is an Online Retail Project that uses:
- Apache Airflow for data orchestration
- Apache Kafka for real-time streaming
- Apache Spark for data processing
- AWS services (EC2, S3, etc.)
- Docker for containerization

## Code Style Guidelines
- Use Python 3.8+ syntax
- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Add docstrings to functions and classes
- Use meaningful variable and function names

## Architecture Patterns
- Use dependency injection for services
- Implement proper error handling and logging
- Follow the principle of separation of concerns
- Use configuration files for environment-specific settings

## File Organization
- Keep related functionality in the same directory
- Use descriptive file names
- Separate configuration from business logic
- Maintain clear import hierarchies

## Testing
- Write unit tests for critical functions
- Use pytest for testing framework
- Mock external dependencies
- Test both success and failure scenarios

## Documentation
- Update README files when adding new features
- Document API endpoints and their parameters
- Include setup and deployment instructions
- Add inline comments for complex logic

## Security
- Never commit sensitive credentials
- Use environment variables for secrets
- Validate all user inputs
- Follow AWS security best practices

## Performance
- Optimize database queries
- Use appropriate data structures
- Implement caching where beneficial
- Monitor resource usage
CURSOR_RULES

# Create .vscode/settings.json for consistent development environment
mkdir -p /home/ubuntu/$PROJECT_DIR_NAME/.vscode
cat > /home/ubuntu/$PROJECT_DIR_NAME/.vscode/settings.json << 'VSCODE_SETTINGS'
{
    "python.defaultInterpreterPath": "/usr/bin/python3",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.formatting.provider": "black",
    "python.formatting.blackArgs": ["--line-length=88"],
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": true
    },
    "files.exclude": {
        "**/__pycache__": true,
        "**/*.pyc": true,
        "**/.pytest_cache": true,
        "**/venv": true,
        "**/.env": true
    },
    "python.testing.pytestEnabled": true,
    "python.testing.unittestEnabled": false,
    "python.testing.pytestArgs": [
        "."
    ],
    "terminal.integrated.defaultProfile.linux": "bash",
    "docker.showStartPage": false,
    "git.enableSmartCommit": true,
    "git.confirmSync": false
}
VSCODE_SETTINGS

# Create .vscode/extensions.json for recommended extensions
cat > /home/ubuntu/$PROJECT_DIR_NAME/.vscode/extensions.json << 'EXTENSIONS_JSON'
{
    "recommendations": [
        "ms-python.python",
        "ms-python.black-formatter",
        "ms-python.pylint",
        "ms-azuretools.vscode-docker",
        "ms-vscode.vscode-json",
        "redhat.vscode-yaml",
        "ms-vscode.vscode-git",
        "ms-vscode.vscode-git-graph",
        "eamodio.gitlens",
        "ms-vscode.vscode-kubernetes-tools",
        "ms-vscode.vscode-helm",
        "ms-vscode.vscode-markdown",
        "ms-vscode.vscode-jupyter"
    ]
}
EXTENSIONS_JSON

# Create .vscode/launch.json for debugging configuration
cat > /home/ubuntu/$PROJECT_DIR_NAME/.vscode/launch.json << 'LAUNCH_JSON'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: Current File",
            "type": "python",
            "request": "launch",
            "program": "${file}",
            "console": "integratedTerminal",
            "cwd": "${workspaceFolder}",
            "env": {
                "PYTHONPATH": "${workspaceFolder}"
            }
        },
        {
            "name": "Python: Airflow DAG",
            "type": "python",
            "request": "launch",
            "program": "${workspaceFolder}/airflow-project/dags/ecommerce_daily_sdk.py",
            "console": "integratedTerminal",
            "cwd": "${workspaceFolder}/airflow-project",
            "env": {
                "PYTHONPATH": "${workspaceFolder}/airflow-project"
            }
        },
        {
            "name": "Python: Kafka Producer",
            "type": "python",
            "request": "launch",
            "program": "${workspaceFolder}/producer.py",
            "console": "integratedTerminal",
            "cwd": "${workspaceFolder}",
            "env": {
                "PYTHONPATH": "${workspaceFolder}"
            }
        }
    ]
}
LAUNCH_JSON

# Set proper permissions
chown -R ubuntu:ubuntu /home/ubuntu/$PROJECT_DIR_NAME/.vscode
chown -R ubuntu:ubuntu /home/ubuntu/$PROJECT_DIR_NAME/.cursorrules

echo "Cursor development environment setup complete!"

# Create development environment setup script
cat > /home/ubuntu/$PROJECT_DIR_NAME/setup_dev_env.sh << 'DEV_SETUP'
#!/bin/bash
set -e

echo "Setting up development environment..."

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install development dependencies
pip install black pylint pytest pytest-cov mypy

# Install project dependencies
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
fi

# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Create .env.example if it doesn't exist
if [ ! -f ".env.example" ]; then
    cat > .env.example << 'ENV_EXAMPLE'
# Airflow Configuration
AIRFLOW__CORE__EXECUTOR=LocalExecutor
AIRFLOW__CORE__SQL_ALCHEMY_CONN=sqlite:////home/ubuntu/airflow.db
AIRFLOW__CORE__FERNET_KEY=your_fernet_key_here
AIRFLOW__CORE__LOAD_EXAMPLES=False

# AWS Configuration
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_DEFAULT_REGION=us-east-1

# Snowflake Configuration
SNOWFLAKE_ACCOUNT=your_snowflake_account
SNOWFLAKE_USER=your_snowflake_user
SNOWFLAKE_PASSWORD=your_snowflake_password
SNOWFLAKE_WAREHOUSE=your_warehouse
SNOWFLAKE_DATABASE=your_database
SNOWFLAKE_SCHEMA=your_schema

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
KAFKA_TOPIC=user_events

# Spark Configuration
SPARK_MASTER_URL=spark://localhost:7077
SPARK_DRIVER_MEMORY=1g
SPARK_EXECUTOR_MEMORY=1g
ENV_EXAMPLE
fi

echo "Development environment setup complete!"
echo "To activate the virtual environment, run: source venv/bin/activate"
DEV_SETUP

# Make the development setup script executable
chmod +x /home/ubuntu/$PROJECT_DIR_NAME/setup_dev_env.sh
chown ubuntu:ubuntu /home/ubuntu/$PROJECT_DIR_NAME/setup_dev_env.sh

# Create a .gitignore template if it doesn't exist
if [ ! -f "/home/ubuntu/$PROJECT_DIR_NAME/.gitignore" ]; then
    cat > /home/ubuntu/$PROJECT_DIR_NAME/.gitignore << 'GITIGNORE'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual Environment
venv/
env/
ENV/

# Environment Variables
.env
.env.local
.env.*.local

# IDE
.vscode/settings.json
.idea/
*.swp
*.swo
*~

# Logs
*.log
logs/

# Airflow
airflow.db
airflow-webserver.pid
standalone_admin_password.txt

# Docker
.dockerignore

# AWS
.aws/

# Testing
.pytest_cache/
.coverage
htmlcov/

# OS
.DS_Store
Thumbs.db
GITIGNORE
fi

chown ubuntu:ubuntu /home/ubuntu/$PROJECT_DIR_NAME/.gitignore
EOF
)

# --- 3. Launch EC2 Instance ---
echo "Launching EC2 instance ($INSTANCE_TYPE) with a ${ROOT_VOLUME_SIZE}GiB root volume..."
RUN_INSTANCES_OUTPUT=$("$AWS_CLI" ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data "$USER_DATA" \
    --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":${ROOT_VOLUME_SIZE},\"VolumeType\":\"gp3\"}}]" \
    --output text --query 'Instances[0].InstanceId' --region "$AWS_REGION" 2>&1)

if echo "$RUN_INSTANCES_OUTPUT" | grep -q '^i-'; then
    INSTANCE_ID="$RUN_INSTANCES_OUTPUT"
    echo "Instance created with ID: $INSTANCE_ID. Waiting for it to become available..."
else
    echo "Failed to launch EC2 instance. Output was:"
    echo "$RUN_INSTANCES_OUTPUT"
    exit 1
fi

# Wait for the instance to be in the 'running' state
"$AWS_CLI" ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" || { echo "Instance did not reach running state"; exit 1; }

# Get the public IP address of the instance
PUBLIC_IP=$("$AWS_CLI" ec2 describe-instances --instance-ids "$INSTANCE_ID" --output text --query 'Reservations[0].Instances[0].PublicIpAddress' --region "$AWS_REGION")
if [ -z "$PUBLIC_IP" ]; then
    echo "Failed to retrieve public IP address for instance $INSTANCE_ID"
    exit 1
fi

# --- 4. Display Final Information ---
echo "------------------------------------------------------------------"
echo "✅ EC2 Instance is now running!"
echo
echo "   Public IP Address: $PUBLIC_IP"
echo "   SSH Command: ssh -i \"$KEY_NAME.pem\" ubuntu@$PUBLIC_IP"
echo
echo "   IMPORTANT NEXT STEPS:"
echo "   1. From your local machine, navigate to the directory containing your key:"
echo "      cd path/to/OnlineRetailProject/airlfow-project"
echo "   2. SSH into your new EC2 instance using the command printed above."
echo "   3. Navigate to the project folder on the server: cd ~/$PROJECT_DIR_NAME"
echo "   4. Create the environment file: nano .env"
echo "   5. Copy the contents from your local 'env.example' file and paste them into nano."
echo "   6. Fill in your secret credentials in the .env file on the server and save it."
echo "   7. Run Airflow: docker compose up -d"
echo
echo "   Airflow UI will be available at: http://$PUBLIC_IP:8080"
echo "   Spark Master UI will be available at: http://$PUBLIC_IP:9090"
echo "------------------------------------------------------------------"
echo "Note: It may take a few minutes for the EC2 instance to boot and for services to start."

