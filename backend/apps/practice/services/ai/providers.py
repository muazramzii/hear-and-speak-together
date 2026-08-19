"""Concrete AI feedback providers.

Both talk plain HTTP rather than pulling in a vendor SDK: the request is a
single prompt, the SDKs are large, and keeping it to `requests` means the
application is not coupled to either vendor's release cycle.

Every failure path returns None. Nothing here may raise into the caller.
"""

import logging

import requests

from .base import AIService, FeedbackContext, build_prompt, is_usable

logger = logging.getLogger(__name__)

# Short on purpose. This call sits between a child finishing a word and seeing
# their score; a slow provider must be abandoned, not waited on.
DEFAULT_TIMEOUT_SECONDS = 4


class MockAIService(AIService):
    """Used in tests and by default in development.

    Automated tests must never call a paid API, and a fixed sentence makes
    assertions exact.
    """

    def __init__(self, *, response="Great effort! Keep practising that word.", fail=False):
        self._response = response
        self._fail = fail

    def generate_feedback(self, context):
        if self._fail:
            return None
        return self._response


class GeminiAIService(AIService):
    """Google Gemini via the Generative Language REST API."""

    ENDPOINT = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        "{model}:generateContent"
    )

    def __init__(self, *, api_key, model, timeout=DEFAULT_TIMEOUT_SECONDS):
        self._api_key = api_key
        self._model = model
        self._timeout = timeout

    def generate_feedback(self, context: FeedbackContext):
        if not self._api_key:
            logger.warning("Gemini feedback requested but AI_API_KEY is empty")
            return None

        try:
            response = requests.post(
                self.ENDPOINT.format(model=self._model),
                params={"key": self._api_key},
                json={
                    "contents": [
                        {"parts": [{"text": build_prompt(context)}]}
                    ],
                    "generationConfig": {
                        "temperature": 0.7,
                        "maxOutputTokens": 60,
                    },
                },
                timeout=self._timeout,
            )
            response.raise_for_status()
            payload = response.json()

            text = (
                payload["candidates"][0]["content"]["parts"][0]["text"]
            )
        except (requests.RequestException, KeyError, IndexError, ValueError) as exc:
            # Includes timeouts, quota errors, and a response shape we did not
            # expect. All of them mean: use the deterministic sentence.
            logger.warning("Gemini feedback unavailable: %s", exc)
            return None

        return text.strip() if is_usable(text) else None


class OpenAIService(AIService):
    """OpenAI via the Chat Completions REST API."""

    ENDPOINT = "https://api.openai.com/v1/chat/completions"

    def __init__(self, *, api_key, model, timeout=DEFAULT_TIMEOUT_SECONDS):
        self._api_key = api_key
        self._model = model
        self._timeout = timeout

    def generate_feedback(self, context: FeedbackContext):
        if not self._api_key:
            logger.warning("OpenAI feedback requested but AI_API_KEY is empty")
            return None

        try:
            response = requests.post(
                self.ENDPOINT,
                headers={"Authorization": f"Bearer {self._api_key}"},
                json={
                    "model": self._model,
                    "messages": [
                        {"role": "user", "content": build_prompt(context)}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 60,
                },
                timeout=self._timeout,
            )
            response.raise_for_status()
            payload = response.json()

            text = payload["choices"][0]["message"]["content"]
        except (requests.RequestException, KeyError, IndexError, ValueError) as exc:
            logger.warning("OpenAI feedback unavailable: %s", exc)
            return None

        return text.strip() if is_usable(text) else None
