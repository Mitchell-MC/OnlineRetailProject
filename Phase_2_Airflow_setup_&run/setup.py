#!/usr/bin/env python3
"""
Main setup script for the Online Retail Airflow project.

This script orchestrates the complete setup process using modular components,
replacing the large shell script with a more maintainable Python solution.
"""

import sys
import argparse
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent / "src"))

from src.config.settings import SetupConfig
from src.setup.system_installer import SystemInstaller  
from src.setup.airflow_installer import AirflowInstaller
from src.utils.connection_manager import ConnectionManager


def main() -> None:
    """
    Main setup function for the Airflow project.
    
    Coordinates the entire setup process including system dependencies,
    Docker, Airflow installation, and connection configuration.
    """
    parser = argparse.ArgumentParser(
        description="Setup script for Online Retail Airflow project"
    )
    parser.add_argument(
        "--skip-system", 
        action="store_true",
        help="Skip system package installation"
    )
    parser.add_argument(
        "--skip-docker",
        action="store_true", 
        help="Skip Docker installation"
    )
    parser.add_argument(
        "--skip-airflow",
        action="store_true",
        help="Skip Airflow installation"  
    )
    parser.add_argument(
        "--connections-only",
        action="store_true",
        help="Only set up connections (requires Airflow to be installed)"
    )
    parser.add_argument(
        "--env-file",
        type=str,
        help="Path to environment file with connection credentials"
    )
    
    args = parser.parse_args()
    
    print("🚀 Starting Airflow setup for Online Retail Project...")
    print("=" * 60)
    
    # Initialize configuration
    config = SetupConfig()
    
    try:
        if args.connections_only:
            setup_connections_only(config, args.env_file)
        else:
            run_full_setup(config, args)
            
        print("\n" + "=" * 60)
        print("🎉 Airflow setup completed successfully!")
        print_next_steps(config)
        
    except Exception as e:
        print(f"\n❌ Setup failed: {e}")
        sys.exit(1)


def run_full_setup(config: SetupConfig, args: argparse.Namespace) -> None:
    """
    Run the complete setup process.
    
    Args:
        config (SetupConfig): Setup configuration
        args (argparse.Namespace): Command line arguments
    """
    # Initialize installers
    system_installer = SystemInstaller(config)
    airflow_installer = AirflowInstaller(config)
    
    # Step 1: Install system dependencies
    if not args.skip_system:
        print("📦 Step 1: Installing system dependencies...")
        if not system_installer.install_system_packages():
            raise RuntimeError("Failed to install system packages")
        print("✅ System dependencies installed\n")
    else:
        print("⏭️  Skipping system package installation\n")
    
    # Step 2: Install Docker  
    if not args.skip_docker:
        print("🐳 Step 2: Installing Docker...")
        if not system_installer.install_docker():
            raise RuntimeError("Failed to install Docker")
        print("✅ Docker installed\n")
    else:
        print("⏭️  Skipping Docker installation\n")
    
    # Step 3: Set up Airflow environment
    if not args.skip_airflow:
        print("🐍 Step 3: Setting up Airflow environment...")
        if not airflow_installer.setup_python_environment():
            raise RuntimeError("Failed to set up Python environment")
        print("✅ Python environment ready\n")
        
        print("⚙️  Step 4: Initializing Airflow...")
        if not airflow_installer.initialize_airflow():
            raise RuntimeError("Failed to initialize Airflow")
        print("✅ Airflow initialized\n")
        
        print("🔧 Step 5: Setting up systemd services...")
        if not airflow_installer.setup_systemd_services():
            raise RuntimeError("Failed to set up systemd services") 
        print("✅ Systemd services configured\n")
    else:
        print("⏭️  Skipping Airflow installation\n")
    
    # Step 6: Set up connections
    print("🔗 Step 6: Setting up connections...")
    setup_connections_only(config, args.env_file)


def setup_connections_only(config: SetupConfig, env_file_path: str = None) -> None:
    """
    Set up only the Airflow connections.
    
    Args:
        config (SetupConfig): Setup configuration
        env_file_path (str, optional): Path to environment file with credentials
    """
    connection_manager = ConnectionManager(config)
    
    # Load credentials from environment file if provided
    if env_file_path:
        env_file = Path(env_file_path)
        if not connection_manager.load_connections_from_env_file(env_file):
            raise RuntimeError(f"Failed to load environment file: {env_file_path}")
    else:
        # Try to load from default location
        default_env_file = config.paths.airflow_project / "airflow_connections.env"
        if default_env_file.exists():
            connection_manager.load_connections_from_env_file(default_env_file)
        else:
            print("⚠️  No environment file found. Using default configuration.")
    
    # Set up all connections
    if not connection_manager.setup_all_connections():
        raise RuntimeError("Failed to set up some connections")
    
    print("✅ Connections configured\n")


def print_next_steps(config: SetupConfig) -> None:
    """
    Print next steps and useful information.
    
    Args:
        config (SetupConfig): Setup configuration
    """
    print("📋 Next steps:")
    print("1. Update credentials: Edit airflow_connections.env")
    print("2. Start Airflow: ./start_airflow.sh")
    print("3. Check status: ./status_airflow.sh")
    print("4. Access Web UI: http://[your-ip]:8080")
    print("5. Login with: airflow / airflow")
    print("")
    print("📁 Project structure:")
    print(f"   - DAGs: {config.paths.dags_folder}")
    print(f"   - Plugins: {config.paths.plugins_folder}")  
    print(f"   - Logs: {config.paths.logs_folder}")
    print(f"   - Config: {config.paths.airflow_home}/airflow.cfg")
    print("")
    print("🔧 Management commands:")
    print("   - Start: ./start_airflow.sh")
    print("   - Stop: ./stop_airflow.sh")
    print("   - Status: ./status_airflow.sh")
    print("")
    print("🔗 Available connections:")
    print("   - snowflake_default (Snowflake database)")
    print("   - s3_default (AWS S3 storage)")
    print("   - aws_default (AWS services)")


if __name__ == "__main__":
    main() 