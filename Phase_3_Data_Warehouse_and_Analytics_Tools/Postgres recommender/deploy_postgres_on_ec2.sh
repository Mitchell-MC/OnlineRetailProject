#!/bin/bash

# =============================================================================
# PostgreSQL Analytics Database Deployment Script for Ubuntu EC2
# =============================================================================
# This script automates the complete deployment of PostgreSQL analytics database
# on Ubuntu EC2 instances for Phase 3 data warehouse.
#
# Usage: 
#   chmod +x deploy_postgres_on_ec2.sh
#   sudo ./deploy_postgres_on_ec2.sh
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
log "Starting PostgreSQL Analytics Database deployment on Ubuntu EC2..."
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
apt-get update -qq
apt-get upgrade -y -qq
log_success "System updated"

# =============================================================================
# STEP 2: Install PostgreSQL
# =============================================================================
log "Step 2: Installing PostgreSQL..."

# Install PostgreSQL and required packages
log "Installing PostgreSQL 15 and dependencies..."
apt-get install -y \
    wget \
    ca-certificates \
    software-properties-common \
    apt-transport-https \
    lsb-release \
    gnupg

# Add PostgreSQL official repository
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Update package list
apt-get update -qq

# Install PostgreSQL 15
apt-get install -y postgresql-15 postgresql-client-15 postgresql-contrib-15

log_success "PostgreSQL 15 installed"

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql
log_success "PostgreSQL service started and enabled"

# =============================================================================
# STEP 3: Configure PostgreSQL
# =============================================================================
log "Step 3: Configuring PostgreSQL..."

# Set postgres user password
POSTGRES_PASSWORD=$(openssl rand -base64 32)
log "Setting postgres user password..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"

# Create application user
APP_USER="ecommerce_app"
APP_PASSWORD=$(openssl rand -base64 32)
log "Creating application user: $APP_USER"
sudo -u postgres createuser --createdb --no-superuser --no-createrole "$APP_USER"
sudo -u postgres psql -c "ALTER USER $APP_USER PASSWORD '$APP_PASSWORD';"

# Create analytics database
log "Creating ecommerce_analytics database..."
sudo -u postgres createdb ecommerce_analytics -O "$APP_USER"

# Configure PostgreSQL for external connections
log "Configuring PostgreSQL for external connections..."

# Backup original config
cp /etc/postgresql/15/main/postgresql.conf /etc/postgresql/15/main/postgresql.conf.backup
cp /etc/postgresql/15/main/pg_hba.conf /etc/postgresql/15/main/pg_hba.conf.backup

# Update postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/15/main/postgresql.conf
sed -i "s/#port = 5432/port = 5432/" /etc/postgresql/15/main/postgresql.conf

# Update pg_hba.conf for application access
echo "host    ecommerce_analytics    $APP_USER    0.0.0.0/0    md5" >> /etc/postgresql/15/main/pg_hba.conf
echo "host    ecommerce_analytics    postgres     0.0.0.0/0    md5" >> /etc/postgresql/15/main/pg_hba.conf

# Restart PostgreSQL to apply config changes
systemctl restart postgresql
log_success "PostgreSQL configured and restarted"

# =============================================================================
# STEP 4: Setup Database Schema
# =============================================================================
log "Step 4: Setting up database schema..."

# Create schema setup script location
SCHEMA_DIR="/opt/ecommerce-postgres"
mkdir -p "$SCHEMA_DIR"

# Check if schema file exists, if not create it
if [ ! -f "postgres_schema_setup.sql" ]; then
    log "Creating PostgreSQL schema setup script..."
    cat > "$SCHEMA_DIR/postgres_schema_setup.sql" << 'EOFSCHEMA'
-- =============================================================================
-- PostgreSQL Analytics Database Schema Setup
-- =============================================================================

-- Connect to the database
\c ecommerce_analytics;

-- Create analytics schema
CREATE SCHEMA IF NOT EXISTS analytics;
SET search_path TO analytics;

-- Staging Events Cart Table
DROP TABLE IF EXISTS stg_events_cart CASCADE;
CREATE TABLE stg_events_cart (
    user_id VARCHAR(50) NOT NULL,
    event_time TIMESTAMP NOT NULL,
    event_type VARCHAR(20) NOT NULL DEFAULT 'cart',
    product_id VARCHAR(50),
    price DECIMAL(10,2),
    brand VARCHAR(100),
    category_code VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Staging Events Purchase Table
DROP TABLE IF EXISTS stg_events_purchase CASCADE;
CREATE TABLE stg_events_purchase (
    user_id VARCHAR(50) NOT NULL,
    event_time TIMESTAMP NOT NULL,
    event_type VARCHAR(20) NOT NULL DEFAULT 'purchase',
    product_id VARCHAR(50),
    price DECIMAL(10,2),
    brand VARCHAR(100),
    category_code VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Staging Events View Table
DROP TABLE IF EXISTS stg_events_view CASCADE;
CREATE TABLE stg_events_view (
    user_id VARCHAR(50) NOT NULL,
    event_time TIMESTAMP NOT NULL,
    event_type VARCHAR(20) NOT NULL DEFAULT 'view',
    product_id VARCHAR(50),
    price DECIMAL(10,2),
    brand VARCHAR(100),
    category_code VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customer 360 Profile Table
DROP TABLE IF EXISTS customer_360_profile CASCADE;
CREATE TABLE customer_360_profile (
    user_id VARCHAR(50) PRIMARY KEY,
    favorite_brand VARCHAR(100),
    most_viewed_category VARCHAR(200),
    total_purchases INTEGER DEFAULT 0,
    total_spend DECIMAL(12,2) DEFAULT 0.00,
    last_seen_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Segments Table
DROP TABLE IF EXISTS user_segments CASCADE;
CREATE TABLE user_segments (
    user_id VARCHAR(50) PRIMARY KEY,
    segment VARCHAR(20) NOT NULL,
    total_purchases INTEGER DEFAULT 0,
    total_spend DECIMAL(12,2) DEFAULT 0.00,
    last_purchase_date TIMESTAMP,
    days_since_last_purchase INTEGER,
    segment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_segment CHECK (segment IN ('Regular Customer', 'New Customer'))
);

-- User Product Recommendations Table
DROP TABLE IF EXISTS user_product_recommendations CASCADE;
CREATE TABLE user_product_recommendations (
    recommendation_id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    recommendation_score DECIMAL(5,3) DEFAULT 0.000,
    rank INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id)
);

-- Product Analytics Table
DROP TABLE IF EXISTS product_analytics CASCADE;
CREATE TABLE product_analytics (
    product_id VARCHAR(50) PRIMARY KEY,
    brand VARCHAR(100),
    category_code VARCHAR(200),
    total_views INTEGER DEFAULT 0,
    total_cart_adds INTEGER DEFAULT 0,
    total_purchases INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0.00,
    unique_viewers INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5,4) DEFAULT 0.0000,
    avg_price DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_stg_cart_user_time ON stg_events_cart(user_id, event_time);
CREATE INDEX IF NOT EXISTS idx_stg_purchase_user_time ON stg_events_purchase(user_id, event_time);
CREATE INDEX IF NOT EXISTS idx_stg_view_user_time ON stg_events_view(user_id, event_time);
CREATE INDEX IF NOT EXISTS idx_user_segments_segment ON user_segments(segment);
CREATE INDEX IF NOT EXISTS idx_recommendations_user ON user_product_recommendations(user_id);

-- Grant permissions
GRANT USAGE ON SCHEMA analytics TO ecommerce_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA analytics TO ecommerce_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA analytics TO ecommerce_app;

SELECT 'PostgreSQL Analytics Schema Setup Complete!' as status;
EOFSCHEMA
else
    # Copy existing schema file
    cp postgres_schema_setup.sql "$SCHEMA_DIR/"
fi

# Run schema setup
log "Executing schema setup..."
sudo -u postgres psql -f "$SCHEMA_DIR/postgres_schema_setup.sql"
log_success "Database schema created"

# =============================================================================
# STEP 5: Install Python Environment
# =============================================================================
log "Step 5: Setting up Python environment..."

# Install Python and pip
apt-get install -y python3 python3-pip python3-venv python3-dev

# Create application directory
APP_HOME="/opt/ecommerce-postgres"
mkdir -p "$APP_HOME"

# Create virtual environment
python3 -m venv "$APP_HOME/venv"

# Install Python dependencies
"$APP_HOME/venv/bin/pip" install --upgrade pip
"$APP_HOME/venv/bin/pip" install \
    psycopg2-binary \
    snowflake-connector-python \
    python-dotenv

log_success "Python environment setup complete"

# =============================================================================
# STEP 6: Setup Application Files
# =============================================================================
log "Step 6: Setting up application files..."

# Create environment file
cat > "$APP_HOME/.env" << EOFENV
# Snowflake Configuration
SNOWFLAKE_ACCOUNT=your_account_here
SNOWFLAKE_USER=your_username_here
SNOWFLAKE_PASSWORD=your_password_here
SNOWFLAKE_WAREHOUSE=ECOMMERCE_WH
SNOWFLAKE_DATABASE=ECOMMERCE_DB
SNOWFLAKE_SCHEMA=ANALYTICS

# PostgreSQL Configuration
POSTGRES_HOST=localhost
POSTGRES_DATABASE=ecommerce_analytics
POSTGRES_USER=$APP_USER
POSTGRES_PASSWORD=$APP_PASSWORD
POSTGRES_PORT=5432
EOFENV

# Copy export script if it exists
if [ -f "export_to_postgres_enhanced.py" ]; then
    cp export_to_postgres_enhanced.py "$APP_HOME/"
else
    log "Creating basic export script..."
    cat > "$APP_HOME/export_to_postgres_enhanced.py" << 'EOFPYTHON'
#!/usr/bin/env python3
import os
import sys
import logging
from dotenv import load_dotenv

load_dotenv()

def main():
    print("PostgreSQL export script ready!")
    print("Configure Snowflake credentials in .env file to enable export")
    
if __name__ == "__main__":
    main()
EOFPYTHON
fi

chmod +x "$APP_HOME/export_to_postgres_enhanced.py"

# =============================================================================
# STEP 7: Configure Firewall
# =============================================================================
log "Step 7: Configuring firewall..."

# Configure UFW
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 5432/tcp  # PostgreSQL

log_success "Firewall configured"

# =============================================================================
# STEP 8: Create Systemd Service
# =============================================================================
log "Step 8: Creating systemd service..."

# Create systemd service for PostgreSQL export
cat > /etc/systemd/system/postgres-export.service << EOFSERVICE
[Unit]
Description=PostgreSQL Analytics Export Service
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=oneshot
User=postgres
Group=postgres
WorkingDirectory=$APP_HOME
Environment=PATH=$APP_HOME/venv/bin
ExecStart=$APP_HOME/venv/bin/python export_to_postgres_enhanced.py
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

# Create systemd timer for scheduled exports
cat > /etc/systemd/system/postgres-export.timer << EOFTIMER
[Unit]
Description=Run PostgreSQL Export Daily
Requires=postgres-export.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOFTIMER

systemctl daemon-reload
log_success "Systemd services created"

# =============================================================================
# STEP 9: Setup Logging
# =============================================================================
log "Step 9: Setting up logging..."

# Create log directory
mkdir -p /var/log/ecommerce-app
chown postgres:postgres /var/log/ecommerce-app

# Configure log rotation
cat > /etc/logrotate.d/ecommerce-postgres << EOFLOGROTATE
/var/log/ecommerce-app/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
EOFLOGROTATE

log_success "Logging configured"

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================
echo
log_success "=== PostgreSQL Analytics Database Deployment Complete ==="
echo
log "Database Information:"
log "Database: ecommerce_analytics"
log "Schema: analytics"
log "Application User: $APP_USER"
log "Application Directory: $APP_HOME"
echo
log "Connection Information:"
log "Host: localhost (or external IP for remote access)"
log "Port: 5432"
log "Database: ecommerce_analytics"
log "Username: $APP_USER"
echo
log "Passwords (save these securely):"
log "postgres user password: $POSTGRES_PASSWORD"
log "Application user ($APP_USER) password: $APP_PASSWORD"
echo
log "Next steps:"
log "1. Configure Snowflake credentials:"
log "   nano $APP_HOME/.env"
echo
log "2. Test database connection:"
log "   psql -h localhost -U $APP_USER -d ecommerce_analytics"
echo
log "3. Run export manually:"
log "   cd $APP_HOME && ./venv/bin/python export_to_postgres_enhanced.py"
echo
log "4. Enable automatic daily exports:"
log "   systemctl enable postgres-export.timer"
log "   systemctl start postgres-export.timer"
echo
log "5. Monitor services:"
log "   systemctl status postgresql"
log "   systemctl status postgres-export.service"
echo
log_success "Deployment completed successfully!"
echo
if [ ! -z "$INSTANCE_ID" ]; then
    log "Instance ID: $INSTANCE_ID"
    log "Instance Type: $INSTANCE_TYPE"
    log "Region: $REGION"
fi
log "Ubuntu Version: $UBUNTU_VERSION"
log "PostgreSQL Version: $(sudo -u postgres psql -c 'SELECT version();' | head -3 | tail -1)"
echo 