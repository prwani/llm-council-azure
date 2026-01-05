# Azure VM Deployment Guide

This guide walks you through deploying the LLM Council application on an Azure VM with managed identity for Azure Foundry access.

## Prerequisites

- Azure subscription with access to Azure AI Foundry
- Azure CLI installed locally
- SSH key pair for VM access

## Step 1: Create Azure VM

### Option A: Using Azure Portal

1. Navigate to Azure Portal → Virtual Machines → Create
2. Configure:
   - **Image**: Ubuntu Server 22.04 LTS
   - **Size**: Standard_D2s_v3 or larger (2 vCPUs, 8 GB RAM minimum)
   - **Authentication**: SSH public key
   - **Inbound ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 8000 (Backend API)
3. Review + Create

### Option B: Using Azure CLI

```bash
# Set variables
RESOURCE_GROUP="llm-council-rg"
VM_NAME="llm-council-vm"
LOCATION="eastus"
VM_SIZE="Standard_D2s_v3"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create VM with system-assigned managed identity
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --image Ubuntu2204 \
  --size $VM_SIZE \
  --admin-username azureuser \
  --generate-ssh-keys \
  --assign-identity \
  --public-ip-sku Standard

# Open required ports
az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 80 --priority 1001
az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 443 --priority 1002
az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 8000 --priority 1003

# Get the VM's managed identity principal ID
IDENTITY_ID=$(az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --query identity.principalId -o tsv)
echo "VM Managed Identity Principal ID: $IDENTITY_ID"
```

## Step 2: Grant Managed Identity Access to Azure AI Foundry

```bash
# Get your Azure AI Foundry resource details
FOUNDRY_RESOURCE_GROUP="your-foundry-rg"
FOUNDRY_NAME="llm-council-foundry"

# Grant "Cognitive Services User" role to the VM's managed identity
az role assignment create \
  --assignee $IDENTITY_ID \
  --role "Cognitive Services User" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$FOUNDRY_RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_NAME"

# Verify the role assignment
az role assignment list --assignee $IDENTITY_ID --output table
```

**Note:** Ensure the role is assigned at the appropriate scope (resource, resource group, or subscription level).

## Step 3: Connect to VM and Setup Environment

```bash
# SSH into the VM
ssh azureuser@<VM_PUBLIC_IP>
```

Once connected, run the setup script:

```bash
# Download and run the setup script (we'll create this next)
curl -O https://raw.githubusercontent.com/your-repo/llm-council-azure/main/scripts/vm_setup.sh
chmod +x vm_setup.sh
sudo ./vm_setup.sh
```

Or manually follow these steps:

### 3.1 Install System Dependencies

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
sudo apt-get install -y \
  python3.11 \
  python3.11-venv \
  python3-pip \
  git \
  nginx \
  curl \
  build-essential

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.cargo/env
```

### 3.2 Clone and Setup Application

```bash
# Clone your repository
cd /home/azureuser
git clone https://github.com/your-username/llm-council-azure.git
cd llm-council-azure

# Create .env file
cat > .env << 'EOF'
PROVIDER=azure
AZURE_ENDPOINT=https://llm-council-foundry.openai.azure.com/openai/v1/
EOF

# Install Python dependencies
uv sync

# Build frontend
cd frontend
npm install
npm run build
cd ..
```

## Step 4: Configure Services

### 4.1 Create Backend Service

```bash
sudo nano /etc/systemd/system/llm-council-backend.service
```

Paste the following:

```ini
[Unit]
Description=LLM Council Backend API
After=network.target

[Service]
Type=simple
User=azureuser
WorkingDirectory=/home/azureuser/llm-council-azure
Environment="PATH=/home/azureuser/.local/bin:/home/azureuser/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/home/azureuser/.cargo/bin/uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 4.2 Configure Nginx

```bash
sudo nano /etc/nginx/sites-available/llm-council
```

Paste the following:

```nginx
server {
    listen 80;
    server_name _;

    # Frontend
    root /home/azureuser/llm-council-azure/frontend/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/llm-council /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
```

## Step 5: Start Services

```bash
# Enable and start backend service
sudo systemctl daemon-reload
sudo systemctl enable llm-council-backend
sudo systemctl start llm-council-backend

# Check backend status
sudo systemctl status llm-council-backend

# Restart nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

## Step 6: Update Frontend API Configuration

Update the frontend to use the `/api/` prefix:

```bash
nano /home/azureuser/llm-council-azure/frontend/src/api.js
```

Change the API_BASE_URL to use relative path:

```javascript
const API_BASE_URL = '/api';
```

Rebuild frontend:

```bash
cd /home/azureuser/llm-council-azure/frontend
npm run build
cd ..
```

## Step 7: Verify Deployment

### Test Backend:

```bash
curl http://localhost:8000/conversations
```

### Test from Browser:

Navigate to `http://<VM_PUBLIC_IP>` in your browser.

## Step 8: Configure Firewall (Optional but Recommended)

```bash
# Install UFW
sudo apt-get install -y ufw

# Configure firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000/tcp

# Enable firewall
sudo ufw --force enable
```

## Troubleshooting

### Check Backend Logs:

```bash
sudo journalctl -u llm-council-backend -f
```

### Check Nginx Logs:

```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### Test Managed Identity:

```bash
# Get a token using managed identity
TOKEN=$(curl -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://cognitiveservices.azure.com/" | jq -r .access_token)
echo $TOKEN
```

### Verify Azure Foundry Connection:

```bash
cd /home/azureuser/llm-council-azure
uv run python -c "
from backend.azure_foundry import query_model
import asyncio

async def test():
    result = await query_model('grok-3', [{'role': 'user', 'content': 'Hello'}])
    print(result)

asyncio.run(test())
"
```

## Maintenance

### Update Application:

```bash
cd /home/azureuser/llm-council-azure
git pull
uv sync
cd frontend
npm install
npm run build
cd ..
sudo systemctl restart llm-council-backend
```

### View Service Status:

```bash
sudo systemctl status llm-council-backend
sudo systemctl status nginx
```

### Restart Services:

```bash
sudo systemctl restart llm-council-backend
sudo systemctl restart nginx
```

## Security Best Practices

1. **Enable HTTPS**: Use Let's Encrypt with Certbot for free SSL certificates
2. **Restrict SSH**: Configure SSH to use key-only authentication
3. **Update Regularly**: Keep the system and packages up to date
4. **Monitor Logs**: Set up log monitoring and alerts
5. **Backup Data**: Regular backups of the `/home/azureuser/llm-council-azure/data` directory
6. **Firewall**: Keep UFW enabled and configured properly
7. **Managed Identity**: Never store credentials in code or config files

## Optional: Setup HTTPS with Let's Encrypt

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
sudo systemctl reload nginx
```

## Monitoring

### Setup Azure Monitor (Optional):

```bash
# Install Azure Monitor agent
wget https://aka.ms/dependencyagentlinux -O InstallDependencyAgent-Linux64.bin
sudo sh InstallDependencyAgent-Linux64.bin -s
```

Configure monitoring through Azure Portal → Monitor → Virtual Machines.
