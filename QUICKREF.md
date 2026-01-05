# Azure VM Deployment Quick Reference

## Initial Setup Commands

```bash
# 1. Create VM with managed identity
az vm create \
  --resource-group llm-council-rg \
  --name llm-council-vm \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --assign-identity

# 2. Get managed identity ID
IDENTITY_ID=$(az vm show --resource-group llm-council-rg --name llm-council-vm --query identity.principalId -o tsv)

# 3. Grant Foundry access
az role assignment create \
  --assignee $IDENTITY_ID \
  --role "Cognitive Services User" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/your-foundry-rg/providers/Microsoft.CognitiveServices/accounts/your-foundry-name"

# 4. SSH to VM
ssh azureuser@<VM_PUBLIC_IP>

# 5. Clone and setup
git clone https://github.com/your-username/llm-council-azure.git
cd llm-council-azure
chmod +x scripts/vm_setup.sh
./scripts/vm_setup.sh

# 6. Configure services
sudo cp scripts/llm-council-backend.service /etc/systemd/system/
sudo cp scripts/nginx-llm-council /etc/nginx/sites-available/llm-council
sudo ln -s /etc/nginx/sites-available/llm-council /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 7. Start services
sudo systemctl daemon-reload
sudo systemctl enable llm-council-backend
sudo systemctl start llm-council-backend
sudo systemctl restart nginx
```

## Monitoring Commands

```bash
# Check backend status
sudo systemctl status llm-council-backend

# View backend logs
sudo journalctl -u llm-council-backend -f

# Check nginx status
sudo systemctl status nginx

# View nginx logs
sudo tail -f /var/log/nginx/llm-council-access.log
sudo tail -f /var/log/nginx/llm-council-error.log
```

## Update/Deploy Commands

```bash
cd ~/llm-council-azure
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## Test Managed Identity

```bash
# Get token
curl -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://cognitiveservices.azure.com/" | jq

# Test Azure Foundry connection
cd ~/llm-council-azure
uv run python -c "
from backend.azure_foundry import query_model
import asyncio
async def test():
    result = await query_model('grok-3', [{'role': 'user', 'content': 'Hello'}])
    print(result)
asyncio.run(test())
"
```

## Troubleshooting

```bash
# Restart backend
sudo systemctl restart llm-council-backend

# Restart nginx
sudo systemctl restart nginx

# Check firewall
sudo ufw status

# Check if port 8000 is listening
sudo netstat -tlnp | grep 8000

# Test backend directly
curl http://localhost:8000/conversations
```
