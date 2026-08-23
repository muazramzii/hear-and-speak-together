"""The developer-only pronunciation sandbox.

Not part of the child-facing flow at all - it exists to let a developer feed
arbitrary words and recordings straight through the real recognition and
scoring pipeline and see every intermediate value, with nothing hidden. It is
gated on `is_staff`, never reachable by a learner account, and is a separate
code path from `EvaluatePracticeView` on purpose: the production endpoint
must stay lean and never grow debug-only branches for a real child's result.
"""

import logging
import time

from django.conf import settings
from rest_framework import serializers, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from .debug_models import PronunciationDebugAttempt
from .pronunciation_test_data import PRONUNCIATION_TEST_WORDS
from .services.base import AssessmentError, NoSpeechDetected
from .services.factory import get_recognition_service
from .services.pronunciation.debug import debug_evaluate
from .services.telemetry import log_processing_time, recording_duration_seconds

logger = logging.getLogger(__name__)

# Mirrors EvaluateRequestSerializer's cap - a short single-word clip is never
# anywhere near this size, so a bigger upload is either a mistake or not a
# recording of one word.
MAX_AUDIO_BYTES = 5 * 1024 * 1024

_SUPPORTED_LANGUAGES = {"en", "ms"}
_ALLOWED_AUDIO_EXTENSIONS = (".wav",)


class DebugEvaluateRequestSerializer(serializers.Serializer):
    """Validates a sandbox submission. Deliberately not scoped to a real
    `Word` or `Profile` - the sandbox is for testing arbitrary text, not
    only seeded lesson content."""

    reference = serializers.CharField(max_length=120)
    language = serializers.CharField(max_length=8)
    audio = serializers.FileField()

    def validate_reference(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("A reference word is required.")
        return cleaned

    def validate_language(self, value):
        code = value.strip().lower()
        if code not in _SUPPORTED_LANGUAGES:
            raise serializers.ValidationError(
                f"Unsupported language {value!r}. Use one of: "
                f"{', '.join(sorted(_SUPPORTED_LANGUAGES))}."
            )
        return code

    def validate_audio(self, value):
        if value.size == 0:
            raise serializers.ValidationError("The recording is empty.")
        if value.size > MAX_AUDIO_BYTES:
            raise serializers.ValidationError(
                "That recording is too long. Please record a single word."
            )
        name = (value.name or "").lower()
        if not name.endswith(_ALLOWED_AUDIO_EXTENSIONS):
            raise serializers.ValidationError(
                "Unsupported file format. Upload a 16kHz mono PCM .wav recording."
            )
        return value


class PronunciationDebugView(APIView):
    """POST /api/dev/pronunciation-debug/

    Multipart form data: `reference`, `language`, `audio`. Runs the real
    recognition service selected by `SPEECH_PROVIDER` (mock by default, the
    same as production) followed by the real, never-mocked pronunciation
    engine, and returns every raw and normalised value produced along the
    way.
    """

    permission_classes = [IsAdminUser]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = DebugEvaluateRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        reference = data["reference"]
        language = data["language"]
        audio_file = data["audio"]

        total_start = time.perf_counter()
        recording_duration = recording_duration_seconds(audio_file)

        recognizer = get_recognition_service()

        whisper_start = time.perf_counter()
        try:
            recognition = recognizer.transcribe(
                audio=audio_file, language_code=language
            )
        except NoSpeechDetected:
            recognition = None
        except AssessmentError as error:
            logger.error(
                "Sandbox recognition failed for reference=%r language=%s: %s",
                reference,
                language,
                error.detail,
            )
            return Response(
                {"detail": error.user_message},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        whisper_time_ms = round((time.perf_counter() - whisper_start) * 1000, 1)

        phoneme_start = time.perf_counter()
        debug_result = (
            debug_evaluate(
                reference_text=reference,
                recognized_text=recognition.text,
                confidence=recognition.confidence,
                language_code=language,
            )
            if recognition is not None
            else None
        )
        phoneme_time_ms = round((time.perf_counter() - phoneme_start) * 1000, 1)
        total_time_ms = round((time.perf_counter() - total_start) * 1000, 1)

        performance = {
            "recording_duration_seconds": recording_duration,
            "whisper_inference_ms": whisper_time_ms,
            "phoneme_analysis_ms": phoneme_time_ms,
            "total_processing_ms": total_time_ms,
        }
        log_processing_time(reference_text=reference, performance=performance)

        attempt = self._log_attempt(
            user=request.user,
            reference=reference,
            language=language,
            audio_file=audio_file,
            recognition=recognition,
            debug_result=debug_result,
            total_time_ms=total_time_ms,
        )

        return Response(
            self._build_response(
                reference=reference,
                language=language,
                recognition=recognition,
                debug_result=debug_result,
                performance=performance,
                attempt_id=attempt.pk,
            ),
            status=status.HTTP_200_OK,
        )

    def _build_response(
        self, *, reference, language, recognition, debug_result, performance, attempt_id
    ):
        heard_speech = recognition is not None

        response = {
            "attempt_id": attempt_id,
            "reference": reference,
            "recognized": recognition.text if heard_speech else "",
            "language": language,
            "heard_speech": heard_speech,
            "whisper": {
                "text": recognition.text if heard_speech else "",
                # 0-1, matching the scale a raw model confidence is normally
                # expressed in - the normalised 0-100 figure lives under
                # `assessment.confidence` instead.
                "confidence": (
                    round(recognition.confidence / 100, 4)
                    if heard_speech and recognition.confidence is not None
                    else None
                ),
                "language": language,
            },
            "performance": performance,
        }

        if debug_result is None:
            response["phoneme"] = None
            response["assessment"] = None
            return response

        response["phoneme"] = {
            "expected": " ".join(debug_result.reference_phonemes),
            "recognized": " ".join(debug_result.recognized_phonemes),
            "distance": debug_result.phoneme_edit_distance,
        }
        response["assessment"] = {
            "similarity": debug_result.similarity_score,
            "confidence": debug_result.confidence_score,
            "completeness": debug_result.completeness_score,
            "final_score": debug_result.pronunciation_score,
            "error_type": debug_result.top_error_type,
            # Everything the top-level `error_type` summarises, in full -
            # this screen exists precisely so nothing has to be inferred.
            "errors": [error.to_dict() for error in debug_result.errors],
        }
        return response

    def _log_attempt(
        self, *, user, reference, language, audio_file, recognition, debug_result, total_time_ms
    ):
        attempt = PronunciationDebugAttempt.objects.create(
            created_by=user if user.is_authenticated else None,
            reference_text=reference,
            recognized_text=recognition.text if recognition is not None else "",
            language_code=language,
            similarity_score=debug_result.similarity_score if debug_result else None,
            confidence_score=debug_result.confidence_score if debug_result else None,
            completeness_score=debug_result.completeness_score if debug_result else None,
            pronunciation_score=debug_result.pronunciation_score if debug_result else None,
            phoneme_distance=debug_result.phoneme_edit_distance if debug_result else None,
            errors=[e.to_dict() for e in debug_result.errors] if debug_result else [],
            # Telemetry is a development aid, not a durable record - stored
            # only when DEBUG is on, per Phase 2.5. Still returned in this
            # response either way, since the sandbox itself is only ever
            # reachable by a developer account.
            processing_time_ms=total_time_ms if settings.DEBUG else None,
        )

        if settings.STORE_AUDIO:
            try:
                audio_file.seek(0)
                attempt.audio.save(
                    f"{reference}-{attempt.pk}.wav", audio_file, save=True
                )
            except Exception:
                logger.exception(
                    "Could not store sandbox audio for attempt %s", attempt.pk
                )

        return attempt


class PronunciationTestWordsView(APIView):
    """GET /api/dev/pronunciation-test-words/

    The dataset used to validate scoring consistency (see
    `pronunciation_test_data.py`), exposed so the sandbox screen can offer it
    as a picker instead of the tester retyping the same words every time.
    """

    permission_classes = [IsAdminUser]

    def get(self, request):
        return Response(PRONUNCIATION_TEST_WORDS)
