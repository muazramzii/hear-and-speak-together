"""Chooses the AI feedback provider.

The rest of the application never names a vendor - swapping Gemini for OpenAI
is an environment change.
"""

import logging

from django.conf import settings

from .base import AIService
from .providers import GeminiAIService, MockAIService, OpenAIService

logger = logging.getLogger(__name__)

DEFAULT_MODELS = {
    "gemini": "gemini-2.0-flash",
    "openai": "gpt-4o-mini",
}


def get_ai_service() -> AIService | None:
    """Return a provider, or None when AI feedback is switched off.

    None is a first-class answer here: `ENABLE_AI_FEEDBACK=False` is the
    default, so the app runs with zero LLM cost unless someone opts in.
    """
    if not getattr(settings, "ENABLE_AI_FEEDBACK", False):
        return None

    provider = (getattr(settings, "AI_PROVIDER", "mock") or "mock").lower()
    api_key = getattr(settings, "AI_API_KEY", "")
    model = getattr(settings, "AI_MODEL", "") or DEFAULT_MODELS.get(provider, "")

    if provider == "gemini":
        return GeminiAIService(api_key=api_key, model=model)
    if provider == "openai":
        return OpenAIService(api_key=api_key, model=model)

    if provider != "mock":
        logger.warning(
            "Unknown AI_PROVIDER %r; falling back to the mock service.", provider
        )
    return MockAIService()
