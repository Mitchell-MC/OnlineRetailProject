# Phase 3 Data Warehouse and Analytics Tools

This is the main Readme for the OnlineRetailProject.  This project creates and end-to-end Datapipeline .that takes Online Session data from an ecommerce website and build out a recommender based on user data and a Data Mart for analytics teams to use for creating dashboards with an example.  Ecommerce can create a treasure trove of data by end consumers that directly contribute to increases in sales simply by having users perform any action throughout their session.  What's more in our modern era it is effective and low cost for vendors to be collecting and using this data ethically.  This projects seeks to give a window into the possibilities created by incorporating data teams into ecommerce and leveraging them for analytics.

This project is designed to take the kaggle dataset FILL_IN_NAME_HERE from WEB_ADDRESS_HERE, this is a large dataset with each month containing gigabytes of data, so it will not be accessible from my repository and i will not be personally providing it to you.

*An important note on the architecture:*  I built this project with the intention of showcasing my skillset.  My choices are not an endorsement of this particular architecture as being "optimal".  I simply chose to showcase my skills at using current and popular infrastructure and applications to build functional solutions.  At certain points more streamlined approaches could and for certain use cases involve using more AWS solutions or more Snowflake features but determining optimal architecture all depends on the constraints of your business. 

This project contains multiple shell scripts, I built this project out in Ubuntu on EC2 instances.  My personal philosophy is that any computer you use to build software ideally is an operating room in terms of cleanliness when you being and you should be building on Linux.  As such I have scripts in each folder where I am running apps to -first- build out that EC@ instance importing my repository and installing necessary depnedencies and where applicable initializing docker then -second- build the required applications in docker. There will be additional shell scripts where necessary to stop/start services/ validate, configure/validate connections and any othe important operations. If you do not wish to use these scripts then you can check them to determine the necessary configurations and environments to be building off of.



## 📁 Directory Structure Overview

This directory has 4 main folders that are split into "Phases" serving distinct functions that are as follows:

### 🏗️ Phase 1
- **Kafka build out**
- **Kafka producer script (simulating an api output from S3 bucket)**
- **Kafka connector script (send to S3 bucket via Kafka)**
- **Shell script to stramline and automate setup**
- **Dockerfile to build out Kafka app**

### 🚀 Phase 2
- **Airflow build out**
- **AWS/Snowflake EC2 connection scripts**
- **Dag to bring in S3 bucket data via Airflow with Astro SDK**
- **Necessary Airflow directory for build**
- **Shell Scripts to operate airflow and check connections without needing to access the web UI**
- **Dag to build out Data WArehouse properly in Snowflake**
- **Dockerfile to build out Airflow app**


### Phase 3
- **Snowflake SQL files to manually build out Data Warehouse in properly in Snowflake**
- **Python scripts to build out Datamart in Dynamo DB**
- **Python script to build out Data Recommender database in Postgres**
- **Shell scripts to build out and run recommender via Postgres**
- **Shell scripts to build out Datamart via dynamoDB in AWS**

### 📖 Phase 4
- **Terraform files**
- **p\ermission less credentials**
- ****

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