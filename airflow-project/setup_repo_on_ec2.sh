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
echo "Setting up Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=\\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \\$(. /etc/os-release && echo "\\$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y

# Install Docker Engine, CLI, Containerd, and Compose plugin
echo "Installing Docker components..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker and enable it to start on boot
echo "Starting and enabling Docker..."
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -a -G docker ubuntu

# Configure Docker daemon for better performance and security
echo "Configuring Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKER_DAEMON'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "default-ulimits": {
        "nofile": {
            "Hard": 64000,
            "Name": "nofile",
            "Soft": 64000
        }
    }
}
DOCKER_DAEMON

# Restart Docker to apply configuration
systemctl restart docker

# Verify Docker installation
echo "Verifying Docker installation..."
docker --version
docker compose version

# Clone the project repository
cd /home/ubuntu
git clone "$PROJECT_REPO_URL"
chown -R ubuntu:ubuntu "$PROJECT_DIR_NAME"

# Navigate to airflow-project directory and set up
cd /home/ubuntu/$PROJECT_DIR_NAME/airflow-project

# Create necessary directories with proper permissions
echo "Creating Airflow directories..."
mkdir -p dags logs plugins jobs
chown -R 50000:0 dags logs plugins jobs

echo "✅ EC2 setup completed successfully!"
echo "🚀 You can now SSH into the instance and start Airflow"
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

# Convert IP to AWS DNS format (replace dots with dashes)
AWS_DNS_NAME="ec2-$(echo $PUBLIC_IP | tr '.' '-').compute-1.amazonaws.com"

# --- 4. Display Final Information ---
echo "------------------------------------------------------------------"
echo "✅ EC2 Instance is now running!"
echo
echo "   Instance ID: $INSTANCE_ID"
echo "   Public IP Address: $PUBLIC_IP"
echo "   AWS DNS Name: $AWS_DNS_NAME"
echo "   SSH Command: ssh -i \"$KEY_NAME.pem\" ubuntu@$AWS_DNS_NAME"
echo
echo "   IMPORTANT NEXT STEPS:"
echo "   1. From your local machine, navigate to the directory containing your key:"
echo "      cd C:\\Users\\mccal\\Downloads\\OnlineRetailProject\\airflow-project"
echo "   2. SSH into your new EC2 instance using the command printed above."
echo "   3. Navigate to the project folder on the server: cd ~/OnlineRetailProject/airflow-project"
echo "   4. Start Airflow using the setup script: ./setup_airflow_instance.sh"
echo
echo "   Airflow UI will be available at: http://$PUBLIC_IP:8080"
echo "   Spark Master UI will be available at: http://$PUBLIC_IP:9090"
echo "------------------------------------------------------------------"
echo "Note: It may take a few minutes for the EC2 instance to boot and for services to start." 