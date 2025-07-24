# 🐧 Ubuntu PostgreSQL Recommender System Setup Guide

This guide will help you set up PostgreSQL on Ubuntu and configure the recommender system with interactive credential confirmation.

## 🚀 Quick Start

### One-Command Setup (Recommended)

```bash
# Navigate to the Phase 3 directory
cd Phase_3_Data_Warehouse_and_Analytics_Tools

# Make the script executable
chmod +x setup_postgres_ubuntu.sh

# Run the Ubuntu setup script
./setup_postgres_ubuntu.sh
```

The script will:
1. ✅ Check Ubuntu version and prerequisites
2. 🔐 Prompt you for database credentials
3. 📦 Install PostgreSQL automatically
4. 🏗️ Configure the database and user
5. 📊 Create the analytics schema
6. 🐍 Install Python dependencies
7. 📝 Create environment configuration
8. ✅ Test the complete setup

## 📋 Prerequisites

- **Ubuntu 18.04+** (20.04 LTS recommended)
- **sudo privileges** (for package installation)
- **Internet connection** (for downloading packages)
- **Python 3.8+** (will be installed if needed)

## 🔐 Credential Setup Process

The script will interactively prompt you for:

### 1. PostgreSQL Password
```
Enter PostgreSQL password for 'postgres' user: [hidden input]
Confirm password: [hidden input]
```

### 2. Configuration Confirmation
```
Database configuration:
  Host: localhost
  Port: 5432
  Database: ecommerce_analytics
  User: postgres
  Password: ********

Proceed with this configuration? (y/n): y
```

## 🏗️ What Gets Installed

### System Packages
- **PostgreSQL 12+** (latest available)
- **PostgreSQL contrib** (additional utilities)
- **Python 3 pip** (if not already installed)

### Python Dependencies
- **psycopg2-binary** (PostgreSQL adapter)
- **pandas** (data processing)
- **numpy** (numerical computing)
- **python-dotenv** (environment management)

### Database Setup
- **Database**: `ecommerce_analytics`
- **Schema**: `analytics`
- **User**: `postgres` (with your chosen password)
- **Permissions**: Full access to the database

## 📊 Expected Output

After successful setup, you should see:

```
==========================================
🎯 POSTGRESQL CONNECTION INFORMATION
==========================================

Host: localhost
Port: 5432
Database: ecommerce_analytics
User: postgres
Password: your_password_here

==========================================
🎉 SETUP COMPLETE - NEXT STEPS
==========================================

PostgreSQL recommender system is ready!

To run the recommender system:
  python3 setup_postgres_recommender_complete.py

To test the setup:
  python3 test_postgres_recommender.py

To connect to database:
  psql -h localhost -p 5432 -U postgres -d ecommerce_analytics

Environment file created: .env
==========================================
```

## 🧪 Verification

After setup, verify everything is working:

```bash
# Run the verification script
python3 verify_ubuntu_setup.py
```

This will test:
- ✅ Environment configuration
- ✅ Database connection
- ✅ Analytics schema
- ✅ psql command line access

## 🔍 Troubleshooting

### Common Issues

**1. Permission Denied**
```bash
❌ This script should not be run as root. Please run as a regular user.
```
**Solution**: Run as a regular user, not root:
```bash
# Don't run as root
sudo ./setup_postgres_ubuntu.sh  # ❌ Wrong

# Run as regular user
./setup_postgres_ubuntu.sh       # ✅ Correct
```

**2. PostgreSQL Service Not Starting**
```bash
❌ Failed to start PostgreSQL service
```
**Solution**: Check system resources and try manual start:
```bash
sudo systemctl status postgresql
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**3. Connection Failed**
```bash
❌ Database connection failed: connection to server at "localhost" (127.0.0.1), port 5432 failed
```
**Solution**: Check PostgreSQL is running and credentials are correct:
```bash
sudo systemctl status postgresql
psql -h localhost -U postgres -d ecommerce_analytics
```

**4. Python Dependencies Missing**
```bash
❌ ModuleNotFoundError: No module named 'psycopg2'
```
**Solution**: Install Python dependencies manually:
```bash
pip3 install psycopg2-binary pandas numpy python-dotenv
```

### Reset and Retry

If something goes wrong, you can reset and try again:

```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove PostgreSQL (optional - for complete reset)
sudo apt-get remove --purge postgresql*

# Remove database files (optional - for complete reset)
sudo rm -rf /var/lib/postgresql/

# Run setup again
./setup_postgres_ubuntu.sh
```

## 🔧 Manual Configuration

If you prefer to configure manually:

### 1. Install PostgreSQL
```bash
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib postgresql-client
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### 2. Configure User
```bash
sudo -u postgres psql
ALTER USER postgres PASSWORD 'your_password_here';
CREATE DATABASE ecommerce_analytics;
GRANT ALL PRIVILEGES ON DATABASE ecommerce_analytics TO postgres;
\q
```

### 3. Create Schema
```bash
psql -h localhost -U postgres -d ecommerce_analytics -c "CREATE SCHEMA IF NOT EXISTS analytics;"
```

### 4. Install Python Dependencies
```bash
pip3 install psycopg2-binary pandas numpy python-dotenv
```

### 5. Create Environment File
```bash
cat > .env << EOF
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DATABASE=ecommerce_analytics
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password_here
EOF
```

## 📊 Security Considerations

### Password Security
- Use a strong password (12+ characters, mixed case, numbers, symbols)
- Don't use the same password as other services
- Consider using a password manager

### Network Security
- PostgreSQL is configured to listen only on localhost by default
- For production, consider:
  - Firewall rules
  - SSL certificates
  - Network isolation

### File Permissions
- The `.env` file contains sensitive credentials
- Set appropriate permissions:
```bash
chmod 600 .env
```

## 🔄 Updating the Setup

To update PostgreSQL or dependencies:

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade

# Update PostgreSQL
sudo apt-get install --only-upgrade postgresql postgresql-contrib

# Update Python packages
pip3 install --upgrade psycopg2-binary pandas numpy python-dotenv
```

## 📈 Performance Tuning

### PostgreSQL Configuration
For better performance, edit `/etc/postgresql/*/main/postgresql.conf`:

```conf
# Memory settings
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB

# Connection settings
max_connections = 100

# Logging
log_statement = 'all'
log_duration = on
```

### Restart PostgreSQL after changes:
```bash
sudo systemctl restart postgresql
```

## 🎯 Next Steps

After successful setup:

1. **Run the recommender system**:
   ```bash
   python3 setup_postgres_recommender_complete.py
   ```

2. **Test the recommender**:
   ```bash
   python3 test_postgres_recommender.py
   ```

3. **Connect to database**:
   ```bash
   psql -h localhost -p 5432 -U postgres -d ecommerce_analytics
   ```

4. **Explore the data**:
   ```sql
   \dt analytics.*
   SELECT * FROM analytics.user_behavior_features LIMIT 5;
   ```

## 📚 Additional Resources

- [PostgreSQL Ubuntu Installation](https://www.postgresql.org/download/linux/ubuntu/)
- [PostgreSQL Configuration](https://www.postgresql.org/docs/current/runtime-config.html)
- [psycopg2 Documentation](https://www.psycopg.org/docs/)
- [Ubuntu System Administration](https://ubuntu.com/server/docs)

---

**🎉 Congratulations!** You now have a fully configured PostgreSQL database ready for the recommender system on Ubuntu. 