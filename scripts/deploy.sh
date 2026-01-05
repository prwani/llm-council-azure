#!/bin/bash
#
# Quick Deploy Script - Run this after pulling updates
#

set -e

APP_DIR="${HOME}/llm-council-azure"

echo "Deploying LLM Council updates..."

# Navigate to app directory
cd "$APP_DIR"

# Pull latest changes
echo "[1/4] Pulling latest changes from git..."
git pull

# Update Python dependencies
echo "[2/4] Updating Python dependencies..."
uv sync

# Rebuild frontend
echo "[3/4] Rebuilding frontend..."
cd frontend
npm install
npm run build
cd ..

# Restart backend service
echo "[4/4] Restarting backend service..."
sudo systemctl restart llm-council-backend

echo ""
echo "Deployment complete!"
echo "Check status with: sudo systemctl status llm-council-backend"
