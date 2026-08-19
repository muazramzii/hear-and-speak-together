"""Tests for the check_azure command.

The command exists to make a real Azure call, so these cover everything
around that call - the audio it generates, the diagnostics it prints, and how
it reacts to each outcome - with the service itself patched out.
"""

import io
import wave
from unittest.mock import patch

from django.core.management import CommandError, call_command
from django.test import TestCase, override_settings

from apps.content.models import Language
from apps.practice.management.commands.check_azure import (
    CHANNELS,
    SAMPLE_RATE,
    SAMPLE_WIDTH,
    silent_wav,
)
from apps.practice.services.base import (
    AssessmentError,
    NoSpeechDetected,
    PronunciationAssessmentResult,
)

SERVICE = "apps.practice.management.commands.check_azure." \
          "AzurePronunciationAssessmentService"


def result_with(prosody):
    return PronunciationAssessmentResult(
        language_code="en",
        locale="en-US",
        reference_text="elephant",
        recognized_text="elephant",
        accuracy_score=88,
        fluency_score=90,
        completeness_score=100,
        pronunciation_score=89,
        prosody_score=prosody,
    )


class SilentWavTests(TestCase):
    def test_produces_the_format_azure_expects(self):
        data = silent_wav(seconds=1.0).read()

        with wave.open(io.BytesIO(data), "rb") as handle:
            self.assertEqual(handle.getframerate(), SAMPLE_RATE)
            self.assertEqual(handle.getnchannels(), CHANNELS)
            self.assertEqual(handle.getsampwidth(), SAMPLE_WIDTH)
            self.assertEqual(handle.getnframes(), SAMPLE_RATE)

    def test_contains_no_audio(self):
        data = silent_wav(seconds=0.25).read()

        with wave.open(io.BytesIO(data), "rb") as handle:
            frames = handle.readframes(handle.getnframes())

        self.assertEqual(set(frames), {0})

    def test_stream_is_positioned_at_the_start(self):
        # A stream left at the end would send zero bytes to Azure.
        self.assertEqual(silent_wav().tell(), 0)


@override_settings(AZURE_SPEECH_KEY="", AZURE_SPEECH_REGION="")
class MissingCredentialsTests(TestCase):
    def test_fails_before_making_any_call(self):
        with self.assertRaises(CommandError) as caught:
            call_command("check_azure", verbosity=0)

        self.assertIn("not configured", str(caught.exception))


@override_settings(AZURE_SPEECH_KEY="fake-key", AZURE_SPEECH_REGION="eastus")
class SilenceProbeTests(TestCase):
    def test_no_speech_on_silence_is_treated_as_success(self):
        """Reaching 'no speech recognised' proves the key, region, locale and
        audio format were all accepted."""
        with patch(SERVICE) as service:
            service.return_value.assess.side_effect = NoSpeechDetected()

            out = io.StringIO()
            call_command("check_azure", stdout=out)

        self.assertIn("no speech recognised", out.getvalue())
        self.assertIn("accepted", out.getvalue())

    def test_an_assessment_error_is_surfaced_with_its_detail(self):
        with patch(SERVICE) as service:
            service.return_value.assess.side_effect = AssessmentError(
                user_message="Speech assessment is not available right now.",
                detail="Azure authentication failed: 401",
            )

            out = io.StringIO()
            with self.assertRaises(CommandError):
                call_command("check_azure", stdout=out, stderr=out)

        self.assertIn("401", out.getvalue())

    def test_the_key_is_never_printed_in_full(self):
        with patch(SERVICE) as service:
            service.return_value.assess.side_effect = NoSpeechDetected()

            out = io.StringIO()
            call_command("check_azure", stdout=out)

        self.assertNotIn("fake-key", out.getvalue())


@override_settings(AZURE_SPEECH_KEY="fake-key", AZURE_SPEECH_REGION="eastus")
class ResultReportingTests(TestCase):
    def setUp(self):
        Language.objects.create(
            code="en",
            name="English",
            locale="en-US",
            supports_prosody=True,
        )
        Language.objects.create(
            code="ms",
            name="Bahasa Melayu",
            locale="ms-MY",
            supports_prosody=False,
        )

    def run_with(self, result, **options):
        with patch(SERVICE) as service:
            service.return_value.assess.return_value = result
            out = io.StringIO()
            call_command("check_azure", "--audio", __file__, stdout=out, **options)
        return out.getvalue()

    def test_reports_every_metric(self):
        output = self.run_with(result_with(prosody=91))

        for metric in (
            "accuracy",
            "fluency",
            "completeness",
            "pronunciation",
            "prosody",
        ):
            self.assertIn(metric, output)

    def test_marks_unmeasured_metrics_rather_than_showing_zero(self):
        output = self.run_with(result_with(prosody=None))

        self.assertIn("not measured for this locale", output)

    def test_confirms_prosody_matches_the_stored_flag(self):
        output = self.run_with(result_with(prosody=91))

        self.assertIn("matches the stored capability flag", output)

    def test_flags_a_mismatch_between_azure_and_the_database(self):
        """en-US claims prosody support; if Azure returns none, the stored
        flag is wrong and the app would hide a metric it could show."""
        output = self.run_with(result_with(prosody=None))

        self.assertIn("Prosody mismatch", output)
        self.assertIn("supports_prosody", output)

    def test_a_missing_audio_file_fails_clearly(self):
        with self.assertRaises(CommandError) as caught:
            call_command("check_azure", "--audio", "no-such-file.wav", verbosity=0)

        self.assertIn("Could not read", str(caught.exception))
