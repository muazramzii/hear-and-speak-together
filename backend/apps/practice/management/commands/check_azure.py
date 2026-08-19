"""Verify the Azure AI Speech integration against the real service.

    python manage.py check_azure
    python manage.py check_azure --locale ms-MY
    python manage.py check_azure --audio recording.wav --word elephant

This is the one step that cannot be proven by the test suite, because the
tests deliberately never call a paid API. Run it once before relying on
assessment, and again after any change to credentials or region.

With no `--audio`, it sends one second of silence. Azure should answer
"no speech recognised" - which is a *successful* outcome here, because
reaching that answer proves the key, the region, the locale and the audio
format are all accepted. Only the recognition failed, and deliberately so.

With `--audio`, it runs a real assessment and prints every metric, marking
which ones the locale did not measure.
"""

import io
import wave

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.content.models import Language
from apps.practice.services.azure_service import (
    AzurePronunciationAssessmentService,
)
from apps.practice.services.base import AssessmentError, NoSpeechDetected

# Azure's models expect 16 kHz mono 16-bit PCM.
SAMPLE_RATE = 16000
SAMPLE_WIDTH = 2
CHANNELS = 1


def silent_wav(seconds=1.0):
    """A valid WAV carrying no speech.

    Enough to exercise authentication, region routing and format handling
    without needing a recording to hand.
    """
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(CHANNELS)
        handle.setsampwidth(SAMPLE_WIDTH)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(b"\x00" * int(SAMPLE_RATE * SAMPLE_WIDTH * seconds))
    buffer.seek(0)
    return buffer


class Command(BaseCommand):
    help = "Make one real call to Azure AI Speech and report what came back."

    def add_arguments(self, parser):
        parser.add_argument(
            "--locale",
            default="en-US",
            help="Locale to test. Defaults to en-US.",
        )
        parser.add_argument(
            "--word",
            default="elephant",
            help="Reference text to score against.",
        )
        parser.add_argument(
            "--audio",
            help="A 16 kHz mono WAV to assess. Omit to send silence.",
        )

    def handle(self, *args, **options):
        locale = options["locale"]
        word = options["word"]

        self._report_configuration(locale)

        language = Language.objects.filter(locale=locale).first()
        if language is None:
            self.stdout.write(
                self.style.WARNING(
                    f"  no Language row for {locale}; assuming prosody is "
                    f"unsupported"
                )
            )
        enable_prosody = bool(language and language.supports_prosody)

        service = self._build_service()
        audio, using_silence = self._open_audio(options["audio"])

        self.stdout.write("")
        self.stdout.write(f"Calling Azure ({locale}, reference '{word}')...")

        try:
            result = service.assess(
                audio=audio,
                reference_text=word,
                language_code=(language.code if language else locale[:2]),
                locale=locale,
                enable_prosody=enable_prosody,
            )
        except NoSpeechDetected:
            if using_silence:
                # The expected outcome: Azure was reached, understood the
                # request, and correctly heard nothing.
                self._pass(
                    "Azure answered 'no speech recognised', which is exactly "
                    "right for silence."
                )
                self._pass(
                    "Credentials, region, locale and audio format are all "
                    "accepted."
                )
                self.stdout.write("")
                self.stdout.write(
                    "Re-run with --audio <recording.wav> to score real speech."
                )
                return
            raise CommandError(
                "Azure heard no speech in that recording. Check it contains "
                "audio and is 16 kHz mono WAV."
            )
        except AssessmentError as error:
            self._fail(error.user_message)
            self.stdout.write(self.style.ERROR(f"  detail: {error.detail}"))
            raise CommandError("Azure call failed. See the detail above.")

        self._report_result(result, language, using_silence)

    # -- steps ------------------------------------------------------------

    def _report_configuration(self, locale):
        key = settings.AZURE_SPEECH_KEY
        region = settings.AZURE_SPEECH_REGION
        provider = settings.SPEECH_PROVIDER

        self.stdout.write("Configuration")
        self.stdout.write(
            f"  SPEECH_PROVIDER      {provider}"
            + ("" if provider == "azure" else "   (the app is using the mock)")
        )
        # Never print the key itself, only enough to tell two keys apart.
        self.stdout.write(
            f"  AZURE_SPEECH_KEY     "
            + (f"set, ends '{key[-4:]}'" if key else "MISSING")
        )
        self.stdout.write(f"  AZURE_SPEECH_REGION  {region or 'MISSING'}")
        self.stdout.write(f"  locale               {locale}")

        if provider != "azure":
            self.stdout.write("")
            self.stdout.write(
                self.style.WARNING(
                    "  This command calls Azure directly regardless, so the "
                    "check is still valid - but the app itself will keep "
                    "using the mock until SPEECH_PROVIDER=azure."
                )
            )

    def _build_service(self):
        try:
            return AzurePronunciationAssessmentService(
                speech_key=settings.AZURE_SPEECH_KEY,
                speech_region=settings.AZURE_SPEECH_REGION,
            )
        except AssessmentError as error:
            raise CommandError(
                f"{error.user_message} ({error.detail})"
            ) from error

    def _open_audio(self, path):
        if not path:
            return silent_wav(), True

        try:
            return open(path, "rb"), False
        except OSError as exc:
            raise CommandError(f"Could not read {path}: {exc}") from exc

    def _report_result(self, result, language, using_silence):
        self.stdout.write("")
        self._pass("Azure returned a pronunciation assessment.")
        self.stdout.write("")
        self.stdout.write(f"  recognised text   {result.recognized_text!r}")
        self.stdout.write(f"  overall score     {result.display_score}")
        self.stdout.write("")
        self.stdout.write("Metrics")

        metrics = {
            "accuracy": result.accuracy_score,
            "fluency": result.fluency_score,
            "completeness": result.completeness_score,
            "pronunciation": result.pronunciation_score,
            "prosody": result.prosody_score,
        }

        for name, value in metrics.items():
            if value is None:
                self.stdout.write(
                    f"  {name:<16} not measured for this locale"
                )
            else:
                self.stdout.write(f"  {name:<16} {value}")

        self._check_prosody_expectation(language, result)

    def _check_prosody_expectation(self, language, result):
        """The claim the whole capability layer rests on, tested for real.

        Azure documents prosody as en-US only. If reality ever disagrees with
        the stored flag, this is where it surfaces - rather than as a score
        the app quietly refuses to show, or one it shows without measuring.
        """
        if language is None:
            return

        self.stdout.write("")
        expected = language.supports_prosody
        actual = result.prosody_score is not None

        if expected == actual:
            self._pass(
                f"Prosody support for {language.locale} matches the stored "
                f"capability flag ({'yes' if expected else 'no'})."
            )
            return

        self._fail(
            f"Prosody mismatch for {language.locale}: the database says "
            f"{'supported' if expected else 'unsupported'}, Azure "
            f"{'returned' if actual else 'did not return'} a score."
        )
        self.stdout.write(
            self.style.ERROR(
                "  Update Language.supports_prosody and "
                "capabilities_verified_on in the admin."
            )
        )

    def _pass(self, message):
        self.stdout.write(self.style.SUCCESS(f"  OK  {message}"))

    def _fail(self, message):
        self.stdout.write(self.style.ERROR(f"  !!  {message}"))
