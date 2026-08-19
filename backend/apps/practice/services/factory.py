"""Chooses the pronunciation assessment implementation.

Driven by `SPEECH_PROVIDER`, so switching between the real Azure service and
the mock is a configuration change rather than a code change - which is what
keeps the test suite free of paid API calls.
"""

import logging

from django.conf import settings

from .azure_service import AzurePronunciationAssessmentService
from .base import PronunciationAssessmentService
from .mock_service import MockPronunciationAssessmentService

logger = logging.getLogger(__name__)


def get_pronunciation_service() -> PronunciationAssessmentService:
    provider = (getattr(settings, "SPEECH_PROVIDER", "mock") or "mock").lower()

    if provider == "azure":
        return AzurePronunciationAssessmentService(
            speech_key=settings.AZURE_SPEECH_KEY,
            speech_region=settings.AZURE_SPEECH_REGION,
        )

    if provider != "mock":
        logger.warning(
            "Unknown SPEECH_PROVIDER %r; falling back to the mock service.",
            provider,
        )

    return MockPronunciationAssessmentService()
