#!/bin/bash

##############################################################################
# Update Script for Azure Container Apps
# 
# This script updates existing container apps with new images.
# Use this for quick redeployments after code changes.
##############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Configuration
if [ -z "$RESOURCE_GROUP" ]; then
    read -p "Enter Resource Group name: " RESOURCE_GROUP
fi

if [ -z "$ACR_NAME" ]; then
    read -p "Enter Azure Container Registry name: " ACR_NAME
fi

BACKEND_APP_NAME="${BACKEND_APP_NAME:-llm-council-backend}"
FRONTEND_APP_NAME="${FRONTEND_APP_NAME:-llm-council-frontend}"

# Image tags
BACKEND_IMAGE_TAG="${ACR_NAME}.azurecr.io/llm-council-backend:latest"
FRONTEND_IMAGE_TAG="${ACR_NAME}.azurecr.io/llm-council-frontend:latest"

# Ask which component to update
echo ""
print_message "$BLUE" "Which component do you want to update?"
echo "1) Backend only"
echo "2) Frontend only"
echo "3) Both"
read -p "Enter choice (1-3): " CHOICE

# Login to ACR
print_message "$BLUE" "Logging into Azure Container Registry..."
az acr login --name "$ACR_NAME"

cd "$(dirname "$0")/../.."

# Update backend
if [ "$CHOICE" = "1" ] || [ "$CHOICE" = "3" ]; then
    print_message "$BLUE" "Building and pushing backend image..."
    docker build \
        -f scripts/deploy-container-app/Dockerfile.backend \
        -t "$BACKEND_IMAGE_TAG" \
        .
    docker push "$BACKEND_IMAGE_TAG"
    
    print_message "$BLUE" "Updating backend container app..."
    az containerapp update \
        --name "$BACKEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --image "$BACKEND_IMAGE_TAG" \
        --output none
    
    print_message "$GREEN" "✓ Backend updated successfully"
fi

# Update frontend
if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "3" ]; then
    # Get backend URL if updating frontend
    if [ "$CHOICE" = "2" ]; then
        BACKEND_URL=$(az containerapp show \
            --name "$BACKEND_APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --query properties.configuration.ingress.fqdn \
            -o tsv)
    fi
    
    print_message "$BLUE" "Building and pushing frontend image..."
    docker build \
        -f scripts/deploy-container-app/Dockerfile.frontend \
        ${BACKEND_URL:+--build-arg VITE_API_URL="https://$BACKEND_URL"} \
        -t "$FRONTEND_IMAGE_TAG" \
        .
    docker push "$FRONTEND_IMAGE_TAG"
    
    print_message "$BLUE" "Updating frontend container app..."
    az containerapp update \
        --name "$FRONTEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --image "$FRONTEND_IMAGE_TAG" \
        --output none
    
    print_message "$GREEN" "✓ Frontend updated successfully"
fi

print_message "$GREEN" "============================================"
print_message "$GREEN" "Update completed successfully!"
print_message "$GREEN" "============================================"
