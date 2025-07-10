"""
Configuration settings for the Online Retail Airflow project.

This module defines all configuration settings using Pydantic v2 for type safety
and validation as specified in the project guidelines.
"""

from pathlib import Path
from typing import Dict, List, Optional

from pydantic import BaseModel, Field, validator


class ProjectPaths(BaseModel):
    """Project directory paths configuration."""
    
    project_dir: Path = Field(default=Path("/home/ubuntu/OnlineRetailProject"))
    airflow_home: Path = Field(default=Path("/home/ubuntu/airflow"))
    airflow_project: Path = Field(default=Path("/home/ubuntu/OnlineRetailProject/airflow-project"))
    
    @property
    def dags_folder(self) -> Path:
        """Get the DAGs folder path."""
        return self.airflow_project / "dags"
    
    @property
    def plugins_folder(self) -> Path:
        """Get the plugins folder path."""
        return self.airflow_project / "plugins"
    
    @property
    def logs_folder(self) -> Path:
        """Get the logs folder path."""
        return self.airflow_project / "logs"


class AirflowUserConfig(BaseModel):
    """Airflow user configuration."""
    
    username: str = Field(default="airflow")
    password: str = Field(default="airflow")
    firstname: str = Field(default="Admin")
    lastname: str = Field(default="User")
    email: str = Field(default="admin@example.com")
    role: str = Field(default="Admin")


class SystemDependencies(BaseModel):
    """System dependencies configuration."""
    
    packages: List[str] = Field(default=[
        "python3",
        "python3-pip", 
        "python3-venv",
        "build-essential",
        "libssl-dev",
        "libffi-dev",
        "python3-dev",
        "git",
        "curl",
        "wget",
        "unzip",
        "software-properties-common",
        "apt-transport-https", 
        "ca-certificates",
        "gnupg",
        "lsb-release"
    ])
    
    docker_packages: List[str] = Field(default=[
        "docker-ce",
        "docker-ce-cli", 
        "containerd.io",
        "docker-compose-plugin"
    ])


class ConnectionConfig(BaseModel):
    """External connection configuration."""
    
    snowflake_account: Optional[str] = None
    snowflake_user: Optional[str] = None
    snowflake_password: Optional[str] = None
    snowflake_database: Optional[str] = None
    snowflake_schema: Optional[str] = None
    snowflake_warehouse: Optional[str] = None
    
    aws_access_key_id: Optional[str] = None
    aws_secret_access_key: Optional[str] = None
    aws_region: str = Field(default="us-east-1")


class AirflowConfig(BaseModel):
    """Main Airflow configuration."""
    
    version: str = Field(default="2.9.2")
    executor: str = Field(default="LocalExecutor")
    load_examples: bool = Field(default=False)
    web_server_host: str = Field(default="0.0.0.0")
    web_server_port: int = Field(default=8080)
    
    # Database configuration
    database_url: str = Field(default="sqlite:////home/ubuntu/airflow/airflow.db")
    
    # Security
    fernet_key: Optional[str] = None
    secret_key: Optional[str] = None


class SetupConfig(BaseModel):
    """Complete setup configuration."""
    
    paths: ProjectPaths = Field(default_factory=ProjectPaths)
    airflow_user: AirflowUserConfig = Field(default_factory=AirflowUserConfig)
    system_deps: SystemDependencies = Field(default_factory=SystemDependencies)
    connections: ConnectionConfig = Field(default_factory=ConnectionConfig)
    airflow: AirflowConfig = Field(default_factory=AirflowConfig)
    
    # Retry configuration
    max_retries: int = Field(default=3, ge=1, le=10)
    retry_delay: int = Field(default=5, ge=1, le=60)
    
    def load_from_env_file(self, env_file_path: Path) -> None:
        """
        Load connection configuration from environment file.
        
        Args:
            env_file_path (Path): Path to the environment file
            
        Raises:
            FileNotFoundError: If the environment file doesn't exist
        """
        if not env_file_path.exists():
            raise FileNotFoundError(f"Environment file not found: {env_file_path}")
        
        # Parse environment file and update connection config
        # This would parse the shell export statements
        # Implementation would depend on specific format
        pass 