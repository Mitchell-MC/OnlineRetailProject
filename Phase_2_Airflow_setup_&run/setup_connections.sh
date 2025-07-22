#!/bin/bash

# Set project directory
PROJECT_DIR="/home/ubuntu/OnlineRetailProject"

echo "🔗 Setting up Airflow connections..."

# Function to check if environment file exists and has valid content
check_env_file() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        # Check if file has actual values (not just placeholders)
        if grep -q "your-" "$env_file"; then
            echo "⚠️  Environment file found but contains placeholder values"
            return 1
        else
            echo "✅ Environment file found with actual values"
            return 0
        fi
    else
        echo "❌ Environment file not found: $env_file"
        return 1
    fi
}

# Function to create demo connections
create_demo_connections() {
    echo "🔗 Creating demo connections for testing..."
    
    # Create a demo Snowflake connection (for testing)
    airflow connections add 'snowflake_default' \
        --conn-type 'snowflake' \
        --conn-host "demo-account.snowflakecomputing.com" \
        --conn-login "demo_user" \
        --conn-password "demo_password" \
        --conn-schema "DEMO_SCHEMA" \
        --conn-port 443 \
        --conn-extra "{\"account\": \"demo-account\", \"warehouse\": \"DEMO_WAREHOUSE\", \"database\": \"DEMO_DB\", \"region\": \"us-east-1\"}" 2>/dev/null || echo "⚠️  Snowflake connection already exists"
    
    # Create a demo S3 connection (for testing)
    airflow connections add 's3_default' \
        --conn-type 'aws' \
        --conn-login "demo_access_key" \
        --conn-password "demo_secret_key" \
        --conn-extra "{\"aws_access_key_id\": \"demo_access_key\", \"aws_secret_access_key\": \"demo_secret_key\", \"region_name\": \"us-east-1\"}" 2>/dev/null || echo "⚠️  S3 connection already exists"
    
    # Create AWS default connection
    airflow connections add 'aws_default' \
        --conn-type 'aws' \
        --conn-extra "{\"region_name\": \"us-east-1\", \"aws_access_key_id\": \"demo_access_key\", \"aws_secret_access_key\": \"demo_secret_key\"}" 2>/dev/null || echo "⚠️  AWS connection already exists"
    
    echo "✅ Demo connections created successfully!"
}

# Function to create connections from environment variables
create_connections_from_env() {
    echo "🔗 Creating connections from environment variables..."
    
    # Check if required environment variables are set
    if [ -z "$SNOWFLAKE_ACCOUNT" ] || [ -z "$SNOWFLAKE_USER" ] || [ -z "$SNOWFLAKE_PASSWORD" ]; then
        echo "❌ Missing required Snowflake environment variables"
        return 1
    fi
    
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "❌ Missing required AWS environment variables"
        return 1
    fi
    
    # Create Snowflake connection
    echo "❄️  Creating Snowflake connection..."
    airflow connections add 'snowflake_default' \
        --conn-type 'snowflake' \
        --conn-host "${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com" \
        --conn-login "${SNOWFLAKE_USER}" \
        --conn-password "${SNOWFLAKE_PASSWORD}" \
        --conn-schema "${SNOWFLAKE_SCHEMA:-ANALYTICS}" \
        --conn-port 443 \
        --conn-extra "{\"account\": \"${SNOWFLAKE_ACCOUNT}\", \"warehouse\": \"${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}\", \"database\": \"${SNOWFLAKE_DATABASE:-ANALYTICS_DB}\", \"region\": \"${SNOWFLAKE_REGION:-us-east-1}\"}"
    
    # Create S3 connection
    echo "☁️  Creating S3 connection..."
    airflow connections add 's3_default' \
        --conn-type 'aws' \
        --conn-login "${AWS_ACCESS_KEY_ID}" \
        --conn-password "${AWS_SECRET_ACCESS_KEY}" \
        --conn-extra "{\"aws_access_key_id\": \"${AWS_ACCESS_KEY_ID}\", \"aws_secret_access_key\": \"${AWS_SECRET_ACCESS_KEY}\", \"region_name\": \"${AWS_DEFAULT_REGION:-us-east-1}\"}"
    
    # Create AWS connection
    echo "🔄 Creating AWS connection..."
    airflow connections add 'aws_default' \
        --conn-type 'aws' \
        --conn-extra "{\"region_name\": \"${AWS_DEFAULT_REGION:-us-east-1}\", \"aws_access_key_id\": \"${AWS_ACCESS_KEY_ID}\", \"aws_secret_access_key\": \"${AWS_SECRET_ACCESS_KEY}\"}"
    
    echo "✅ All connections created successfully!"
}

# Function to create a template environment file
create_template_env() {
    echo "📝 Creating template environment file..."
    
    cat > "$PROJECT_DIR/airflow-project/airflow_connections.env.template" << 'EOF'
# Snowflake Connection Variables
# Update these with your actual Snowflake credentials
export SNOWFLAKE_ACCOUNT="your-snowflake-account"
export SNOWFLAKE_USER="your-snowflake-username"
export SNOWFLAKE_PASSWORD="your-snowflake-password"
export SNOWFLAKE_DATABASE="your-snowflake-database"
export SNOWFLAKE_SCHEMA="your-snowflake-schema"
export SNOWFLAKE_WAREHOUSE="your-snowflake-warehouse"
export SNOWFLAKE_REGION="us-east-1"

# AWS Connection Variables
# Update these with your actual AWS credentials
export AWS_ACCESS_KEY_ID="your-aws-access-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Optional: Set to 'true' to use demo connections for testing
export USE_DEMO_CONNECTIONS="false"
EOF
    
    echo "✅ Template environment file created: $PROJECT_DIR/airflow-project/airflow_connections.env.template"
    echo "📝 Please copy this file to airflow_connections.env and update with your actual credentials"
}

# Function to validate connections
validate_connections() {
    echo "🔍 Validating connections..."
    
    # Check if connections exist
    if airflow connections get snowflake_default >/dev/null 2>&1; then
        echo "✅ Snowflake connection exists"
    else
        echo "❌ Snowflake connection not found"
    fi
    
    if airflow connections get s3_default >/dev/null 2>&1; then
        echo "✅ S3 connection exists"
    else
        echo "❌ S3 connection not found"
    fi
    
    if airflow connections get aws_default >/dev/null 2>&1; then
        echo "✅ AWS connection exists"
    else
        echo "❌ AWS connection not found"
    fi
}

# Activate virtual environment
if [ ! -d "$PROJECT_DIR/airflow-project/venv" ]; then
    echo "❌ Virtual environment not found. Please run setup_airflow_instance.sh first."
    exit 1
fi

source "$PROJECT_DIR/airflow-project/venv/bin/activate"

# Set Airflow home
export AIRFLOW_HOME="/home/ubuntu/airflow"

# Check for environment file in multiple locations
ENV_FILE_FOUND=false

# Check current directory
if check_env_file "./airflow_connections.env"; then
    source "./airflow_connections.env"
    ENV_FILE_FOUND=true
    echo "✅ Loaded connection environment variables from current directory"
fi

# Check project directory
if [ "$ENV_FILE_FOUND" = false ] && check_env_file "$PROJECT_DIR/airflow-project/airflow_connections.env"; then
    source "$PROJECT_DIR/airflow-project/airflow_connections.env"
    ENV_FILE_FOUND=true
    echo "✅ Loaded connection environment variables from project directory"
fi

# Check parent directory
if [ "$ENV_FILE_FOUND" = false ] && check_env_file "$PROJECT_DIR/airflow_connections.env"; then
    source "$PROJECT_DIR/airflow_connections.env"
    ENV_FILE_FOUND=true
    echo "✅ Loaded connection environment variables from parent directory"
fi

# If no valid environment file found, offer options
if [ "$ENV_FILE_FOUND" = false ]; then
    echo "❌ No valid airflow_connections.env file found."
    echo ""
    echo "📁 Expected locations:"
    echo "   - ./airflow_connections.env (current directory)"
    echo "   - $PROJECT_DIR/airflow-project/airflow_connections.env"
    echo "   - $PROJECT_DIR/airflow_connections.env"
    echo ""
    echo "🔧 Options:"
    echo "   1. Create demo connections for testing"
    echo "   2. Create template environment file"
    echo "   3. Exit and create environment file manually"
    echo ""
    read -p "Choose an option (1-3): " choice
    
    case $choice in
        1)
            echo "🔗 Creating demo connections..."
            create_demo_connections
            ;;
        2)
            create_template_env
            echo "📝 Please update the template file with your credentials and run this script again."
            exit 0
            ;;
        3)
            echo "📝 Please create airflow_connections.env with your credentials and run this script again."
            exit 1
            ;;
        *)
            echo "❌ Invalid option. Exiting."
            exit 1
            ;;
    esac
else
    # Check if we should use demo connections
    if [ "$USE_DEMO_CONNECTIONS" = "true" ]; then
        echo "🔗 Using demo connections as requested..."
        create_demo_connections
    else
        # Create connections from environment variables
        create_connections_from_env
    fi
fi

# Validate connections
validate_connections

echo ""
echo "✅ Connection setup completed!"
echo "📋 Available connections:"
airflow connections list

echo ""
echo "🔧 Next steps:"
echo "   1. Test your connections using test_connections.sh"
echo "   2. Update your DAGs to use the correct connection IDs"
echo "   3. Unpause and trigger your DAGs"
