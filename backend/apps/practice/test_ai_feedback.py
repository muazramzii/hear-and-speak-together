"""Phase 5 tests: the optional LLM feedback layer.

No test here makes a network call. The point of these is to prove that the
application keeps working when the provider does not.
"""

from unittest.mock import patch

import requests
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings

from apps.content.models import Category, Language, Lesson, Word
from apps.profiles.models import Profile

from .services.ai.base import FeedbackContext, build_prompt, is_usable
from .services.ai.factory import get_ai_service
from .services.ai.providers import (
    GeminiAIService,
    MockAIService,
    OpenAIService,
)
from .services import feedback as feedback_engine
from .services.evaluation import PracticeEvaluationService
from .services.recognition.mock_service import MockSpeechRecognitionService

User = get_user_model()


def context(score=82, language="en"):
    return FeedbackContext(
        target_word="elephant",
        language_code=language,
        locale="en-US" if language == "en" else "ms-MY",
        recognized_text="elepant",
        score=score,
        similarity_score=78,
        confidence_score=88,
        error_type="wrong_consonant",
    )


class PromptTests(TestCase):
    def test_prompt_names_the_target_language(self):
        self.assertIn("Bahasa Melayu", build_prompt(context(language="ms")))
        self.assertIn("English", build_prompt(context(language="en")))

    def test_prompt_forbids_stating_a_score(self):
        """The number on screen comes from the pronunciation engine. The
        model must not restate or contradict it."""
        self.assertIn("Never state a number", build_prompt(context()))

    def test_prompt_carries_no_personal_data(self):
        prompt = build_prompt(context())

        for leak in ("@", "email", "profile_id", "user"):
            self.assertNotIn(leak, prompt.lower())


class UsabilityTests(TestCase):
    def test_rejects_empty_and_whitespace(self):
        self.assertFalse(is_usable(""))
        self.assertFalse(is_usable(None))
        self.assertFalse(is_usable("  "))

    def test_rejects_an_essay(self):
        self.assertFalse(is_usable("word " * 200))

    def test_rejects_multi_paragraph_output(self):
        self.assertFalse(is_usable("Line one\nLine two\nLine three"))

    def test_accepts_a_normal_sentence(self):
        self.assertTrue(is_usable("Great job! Try the middle sound again."))


class FactoryTests(TestCase):
    @override_settings(ENABLE_AI_FEEDBACK=False)
    def test_returns_none_when_ai_feedback_is_disabled(self):
        """The default. No provider means no LLM call and no cost."""
        self.assertIsNone(get_ai_service())

    @override_settings(ENABLE_AI_FEEDBACK=True, AI_PROVIDER="mock")
    def test_mock_provider(self):
        self.assertIsInstance(get_ai_service(), MockAIService)

    @override_settings(
        ENABLE_AI_FEEDBACK=True, AI_PROVIDER="gemini", AI_API_KEY="k"
    )
    def test_gemini_provider(self):
        self.assertIsInstance(get_ai_service(), GeminiAIService)

    @override_settings(
        ENABLE_AI_FEEDBACK=True, AI_PROVIDER="openai", AI_API_KEY="k"
    )
    def test_openai_provider(self):
        self.assertIsInstance(get_ai_service(), OpenAIService)

    @override_settings(ENABLE_AI_FEEDBACK=True, AI_PROVIDER="nonsense")
    def test_unknown_provider_falls_back_to_mock(self):
        self.assertIsInstance(get_ai_service(), MockAIService)


class ProviderResilienceTests(TestCase):
    """Every provider failure must return None, never raise."""

    def test_gemini_without_a_key_returns_none(self):
        service = GeminiAIService(api_key="", model="gemini-2.0-flash")

        self.assertIsNone(service.generate_feedback(context()))

    def test_gemini_timeout_returns_none(self):
        service = GeminiAIService(api_key="k", model="gemini-2.0-flash")

        with patch(
            "requests.post", side_effect=requests.Timeout("timed out")
        ):
            self.assertIsNone(service.generate_feedback(context()))

    def test_gemini_unexpected_payload_returns_none(self):
        service = GeminiAIService(api_key="k", model="gemini-2.0-flash")

        with patch("requests.post") as post:
            post.return_value.raise_for_status.return_value = None
            post.return_value.json.return_value = {"unexpected": True}

            self.assertIsNone(service.generate_feedback(context()))

    def test_gemini_success_returns_the_sentence(self):
        service = GeminiAIService(api_key="k", model="gemini-2.0-flash")

        with patch("requests.post") as post:
            post.return_value.raise_for_status.return_value = None
            post.return_value.json.return_value = {
                "candidates": [
                    {
                        "content": {
                            "parts": [{"text": "  Nearly there! Try again.  "}]
                        }
                    }
                ]
            }

            self.assertEqual(
                service.generate_feedback(context()), "Nearly there! Try again."
            )

    def test_openai_http_error_returns_none(self):
        service = OpenAIService(api_key="k", model="gpt-4o-mini")

        with patch(
            "requests.post", side_effect=requests.HTTPError("429 Too Many Requests")
        ):
            self.assertIsNone(service.generate_feedback(context()))

    def test_openai_success_returns_the_sentence(self):
        service = OpenAIService(api_key="k", model="gpt-4o-mini")

        with patch("requests.post") as post:
            post.return_value.raise_for_status.return_value = None
            post.return_value.json.return_value = {
                "choices": [{"message": {"content": "Well done!"}}]
            }

            self.assertEqual(service.generate_feedback(context()), "Well done!")

    def test_an_unusable_response_is_discarded(self):
        service = OpenAIService(api_key="k", model="gpt-4o-mini")

        with patch("requests.post") as post:
            post.return_value.raise_for_status.return_value = None
            post.return_value.json.return_value = {
                "choices": [{"message": {"content": "x" * 5000}}]
            }

            self.assertIsNone(service.generate_feedback(context()))


class EvaluationWithAITests(TestCase):
    """The application must never depend on the LLM being available."""

    def setUp(self):
        self.language = Language.objects.create(
            code="en", name="English", locale="en-US"
        )
        category = Category.objects.create(
            language=self.language, slug="animals", name="Animals"
        )
        lesson = Lesson.objects.create(category=category, title="Animals")
        self.word = Word.objects.create(lesson=lesson, text="elephant")

        user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=user, name="Ali", practice_language=self.language
        )

    def audio(self):
        return SimpleUploadedFile("a.wav", b"\x00" * 2048, content_type="audio/wav")

    def evaluate(self, ai_service, **recognition_kwargs):
        recognition_kwargs.setdefault("text", "elephant")
        recognition_kwargs.setdefault("confidence", 90.0)
        service = PracticeEvaluationService(
            MockSpeechRecognitionService(**recognition_kwargs),
            ai_service=ai_service,
        )
        return service.evaluate(
            profile=self.profile, word=self.word, audio_file=self.audio()
        )

    def _deterministic_message_for(self, attempt):
        # Derived the same way the code derives it, rather than duplicating
        # band wording in the test - keeps this test from breaking every time
        # the copy is tweaked, while still proving the deterministic path ran.
        return feedback_engine.build_feedback(attempt.display_score, "en")

    def test_without_ai_the_deterministic_message_is_stored(self):
        attempt, _ = self.evaluate(None)

        self.assertEqual(attempt.feedback, self._deterministic_message_for(attempt))

    def test_ai_output_replaces_the_deterministic_message(self):
        attempt, _ = self.evaluate(
            MockAIService(response="So close! Try the middle sound again.")
        )

        self.assertEqual(attempt.feedback, "So close! Try the middle sound again.")

    def test_ai_failure_falls_back_without_failing_the_attempt(self):
        attempt, result = self.evaluate(MockAIService(fail=True))

        self.assertIsNotNone(result)
        self.assertEqual(attempt.feedback, self._deterministic_message_for(attempt))

    def test_an_ai_provider_that_raises_cannot_break_an_attempt(self):
        class Exploding(MockAIService):
            def generate_feedback(self, context):
                raise RuntimeError("provider exploded")

        attempt, result = self.evaluate(Exploding())

        self.assertIsNotNone(result)
        self.assertEqual(attempt.feedback, self._deterministic_message_for(attempt))

    def test_the_score_is_untouched_by_the_ai_layer(self):
        """The headline number comes from the pronunciation engine. The LLM
        only rewords."""
        without, _ = self.evaluate(None)
        with_ai, _ = self.evaluate(
            MockAIService(response="Completely different wording.")
        )

        self.assertEqual(without.display_score, with_ai.display_score)
        self.assertEqual(without.points_awarded, with_ai.points_awarded)

    def test_no_ai_call_is_made_when_nothing_was_heard(self):
        """There is nothing to encourage, so there is no reason to spend a
        request on it."""
        calls = []

        class Counting(MockAIService):
            def generate_feedback(self, context):
                calls.append(context)
                return "should not be used"

        service = PracticeEvaluationService(
            MockSpeechRecognitionService(simulate_no_speech=True),
            ai_service=Counting(),
        )
        service.evaluate(
            profile=self.profile, word=self.word, audio_file=self.audio()
        )

        self.assertEqual(calls, [])
