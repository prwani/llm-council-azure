# Azure Foundry Configuration Example

This document shows how to configure and use Azure Foundry models with LLM Council.

## Quick Start

1. **Set up your `.env` file:**

```bash
# Use Azure Foundry
PROVIDER=azure
AZURE_ENDPOINT=https://llm-council-foundry.openai.azure.com/openai/v1/
```

2. **Authenticate with Azure:**

```bash
# Using Azure CLI (recommended for development)
az login

# Or set service principal credentials
export AZURE_TENANT_ID=your-tenant-id
export AZURE_CLIENT_ID=your-client-id
export AZURE_CLIENT_SECRET=your-client-secret
```

3. **Update model configuration in `backend/config.py`:**

```python
PROVIDER = "azure"  # Can also be set via .env
AZURE_ENDPOINT = "https://llm-council-foundry.openai.azure.com/openai/v1/"

# Use Azure deployment names (not OpenRouter format)
COUNCIL_MODELS = [
    "grok-3",
    "gemini-3-pro",
    "claude-sonnet-4",
    "gpt-5",
]

CHAIRMAN_MODEL = "gemini-3-pro"
```

4. **Start the application:**

```bash
# Backend
uv run python -m backend.main

# Frontend
cd frontend
npm run dev
```

## Switching Between Providers

To switch between OpenRouter and Azure, just change the `PROVIDER` environment variable:

### For OpenRouter:
```bash
PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-v1-your-key
```

### For Azure:
```bash
PROVIDER=azure
AZURE_ENDPOINT=https://your-endpoint.openai.azure.com/openai/v1/
```

No code changes needed - just update your `.env` file and restart the backend!

## Architecture Notes

- **Routing**: The `openrouter.py` module automatically routes requests to the correct provider
- **Lazy Loading**: Azure module is only imported when `PROVIDER=azure`
- **Same Interface**: Both providers use the same API interface, so the rest of the codebase is unchanged
- **Authentication**: OpenRouter uses API keys, Azure uses Azure Entra (DefaultAzureCredential)

## Troubleshooting

**Authentication Errors:**
- Ensure you're logged in with `az login`
- Check that your Azure identity has access to the Foundry resource
- Verify AZURE_ENDPOINT is correct

**Model Not Found:**
- Verify deployment names in your Azure Foundry resource
- Ensure model names in config match your deployments exactly
- Check that models are deployed and available in your region
