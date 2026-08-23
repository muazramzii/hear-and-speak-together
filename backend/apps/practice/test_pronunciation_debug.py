"""Phase 2 tests: the developer-only pronunciation sandbox.

No test here loads a real Whisper model or calls a network service - the
recognition service is always mocked, exactly like every other automated
test in this project. The point of these tests is to validate the *engine*
(scoring and error classification), and that the sandbox endpoint is
reachable only by a developer account, never by a child's.
"""

from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from rest_framework.test import APITestCase

from .pronunciation_test_data import PRONUNCIATION_TEST_WORDS
from .services.pronunciation.debug import debug_evaluate
from .services.recognition.mock_service import MockSpeechRecognitionService

User = get_user_model()


def audio_file(name="attempt.wav"):
    return SimpleUploadedFile(name, b"\x00" * 2048, content_type="audio/wav")


class PronunciationDebugAPITests(APITestCase):
    def setUp(self):
        self.staff = User.objects.create_user(
            email="dev@example.com", name="Dev", password="TeaCup!2026", is_staff=True
        )
        self.student = User.objects.create_user(
            email="kid@example.com", name="Kid", password="TeaCup!2026"
        )

    def submit(self, *, reference, language, mock=None, filename="attempt.wav"):
        mock = mock or MockSpeechRecognitionService(text=reference, confidence=95.0)
        self.client.force_authenticate(user=self.staff)
        with patch(
            "apps.practice.debug_views.get_recognition_service", return_value=mock
        ):
            return self.client.post(
                "/api/dev/pronunciation-debug/",
                {
                    "reference": reference,
                    "language": language,
                    "audio": audio_file(filename),
                },
                format="multipart",
            )

    # -- access control -----------------------------------------------------

    def test_anonymous_is_rejected(self):
        response = self.client.post(
            "/api/dev/pronunciation-debug/",
            {"reference": "bola", "language": "ms", "audio": audio_file()},
            format="multipart",
        )

        self.assertEqual(response.status_code, 401)

    def test_a_non_staff_account_cannot_reach_the_sandbox(self):
        self.client.force_authenticate(user=self.student)

        response = self.client.post(
            "/api/dev/pronunciation-debug/",
            {"reference": "bola", "language": "ms", "audio": audio_file()},
            format="multipart",
        )

        self.assertEqual(response.status_code, 403)

    # -- correct pronunciation ----------------------------------------------

    def test_english_pronunciation_is_scored_and_reported_in_full(self):
        response = self.submit(reference="elephant", language="en")

        self.assertEqual(response.status_code, 200)
        body = response.json()

        self.assertEqual(body["reference"], "elephant")
        self.assertEqual(body["recognized"], "elephant")
        self.assertTrue(body["heard_speech"])
        self.assertEqual(body["whisper"]["text"], "elephant")
        self.assertAlmostEqual(body["whisper"]["confidence"], 0.95, places=3)
        self.assertGreaterEqual(body["assessment"]["final_score"], 85)
        self.assertIsNone(body["assessment"]["error_type"])
        self.assertEqual(body["assessment"]["errors"], [])
        self.assertTrue(body["phoneme"]["expected"])
        self.assertEqual(body["phoneme"]["distance"], 0)

    def test_malay_pronunciation_is_scored_and_reported_in_full(self):
        response = self.submit(reference="bola", language="ms")

        self.assertEqual(response.status_code, 200)
        body = response.json()

        self.assertGreaterEqual(body["assessment"]["final_score"], 85)
        self.assertEqual(body["phoneme"]["distance"], 0)

    # -- performance logging --------------------------------------------------

    def test_performance_breakdown_is_returned(self):
        response = self.submit(reference="bola", language="ms")

        performance = response.json()["performance"]
        for key in (
            "recording_duration_seconds",
            "whisper_inference_ms",
            "phoneme_analysis_ms",
            "total_processing_ms",
        ):
            self.assertIn(key, performance)

    # -- error classification -------------------------------------------------

    def test_a_missing_consonant_is_detected(self):
        # "kucing" -> "ucing": the leading /k/ is dropped entirely.
        response = self.submit(
            reference="kucing",
            language="ms",
            mock=MockSpeechRecognitionService(text="ucing", confidence=90.0),
        )

        errors = response.json()["assessment"]["errors"]
        self.assertTrue(errors)
        self.assertEqual(errors[0]["type"], "missing_phoneme")
        self.assertEqual(errors[0]["expected"], "k")

    def test_a_missing_ending_is_detected(self):
        # "gajah" -> "gaja": the trailing /h/ is dropped.
        response = self.submit(
            reference="gajah",
            language="ms",
            mock=MockSpeechRecognitionService(text="gaja", confidence=90.0),
        )

        errors = response.json()["assessment"]["errors"]
        self.assertTrue(errors)
        self.assertEqual(errors[0]["type"], "missing_ending")
        self.assertEqual(errors[0]["expected"], "h")

    def test_a_wrong_vowel_is_detected(self):
        # "pensel" -> "punsel": the second phoneme (schwa) becomes /u/.
        response = self.submit(
            reference="pensel",
            language="ms",
            mock=MockSpeechRecognitionService(text="punsel", confidence=90.0),
        )

        errors = response.json()["assessment"]["errors"]
        self.assertTrue(errors)
        self.assertEqual(errors[0]["type"], "wrong_vowel")

    # -- edge cases -------------------------------------------------------

    def test_empty_audio_is_a_valid_result_not_an_error(self):
        response = self.submit(
            reference="bola",
            language="ms",
            mock=MockSpeechRecognitionService(simulate_no_speech=True),
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertFalse(body["heard_speech"])
        self.assertEqual(body["recognized"], "")
        self.assertIsNone(body["phoneme"])
        self.assertIsNone(body["assessment"])

    def test_an_invalid_language_is_rejected(self):
        response = self.submit(reference="bonjour", language="fr")

        self.assertEqual(response.status_code, 400)
        self.assertIn("language", response.json())

    def test_an_unsupported_file_format_is_rejected(self):
        response = self.submit(
            reference="bola", language="ms", filename="attempt.mp3"
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("audio", response.json())

    def test_every_attempt_is_logged(self):
        from .models import PronunciationDebugAttempt

        self.submit(reference="bola", language="ms")

        attempt = PronunciationDebugAttempt.objects.get(reference_text="bola")
        self.assertEqual(attempt.recognized_text, "bola")
        self.assertEqual(attempt.created_by, self.staff)

    @override_settings(DEBUG=True)
    def test_processing_time_is_stored_in_development_mode(self):
        from .models import PronunciationDebugAttempt

        self.submit(reference="bola", language="ms")

        attempt = PronunciationDebugAttempt.objects.get(reference_text="bola")
        self.assertIsNotNone(attempt.processing_time_ms)

    @override_settings(DEBUG=False)
    def test_processing_time_is_not_stored_outside_development_mode(self):
        from .models import PronunciationDebugAttempt

        response = self.submit(reference="bola", language="ms")

        # Still returned in the response - the sandbox itself is already
        # gated on `is_staff`, so a developer running it against a
        # DEBUG=False deployment still needs to see the numbers.
        self.assertIn("performance", response.json())

        attempt = PronunciationDebugAttempt.objects.get(reference_text="bola")
        self.assertIsNone(attempt.processing_time_ms)

    def test_raw_avg_logprob_never_reaches_the_response(self):
        """Whisper's raw log-probability is negative and unbounded below;
        the calibrated confidence this endpoint returns must always be a
        plain 0-1 fraction, never that raw figure."""
        response = self.submit(reference="bola", language="ms")

        confidence = response.json()["whisper"]["confidence"]
        self.assertGreaterEqual(confidence, 0.0)
        self.assertLessEqual(confidence, 1.0)


class PronunciationDatasetConsistencyTests(APITestCase):
    """Runs the Phase 2 validation dataset directly against the engine (no
    HTTP, no mocked recognition needed) to check that every correct word
    scores well and every mispronunciation scores measurably lower."""

    def test_every_correct_word_scores_well(self):
        for language, spec in PRONUNCIATION_TEST_WORDS.items():
            for word in spec["words"]:
                result = debug_evaluate(
                    reference_text=word,
                    recognized_text=word,
                    confidence=95.0,
                    language_code=language,
                )
                self.assertGreaterEqual(
                    result.pronunciation_score,
                    75,
                    f"{language}:{word} scored too low when said correctly",
                )

    def test_every_mispronunciation_scores_lower_than_correct(self):
        for language, spec in PRONUNCIATION_TEST_WORDS.items():
            for word, mispronounced in spec["mispronunciations"].items():
                correct = debug_evaluate(
                    reference_text=word,
                    recognized_text=word,
                    confidence=95.0,
                    language_code=language,
                )
                wrong = debug_evaluate(
                    reference_text=word,
                    recognized_text=mispronounced,
                    confidence=95.0,
                    language_code=language,
                )

                if wrong.recognized_phonemes == correct.reference_phonemes:
                    # A genuine, documented G2P limitation, not a scoring
                    # bug: e.g. English "banana" -> "bananna" is a spelling
                    # mistake that g2p_en's model happens to realise as the
                    # *same* phoneme sequence (it collapses the doubled
                    # consonant), so there is nothing for the engine to
                    # penalise - the text-level mispronunciation never
                    # reaches the phoneme layer at all. See
                    # docs/pronunciation-engine.md.
                    self.assertEqual(wrong.pronunciation_score, correct.pronunciation_score)
                    continue

                self.assertLess(
                    wrong.pronunciation_score,
                    correct.pronunciation_score,
                    f"{language}:{word} -> {mispronounced} did not score lower",
                )
                # A mispronunciation is only useful for validation if the
                # engine can also point at *something* specific about it.
                self.assertTrue(
                    wrong.errors,
                    f"{language}:{word} -> {mispronounced} produced no errors",
                )
