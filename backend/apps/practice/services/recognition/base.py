"""The speech recognition boundary.

Business logic depends on `RecognitionResult`, never on whatever a specific
engine returns, for the same reason the old Azure boundary existed: an engine
change should touch one adapter, not the whole application.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class RecognitionResult:
    text: str

    # 0-100, or None if the engine exposes no such signal. Whisper has no
    # calibrated confidence score - this is derived from `avg_logprob`, a log
    # probability, not a true probability. Treat it as a rough proxy for "how
    # sure the model was", not a precise number.
    confidence: float | None
    language_code: str


class SpeechRecognitionService(ABC):
    """Transcribes a recording. Nothing more.

    Deliberately narrow: this stage only turns audio into text. Deciding
    whether that text represents good pronunciation is the pronunciation
    engine's job, not this one's - conflating them was the core problem with
    scoring directly off a transcript.
    """

    @abstractmethod
    def transcribe(self, *, audio, language_code) -> RecognitionResult:
        """Return what was heard.

        Raises `NoSpeechDetected` when the recording held nothing
        recognisable, and `AssessmentError` for any other failure.
        """
        raise NotImplementedError
