#!/bin/bash

# =============================================================================
# Ubuntu PostgreSQL Recommender System Setup Script
# =============================================================================
# This script sets up PostgreSQL on Ubuntu and configures the recommender system
# with interactive credential confirmation.
#
# Usage: chmod +x setup_postgres_ubuntu.sh && ./setup_postgres_ubuntu.sh
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
DB_NAME="ecommerce_analytics"
DB_USER="postgres"
DB_PASSWORD=""
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"

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

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

print_step() {
    echo -e "${CYAN}➤ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
}

# Function to check Ubuntu version
check_ubuntu() {
    if ! command_exists lsb_release; then
        print_error "This script requires Ubuntu. Please install lsb-release first."
        exit 1
    fi
    
    UBUNTU_VERSION=$(lsb_release -rs)
    print_success "Ubuntu $UBUNTU_VERSION detected"
}

# Function to install PostgreSQL
install_postgresql() {
    print_step "Installing PostgreSQL..."
    
    # Update package list
    print_status "Updating package list..."
    sudo apt-get update -qq
    
    # Install PostgreSQL
    print_status "Installing PostgreSQL..."
    sudo apt-get install -y postgresql postgresql-contrib postgresql-client
    
    # Start and enable PostgreSQL service
    print_status "Starting PostgreSQL service..."
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    # Check if PostgreSQL is running
    if sudo systemctl is-active --quiet postgresql; then
        print_success "PostgreSQL installed and running"
    else
        print_error "Failed to start PostgreSQL service"
        exit 1
    fi
}

# Function to get PostgreSQL version
get_postgres_version() {
    if command_exists psql; then
        PSQL_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1,2)
        print_success "PostgreSQL version: $PSQL_VERSION"
    else
        print_error "PostgreSQL not found in PATH"
        exit 1
    fi
}

# Function to configure PostgreSQL user
configure_postgres_user() {
    print_step "Configuring PostgreSQL user..."
    
    # Switch to postgres user and set password
    print_status "Setting up postgres user..."
    
    # Create a temporary SQL file
    cat > /tmp/setup_postgres.sql << EOF
ALTER USER postgres PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO postgres;
\q
EOF
    
    # Execute as postgres user
    sudo -u postgres psql -f /tmp/setup_postgres.sql
    
    # Clean up
    rm /tmp/setup_postgres.sql
    
    print_success "PostgreSQL user configured"
}

# Function to test database connection
test_connection() {
    print_step "Testing database connection..."
    
    # Test connection with password
    if PGPASSWORD="$DB_PASSWORD" psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $DB_USER -d $DB_NAME -c "SELECT version();" >/dev/null 2>&1; then
        print_success "Database connection successful"
        return 0
    else
        print_error "Database connection failed"
        return 1
    fi
}

# Function to create analytics schema
create_analytics_schema() {
    print_step "Creating analytics schema..."
    
    # Create schema SQL
    cat > /tmp/create_schema.sql << EOF
CREATE SCHEMA IF NOT EXISTS analytics;
\q
EOF
    
    # Execute schema creation
    if PGPASSWORD="$DB_PASSWORD" psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $DB_USER -d $DB_NAME -f /tmp/create_schema.sql; then
        print_success "Analytics schema created"
    else
        print_error "Failed to create analytics schema"
        rm /tmp/create_schema.sql
        exit 1
    fi
    
    # Clean up
    rm /tmp/create_schema.sql
}

# Function to install Python dependencies
install_python_deps() {
    print_step "Installing Python dependencies..."
    
    # Check if pip is available
    if ! command_exists pip3; then
        print_status "Installing pip3..."
        sudo apt-get install -y python3-pip
    fi
    
    # Install required packages
    print_status "Installing Python packages..."
    pip3 install psycopg2-binary pandas numpy python-dotenv
    
    print_success "Python dependencies installed"
}

# Function to create environment file
create_env_file() {
    print_step "Creating environment configuration..."
    
    # Create .env file
    cat > .env << EOF
# PostgreSQL Configuration
POSTGRES_HOST=$POSTGRES_HOST
POSTGRES_PORT=$POSTGRES_PORT
POSTGRES_DATABASE=$DB_NAME
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASSWORD

# Database Configuration for Python scripts
DB_HOST=$POSTGRES_HOST
DB_PORT=$POSTGRES_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF
    
    print_success "Environment file created: .env"
}

# Function to display connection information
display_connection_info() {
    print_header "=========================================="
    print_header "🎯 POSTGRESQL CONNECTION INFORMATION"
    print_header "=========================================="
    echo ""
    echo -e "${CYAN}Host:${NC} $POSTGRES_HOST"
    echo -e "${CYAN}Port:${NC} $POSTGRES_PORT"
    echo -e "${CYAN}Database:${NC} $DB_NAME"
    echo -e "${CYAN}User:${NC} $DB_USER"
    echo -e "${CYAN}Password:${NC} $DB_PASSWORD"
    echo ""
    print_header "=========================================="
}

# Function to test the complete setup
test_complete_setup() {
    print_step "Running complete setup test..."
    
    # Test 1: Database connection
    if test_connection; then
        print_success "✅ Database connection test passed"
    else
        print_error "❌ Database connection test failed"
        return 1
    fi
    
    # Test 2: Schema exists
    if PGPASSWORD="$DB_PASSWORD" psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $DB_USER -d $DB_NAME -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'analytics';" | grep -q analytics; then
        print_success "✅ Analytics schema test passed"
    else
        print_error "❌ Analytics schema test failed"
        return 1
    fi
    
    # Test 3: Python connection
    python3 -c "
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

try:
    conn = psycopg2.connect(
        host=os.getenv('POSTGRES_HOST'),
        port=os.getenv('POSTGRES_PORT'),
        database=os.getenv('POSTGRES_DATABASE'),
        user=os.getenv('POSTGRES_USER'),
        password=os.getenv('POSTGRES_PASSWORD')
    )
    print('✅ Python database connection test passed')
    conn.close()
except Exception as e:
    print(f'❌ Python database connection test failed: {e}')
    exit(1)
"
    
    print_success "All tests passed!"
}

# Function to prompt for credentials
prompt_for_credentials() {
    print_header "=========================================="
    print_header "🔐 DATABASE CREDENTIALS SETUP"
    print_header "=========================================="
    echo ""
    print_status "Please provide the database credentials:"
    echo ""
    
    # Prompt for password
    while true; do
        echo -n "Enter PostgreSQL password for 'postgres' user: "
        read -s DB_PASSWORD
        echo ""
        
        if [[ -z "$DB_PASSWORD" ]]; then
            print_error "Password cannot be empty. Please try again."
            continue
        fi
        
        echo -n "Confirm password: "
        read -s CONFIRM_PASSWORD
        echo ""
        
        if [[ "$DB_PASSWORD" == "$CONFIRM_PASSWORD" ]]; then
            print_success "Password confirmed"
            break
        else
            print_error "Passwords do not match. Please try again."
        fi
    done
    
    echo ""
    print_status "Database configuration:"
    echo -e "  Host: ${CYAN}$POSTGRES_HOST${NC}"
    echo -e "  Port: ${CYAN}$POSTGRES_PORT${NC}"
    echo -e "  Database: ${CYAN}$DB_NAME${NC}"
    echo -e "  User: ${CYAN}$DB_USER${NC}"
    echo -e "  Password: ${CYAN}********${NC}"
    echo ""
    
    # Ask for confirmation
    while true; do
        echo -n "Proceed with this configuration? (y/n): "
        read -r CONFIRM
        case $CONFIRM in
            [Yy]* ) 
                print_success "Configuration confirmed"
                break
                ;;
            [Nn]* ) 
                print_warning "Setup cancelled by user"
                exit 0
                ;;
            * ) 
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Function to display next steps
display_next_steps() {
    print_header "=========================================="
    print_header "🎉 SETUP COMPLETE - NEXT STEPS"
    print_header "=========================================="
    echo ""
    print_success "PostgreSQL recommender system is ready!"
    echo ""
    print_status "To run the recommender system:"
    echo "  python3 setup_postgres_recommender_complete.py"
    echo ""
    print_status "To test the setup:"
    echo "  python3 test_postgres_recommender.py"
    echo ""
    print_status "To connect to database:"
    echo "  psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $DB_USER -d $DB_NAME"
    echo ""
    print_status "Environment file created: .env"
    echo ""
    print_header "=========================================="
}

# Main setup function
main_setup() {
    print_header "=========================================="
    print_header "🚀 UBUNTU POSTGRESQL RECOMMENDER SETUP"
    print_header "=========================================="
    echo ""
    
    # Check prerequisites
    print_step "Checking prerequisites..."
    check_root
    check_ubuntu
    
    # Prompt for credentials
    prompt_for_credentials
    
    # Install PostgreSQL
    print_step "Installing PostgreSQL..."
    install_postgresql
    get_postgres_version
    
    # Configure PostgreSQL
    print_step "Configuring PostgreSQL..."
    configure_postgres_user
    
    # Test connection
    print_step "Testing database connection..."
    if test_connection; then
        print_success "Database connection successful"
    else
        print_error "Database connection failed. Please check your credentials."
        exit 1
    fi
    
    # Create analytics schema
    create_analytics_schema
    
    # Install Python dependencies
    install_python_deps
    
    # Create environment file
    create_env_file
    
    # Test complete setup
    test_complete_setup
    
    # Display connection information
    display_connection_info
    
    # Display next steps
    display_next_steps
}

# Function to handle cleanup on exit
cleanup() {
    print_status "Cleaning up..."
    # Remove temporary files if they exist
    rm -f /tmp/setup_postgres.sql /tmp/create_schema.sql
}

# Set up trap to call cleanup on script exit
trap cleanup EXIT

# Run main setup
main_setup 