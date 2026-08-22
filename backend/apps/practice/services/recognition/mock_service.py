"""Deterministic stand-in for Whisper, used in every automated test.

Loading a real model is slow on a cold cache and unnecessary for testing
anything except the Whisper adapter itself - the rest of the pipeline only
needs *some* `RecognitionResult` to react to.
"""

from ..base import NoSpeechDetected
from .base import RecognitionResult, SpeechRecognitionService


class MockSpeechRecognitionService(SpeechRecognitionService):
    def __init__(self, *, text="elephant", confidence=90.0, simulate_no_speech=False):
        self._text = text
        self._confidence = confidence
        self._simulate_no_speech = simulate_no_speech

    def transcribe(self, *, audio, language_code):
        if self._simulate_no_speech:
            raise NoSpeechDetected()

        audio.read()  # mirrors the real service consuming the stream

        return RecognitionResult(
            text=self._text,
            confidence=self._confidence,
            language_code=language_code,
        )
