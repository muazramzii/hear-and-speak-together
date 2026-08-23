"""A log of developer-sandbox pronunciation attempts.

Deliberately separate from `PracticeAttempt`: this is not a child's practice
history, it carries no profile or word (the sandbox tests arbitrary
reference text, not seeded content), and it exists purely so the accuracy
and performance of the engine itself can be reviewed later - the raw
material Learning Analytics will eventually read from.
"""

from django.db import models
from django.utils.translation import gettext_lazy as _


def debug_audio_path(instance, filename):
    return f"pronunciation-debug/{instance.created_at:%Y/%m/%d}/{filename}"


class PronunciationDebugAttempt(models.Model):
    created_by = models.ForeignKey(
        "accounts.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="pronunciation_debug_attempts",
    )

    reference_text = models.CharField(_("reference text"), max_length=120)
    recognized_text = models.CharField(
        _("recognized text"), max_length=255, blank=True
    )
    language_code = models.CharField(_("language code"), max_length=8)

    similarity_score = models.FloatField(_("similarity"), null=True, blank=True)
    confidence_score = models.FloatField(_("confidence"), null=True, blank=True)
    completeness_score = models.FloatField(_("completeness"), null=True, blank=True)
    pronunciation_score = models.FloatField(_("pronunciation"), null=True, blank=True)
    phoneme_distance = models.PositiveIntegerField(
        _("phoneme edit distance"), null=True, blank=True
    )
    errors = models.JSONField(_("errors"), default=list, blank=True)

    processing_time_ms = models.FloatField(
        _("total processing time (ms)"), null=True, blank=True
    )

    # Optional and off unless explicitly enabled - a raw recording is still
    # sensitive even in a developer tool.
    audio = models.FileField(
        _("audio"), upload_to=debug_audio_path, null=True, blank=True
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("pronunciation debug attempt")
        verbose_name_plural = _("pronunciation debug attempts")
        ordering = ["-created_at"]

    def __str__(self):
        return (
            f"{self.reference_text} -> {self.recognized_text or '(nothing heard)'} "
            f"[{self.language_code}]"
        )
