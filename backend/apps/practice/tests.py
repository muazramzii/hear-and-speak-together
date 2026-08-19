"""Phase 4 tests: pronunciation assessment, feedback and the practice API.

Nothing here touches Azure. The assessment boundary is exercised through the
mock implementation, so the suite runs offline, needs no key, and costs
nothing.
"""

import io

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework.test import APITestCase

from apps.content.models import Category, Language, Lesson, Word
from apps.profiles.models import Profile

from .models import PracticeAttempt
from .services import feedback as feedback_engine
from .services.base import (
    AssessmentError,
    NoSpeechDetected,
    PronunciationAssessmentResult,
)
from .services.evaluation import PracticeEvaluationService
from .services.factory import get_pronunciation_service
from .services.mock_service import MockPronunciationAssessmentService

User = get_user_model()


def make_world(*, code="en", locale="en-US", prosody=True):
    language = Language.objects.create(
        code=code,
        name=code.upper(),
        locale=locale,
        supports_pronunciation_assessment=True,
        supports_prosody=prosody,
    )
    category = Category.objects.create(
        language=language, slug="animals", name="Animals"
    )
    lesson = Lesson.objects.create(category=category, title="Animals")
    word = Word.objects.create(lesson=lesson, text="elephant")
    return language, word


def audio(size=2048):
    return SimpleUploadedFile("a.wav", b"\x00" * size, content_type="audio/wav")


class AssessmentResultTests(TestCase):
    def test_display_score_prefers_azures_composite(self):
        result = PronunciationAssessmentResult(
            language_code="en",
            locale="en-US",
            reference_text="cat",
            recognized_text="cat",
            accuracy_score=70,
            pronunciation_score=82,
        )

        self.assertEqual(result.display_score, 82)

    def test_display_score_falls_back_to_accuracy(self):
        result = PronunciationAssessmentResult(
            language_code="en",
            locale="en-US",
            reference_text="cat",
            recognized_text="cat",
            accuracy_score=70,
        )

        self.assertEqual(result.display_score, 70)

    def test_measured_metrics_omits_unmeasured_ones(self):
        result = PronunciationAssessmentResult(
            language_code="ms",
            locale="ms-MY",
            reference_text="kucing",
            recognized_text="kucing",
            accuracy_score=80,
            fluency_score=85,
            prosody_score=None,
        )

        self.assertIn("accuracy", result.measured_metrics)
        self.assertNotIn("prosody", result.measured_metrics)


class MockServiceTests(TestCase):
    def test_returns_prosody_only_when_the_locale_supports_it(self):
        service = MockPronunciationAssessmentService(forced_score=88)

        english = service.assess(
            audio=io.BytesIO(b"x"),
            reference_text="elephant",
            language_code="en",
            locale="en-US",
            enable_prosody=True,
        )
        malay = service.assess(
            audio=io.BytesIO(b"x"),
            reference_text="gajah",
            language_code="ms",
            locale="ms-MY",
            enable_prosody=False,
        )

        self.assertIsNotNone(english.prosody_score)
        self.assertIsNone(malay.prosody_score)

    def test_scores_are_deterministic_for_the_same_word(self):
        service = MockPronunciationAssessmentService()
        kwargs = dict(
            reference_text="elephant",
            language_code="en",
            locale="en-US",
            enable_prosody=False,
        )

        first = service.assess(audio=io.BytesIO(b"x"), **kwargs)
        second = service.assess(audio=io.BytesIO(b"x"), **kwargs)

        self.assertEqual(first.accuracy_score, second.accuracy_score)

    def test_can_simulate_silence(self):
        service = MockPronunciationAssessmentService(simulate_no_speech=True)

        with self.assertRaises(NoSpeechDetected):
            service.assess(
                audio=io.BytesIO(b"x"),
                reference_text="cat",
                language_code="en",
                locale="en-US",
                enable_prosody=False,
            )


class FactoryTests(TestCase):
    @override_settings(SPEECH_PROVIDER="mock")
    def test_defaults_to_the_mock_service(self):
        self.assertIsInstance(
            get_pronunciation_service(), MockPronunciationAssessmentService
        )

    @override_settings(SPEECH_PROVIDER="nonsense")
    def test_unknown_provider_falls_back_to_mock_rather_than_crashing(self):
        self.assertIsInstance(
            get_pronunciation_service(), MockPronunciationAssessmentService
        )

    @override_settings(
        SPEECH_PROVIDER="azure", AZURE_SPEECH_KEY="", AZURE_SPEECH_REGION=""
    )
    def test_azure_without_credentials_fails_loudly(self):
        with self.assertRaises(AssessmentError):
            get_pronunciation_service()


class FeedbackTests(TestCase):
    def _result(self, score, *, language="en", prosody=None):
        return PronunciationAssessmentResult(
            language_code=language,
            locale="en-US" if language == "en" else "ms-MY",
            reference_text="elephant",
            recognized_text="elephant",
            accuracy_score=score,
            fluency_score=score,
            completeness_score=100,
            pronunciation_score=score,
            prosody_score=prosody,
        )

    def test_bands_map_to_the_right_message(self):
        self.assertIn("Excellent", feedback_engine.build_feedback(self._result(95)))
        self.assertIn("Good job", feedback_engine.build_feedback(self._result(80)))
        self.assertIn("Nice try", feedback_engine.build_feedback(self._result(60)))
        self.assertIn(
            "Keep practising", feedback_engine.build_feedback(self._result(30))
        )

    def test_feedback_is_written_in_the_practice_language(self):
        malay = feedback_engine.build_feedback(self._result(95, language="ms"))

        self.assertIn("Cemerlang", malay)

    def test_tips_never_mention_a_metric_that_was_not_measured(self):
        """The design mock shows an intonation row; Azure does not measure
        prosody for ms-MY, so that row must not appear."""
        tips = feedback_engine.build_tips(
            self._result(90, language="ms", prosody=None)
        )

        metrics = [tip["metric"] for tip in tips]
        self.assertNotIn("prosody", metrics)
        self.assertIn("accuracy", metrics)

    def test_tips_include_prosody_where_it_is_measured(self):
        tips = feedback_engine.build_tips(self._result(90, prosody=92))

        self.assertIn("prosody", [tip["metric"] for tip in tips])

    def test_tips_carry_a_tone_so_meaning_survives_without_colour(self):
        tips = feedback_engine.build_tips(self._result(40))

        self.assertTrue(all(tip["tone"] in {"positive", "suggestion"} for tip in tips))
        self.assertTrue(any(tip["tone"] == "suggestion" for tip in tips))

    def test_points_reward_effort_even_on_a_poor_attempt(self):
        self.assertEqual(feedback_engine.points_for_score(95), 10)
        self.assertEqual(feedback_engine.points_for_score(80), 7)
        self.assertEqual(feedback_engine.points_for_score(60), 4)
        self.assertEqual(feedback_engine.points_for_score(10), 2)
        self.assertEqual(feedback_engine.points_for_score(None), 0)


class EvaluationServiceTests(TestCase):
    def setUp(self):
        self.language, self.word = make_world()
        self.user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )

    def _service(self, **kwargs):
        return PracticeEvaluationService(
            MockPronunciationAssessmentService(**kwargs)
        )

    def test_records_an_attempt_and_awards_points(self):
        attempt, result = self._service(forced_score=92).evaluate(
            profile=self.profile, word=self.word, audio_file=audio()
        )

        self.assertIsNotNone(result)
        self.assertEqual(attempt.display_score, 92)
        self.assertEqual(attempt.points_awarded, 10)

        self.profile.refresh_from_db()
        self.assertEqual(self.profile.points, 10)
        self.assertEqual(self.profile.streak_days, 1)

    def test_silence_still_records_an_attempt_but_no_points(self):
        attempt, result = self._service(simulate_no_speech=True).evaluate(
            profile=self.profile, word=self.word, audio_file=audio()
        )

        self.assertIsNone(result)
        self.assertEqual(attempt.points_awarded, 0)
        self.assertEqual(attempt.recognized_text, "")
        self.assertIn("could not hear", attempt.feedback.lower())

    def test_prosody_is_null_for_a_locale_without_support(self):
        malay, word = make_world(code="ms", locale="ms-MY", prosody=False)
        profile = Profile.objects.create(
            owner=self.user, name="Sofia", practice_language=malay
        )

        attempt, _ = self._service(forced_score=88).evaluate(
            profile=profile, word=word, audio_file=audio()
        )

        self.assertIsNone(attempt.prosody_score)
        self.assertIsNotNone(attempt.accuracy_score)

    def test_language_without_assessment_support_is_refused(self):
        self.language.supports_pronunciation_assessment = False
        self.language.save()

        with self.assertRaises(AssessmentError):
            self._service().evaluate(
                profile=self.profile, word=self.word, audio_file=audio()
            )

    @override_settings(STORE_AUDIO=False)
    def test_audio_is_not_stored_by_default(self):
        attempt, _ = self._service(forced_score=80).evaluate(
            profile=self.profile, word=self.word, audio_file=audio()
        )

        self.assertFalse(attempt.audio)

    def test_streak_does_not_double_count_within_one_day(self):
        service = self._service(forced_score=80)
        service.evaluate(
            profile=self.profile, word=self.word, audio_file=audio()
        )
        self.profile.refresh_from_db()
        service.evaluate(
            profile=self.profile, word=self.word, audio_file=audio()
        )

        self.profile.refresh_from_db()
        self.assertEqual(self.profile.streak_days, 1)


class EvaluateAPITests(APITestCase):
    def setUp(self):
        self.language, self.word = make_world()
        self.user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )
        self.authenticate(self.user)

    def authenticate(self, user):
        login = self.client.post(
            reverse("accounts:login"),
            {"email": user.email, "password": "TeaCup!2026"},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.json()['access']}"
        )

    def evaluate(self, **overrides):
        payload = {
            "word_id": self.word.id,
            "profile_id": self.profile.id,
            "audio": audio(),
        }
        payload.update(overrides)
        return self.client.post(
            "/api/practice/evaluate/", payload, format="multipart"
        )

    def test_requires_authentication(self):
        self.client.credentials()

        self.assertEqual(self.evaluate().status_code, 401)

    def test_successful_evaluation_returns_scores_and_feedback(self):
        response = self.evaluate()

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["reference_text"], "elephant")
        self.assertIsNotNone(body["score"])
        self.assertTrue(body["feedback"])
        self.assertTrue(body["heard_speech"])
        self.assertIn("available_metrics", body)

    def test_response_advertises_only_metrics_the_locale_supports(self):
        malay, word = make_world(code="ms", locale="ms-MY", prosody=False)
        profile = Profile.objects.create(
            owner=self.user, name="Sofia", practice_language=malay
        )

        body = self.evaluate(word_id=word.id, profile_id=profile.id).json()

        self.assertNotIn("prosody", body["available_metrics"])
        self.assertIsNone(body["scores"]["prosody"])
        self.assertNotIn(
            "prosody", [tip["metric"] for tip in body["tips"]]
        )

    def test_empty_recording_is_rejected_before_any_assessment(self):
        empty = SimpleUploadedFile("a.wav", b"", content_type="audio/wav")

        response = self.evaluate(audio=empty)

        self.assertEqual(response.status_code, 400)
        self.assertEqual(PracticeAttempt.objects.count(), 0)

    def test_oversized_recording_is_rejected(self):
        big = SimpleUploadedFile(
            "a.wav", b"\x00" * (6 * 1024 * 1024), content_type="audio/wav"
        )

        response = self.evaluate(audio=big)

        self.assertEqual(response.status_code, 400)

    def test_unknown_word_is_rejected(self):
        response = self.evaluate(word_id=999999)

        self.assertEqual(response.status_code, 400)

    def test_cannot_log_an_attempt_against_another_users_child(self):
        stranger = User.objects.create_user(
            email="other@example.com", name="Other", password="TeaCup!2026"
        )
        theirs = Profile.objects.create(
            owner=stranger, name="Hidden", practice_language=self.language
        )

        response = self.evaluate(profile_id=theirs.id)

        self.assertEqual(response.status_code, 400)
        self.assertFalse(PracticeAttempt.objects.filter(profile=theirs).exists())

    def test_profile_totals_come_back_for_the_ui(self):
        body = self.evaluate().json()

        self.assertEqual(body["profile"]["id"], self.profile.id)
        self.assertGreater(body["profile"]["points"], 0)
        self.assertEqual(body["profile"]["streak_days"], 1)


class AttemptHistoryTests(APITestCase):
    def setUp(self):
        self.language, self.word = make_world()
        self.user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.other = User.objects.create_user(
            email="o@example.com", name="O", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )
        self.their_profile = Profile.objects.create(
            owner=self.other, name="Hidden", practice_language=self.language
        )

        PracticeAttempt.objects.create(
            profile=self.profile,
            word=self.word,
            language_code="en",
            locale="en-US",
            reference_text="elephant",
            pronunciation_score=82,
        )
        PracticeAttempt.objects.create(
            profile=self.their_profile,
            word=self.word,
            language_code="en",
            locale="en-US",
            reference_text="elephant",
            pronunciation_score=99,
        )

        login = self.client.post(
            reverse("accounts:login"),
            {"email": self.user.email, "password": "TeaCup!2026"},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.json()['access']}"
        )

    def test_lists_only_own_childrens_attempts(self):
        body = self.client.get("/api/attempts/").json()

        scores = [item["score"] for item in body["results"]]
        self.assertEqual(scores, [82])

    def test_can_filter_by_profile(self):
        body = self.client.get(
            f"/api/attempts/?profile={self.profile.id}"
        ).json()

        self.assertEqual(body["count"], 1)

    def test_another_users_attempt_is_not_retrievable(self):
        theirs = PracticeAttempt.objects.get(profile=self.their_profile)

        response = self.client.get(f"/api/attempts/{theirs.id}/")

        self.assertEqual(response.status_code, 404)

    def test_requires_authentication(self):
        self.client.credentials()

        self.assertEqual(self.client.get("/api/attempts/").status_code, 401)
