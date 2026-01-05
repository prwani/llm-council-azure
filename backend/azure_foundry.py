"""Azure Foundry API client for making LLM requests."""

import asyncio
from openai import AsyncOpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from typing import List, Dict, Any, Optional
from .config import AZURE_ENDPOINT


# Create Azure credential and token provider
_credential = None
_client = None


def _get_client() -> AsyncOpenAI:
    """Get or create the Azure OpenAI client."""
    global _credential, _client
    
    if _client is None:
        _credential = DefaultAzureCredential()
        token_provider = get_bearer_token_provider(
            _credential, 
            "https://cognitiveservices.azure.com/.default"
        )
        
        # For Azure AI Foundry, use AsyncOpenAI with api_key set to token
        # The token provider returns a callable that gets the current token
        token = token_provider()
        
        _client = AsyncOpenAI(
            base_url=AZURE_ENDPOINT,
            api_key=token,
            default_headers={"Authorization": f"Bearer {token}"}
        )
    
    return _client


async def query_model(
    model: str,
    messages: List[Dict[str, str]],
    timeout: float = 120.0
) -> Optional[Dict[str, Any]]:
    """
    Query a single model via Azure Foundry API.

    Args:
        model: Azure deployment name (e.g., "grok-3")
        messages: List of message dicts with 'role' and 'content'
        timeout: Request timeout in seconds

    Returns:
        Response dict with 'content' and optional 'reasoning_details', or None if failed
    """
    try:
        client = _get_client()
        
        # Call Azure Foundry API (uses OpenAI chat completions format)
        response = await client.chat.completions.create(
            model=model,
            messages=messages,
            timeout=timeout,
        )
        
        # Validate response has choices
        if not response.choices or len(response.choices) == 0:
            print(f"Error: Azure Foundry model {model} returned no choices")
            return None
        
        message = response.choices[0].message
        
        return {
            'content': message.content,
            'reasoning_details': None  # Azure Foundry typically does not support reasoning_details in standard responses
        }

    except Exception as e:
        print(f"Error querying Azure Foundry model {model}: {e}")
        return None


async def query_models_parallel(
    models: List[str],
    messages: List[Dict[str, str]]
) -> Dict[str, Optional[Dict[str, Any]]]:
    """
    Query multiple models in parallel.

    Args:
        models: List of Azure deployment names
        messages: List of message dicts to send to each model

    Returns:
        Dict mapping model identifier to response dict (or None if failed)
    """
    # Create tasks for all models
    tasks = [query_model(model, messages) for model in models]

    # Wait for all to complete
    responses = await asyncio.gather(*tasks)

    # Map models to their responses
    return {model: response for model, response in zip(models, responses)}
