# PostgreSQL Analytics Database Deployment Guide - Phase 3

This guide provides step-by-step instructions for deploying a PostgreSQL analytics database on Ubuntu EC2 instances for Phase 3 of the Online Retail Project.

## 📋 Overview

The PostgreSQL deployment creates a complete analytics database that mirrors the Snowflake ANALYTICS schema, enabling:
- Local analytics processing
- Alternative database platform for analytics
- Backup analytics infrastructure
- High-performance local queries

## 🏗️ Architecture

```
Snowflake ANALYTICS Schema
    ↓ (Export)
┌─────────────────────────────┐
│   PostgreSQL Database       │
│   - ecommerce_analytics     │
│   - analytics schema        │
│   - All analytics tables    │
│   - Indexes & Views         │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│     Applications            │
│   - BI Tools                │
│   - Custom Analytics        │
│   - Reporting Systems       │
└─────────────────────────────┘
```

## 📋 Prerequisites

### System Requirements
- Ubuntu 20.04+ EC2 instance
- Minimum 4GB RAM (8GB recommended)
- 50GB+ storage space
- Internet connectivity

### Credentials Needed
- Snowflake account credentials
- AWS EC2 access
- SSH key pair for EC2 access

## 🚀 Quick Deployment

### Option 1: Automated Deployment

```bash
# Download and run the deployment script
curl -sSL https://raw.githubusercontent.com/your-repo/deploy_postgres_on_ec2.sh -o deploy_postgres_on_ec2.sh
chmod +x deploy_postgres_on_ec2.sh
sudo ./deploy_postgres_on_ec2.sh
```

### Option 2: Manual Step-by-Step

Follow the detailed steps below for manual installation.

## 📝 Step-by-Step Deployment

### Step 1: Launch EC2 Instance

1. **AMI**: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
2. **Instance Type**: t3.medium or larger (minimum 4GB RAM)
3. **Key Pair**: Create or select existing key pair
4. **Security Group**:
   - SSH (22) from your IP
   - PostgreSQL (5432) from trusted IPs
   - HTTPS (443) outbound
   - HTTP (80) outbound

### Step 2: Connect to Instance

```bash
ssh -i "your-key.pem" ubuntu@your-instance-ip
```

### Step 3: System Update

```bash
sudo apt update
sudo apt upgrade -y
```

### Step 4: Install PostgreSQL

```bash
# Add PostgreSQL repository
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Update package list
sudo apt update

# Install PostgreSQL 15
sudo apt install -y postgresql-15 postgresql-client-15 postgresql-contrib-15

# Start and enable service
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Step 5: Configure PostgreSQL

```bash
# Set postgres user password
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'your_secure_password';"

# Create application user
sudo -u postgres createuser --createdb --no-superuser --no-createrole ecommerce_app
sudo -u postgres psql -c "ALTER USER ecommerce_app PASSWORD 'app_secure_password';"

# Create analytics database
sudo -u postgres createdb ecommerce_analytics -O ecommerce_app
```

### Step 6: Configure Network Access

```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/15/main/postgresql.conf

# Find and modify:
listen_addresses = '*'
port = 5432

# Edit client authentication
sudo nano /etc/postgresql/15/main/pg_hba.conf

# Add lines for application access:
host    ecommerce_analytics    ecommerce_app    0.0.0.0/0    md5
host    ecommerce_analytics    postgres         0.0.0.0/0    md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Step 7: Setup Database Schema

```bash
# Download schema setup script
wget https://raw.githubusercontent.com/your-repo/postgres_schema_setup.sql

# Run schema setup
sudo -u postgres psql -f postgres_schema_setup.sql
```

### Step 8: Install Python Environment

```bash
# Install Python dependencies
sudo apt install -y python3 python3-pip python3-venv python3-dev

# Create application directory
sudo mkdir -p /opt/ecommerce-postgres
cd /opt/ecommerce-postgres

# Create virtual environment
sudo python3 -m venv venv

# Install packages
sudo ./venv/bin/pip install psycopg2-binary snowflake-connector-python python-dotenv
```

### Step 9: Configure Application

```bash
# Create environment file
sudo nano /opt/ecommerce-postgres/.env
```

Add configuration:
```bash
# Snowflake Configuration
SNOWFLAKE_ACCOUNT=your_account_identifier
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_WAREHOUSE=ECOMMERCE_WH
SNOWFLAKE_DATABASE=ECOMMERCE_DB
SNOWFLAKE_SCHEMA=ANALYTICS

# PostgreSQL Configuration
POSTGRES_HOST=localhost
POSTGRES_DATABASE=ecommerce_analytics
POSTGRES_USER=ecommerce_app
POSTGRES_PASSWORD=app_secure_password
POSTGRES_PORT=5432
```

### Step 10: Deploy Application Files

```bash
# Download export scripts
cd /opt/ecommerce-postgres
sudo wget https://raw.githubusercontent.com/your-repo/export_to_postgres_enhanced.py
sudo wget https://raw.githubusercontent.com/your-repo/setup_postgres_export.py

# Make executable
sudo chmod +x *.py
```

### Step 11: Test Setup

```bash
# Verify setup
sudo -u postgres /opt/ecommerce-postgres/venv/bin/python /opt/ecommerce-postgres/setup_postgres_export.py
```

Expected output:
```
✓ All required environment variables are set
✓ PostgreSQL connection successful
✓ Analytics schema exists
✓ Found X tables in analytics schema
✓ Snowflake connection successful
✓ Snowflake data available for export
✓ All tests passed - PostgreSQL setup is ready!
```

## 🔄 Running the Export

### Manual Export

```bash
# Run export manually
cd /opt/ecommerce-postgres
sudo -u postgres ./venv/bin/python export_to_postgres_enhanced.py
```

### Automated Export

```bash
# Enable daily automatic exports
sudo systemctl enable postgres-export.timer
sudo systemctl start postgres-export.timer

# Check timer status
sudo systemctl status postgres-export.timer
```

## 📊 Database Schema

### Core Tables

| Table | Purpose | Records |
|-------|---------|---------|
| `customer_360_profile` | Complete customer profiles | ~148 customers |
| `user_segments` | Customer segmentation | Regular/New customers |
| `user_product_recommendations` | ML recommendations | Product suggestions |
| `stg_events_cart` | Cart event staging | Raw cart events |
| `stg_events_purchase` | Purchase event staging | Raw purchase events |
| `stg_events_view` | View event staging | Raw view events |

### Analytics Tables (Auto-Generated)

| Table | Purpose | Source |
|-------|---------|--------|
| `product_analytics` | Product performance metrics | Derived from events |
| `brand_analytics` | Brand performance metrics | Aggregated data |
| `category_analytics` | Category performance | Event analysis |

### Views

| View | Purpose |
|------|---------|
| `customer_summary` | Combined customer insights |
| `product_performance` | Product KPIs and rankings |
| `brand_performance` | Brand analysis with rankings |

## 🔍 Monitoring and Maintenance

### Service Status

```bash
# Check PostgreSQL service
sudo systemctl status postgresql

# Check export service
sudo systemctl status postgres-export.service

# Check export timer
sudo systemctl status postgres-export.timer
```

### Logs

```bash
# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log

# Application logs
sudo tail -f /var/log/ecommerce-app/postgres_export.log

# System logs
sudo journalctl -u postgres-export.service -f
```

### Database Maintenance

```bash
# Connect to database
psql -h localhost -U ecommerce_app -d ecommerce_analytics

# Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'analytics'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

# Check data counts
SELECT 
    table_name,
    (xpath('/row/cnt/text()', xml_count))[1]::text::int as row_count
FROM (
    SELECT 
        table_name, 
        query_to_xml(format('select count(*) as cnt from analytics.%I', table_name), false, true, '') as xml_count
    FROM information_schema.tables 
    WHERE table_schema = 'analytics'
) t;
```

## 🔧 Performance Optimization

### Index Management

```sql
-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'analytics'
ORDER BY idx_scan DESC;

-- Create additional indexes as needed
CREATE INDEX idx_custom ON analytics.table_name(column_name);
```

### Query Performance

```sql
-- Enable query timing
\timing

-- Analyze table statistics
ANALYZE analytics.customer_360_profile;

-- Check query plans
EXPLAIN ANALYZE SELECT * FROM analytics.customer_summary LIMIT 10;
```

## 🔒 Security Configuration

### Database Security

```sql
-- Review user permissions
\du

-- Check table permissions
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type 
FROM information_schema.table_privileges 
WHERE table_schema = 'analytics';
```

### Network Security

```bash
# Configure UFW firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 5432/tcp  # PostgreSQL (restrict as needed)

# Check listening ports
sudo netstat -tlnp | grep 5432
```

## 📈 Scaling Considerations

### Hardware Scaling

- **CPU**: Scale up for complex analytics queries
- **Memory**: More RAM improves query performance
- **Storage**: Use SSD for better I/O performance

### Database Scaling

```sql
-- Configure memory settings in postgresql.conf
shared_buffers = 1GB                    # 25% of RAM
effective_cache_size = 3GB             # 75% of RAM
work_mem = 4MB                         # Per query operation
maintenance_work_mem = 256MB           # Maintenance operations
```

## 🔄 Backup and Recovery

### Database Backup

```bash
# Full database backup
pg_dump -h localhost -U ecommerce_app ecommerce_analytics > backup_$(date +%Y%m%d).sql

# Schema-only backup
pg_dump -h localhost -U ecommerce_app -s ecommerce_analytics > schema_backup.sql

# Automated daily backup script
cat > /opt/ecommerce-postgres/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/ecommerce-postgres/backups"
mkdir -p $BACKUP_DIR
pg_dump -h localhost -U ecommerce_app ecommerce_analytics > $BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql
find $BACKUP_DIR -name "backup_*.sql" -mtime +7 -delete
EOF

chmod +x /opt/ecommerce-postgres/backup.sh
```

### Recovery

```bash
# Restore from backup
psql -h localhost -U ecommerce_app ecommerce_analytics < backup_file.sql
```

## 🚨 Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   
   # Check port binding
   sudo netstat -tlnp | grep 5432
   
   # Check configuration
   sudo grep listen_addresses /etc/postgresql/15/main/postgresql.conf
   ```

2. **Authentication Failed**
   ```bash
   # Check pg_hba.conf
   sudo cat /etc/postgresql/15/main/pg_hba.conf | grep ecommerce
   
   # Reset password
   sudo -u postgres psql -c "ALTER USER ecommerce_app PASSWORD 'new_password';"
   ```

3. **Export Fails**
   ```bash
   # Check Snowflake connectivity
   ./venv/bin/python setup_postgres_export.py
   
   # Check logs
   tail -f /var/log/ecommerce-app/postgres_export.log
   ```

4. **Performance Issues**
   ```sql
   -- Check slow queries
   SELECT query, mean_time, calls 
   FROM pg_stat_statements 
   ORDER BY mean_time DESC 
   LIMIT 10;
   
   -- Update table statistics
   ANALYZE;
   ```

## 📊 Success Metrics

After successful deployment:

### Data Validation
- ✅ All Snowflake tables exported successfully
- ✅ Data integrity maintained across platforms
- ✅ Analytics views functional
- ✅ Performance within acceptable limits

### Operational Metrics
- ✅ Automated daily exports running
- ✅ Database backup system active
- ✅ Monitoring and alerting configured
- ✅ Security policies enforced

## 🚀 Next Steps

1. **Application Integration**
   - Connect BI tools to PostgreSQL
   - Develop custom analytics dashboards
   - Set up real-time analytics

2. **Advanced Features**
   - Implement materialized views
   - Set up read replicas
   - Configure connection pooling

3. **Monitoring Enhancement**
   - Set up performance monitoring
   - Configure alerting
   - Implement log analysis

For additional support, refer to the PostgreSQL documentation or contact the development team. 