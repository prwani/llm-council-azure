"""Azure Foundry API client for making LLM requests."""

from openai import AsyncOpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from typing import List, Dict, Any, Optional
from .config import AZURE_ENDPOINT


# Create Azure credential and token provider
_token_provider = None
_client = None


def _get_client() -> AsyncOpenAI:
    """Get or create the Azure OpenAI client."""
    global _token_provider, _client
    
    if _client is None:
        _token_provider = get_bearer_token_provider(
            DefaultAzureCredential(), 
            "https://cognitiveservices.azure.com/.default"
        )
        _client = AsyncOpenAI(
            base_url=AZURE_ENDPOINT,
            api_key=_token_provider
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
        
        message = response.choices[0].message
        
        return {
            'content': message.content,
            'reasoning_details': None  # Azure Foundry may not support this
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
    import asyncio

    # Create tasks for all models
    tasks = [query_model(model, messages) for model in models]

    # Wait for all to complete
    responses = await asyncio.gather(*tasks)

    # Map models to their responses
    return {model: response for model, response in zip(models, responses)}
