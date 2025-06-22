#!/bin/bash

# ==============================================================================
# Configuration Section: Edit these variables to match your setup
# ==============================================================================
AWS_REGION="us-east-1"
KEY_NAME="retail_airflow_key" # The name of your .pem file for SSH access
INSTANCE_TYPE="t3.medium" # t2.medium or larger is recommended
AMI_ID="ami-0f3f13f145e66a0a3" # Amazon Linux 2 AMI for us-east-1
PROJECT_REPO_URL="https://github.com/Mitchell-MC/OnlineRetailProject.git" # Your project's Git repo URL
SECURITY_GROUP_NAME="airflow-sg"

# ==============================================================================
# Secure Credential Input: The script will now prompt for secrets.
# ==============================================================================
echo "Please enter your credentials. For passwords/secrets, typing will be hidden."

read -p "Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -s -p "Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""
read -s -p "Enter your Snowflake Password: " SNOWFLAKE_PASS
echo ""

# Static credentials from your project setup
AIRFLOW_USER="admin"
AIRFLOW_PASS="admin"
SNOWFLAKE_USER="MITCHELLMCC"
SNOWFLAKE_ACCOUNT="KLRPPBG-NEC57960"

# ==============================================================================
# Script Execution
# ==============================================================================
echo "Starting setup process in region: $AWS_REGION"

# --- 1. Check for and Create Security Group (Idempotent Logic) ---
echo "Checking for security group '$SECURITY_GROUP_NAME'..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --group-names "$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text --region "$AWS_REGION" 2>/dev/null)

if [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Security Group '$SECURITY_GROUP_NAME' not found. Creating a new one..."
    SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Security group for Airflow EC2" --output text --query 'GroupId' --region "$AWS_REGION")
    
    echo "Adding ingress rules..."
    aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    
    echo "Security Group created with ID: $SECURITY_GROUP_ID"
else
    echo "Security Group '$SECURITY_GROUP_NAME' already exists. Using existing ID: $SECURITY_GROUP_ID"
fi


# --- 2. Define User Data Script for EC2 Instance ---
echo "Preparing setup script for the new instance..."
PROJECT_DIR_NAME=$(basename "$PROJECT_REPO_URL" .git)

USER_DATA=$(cat <<EOF
#!/bin/bash
# Update and install dependencies
yum update -y
yum install -y docker git

# Start Docker and enable it to start on boot
service docker start
usermod -a -G docker ec2-user

# Install Docker Compose v2
DOCKER_COMPOSE_VERSION="v2.27.0"
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/\\$DOCKER_COMPOSE_VERSION/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Clone the project repository
cd /home/ec2-user
git clone "$PROJECT_REPO_URL"

# Navigate to the project directory
cd "$PROJECT_DIR_NAME/airflow-project"

# Create .env file for docker-compose
cat > .env <<EOL
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
SNOWFLAKE_USER=$SNOWFLAKE_USER
SNOWFLAKE_PASSWORD=$SNOWFLAKE_PASS
SNOWFLAKE_ACCOUNT=$SNOWFLAKE_ACCOUNT
AIRFLOW_UID=\$(id -u)
AIRFLOW_GID=0
EOL

# Initialize and start Airflow services using Docker Compose
docker compose up -d
EOF
)

# --- 3. Launch EC2 Instance ---
echo "Launching EC2 instance ($INSTANCE_TYPE)..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data "$USER_DATA" \
    --output text --query 'Instances[0].InstanceId' --region "$AWS_REGION")

echo "Instance created with ID: $INSTANCE_ID. Waiting for it to become available..."

# Wait for the instance to be in the 'running' state
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

# Get the public IP address of the instance
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --output text --query 'Reservations[0].Instances[0].PublicIpAddress' --region "$AWS_REGION")

# --- 4. Display Final Information ---
echo "--------------------------------------------------"
echo "✅ EC2 Instance is now running!"
echo
echo "   Public IP Address: $PUBLIC_IP"
echo "   SSH Command: ssh -i \"$KEY_NAME.pem\" ec2-user@$PUBLIC_IP"
echo "   Airflow UI: http://$PUBLIC_IP:8080"
echo
echo "   Username: $AIRFLOW_USER"
echo "   Password: $AIRFLOW_PASS"
echo "--------------------------------------------------"
echo "Note: It may take a few minutes for the Airflow services to fully start. Please be patient."