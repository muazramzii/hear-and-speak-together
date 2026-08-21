"""Tests for the SpeechAce assessor and per-language provider selection.

No test makes a network call; `requests.post` is patched throughout.
"""

import io
from unittest.mock import patch

import requests
from django.test import TestCase, override_settings

from apps.content.models import Language

from .services.azure_service import AzurePronunciationAssessmentService
from .services.base import AssessmentError, NoSpeechDetected
from .services.factory import get_pronunciation_service
from .services.mock_service import MockPronunciationAssessmentService
from .services.speechace_service import (
    SUPPORTED_DIALECTS,
    SpeechAceAssessmentService,
)


def scored_payload(quality=88, overall=90):
    return {
        "status": "success",
        "text_score": {
            "speechace_score": {"pronunciation": overall},
            "word_score_list": [
                {"word": "elephant", "quality_score": quality}
            ],
        },
    }


def fake_response(status_code=200, payload=None, text=""):
    class _Response:
        def __init__(self):
            self.status_code = status_code
            self.text = text

        def json(self):
            if payload is None:
                raise ValueError("no json")
            return payload

    return _Response()


def service():
    return SpeechAceAssessmentService(api_key="fake-key")


def assess(svc, *, locale="en-US", language_code="en"):
    return svc.assess(
        audio=io.BytesIO(b"\x00" * 1024),
        reference_text="elephant",
        language_code=language_code,
        locale=locale,
        enable_prosody=False,
    )


class ConfigurationTests(TestCase):
    def test_a_missing_key_fails_loudly(self):
        with self.assertRaises(AssessmentError):
            SpeechAceAssessmentService(api_key="")


class DialectTests(TestCase):
    def test_malay_is_refused_rather_than_scored_against_english(self):
        """Scoring Malay with an English model would return a confident,
        meaningless number - far worse than refusing."""
        with self.assertRaises(AssessmentError) as caught:
            assess(service(), locale="ms-MY", language_code="ms")

        self.assertIn("does not support", caught.exception.detail)
        self.assertFalse(caught.exception.retryable)

    def test_no_request_is_made_for_an_unsupported_dialect(self):
        with patch("requests.post") as post:
            with self.assertRaises(AssessmentError):
                assess(service(), locale="ms-MY", language_code="ms")

        post.assert_not_called()

    def test_supported_dialects_are_accepted(self):
        for dialect in SUPPORTED_DIALECTS:
            with patch("requests.post") as post:
                post.return_value = fake_response(payload=scored_payload())
                result = assess(service(), locale=dialect)

            self.assertIsNotNone(result.pronunciation_score)

    def test_malay_is_not_in_the_supported_set(self):
        self.assertNotIn("ms-my", SUPPORTED_DIALECTS)


class ScoringTests(TestCase):
    def test_maps_the_overall_score(self):
        with patch("requests.post") as post:
            post.return_value = fake_response(
                payload=scored_payload(quality=80, overall=85)
            )
            result = assess(service())

        self.assertEqual(result.pronunciation_score, 85)
        self.assertEqual(result.accuracy_score, 80)

    def test_never_invents_metrics_this_api_does_not_return(self):
        """Fluency and completeness describe connected speech, and there is no
        prosody metric at all - so all three stay null rather than being
        filled with a number that means something else."""
        with patch("requests.post") as post:
            post.return_value = fake_response(payload=scored_payload())
            result = assess(service())

        self.assertIsNone(result.fluency_score)
        self.assertIsNone(result.completeness_score)
        self.assertIsNone(result.prosody_score)

    def test_a_low_score_is_marked_as_a_mispronunciation(self):
        with patch("requests.post") as post:
            post.return_value = fake_response(
                payload=scored_payload(quality=40, overall=42)
            )
            result = assess(service())

        self.assertEqual(result.error_type, "Mispronunciation")

    def test_an_empty_word_list_means_nothing_was_heard(self):
        with patch("requests.post") as post:
            post.return_value = fake_response(
                payload={"text_score": {"word_score_list": []}}
            )

            with self.assertRaises(NoSpeechDetected):
                assess(service())

    def test_the_key_is_sent_as_a_query_parameter(self):
        with patch("requests.post") as post:
            post.return_value = fake_response(payload=scored_payload())
            assess(service())

        self.assertEqual(post.call_args.kwargs["params"]["key"], "fake-key")
        self.assertEqual(post.call_args.kwargs["params"]["dialect"], "en-us")


class FailureTests(TestCase):
    def _expect_error(self, **response_kwargs):
        with patch("requests.post") as post:
            post.return_value = fake_response(**response_kwargs)
            with self.assertRaises(AssessmentError) as caught:
                assess(service())
        return caught.exception

    def test_a_bad_key_is_not_retryable(self):
        error = self._expect_error(status_code=401, text="unauthorized")

        self.assertFalse(error.retryable)

    def test_rate_limiting_is_retryable(self):
        error = self._expect_error(status_code=429, text="slow down")

        self.assertTrue(error.retryable)

    def test_a_timeout_is_reported_as_such(self):
        with patch("requests.post", side_effect=requests.Timeout("slow")):
            with self.assertRaises(AssessmentError) as caught:
                assess(service())

        self.assertIn("too long", caught.exception.user_message)

    def test_non_json_is_handled(self):
        error = self._expect_error(status_code=200, payload=None)

        self.assertIn("non-JSON", error.detail)

    def test_technical_detail_never_reaches_the_child(self):
        error = self._expect_error(status_code=500, text="stack trace here")

        self.assertNotIn("stack trace", error.user_message)


class PerLanguageSelectionTests(TestCase):
    """The reason selection is per language at all."""

    def setUp(self):
        self.english = Language.objects.create(
            code="en", name="English", locale="en-US"
        )
        self.malay = Language.objects.create(
            code="ms", name="Bahasa Melayu", locale="ms-MY"
        )

    @override_settings(SPEECH_PROVIDER="mock", SPEECHACE_API_KEY="k")
    def test_a_language_can_override_the_global_provider(self):
        self.english.assessment_provider = "speechace"
        self.english.save()

        self.assertIsInstance(
            get_pronunciation_service(self.english), SpeechAceAssessmentService
        )

    @override_settings(SPEECH_PROVIDER="mock", SPEECHACE_API_KEY="k")
    def test_malay_can_stay_on_the_mock_while_english_uses_speechace(self):
        """The whole point: no single provider covers both languages."""
        self.english.assessment_provider = "speechace"
        self.english.save()
        self.malay.assessment_provider = "mock"
        self.malay.save()

        self.assertIsInstance(
            get_pronunciation_service(self.english), SpeechAceAssessmentService
        )
        self.assertIsInstance(
            get_pronunciation_service(self.malay),
            MockPronunciationAssessmentService,
        )

    @override_settings(
        SPEECH_PROVIDER="mock",
        AZURE_SPEECH_KEY="k",
        AZURE_SPEECH_REGION="eastus",
    )
    def test_malay_can_use_azure_while_english_uses_something_else(self):
        self.malay.assessment_provider = "azure"
        self.malay.save()

        self.assertIsInstance(
            get_pronunciation_service(self.malay),
            AzurePronunciationAssessmentService,
        )

    @override_settings(SPEECH_PROVIDER="mock")
    def test_default_falls_back_to_the_global_setting(self):
        self.assertIsInstance(
            get_pronunciation_service(self.english),
            MockPronunciationAssessmentService,
        )

    @override_settings(SPEECH_PROVIDER="mock")
    def test_no_language_still_works(self):
        self.assertIsInstance(
            get_pronunciation_service(), MockPronunciationAssessmentService
        )

    @override_settings(SPEECH_PROVIDER="mock", SPEECHACE_API_KEY="")
    def test_selecting_speechace_without_a_key_fails_loudly(self):
        """A half-configured deployment should not silently score with a mock
        while the admin believes real assessment is running."""
        self.english.assessment_provider = "speechace"
        self.english.save()

        with self.assertRaises(AssessmentError):
            get_pronunciation_service(self.english)
