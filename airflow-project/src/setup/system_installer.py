"""
System installer module for setting up system dependencies.

This module handles installation of system packages and Docker,
replacing the corresponding sections from the large shell script.
"""

import subprocess
import time
from pathlib import Path
from typing import List, Optional

from src.config.settings import SetupConfig, SystemDependencies


class SystemInstaller:
    """Handles system-level package installation and configuration."""
    
    def __init__(self, config: SetupConfig) -> None:
        """
        Initialize the system installer.
        
        Args:
            config (SetupConfig): Complete setup configuration
        """
        self.config = config
        self.system_deps = config.system_deps
        
    def install_system_packages(self) -> bool:
        """
        Install system packages with retry logic.
        
        Returns:
            bool: True if installation was successful
            
        Raises:
            RuntimeError: If installation fails after max retries
        """
        print("📦 Installing system packages...")
        
        # Update package lists first
        if not self._update_package_lists():
            return False
            
        # Install packages with retry logic
        return self._install_packages_with_retry(self.system_deps.packages)
    
    def install_docker(self) -> bool:
        """
        Install Docker with proper repository setup.
        
        Returns:
            bool: True if Docker installation was successful
            
        Raises:
            RuntimeError: If Docker installation fails
        """
        print("🐳 Installing Docker...")
        
        # Clean up any existing Docker repositories
        self._cleanup_docker_repositories()
        
        # Add Docker's official GPG key
        if not self._add_docker_gpg_key():
            return False
            
        # Add Docker repository
        if not self._add_docker_repository():
            return False
            
        # Update package lists for Docker
        if not self._update_package_lists():
            return False
            
        # Install Docker packages
        if not self._install_packages_with_retry(self.system_deps.docker_packages):
            return False
            
        # Configure Docker service
        return self._configure_docker_service()
    
    def _update_package_lists(self) -> bool:
        """
        Update package lists with retry logic.
        
        Returns:
            bool: True if update was successful
        """
        for attempt in range(1, self.config.max_retries + 1):
            print(f"📦 Updating package lists (attempt {attempt}/{self.config.max_retries})...")
            
            try:
                result = subprocess.run(
                    ["sudo", "apt-get", "update", "-y"],
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                
                if result.returncode == 0:
                    print("✅ Package lists updated successfully")
                    return True
                    
                print(f"❌ Package list update failed: {result.stderr}")
                
            except subprocess.TimeoutExpired:
                print("❌ Package list update timed out")
            except Exception as e:
                print(f"❌ Package list update error: {e}")
                
            if attempt < self.config.max_retries:
                print(f"⏳ Retrying in {self.config.retry_delay} seconds...")
                time.sleep(self.config.retry_delay)
        
        raise RuntimeError(f"Failed to update package lists after {self.config.max_retries} attempts")
    
    def _install_packages_with_retry(self, packages: List[str]) -> bool:
        """
        Install packages with retry logic.
        
        Args:
            packages (List[str]): List of package names to install
            
        Returns:
            bool: True if installation was successful
        """
        for attempt in range(1, self.config.max_retries + 1):
            print(f"🔧 Installing packages (attempt {attempt}/{self.config.max_retries})...")
            
            try:
                cmd = ["sudo", "apt-get", "install", "-y"] + packages
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=900  # 15 minutes timeout
                )
                
                if result.returncode == 0:
                    print("✅ Packages installed successfully")
                    return True
                    
                print(f"❌ Package installation failed: {result.stderr}")
                
            except subprocess.TimeoutExpired:
                print("❌ Package installation timed out")
            except Exception as e:
                print(f"❌ Package installation error: {e}")
                
            if attempt < self.config.max_retries:
                print(f"⏳ Retrying in {self.config.retry_delay} seconds...")
                time.sleep(self.config.retry_delay)
        
        raise RuntimeError(f"Failed to install packages after {self.config.max_retries} attempts")
    
    def _cleanup_docker_repositories(self) -> None:
        """Clean up any existing Docker repository configurations."""
        print("🧹 Cleaning up Docker repository configuration...")
        
        # Remove Docker repository files
        docker_files = [
            "/etc/apt/sources.list.d/docker.list",
            "/etc/apt/sources.list.d/docker-ce.list"
        ]
        
        for file_path in docker_files:
            try:
                subprocess.run(["sudo", "rm", "-f", file_path], check=False)
            except Exception:
                pass  # Ignore errors for cleanup
        
        # Remove Docker GPG keys
        gpg_files = [
            "/usr/share/keyrings/docker-archive-keyring.gpg",
            "/etc/apt/trusted.gpg.d/docker.gpg",
            "/etc/apt/keyrings/docker.asc",
            "/etc/apt/keyrings/docker.gpg",
            "/usr/share/keyrings/docker.gpg"
        ]
        
        for file_path in gpg_files:
            try:
                subprocess.run(["sudo", "rm", "-f", file_path], check=False)
            except Exception:
                pass  # Ignore errors for cleanup
                
        print("✅ Docker repository cleanup completed")
    
    def _add_docker_gpg_key(self) -> bool:
        """
        Add Docker's official GPG key.
        
        Returns:
            bool: True if GPG key was added successfully
        """
        print("🔑 Adding Docker's official GPG key...")
        
        try:
            # Download and add GPG key
            cmd = [
                "curl", "-fsSL", 
                "https://download.docker.com/linux/ubuntu/gpg"
            ]
            curl_process = subprocess.run(cmd, capture_output=True, text=True)
            
            if curl_process.returncode != 0:
                print(f"❌ Failed to download GPG key: {curl_process.stderr}")
                return False
            
            # Add the key
            cmd = [
                "sudo", "gpg", "--dearmor", "-o", 
                "/usr/share/keyrings/docker-archive-keyring.gpg"
            ]
            gpg_process = subprocess.run(
                cmd, 
                input=curl_process.stdout, 
                text=True, 
                capture_output=True
            )
            
            if gpg_process.returncode == 0:
                print("✅ Docker GPG key added successfully")
                return True
            else:
                print(f"❌ Failed to add GPG key: {gpg_process.stderr}")
                return False
                
        except Exception as e:
            print(f"❌ Error adding Docker GPG key: {e}")
            return False
    
    def _add_docker_repository(self) -> bool:
        """
        Add Docker repository to apt sources.
        
        Returns:
            bool: True if repository was added successfully
        """
        print("📦 Adding Docker repository...")
        
        try:
            # Get architecture and release
            arch_result = subprocess.run(
                ["dpkg", "--print-architecture"], 
                capture_output=True, 
                text=True
            )
            
            release_result = subprocess.run(
                ["lsb_release", "-cs"], 
                capture_output=True, 
                text=True
            )
            
            if arch_result.returncode != 0 or release_result.returncode != 0:
                print("❌ Failed to get system architecture or release")
                return False
            
            arch = arch_result.stdout.strip()
            release = release_result.stdout.strip()
            
            # Create repository entry
            repo_entry = (
                f"deb [arch={arch} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] "
                f"https://download.docker.com/linux/ubuntu {release} stable"
            )
            
            # Add repository
            with open("/tmp/docker.list", "w") as f:
                f.write(repo_entry)
            
            result = subprocess.run([
                "sudo", "mv", "/tmp/docker.list", "/etc/apt/sources.list.d/docker.list"
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                print("✅ Docker repository added successfully")
                return True
            else:
                print(f"❌ Failed to add Docker repository: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"❌ Error adding Docker repository: {e}")
            return False
    
    def _configure_docker_service(self) -> bool:
        """
        Configure Docker service and user permissions.
        
        Returns:
            bool: True if configuration was successful
        """
        print("🔧 Configuring Docker service...")
        
        try:
            # Start and enable Docker service
            subprocess.run(["sudo", "systemctl", "start", "docker"], check=True)
            subprocess.run(["sudo", "systemctl", "enable", "docker"], check=True)
            
            # Add ubuntu user to docker group
            subprocess.run(["sudo", "usermod", "-aG", "docker", "ubuntu"], check=True)
            
            print("✅ Docker service configured successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to configure Docker service: {e}")
            return False
        except Exception as e:
            print(f"❌ Error configuring Docker service: {e}")
            return False 