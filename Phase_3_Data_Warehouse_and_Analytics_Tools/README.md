# Phase 3 Data Warehouse and Analytics Tools

This directory contains all the tools, scripts, and documentation for Phase 3 of the Online Retail Project, which focuses on building a complete data warehouse in Snowflake and setting up analytics exports to various platforms.

## 📁 Directory Structure Overview

This directory is organized into the following categories:

### 🏗️ Snowflake Data Warehouse Setup
- **Core warehouse build scripts**
- **Migration and schema management**
- **Data validation and testing**

### 🚀 AWS DynamoDB Export System
- **EC2 deployment automation**
- **DynamoDB export scripts**
- **Setup and configuration guides**

### 📊 Alternative Export Options
- **PostgreSQL export capabilities**
- **CSV data exports**

### 📖 Documentation and Guides
- **Deployment guides**
- **Setup instructions**
- **Phase 3 walkthrough**

---

## 🏗️ Snowflake Data Warehouse Files

### Primary Warehouse Build Scripts
| File | Purpose | Usage |
|------|---------|-------|
| `build_warehouse_snowflake.sql` | **Main warehouse build script** | Direct Snowflake execution ✅ |
| `snowflake_phase3_complete.sql` | Complete Phase 3 implementation | Comprehensive warehouse setup |
| `snowflake_phase3_simple.sql` | Simplified Phase 3 version | Streamlined implementation |
| `build_warehouse_final.sql` | Final warehouse configuration | Production-ready setup |

### Python Execution Scripts
| File | Purpose | Usage |
|------|---------|-------|
| `run_snowflake_phase3.py` | Python runner for Phase 3 SQL | Automated execution |
| `run_final_warehouse.py` | Python runner for final build | Production deployment |

### Migration and Schema Management
| File | Purpose | Usage |
|------|---------|-------|
| `migrate_to_analytics.sql` | Data migration to ANALYTICS schema | Schema organization |
| `snowflake_datawarehouse_setup.sql` | Initial warehouse setup | Foundation setup |

### Data Validation and Analysis
| File | Purpose | Usage |
|------|---------|-------|
| `examine_snowflake_schema.py` | Schema inspection and validation | Data verification |
| `check_data_locations.py` | Data location and integrity checks | Quality assurance |

---

## 🚀 AWS DynamoDB Export System

### EC2 Deployment Automation
| File | Purpose | Usage |
|------|---------|-------|
| `deploy_to_ec2.sh` | **Complete EC2 deployment script** | Ubuntu instance setup |
| `setup_and_run_dynamodb_export.sh` | **Automated setup and execution** | One-command deployment |
| `ec2_iam_policy.json` | IAM policy for EC2 permissions | AWS security configuration |

### DynamoDB Export Scripts
| File | Purpose | Usage |
|------|---------|-------|
| `export_to_dynamodb_enhanced.py` | **Production DynamoDB exporter** | Enhanced with error handling |
| `export_to_dynamodb.py` | Basic DynamoDB export | Simple implementation |
| `setup_dynamodb_export.py` | Setup verification script | Pre-deployment testing |

### Documentation and Guides
| File | Purpose | Usage |
|------|---------|-------|
| `EC2_DEPLOYMENT_GUIDE.md` | **Complete EC2 deployment guide** | Step-by-step instructions |
| `DYNAMODB_SETUP_GUIDE.md` | DynamoDB setup instructions | Configuration guide |

---

## 📊 Alternative Export Options

### Database Exports
| File | Purpose | Usage |
|------|---------|-------|
| `export_to_postgres.py` | PostgreSQL export script | Alternative database option |

### Data Files
| File | Purpose | Usage |
|------|---------|-------|
| `2025-07-17 6_26pm.csv` | Sample export data | Testing and validation |

---

## 📖 Documentation

### Project Documentation
| File | Purpose | Usage |
|------|---------|-------|
| `Phase 3 walkthrough.txt` | **Complete Phase 3 documentation** | Project overview and history |
| `README.md` | This file | Directory organization |

---

## 🚀 Quick Start Guide

### 1. Snowflake Data Warehouse Setup

**Recommended approach** - Direct SQL execution:
```sql
-- Execute in Snowflake directly
-- File: build_warehouse_snowflake.sql
```

**Alternative** - Python execution:
```bash
python run_final_warehouse.py
```

### 2. DynamoDB Export to AWS

**Complete automated deployment:**
```bash
# On Ubuntu EC2 instance
chmod +x setup_and_run_dynamodb_export.sh
sudo ./setup_and_run_dynamodb_export.sh
```

**Manual EC2 deployment:**
```bash
# Deploy application to EC2
chmod +x deploy_to_ec2.sh
sudo ./deploy_to_ec2.sh

# Then configure and run export
python export_to_dynamodb_enhanced.py
```

### 3. Alternative Database Exports

**PostgreSQL export:**
```bash
python export_to_postgres.py
```

---

## 🏗️ Architecture Overview

### Data Flow
```
Snowflake ANALYTICS Schema
    ↓
┌─────────────────────────────┐
│     Data Warehouse          │
│  - USER_SEGMENTS            │
│  - USER_PRODUCT_RECOMMENDATIONS │
│  - CUSTOMER_360_PROFILE     │
│  - Analytics Views          │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│      Export Targets         │
│  - AWS DynamoDB             │
│  - PostgreSQL               │
│  - CSV Files                │
└─────────────────────────────┘
```

### AWS Infrastructure
```
EC2 Instance (Ubuntu)
├── IAM Role: EcommerceDynamoDBExportRole
├── Application: /opt/ecommerce-app/
├── Logs: /var/log/ecommerce-app/
└── DynamoDB Tables:
    ├── ecommerce_user_segments
    └── ecommerce_product_recommendations
```

---

## 📋 Prerequisites

### Snowflake Requirements
- Access to ECOMMERCE_DB database
- ANALYTICS schema with data
- Appropriate user permissions

### AWS Requirements
- AWS Account with DynamoDB access
- EC2 instance (Ubuntu 20.04+)
- IAM role with DynamoDB permissions

### Environment Setup
- Python 3.8+
- Required packages: boto3, snowflake-connector-python, python-dotenv

---

## 🔧 Configuration

### Environment Variables (.env)
```bash
# Snowflake Configuration
SNOWFLAKE_ACCOUNT=your_account_here
SNOWFLAKE_USER=your_username_here
SNOWFLAKE_PASSWORD=your_password_here
SNOWFLAKE_WAREHOUSE=ECOMMERCE_WH
SNOWFLAKE_DATABASE=ECOMMERCE_DB
SNOWFLAKE_SCHEMA=ANALYTICS

# AWS Configuration
AWS_REGION=us-east-1
DYNAMODB_USER_SEGMENTS_TABLE=ecommerce_user_segments
DYNAMODB_RECOMMENDATIONS_TABLE=ecommerce_product_recommendations
```

---

## 📊 Data Tables Created

### Snowflake Analytics Tables
- `USER_SEGMENTS` - Customer segmentation (Regular/New customers)
- `USER_PRODUCT_RECOMMENDATIONS` - ML-based product recommendations
- `CUSTOMER_360_PROFILE` - Complete customer profiles
- `STG_EVENTS_*` - Staging tables for event data

### DynamoDB Tables
- `ecommerce_user_segments` - User segmentation for real-time access
- `ecommerce_product_recommendations` - Product recommendations for applications

---

## 🔍 Troubleshooting

### Common Issues

1. **Snowflake Connection Issues**
   - Verify credentials in .env file
   - Check account identifier format
   - Ensure warehouse is running

2. **AWS/DynamoDB Issues**
   - Verify IAM role permissions
   - Check region configuration
   - Ensure EC2 instance has internet access

3. **Python Dependencies**
   - Install required packages: `pip install boto3 snowflake-connector-python python-dotenv`
   - Check Python version (3.8+ required)

### Log Locations
- Application logs: `/var/log/ecommerce-app/export.log`
- System logs: `sudo journalctl -u ecommerce-export.service`

---

## 📈 Success Metrics

After successful deployment, you should see:

### Snowflake Analytics
- ✅ Complete data warehouse in ANALYTICS schema
- ✅ User segmentation with customer categories
- ✅ Product recommendation system
- ✅ Customer 360-degree profiles

### DynamoDB Integration
- ✅ Real-time accessible user segments
- ✅ Product recommendations for applications
- ✅ Automated daily data synchronization
- ✅ Scalable cloud infrastructure

---

## 🚀 Next Steps

1. **Production Deployment**
   - Deploy to production EC2 instances
   - Set up monitoring and alerting
   - Configure backup procedures

2. **Application Integration**
   - Connect applications to DynamoDB tables
   - Implement real-time recommendation system
   - Build customer analytics dashboards

3. **Optimization**
   - Monitor query performance
   - Optimize export processes
   - Implement incremental updates

---

## 📝 Version History

- **Phase 3 Complete** - Full data warehouse with DynamoDB exports
- **EC2 Automation** - Automated deployment scripts
- **Production Ready** - Enhanced error handling and monitoring

For detailed project history, see `Phase 3 walkthrough.txt`. 