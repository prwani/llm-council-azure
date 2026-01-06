#!/bin/bash

##############################################################################
# Cleanup Script for Azure Container Apps
# 
# This script removes all Azure resources created for the deployment.
# WARNING: This will delete all resources in the resource group!
##############################################################################

set -e

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
    read -p "Enter Resource Group name to delete: " RESOURCE_GROUP
fi

print_message "$RED" "============================================"
print_message "$RED" "WARNING: This will delete ALL resources"
print_message "$RED" "in the resource group: $RESOURCE_GROUP"
print_message "$RED" "============================================"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_message "$YELLOW" "Cleanup cancelled."
    exit 0
fi

print_message "$BLUE" "Deleting resource group '$RESOURCE_GROUP'..."
az group delete \
    --name "$RESOURCE_GROUP" \
    --yes \
    --no-wait

print_message "$GREEN" "Deletion initiated. Resources will be removed in the background."
print_message "$YELLOW" "You can check the status in the Azure Portal."
