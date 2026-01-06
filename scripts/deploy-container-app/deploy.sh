#!/bin/bash

##############################################################################
# Azure Container Apps Deployment Script
# 
# This script deploys the LLM Council application to Azure Container Apps
# with both backend and frontend as separate container apps.
##############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if required commands are available
check_dependencies() {
    print_message "$BLUE" "Checking dependencies..."
    
    if ! command -v az &> /dev/null; then
        print_message "$RED" "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_message "$RED" "Docker is not installed. Please install it from https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    print_message "$GREEN" "✓ All dependencies are installed"
}

# Configuration variables
print_message "$BLUE" "=== Azure Container Apps Deployment ==="
echo ""

# Prompt for required variables if not set
if [ -z "$RESOURCE_GROUP" ]; then
    read -p "Enter Azure Resource Group name: " RESOURCE_GROUP
fi

if [ -z "$LOCATION" ]; then
    read -p "Enter Azure Location (e.g., eastus, westeurope): " LOCATION
    LOCATION=${LOCATION:-eastus}
fi

if [ -z "$ENVIRONMENT_NAME" ]; then
    read -p "Enter Container App Environment name: " ENVIRONMENT_NAME
    ENVIRONMENT_NAME=${ENVIRONMENT_NAME:-llm-council-env}
fi

if [ -z "$ACR_NAME" ]; then
    read -p "Enter Azure Container Registry name (alphanumeric only): " ACR_NAME
fi

if [ -z "$BACKEND_APP_NAME" ]; then
    BACKEND_APP_NAME="llm-council-backend"
fi

if [ -z "$FRONTEND_APP_NAME" ]; then
    FRONTEND_APP_NAME="llm-council-frontend"
fi

# Environment variables for the backend
if [ -z "$PROVIDER" ]; then
    read -p "Enter PROVIDER (openrouter/azure) [openrouter]: " PROVIDER
    PROVIDER=${PROVIDER:-openrouter}
fi

if [ "$PROVIDER" = "openrouter" ] && [ -z "$OPENROUTER_API_KEY" ]; then
    read -s -p "Enter OpenRouter API Key: " OPENROUTER_API_KEY
    echo ""
fi

if [ "$PROVIDER" = "azure" ] && [ -z "$AZURE_ENDPOINT" ]; then
    read -p "Enter Azure Foundry Endpoint: " AZURE_ENDPOINT
fi

# Image tags
BACKEND_IMAGE_TAG="${ACR_NAME}.azurecr.io/llm-council-backend:latest"
FRONTEND_IMAGE_TAG="${ACR_NAME}.azurecr.io/llm-council-frontend:latest"

# Check dependencies
check_dependencies

# Login to Azure
print_message "$BLUE" "Logging into Azure..."
az account show &> /dev/null || az login

# Set subscription if provided
if [ -n "$SUBSCRIPTION_ID" ]; then
    print_message "$BLUE" "Setting subscription to $SUBSCRIPTION_ID..."
    az account set --subscription "$SUBSCRIPTION_ID"
fi

# Create resource group
print_message "$BLUE" "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none || true

# Create Azure Container Registry
print_message "$BLUE" "Creating Azure Container Registry '$ACR_NAME'..."
az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Basic \
    --admin-enabled true \
    --output none || true

# Login to ACR
print_message "$BLUE" "Logging into Azure Container Registry..."
az acr login --name "$ACR_NAME"

# Build and push backend image
print_message "$BLUE" "Building and pushing backend Docker image..."
cd "$(dirname "$0")/../.."
docker build \
    -f scripts/deploy-container-app/Dockerfile.backend \
    -t "$BACKEND_IMAGE_TAG" \
    .

docker push "$BACKEND_IMAGE_TAG"
print_message "$GREEN" "✓ Backend image pushed successfully"

# Build and push frontend image
print_message "$BLUE" "Building and pushing frontend Docker image..."
docker build \
    -f scripts/deploy-container-app/Dockerfile.frontend \
    -t "$FRONTEND_IMAGE_TAG" \
    .

docker push "$FRONTEND_IMAGE_TAG"
print_message "$GREEN" "✓ Frontend image pushed successfully"

# Create Container App Environment
print_message "$BLUE" "Creating Container App Environment '$ENVIRONMENT_NAME'..."
az containerapp env create \
    --name "$ENVIRONMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none || true

# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query passwords[0].value -o tsv)

# Deploy backend container app
print_message "$BLUE" "Deploying backend container app..."
az containerapp create \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$BACKEND_IMAGE_TAG" \
    --registry-server "${ACR_NAME}.azurecr.io" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --target-port 8000 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.5 \
    --memory 1.0Gi \
    --env-vars \
        "PROVIDER=${PROVIDER}" \
        "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}" \
        "AZURE_ENDPOINT=${AZURE_ENDPOINT:-}" \
    --output none

BACKEND_URL=$(az containerapp show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn \
    -o tsv)

print_message "$GREEN" "✓ Backend deployed at: https://$BACKEND_URL"

# Update frontend environment variable with backend URL
print_message "$BLUE" "Building frontend with backend URL..."

# Rebuild frontend image with backend URL as build arg
docker build \
    -f scripts/deploy-container-app/Dockerfile.frontend \
    --build-arg VITE_API_URL="https://$BACKEND_URL" \
    -t "$FRONTEND_IMAGE_TAG" \
    .

docker push "$FRONTEND_IMAGE_TAG"

# Deploy frontend container app
print_message "$BLUE" "Deploying frontend container app..."
az containerapp create \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT_NAME" \
    --image "$FRONTEND_IMAGE_TAG" \
    --registry-server "${ACR_NAME}.azurecr.io" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --target-port 80 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.25 \
    --memory 0.5Gi \
    --env-vars \
        "VITE_API_URL=https://$BACKEND_URL" \
    --output none

FRONTEND_URL=$(az containerapp show \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn \
    -o tsv)

print_message "$GREEN" "✓ Frontend deployed at: https://$FRONTEND_URL"

# Update backend CORS settings
print_message "$BLUE" "Updating backend CORS settings..."
az containerapp update \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --set-env-vars "CORS_ORIGINS=https://$FRONTEND_URL" \
    --output none

print_message "$GREEN" "============================================"
print_message "$GREEN" "Deployment completed successfully!"
print_message "$GREEN" "============================================"
echo ""
print_message "$BLUE" "Backend URL:  https://$BACKEND_URL"
print_message "$BLUE" "Frontend URL: https://$FRONTEND_URL"
echo ""
print_message "$YELLOW" "Note: It may take a few minutes for the apps to be fully ready."
print_message "$YELLOW" "Visit the frontend URL to access your application."
