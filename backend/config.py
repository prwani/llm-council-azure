"""Configuration for the LLM Council."""

import os
from dotenv import load_dotenv

load_dotenv()

# Provider selection: "openrouter" or "azure"
PROVIDER = os.getenv("PROVIDER", "openrouter").lower()

# OpenRouter configuration
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"

# Azure Foundry configuration
AZURE_ENDPOINT = os.getenv("AZURE_ENDPOINT", "https://llm-council-foundry.openai.azure.com/openai/v1/")

# Council members - list of model identifiers
# For OpenRouter: use format "provider/model-name" (e.g., "openai/gpt-5.1")
# For Azure: use deployment names (e.g., "grok-3")
# IMPORTANT: Change these to match your selected PROVIDER!
# The defaults below are for OpenRouter. If using Azure, replace with your deployment names.
COUNCIL_MODELS = [
    "DeepSeek-V3.2",
    "gpt-5.2-chat",
    "Mistral-Large-3",
    "grok-3",
]

# Chairman model - synthesizes final response
# IMPORTANT: Use the appropriate format for your selected PROVIDER!
# The default below is for OpenRouter. If using Azure, replace with your deployment name.
CHAIRMAN_MODEL = "gpt-5.2-chat"

# Data directory for conversation storage
DATA_DIR = "data/conversations"
