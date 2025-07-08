"""
Connection manager utility for Airflow connections.

This module provides utilities for managing Airflow connections
for external systems like Snowflake and AWS.
"""

import subprocess
from pathlib import Path
from typing import Dict, Optional

from src.config.settings import ConnectionConfig, SetupConfig


class ConnectionManager:
    """Manages Airflow connections for external systems."""
    
    def __init__(self, config: SetupConfig) -> None:
        """
        Initialize the connection manager.
        
        Args:
            config (SetupConfig): Complete setup configuration
        """
        self.config = config
        self.connections = config.connections
        self.paths = config.paths
        
    def setup_all_connections(self) -> bool:
        """
        Set up all configured connections in Airflow.
        
        Returns:
            bool: True if all connections were set up successfully
        """
        print("🔗 Setting up Airflow connections...")
        
        success = True
        
        if self._has_snowflake_config():
            success &= self.setup_snowflake_connection()
            
        if self._has_aws_config():
            success &= self.setup_aws_connections()
            
        if success:
            print("✅ All connections set up successfully")
        else:
            print("❌ Some connections failed to set up")
            
        return success
    
    def setup_snowflake_connection(self) -> bool:
        """
        Set up Snowflake connection in Airflow.
        
        Returns:
            bool: True if Snowflake connection was set up successfully
        """
        if not self._has_snowflake_config():
            print("⚠️  Snowflake configuration not complete, skipping...")
            return True
            
        print("❄️  Creating Snowflake connection...")
        
        try:
            # Build connection parameters
            extra_config = {
                "account": self.connections.snowflake_account,
                "warehouse": self.connections.snowflake_warehouse,
                "database": self.connections.snowflake_database,
                "region": self.connections.aws_region
            }
            
            # Create connection command
            cmd = [
                str(self.paths.airflow_project / "venv" / "bin" / "airflow"),
                "connections", "add", "snowflake_default",
                "--conn-type", "snowflake",
                "--conn-host", f"{self.connections.snowflake_account}.snowflakecomputing.com",
                "--conn-login", self.connections.snowflake_user,
                "--conn-password", self.connections.snowflake_password,
                "--conn-schema", self.connections.snowflake_schema,
                "--conn-port", "443",
                "--conn-extra", str(extra_config).replace("'", '"')
            ]
            
            result = self._run_airflow_command(cmd)
            
            if result:
                print("✅ Snowflake connection created successfully")
                return True
            else:
                print("❌ Failed to create Snowflake connection")
                return False
                
        except Exception as e:
            print(f"❌ Error creating Snowflake connection: {e}")
            return False
    
    def setup_aws_connections(self) -> bool:
        """
        Set up AWS and S3 connections in Airflow.
        
        Returns:
            bool: True if AWS connections were set up successfully
        """
        if not self._has_aws_config():
            print("⚠️  AWS configuration not complete, skipping...")
            return True
            
        print("☁️  Creating AWS connections...")
        
        # Set up S3 connection
        s3_success = self._setup_s3_connection()
        
        # Set up AWS connection
        aws_success = self._setup_aws_connection()
        
        return s3_success and aws_success
    
    def _setup_s3_connection(self) -> bool:
        """Set up S3 connection."""
        try:
            extra_config = {
                "aws_access_key_id": self.connections.aws_access_key_id,
                "aws_secret_access_key": self.connections.aws_secret_access_key,
                "region_name": self.connections.aws_region
            }
            
            cmd = [
                str(self.paths.airflow_project / "venv" / "bin" / "airflow"),
                "connections", "add", "s3_default",
                "--conn-type", "s3",
                "--conn-login", self.connections.aws_access_key_id,
                "--conn-password", self.connections.aws_secret_access_key,
                "--conn-extra", str(extra_config).replace("'", '"')
            ]
            
            if self._run_airflow_command(cmd):
                print("✅ S3 connection created successfully")
                return True
            else:
                print("❌ Failed to create S3 connection")
                return False
                
        except Exception as e:
            print(f"❌ Error creating S3 connection: {e}")
            return False
    
    def _setup_aws_connection(self) -> bool:
        """Set up general AWS connection."""
        try:
            extra_config = {
                "region_name": self.connections.aws_region,
                "aws_access_key_id": self.connections.aws_access_key_id,
                "aws_secret_access_key": self.connections.aws_secret_access_key
            }
            
            cmd = [
                str(self.paths.airflow_project / "venv" / "bin" / "airflow"),
                "connections", "add", "aws_default",
                "--conn-type", "aws",
                "--conn-extra", str(extra_config).replace("'", '"')
            ]
            
            if self._run_airflow_command(cmd):
                print("✅ AWS connection created successfully")
                return True
            else:
                print("❌ Failed to create AWS connection")
                return False
                
        except Exception as e:
            print(f"❌ Error creating AWS connection: {e}")
            return False
    
    def _has_snowflake_config(self) -> bool:
        """Check if Snowflake configuration is complete."""
        return all([
            self.connections.snowflake_account,
            self.connections.snowflake_user,
            self.connections.snowflake_password,
            self.connections.snowflake_database,
            self.connections.snowflake_schema,
            self.connections.snowflake_warehouse
        ])
    
    def _has_aws_config(self) -> bool:
        """Check if AWS configuration is complete."""
        return all([
            self.connections.aws_access_key_id,
            self.connections.aws_secret_access_key
        ])
    
    def _run_airflow_command(self, cmd: list) -> bool:
        """
        Run an Airflow command with proper environment.
        
        Args:
            cmd (list): Command to run
            
        Returns:
            bool: True if command was successful
        """
        try:
            env = {
                "AIRFLOW_HOME": str(self.paths.airflow_home),
                "PYTHONPATH": str(self.paths.airflow_project),
                "PATH": subprocess.os.environ.get("PATH", "")
            }
            
            result = subprocess.run(
                cmd,
                env=env,
                capture_output=True,
                text=True,
                cwd=str(self.paths.airflow_project)
            )
            
            # Connection might already exist, which is okay
            if result.returncode == 0 or "already exist" in result.stderr:
                return True
            else:
                print(f"Command failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"Error running command: {e}")
            return False
    
    def load_connections_from_env_file(self, env_file_path: Path) -> bool:
        """
        Load connection configuration from environment file.
        
        Args:
            env_file_path (Path): Path to the environment file
            
        Returns:
            bool: True if configuration was loaded successfully
        """
        if not env_file_path.exists():
            print(f"❌ Environment file not found: {env_file_path}")
            return False
            
        try:
            print(f"📋 Loading connections from {env_file_path}")
            
            with open(env_file_path, "r") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("export "):
                        # Parse export statements
                        line = line[7:]  # Remove "export "
                        if "=" in line:
                            key, value = line.split("=", 1)
                            value = value.strip('"\'')  # Remove quotes
                            
                            # Map environment variables to connection config
                            self._map_env_variable(key, value)
            
            print("✅ Environment variables loaded successfully")
            return True
            
        except Exception as e:
            print(f"❌ Error loading environment file: {e}")
            return False
    
    def _map_env_variable(self, key: str, value: str) -> None:
        """
        Map environment variable to connection configuration.
        
        Args:
            key (str): Environment variable name
            value (str): Environment variable value
        """
        # Mapping of environment variables to connection config attributes
        env_mapping = {
            "SNOWFLAKE_ACCOUNT": "snowflake_account",
            "SNOWFLAKE_USER": "snowflake_user", 
            "SNOWFLAKE_PASSWORD": "snowflake_password",
            "SNOWFLAKE_DATABASE": "snowflake_database",
            "SNOWFLAKE_SCHEMA": "snowflake_schema",
            "SNOWFLAKE_WAREHOUSE": "snowflake_warehouse",
            "AWS_ACCESS_KEY_ID": "aws_access_key_id",
            "AWS_SECRET_ACCESS_KEY": "aws_secret_access_key",
            "AWS_DEFAULT_REGION": "aws_region"
        }
        
        if key in env_mapping:
            setattr(self.connections, env_mapping[key], value) 