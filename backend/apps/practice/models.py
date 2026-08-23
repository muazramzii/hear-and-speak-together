"""Records of speaking attempts."""

from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.content.models import Word
from apps.profiles.models import Profile

# Re-exported so Django's app registry discovers them; quiz results and the
# dev-sandbox debug log each live in their own module because they are a
# different kind of record entirely.
from .debug_models import PronunciationDebugAttempt  # noqa: F401
from .quiz_models import QuizMode, QuizSession  # noqa: F401


def attempt_audio_path(instance, filename):
    return f"attempts/{instance.profile_id}/{instance.word_id}/{filename}"


class PracticeAttempt(models.Model):
    """One recording, scored by the self-hosted pronunciation engine.

    Attached to a `Profile` rather than a `User`: on a shared family account
    the attempt belongs to the child who made it.

    There is no prosody field here, unlike the Azure-backed version of this
    model. Whisper plus a text-level phonetic comparison has no acoustic
    signal to derive stress or intonation from, so the metric does not exist
    in this architecture at all - not a null placeholder for something that
    might one day be measured, just absent.
    """

    profile = models.ForeignKey(
        Profile, on_delete=models.CASCADE, related_name="attempts"
    )
    word = models.ForeignKey(
        Word, on_delete=models.CASCADE, related_name="attempts"
    )

    language_code = models.CharField(_("language code"), max_length=8)
    locale = models.CharField(_("locale"), max_length=16)

    reference_text = models.CharField(_("reference text"), max_length=120)
    recognized_text = models.CharField(
        _("recognized text"), max_length=255, blank=True
    )

    # ---- Pronunciation engine scores (0-100) ----
    similarity_score = models.FloatField(
        _("similarity"),
        null=True,
        blank=True,
        help_text=_("Phonetic-feature distance between reference and spoken."),
    )
    confidence_score = models.FloatField(
        _("confidence"),
        null=True,
        blank=True,
        help_text=_("Whisper's own confidence in the transcription."),
    )
    completeness_score = models.FloatField(_("completeness"), null=True, blank=True)
    pronunciation_score = models.FloatField(
        _("pronunciation"),
        null=True,
        blank=True,
        help_text=_("The single weighted score shown to the child."),
    )

    errors = models.JSONField(
        _("errors"),
        default=list,
        blank=True,
        help_text=_("Structured list of {type, expected, detected}."),
    )
    feedback = models.TextField(_("feedback"), blank=True)
    points_awarded = models.PositiveIntegerField(_("points awarded"), default=0)

    # Only populated when STORE_AUDIO is enabled. Off by default: recordings
    # of children are sensitive, and storing every one costs money for little
    # benefit.
    audio = models.FileField(
        _("audio"), upload_to=attempt_audio_path, null=True, blank=True
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("practice attempt")
        verbose_name_plural = _("practice attempts")
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["profile", "-created_at"]),
            models.Index(fields=["profile", "word"]),
        ]

    def __str__(self):
        return f"{self.profile.name} - {self.reference_text} ({self.display_score})"

    @property
    def display_score(self):
        if self.pronunciation_score is None:
            return None
        return round(self.pronunciation_score)

    @property
    def was_successful(self):
        score = self.display_score
        return score is not None and score >= 75
