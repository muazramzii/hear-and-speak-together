"""Processing-time telemetry for the recognition + scoring pipeline.

Shared by the production evaluation flow (`evaluation.py`) and the developer
sandbox (`debug_views.py`), so both measure and log the same four numbers -
recording duration, Whisper inference time, phoneme analysis time, total
latency - the same way.

Logged at DEBUG level only, which the `apps` logger is configured to emit
only when `settings.DEBUG` is true (see `config/settings.py`'s `LOGGING`
block) - so on a production deployment (`DEBUG=False`) these calls are
simply dropped by the logging framework and nothing is written anywhere.
None of this is ever included in a response returned to a child.
"""

import logging
import wave

logger = logging.getLogger(__name__)


def recording_duration_seconds(audio_file):
    """Best-effort. A file that is not a well-formed WAV must degrade to
    `None`, not raise - this is a diagnostic number, not something anything
    is scored on."""
    try:
        audio_file.seek(0)
        with wave.open(audio_file, "rb") as wav_file:
            frames = wav_file.getnframes()
            rate = wav_file.getframerate()
            return round(frames / float(rate), 3) if rate else None
    except Exception:
        return None
    finally:
        audio_file.seek(0)


def log_processing_time(*, reference_text, performance):
    """`performance` is a dict with recording_duration_seconds,
    whisper_inference_ms, phoneme_analysis_ms and total_processing_ms."""
    logger.debug("Pronunciation processing time for %r: %s", reference_text, performance)
