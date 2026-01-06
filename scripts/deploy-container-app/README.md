# Azure Container Apps Deployment

This directory contains scripts and configuration files to deploy the LLM Council application to Azure Container Apps as serverless containers.

## Prerequisites

1. **Azure CLI**: Install from https://docs.microsoft.com/cli/azure/install-azure-cli
2. **Docker**: Install from https://docs.docker.com/get-docker/
3. **Azure Subscription**: You need an active Azure subscription

## Architecture

The deployment creates:
- **Azure Container Registry (ACR)**: Stores Docker images
- **Container Apps Environment**: Hosts the container apps
- **Backend Container App**: FastAPI application (Python)
- **Frontend Container App**: React SPA served with nginx

Both apps are configured with:
- Auto-scaling (1-3 replicas)
- Health checks
- External ingress (HTTPS endpoints)
- Appropriate resource limits

## Quick Start

### 1. Deploy Everything

Run the main deployment script:

```bash
cd scripts/deploy-container-app
chmod +x deploy.sh
./deploy.sh
```

You'll be prompted for:
- **Resource Group**: Name for your Azure resource group
- **Location**: Azure region (e.g., `eastus`, `westeurope`)
- **Environment Name**: Container Apps environment name
- **ACR Name**: Container registry name (alphanumeric only)
- **Provider**: `openrouter` or `azure`
- **API Keys/Endpoints**: Based on your provider choice

The script will:
1. Create Azure resources (Resource Group, ACR, Container Apps Environment)
2. Build Docker images for backend and frontend
3. Push images to ACR
4. Deploy both container apps
5. Configure CORS and environment variables
6. Output the application URLs

### 2. Update Existing Deployment

To update after code changes:

```bash
chmod +x update.sh
./update.sh
```

Choose to update:
- Backend only
- Frontend only
- Both

### 3. Clean Up Resources

To delete all Azure resources:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

⚠️ **WARNING**: This deletes the entire resource group and all its resources!

## Environment Variables

### Backend Environment Variables

Set these before running `deploy.sh` or you'll be prompted:

```bash
export RESOURCE_GROUP="llm-council-rg"
export LOCATION="eastus"
export ACR_NAME="llmcouncilacr"
export ENVIRONMENT_NAME="llm-council-env"
export PROVIDER="openrouter"
export OPENROUTER_API_KEY="your-key-here"
# or for Azure
export PROVIDER="azure"
export AZURE_ENDPOINT="https://your-foundry.openai.azure.com/openai/v1/"
```

### Optional Variables

```bash
export SUBSCRIPTION_ID="your-subscription-id"  # If you have multiple subscriptions
export BACKEND_APP_NAME="llm-council-backend"   # Custom backend app name
export FRONTEND_APP_NAME="llm-council-frontend" # Custom frontend app name
```

## File Descriptions

### Dockerfiles

- **Dockerfile.backend**: Multi-stage build for Python FastAPI backend
  - Base: `python:3.11-slim`
  - Installs dependencies from `pyproject.toml`
  - Exposes port 8000
  - Includes health check endpoint

- **Dockerfile.frontend**: Multi-stage build for React frontend
  - Build stage: Node.js to compile React app
  - Serve stage: nginx Alpine to serve static files
  - Exposes port 80
  - Includes custom nginx configuration

### Configuration Files

- **nginx.conf**: nginx configuration for frontend
  - Serves React SPA with HTML5 History API support
  - Enables gzip compression
  - Sets security headers
  - Configures caching for static assets
  - Includes health check endpoint

### Scripts

- **deploy.sh**: Full deployment script
  - Creates all Azure resources
  - Builds and pushes Docker images
  - Deploys container apps
  - Configures networking and environment

- **update.sh**: Quick update script
  - Rebuilds and pushes images
  - Updates running container apps
  - Faster than full redeployment

- **cleanup.sh**: Resource cleanup script
  - Deletes resource group and all resources
  - Use with caution!

## Scaling Configuration

Current configuration:
- **Backend**: 0.5 CPU, 1.0 GB RAM, 1-3 replicas
- **Frontend**: 0.25 CPU, 0.5 GB RAM, 1-3 replicas

To modify scaling, edit the `az containerapp create` commands in `deploy.sh`:

```bash
--min-replicas 1 \
--max-replicas 5 \
--cpu 1.0 \
--memory 2.0Gi
```

## Monitoring and Logs

View logs using Azure CLI:

```bash
# Backend logs
az containerapp logs show \
    --name llm-council-backend \
    --resource-group $RESOURCE_GROUP \
    --follow

# Frontend logs
az containerapp logs show \
    --name llm-council-frontend \
    --resource-group $RESOURCE_GROUP \
    --follow
```

Or use Azure Portal:
1. Navigate to your Container App
2. Click "Log stream" or "Monitoring" → "Logs"

## Costs

Azure Container Apps pricing is based on:
- **vCPU-seconds** and **Memory GB-seconds** consumed
- First 180,000 vCPU-seconds and 360,000 GB-seconds per month are **free**

Estimated monthly cost for this setup (beyond free tier):
- Light usage: $5-15/month
- Moderate usage: $15-50/month

The app automatically scales to zero replicas when idle (if configured), minimizing costs.

## Troubleshooting

### Deployment fails with authentication error
```bash
az login
az account set --subscription <your-subscription-id>
```

### ACR name already exists
Choose a globally unique name (alphanumeric only, no hyphens or special characters).

### Container app doesn't start
Check logs:
```bash
az containerapp logs show --name llm-council-backend --resource-group $RESOURCE_GROUP
```

### Frontend can't connect to backend
Verify CORS is configured correctly and backend URL is set in frontend environment.

## Custom Domain (Optional)

To use a custom domain:

```bash
# Add custom domain to container app
az containerapp hostname add \
    --name llm-council-frontend \
    --resource-group $RESOURCE_GROUP \
    --hostname your-domain.com

# Bind certificate
az containerapp hostname bind \
    --name llm-council-frontend \
    --resource-group $RESOURCE_GROUP \
    --hostname your-domain.com \
    --certificate <certificate-id>
```

## Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Azure Container Apps Pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Azure CLI Reference](https://learn.microsoft.com/cli/azure/)

## Security Considerations

1. **API Keys**: Never commit API keys to version control
2. **ACR Credentials**: Stored securely by Azure Container Apps
3. **HTTPS**: All external ingress is HTTPS by default
4. **Managed Identity**: Consider using Azure Managed Identity instead of API keys for Azure services
5. **Secrets**: Use Container Apps secrets for sensitive data

To use secrets instead of environment variables:

```bash
az containerapp secret set \
    --name llm-council-backend \
    --resource-group $RESOURCE_GROUP \
    --secrets "openrouter-key=<your-key>"

az containerapp update \
    --name llm-council-backend \
    --resource-group $RESOURCE_GROUP \
    --set-env-vars "OPENROUTER_API_KEY=secretref:openrouter-key"
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Azure Container Apps documentation
3. Check application logs in Azure Portal
4. Open an issue in the project repository
