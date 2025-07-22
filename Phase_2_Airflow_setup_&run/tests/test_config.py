"""
Tests for the configuration module.

Tests the Pydantic configuration models to ensure proper validation
and default value handling as required by the project guidelines.
"""

import pytest
from pathlib import Path

from src.config.settings import (
    ProjectPaths, 
    AirflowUserConfig,
    SystemDependencies,
    ConnectionConfig,
    AirflowConfig,
    SetupConfig
)


class TestProjectPaths:
    """Test cases for ProjectPaths configuration."""
    
    def test_default_paths(self):
        """Test that default paths are set correctly."""
        paths = ProjectPaths()
        
        assert paths.project_dir == Path("/home/ubuntu/OnlineRetailProject")
        assert paths.airflow_home == Path("/home/ubuntu/airflow")
        assert paths.airflow_project == Path("/home/ubuntu/OnlineRetailProject/airflow-project")
    
    def test_computed_properties(self):
        """Test computed path properties."""
        paths = ProjectPaths()
        
        expected_dags = Path("/home/ubuntu/OnlineRetailProject/airflow-project/dags")
        expected_plugins = Path("/home/ubuntu/OnlineRetailProject/airflow-project/plugins")
        expected_logs = Path("/home/ubuntu/OnlineRetailProject/airflow-project/logs")
        
        assert paths.dags_folder == expected_dags
        assert paths.plugins_folder == expected_plugins
        assert paths.logs_folder == expected_logs
    
    def test_custom_paths(self):
        """Test setting custom paths."""
        custom_project = Path("/custom/project")
        custom_airflow = Path("/custom/airflow")
        
        paths = ProjectPaths(
            project_dir=custom_project,
            airflow_home=custom_airflow
        )
        
        assert paths.project_dir == custom_project
        assert paths.airflow_home == custom_airflow


class TestAirflowUserConfig:
    """Test cases for AirflowUserConfig."""
    
    def test_default_user_config(self):
        """Test default user configuration values."""
        user_config = AirflowUserConfig()
        
        assert user_config.username == "airflow"
        assert user_config.password == "airflow"
        assert user_config.firstname == "Admin"
        assert user_config.lastname == "User"
        assert user_config.email == "admin@example.com"
        assert user_config.role == "Admin"
    
    def test_custom_user_config(self):
        """Test custom user configuration."""
        user_config = AirflowUserConfig(
            username="custom_user",
            password="secure_password",
            email="custom@company.com"
        )
        
        assert user_config.username == "custom_user"
        assert user_config.password == "secure_password"
        assert user_config.email == "custom@company.com"
        # Defaults should still be set
        assert user_config.firstname == "Admin"
        assert user_config.role == "Admin"


class TestSystemDependencies:
    """Test cases for SystemDependencies configuration."""
    
    def test_default_packages(self):
        """Test that default system packages are included."""
        deps = SystemDependencies()
        
        # Check that essential packages are included
        assert "python3" in deps.packages
        assert "python3-pip" in deps.packages
        assert "python3-venv" in deps.packages
        assert "docker-ce" in deps.docker_packages
        assert "docker-ce-cli" in deps.docker_packages
    
    def test_packages_are_lists(self):
        """Test that package lists are properly typed."""
        deps = SystemDependencies()
        
        assert isinstance(deps.packages, list)
        assert isinstance(deps.docker_packages, list)
        assert len(deps.packages) > 0
        assert len(deps.docker_packages) > 0


class TestConnectionConfig:
    """Test cases for ConnectionConfig."""
    
    def test_default_connection_config(self):
        """Test default connection configuration."""
        config = ConnectionConfig()
        
        # All optional fields should be None by default
        assert config.snowflake_account is None
        assert config.snowflake_user is None
        assert config.aws_access_key_id is None
        assert config.aws_secret_access_key is None
        
        # Default region should be set
        assert config.aws_region == "us-east-1"
    
    def test_snowflake_configuration(self):
        """Test Snowflake connection configuration."""
        config = ConnectionConfig(
            snowflake_account="test-account",
            snowflake_user="test-user",
            snowflake_password="test-password",
            snowflake_database="TEST_DB",
            snowflake_schema="TEST_SCHEMA",
            snowflake_warehouse="TEST_WH"
        )
        
        assert config.snowflake_account == "test-account"
        assert config.snowflake_user == "test-user" 
        assert config.snowflake_database == "TEST_DB"
    
    def test_aws_configuration(self):
        """Test AWS connection configuration."""
        config = ConnectionConfig(
            aws_access_key_id="test-key",
            aws_secret_access_key="test-secret",
            aws_region="us-west-2"
        )
        
        assert config.aws_access_key_id == "test-key"
        assert config.aws_secret_access_key == "test-secret"
        assert config.aws_region == "us-west-2"


class TestAirflowConfig:
    """Test cases for AirflowConfig."""
    
    def test_default_airflow_config(self):
        """Test default Airflow configuration."""
        config = AirflowConfig()
        
        assert config.version == "2.9.2"
        assert config.executor == "LocalExecutor"
        assert config.load_examples is False
        assert config.web_server_host == "0.0.0.0"
        assert config.web_server_port == 8080
        assert "sqlite" in config.database_url
    
    def test_custom_airflow_config(self):
        """Test custom Airflow configuration."""
        config = AirflowConfig(
            version="2.10.0",
            executor="CeleryExecutor",
            web_server_port=9090,
            load_examples=True
        )
        
        assert config.version == "2.10.0"
        assert config.executor == "CeleryExecutor"
        assert config.web_server_port == 9090
        assert config.load_examples is True


class TestSetupConfig:
    """Test cases for complete SetupConfig."""
    
    def test_default_setup_config(self):
        """Test that all nested configs are properly initialized."""
        config = SetupConfig()
        
        # Check that all components are present
        assert isinstance(config.paths, ProjectPaths)
        assert isinstance(config.airflow_user, AirflowUserConfig)
        assert isinstance(config.system_deps, SystemDependencies)
        assert isinstance(config.connections, ConnectionConfig)
        assert isinstance(config.airflow, AirflowConfig)
        
        # Check retry configuration
        assert config.max_retries == 3
        assert config.retry_delay == 5
    
    def test_retry_validation(self):
        """Test that retry values are properly validated."""
        # Valid values should work
        config = SetupConfig(max_retries=5, retry_delay=10)
        assert config.max_retries == 5
        assert config.retry_delay == 10
        
        # Test boundary conditions
        config = SetupConfig(max_retries=1, retry_delay=1)
        assert config.max_retries == 1
        assert config.retry_delay == 1
    
    def test_load_from_env_file_missing_file(self):
        """Test loading from non-existent environment file."""
        config = SetupConfig()
        non_existent_file = Path("/non/existent/file.env")
        
        with pytest.raises(FileNotFoundError):
            config.load_from_env_file(non_existent_file) 