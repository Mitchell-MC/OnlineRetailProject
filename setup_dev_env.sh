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
