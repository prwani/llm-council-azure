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
COUNCIL_MODELS = [
    "openai/gpt-5.1",
    "google/gemini-3-pro-preview",
    "anthropic/claude-sonnet-4.5",
    "x-ai/grok-4",
]

# Chairman model - synthesizes final response
CHAIRMAN_MODEL = "google/gemini-3-pro-preview"

# Data directory for conversation storage
DATA_DIR = "data/conversations"
