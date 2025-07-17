#!/bin/bash

# =============================================================================
# EC2 Ubuntu Deployment Script for DynamoDB Export Application
# =============================================================================
# This script automates the deployment of the DynamoDB export application
# to a fresh Ubuntu EC2 instance.
#
# Usage:
#   1. Launch Ubuntu 20.04+ EC2 instance with appropriate IAM role
#   2. SSH into the instance
#   3. Run: curl -sSL https://raw.githubusercontent.com/your-repo/setup.sh | bash
#   OR
#   4. Upload this script and run: chmod +x deploy_to_ec2.sh && ./deploy_to_ec2.sh
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# STEP 1: System Validation and Setup
# =============================================================================
log "Starting EC2 Ubuntu deployment for DynamoDB Export Application..."
log "Step 1: System validation and initial setup..."

# Verify Ubuntu
if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
    log_error "This script requires Ubuntu. Detected: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2)"
    exit 1
fi

UBUNTU_VERSION=$(lsb_release -rs)
log_success "Ubuntu $UBUNTU_VERSION detected"

# Check if running on EC2
if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    log_success "EC2 Instance: $INSTANCE_ID ($INSTANCE_TYPE) in region $REGION"
else
    log_warning "Not running on EC2 instance"
fi

# Update system
log "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
log_success "System updated"

# =============================================================================
# STEP 2: Install Essential Dependencies
# =============================================================================
log "Step 2: Installing essential dependencies..."

# Install essential packages
log "Installing essential packages..."
sudo apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

log_success "Essential packages installed"

# Install AWS CLI v2
if ! command_exists aws; then
    log "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    log_success "AWS CLI v2 installed"
else
    log_success "AWS CLI already installed"
fi

# =============================================================================
# STEP 3: Create Application User and Directory
# =============================================================================
log "Step 3: Setting up application environment..."

# Create application user
APP_USER="ecommerce"
APP_HOME="/opt/ecommerce-app"

if ! id "$APP_USER" &>/dev/null; then
    log "Creating application user: $APP_USER"
    sudo useradd -r -m -d "$APP_HOME" -s /bin/bash "$APP_USER"
    sudo usermod -aG sudo "$APP_USER"
    log_success "User $APP_USER created"
else
    log_success "User $APP_USER already exists"
fi

# Create application directory
sudo mkdir -p "$APP_HOME"
sudo chown "$APP_USER:$APP_USER" "$APP_HOME"
log_success "Application directory created: $APP_HOME"

# =============================================================================
# STEP 4: Clone/Deploy Application Code
# =============================================================================
log "Step 4: Deploying application code..."

# Switch to application directory
cd "$APP_HOME"

# If this script is being run from a git repo, clone it
if [ -d ".git" ]; then
    log "Detected git repository, pulling latest changes..."
    sudo -u "$APP_USER" git pull
else
    # Create application files directly
    log "Creating application files..."
    
    # Create main application files (these would typically be cloned from git)
    sudo -u "$APP_USER" cat > export_to_dynamodb_enhanced.py << 'EOFPYTHON'
#!/usr/bin/env python3
"""
Enhanced DynamoDB Export Script for EC2 Deployment
Exports user segments and product recommendations from Snowflake to DynamoDB
"""

import os
import sys
import logging
import boto3
import snowflake.connector
from typing import Dict, List, Any, Optional
from datetime import datetime
import json
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/ecommerce-app/export.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class DynamoDBExporter:
    def __init__(self):
        self.snowflake_config = {
            'account': os.getenv('SNOWFLAKE_ACCOUNT'),
            'user': os.getenv('SNOWFLAKE_USER'),
            'password': os.getenv('SNOWFLAKE_PASSWORD'),
            'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'ECOMMERCE_WH'),
            'database': os.getenv('SNOWFLAKE_DATABASE', 'ECOMMERCE_DB'),
            'schema': os.getenv('SNOWFLAKE_SCHEMA', 'ANALYTICS')
        }
        
        # Initialize AWS clients
        session = boto3.Session(region_name=os.getenv('AWS_REGION', 'us-east-1'))
        self.dynamodb = session.resource('dynamodb')
        self.dynamodb_client = session.client('dynamodb')
        
        self.tables = {
            'user_segments': os.getenv('DYNAMODB_USER_SEGMENTS_TABLE', 'ecommerce_user_segments'),
            'recommendations': os.getenv('DYNAMODB_RECOMMENDATIONS_TABLE', 'ecommerce_product_recommendations')
        }

    def connect_snowflake(self):
        """Establish connection to Snowflake"""
        try:
            conn = snowflake.connector.connect(**self.snowflake_config)
            logger.info("Successfully connected to Snowflake")
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {e}")
            raise

    def create_dynamodb_tables(self):
        """Create DynamoDB tables if they don't exist"""
        
        # User segments table
        try:
            self.dynamodb_client.describe_table(TableName=self.tables['user_segments'])
            logger.info(f"Table {self.tables['user_segments']} already exists")
        except self.dynamodb_client.exceptions.ResourceNotFoundException:
            logger.info(f"Creating table {self.tables['user_segments']}")
            self.dynamodb_client.create_table(
                TableName=self.tables['user_segments'],
                KeySchema=[
                    {'AttributeName': 'user_id', 'KeyType': 'HASH'}
                ],
                AttributeDefinitions=[
                    {'AttributeName': 'user_id', 'AttributeType': 'S'}
                ],
                BillingMode='PAY_PER_REQUEST'
            )
            
            # Wait for table to be created
            waiter = self.dynamodb_client.get_waiter('table_exists')
            waiter.wait(TableName=self.tables['user_segments'])
            logger.info(f"Table {self.tables['user_segments']} created successfully")

        # Product recommendations table
        try:
            self.dynamodb_client.describe_table(TableName=self.tables['recommendations'])
            logger.info(f"Table {self.tables['recommendations']} already exists")
        except self.dynamodb_client.exceptions.ResourceNotFoundException:
            logger.info(f"Creating table {self.tables['recommendations']}")
            self.dynamodb_client.create_table(
                TableName=self.tables['recommendations'],
                KeySchema=[
                    {'AttributeName': 'user_id', 'KeyType': 'HASH'},
                    {'AttributeName': 'product_id', 'KeyType': 'RANGE'}
                ],
                AttributeDefinitions=[
                    {'AttributeName': 'user_id', 'AttributeType': 'S'},
                    {'AttributeName': 'product_id', 'AttributeType': 'S'}
                ],
                BillingMode='PAY_PER_REQUEST'
            )
            
            # Wait for table to be created
            waiter = self.dynamodb_client.get_waiter('table_exists')
            waiter.wait(TableName=self.tables['recommendations'])
            logger.info(f"Table {self.tables['recommendations']} created successfully")

    def export_user_segments(self, conn):
        """Export user segments from Snowflake to DynamoDB"""
        cursor = conn.cursor()
        
        query = """
        SELECT 
            USER_ID,
            SEGMENT,
            TOTAL_PURCHASES,
            TOTAL_SPEND,
            LAST_PURCHASE_DATE,
            DAYS_SINCE_LAST_PURCHASE
        FROM USER_SEGMENTS
        """
        
        try:
            cursor.execute(query)
            results = cursor.fetchall()
            
            table = self.dynamodb.Table(self.tables['user_segments'])
            
            # Batch write to DynamoDB
            with table.batch_writer() as batch:
                for row in results:
                    item = {
                        'user_id': str(row[0]),
                        'segment': row[1],
                        'total_purchases': int(row[2]) if row[2] else 0,
                        'total_spend': float(row[3]) if row[3] else 0.0,
                        'last_purchase_date': str(row[4]) if row[4] else '',
                        'days_since_last_purchase': int(row[5]) if row[5] else 0,
                        'updated_at': datetime.now().isoformat()
                    }
                    batch.put_item(Item=item)
            
            logger.info(f"Exported {len(results)} user segments to DynamoDB")
            return len(results)
            
        except Exception as e:
            logger.error(f"Error exporting user segments: {e}")
            raise
        finally:
            cursor.close()

    def export_recommendations(self, conn):
        """Export product recommendations from Snowflake to DynamoDB"""
        cursor = conn.cursor()
        
        query = """
        SELECT 
            USER_ID,
            PRODUCT_ID,
            RECOMMENDATION_SCORE,
            RANK
        FROM USER_PRODUCT_RECOMMENDATIONS
        """
        
        try:
            cursor.execute(query)
            results = cursor.fetchall()
            
            table = self.dynamodb.Table(self.tables['recommendations'])
            
            # Batch write to DynamoDB
            with table.batch_writer() as batch:
                for row in results:
                    item = {
                        'user_id': str(row[0]),
                        'product_id': str(row[1]),
                        'recommendation_score': float(row[2]) if row[2] else 0.0,
                        'rank': int(row[3]) if row[3] else 0,
                        'updated_at': datetime.now().isoformat()
                    }
                    batch.put_item(Item=item)
            
            logger.info(f"Exported {len(results)} product recommendations to DynamoDB")
            return len(results)
            
        except Exception as e:
            logger.error(f"Error exporting recommendations: {e}")
            raise
        finally:
            cursor.close()

    def run_export(self):
        """Main export process"""
        logger.info("Starting DynamoDB export process...")
        
        try:
            # Create tables if needed
            self.create_dynamodb_tables()
            
            # Connect to Snowflake
            conn = self.connect_snowflake()
            
            # Export data
            segments_count = self.export_user_segments(conn)
            recommendations_count = self.export_recommendations(conn)
            
            # Close connection
            conn.close()
            
            logger.info(f"Export completed successfully!")
            logger.info(f"User segments exported: {segments_count}")
            logger.info(f"Product recommendations exported: {recommendations_count}")
            
            return {
                'success': True,
                'user_segments_count': segments_count,
                'recommendations_count': recommendations_count
            }
            
        except Exception as e:
            logger.error(f"Export failed: {e}")
            return {'success': False, 'error': str(e)}

def main():
    """Main function"""
    exporter = DynamoDBExporter()
    result = exporter.run_export()
    
    if result['success']:
        print("Export completed successfully!")
        sys.exit(0)
    else:
        print(f"Export failed: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOFPYTHON

    # Create setup verification script
    sudo -u "$APP_USER" cat > setup_dynamodb_export.py << 'EOFPYTHON'
#!/usr/bin/env python3
"""
Setup verification script for DynamoDB export on EC2
"""

import os
import sys
import boto3
import snowflake.connector
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

def test_snowflake_connection():
    """Test Snowflake connection"""
    try:
        config = {
            'account': os.getenv('SNOWFLAKE_ACCOUNT'),
            'user': os.getenv('SNOWFLAKE_USER'),
            'password': os.getenv('SNOWFLAKE_PASSWORD'),
            'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'ECOMMERCE_WH'),
            'database': os.getenv('SNOWFLAKE_DATABASE', 'ECOMMERCE_DB'),
            'schema': os.getenv('SNOWFLAKE_SCHEMA', 'ANALYTICS')
        }
        
        conn = snowflake.connector.connect(**config)
        cursor = conn.cursor()
        cursor.execute("SELECT CURRENT_TIMESTAMP()")
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        
        print("✓ Snowflake connection successful")
        return True
    except Exception as e:
        print(f"✗ Snowflake connection failed: {e}")
        return False

def test_aws_credentials():
    """Test AWS credentials"""
    try:
        session = boto3.Session(region_name=os.getenv('AWS_REGION', 'us-east-1'))
        sts = session.client('sts')
        identity = sts.get_caller_identity()
        
        print(f"✓ AWS credentials valid - Account: {identity['Account']}")
        return True
    except Exception as e:
        print(f"✗ AWS credentials failed: {e}")
        return False

def test_dynamodb_access():
    """Test DynamoDB access"""
    try:
        session = boto3.Session(region_name=os.getenv('AWS_REGION', 'us-east-1'))
        dynamodb = session.client('dynamodb')
        dynamodb.list_tables()
        
        print("✓ DynamoDB access successful")
        return True
    except Exception as e:
        print(f"✗ DynamoDB access failed: {e}")
        return False

def main():
    """Main verification function"""
    print("Verifying DynamoDB export setup...")
    print("=" * 50)
    
    all_tests_passed = True
    
    # Test components
    all_tests_passed &= test_aws_credentials()
    all_tests_passed &= test_dynamodb_access()
    all_tests_passed &= test_snowflake_connection()
    
    print("=" * 50)
    if all_tests_passed:
        print("✓ All tests passed - Setup is ready!")
        sys.exit(0)
    else:
        print("✗ Some tests failed - Please check configuration")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOFPYTHON

    # Create environment template
    sudo -u "$APP_USER" cat > .env.template << 'EOFENV'
# Snowflake Configuration
SNOWFLAKE_ACCOUNT=your_account_here
SNOWFLAKE_USER=your_username_here
SNOWFLAKE_PASSWORD=your_password_here
SNOWFLAKE_WAREHOUSE=ECOMMERCE_WH
SNOWFLAKE_DATABASE=ECOMMERCE_DB
SNOWFLAKE_SCHEMA=ANALYTICS

# AWS Configuration (usually not needed on EC2 with IAM role)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# DynamoDB Configuration
DYNAMODB_USER_SEGMENTS_TABLE=ecommerce_user_segments
DYNAMODB_RECOMMENDATIONS_TABLE=ecommerce_product_recommendations
EOFENV

    log_success "Application files created"
fi

# =============================================================================
# STEP 5: Setup Python Environment
# =============================================================================
log "Step 5: Setting up Python environment..."

# Create virtual environment
sudo -u "$APP_USER" python3 -m venv "$APP_HOME/venv"
log_success "Python virtual environment created"

# Install Python dependencies
sudo -u "$APP_USER" "$APP_HOME/venv/bin/pip" install --upgrade pip

# Install required packages
sudo -u "$APP_USER" "$APP_HOME/venv/bin/pip" install \
    boto3>=1.26.0 \
    snowflake-connector-python>=3.0.0 \
    python-dotenv>=1.0.0

log_success "Python dependencies installed"

# =============================================================================
# STEP 6: Setup System Services
# =============================================================================
log "Step 6: Setting up system services..."

# Create log directory
sudo mkdir -p /var/log/ecommerce-app
sudo chown "$APP_USER:$APP_USER" /var/log/ecommerce-app
log_success "Log directory created"

# Create systemd service for the application
sudo cat > /etc/systemd/system/ecommerce-export.service << EOFSERVICE
[Unit]
Description=Ecommerce DynamoDB Export Service
After=network.target

[Service]
Type=oneshot
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_HOME
Environment=PATH=$APP_HOME/venv/bin
ExecStart=$APP_HOME/venv/bin/python export_to_dynamodb_enhanced.py
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

# Create systemd timer for scheduled exports
sudo cat > /etc/systemd/system/ecommerce-export.timer << EOFTIMER
[Unit]
Description=Run Ecommerce Export Daily
Requires=ecommerce-export.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOFTIMER

sudo systemctl daemon-reload
log_success "Systemd services created"

# =============================================================================
# STEP 7: Setup Firewall and Security
# =============================================================================
log "Step 7: Configuring security..."

# Configure UFW firewall
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 80/tcp   # HTTP

log_success "Firewall configured"

# =============================================================================
# STEP 8: Final Configuration
# =============================================================================
log "Step 8: Final configuration..."

# Make scripts executable
sudo chmod +x "$APP_HOME"/*.py

# Copy deployment script to the application directory
sudo cp "$0" "$APP_HOME/deploy_to_ec2.sh" 2>/dev/null || log_warning "Could not copy deployment script"

# Create setup completion script
sudo -u "$APP_USER" cat > "$APP_HOME/complete_setup.sh" << 'EOFCOMPLETE'
#!/bin/bash
echo "To complete the setup:"
echo "1. Edit the .env file with your Snowflake credentials:"
echo "   nano /opt/ecommerce-app/.env"
echo ""
echo "2. Test the setup:"
echo "   cd /opt/ecommerce-app && ./venv/bin/python setup_dynamodb_export.py"
echo ""
echo "3. Run the export manually:"
echo "   cd /opt/ecommerce-app && ./venv/bin/python export_to_dynamodb_enhanced.py"
echo ""
echo "4. Enable automatic daily exports:"
echo "   sudo systemctl enable ecommerce-export.timer"
echo "   sudo systemctl start ecommerce-export.timer"
echo ""
echo "5. Check service status:"
echo "   sudo systemctl status ecommerce-export.service"
echo "   sudo systemctl status ecommerce-export.timer"
EOFCOMPLETE

sudo chmod +x "$APP_HOME/complete_setup.sh"

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================
echo
log_success "=== EC2 Ubuntu Deployment Complete ==="
echo
log "Application deployed to: $APP_HOME"
log "Application user: $APP_USER"
log "Python environment: $APP_HOME/venv"
log "Log directory: /var/log/ecommerce-app"
echo
log "Next steps:"
log "1. Configure Snowflake credentials:"
log "   sudo -u $APP_USER nano $APP_HOME/.env"
echo
log "2. Test the setup:"
log "   sudo -u $APP_USER $APP_HOME/complete_setup.sh"
echo
log "3. Or run the complete setup command:"
log "   cd $APP_HOME && sudo -u $APP_USER ./venv/bin/python setup_dynamodb_export.py"
echo
log_success "Deployment completed successfully!"
echo
log "Instance Details:"
if [ ! -z "$INSTANCE_ID" ]; then
    log "Instance ID: $INSTANCE_ID"
    log "Instance Type: $INSTANCE_TYPE"
    log "Region: $REGION"
fi
log "Ubuntu Version: $UBUNTU_VERSION"
echo 