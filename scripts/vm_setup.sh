#!/bin/bash
#
# Azure VM Setup Script for LLM Council
# Run this script on a fresh Azure Ubuntu 22.04 VM
#

set -e

echo "========================================="
echo "LLM Council Azure VM Setup"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "Please run this script as a regular user with sudo privileges, not as root."
  exit 1
fi

# Update system
echo "[1/8] Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
echo "[2/8] Installing system dependencies..."
sudo apt-get install -y \
  python3.11 \
  python3.11-venv \
  python3-pip \
  git \
  nginx \
  curl \
  build-essential \
  jq

# Install Node.js 20.x
echo "[3/8] Installing Node.js..."
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "Node.js already installed: $(node --version)"
fi

# Install uv
echo "[4/8] Installing uv (Python package manager)..."
if ! command -v uv &> /dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.cargo/bin:$PATH"
  source $HOME/.cargo/env
else
  echo "uv already installed: $(uv --version)"
fi

# Get application directory
APP_DIR="${HOME}/llm-council-azure"

# Check if application already exists
if [ -d "$APP_DIR" ]; then
  echo "[5/8] Application directory already exists. Pulling latest changes..."
  cd "$APP_DIR"
  git pull
else
  echo "[5/8] Application not found. Please clone the repository first:"
  echo "    cd ~"
  echo "    git clone https://github.com/your-username/llm-council-azure.git"
  echo ""
  echo "Then run this script again."
  exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f "$APP_DIR/.env" ]; then
  echo "[6/8] Creating .env file..."
  cat > "$APP_DIR/.env" << 'EOF'
PROVIDER=azure
AZURE_ENDPOINT=https://llm-council-foundry.openai.azure.com/openai/v1/
EOF
  echo "Created .env file. Please update AZURE_ENDPOINT with your actual endpoint."
else
  echo "[6/8] .env file already exists, skipping..."
fi

# Install Python dependencies
echo "[7/8] Installing Python dependencies..."
cd "$APP_DIR"
uv sync

# Install and build frontend
echo "[8/8] Building frontend..."
cd "$APP_DIR/frontend"
npm install
npm run build

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Update the .env file with your Azure Foundry endpoint:"
echo "   nano $APP_DIR/.env"
echo ""
echo "2. Create and start the systemd service:"
echo "   sudo cp $APP_DIR/scripts/llm-council-backend.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable llm-council-backend"
echo "   sudo systemctl start llm-council-backend"
echo ""
echo "3. Configure and start Nginx:"
echo "   sudo cp $APP_DIR/scripts/nginx-llm-council /etc/nginx/sites-available/llm-council"
echo "   sudo ln -s /etc/nginx/sites-available/llm-council /etc/nginx/sites-enabled/"
echo "   sudo rm -f /etc/nginx/sites-enabled/default"
echo "   sudo nginx -t"
echo "   sudo systemctl restart nginx"
echo ""
echo "4. Test the application at http://$(curl -s ifconfig.me)"
echo ""
