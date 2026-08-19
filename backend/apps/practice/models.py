"""Records of speaking attempts."""

from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.content.models import Word
from apps.profiles.models import Profile


def attempt_audio_path(instance, filename):
    return f"attempts/{instance.profile_id}/{instance.word_id}/{filename}"


class PracticeAttempt(models.Model):
    """One recording, scored.

    Attached to a `Profile` rather than a `User`: on a shared family account
    the attempt belongs to the child who made it.

    Every score is nullable on purpose. Azure does not measure every metric
    for every locale - prosody is en-US only - and a null here means "not
    measured". It must never be displayed as zero.
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

    # ---- Azure scores (0-100) ----
    accuracy_score = models.FloatField(_("accuracy"), null=True, blank=True)
    fluency_score = models.FloatField(_("fluency"), null=True, blank=True)
    pronunciation_score = models.FloatField(
        _("pronunciation"), null=True, blank=True
    )
    completeness_score = models.FloatField(
        _("completeness"), null=True, blank=True
    )
    prosody_score = models.FloatField(
        _("prosody"),
        null=True,
        blank=True,
        help_text=_("Null where the locale does not support prosody (ms-MY)."),
    )

    error_type = models.CharField(
        _("error type"), max_length=32, blank=True
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
        if self.pronunciation_score is not None:
            return round(self.pronunciation_score)
        if self.accuracy_score is not None:
            return round(self.accuracy_score)
        return None

    @property
    def was_successful(self):
        score = self.display_score
        return score is not None and score >= 75
