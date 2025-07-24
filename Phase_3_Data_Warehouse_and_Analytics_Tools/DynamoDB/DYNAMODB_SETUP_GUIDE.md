# DynamoDB Setup Guide

## Overview
This guide covers setting up AWS DynamoDB for real-time data access in the Online Retail Project. DynamoDB serves as a low-latency data store for application access, complementing the Snowflake data warehouse.

## Architecture
```
Snowflake Data Warehouse → DynamoDB Export → Real-time Application Access
```

## Prerequisites
- AWS Account with appropriate permissions
- AWS CLI configured
- Python 3.8+ with required packages
- Access to Snowflake data warehouse

## Required Files

### Core Scripts
- **`export_to_dynamodb_robust.py`** - Production-ready DynamoDB export script
- **`setup_dynamodb_export.py`** - DynamoDB table setup and configuration
- **`setup_and_run_dynamodb_export.sh`** - Automated deployment script
- **`deploy_dynamoDB_to_ec2.sh`** - EC2 deployment automation

## Quick Start

### 1. Local Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Configure AWS credentials
aws configure

# Run DynamoDB export
python3 export_to_dynamodb_robust.py
```

### 2. EC2 Deployment
```bash
# Deploy to EC2
./deploy_dynamoDB_to_ec2.sh

# Or use the setup script
./setup_and_run_dynamodb_export.sh
```

## Configuration

### Environment Variables
Create a `.env` file with:
```env
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=us-east-1
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_WAREHOUSE=your_warehouse
SNOWFLAKE_DATABASE=your_database
SNOWFLAKE_SCHEMA=your_schema
```

### DynamoDB Table Structure
The export creates tables with:
- **Product Recommendations**: Product ID, recommendations, scores
- **User Behavior**: User ID, behavior patterns, preferences
- **Category Performance**: Category metrics and trends

## Features

### Export Script (`export_to_dynamodb_robust.py`)
- ✅ Production-ready with comprehensive error handling
- ✅ Logging and monitoring capabilities
- ✅ Credential validation
- ✅ Table creation and management
- ✅ Data transformation and optimization
- ✅ Batch processing for large datasets

### Setup Script (`setup_dynamodb_export.py`)
- ✅ DynamoDB table creation
- ✅ IAM role configuration
- ✅ Permission setup
- ✅ Connection testing

### Deployment Scripts
- ✅ **`setup_and_run_dynamodb_export.sh`**: Local deployment
- ✅ **`deploy_dynamoDB_to_ec2.sh`**: EC2 deployment with full automation

## Testing

### Verify Data Export
```bash
# Test the export process
python3 export_to_dynamodb_robust.py --test

# Check table contents
aws dynamodb scan --table-name product_recommendations
```

## Monitoring

### CloudWatch Metrics
- DynamoDB read/write capacity
- Error rates and latency
- Data transfer volumes

### Logs
- Export process logs
- Error tracking
- Performance metrics

## Troubleshooting

### Common Issues
1. **AWS Credentials**: Ensure proper IAM permissions
2. **Snowflake Connection**: Verify connection parameters
3. **DynamoDB Limits**: Monitor read/write capacity
4. **Data Format**: Check data transformation logic

### Error Resolution
- Check CloudWatch logs for detailed error messages
- Verify table structure matches expected schema
- Ensure sufficient DynamoDB capacity

## Performance Optimization

### Best Practices
- Use batch operations for large datasets
- Implement exponential backoff for retries
- Monitor and adjust read/write capacity
- Use appropriate data types for efficient storage

### Cost Optimization
- Choose appropriate DynamoDB capacity mode
- Monitor usage patterns
- Implement data lifecycle policies
- Use reserved capacity for predictable workloads

## Security

### IAM Policies
- Least privilege access
- DynamoDB-specific permissions
- Encryption at rest and in transit

### Data Protection
- PII handling compliance
- Data retention policies
- Access logging and monitoring

## Integration

### Application Access
```python
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('product_recommendations')

# Query recommendations
response = table.get_item(Key={'product_id': '12345'})
```

### API Integration
- RESTful API endpoints
- GraphQL integration
- Real-time data access

## Maintenance

### Regular Tasks
- Monitor performance metrics
- Update IAM policies as needed
- Review and optimize data structure
- Backup and recovery procedures

### Updates
- Keep AWS SDK versions current
- Monitor for security patches
- Update deployment scripts

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review error messages in export scripts
3. Verify AWS service status
4. Consult AWS documentation

---

**Note**: This setup provides a robust, production-ready DynamoDB integration for real-time data access in the Online Retail Project. 