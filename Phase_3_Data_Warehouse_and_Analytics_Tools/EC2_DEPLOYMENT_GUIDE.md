# EC2 Ubuntu Deployment Guide - DynamoDB Export Application

This guide provides step-by-step instructions for deploying the DynamoDB export application on Ubuntu EC2 instances.

## Prerequisites

- AWS Account with appropriate permissions
- Access to Snowflake data warehouse
- Basic knowledge of AWS EC2 and IAM

## Step 1: Create IAM Role for EC2

### 1.1 Create IAM Policy

1. Go to AWS IAM Console → Policies → Create Policy
2. Use the JSON tab and paste the contents of `ec2_iam_policy.json`
3. Name the policy: `EcommerceDynamoDBExportPolicy`
4. Add description: "Policy for EC2 instance to export data to DynamoDB"
5. Create the policy

### 1.2 Create IAM Role

1. Go to AWS IAM Console → Roles → Create Role
2. Select "AWS Service" → "EC2"
3. Attach the policy: `EcommerceDynamoDBExportPolicy`
4. Name the role: `EcommerceDynamoDBExportRole`
5. Add description: "Role for EC2 instance running DynamoDB export application"
6. Create the role

## Step 2: Launch EC2 Instance

### 2.1 Instance Configuration

1. **AMI**: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
2. **Instance Type**: t3.small or larger (minimum 2GB RAM)
3. **Key Pair**: Create or select existing key pair for SSH access
4. **Security Group**: 
   - SSH (22) from your IP
   - HTTPS (443) outbound
   - HTTP (80) outbound (for package installation)

### 2.2 Advanced Details

- **IAM Instance Profile**: Select `EcommerceDynamoDBExportRole`
- **User Data** (optional - for automated setup):

```bash
#!/bin/bash
cd /home/ubuntu
wget https://raw.githubusercontent.com/your-repo/deploy_to_ec2.sh
chmod +x deploy_to_ec2.sh
./deploy_to_ec2.sh
```

### 2.3 Storage

- **Root Volume**: 20GB gp3 (minimum)
- **Encryption**: Enabled (recommended)

## Step 3: Connect to Instance

```bash
# Replace with your key file and instance IP
ssh -i "your-key.pem" ubuntu@your-instance-ip
```

## Step 4: Run Deployment Script

### Option A: Automated Deployment

```bash
# Download and run the deployment script
curl -sSL https://raw.githubusercontent.com/your-repo/deploy_to_ec2.sh -o deploy_to_ec2.sh
chmod +x deploy_to_ec2.sh
sudo ./deploy_to_ec2.sh
```

### Option B: Manual Deployment

1. Upload the deployment script to your instance:

```bash
scp -i "your-key.pem" deploy_to_ec2.sh ubuntu@your-instance-ip:~/
```

2. SSH into the instance and run:

```bash
chmod +x deploy_to_ec2.sh
sudo ./deploy_to_ec2.sh
```

## Step 5: Configure Application

After deployment completes:

### 5.1 Configure Snowflake Credentials

```bash
sudo -u ecommerce nano /opt/ecommerce-app/.env
```

Update the following values:
```
SNOWFLAKE_ACCOUNT=your_account_identifier
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_WAREHOUSE=ECOMMERCE_WH
SNOWFLAKE_DATABASE=ECOMMERCE_DB
SNOWFLAKE_SCHEMA=ANALYTICS
```

### 5.2 Test the Setup

```bash
# Switch to application user
sudo -u ecommerce -i

# Navigate to application directory
cd /opt/ecommerce-app

# Test connectivity
./venv/bin/python setup_dynamodb_export.py
```

Expected output:
```
✓ AWS credentials valid - Account: 123456789012
✓ DynamoDB access successful
✓ Snowflake connection successful
✓ All tests passed - Setup is ready!
```

## Step 6: Run Export

### 6.1 Manual Export

```bash
# Run the export manually
sudo -u ecommerce /opt/ecommerce-app/venv/bin/python /opt/ecommerce-app/export_to_dynamodb_enhanced.py
```

### 6.2 Automated Export (Daily)

```bash
# Enable daily automated exports
sudo systemctl enable ecommerce-export.timer
sudo systemctl start ecommerce-export.timer

# Check timer status
sudo systemctl status ecommerce-export.timer
```

## Step 7: Monitoring and Maintenance

### 7.1 Check Service Status

```bash
# Check export service
sudo systemctl status ecommerce-export.service

# Check export timer
sudo systemctl status ecommerce-export.timer

# View recent logs
sudo journalctl -u ecommerce-export.service -f
```

### 7.2 Application Logs

```bash
# View application logs
sudo tail -f /var/log/ecommerce-app/export.log

# View all logs
sudo less /var/log/ecommerce-app/export.log
```

### 7.3 Manual Service Control

```bash
# Run export immediately
sudo systemctl start ecommerce-export.service

# Stop timer
sudo systemctl stop ecommerce-export.timer

# Restart timer
sudo systemctl restart ecommerce-export.timer
```

## Step 8: Verify DynamoDB Tables

### 8.1 Using AWS CLI (on EC2 instance)

```bash
# List DynamoDB tables
aws dynamodb list-tables

# Describe user segments table
aws dynamodb describe-table --table-name ecommerce_user_segments

# Count items in table
aws dynamodb scan --table-name ecommerce_user_segments --select COUNT

# Get sample item
aws dynamodb scan --table-name ecommerce_user_segments --limit 1
```

### 8.2 Using AWS Console

1. Go to AWS DynamoDB Console
2. Tables → `ecommerce_user_segments`
3. View items, metrics, and configuration

## Troubleshooting

### Common Issues

1. **Snowflake Connection Failed**
   - Check credentials in `.env` file
   - Verify network connectivity
   - Check Snowflake account identifier format

2. **DynamoDB Access Denied**
   - Verify IAM role is attached to EC2 instance
   - Check IAM policy permissions
   - Ensure region is correct

3. **Python Dependencies Issues**
   - Reinstall dependencies: `sudo -u ecommerce /opt/ecommerce-app/venv/bin/pip install -r requirements.txt`
   - Check Python version: `python3 --version`

4. **Service Won't Start**
   - Check logs: `sudo journalctl -u ecommerce-export.service -n 50`
   - Verify file permissions: `ls -la /opt/ecommerce-app/`
   - Test manually: `sudo -u ecommerce /opt/ecommerce-app/venv/bin/python /opt/ecommerce-app/export_to_dynamodb_enhanced.py`

### Log Locations

- Application logs: `/var/log/ecommerce-app/export.log`
- System logs: `sudo journalctl -u ecommerce-export.service`
- System logs: `sudo journalctl -u ecommerce-export.timer`

## Security Considerations

1. **Network Security**
   - Use VPC with private subnets for production
   - Implement Security Groups with minimal required access
   - Consider using VPC endpoints for AWS services

2. **Credentials Management**
   - Use IAM roles instead of access keys when possible
   - Store sensitive data in AWS Secrets Manager or Parameter Store
   - Regularly rotate credentials

3. **Monitoring**
   - Enable CloudTrail for API logging
   - Set up CloudWatch alarms for failed exports
   - Monitor DynamoDB metrics

## Scaling Considerations

1. **Instance Size**
   - Monitor CPU and memory usage
   - Scale up instance type if needed
   - Consider using Auto Scaling Groups for high availability

2. **Data Volume**
   - Monitor export duration
   - Consider parallel processing for large datasets
   - Implement incremental exports for better performance

3. **Cost Optimization**
   - Use Reserved Instances for long-running workloads
   - Consider Spot Instances for dev/test environments
   - Monitor DynamoDB usage and optimize billing mode

## Backup and Recovery

1. **Instance Backup**
   - Create AMI snapshots regularly
   - Backup application configuration files

2. **DynamoDB Backup**
   - Enable point-in-time recovery
   - Create on-demand backups before major changes

3. **Configuration Backup**
   - Store deployment scripts in version control
   - Document custom configurations

## Next Steps

After successful deployment:

1. **Integration Testing**
   - Test data accuracy in DynamoDB
   - Verify application integration
   - Test failure scenarios

2. **Production Deployment**
   - Deploy to production environment
   - Configure monitoring and alerting
   - Set up backup procedures

3. **Optimization**
   - Monitor performance metrics
   - Optimize export queries
   - Implement caching if needed

For additional support or questions, refer to the application documentation or contact the development team. 