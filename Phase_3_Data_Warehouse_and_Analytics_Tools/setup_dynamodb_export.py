#!/usr/bin/env python3
"""
Setup Script for DynamoDB Export

This script helps you configure and test your environment before running
the DynamoDB export. It checks credentials, tests connections, and provides
guidance on missing dependencies.
"""

import os
import sys
import subprocess

def check_python_packages():
    """Check if required Python packages are installed."""
    print("🔍 Checking Python packages...")
    
    required_packages = [
        'boto3',
        'snowflake-connector-python'
    ]
    
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
            print(f"  ✅ {package}")
        except ImportError:
            print(f"  ❌ {package} - NOT INSTALLED")
            missing_packages.append(package)
    
    if missing_packages:
        print(f"\n📦 Missing packages detected. Install them with:")
        print(f"pip install {' '.join(missing_packages)}")
        return False
    
    print("✅ All required packages are installed")
    return True

def check_aws_credentials():
    """Check if AWS credentials are configured."""
    print("\n🔍 Checking AWS credentials...")
    
    try:
        import boto3
        
        # Try to create a DynamoDB client
        dynamodb = boto3.client('dynamodb')
        
        # Test with a simple operation (list tables)
        response = dynamodb.list_tables()
        print("✅ AWS credentials are configured and working")
        print(f"   Region: {dynamodb.meta.region_name}")
        return True
        
    except Exception as e:
        print(f"❌ AWS credentials issue: {str(e)}")
        print("\n💡 To configure AWS credentials:")
        print("   1. Install AWS CLI: pip install awscli")
        print("   2. Run: aws configure")
        print("   3. Or set environment variables:")
        print("      export AWS_ACCESS_KEY_ID=your_access_key")
        print("      export AWS_SECRET_ACCESS_KEY=your_secret_key")
        print("      export AWS_DEFAULT_REGION=us-east-1")
        return False

def check_snowflake_credentials():
    """Check if Snowflake credentials are set."""
    print("\n🔍 Checking Snowflake credentials...")
    
    required_vars = ['SNOWFLAKE_USER', 'SNOWFLAKE_PASSWORD', 'SNOWFLAKE_ACCOUNT']
    missing_vars = []
    
    for var in required_vars:
        if os.getenv(var):
            print(f"  ✅ {var}")
        else:
            print(f"  ❌ {var} - NOT SET")
            missing_vars.append(var)
    
    if missing_vars:
        print(f"\n💡 Set missing environment variables:")
        for var in missing_vars:
            if var == 'SNOWFLAKE_USER':
                print(f"   export {var}=your_snowflake_username")
            elif var == 'SNOWFLAKE_PASSWORD':
                print(f"   export {var}=your_snowflake_password")
            elif var == 'SNOWFLAKE_ACCOUNT':
                print(f"   export {var}=your_snowflake_account")
        return False
    
    # Test Snowflake connection
    try:
        import snowflake.connector
        
        conn = snowflake.connector.connect(
            user=os.getenv('SNOWFLAKE_USER'),
            password=os.getenv('SNOWFLAKE_PASSWORD'),
            account=os.getenv('SNOWFLAKE_ACCOUNT'),
            warehouse=os.getenv('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
            database='ECOMMERCE_DB',
            schema='ANALYTICS'
        )
        
        cursor = conn.cursor()
        cursor.execute("SELECT CURRENT_VERSION()")
        version = cursor.fetchone()[0]
        conn.close()
        
        print(f"✅ Snowflake connection successful (Version: {version})")
        return True
        
    except Exception as e:
        print(f"❌ Snowflake connection failed: {str(e)}")
        return False

def test_data_availability():
    """Test if the required tables exist in Snowflake."""
    print("\n🔍 Checking data availability...")
    
    try:
        import snowflake.connector
        
        conn = snowflake.connector.connect(
            user=os.getenv('SNOWFLAKE_USER'),
            password=os.getenv('SNOWFLAKE_PASSWORD'),
            account=os.getenv('SNOWFLAKE_ACCOUNT'),
            warehouse=os.getenv('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
            database='ECOMMERCE_DB',
            schema='ANALYTICS'
        )
        
        cursor = conn.cursor()
        
        # Check USER_SEGMENTS table
        try:
            cursor.execute("SELECT COUNT(*) FROM USER_SEGMENTS")
            user_segments_count = cursor.fetchone()[0]
            print(f"  ✅ USER_SEGMENTS table: {user_segments_count} rows")
        except Exception as e:
            print(f"  ❌ USER_SEGMENTS table: {str(e)}")
        
        # Check USER_PRODUCT_RECOMMENDATIONS table
        try:
            cursor.execute("SELECT COUNT(*) FROM USER_PRODUCT_RECOMMENDATIONS")
            recommendations_count = cursor.fetchone()[0]
            print(f"  ✅ USER_PRODUCT_RECOMMENDATIONS table: {recommendations_count} rows")
        except Exception as e:
            print(f"  ❌ USER_PRODUCT_RECOMMENDATIONS table: {str(e)}")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Data availability check failed: {str(e)}")
        return False

def create_env_file():
    """Create a sample .env file for credentials."""
    env_content = """# Snowflake Credentials
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_WAREHOUSE=COMPUTE_WH

# AWS Credentials (optional if using AWS CLI or IAM roles)
# AWS_ACCESS_KEY_ID=your_access_key
# AWS_SECRET_ACCESS_KEY=your_secret_key
# AWS_DEFAULT_REGION=us-east-1
"""
    
    with open('.env.example', 'w') as f:
        f.write(env_content)
    
    print("📄 Created .env.example file")
    print("   Copy this to .env and fill in your credentials")

def main():
    """Main setup function."""
    print("🚀 DynamoDB Export Setup")
    print("=" * 50)
    
    all_checks_passed = True
    
    # Check Python packages
    if not check_python_packages():
        all_checks_passed = False
    
    # Check AWS credentials
    if not check_aws_credentials():
        all_checks_passed = False
    
    # Check Snowflake credentials
    if not check_snowflake_credentials():
        all_checks_passed = False
    
    # Check data availability (only if Snowflake is working)
    if os.getenv('SNOWFLAKE_USER'):
        if not test_data_availability():
            all_checks_passed = False
    
    # Create sample env file
    create_env_file()
    
    print("\n" + "=" * 50)
    if all_checks_passed:
        print("🎉 Setup complete! You're ready to run the DynamoDB export.")
        print("\nTo export your data, run:")
        print("   python export_to_dynamodb_enhanced.py")
    else:
        print("⚠️  Setup incomplete. Please address the issues above.")
        print("\nAfter fixing the issues, run this setup script again.")

if __name__ == "__main__":
    main() 