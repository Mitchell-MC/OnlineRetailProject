"""
Airflow installer module for setting up Apache Airflow.

This module handles Airflow installation, configuration, database initialization,
and service configuration, replacing the Airflow-specific sections from the shell script.
"""

import os
import subprocess
import secrets
from pathlib import Path
from typing import Dict, Optional

from cryptography.fernet import Fernet

from src.config.settings import SetupConfig


class AirflowInstaller:
    """Handles Airflow installation and configuration."""
    
    def __init__(self, config: SetupConfig) -> None:
        """
        Initialize the Airflow installer.
        
        Args:
            config (SetupConfig): Complete setup configuration
        """
        self.config = config
        self.paths = config.paths
        self.airflow_config = config.airflow
        
    def setup_python_environment(self) -> bool:
        """
        Set up Python virtual environment and install Airflow.
        
        Returns:
            bool: True if environment setup was successful
        """
        print("🐍 Setting up Python virtual environment...")
        
        # Create virtual environment
        if not self._create_virtual_environment():
            return False
            
        # Install Airflow and dependencies
        if not self._install_airflow_packages():
            return False
            
        return True
    
    def initialize_airflow(self) -> bool:
        """
        Initialize Airflow database and create admin user.
        
        Returns:
            bool: True if initialization was successful
        """
        print("⚙️ Initializing Airflow...")
        
        # Generate security keys
        self._generate_security_keys()
        
        # Create Airflow configuration
        if not self._create_airflow_config():
            return False
            
        # Initialize database
        if not self._initialize_database():
            return False
            
        # Create admin user
        if not self._create_admin_user():
            return False
            
        return True
    
    def setup_systemd_services(self) -> bool:
        """
        Set up systemd services for Airflow webserver and scheduler.
        
        Returns:
            bool: True if service setup was successful
        """
        print("🔧 Setting up systemd services...")
        
        # Create service files
        if not self._create_service_files():
            return False
            
        # Enable and configure services
        if not self._configure_services():
            return False
            
        return True
    
    def _create_virtual_environment(self) -> bool:
        """
        Create Python virtual environment.
        
        Returns:
            bool: True if virtual environment creation was successful
        """
        try:
            venv_path = self.paths.airflow_project / "venv"
            
            # Create virtual environment
            subprocess.run([
                "python3", "-m", "venv", str(venv_path)
            ], check=True, cwd=str(self.paths.airflow_project))
            
            # Upgrade pip
            pip_path = venv_path / "bin" / "pip"
            subprocess.run([
                str(pip_path), "install", "--upgrade", "pip"
            ], check=True)
            
            print("✅ Virtual environment created successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to create virtual environment: {e}")
            return False
        except Exception as e:
            print(f"❌ Error creating virtual environment: {e}")
            return False
    
    def _install_airflow_packages(self) -> bool:
        """
        Install Airflow and dependencies from requirements.txt.
        
        Returns:
            bool: True if package installation was successful
        """
        try:
            print("📚 Installing Airflow and dependencies...")
            
            pip_path = self.paths.airflow_project / "venv" / "bin" / "pip"
            requirements_path = self.paths.airflow_project / "requirements.txt"
            
            # Install from requirements.txt
            subprocess.run([
                str(pip_path), "install", "-r", str(requirements_path)
            ], check=True, timeout=1800)  # 30 minutes timeout
            
            print("✅ Airflow packages installed successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to install Airflow packages: {e}")
            return False
        except subprocess.TimeoutExpired:
            print("❌ Airflow package installation timed out")
            return False
        except Exception as e:
            print(f"❌ Error installing Airflow packages: {e}")
            return False
    
    def _generate_security_keys(self) -> None:
        """Generate security keys for Airflow configuration."""
        # Generate Fernet key for encryption
        if not self.airflow_config.fernet_key:
            self.airflow_config.fernet_key = Fernet.generate_key().decode()
            
        # Generate secret key for web sessions
        if not self.airflow_config.secret_key:
            self.airflow_config.secret_key = secrets.token_hex(32)
    
    def _create_airflow_config(self) -> bool:
        """
        Create Airflow configuration file.
        
        Returns:
            bool: True if configuration file creation was successful
        """
        try:
            print("🔧 Creating Airflow configuration...")
            
            # Ensure Airflow home directory exists
            self.paths.airflow_home.mkdir(parents=True, exist_ok=True)
            
            config_content = self._generate_airflow_config_content()
            config_path = self.paths.airflow_home / "airflow.cfg"
            
            with open(config_path, "w") as f:
                f.write(config_content)
            
            print("✅ Airflow configuration created successfully")
            return True
            
        except Exception as e:
            print(f"❌ Error creating Airflow configuration: {e}")
            return False
    
    def _generate_airflow_config_content(self) -> str:
        """
        Generate Airflow configuration file content.
        
        Returns:
            str: Airflow configuration file content
        """
        return f"""[core]
dags_folder = {self.paths.dags_folder}
plugins_folder = {self.paths.plugins_folder}
executor = {self.airflow_config.executor}
sql_alchemy_conn = {self.airflow_config.database_url}
load_examples = {str(self.airflow_config.load_examples).lower()}
fernet_key = {self.airflow_config.fernet_key}
default_timezone = utc
max_active_tasks_per_dag = 16
max_active_runs_per_dag = 16

[webserver]
web_server_host = {self.airflow_config.web_server_host}
web_server_port = {self.airflow_config.web_server_port}
secret_key = {self.airflow_config.secret_key}
base_url = http://localhost:{self.airflow_config.web_server_port}
enable_proxy_fix = True
expose_config = True

[scheduler]
job_heartbeat_sec = 5
scheduler_heartbeat_sec = 5
num_runs = -1
processor_poll_interval = 1
min_file_process_interval = 0
dag_dir_list_interval = 300
print_stats_interval = 30
pool_metrics_interval = 5.0
scheduler_zombie_task_threshold = 300
catchup_by_default = False
max_tis_per_query = 512

[logging]
base_log_folder = {self.paths.logs_folder}
dag_processor_manager_log_location = {self.paths.logs_folder}/dag_processor_manager/dag_processor_manager.log
remote_logging = False
logging_level = INFO
fab_logging_level = WARN

[celery]
broker_url = redis://localhost:6379/0
result_backend = db+postgresql://airflow:airflow@localhost/airflow
worker_concurrency = 16

[api]
auth_backends = airflow.api.auth.backend.basic_auth

[email]
email_backend = airflow.utils.email.send_email_smtp
"""
    
    def _initialize_database(self) -> bool:
        """
        Initialize Airflow database.
        
        Returns:
            bool: True if database initialization was successful
        """
        try:
            print("🗄️ Initializing Airflow database...")
            
            airflow_path = self.paths.airflow_project / "venv" / "bin" / "airflow"
            
            # Set environment variables
            env = {
                "AIRFLOW_HOME": str(self.paths.airflow_home),
                "PYTHONPATH": str(self.paths.airflow_project),
                "PATH": os.environ.get("PATH", "")
            }
            
            # Initialize database
            subprocess.run([
                str(airflow_path), "db", "migrate"
            ], env=env, check=True, cwd=str(self.paths.airflow_project))
            
            print("✅ Airflow database initialized successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to initialize Airflow database: {e}")
            return False
        except Exception as e:
            print(f"❌ Error initializing Airflow database: {e}")
            return False
    
    def _create_admin_user(self) -> bool:
        """
        Create Airflow admin user.
        
        Returns:
            bool: True if user creation was successful
        """
        try:
            print("👤 Creating Airflow admin user...")
            
            airflow_path = self.paths.airflow_project / "venv" / "bin" / "airflow"
            user_config = self.config.airflow_user
            
            # Set environment variables
            env = {
                "AIRFLOW_HOME": str(self.paths.airflow_home),
                "PYTHONPATH": str(self.paths.airflow_project),
                "PATH": os.environ.get("PATH", "")
            }
            
            # Create user
            subprocess.run([
                str(airflow_path), "users", "create",
                "--username", user_config.username,
                "--firstname", user_config.firstname,
                "--lastname", user_config.lastname,
                "--role", user_config.role,
                "--email", user_config.email,
                "--password", user_config.password
            ], env=env, check=True, cwd=str(self.paths.airflow_project))
            
            print("✅ Airflow admin user created successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            # User might already exist, which is okay
            if "already exist" in str(e):
                print("ℹ️  Airflow admin user already exists")
                return True
            print(f"❌ Failed to create Airflow admin user: {e}")
            return False
        except Exception as e:
            print(f"❌ Error creating Airflow admin user: {e}")
            return False
    
    def _create_service_files(self) -> bool:
        """
        Create systemd service files for Airflow.
        
        Returns:
            bool: True if service files were created successfully
        """
        try:
            # Create webserver service
            webserver_content = self._generate_webserver_service_content()
            with open("/tmp/airflow-webserver.service", "w") as f:
                f.write(webserver_content)
            
            subprocess.run([
                "sudo", "mv", "/tmp/airflow-webserver.service", 
                "/etc/systemd/system/airflow-webserver.service"
            ], check=True)
            
            # Create scheduler service
            scheduler_content = self._generate_scheduler_service_content()
            with open("/tmp/airflow-scheduler.service", "w") as f:
                f.write(scheduler_content)
            
            subprocess.run([
                "sudo", "mv", "/tmp/airflow-scheduler.service",
                "/etc/systemd/system/airflow-scheduler.service"
            ], check=True)
            
            print("✅ Systemd service files created successfully")
            return True
            
        except Exception as e:
            print(f"❌ Error creating service files: {e}")
            return False
    
    def _generate_webserver_service_content(self) -> str:
        """Generate webserver systemd service content."""
        return f"""[Unit]
Description=Airflow webserver daemon
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
Environment=AIRFLOW_HOME={self.paths.airflow_home}
Environment=PYTHONPATH={self.paths.airflow_project}
WorkingDirectory={self.paths.airflow_project}
ExecStart={self.paths.airflow_project}/venv/bin/airflow webserver
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
"""
    
    def _generate_scheduler_service_content(self) -> str:
        """Generate scheduler systemd service content."""
        return f"""[Unit]
Description=Airflow scheduler daemon
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
Environment=AIRFLOW_HOME={self.paths.airflow_home}
Environment=PYTHONPATH={self.paths.airflow_project}
WorkingDirectory={self.paths.airflow_project}
ExecStart={self.paths.airflow_project}/venv/bin/airflow scheduler
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
"""
    
    def _configure_services(self) -> bool:
        """
        Configure and enable systemd services.
        
        Returns:
            bool: True if services were configured successfully
        """
        try:
            # Reload systemd
            subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)
            
            # Enable services
            subprocess.run([
                "sudo", "systemctl", "enable", 
                "airflow-webserver", "airflow-scheduler"
            ], check=True)
            
            print("✅ Systemd services configured successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to configure services: {e}")
            return False
        except Exception as e:
            print(f"❌ Error configuring services: {e}")
            return False 