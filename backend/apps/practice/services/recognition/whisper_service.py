"""Self-hosted Whisper implementation of the recognition boundary.

Runs entirely on the Django server via `faster-whisper` (a CTranslate2
reimplementation of Whisper - same weights, meaningfully faster on CPU, and
installable on Windows with no native toolchain). No audio and no credential
ever leaves the machine.

Verified on this project's own hardware: loading a cached model and
transcribing one real spoken word took well under a second on CPU with the
`base` model. The **first** run is a different story - see `MODEL_SIZE`
below - because downloading a model from an unauthenticated Hugging Face Hub
connection was measured at over two hours for a 140 MB model. That is a
download-throughput problem, not a compute problem; once cached, it is fast.
"""

import logging
from functools import lru_cache

from django.conf import settings

from ..base import AssessmentError, NoSpeechDetected
from .base import RecognitionResult, SpeechRecognitionService
from .confidence import ConfidenceNormalizer

logger = logging.getLogger(__name__)

# A segment Whisper is this unsure is treated as silence rather than a weak
# guess - stops a hallucinated word from masquerading as a real attempt.
NO_SPEECH_THRESHOLD = 0.6


@lru_cache(maxsize=1)
def _load_model(model_size, device, compute_type):
    """Loaded once per process and cached.

    Loading is what pays the download cost on a cold cache; every request
    after the first reuses this instance rather than reloading from disk.
    """
    from faster_whisper import WhisperModel

    logger.info(
        "Loading Whisper model %s (device=%s, compute_type=%s)...",
        model_size,
        device,
        compute_type,
    )
    return WhisperModel(model_size, device=device, compute_type=compute_type)


class WhisperSpeechRecognitionService(SpeechRecognitionService):
    def __init__(self, *, model_size=None, device=None, compute_type=None):
        self._model_size = model_size or getattr(
            settings, "WHISPER_MODEL_SIZE", "base"
        )
        self._device = device or getattr(settings, "WHISPER_DEVICE", "cpu")
        self._compute_type = compute_type or getattr(
            settings, "WHISPER_COMPUTE_TYPE", "int8"
        )

    def transcribe(self, *, audio, language_code):
        try:
            model = _load_model(self._model_size, self._device, self._compute_type)
        except Exception as exc:
            raise AssessmentError(
                user_message="Speech assessment is not available right now.",
                detail=f"Could not load Whisper model: {exc}",
                retryable=False,
            ) from exc

        try:
            audio.seek(0)
            segments, _ = model.transcribe(
                audio,
                language=language_code,
                # The target word is already known; Whisper is asked to
                # transcribe, not to guess whether English or Malay was
                # spoken.
                vad_filter=True,
                condition_on_previous_text=False,
            )
            segments = list(segments)
        except Exception as exc:
            raise AssessmentError(
                user_message="Speech assessment is temporarily unavailable. Please try again.",
                detail=f"Whisper transcription failed: {exc}",
            ) from exc

        usable = [
            segment
            for segment in segments
            if segment.text.strip() and segment.no_speech_prob < NO_SPEECH_THRESHOLD
        ]

        if not usable:
            raise NoSpeechDetected()

        text = " ".join(segment.text.strip() for segment in usable)
        confidence = ConfidenceNormalizer.normalize(
            segment.avg_logprob for segment in usable
        )

        return RecognitionResult(
            text=text, confidence=confidence, language_code=language_code
        )
