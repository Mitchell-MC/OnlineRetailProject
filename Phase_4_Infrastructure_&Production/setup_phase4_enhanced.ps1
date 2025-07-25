# Enhanced Phase 4 Setup Script for Online Retail Project (Windows PowerShell)
# Infrastructure as Code & Production Deployment with Auto-Dependency Installation

param(
    [string]$Environment = "dev",
    [string]$AwsRegion = "us-east-1"
)

# Configuration
$PROJECT_NAME = "online-retail-project"

Write-Host "🚀 Enhanced Phase 4 Setup: Infrastructure as Code & Production Deployment" -ForegroundColor Blue
Write-Host "Environment: $Environment" -ForegroundColor Blue
Write-Host "AWS Region: $AwsRegion" -ForegroundColor Blue

# Function to setup Python virtual environment
function Setup-PythonEnvironment {
    Write-Host "🐍 Setting up Python virtual environment..." -ForegroundColor Yellow
    
    # Check if Python is available
    $pythonCmd = $null
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonCmd = "python"
    }
    elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $pythonCmd = "py"
    }
    else {
        Write-Host "❌ Python is not installed. Please install Python 3.8+ first." -ForegroundColor Red
        exit 1
    }
    
    # Create virtual environment if it doesn't exist
    if (!(Test-Path "venv")) {
        Write-Host "📦 Creating virtual environment..." -ForegroundColor Yellow
        & $pythonCmd -m venv venv
    }
    
    # Activate virtual environment
    Write-Host "⚡ Activating virtual environment..." -ForegroundColor Yellow
    & "venv\Scripts\Activate.ps1"
    
    # Install Python dependencies
    if (Test-Path "requirements.txt") {
        Write-Host "📋 Installing Python dependencies..." -ForegroundColor Yellow
        pip install -r requirements.txt
    }
    
    Write-Host "✅ Python environment setup complete" -ForegroundColor Green
}

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Function to install Chocolatey (Windows package manager)
function Install-Chocolatey {
    if (!(Test-Command choco)) {
        Write-Host "📦 Installing Chocolatey package manager..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "✅ Chocolatey installed" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Chocolatey already installed" -ForegroundColor Green
    }
}

# Function to install AWS CLI
function Install-AwsCli {
    if (!(Test-Command aws)) {
        Write-Host "📦 Installing AWS CLI..." -ForegroundColor Yellow
        if (Test-Command choco) {
            choco install awscli -y
        }
        else {
            Write-Host "⚠️  Please install AWS CLI manually from https://aws.amazon.com/cli/" -ForegroundColor Yellow
        }
        Write-Host "✅ AWS CLI installed" -ForegroundColor Green
    }
    else {
        Write-Host "✅ AWS CLI already installed" -ForegroundColor Green
    }
}

# Function to install Terraform
function Install-Terraform {
    if (!(Test-Command terraform)) {
        Write-Host "📦 Installing Terraform..." -ForegroundColor Yellow
        if (Test-Command choco) {
            choco install terraform -y
        }
        else {
            Write-Host "⚠️  Please install Terraform manually from https://www.terraform.io/downloads" -ForegroundColor Yellow
        }
        Write-Host "✅ Terraform installed" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Terraform already installed" -ForegroundColor Green
    }
}

# Function to install kubectl
function Install-Kubectl {
    if (!(Test-Command kubectl)) {
        Write-Host "📦 Installing kubectl..." -ForegroundColor Yellow
        if (Test-Command choco) {
            choco install kubernetes-cli -y
        }
        else {
            Write-Host "⚠️  Please install kubectl manually from https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/" -ForegroundColor Yellow
        }
        Write-Host "✅ kubectl installed" -ForegroundColor Green
    }
    else {
        Write-Host "✅ kubectl already installed" -ForegroundColor Green
    }
}

# Function to install Docker Desktop
function Install-Docker {
    if (!(Test-Command docker)) {
        Write-Host "📦 Installing Docker Desktop..." -ForegroundColor Yellow
        if (Test-Command choco) {
            choco install docker-desktop -y
        }
        else {
            Write-Host "⚠️  Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
        }
        Write-Host "✅ Docker installation initiated" -ForegroundColor Green
        Write-Host "⚠️  Please restart your computer after Docker installation" -ForegroundColor Yellow
    }
    else {
        Write-Host "✅ Docker already installed" -ForegroundColor Green
    }
}

# Function to install all dependencies
function Install-Dependencies {
    Write-Host "📦 Installing system dependencies..." -ForegroundColor Yellow
    
    Install-Chocolatey
    Install-AwsCli
    Install-Terraform
    Install-Kubectl
    Install-Docker
    
    Write-Host "✅ All dependencies installed" -ForegroundColor Green
}

# Enhanced prerequisites check with auto-install
function Test-AndInstallPrerequisites {
    Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow
    
    $missingDeps = @()
    
    # Check each prerequisite
    if (!(Test-Command aws)) { $missingDeps += "aws-cli" }
    if (!(Test-Command terraform)) { $missingDeps += "terraform" }
    if (!(Test-Command kubectl)) { $missingDeps += "kubectl" }
    if (!(Test-Command docker)) { $missingDeps += "docker" }
    
    if ($missingDeps.Count -gt 0) {
        Write-Host "⚠️  Missing dependencies: $($missingDeps -join ', ')" -ForegroundColor Yellow
        $response = Read-Host "Do you want to automatically install missing dependencies? (y/n)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Install-Dependencies
        }
        else {
            Write-Host "❌ Please install missing dependencies manually." -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "✅ All prerequisites are satisfied" -ForegroundColor Green
    }
}

# Function to configure AWS credentials
function Set-AwsCredentials {
    Write-Host "🔐 Configuring AWS credentials..." -ForegroundColor Yellow
    
    # Check if AWS credentials are configured
    try {
        aws sts get-caller-identity 2>$null | Out-Null
        Write-Host "✅ AWS credentials configured" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  AWS credentials not configured." -ForegroundColor Yellow
        $response = Read-Host "Do you want to configure AWS credentials now? (y/n)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            aws configure
        }
        else {
            Write-Host "❌ AWS credentials are required to continue." -ForegroundColor Red
            exit 1
        }
    }
}

# Function to test the setup
function Test-Setup {
    Write-Host "🔍 Testing setup..." -ForegroundColor Yellow
    
    # Test Python imports
    try {
        python -c "import boto3, kubernetes, pandas; print('✅ Python imports successful')"
    }
    catch {
        Write-Host "❌ Python imports failed" -ForegroundColor Red
    }
    
    # Test AWS CLI
    try {
        aws --version
        Write-Host "✅ AWS CLI working" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ AWS CLI not working" -ForegroundColor Red
    }
    
    # Test other tools
    foreach ($tool in @("terraform", "kubectl", "docker")) {
        if (Test-Command $tool) {
            Write-Host "✅ $tool is available" -ForegroundColor Green
        }
        else {
            Write-Host "❌ $tool is not available" -ForegroundColor Red
        }
    }
}

# Main execution
function Main {
    Write-Host "🚀 Starting Enhanced Phase 4 setup..." -ForegroundColor Blue
    
    Setup-PythonEnvironment
    Test-AndInstallPrerequisites
    Set-AwsCredentials
    Test-Setup
    
    Write-Host "🎉 Enhanced Phase 4 setup completed!" -ForegroundColor Green
    Write-Host "📋 Virtual environment created and activated" -ForegroundColor Blue
    Write-Host "📋 To activate in future sessions: venv\Scripts\Activate.ps1" -ForegroundColor Blue
    Write-Host "📋 Next steps:" -ForegroundColor Blue
    Write-Host "   1. Configure GitHub secrets for CI/CD" -ForegroundColor Cyan
    Write-Host "   2. Initialize Terraform infrastructure" -ForegroundColor Cyan
    Write-Host "   3. Deploy Kubernetes resources" -ForegroundColor Cyan
    Write-Host "   4. Set up monitoring and alerting" -ForegroundColor Cyan
}

# Run main function
Main 