# Troubleshooting Guide - 500 Internal Server Error

## Quick Diagnosis Commands

Run these commands on your VM to diagnose the issue:

```bash
# 1. Check if backend service is running
sudo systemctl status llm-council-backend

# 2. Check backend logs for errors
sudo journalctl -u llm-council-backend -n 50 --no-pager

# 3. Check if backend is listening on port 8000
sudo netstat -tlnp | grep 8000

# 4. Check nginx error logs
sudo tail -50 /var/log/nginx/llm-council-error.log

# 5. Test backend directly (bypass nginx)
curl http://localhost:8000/conversations
```

## Common Issues and Fixes

### Issue 1: Backend Service Not Running

**Symptoms:**
```
● llm-council-backend.service - LLM Council Backend API
   Loaded: loaded
   Active: failed (Result: exit-code)
```

**Fix:**
```bash
# Check the detailed error
sudo journalctl -u llm-council-backend -n 100 --no-pager

# Common causes:
# - Wrong user in service file
# - Wrong paths
# - Missing dependencies
```

### Issue 2: Path or User Issues in Service File

**Problem:** Service file has wrong username or paths

**Fix:**
```bash
# Edit the service file
sudo nano /etc/systemd/system/llm-council-backend.service

# Make sure these match your setup:
User=azureuser                                    # Your actual username
WorkingDirectory=/home/azureuser/llm-council-azure  # Your actual path
ExecStart=/home/azureuser/.cargo/bin/uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000

# If uv is in a different location, find it:
which uv

# Then update ExecStart with the correct path
# After editing:
sudo systemctl daemon-reload
sudo systemctl restart llm-council-backend
```

### Issue 3: Missing or Incorrect .env File

**Problem:** Backend can't find Azure endpoint or has wrong configuration

**Fix:**
```bash
cd ~/llm-council-azure
cat .env

# Should contain:
# PROVIDER=azure
# AZURE_ENDPOINT=https://your-actual-endpoint.openai.azure.com/openai/v1/

# If missing or wrong, fix it:
nano .env

# Then restart:
sudo systemctl restart llm-council-backend
```

### Issue 4: Python Dependencies Not Installed

**Problem:** Missing packages

**Fix:**
```bash
cd ~/llm-council-azure

# Reinstall dependencies
uv sync

# Test manually first
uv run python -c "from backend import main; print('Import successful')"

# If that works, restart service
sudo systemctl restart llm-council-backend
```

### Issue 5: Managed Identity Not Working

**Problem:** Can't authenticate to Azure Foundry

**Symptoms in logs:**
```
DefaultAzureCredential failed to retrieve a token
Authentication failed
```

**Fix:**
```bash
# Test managed identity token retrieval
curl -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://cognitiveservices.azure.com/" | jq

# If this fails, check:
# 1. VM has system-assigned managed identity enabled
az vm show --resource-group llm-council --name llm-council-vm --query identity

# 2. Managed identity has proper role assignment
az role assignment list --assignee <IDENTITY_PRINCIPAL_ID> --output table

# 3. Re-grant access if needed
IDENTITY_ID=$(az vm show --resource-group llm-council --name llm-council-vm --query identity.principalId -o tsv)
az role assignment create \
  --assignee $IDENTITY_ID \
  --role "Cognitive Services User" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/YOUR_FOUNDRY_RG/providers/Microsoft.CognitiveServices/accounts/YOUR_FOUNDRY_NAME"
```

### Issue 6: Port 8000 Already in Use

**Problem:** Another process is using port 8000

**Fix:**
```bash
# Find what's using port 8000
sudo lsof -i :8000

# Kill the process if needed (replace PID with actual process ID)
sudo kill -9 <PID>

# Then restart service
sudo systemctl restart llm-council-backend
```

### Issue 7: Nginx Configuration Error

**Problem:** Nginx can't connect to backend

**Fix:**
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx is running
sudo systemctl status nginx

# Verify backend proxy configuration
sudo cat /etc/nginx/sites-available/llm-council | grep proxy_pass

# Should show: proxy_pass http://127.0.0.1:8000/;

# Restart nginx
sudo systemctl restart nginx
```

### Issue 8: File Permissions

**Problem:** Service can't read files or write to data directory

**Fix:**
```bash
# Fix ownership
sudo chown -R azureuser:azureuser ~/llm-council-azure

# Ensure data directory exists and is writable
mkdir -p ~/llm-council-azure/data/conversations
chmod 755 ~/llm-council-azure/data/conversations

# Restart service
sudo systemctl restart llm-council-backend
```

## Step-by-Step Troubleshooting Process

### Step 1: Check Backend Service Status

```bash
sudo systemctl status llm-council-backend
```

- **If "active (running)"** → Go to Step 2
- **If "failed" or "inactive"** → Check logs in Step 3

### Step 2: Test Backend Directly

```bash
curl http://localhost:8000/conversations
```

- **If you get JSON response** → Backend works, issue is with nginx (Go to Step 5)
- **If connection refused** → Backend not listening (Go to Step 3)
- **If error response** → Backend has internal error (Go to Step 3)

### Step 3: Check Backend Logs

```bash
sudo journalctl -u llm-council-backend -n 100 --no-pager
```

Look for errors:
- **ImportError** → Missing dependencies (Fix: `uv sync`)
- **FileNotFoundError** → Wrong paths in service file
- **Authentication errors** → Managed identity issue
- **Port already in use** → Kill conflicting process

### Step 4: Manual Test

```bash
cd ~/llm-council-azure
uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

- Watch for errors
- If it starts successfully, the issue is with the service configuration
- Press Ctrl+C to stop, then fix the service file

### Step 5: Check Nginx Configuration

```bash
# Test nginx config
sudo nginx -t

# Check nginx error logs
sudo tail -50 /var/log/nginx/llm-council-error.log

# Verify backend is proxied correctly
curl -v http://localhost/api/conversations
```

## Complete Reset (Nuclear Option)

If nothing else works:

```bash
# Stop everything
sudo systemctl stop llm-council-backend
sudo systemctl stop nginx

# Remove and reinstall
cd ~
rm -rf llm-council-azure
git clone <your-repo-url> llm-council-azure
cd llm-council-azure

# Run setup script again
./scripts/vm_setup.sh

# Update .env with correct values
nano .env

# Reinstall service files
sudo cp scripts/llm-council-backend.service /etc/systemd/system/
sudo cp scripts/nginx-llm-council /etc/nginx/sites-available/llm-council

# Restart everything
sudo systemctl daemon-reload
sudo systemctl start llm-council-backend
sudo systemctl start nginx

# Check status
sudo systemctl status llm-council-backend
```

## Verification Steps

Once you've made fixes:

```bash
# 1. Backend service is running
sudo systemctl status llm-council-backend
# Should show: "active (running)"

# 2. Backend responds on port 8000
curl http://localhost:8000/conversations
# Should return: {"conversations":[]}

# 3. Nginx is running
sudo systemctl status nginx
# Should show: "active (running)"

# 4. Can access through nginx
curl http://localhost/api/conversations
# Should return: {"conversations":[]}

# 5. Check in browser
# Navigate to: http://<VM_PUBLIC_IP>
```

## Getting Help

If still stuck, collect this diagnostic info:

```bash
# Create diagnostic bundle
cd ~/llm-council-azure
cat << 'EOF' > /tmp/diagnostics.sh
#!/bin/bash
echo "=== System Info ==="
uname -a
echo ""
echo "=== Backend Service Status ==="
sudo systemctl status llm-council-backend
echo ""
echo "=== Backend Logs (last 50 lines) ==="
sudo journalctl -u llm-council-backend -n 50 --no-pager
echo ""
echo "=== Port 8000 Status ==="
sudo netstat -tlnp | grep 8000
echo ""
echo "=== Nginx Status ==="
sudo systemctl status nginx
echo ""
echo "=== Nginx Error Logs ==="
sudo tail -30 /var/log/nginx/llm-council-error.log
echo ""
echo "=== Environment File ==="
cat ~/llm-council-azure/.env
echo ""
echo "=== Python Environment ==="
cd ~/llm-council-azure && uv run python --version
echo ""
echo "=== Directory Structure ==="
ls -la ~/llm-council-azure/
EOF

chmod +x /tmp/diagnostics.sh
/tmp/diagnostics.sh > /tmp/diagnostics.txt 2>&1
cat /tmp/diagnostics.txt
```

Share the output for further assistance.
