#!/bin/bash
# Development Environment Setup Script
echo "Setting up development environment..."

# Install additional Python packages for development
pip3 install black pylint pytest pytest-cov

# Install Node.js packages for development
npm install -g prettier eslint

# Create .gitignore if it doesn't exist
if [ ! -f .gitignore ]; then
    cat > .gitignore << 'GITIGNORE'
# Python
__pycache__/
*.py[cod]
*.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Logs
*.log
logs/

# Airflow
airflow.cfg
airflow.db
airflow-webserver.pid

# Docker
.dockerignore

# AWS
.aws/

# Temporary files
*.tmp
*.temp
GITIGNORE
fi

echo "Development environment setup complete!"
