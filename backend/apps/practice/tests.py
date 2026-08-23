"""Practice tests: recognition, the pronunciation engine, feedback and the
practice API.

Nothing here loads a real Whisper model or downloads anything - the
recognition boundary is exercised through `MockSpeechRecognitionService`, so
the suite runs offline, needs no model download, and is fast. The
pronunciation engine itself is deterministic and is exercised directly: there
is nothing external about it to mock.
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
from .services.base import AssessmentError, NoSpeechDetected
from .services.evaluation import PracticeEvaluationService
from .services.factory import get_recognition_service
from .services.pronunciation.engine import PronunciationEngine
from .services.recognition.confidence import ConfidenceNormalizer
from .services.recognition.mock_service import MockSpeechRecognitionService
from .services.recognition.whisper_service import WhisperSpeechRecognitionService

User = get_user_model()


def make_world(*, code="en", locale="en-US"):
    language = Language.objects.create(code=code, name=code.upper(), locale=locale)
    category = Category.objects.create(
        language=language, slug="animals", name="Animals"
    )
    lesson = Lesson.objects.create(category=category, title="Animals")
    word = Word.objects.create(lesson=lesson, text="elephant")
    return language, word


def audio(size=2048):
    return SimpleUploadedFile("a.wav", b"\x00" * size, content_type="audio/wav")


class RecognitionMockTests(TestCase):
    def test_returns_the_configured_text_and_confidence(self):
        service = MockSpeechRecognitionService(text="cat", confidence=91.0)

        result = service.transcribe(audio=io.BytesIO(b"x"), language_code="en")

        self.assertEqual(result.text, "cat")
        self.assertEqual(result.confidence, 91.0)
        self.assertEqual(result.language_code, "en")

    def test_can_simulate_silence(self):
        service = MockSpeechRecognitionService(simulate_no_speech=True)

        with self.assertRaises(NoSpeechDetected):
            service.transcribe(audio=io.BytesIO(b"x"), language_code="en")


class ConfidenceNormalizerTests(TestCase):
    """Whisper's raw `avg_logprob` reads as "not very confident" on almost
    every real attempt (see the module docstring in confidence.py) unless
    it is rescaled. These tests pin the rescale's boundary behaviour rather
    than its exact numbers, so the bounds can be retuned later without
    rewriting the tests."""

    def test_empty_input_is_zero(self):
        self.assertEqual(ConfidenceNormalizer.normalize([]), 0.0)

    def test_the_lower_bound_maps_to_zero(self):
        from math import log

        raw = log(ConfidenceNormalizer.LOWER_BOUND)

        self.assertEqual(ConfidenceNormalizer.normalize([raw]), 0.0)

    def test_the_upper_bound_maps_to_one_hundred(self):
        from math import log

        raw = log(ConfidenceNormalizer.UPPER_BOUND)

        self.assertEqual(ConfidenceNormalizer.normalize([raw]), 100.0)

    def test_values_outside_the_band_clamp_rather_than_extrapolate(self):
        # A near-certain segment (avg_logprob close to 0) must not score
        # above 100, and a very unsure one must not go negative.
        self.assertEqual(ConfidenceNormalizer.normalize([0.0]), 100.0)
        self.assertEqual(ConfidenceNormalizer.normalize([-10.0]), 0.0)

    def test_multiple_segments_are_averaged(self):
        from math import log

        low = log(ConfidenceNormalizer.LOWER_BOUND)
        high = log(ConfidenceNormalizer.UPPER_BOUND)

        self.assertAlmostEqual(
            ConfidenceNormalizer.normalize([low, high]), 50.0, delta=0.5
        )

    def test_output_is_always_within_zero_to_one_hundred(self):
        for raw in (-50.0, -5.0, -1.0, -0.1, 0.0):
            score = ConfidenceNormalizer.normalize([raw])
            self.assertGreaterEqual(score, 0.0)
            self.assertLessEqual(score, 100.0)


class FactoryTests(TestCase):
    @override_settings(SPEECH_PROVIDER="mock")
    def test_defaults_to_the_mock_service(self):
        self.assertIsInstance(
            get_recognition_service(), MockSpeechRecognitionService
        )

    @override_settings(SPEECH_PROVIDER="nonsense")
    def test_unknown_provider_falls_back_to_mock_rather_than_crashing(self):
        self.assertIsInstance(
            get_recognition_service(), MockSpeechRecognitionService
        )

    @override_settings(SPEECH_PROVIDER="whisper")
    def test_whisper_provider_selects_the_real_service(self):
        # Does not load the model - that only happens on first `transcribe`.
        self.assertIsInstance(
            get_recognition_service(), WhisperSpeechRecognitionService
        )


class PronunciationEngineTests(TestCase):
    """The core of the new architecture: scoring derived from a phoneme-level
    comparison, not from the raw transcript."""

    def setUp(self):
        self.engine = PronunciationEngine()

    def test_an_exact_match_scores_at_the_top(self):
        result = self.engine.evaluate(
            reference_text="cat",
            recognized_text="cat",
            confidence=95.0,
            language_code="en",
        )

        self.assertEqual(result.similarity_score, 100.0)
        self.assertGreaterEqual(result.pronunciation_score, 90)
        self.assertEqual(result.errors, [])

    def test_a_wrong_consonant_is_penalised_and_classified(self):
        """The project's own worked example: bola said as bota."""
        result = self.engine.evaluate(
            reference_text="bola",
            recognized_text="bota",
            confidence=90.0,
            language_code="ms",
        )

        self.assertLess(result.similarity_score, 100.0)
        self.assertEqual(len(result.errors), 1)
        self.assertEqual(result.errors[0].type, "wrong_consonant")
        self.assertEqual(result.errors[0].expected, "l")
        self.assertEqual(result.errors[0].detected, "t")

    def test_a_dropped_final_sound_is_a_missing_ending(self):
        """gajah -> gaja: the final phoneme is genuinely absent, not
        substituted, and completeness should reflect the shorter output."""
        result = self.engine.evaluate(
            reference_text="gajah",
            recognized_text="gaja",
            confidence=88.0,
            language_code="ms",
        )

        self.assertEqual(result.errors[0].type, "missing_ending")
        self.assertLess(result.completeness_score, 100.0)

    def test_no_score_is_ever_fabricated_as_prosody(self):
        """There is no prosody field in this architecture at all - Whisper
        and a text-level phonetic comparison have no acoustic signal to
        derive it from."""
        result = self.engine.evaluate(
            reference_text="cat",
            recognized_text="cat",
            confidence=95.0,
            language_code="en",
        )

        self.assertFalse(hasattr(result, "prosody_score"))

    def test_completeness_is_capped_at_100_not_rewarded_for_padding(self):
        result = self.engine.evaluate(
            reference_text="cat",
            recognized_text="cat cat cat",
            confidence=90.0,
            language_code="en",
        )

        self.assertEqual(result.completeness_score, 100.0)

    def test_missing_confidence_is_treated_as_zero_not_as_an_error(self):
        result = self.engine.evaluate(
            reference_text="cat",
            recognized_text="cat",
            confidence=None,
            language_code="en",
        )

        self.assertEqual(result.confidence_score, 0.0)

    def test_an_unsupported_language_is_refused(self):
        with self.assertRaises(ValueError):
            self.engine.evaluate(
                reference_text="chat",
                recognized_text="chat",
                confidence=90.0,
                language_code="fr",
            )

    def test_weights_are_configurable_not_hardcoded(self):
        confidence_only = PronunciationEngine(
            weights={"similarity": 0.0, "confidence": 1.0, "completeness": 0.0}
        )

        result = confidence_only.evaluate(
            reference_text="cat",
            recognized_text="xyz",  # would score near zero on similarity
            confidence=100.0,
            language_code="en",
        )

        self.assertEqual(result.pronunciation_score, 100)


class FeedbackTests(TestCase):
    def test_bands_map_to_the_right_message(self):
        self.assertIn("Excellent", feedback_engine.build_feedback(95, "en"))
        self.assertIn("Great job", feedback_engine.build_feedback(80, "en"))
        self.assertIn("Nice try", feedback_engine.build_feedback(60, "en"))
        self.assertIn("practice", feedback_engine.build_feedback(30, "en"))

    def test_feedback_is_written_in_the_practice_language(self):
        self.assertIn("Cemerlang", feedback_engine.build_feedback(95, "ms"))

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

    def _service(self, **recognition_kwargs):
        return PracticeEvaluationService(
            MockSpeechRecognitionService(**recognition_kwargs)
        )

    def test_records_an_attempt_and_awards_points(self):
        attempt, result = self._service(
            text="elephant", confidence=95.0
        ).evaluate(profile=self.profile, word=self.word, audio_file=audio())

        self.assertIsNotNone(result)
        self.assertGreaterEqual(attempt.display_score, 90)
        self.assertEqual(attempt.points_awarded, 10)

        self.profile.refresh_from_db()
        self.assertGreater(self.profile.points, 0)
        self.assertEqual(self.profile.streak_days, 1)

    def test_a_mispronunciation_scores_lower_and_is_recorded(self):
        attempt, result = self._service(
            text="elepant", confidence=85.0
        ).evaluate(profile=self.profile, word=self.word, audio_file=audio())

        self.assertLess(attempt.display_score, 100)
        self.assertEqual(len(attempt.errors), 1)
        self.assertEqual(attempt.errors[0]["type"], "wrong_consonant")

    def test_silence_still_records_an_attempt_but_no_points(self):
        attempt, result = self._service(simulate_no_speech=True).evaluate(
            profile=self.profile, word=self.word, audio_file=audio()
        )

        self.assertIsNone(result)
        self.assertEqual(attempt.points_awarded, 0)
        self.assertEqual(attempt.recognized_text, "")
        self.assertIn("could not hear", attempt.feedback.lower())

    def test_an_unsupported_language_is_refused_before_any_recognition(self):
        french = Language.objects.create(code="fr", name="French", locale="fr-FR")
        category = Category.objects.create(
            language=french, slug="x", name="X"
        )
        lesson = Lesson.objects.create(category=category, title="X")
        word = Word.objects.create(lesson=lesson, text="chat")
        profile = Profile.objects.create(
            owner=self.user, name="Léa", practice_language=french
        )

        with self.assertRaises(AssessmentError):
            self._service().evaluate(
                profile=profile, word=word, audio_file=audio()
            )

    @override_settings(STORE_AUDIO=False)
    def test_audio_is_not_stored_by_default(self):
        attempt, _ = self._service(text="elephant").evaluate(
            profile=self.profile, word=self.word, audio_file=audio()
        )

        self.assertFalse(attempt.audio)

    def test_streak_does_not_double_count_within_one_day(self):
        service = self._service(text="elephant")
        service.evaluate(profile=self.profile, word=self.word, audio_file=audio())
        self.profile.refresh_from_db()
        service.evaluate(profile=self.profile, word=self.word, audio_file=audio())

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
        self.assertEqual(body["reference"], "elephant")
        self.assertIsNotNone(body["score"])
        self.assertIn("similarity", body)
        self.assertIn("confidence", body)
        self.assertIn("completeness", body)
        self.assertIn("errors", body)
        self.assertTrue(body["feedback"])
        self.assertTrue(body["heard_speech"])

    def test_empty_recording_is_rejected_before_any_recognition(self):
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
