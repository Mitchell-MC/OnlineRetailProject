# DynamoDB Export Setup Guide

This guide will help you export your Snowflake data warehouse to DynamoDB tables for real-time application access.

## 🎯 What This Does

The DynamoDB export will create two tables in AWS:
- **`ecommerce_user_segments`** - Customer segmentation data (VIP, Premium, Regular, New)
- **`ecommerce_product_recommendations`** - Personalized product recommendations for each user

## 📋 Prerequisites

1. **AWS Account** with DynamoDB access
2. **Snowflake credentials** (same ones you used for the warehouse build)
3. **Python packages**: `boto3` and `snowflake-connector-python`

## 🚀 Step-by-Step Setup

### Step 1: Run the Setup Script
```bash
python setup_dynamodb_export.py
```

This will:
- ✅ Check if required packages are installed
- ✅ Test AWS credentials
- ✅ Test Snowflake connection
- ✅ Verify your warehouse tables exist
- 📄 Create a `.env.example` file

### Step 2: Configure Credentials

#### For AWS (choose one option):

**Option A: Use AWS CLI (Recommended)**
```bash
pip install awscli
aws configure
```

**Option B: Set Environment Variables**
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1
```

#### For Snowflake:
```bash
export SNOWFLAKE_USER=your_username
export SNOWFLAKE_PASSWORD=your_password
export SNOWFLAKE_ACCOUNT=your_account
```

### Step 3: Install Missing Packages (if needed)
```bash
pip install boto3 snowflake-connector-python
```

### Step 4: Run the Export
```bash
python export_to_dynamodb_enhanced.py
```

## 📊 What Happens During Export

1. **Creates DynamoDB Tables** (if they don't exist)
2. **Fetches User Segments** from Snowflake
3. **Fetches Product Recommendations** from Snowflake
4. **Writes Data to DynamoDB** in batches
5. **Provides Success Confirmation**

## 🔍 Troubleshooting

### "Missing required environment variables"
- Make sure you've set your Snowflake credentials as environment variables
- Run the setup script again to verify

### "AWS credentials issue"
- Install AWS CLI: `pip install awscli`
- Run: `aws configure`
- Or set AWS environment variables

### "No module named 'boto3'"
- Install required packages: `pip install boto3 snowflake-connector-python`

### "Table does not exist"
- Make sure you've run the `build_warehouse_snowflake.sql` script first
- Verify tables exist in Snowflake: `USER_SEGMENTS` and `USER_PRODUCT_RECOMMENDATIONS`

## 📈 After Export

Once complete, you'll have:
- **Real-time user segments** in DynamoDB for personalization
- **Product recommendations** for your application to serve
- **Scalable NoSQL storage** for high-traffic applications

Your applications can now query these DynamoDB tables for:
- Customer segmentation for targeted marketing
- Product recommendations for users
- Real-time personalization features

## 💡 Next Steps

After DynamoDB export, consider:
1. **Setting up PostgreSQL export** for BI tools
2. **Creating API endpoints** to serve the DynamoDB data
3. **Scheduling regular exports** via Airflow DAGs
4. **Monitoring and alerting** for the export process 