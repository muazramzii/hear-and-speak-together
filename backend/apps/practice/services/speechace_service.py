"""SpeechAce implementation of the pronunciation assessment boundary.

Added because Azure requires a subscription that was not obtainable, while
SpeechAce offers a free trial tier. It is a genuine acoustic assessor - it
scores the audio against the reference text and returns phoneme-level quality -
so it satisfies the same rule Azure does: the score comes from the sound, not
from comparing transcripts.

**It does not support Malay.** SpeechAce covers en-us, en-gb, fr-fr, fr-ca,
es-es and es-mx only, so `ms-MY` must be routed elsewhere. That is why the
provider is chosen per language rather than globally.

Verified against the v9 scoring API: POST to
`/api/scoring/text/v9/json` with the key as a query parameter, `text` and
`user_audio_file` as multipart form fields.
"""

import logging

import requests

from .base import (
    AssessmentError,
    NoSpeechDetected,
    PronunciationAssessmentResult,
    PronunciationAssessmentService,
    WordResult,
)

logger = logging.getLogger(__name__)

# Dialects SpeechAce accepts. Anything else must not be sent - the request
# would either be rejected or, worse, scored against the wrong language model.
SUPPORTED_DIALECTS = {"en-us", "en-gb", "fr-fr", "fr-ca", "es-es", "es-mx"}

DEFAULT_ENDPOINT = "https://api.speechace.co/api/scoring/text/v9/json"
DEFAULT_TIMEOUT = 30


class SpeechAceAssessmentService(PronunciationAssessmentService):
    def __init__(self, *, api_key, endpoint=DEFAULT_ENDPOINT, timeout=DEFAULT_TIMEOUT):
        if not api_key:
            raise AssessmentError(
                user_message="Speech assessment is not available right now.",
                detail="SPEECHACE_API_KEY is not configured",
                retryable=False,
            )
        self._api_key = api_key
        self._endpoint = endpoint
        self._timeout = timeout

    def assess(
        self, *, audio, reference_text, language_code, locale, enable_prosody
    ):
        dialect = self._dialect_for(locale)

        try:
            response = requests.post(
                self._endpoint,
                params={"key": self._api_key, "dialect": dialect},
                data={"text": reference_text},
                files={"user_audio_file": ("attempt.wav", audio, "audio/wav")},
                timeout=self._timeout,
            )
        except requests.Timeout as exc:
            raise AssessmentError(
                user_message="That took too long. Please try again.",
                detail=f"SpeechAce timeout: {exc}",
            ) from exc
        except requests.RequestException as exc:
            raise AssessmentError(
                user_message="Speech assessment is temporarily unavailable. Please try again.",
                detail=f"SpeechAce request failed: {exc}",
            ) from exc

        return self._normalise(
            response, reference_text, language_code, locale
        )

    # -- helpers ----------------------------------------------------------

    def _dialect_for(self, locale):
        dialect = (locale or "").lower()
        if dialect not in SUPPORTED_DIALECTS:
            # Refused rather than silently substituted: scoring Malay against
            # an English model would produce a confident, meaningless number.
            raise AssessmentError(
                user_message="Speaking practice is not available for this language yet.",
                detail=(
                    f"SpeechAce does not support {locale!r}; supported: "
                    f"{sorted(SUPPORTED_DIALECTS)}"
                ),
                retryable=False,
            )
        return dialect

    def _normalise(self, response, reference_text, language_code, locale):
        self._raise_for_status(response)

        try:
            payload = response.json()
        except ValueError as exc:
            raise AssessmentError(
                user_message="Speech assessment is temporarily unavailable. Please try again.",
                detail=f"SpeechAce returned non-JSON: {exc}",
            ) from exc

        if payload.get("status") == "error":
            raise AssessmentError(
                user_message="Speech assessment is temporarily unavailable. Please try again.",
                detail=f"SpeechAce error: {payload.get('short_message')}",
            )

        text_score = payload.get("text_score") or {}
        words = text_score.get("word_score_list") or []

        if not words:
            # No word was scored, which for scripted assessment means nothing
            # usable was heard.
            raise NoSpeechDetected()

        overall = (text_score.get("speechace_score") or {}).get("pronunciation")

        word_results = [
            WordResult(
                word=word.get("word", ""),
                accuracy_score=word.get("quality_score"),
                # SpeechAce has no direct equivalent of Azure's ErrorType, so
                # this is derived from the score rather than invented.
                error_type=self._error_type_for(word.get("quality_score")),
            )
            for word in words
        ]

        accuracy = self._mean(
            [w.accuracy_score for w in word_results if w.accuracy_score is not None]
        )

        return PronunciationAssessmentResult(
            language_code=language_code,
            locale=locale,
            reference_text=reference_text,
            # Scripted assessment scores against the reference, and SpeechAce
            # returns no separate transcript, so the words it scored are the
            # closest honest equivalent.
            recognized_text=" ".join(w.word for w in word_results),
            accuracy_score=accuracy,
            # SpeechAce's fluency and completeness apply to connected speech,
            # not single words, so they are left unmeasured rather than
            # filled with a number that means something different.
            fluency_score=None,
            completeness_score=None,
            pronunciation_score=overall if overall is not None else accuracy,
            # No prosody metric in this API. Null, never fabricated.
            prosody_score=None,
            error_type=word_results[0].error_type if word_results else None,
            words=word_results,
        )

    def _raise_for_status(self, response):
        if response.status_code == 200:
            return

        detail = f"SpeechAce HTTP {response.status_code}: {response.text[:200]}"
        logger.error(detail)

        if response.status_code in (401, 403):
            raise AssessmentError(
                user_message="Speech assessment is not available right now.",
                detail=detail,
                retryable=False,
            )
        if response.status_code == 429:
            raise AssessmentError(
                user_message="We are a bit busy right now. Please try again in a moment.",
                detail=detail,
            )
        raise AssessmentError(
            user_message="Speech assessment is temporarily unavailable. Please try again.",
            detail=detail,
        )

    @staticmethod
    def _error_type_for(quality_score):
        if quality_score is None:
            return None
        return None if quality_score >= 70 else "Mispronunciation"

    @staticmethod
    def _mean(values):
        return sum(values) / len(values) if values else None
