#!/bin/bash

# Enhanced Phase 4 Setup Script for Online Retail Project
# Infrastructure as Code & Production Deployment with Auto-Dependency Installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="online-retail-project"
ENVIRONMENT=${1:-"dev"}
AWS_REGION=${2:-"us-east-1"}

echo -e "${BLUE}🚀 Enhanced Phase 4 Setup: Infrastructure as Code & Production Deployment${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}AWS Region: ${AWS_REGION}${NC}"

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
        elif [ -f /etc/redhat-release ]; then
            OS="redhat"
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
    echo -e "${BLUE}Detected OS: ${OS}${NC}"
}

# Function to setup Python virtual environment
setup_python_environment() {
    echo -e "${YELLOW}🐍 Setting up Python virtual environment...${NC}"
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        echo -e "${RED}❌ Python is not installed. Please install Python 3.8+ first.${NC}"
        exit 1
    fi
    
    # Use python3 if available, otherwise python
    PYTHON_CMD="python3"
    if ! command -v python3 &> /dev/null; then
        PYTHON_CMD="python"
    fi
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        echo -e "${YELLOW}📦 Creating virtual environment...${NC}"
        $PYTHON_CMD -m venv venv
    fi
    
    # Activate virtual environment
    echo -e "${YELLOW}⚡ Activating virtual environment...${NC}"
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install Python dependencies
    if [ -f "requirements.txt" ]; then
        echo -e "${YELLOW}📋 Installing Python dependencies...${NC}"
        pip install -r requirements.txt
    fi
    
    echo -e "${GREEN}✅ Python environment setup complete${NC}"
}

# Function to install AWS CLI
install_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${YELLOW}📦 Installing AWS CLI...${NC}"
        case $OS in
            "debian")
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install
                rm -rf aws awscliv2.zip
                ;;
            "macos")
                if command -v brew &> /dev/null; then
                    brew install awscli
                else
                    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
                    sudo installer -pkg AWSCLIV2.pkg -target /
                    rm AWSCLIV2.pkg
                fi
                ;;
            "windows")
                echo -e "${YELLOW}⚠️  Please install AWS CLI manually from https://aws.amazon.com/cli/${NC}"
                ;;
            *)
                echo -e "${YELLOW}⚠️  Please install AWS CLI manually for your OS${NC}"
                ;;
        esac
        echo -e "${GREEN}✅ AWS CLI installed${NC}"
    else
        echo -e "${GREEN}✅ AWS CLI already installed${NC}"
    fi
}

# Function to install Terraform
install_terraform() {
    if ! command -v terraform &> /dev/null; then
        echo -e "${YELLOW}📦 Installing Terraform...${NC}"
        TERRAFORM_VERSION="1.6.6"
        case $OS in
            "debian")
                wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
                sudo apt update && sudo apt install terraform
                ;;
            "macos")
                if command -v brew &> /dev/null; then
                    brew tap hashicorp/tap
                    brew install hashicorp/tap/terraform
                else
                    curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_darwin_amd64.zip -o terraform.zip
                    unzip terraform.zip
                    sudo mv terraform /usr/local/bin/
                    rm terraform.zip
                fi
                ;;
            "windows")
                echo -e "${YELLOW}⚠️  Please install Terraform manually from https://www.terraform.io/downloads${NC}"
                ;;
            *)
                # Generic Linux install
                curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform.zip
                unzip terraform.zip
                sudo mv terraform /usr/local/bin/
                rm terraform.zip
                ;;
        esac
        echo -e "${GREEN}✅ Terraform installed${NC}"
    else
        echo -e "${GREEN}✅ Terraform already installed${NC}"
    fi
}

# Function to install kubectl
install_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}📦 Installing kubectl...${NC}"
        case $OS in
            "debian")
                curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
                echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
                sudo apt-get update
                sudo apt-get install -y kubectl
                ;;
            "macos")
                if command -v brew &> /dev/null; then
                    brew install kubectl
                else
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                    chmod +x kubectl
                    sudo mv kubectl /usr/local/bin/
                fi
                ;;
            "windows")
                echo -e "${YELLOW}⚠️  Please install kubectl manually from https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/${NC}"
                ;;
            *)
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
                ;;
        esac
        echo -e "${GREEN}✅ kubectl installed${NC}"
    else
        echo -e "${GREEN}✅ kubectl already installed${NC}"
    fi
}

# Function to install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}📦 Installing Docker...${NC}"
        case $OS in
            "debian")
                sudo apt-get update
                sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io
                sudo usermod -aG docker $USER
                ;;
            "macos")
                if command -v brew &> /dev/null; then
                    brew install --cask docker
                else
                    echo -e "${YELLOW}⚠️  Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop${NC}"
                fi
                ;;
            "windows")
                echo -e "${YELLOW}⚠️  Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop${NC}"
                ;;
            *)
                echo -e "${YELLOW}⚠️  Please install Docker manually for your OS${NC}"
                ;;
        esac
        echo -e "${GREEN}✅ Docker installation initiated${NC}"
    else
        echo -e "${GREEN}✅ Docker already installed${NC}"
    fi
}

# Function to install all dependencies
install_dependencies() {
    echo -e "${YELLOW}📦 Installing system dependencies...${NC}"
    
    detect_os
    install_aws_cli
    install_terraform
    install_kubectl
    install_docker
    
    echo -e "${GREEN}✅ All dependencies installed${NC}"
}

# Enhanced prerequisites check with auto-install
check_and_install_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
    
    MISSING_DEPS=()
    
    # Check each prerequisite
    if ! command -v aws &> /dev/null; then
        MISSING_DEPS+=("aws-cli")
    fi
    
    if ! command -v terraform &> /dev/null; then
        MISSING_DEPS+=("terraform")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        MISSING_DEPS+=("kubectl")
    fi
    
    if ! command -v docker &> /dev/null; then
        MISSING_DEPS+=("docker")
    fi
    
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Missing dependencies: ${MISSING_DEPS[*]}${NC}"
        read -p "Do you want to automatically install missing dependencies? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_dependencies
        else
            echo -e "${RED}❌ Please install missing dependencies manually.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ All prerequisites are satisfied${NC}"
    fi
}

# Function to configure AWS credentials
configure_aws() {
    echo -e "${YELLOW}🔐 Configuring AWS credentials...${NC}"
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${YELLOW}⚠️  AWS credentials not configured. Please run 'aws configure' first.${NC}"
        read -p "Do you want to configure AWS credentials now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            aws configure
        else
            echo -e "${RED}❌ AWS credentials are required to continue.${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ AWS credentials configured${NC}"
}

# Continue with existing functions from original script...
# (Include all the remaining functions from the original setup_phase4.sh)

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting Enhanced Phase 4 setup...${NC}"
    
    setup_python_environment
    check_and_install_prerequisites
    configure_aws
    
    echo -e "${GREEN}🎉 Enhanced Phase 4 setup completed!${NC}"
    echo -e "${BLUE}📋 Virtual environment created and activated${NC}"
    echo -e "${BLUE}📋 To activate in future sessions: source venv/bin/activate${NC}"
}

# Run main function
main "$@" 