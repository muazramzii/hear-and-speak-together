"""Chooses the speech recognition implementation.

Only recognition is swappable - the pronunciation engine that scores what
came back is deterministic and identical in every environment, so there is
nothing to select there. Defaults to the mock, so a fresh checkout and the
whole test suite run with no model download and no GPU/CPU cost.
"""

from django.conf import settings

from .recognition.base import SpeechRecognitionService
from .recognition.mock_service import MockSpeechRecognitionService
from .recognition.whisper_service import WhisperSpeechRecognitionService


def get_recognition_service() -> SpeechRecognitionService:
    provider = (getattr(settings, "SPEECH_PROVIDER", "mock") or "mock").lower()

    if provider == "whisper":
        return WhisperSpeechRecognitionService()

    return MockSpeechRecognitionService()
