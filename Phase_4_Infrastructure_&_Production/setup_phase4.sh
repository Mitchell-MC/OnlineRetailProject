#!/bin/bash

# Phase 4 Setup Script for Online Retail Project
# Infrastructure as Code & Production Deployment

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

echo -e "${BLUE}🚀 Setting up Phase 4: Infrastructure as Code & Production Deployment${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}AWS Region: ${AWS_REGION}${NC}"

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites are satisfied${NC}"
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

# Function to create S3 bucket for Terraform state
create_terraform_state_bucket() {
    echo -e "${YELLOW}🪣 Creating S3 bucket for Terraform state...${NC}"
    
    BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ENVIRONMENT}"
    
    if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
        aws s3 mb "s3://${BUCKET_NAME}" --region "${AWS_REGION}"
        aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" --versioning-configuration Status=Enabled
        aws s3api put-bucket-encryption --bucket "${BUCKET_NAME}" --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
        echo -e "${GREEN}✅ Terraform state bucket created: ${BUCKET_NAME}${NC}"
    else
        echo -e "${GREEN}✅ Terraform state bucket already exists: ${BUCKET_NAME}${NC}"
    fi
}

# Function to initialize Terraform
initialize_terraform() {
    echo -e "${YELLOW}🏗️  Initializing Terraform...${NC}"
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan Terraform changes
    echo -e "${YELLOW}📋 Planning Terraform changes...${NC}"
    terraform plan -var="environment=${ENVIRONMENT}" -var="aws_region=${AWS_REGION}"
    
    # Ask for confirmation
    read -p "Do you want to apply these changes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🚀 Applying Terraform changes...${NC}"
        terraform apply -var="environment=${ENVIRONMENT}" -var="aws_region=${AWS_REGION}" -auto-approve
        echo -e "${GREEN}✅ Terraform infrastructure deployed successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Terraform changes not applied${NC}"
    fi
    
    cd ..
}

# Function to deploy Kubernetes resources
deploy_kubernetes_resources() {
    echo -e "${YELLOW}☸️  Deploying Kubernetes resources...${NC}"
    
    # Create namespace
    kubectl create namespace online-retail --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Kafka
    echo -e "${YELLOW}📦 Deploying Kafka...${NC}"
    kubectl apply -f deployment/kubernetes/kafka-deployment.yaml
    
    # Deploy Airflow
    echo -e "${YELLOW}📦 Deploying Airflow...${NC}"
    kubectl apply -f deployment/kubernetes/airflow-deployment.yaml
    
    # Wait for deployments to be ready
    echo -e "${YELLOW}⏳ Waiting for deployments to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment/kafka -n online-retail
    kubectl wait --for=condition=available --timeout=300s deployment/airflow-webserver -n online-retail
    kubectl wait --for=condition=available --timeout=300s deployment/airflow-scheduler -n online-retail
    
    echo -e "${GREEN}✅ Kubernetes resources deployed successfully${NC}"
}

# Function to setup monitoring
setup_monitoring() {
    echo -e "${YELLOW}📊 Setting up monitoring...${NC}"
    
    # Deploy Prometheus
    kubectl apply -f monitoring/prometheus/
    
    # Deploy Grafana
    kubectl apply -f monitoring/grafana/
    
    # Deploy AlertManager
    kubectl apply -f monitoring/alerting/
    
    echo -e "${GREEN}✅ Monitoring stack deployed successfully${NC}"
}

# Function to setup CI/CD
setup_cicd() {
    echo -e "${YELLOW}🔄 Setting up CI/CD pipeline...${NC}"
    
    # Create GitHub Actions secrets (manual step)
    echo -e "${YELLOW}⚠️  Please configure the following GitHub secrets manually:${NC}"
    echo -e "${BLUE}  - AWS_ACCESS_KEY_ID${NC}"
    echo -e "${BLUE}  - AWS_SECRET_ACCESS_KEY${NC}"
    echo -e "${BLUE}  - DOCKER_REGISTRY${NC}"
    echo -e "${BLUE}  - DOCKER_USERNAME${NC}"
    echo -e "${BLUE}  - DOCKER_PASSWORD${NC}"
    
    # Copy GitHub Actions workflow
    if [ -d ".github/workflows" ]; then
        cp ci-cd/github-actions/deploy.yml .github/workflows/
        echo -e "${GREEN}✅ GitHub Actions workflow copied${NC}"
    else
        echo -e "${YELLOW}⚠️  .github/workflows directory not found. Please create it manually.${NC}"
    fi
}

# Function to verify deployment
verify_deployment() {
    echo -e "${YELLOW}🔍 Verifying deployment...${NC}"
    
    # Check Kubernetes pods
    echo -e "${BLUE}📋 Checking Kubernetes pods...${NC}"
    kubectl get pods -n online-retail
    
    # Check services
    echo -e "${BLUE}📋 Checking services...${NC}"
    kubectl get services -n online-retail
    
    # Check if Airflow is accessible
    echo -e "${BLUE}📋 Checking Airflow accessibility...${NC}"
    kubectl port-forward service/airflow-service 8080:8080 -n online-retail &
    sleep 10
    
    if curl -f http://localhost:8080/health &> /dev/null; then
        echo -e "${GREEN}✅ Airflow is accessible at http://localhost:8080${NC}"
    else
        echo -e "${RED}❌ Airflow is not accessible${NC}"
    fi
    
    # Kill port-forward
    pkill -f "kubectl port-forward"
}

# Function to display next steps
display_next_steps() {
    echo -e "${GREEN}🎉 Phase 4 setup completed successfully!${NC}"
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo -e "${BLUE}  1. Configure GitHub secrets for CI/CD${NC}"
    echo -e "${BLUE}  2. Set up monitoring dashboards in Grafana${NC}"
    echo -e "${BLUE}  3. Configure alerting rules${NC}"
    echo -e "${BLUE}  4. Test the complete pipeline${NC}"
    echo -e "${BLUE}  5. Set up production monitoring and alerting${NC}"
    echo -e "${BLUE}  6. Configure backup and disaster recovery${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting Phase 4 setup...${NC}"
    
    check_prerequisites
    configure_aws
    create_terraform_state_bucket
    initialize_terraform
    deploy_kubernetes_resources
    setup_monitoring
    setup_cicd
    verify_deployment
    display_next_steps
    
    echo -e "${GREEN}✅ Phase 4 setup completed!${NC}"
}

# Run main function
main "$@" 