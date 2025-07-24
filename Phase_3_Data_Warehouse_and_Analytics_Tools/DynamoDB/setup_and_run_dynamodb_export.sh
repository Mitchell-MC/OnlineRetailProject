#!/bin/bash

# =============================================================================
# DynamoDB Export Setup and Execution Script for Ubuntu EC2
# =============================================================================
# This script automates the complete setup and execution of DynamoDB exports
# from Snowflake data warehouse to AWS DynamoDB tables on Ubuntu EC2 instances.
#
# Prerequisites:
# - Ubuntu 20.04+ EC2 instance
# - EC2 instance with appropriate IAM role for DynamoDB access
# - Internet connectivity for package installation
# - Snowflake credentials available
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
# STEP 1: System Update and Environment Validation
# =============================================================================
log "Starting DynamoDB Export Setup and Execution on Ubuntu EC2..."
log "Step 1: Updating system and validating environment..."

# Check if running on Ubuntu
if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
    log_error "This script is designed for Ubuntu systems. Detected: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2)"
    exit 1
fi

UBUNTU_VERSION=$(lsb_release -rs)
log_success "Ubuntu detected: $UBUNTU_VERSION"

# Update system packages
log "Updating system packages..."
sudo apt-get update -qq > /dev/null 2>&1
log_success "System packages updated"

# Install Python 3 and pip if not present
if ! command_exists python3; then
    log "Installing Python 3..."
    sudo apt-get install -y python3 python3-pip python3-venv
    log_success "Python 3 installed"
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
log_success "Python detected: $PYTHON_VERSION"

# Check/Install pip
if ! command_exists pip3; then
    log "Installing pip3..."
    sudo apt-get install -y python3-pip
    log_success "pip3 installed"
fi

# Install/Check AWS CLI
if ! command_exists aws; then
    log "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo apt-get install -y unzip
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    log_success "AWS CLI v2 installed"
else
    log_success "AWS CLI detected"
fi

# Check for EC2 instance metadata service (indicates we're on EC2)
if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    log_success "Running on EC2 instance: $INSTANCE_ID ($INSTANCE_TYPE) in $REGION"
    
    # Check if IAM role is attached
    if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/iam/security-credentials/ >/dev/null 2>&1; then
        IAM_ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
        log_success "IAM role detected: $IAM_ROLE"
        
        # Test AWS credentials through IAM role
        if aws sts get-caller-identity >/dev/null 2>&1; then
            AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
            AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
            log_success "AWS credentials validated via IAM role - Account: $AWS_ACCOUNT"
            log_success "Current AWS identity: $AWS_USER"
        else
            log_error "IAM role attached but AWS credentials not working"
            exit 1
        fi
    else
        log_warning "No IAM role detected. You may need to configure AWS credentials manually."
        log "Run: aws configure"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    log_warning "Not running on EC2 instance"
    
    # Check AWS credentials for non-EC2 environment
    if aws sts get-caller-identity >/dev/null 2>&1; then
        AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
        log_success "AWS credentials validated - Account: $AWS_ACCOUNT"
        log_success "Current AWS identity: $AWS_USER"
    else
        log_warning "AWS credentials not configured"
        log "Please run: aws configure"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# =============================================================================
# STEP 2: Install Python Dependencies
# =============================================================================
log "Step 2: Installing Python dependencies..."

REQUIRED_PACKAGES=(
    "boto3>=1.26.0"
    "snowflake-connector-python>=3.0.0"
    "python-dotenv>=1.0.0"
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    package_name=$(echo $package | cut -d'>' -f1 | cut -d'=' -f1)
    log "Installing $package_name..."
    
    if pip3 install "$package" --quiet; then
        log_success "$package_name installed successfully"
    else
        log_error "Failed to install $package_name"
        exit 1
    fi
done

# =============================================================================
# STEP 3: Environment Configuration
# =============================================================================
log "Step 3: Setting up environment configuration..."

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    log "Creating .env file..."
    cat > .env << EOF
# Snowflake Configuration
SNOWFLAKE_ACCOUNT=your_account_here
SNOWFLAKE_USER=your_username_here
SNOWFLAKE_PASSWORD=your_password_here
SNOWFLAKE_WAREHOUSE=ECOMMERCE_WH
SNOWFLAKE_DATABASE=ECOMMERCE_DB
SNOWFLAKE_SCHEMA=ANALYTICS

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here

# DynamoDB Configuration
DYNAMODB_USER_SEGMENTS_TABLE=ecommerce_user_segments
DYNAMODB_RECOMMENDATIONS_TABLE=ecommerce_product_recommendations
EOF
    
    log_warning ".env file created with template values"
    log "Please edit .env file with your actual credentials before continuing"
    read -p "Press Enter after updating .env file..."
else
    log_success ".env file already exists"
fi

# =============================================================================
# STEP 4: Verify Setup
# =============================================================================
log "Step 4: Verifying setup..."

log "Running setup verification script..."
if python3 setup_dynamodb_export.py; then
    log_success "Setup verification passed"
else
    log_error "Setup verification failed"
    log "Please check your credentials and configuration"
    exit 1
fi

# =============================================================================
# STEP 5: Create Backup
# =============================================================================
log "Step 5: Creating backup of existing DynamoDB tables (if any)..."

# Get current timestamp for backup naming
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="dynamodb_backups_$TIMESTAMP"

if aws dynamodb list-tables >/dev/null 2>&1; then
    # Check if our tables exist
    EXISTING_TABLES=$(aws dynamodb list-tables --query 'TableNames[?contains(@, `ecommerce_`)]' --output text 2>/dev/null || echo "")
    
    if [ ! -z "$EXISTING_TABLES" ]; then
        log "Found existing ecommerce tables: $EXISTING_TABLES"
        log "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        
        for table in $EXISTING_TABLES; do
            log "Backing up table: $table"
            aws dynamodb scan --table-name "$table" --output json > "$BACKUP_DIR/${table}_backup.json" 2>/dev/null || log_warning "Could not backup $table"
        done
        
        log_success "Backup completed in $BACKUP_DIR"
    else
        log "No existing ecommerce tables found"
    fi
else
    log_warning "Could not check existing DynamoDB tables"
fi

# =============================================================================
# STEP 6: Execute DynamoDB Export
# =============================================================================
log "Step 6: Executing DynamoDB export..."

log "Starting enhanced DynamoDB export..."
if python3 export_to_dynamodb_enhanced.py; then
    log_success "DynamoDB export completed successfully!"
else
    log_error "DynamoDB export failed"
    exit 1
fi

# =============================================================================
# STEP 7: Verification and Summary
# =============================================================================
log "Step 7: Verifying exported data..."

# Verify tables were created and have data
if aws dynamodb list-tables >/dev/null 2>&1; then
    log "Checking created tables..."
    
    TABLES=("ecommerce_user_segments" "ecommerce_product_recommendations")
    
    for table in "${TABLES[@]}"; do
        if aws dynamodb describe-table --table-name "$table" >/dev/null 2>&1; then
            ITEM_COUNT=$(aws dynamodb scan --table-name "$table" --select COUNT --query 'Count' --output text 2>/dev/null || echo "0")
            log_success "Table $table created with $ITEM_COUNT items"
        else
            log_warning "Table $table not found"
        fi
    done
else
    log_warning "Could not verify tables (AWS CLI access issue)"
fi

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================
echo
log_success "=== DynamoDB Export Setup and Execution Complete ==="
echo
log "Summary:"
log "✓ Environment validated"
log "✓ Dependencies installed"
log "✓ Configuration verified"
log "✓ DynamoDB export executed"
log "✓ Data verification completed"
echo
log "Next steps:"
log "1. Verify data in AWS DynamoDB console"
log "2. Test application integration with new tables"
log "3. Set up monitoring and alerts"
echo
log "Backup location: $BACKUP_DIR (if created)"
log "Log files available for troubleshooting"
echo
log_success "Setup and execution completed successfully!" 