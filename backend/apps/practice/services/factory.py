"""Chooses the pronunciation assessment implementation.

Selection is **per language**, because coverage genuinely differs between
providers: SpeechAce has no Malay, so `ms-MY` can only be served by Azure or
the mock. A single global provider would either break the Malay half of the
app or score it against the wrong language model.

A `Language` row may name its own provider; otherwise the `SPEECH_PROVIDER`
setting decides. Both default to the mock, so a fresh checkout costs nothing.
"""

import logging

from django.conf import settings

from .azure_service import AzurePronunciationAssessmentService
from .base import AssessmentError, PronunciationAssessmentService
from .mock_service import MockPronunciationAssessmentService
from .speechace_service import SpeechAceAssessmentService

logger = logging.getLogger(__name__)


def _build(provider) -> PronunciationAssessmentService:
    if provider == "azure":
        return AzurePronunciationAssessmentService(
            speech_key=settings.AZURE_SPEECH_KEY,
            speech_region=settings.AZURE_SPEECH_REGION,
        )

    if provider == "speechace":
        return SpeechAceAssessmentService(
            api_key=getattr(settings, "SPEECHACE_API_KEY", "")
        )

    if provider != "mock":
        logger.warning(
            "Unknown speech provider %r; falling back to the mock service.",
            provider,
        )

    return MockPronunciationAssessmentService()


def get_pronunciation_service(language=None) -> PronunciationAssessmentService:
    """Return the assessor for `language`, or the configured default.

    Falling back to the mock on a misconfiguration is deliberate: a child
    getting a mock score is a much smaller failure than the practice screen
    erroring out, and the server log records what happened.
    """
    configured = (getattr(settings, "SPEECH_PROVIDER", "mock") or "mock").lower()

    provider = configured
    if language is not None:
        per_language = (getattr(language, "assessment_provider", "") or "").lower()
        if per_language and per_language != "default":
            provider = per_language

    try:
        return _build(provider)
    except AssessmentError:
        # Raised when a provider is selected but its credentials are absent.
        # Re-raised only if it was an explicit choice, so a half-configured
        # deployment fails loudly rather than silently scoring with a mock.
        raise
