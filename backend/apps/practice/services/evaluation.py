"""Orchestrates a practice attempt.

Kept out of the view so the whole flow can be tested without HTTP, and so the
view stays a thin translation layer between the request and this service.

The pipeline is recognition, then scoring, as two separate stages:

    audio -> SpeechRecognitionService -> transcript -> PronunciationEngine -> score

Whisper only ever answers "what did the model think was said"; the
pronunciation engine is the only thing that decides how well it was said.
Conflating the two - scoring directly off whatever a transcription service
returns - was the failure mode this split exists to avoid.
"""

import logging
import time

from django.conf import settings
from django.db import transaction

from apps.practice.models import PracticeAttempt

from . import feedback as feedback_engine
from .ai.base import FeedbackContext
from .base import AssessmentError, NoSpeechDetected
from .pronunciation.engine import PronunciationEngine
from .telemetry import log_processing_time, recording_duration_seconds

logger = logging.getLogger(__name__)

_SUPPORTED_LANGUAGES = {"en", "ms"}


class PracticeEvaluationService:
    def __init__(self, recognition_service, ai_service=None, engine=None):
        self._recognizer = recognition_service
        self._engine = engine or PronunciationEngine()
        # Optional by design. None means deterministic feedback only, which is
        # the default and costs nothing.
        self._ai = ai_service

    def evaluate(self, *, profile, word, audio_file):
        """Recognise a recording, score it, persist the attempt, and update
        the learner.

        Returns `(attempt, result)`. `result` is None when nothing
        intelligible was heard - that still produces a stored attempt,
        because "the child tried and we could not hear them" is real
        information for a parent.
        """
        language = word.lesson.category.language

        self._guard_language(language)

        total_start = time.perf_counter()
        duration = recording_duration_seconds(audio_file)

        whisper_start = time.perf_counter()
        try:
            recognition = self._recognizer.transcribe(
                audio=audio_file, language_code=language.code
            )
        except NoSpeechDetected:
            attempt = self._record_no_speech(profile, word, language)
            return attempt, None
        whisper_ms = round((time.perf_counter() - whisper_start) * 1000, 1)

        phoneme_start = time.perf_counter()
        result = self._engine.evaluate(
            reference_text=word.text,
            recognized_text=recognition.text,
            confidence=recognition.confidence,
            language_code=language.code,
        )
        phoneme_ms = round((time.perf_counter() - phoneme_start) * 1000, 1)
        total_ms = round((time.perf_counter() - total_start) * 1000, 1)

        # Development-only diagnostics - never returned to the client, never
        # stored on the attempt. See services/telemetry.py.
        log_processing_time(
            reference_text=word.text,
            performance={
                "recording_duration_seconds": duration,
                "whisper_inference_ms": whisper_ms,
                "phoneme_analysis_ms": phoneme_ms,
                "total_processing_ms": total_ms,
            },
        )

        # Deterministic feedback is always computed first, so an AI provider
        # that is slow, down or misconfigured simply leaves it in place.
        # Deliberately outside the write transaction below: a network call
        # must never hold a database lock open.
        feedback_text = feedback_engine.build_feedback(
            result.pronunciation_score, language.code
        )
        ai_text = self._ai_feedback(result, language)
        if ai_text:
            feedback_text = ai_text

        attempt = self._record(
            profile, word, language, result, audio_file, feedback_text
        )
        # Runs after the attempt is committed, so analytics can never roll it
        # back. The awards are attached for the response.
        attempt.newly_earned_achievements = self.update_progress_and_awards(
            profile, word
        )
        return attempt, result

    # -- internals --------------------------------------------------------

    def _guard_language(self, language):
        if language.code not in _SUPPORTED_LANGUAGES:
            raise AssessmentError(
                user_message="Speaking practice is not available for this language yet.",
                detail=(
                    f"No G2P/recognition support for language {language.code!r}"
                ),
                retryable=False,
            )

    def _ai_feedback(self, result, language):
        """Ask the LLM to rephrase the deterministic message.

        Returns None on every failure path, so the caller keeps the
        deterministic sentence. The LLM never sees or influences the score -
        it only receives the numbers the engine already produced.
        """
        if self._ai is None:
            return None

        try:
            return self._ai.generate_feedback(
                FeedbackContext(
                    target_word=result.reference_text,
                    language_code=result.language_code,
                    locale=language.locale,
                    recognized_text=result.recognized_text,
                    score=result.pronunciation_score,
                    similarity_score=result.similarity_score,
                    confidence_score=result.confidence_score,
                    error_type=(
                        result.errors[0].type if result.errors else None
                    ),
                )
            )
        except Exception:
            # A provider is not allowed to fail an attempt, so even an
            # unexpected exception degrades to the deterministic message.
            logger.exception("AI feedback raised; using deterministic feedback")
            return None

    @transaction.atomic
    def _record(self, profile, word, language, result, audio_file, feedback_text):
        points = feedback_engine.points_for_score(result.pronunciation_score)

        attempt = PracticeAttempt.objects.create(
            profile=profile,
            word=word,
            language_code=language.code,
            locale=language.locale,
            reference_text=result.reference_text,
            recognized_text=result.recognized_text,
            similarity_score=result.similarity_score,
            confidence_score=result.confidence_score,
            completeness_score=result.completeness_score,
            pronunciation_score=result.pronunciation_score,
            errors=[error.to_dict() for error in result.errors],
            feedback=feedback_text,
            points_awarded=points,
        )

        if settings.STORE_AUDIO and audio_file is not None:
            self._attach_audio(attempt, audio_file, word)

        self._reward(profile, points)
        return attempt

    @transaction.atomic
    def _record_no_speech(self, profile, word, language):
        return PracticeAttempt.objects.create(
            profile=profile,
            word=word,
            language_code=language.code,
            locale=language.locale,
            reference_text=word.text,
            recognized_text="",
            feedback=feedback_engine.no_speech_feedback(language.code),
            points_awarded=0,
        )

    def _attach_audio(self, attempt, audio_file, word):
        try:
            audio_file.seek(0)
            attempt.audio.save(
                f"{word.text}-{attempt.pk}.wav", audio_file, save=True
            )
        except Exception:
            # Losing the recording must never lose the score.
            logger.exception("Could not store audio for attempt %s", attempt.pk)

    def _reward(self, profile, points):
        profile.award_points(points)
        profile.register_practice()
        profile.save(
            update_fields=[
                "points",
                "level",
                "streak_days",
                "last_practised_on",
                "updated_at",
            ]
        )

    def update_progress_and_awards(self, profile, word):
        """Refresh lesson progress and award any newly earned achievements.

        Imported here rather than at module scope: `apps.progress` depends on
        `apps.practice` for attempt data, so a top-level import would make the
        two apps import each other.

        Failures are logged and swallowed. Analytics are a read-side
        convenience; losing them must never lose a child's score, which is
        already committed by this point.
        """
        from apps.progress.services import achievements, analytics

        try:
            analytics.update_lesson_progress(profile, word.lesson)
            return achievements.evaluate(profile)
        except Exception:
            logger.exception(
                "Could not update progress for profile=%s lesson=%s",
                profile.pk,
                word.lesson_id,
            )
            return []
