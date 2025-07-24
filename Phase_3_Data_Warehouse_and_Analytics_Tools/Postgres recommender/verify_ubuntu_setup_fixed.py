#!/usr/bin/env python3
"""
Ubuntu PostgreSQL Setup Verification Script
This script verifies the PostgreSQL setup and confirms database credentials.
"""

import os
import sys
import psycopg2
import psycopg2.extras
import logging
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class UbuntuSetupVerifier:
    def __init__(self):
        self.db_config = {
            'host': os.getenv('POSTGRES_HOST', 'localhost'),
            'port': int(os.getenv('POSTGRES_PORT', '5432')),
            'database': os.getenv('POSTGRES_DATABASE', 'ecommerce_analytics'),
            'user': os.getenv('POSTGRES_USER', 'postgres'),
            'password': os.getenv('POSTGRES_PASSWORD', '')
        }

    def verify_environment_file(self):
        """Verify that .env file exists and has required variables"""
        logger.info("🔍 Verifying environment configuration...")
        
        required_vars = [
            'POSTGRES_HOST', 'POSTGRES_PORT', 'POSTGRES_DATABASE',
            'POSTGRES_USER', 'POSTGRES_PASSWORD'
        ]
        
        missing_vars = []
        for var in required_vars:
            if not os.getenv(var):
                missing_vars.append(var)
        
        if missing_vars:
            logger.error(f"❌ Missing environment variables: {', '.join(missing_vars)}")
            logger.error("Please run the Ubuntu setup script first: ./setup_postgres_ubuntu.sh")
            return False
        
        logger.info("✅ Environment variables found")
        return True

    def test_database_connection(self):
        """Test database connection with current credentials"""
        logger.info("🔍 Testing database connection...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Test basic query
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
            logger.info(f"✅ Database connection successful")
            logger.info(f"   PostgreSQL version: {version.split(',')[0]}")
            
            # Test database name
            cursor.execute("SELECT current_database()")
            db_name = cursor.fetchone()[0]
            logger.info(f"   Connected to database: {db_name}")
            
            # Test user
            cursor.execute("SELECT current_user")
            user = cursor.fetchone()[0]
            logger.info(f"   Connected as user: {user}")
            
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"❌ Database connection failed: {e}")
            return False

    def verify_analytics_schema(self):
        """Verify that analytics schema exists"""
        logger.info("🔍 Verifying analytics schema...")
        
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Check if analytics schema exists
            cursor.execute("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name = 'analytics'
            """)
            
            if cursor.fetchone():
                logger.info("✅ Analytics schema exists")
                
                # List tables in analytics schema
                cursor.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = 'analytics'
                    ORDER BY table_name
                """)
                
                tables = [row[0] for row in cursor.fetchall()]
                if tables:
                    logger.info(f"   Tables found: {', '.join(tables)}")
                else:
                    logger.info("   No tables found (this is normal for fresh setup)")
                
                conn.close()
                return True
            else:
                logger.error("❌ Analytics schema not found")
                conn.close()
                return False
                
        except Exception as e:
            logger.error(f"❌ Schema verification failed: {e}")
            return False

    def test_psql_command(self):
        """Test psql command line access"""
        logger.info("🔍 Testing psql command line access...")
        
        try:
            import subprocess
            
            # Test psql connection
            cmd = [
                'psql', '-h', self.db_config['host'],
                '-p', str(self.db_config['port']),
                '-U', self.db_config['user'],
                '-d', self.db_config['database'],
                '-c', 'SELECT version();'
            ]
            
            env = os.environ.copy()
            env['PGPASSWORD'] = self.db_config['password']
            
            result = subprocess.run(
                cmd, 
                capture_output=True, 
                text=True, 
                env=env,
                timeout=10
            )
            
            if result.returncode == 0:
                logger.info("✅ psql command line access successful")
                return True
            else:
                logger.error(f"❌ psql command failed: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"❌ psql test failed: {e}")
            return False

    def display_connection_summary(self):
        """Display a summary of the connection configuration"""
        logger.info("📊 Connection Configuration Summary:")
        logger.info(f"   Host: {self.db_config['host']}")
        logger.info(f"   Port: {self.db_config['port']}")
        logger.info(f"   Database: {self.db_config['database']}")
        logger.info(f"   User: {self.db_config['user']}")
        logger.info(f"   Password: {'*' * len(self.db_config['password'])}")

    def run_complete_verification(self):
        """Run all verification tests"""
        logger.info("🚀 Starting Ubuntu PostgreSQL setup verification...")
        
        tests = [
            ("Environment Configuration", self.verify_environment_file),
            ("Database Connection", self.test_database_connection),
            ("Analytics Schema", self.verify_analytics_schema),
            ("psql Command Line", self.test_psql_command)
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            logger.info(f"\n📋 Running test: {test_name}")
            if test_func():
                passed += 1
                logger.info(f"✅ {test_name} PASSED")
            else:
                logger.error(f"❌ {test_name} FAILED")
        
        logger.info(f"\n📊 Verification Results: {passed}/{total} tests passed")
        
        if passed == total:
            logger.info("🎉 All verification tests passed!")
            self.display_connection_summary()
            return True
        else:
            logger.error(f"❌ {total - passed} test(s) failed.")
            return False

def main():
    """Main function to run verification"""
    print("🔍 Ubuntu PostgreSQL Setup Verification")
    print("=" * 50)
    
    verifier = UbuntuSetupVerifier()
    
    try:
        success = verifier.run_complete_verification()
        if success:
            print("\n🎉 Verification completed successfully!")
            print("\n📋 Your PostgreSQL setup is ready for the recommender system.")
            print("\n💡 Next steps:")
            print("1. Run the recommender setup: python3 setup_postgres_recommender_complete.py")
            print("2. Test the recommender: python3 test_postgres_recommender.py")
            print("3. Connect to database: psql -h localhost -p 5432 -U postgres -d ecommerce_analytics")
        else:
            print("\n❌ Some verification tests failed.")
            print("\n💡 Troubleshooting:")
            print("1. Make sure you ran the Ubuntu setup script: ./setup_postgres_ubuntu.sh")
            print("2. Check that PostgreSQL is running: sudo systemctl status postgresql")
            print("3. Verify your credentials in the .env file")
            print("4. Try running the setup script again")
            
    except KeyboardInterrupt:
        print("\n⚠️ Verification interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")

if __name__ == "__main__":
    main() 