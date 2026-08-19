"""Orchestrates a practice attempt.

Kept out of the view so the whole flow can be tested without HTTP, and so the
view stays a thin translation layer between the request and this service.
"""

import logging

from django.conf import settings
from django.db import transaction

from apps.practice.models import PracticeAttempt

from . import feedback as feedback_engine
from .ai.base import FeedbackContext
from .base import AssessmentError, NoSpeechDetected

logger = logging.getLogger(__name__)


class PracticeEvaluationService:
    def __init__(self, assessment_service, ai_service=None):
        self._assessor = assessment_service
        # Optional by design. None means deterministic feedback only, which is
        # the default and costs nothing.
        self._ai = ai_service

    def evaluate(self, *, profile, word, audio_file):
        """Assess a recording, persist the attempt, and update the learner.

        Returns `(attempt, result)`. `result` is None when nothing intelligible
        was heard - that still produces a stored attempt, because "the child
        tried and we could not hear them" is real information for a parent.
        """
        language = word.lesson.category.language

        self._guard_language(language)

        try:
            result = self._assessor.assess(
                audio=audio_file,
                reference_text=word.text,
                language_code=language.code,
                locale=language.locale,
                # Decided from the verified capability flag, never guessed.
                enable_prosody=language.supports_prosody,
            )
        except NoSpeechDetected:
            attempt = self._record_no_speech(profile, word, language)
            return attempt, None

        # Deterministic feedback is always computed first, so an AI provider
        # that is slow, down or misconfigured simply leaves it in place.
        # Deliberately outside the write transaction below: a network call must
        # never hold a database lock open.
        feedback_text = feedback_engine.build_feedback(result)
        ai_text = self._ai_feedback(result)
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
        if not language.supports_pronunciation_assessment:
            raise AssessmentError(
                user_message="Speaking practice is not available for this language yet.",
                detail=(
                    f"Language {language.locale} is not marked as supporting "
                    f"pronunciation assessment"
                ),
                retryable=False,
            )

    def _ai_feedback(self, result):
        """Ask the LLM to rephrase the deterministic message.

        Returns None on every failure path, so the caller keeps the
        deterministic sentence. The LLM never sees or influences the score -
        it only receives the numbers Azure already produced.
        """
        if self._ai is None:
            return None

        score = result.display_score
        if score is None:
            return None  # nothing was heard; there is nothing to encourage

        try:
            return self._ai.generate_feedback(
                FeedbackContext(
                    target_word=result.reference_text,
                    language_code=result.language_code,
                    locale=result.locale,
                    recognized_text=result.recognized_text,
                    score=score,
                    accuracy_score=result.accuracy_score,
                    fluency_score=result.fluency_score,
                    error_type=result.error_type,
                )
            )
        except Exception:
            # A provider is not allowed to fail an attempt, so even an
            # unexpected exception degrades to the deterministic message.
            logger.exception("AI feedback raised; using deterministic feedback")
            return None

    @transaction.atomic
    def _record(self, profile, word, language, result, audio_file, feedback_text):
        score = result.display_score
        points = feedback_engine.points_for_score(score)

        attempt = PracticeAttempt.objects.create(
            profile=profile,
            word=word,
            language_code=language.code,
            locale=language.locale,
            reference_text=result.reference_text,
            recognized_text=result.recognized_text,
            accuracy_score=result.accuracy_score,
            fluency_score=result.fluency_score,
            pronunciation_score=result.pronunciation_score,
            completeness_score=result.completeness_score,
            # Stays None for locales without prosody support.
            prosody_score=result.prosody_score,
            error_type=result.error_type or "",
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
