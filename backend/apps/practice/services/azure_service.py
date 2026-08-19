"""Azure AI Speech implementation of the pronunciation assessment boundary.

This is the only module in the project that knows Azure exists. Everything
above it works with `PronunciationAssessmentResult`.

Verified against the Speech SDK's current API (azure-cognitiveservices-speech
1.51): `PronunciationAssessmentConfig(reference_text=..., grading_system=...,
granularity=..., enable_miscue=...)`, `enable_prosody_assessment()`, and
`apply_to(recognizer)` before `recognize_once()`.
"""

import logging
import os
import tempfile

from .base import (
    AssessmentError,
    NoSpeechDetected,
    PronunciationAssessmentResult,
    PronunciationAssessmentService,
    WordResult,
)

logger = logging.getLogger(__name__)


class AzurePronunciationAssessmentService(PronunciationAssessmentService):
    """Scripted assessment: the reference word is known in advance.

    Scripted is the right mode for vocabulary practice - it scores the child
    against the exact word being taught, rather than first guessing what they
    said and scoring that.
    """

    def __init__(self, *, speech_key, speech_region, timeout_seconds=20):
        if not speech_key or not speech_region:
            raise AssessmentError(
                user_message="Speech assessment is not available right now.",
                detail="AZURE_SPEECH_KEY or AZURE_SPEECH_REGION is not configured",
                retryable=False,
            )
        self._key = speech_key
        self._region = speech_region
        self._timeout_seconds = timeout_seconds

    def assess(
        self, *, audio, reference_text, language_code, locale, enable_prosody
    ):
        # Imported lazily so the rest of the app - and the whole test suite -
        # never needs the native Speech SDK loaded.
        import azure.cognitiveservices.speech as speechsdk

        path = self._spool_to_disk(audio)

        try:
            speech_config = speechsdk.SpeechConfig(
                subscription=self._key, region=self._region
            )
            speech_config.speech_recognition_language = locale

            pronunciation_config = speechsdk.PronunciationAssessmentConfig(
                reference_text=reference_text,
                grading_system=speechsdk.PronunciationAssessmentGradingSystem.HundredMark,
                granularity=speechsdk.PronunciationAssessmentGranularity.Phoneme,
                # Miscue detection compares against a longer script to spot
                # skipped or inserted words. For a single word it only adds
                # noise, so it stays off.
                enable_miscue=False,
            )

            # Only enabled where Azure documents support for it. Calling this
            # for an unsupported locale would either error or silently return
            # nothing - either way the app must not imply prosody was measured.
            if enable_prosody:
                pronunciation_config.enable_prosody_assessment()

            audio_config = speechsdk.audio.AudioConfig(filename=path)
            recognizer = speechsdk.SpeechRecognizer(
                speech_config=speech_config, audio_config=audio_config
            )
            pronunciation_config.apply_to(recognizer)

            result = recognizer.recognize_once()
            return self._normalise(
                speechsdk=speechsdk,
                result=result,
                reference_text=reference_text,
                language_code=language_code,
                locale=locale,
            )
        finally:
            self._cleanup(path)

    # -- helpers ----------------------------------------------------------

    def _spool_to_disk(self, audio):
        """The SDK's AudioConfig wants a filename, not a stream."""
        try:
            with tempfile.NamedTemporaryFile(
                suffix=".wav", delete=False
            ) as handle:
                for chunk in iter(lambda: audio.read(64 * 1024), b""):
                    handle.write(chunk)
                return handle.name
        except OSError as exc:
            raise AssessmentError(
                user_message="We could not process your recording. Please try again.",
                detail=f"Failed to spool audio to disk: {exc}",
            ) from exc

    def _cleanup(self, path):
        try:
            os.unlink(path)
        except OSError:
            logger.warning("Could not delete temporary audio file %s", path)

    def _normalise(self, *, speechsdk, result, reference_text, language_code, locale):
        reason = result.reason

        if reason == speechsdk.ResultReason.NoMatch:
            raise NoSpeechDetected()

        if reason == speechsdk.ResultReason.Canceled:
            self._raise_for_cancellation(speechsdk, result)

        if reason != speechsdk.ResultReason.RecognizedSpeech:
            raise AssessmentError(
                user_message="Speech assessment is temporarily unavailable. Please try again.",
                detail=f"Unexpected Azure result reason: {reason}",
            )

        try:
            assessment = speechsdk.PronunciationAssessmentResult(result)
        except Exception as exc:
            raise AssessmentError(
                user_message="Speech assessment is temporarily unavailable. Please try again.",
                detail=f"Malformed pronunciation assessment payload: {exc}",
            ) from exc

        words = [
            WordResult(
                word=word.word,
                accuracy_score=getattr(word, "accuracy_score", None),
                error_type=getattr(word, "error_type", None),
            )
            for word in (getattr(assessment, "words", None) or [])
        ]

        return PronunciationAssessmentResult(
            language_code=language_code,
            locale=locale,
            reference_text=reference_text,
            recognized_text=result.text or "",
            accuracy_score=getattr(assessment, "accuracy_score", None),
            fluency_score=getattr(assessment, "fluency_score", None),
            pronunciation_score=getattr(assessment, "pronunciation_score", None),
            completeness_score=getattr(assessment, "completeness_score", None),
            # Absent for locales without prosody support. Stays None rather
            # than becoming a fabricated number.
            prosody_score=getattr(assessment, "prosody_score", None),
            error_type=words[0].error_type if words else None,
            words=words,
        )

    def _raise_for_cancellation(self, speechsdk, result):
        """Turn Azure's cancellation detail into a child-safe message.

        The technical reason is logged, never returned - a child should not
        see "AuthenticationFailure".
        """
        details = result.cancellation_details
        reason = details.reason
        error_detail = details.error_details or ""

        logger.error(
            "Azure speech cancelled: reason=%s detail=%s", reason, error_detail
        )

        if reason == speechsdk.CancellationReason.Error:
            lowered = error_detail.lower()
            if "401" in lowered or "forbidden" in lowered or "authentication" in lowered:
                raise AssessmentError(
                    user_message="Speech assessment is not available right now.",
                    detail=f"Azure authentication failed: {error_detail}",
                    retryable=False,
                )
            if "429" in lowered or "quota" in lowered or "throttl" in lowered:
                raise AssessmentError(
                    user_message="We are a bit busy right now. Please try again in a moment.",
                    detail=f"Azure quota or throttling: {error_detail}",
                )
            if "timeout" in lowered or "timed out" in lowered:
                raise AssessmentError(
                    user_message="That took too long. Please try again.",
                    detail=f"Azure timeout: {error_detail}",
                )

        raise AssessmentError(
            user_message="Speech assessment is temporarily unavailable. Please try again.",
            detail=f"Azure cancelled: reason={reason} detail={error_detail}",
        )
